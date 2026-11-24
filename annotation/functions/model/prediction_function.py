
import json
import os

import mysql.connector
import numpy as np
import onnxruntime as ort
import pandas as pd

from . import trainer


# --------------------------------------------------
# CONFIGURATION FROM TRAINER
# --------------------------------------------------

TABLE_NAME = "labeled_flatdata"

TARGET = trainer.TARGET

TIMEFRAMES = trainer.TIMEFRAMES

FEATURE_COLUMNS = trainer.generate_feature_columns()


# --------------------------------------------------
# DATABASE CONNECTION
# --------------------------------------------------

def get_connection():

    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="marketdata",
    )


# --------------------------------------------------
# MAIN PREDICTION FUNCTION
# --------------------------------------------------

def prediction(candle_id):

    print("\n========== START PREDICTION ==========\n")

    script_dir = os.path.dirname(
        os.path.abspath(__file__)
    )

    # ------------------------------------------
    # 1. LOAD MODEL FILE PATHS
    # ------------------------------------------

    model_path = os.path.join(
        script_dir,
        f"model_{TARGET}.onnx"
    )

    classes_path = os.path.join(
        script_dir,
        f"classes_{TARGET}.json"
    )

    features_path = os.path.join(
        script_dir,
        f"features_{TARGET}.json"
    )

    required_files = [
        model_path,
        classes_path,
        features_path
    ]

    for path in required_files:

        if not os.path.exists(path):

            raise FileNotFoundError(
                f"Missing model file: {path}"
            )

    # ------------------------------------------
    # 2. LOAD TRAINING FEATURE ORDER
    # ------------------------------------------

    with open(features_path, "r") as f:

        expected_features = json.load(f)

    print(
        "Expected model features:",
        len(expected_features)
    )

    if expected_features != FEATURE_COLUMNS:

        raise ValueError(
            "Feature configuration mismatch between "
            "trainer.py and saved ONNX model."
        )

    # ------------------------------------------
    # 3. FETCH CANDLE FROM DATABASE
    # ------------------------------------------

    db = None

    try:

        db = get_connection()

        query = f"""
            SELECT *
            FROM {TABLE_NAME}
            WHERE id = %s
        """

        df = pd.read_sql(
            query,
            db,
            params=(candle_id,)
        )

    except Exception as e:

        print("Database error:", e)

        return {}

    finally:

        if db is not None and db.is_connected():

            db.close()

    if df.empty:

        print("Candle not found:", candle_id)

        return {}

    # ------------------------------------------
    # 4. VALIDATE DATABASE COLUMNS
    # ------------------------------------------

    missing_columns = [
        col
        for col in expected_features
        if col not in df.columns
    ]

    if missing_columns:

        raise ValueError(
            "Missing database columns:\n"
            + "\n".join(missing_columns)
        )

    # ------------------------------------------
    # 5. EXTRACT FEATURES
    # ------------------------------------------

    X_input = df[expected_features].copy()

    X_input = X_input.apply(
        pd.to_numeric,
        errors="coerce"
    )

    X_input = X_input.replace(
        [np.inf, -np.inf],
        np.nan
    )

    input_data = X_input.to_numpy(
        dtype=np.float32
    )

    # ------------------------------------------
    # 6. VALIDATE INPUT SHAPE
    # ------------------------------------------

    expected_shape = (
        1,
        len(expected_features)
    )

    if input_data.shape != expected_shape:

        raise ValueError(
            f"Invalid input shape: {input_data.shape}. "
            f"Expected: {expected_shape}"
        )

    # ------------------------------------------
    # 7. LOAD CLASS MAPPING
    # ------------------------------------------

    with open(classes_path, "r") as f:

        classes = json.load(f)

    # ------------------------------------------
    # 8. INPUT SUMMARY
    # ------------------------------------------

    print("\n========== INPUT SUMMARY ==========\n")

    print("Candle ID:", candle_id)

    print("H4 candles:", TIMEFRAMES["H4"])

    print("H1 candles:", TIMEFRAMES["H1"])

    print("M15 candles:", TIMEFRAMES["M15"])

    print("M5 candles:", TIMEFRAMES["M5"])

    print(
        "Total features:",
        input_data.shape[1]
    )

    print(
        "Missing values:",
        int(np.isnan(input_data).sum())
    )

    print(
        "Time remaining columns:",
        [
            col for col in expected_features
            if col.startswith("time_remaining_")
        ]
    )

    # ------------------------------------------
    # 9. LOAD ONNX MODEL
    # ------------------------------------------

    session = ort.InferenceSession(
        model_path,
        providers=["CPUExecutionProvider"]
    )

    input_name = session.get_inputs()[0].name

    # ------------------------------------------
    # 10. RUN PREDICTION
    # ------------------------------------------

    outputs = session.run(
        None,
        {
            input_name: input_data
        }
    )

    predicted_class_idx = int(
        np.asarray(outputs[0]).reshape(-1)[0]
    )

    if not 0 <= predicted_class_idx < len(classes):

        raise ValueError(
            f"Invalid predicted class index: "
            f"{predicted_class_idx}"
        )

    predicted_label = classes[predicted_class_idx]

    # ------------------------------------------
    # 11. GET CLASS PROBABILITIES
    # ------------------------------------------

    probabilities = {}

    if len(outputs) > 1:

        probability_array = np.asarray(
            outputs[1]
        ).reshape(1, -1)[0]

        for index, class_name in enumerate(classes):

            if index < len(probability_array):

                probabilities[class_name] = float(
                    probability_array[index]
                )

    # ------------------------------------------
    # 12. FINAL RESULTS
    # ------------------------------------------

    results = {

        "id": candle_id,

        "decision": predicted_label,

        "class_index": predicted_class_idx,

        "probabilities": probabilities,

        "features": input_data.shape[1],

        "timeframes": list(TIMEFRAMES.keys())
    }

    print("\n========== FINAL PREDICTION ==========\n")

    print("Candle ID:", candle_id)

    print("Decision:", predicted_label)

    print("\nClass probabilities:")

    for class_name, probability in probabilities.items():

        print(
            f"{class_name}: {probability:.2%}"
        )

    print("\n========== PREDICTION COMPLETE ==========\n")

    return results


# --------------------------------------------------
# EXAMPLE USAGE
# --------------------------------------------------

if __name__ == "__main__":

    result = prediction(12345)

    print("\nReturned result:")

    print(result)
