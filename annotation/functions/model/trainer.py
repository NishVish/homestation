import json
import os

import mysql.connector
import numpy as np
import pandas as pd

from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import accuracy_score
from sklearn.model_selection import StratifiedKFold, cross_val_predict
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder

from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType


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
# GENERATE FEATURE COLUMNS
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
# MODEL CREATION
# --------------------------------------------------

def create_model():

    return Pipeline([
        (
            "imputer",
            SimpleImputer(strategy="median")
        ),
        (
            "classifier",
            RandomForestClassifier(
                n_estimators=200,
                max_depth=None,
                min_samples_leaf=2,
                random_state=42,
                class_weight="balanced",
                n_jobs=-1,
            )
        )
    ])


# --------------------------------------------------
# LABEL CLEANING
# --------------------------------------------------

def clean_labels(series):

    values = series.fillna("").astype(str).str.strip()

    valid = (
        values.ne("")
        & values.str.lower().ne("nan")
        & values.str.lower().ne("null")
    )

    return values, valid


# --------------------------------------------------
# TRAIN MODEL AND GENERATE OOF PREDICTIONS
# --------------------------------------------------

def train_model(target, X, y_raw):

    encoder = LabelEncoder()

    y = encoder.fit_transform(y_raw)

    if len(encoder.classes_) < 2:

        raise ValueError(
            f"{target}: requires at least two different classes."
        )

    class_counts = pd.Series(y).value_counts()

    min_class_count = int(class_counts.min())

    model = create_model()

    # ------------------------------------------
    # OUT OF FOLD VALIDATION
    # ------------------------------------------

    if min_class_count >= 2:

        n_splits = min(5, min_class_count)

        cv = StratifiedKFold(
            n_splits=n_splits,
            shuffle=True,
            random_state=42
        )

        oof_predictions = cross_val_predict(
            create_model(),
            X,
            y,
            cv=cv,
            method="predict",
            n_jobs=1
        )

        accuracy = accuracy_score(
            y,
            oof_predictions
        )

        print(
            f"{target}: OOF accuracy = {accuracy:.2%}"
        )

    else:

        print(
            f"WARNING: {target} contains a class "
            "with only one sample."
        )

        print(
            "Using in-sample accuracy as fallback."
        )

        model.fit(X, y)

        oof_predictions = model.predict(X)

        accuracy = accuracy_score(
            y,
            oof_predictions
        )

    # ------------------------------------------
    # FINAL MODEL TRAINING
    # ------------------------------------------

    model.fit(X, y)

    return {
        "model": model,

        "encoder": encoder,

        "oof_predictions": encoder.inverse_transform(
            oof_predictions.astype(int)
        ),

        "accuracy": accuracy,

        "classes": list(encoder.classes_),

        "training_rows": len(y),
    }


# --------------------------------------------------
# EXPORT MODEL TO ONNX
# --------------------------------------------------

def export_model(
    target,
    model_data,
    feature_columns,
    script_dir
):

    model = model_data["model"]

    initial_type = [
        (
            "float_input",
            FloatTensorType([
                None,
                len(feature_columns)
            ])
        )
    ]

    onnx_model = convert_sklearn(
        model,
        initial_types=initial_type,
        options={
            id(model.named_steps["classifier"]): {
                "zipmap": False
            }
        }
    )

    # ------------------------------------------
    # SAVE ONNX MODEL
    # ------------------------------------------

    model_path = os.path.join(
        script_dir,
        f"model_{target}.onnx"
    )

    with open(model_path, "wb") as f:

        f.write(
            onnx_model.SerializeToString()
        )

    # ------------------------------------------
    # SAVE CLASS MAPPING
    # ------------------------------------------

    classes_path = os.path.join(
        script_dir,
        f"classes_{target}.json"
    )

    with open(classes_path, "w") as f:

        json.dump(
            model_data["classes"],
            f,
            indent=4
        )

    # ------------------------------------------
    # SAVE EXACT FEATURE ORDER
    # ------------------------------------------

    feature_path = os.path.join(
        script_dir,
        f"features_{target}.json"
    )

    with open(feature_path, "w") as f:

        json.dump(
            feature_columns,
            f,
            indent=4
        )

    print("\nModel exported:")
    print(model_path)

    print("\nClasses exported:")
    print(classes_path)

    print("\nFeatures exported:")
    print(feature_path)


# --------------------------------------------------
# MAIN TRAINING FUNCTION
# --------------------------------------------------

def train_models_and_export_onnx():

    print("\n========== START TRAINING ==========\n")

    script_dir = os.path.dirname(
        os.path.abspath(__file__)
    )

    db = None

    # ------------------------------------------
    # 1. LOAD DATABASE
    # ------------------------------------------

    try:

        db = get_connection()

        query = f"""
            SELECT *
            FROM {TABLE_NAME}
            WHERE edited = 1
        """

        df = pd.read_sql(query, db)

        print("Loaded database rows:", len(df))

    except Exception as e:

        print("Database error:", e)

        return None

    finally:

        if db is not None and db.is_connected():

            db.close()

    if df.empty:

        print("No training data found.")

        return None

    # ------------------------------------------
    # 2. GENERATE ALL FEATURE COLUMNS
    # ------------------------------------------

    feature_columns = generate_feature_columns()

    print("\n========== FEATURE CONFIGURATION ==========\n")

    for timeframe, candle_count in TIMEFRAMES.items():

        print(
            f"{timeframe}: "
            f"{candle_count} candles x 4 = "
            f"{candle_count * 4} features"
        )

    print(
        "\nTotal expected features:",
        len(feature_columns)
    )

    # ------------------------------------------
    # 3. VALIDATE DATABASE COLUMNS
    # ------------------------------------------

    missing_columns = [
        col
        for col in feature_columns
        if col not in df.columns
    ]

    if missing_columns:

        raise ValueError(
            "Missing feature columns:\n"
            + "\n".join(missing_columns)
        )

    if TARGET not in df.columns:

        raise ValueError(
            f"Missing target column: {TARGET}"
        )

    # ------------------------------------------
    # 4. EXTRACT ALL OHLC FEATURES
    # ------------------------------------------

    X_raw = df[feature_columns].copy()

    X_raw = X_raw.apply(
        pd.to_numeric,
        errors="coerce"
    )

    X_raw = X_raw.replace(
        [np.inf, -np.inf],
        np.nan
    )

    X_raw = X_raw.astype(np.float32)

    # ------------------------------------------
    # 5. EXTRACT TARGET
    # ------------------------------------------

    y_raw, valid = clean_labels(
        df[TARGET]
    )

    X = X_raw.loc[valid].copy()

    y = y_raw.loc[valid].copy()

    if len(y) < 2:

        print("Insufficient labeled training records.")

        return None

    # ------------------------------------------
    # 6. DATASET SUMMARY
    # ------------------------------------------

    print("\n========== DATASET SUMMARY ==========\n")

    print("Database:", TABLE_NAME)

    print("SQL filter: edited = 1")

    print("Total loaded rows:", len(df))

    print("Valid labeled rows:", len(y))

    print("Total features:", len(feature_columns))

    print("Target:", TARGET)

    print("\nTarget distribution:")

    print(y.value_counts())

    print("\nMissing OHLC values:")

    print(
        int(X.isna().sum().sum())
    )

    # ------------------------------------------
    # 7. SAVE FEATURE ORDER
    # ------------------------------------------

    feature_path = os.path.join(
        script_dir,
        "feature_columns.json"
    )

    with open(feature_path, "w") as f:

        json.dump(
            feature_columns,
            f,
            indent=4
        )

    # ------------------------------------------
    # 8. TRAIN DECISION MODEL
    # ------------------------------------------

    print(
        "\n========== TRAINING DECISION MODEL ==========\n"
    )

    model_data = train_model(
        TARGET,
        X,
        y
    )

    # ------------------------------------------
    # 9. EXPORT ONNX
    # ------------------------------------------

    print(
        "\n========== EXPORTING ONNX ==========\n"
    )

    export_model(
        TARGET,
        model_data,
        feature_columns,
        script_dir
    )

    # ------------------------------------------
    # 10. SAVE TRAINING RESULTS
    # ------------------------------------------

    results = {

        TARGET: {

            "accuracy": float(
                model_data["accuracy"]
            ),

            "training_rows": int(
                model_data["training_rows"]
            ),

            "features": len(feature_columns),

            "classes": model_data["classes"],

            "timeframes": TIMEFRAMES,

            "ohlc_columns": OHLC_COLUMNS,

            "target": TARGET,

            "filter": "edited = 1"
        }
    }

    results_path = os.path.join(
        script_dir,
        "training_results.json"
    )

    with open(results_path, "w") as f:

        json.dump(
            results,
            f,
            indent=4
        )

    # ------------------------------------------
    # 11. TRAINING SUMMARY
    # ------------------------------------------

    print(
        "\n========== TRAINING COMPLETE ==========\n"
    )

    print("Target:", TARGET)

    print(
        "Training rows:",
        model_data["training_rows"]
    )

    print(
        "Input features:",
        len(feature_columns)
    )

    print(
        "Classes:",
        model_data["classes"]
    )

    print(
        "OOF accuracy:",
        f"{model_data['accuracy']:.2%}"
    )

    print("\nGenerated files:")

    print(f"1. model_{TARGET}.onnx")

    print(f"2. classes_{TARGET}.json")

    print(f"3. features_{TARGET}.json")

    print("4. feature_columns.json")

    print("5. training_results.json")

    return pd.DataFrame(results).T


# --------------------------------------------------
# EXECUTION
# --------------------------------------------------

if __name__ == "__main__":

    train_models_and_export_onnx()
