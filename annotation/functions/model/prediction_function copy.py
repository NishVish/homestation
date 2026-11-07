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


def prediction(candle_id):
    print("this is prediction")
    """Takes a candle id, queries MySQL, runs inference across all ONNX models,

    and returns a dictionary of predicted labels.
    """
    target_models = [
        "was",
        "then",
        "currently",
        "future",
        "volatility",
        "bias",
        "phase",
        "momentum_direction",
        "momentum_strength",
        "setup",
        "momentum_candle",
        "decision",
    ]

    # Fetch record from database
    try:
        db = get_connection()
        query = "SELECT * FROM `labeled_flatdata` WHERE `id` = %s"
        df_new = pd.read_sql(query, db, params=(candle_id,))
    except Exception as e:
        print(f"Database connection error during prediction: {e}")
        return {}
    finally:
        if "db" in locals() and db.is_connected():
            db.close()

    if df_new.empty:
        print(f"No record found with id = {candle_id} for prediction.")
        return {}

    # Extract and format features
    feature_columns = [
        col
        for col in df_new.columns
        if col.startswith("M1_")
        and not col.endswith("_time")
        and col.rsplit("_", 1)[-1] in {"open", "high", "low", "close"}
    ]

    X_new = df_new[feature_columns].copy()
    X_new = X_new.apply(pd.to_numeric, errors="coerce")
    X_new = X_new.replace([np.inf, -np.inf], np.nan)
    input_data = X_new.to_numpy(dtype=np.float32)

    results = {}

    # Get the absolute directory where prediction_function.py lives
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Loop through each target model and run inference using absolute paths
    for target_name in target_models:
        onnx_model_path = os.path.join(script_dir, f"model_{target_name}.onnx")
        classes_path = os.path.join(script_dir, f"classes_{target_name}.json")

        if not os.path.exists(onnx_model_path) or not os.path.exists(classes_path):
            continue

        try:
            session = ort.InferenceSession(onnx_model_path)
            with open(classes_path, "r") as f:
                class_labels = json.load(f)

            input_name = session.get_inputs()[0].name
            expected_feature_count = session.get_inputs()[0].shape[1]

            if input_data.shape[1] != expected_feature_count:
                continue

            outputs = session.run(None, {input_name: input_data})
            predicted_class_idx = outputs[0][0]
            predicted_label = class_labels[int(predicted_class_idx)]

            results[target_name] = predicted_label

        except Exception as e:
            print(f"Inference error for model '{target_name}': {e}")
            
    print("this is Prediction_end")
    return results