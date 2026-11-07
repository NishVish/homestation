
import json
import os
import mysql.connector
import numpy as np
import onnxruntime as ort
import pandas as pd


def get_connection():

    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="marketdata",
    )


# ==================================================
# GENERATE ALL FEATURES FOR SELECTED TIMEFRAME
# ==================================================

def generate_feature_columns(timeframe, df):

    timeframe_prefix = {
        "15m": "M15",
        "5m": "M5",
        "1m": "M1"
    }

    if timeframe not in timeframe_prefix:
        raise ValueError(
            f"Unsupported timeframe: {timeframe}"
        )

    prefix = timeframe_prefix[timeframe]

    columns = [
        col for col in df.columns
        if col.startswith(prefix + "_")
    ]

    if not columns:
        raise ValueError(
            f"No features found for timeframe: {timeframe}"
        )

    return columns


# ==================================================
# MAIN PREDICTION FUNCTION
# ==================================================

def prediction(candle_id, timeframe="1m"):

    print("\n========== START PREDICTION ==========")

    script_dir = os.path.dirname(
        os.path.abspath(__file__)
    )

    # ------------------------------------------
    # 1. FETCH CANDLE
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
    # 2. LOAD ALL RAW FEATURES DYNAMICALLY
    # ------------------------------------------

    try:

        raw_feature_columns = generate_feature_columns(
            timeframe,
            df
        )

    except ValueError as e:

        print("Feature error:", e)
        return {}

    print(
        f"Timeframe: {timeframe}"
    )

    print(
        f"Total raw features: {len(raw_feature_columns)}"
    )

    X_raw = df[raw_feature_columns].copy()

    X_raw = X_raw.apply(
        pd.to_numeric,
        errors="coerce"
    )

    X_raw = X_raw.replace(
        [np.inf, -np.inf],
        np.nan
    )

    feature_values = X_raw.iloc[0].to_dict()

    results = {}

    # ------------------------------------------
    # 3. PREDICT ONE MODEL
    # ------------------------------------------

    def predict_model(target):

        model_path = os.path.join(
            script_dir,
            f"model_{target}.onnx"
        )

        classes_path = os.path.join(
            script_dir,
            f"classes_{target}.json"
        )

        features_path = os.path.join(
            script_dir,
            f"features_{target}.json"
        )

        if not all(
            os.path.exists(path)
            for path in [
                model_path,
                classes_path,
                features_path
            ]
        ):

            raise FileNotFoundError(
                f"Missing model files for {target}"
            )

        with open(classes_path, "r") as f:
            classes = json.load(f)

        with open(features_path, "r") as f:
            expected_features = json.load(f)

        # Exact feature order used during training.

        input_values = [
            feature_values.get(col, np.nan)
            for col in expected_features
        ]

        input_data = np.asarray(
            [input_values],
            dtype=np.float32
        )

        session = ort.InferenceSession(
            model_path,
            providers=["CPUExecutionProvider"]
        )

        input_name = session.get_inputs()[0].name

        outputs = session.run(
            None,
            {
                input_name: input_data
            }
        )

        # RandomForestClassifier ONNX output:
        # First output contains encoded class labels.

        predicted_class_idx = int(
            np.asarray(outputs[0]).reshape(-1)[0]
        )

        if not 0 <= predicted_class_idx < len(classes):

            raise ValueError(
                f"Invalid predicted class index for {target}: "
                f"{predicted_class_idx}"
            )

        predicted_label = classes[predicted_class_idx]

        print(
            f"{target}: {predicted_label}"
        )

        return predicted_label

    # ------------------------------------------
    # 4. ADD ONE-HOT PREDICTION FEATURES
    # ------------------------------------------

    def add_prediction_features(target, predicted_label):

        classes_path = os.path.join(
            script_dir,
            f"classes_{target}.json"
        )

        with open(classes_path, "r") as f:
            classes = json.load(f)

        for class_name in classes:

            feature_values[
                f"pred_{target}__{class_name}"
            ] = np.float32(
                predicted_label == class_name
            )

    # ------------------------------------------
    # 5. STAGE 1: FIRST 9 MODELS
    # ------------------------------------------

    base_targets = [
        "was",
        "then",
        "currently",
        "future",
        "volatility",
        "bias",
        "phase",
        "momentum_direction",
        "momentum_strength",
    ]

    for target in base_targets:

        predicted_label = predict_model(target)

        results[target] = predicted_label

        add_prediction_features(
            target,
            predicted_label
        )

    # ------------------------------------------
    # 6. STAGE 2: SETUP
    # ------------------------------------------

    setup_prediction = predict_model("setup")

    results["setup"] = setup_prediction

    add_prediction_features(
        "setup",
        setup_prediction
    )

    # ------------------------------------------
    # 7. STAGE 3: MOMENTUM CANDLE
    # ------------------------------------------

    momentum_prediction = predict_model(
        "momentum_candle"
    )

    results["momentum_candle"] = momentum_prediction

    add_prediction_features(
        "momentum_candle",
        momentum_prediction
    )

    # ------------------------------------------
    # 8. STAGE 4: DECISION
    # ------------------------------------------

    decision_prediction = predict_model(
        "decision"
    )

    results["decision"] = decision_prediction

    # ------------------------------------------
    # 9. FINAL RESULTS
    # ------------------------------------------

    print("\n========== FINAL PREDICTIONS ==========")

    print(results)

    print("\n========== PREDICTION COMPLETE ==========")

    return results


# ==================================================
# EXAMPLE USAGE
# ==================================================

# prediction(12345, "15m")
# prediction(12345, "5m")
# prediction(12345, "1m")
