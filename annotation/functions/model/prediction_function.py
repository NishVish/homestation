import json
import os

import mysql.connector
import numpy as np
import onnxruntime as ort
import pandas as pd


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
# CONFIGURATION
# --------------------------------------------------

TABLE_NAME = "labeled_flatdata"

TARGET = "decision"

TIMEFRAMES = {
    "H4": 20,
    "H1": 20,
    "M15": 20,
    "M5": 20,
}

OHLC_COLUMNS = [
    "open",
    "high",
    "low",
    "close"
]


# --------------------------------------------------
# GENERATE ALL FEATURE COLUMNS
# --------------------------------------------------

def generate_feature_columns():

    feature_columns = []

    for timeframe, candle_count in TIMEFRAMES.items():

        for candle in range(1, candle_count + 1):

            candle_name = f"{timeframe}_{candle:02d}"

            for ohlc in OHLC_COLUMNS:

                feature_columns.append(
                    f"{candle_name}_{ohlc}"
                )

    return feature_columns


# --------------------------------------------------
# MAIN PREDICTION FUNCTION
# --------------------------------------------------

def prediction(candle_id):

    print("\n========== START PREDICTION ==========\n")

    script_dir = os.path.dirname(
        os.path.abspath(__file__)
    )

    # ------------------------------------------
    # 1. FETCH CANDLE FROM DATABASE
    # ------------------------------------------

    db = None

    try:

        db = get_connection()

        query = """
            SELECT *
            FROM labeled_flatdata
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
    # 2. GENERATE ALL EXPECTED FEATURES
    # ------------------------------------------

    raw_feature_columns = generate_feature_columns()

    print("Expected features:", len(raw_feature_columns))

    if len(raw_feature_columns) != 320:

        raise ValueError(
            "Expected exactly 320 input features."
        )

    # ------------------------------------------
    # 3. VALIDATE DATABASE COLUMNS
    # ------------------------------------------

    missing_columns = [
        col
        for col in raw_feature_columns
        if col not in df.columns
    ]

    if missing_columns:

        raise ValueError(
            "Missing database columns:\n"
            + "\n".join(missing_columns)
        )

    # ------------------------------------------
    # 4. EXTRACT ALL TIMEFRAME FEATURES
    # ------------------------------------------

    X_raw = df[raw_feature_columns].copy()

    X_raw = X_raw.apply(
        pd.to_numeric,
        errors="coerce"
    )

    X_raw = X_raw.replace(
        [np.inf, -np.inf],
        np.nan
    )

    # ------------------------------------------
    # 5. LOAD MODEL FILES
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
    # 6. LOAD CLASS MAPPING
    # ------------------------------------------

    with open(classes_path, "r") as f:

        classes = json.load(f)

    # ------------------------------------------
    # 7. LOAD EXACT FEATURE ORDER
    # ------------------------------------------

    with open(features_path, "r") as f:

        expected_features = json.load(f)

    if len(expected_features) != 320:

        raise ValueError(
            f"Expected 320 model features, "
            f"found {len(expected_features)}."
        )

    if expected_features != raw_feature_columns:

        raise ValueError(
            "Feature order mismatch between "
            "training and prediction."
        )

    # ------------------------------------------
    # 8. PREPARE MODEL INPUT
    # ------------------------------------------

    X_input = X_raw[expected_features].copy()

    input_data = X_input.to_numpy(
        dtype=np.float32
    )

    if input_data.shape != (1, 320):

        raise ValueError(
            f"Invalid input shape: {input_data.shape}"
        )

    print("\n========== INPUT SUMMARY ==========\n")

    print("Candle ID:", candle_id)

    print("H4 features:", 80)

    print("H1 features:", 80)

    print("M15 features:", 80)

    print("M5 features:", 80)

    print("Total features:", input_data.shape[1])

    print(
        "Missing values:",
        int(np.isnan(input_data).sum())
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

    # First ONNX output contains encoded class labels.

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
        )

        probability_array = probability_array.reshape(
            1, -1
        )[0]

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
