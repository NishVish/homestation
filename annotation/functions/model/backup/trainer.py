
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

BASE_TARGETS = [
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

SETUP_TARGET = "setup"
MOMENTUM_TARGET = "momentum_candle"
DECISION_TARGET = "decision"

ALL_TARGETS = (
    BASE_TARGETS
    + [SETUP_TARGET, MOMENTUM_TARGET, DECISION_TARGET]
)


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
# TRAIN MODEL AND GENERATE OUT-OF-FOLD PREDICTIONS
# --------------------------------------------------

def train_with_oof(target, X, y_raw):

    encoder = LabelEncoder()
    y = encoder.fit_transform(y_raw)

    if len(encoder.classes_) < 2:
        raise ValueError(
            f"{target}: requires at least two different classes."
        )

    model = create_model()

    class_counts = pd.Series(y).value_counts()

    min_class_count = int(class_counts.min())

    # OOF predictions prevent a downstream model from
    # simply learning perfect upstream training labels.

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

        accuracy = accuracy_score(y, oof_predictions)

        print(
            f"{target}: OOF accuracy = {accuracy:.2%}"
        )

    else:

        print(
            f"WARNING: {target} has a class with only one "
            "sample. Using in-sample predictions for OOF fallback."
        )

        model.fit(X, y)
        oof_predictions = model.predict(X)

        accuracy = accuracy_score(y, oof_predictions)

    # Train final model using all available labeled rows.

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
# GENERATE ONE-HOT PREDICTION FEATURES
# --------------------------------------------------

def add_prediction_features(
    X,
    target,
    predictions,
    classes
):

    X = X.copy()

    predictions = pd.Series(
        predictions,
        index=X.index
    )

    for class_name in classes:

        column_name = f"pred_{target}__{class_name}"

        X[column_name] = (
            predictions == class_name
        ).astype(np.float32)

    return X


# --------------------------------------------------
# EXPORT MODEL
# --------------------------------------------------

def export_model(target, model_data, feature_columns, script_dir):

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

    model_path = os.path.join(
        script_dir,
        f"model_{target}.onnx"
    )

    with open(model_path, "wb") as f:
        f.write(onnx_model.SerializeToString())

    # Save class mapping.

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

    # Save exact input feature order for inference.

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

    print(f"Exported: {model_path}")


# --------------------------------------------------
# MAIN TRAINING FUNCTION
# --------------------------------------------------

def train_models_and_export_onnx():

    print("\n========== START TRAINING ==========\n")

    script_dir = os.path.dirname(
        os.path.abspath(__file__)
    )

    # ------------------------------------------
    # 1. LOAD DATABASE
    # ------------------------------------------

    try:

        db = get_connection()
# make changes here that only take columns with of 1min timeframe....abs
        query = """
            SELECT *
            FROM labeled_flatdata
            WHERE edited = '1'
        """

        df = pd.read_sql(query, db)

        print("Loaded rows:", len(df))

    except Exception as e:

        print("Database error:", e)
        return None

    finally:

        if "db" in locals() and db.is_connected():
            db.close()

    if df.empty:
        print("No training data found.")
        return None

    # ------------------------------------------
    # 2. EXTRACT OHLC FEATURES
    # ------------------------------------------

    feature_columns = [
        col
        for col in df.columns
        if col.startswith("M1_")
        and not col.endswith("_time")
        and col.rsplit("_", 1)[-1]
        in {"open", "high", "low", "close"}
    ]

    if not feature_columns:
        print("No OHLC features found.")
        return None

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
    # 3. SAVE RAW FEATURE ORDER
    # ------------------------------------------

    with open(
        os.path.join(script_dir, "feature_columns.json"),
        "w"
    ) as f:

        json.dump(feature_columns, f, indent=4)

    models = {}
    results = {}

    # ------------------------------------------
    # 4. TRAIN FIRST 9 MODELS
    # ------------------------------------------

    print("\n========== STAGE 1 ==========\n")

    base_predictions = {}

    for target in BASE_TARGETS:

        if target not in df.columns:
            raise ValueError(
                f"Missing database column: {target}"
            )

        y_raw, valid = clean_labels(df[target])

        X_target = X_raw.loc[valid]
        y_target = y_raw.loc[valid]

        if len(y_target) < 2:
            raise ValueError(
                f"{target}: insufficient training rows."
            )

        print(
            f"\nTraining base model: {target}"
        )

        model_data = train_with_oof(
            target,
            X_target,
            y_target
        )

        models[target] = model_data

        # Generate predictions for all rows.
        # Labeled rows receive OOF predictions.
        # Rows without labels receive full-model predictions.

        all_predictions = pd.Series(
            model_data["encoder"].inverse_transform(
                model_data["model"].predict(
                    X_raw
                ).astype(int)
            ),
            index=df.index
        )

        all_predictions.loc[valid] = (
            model_data["oof_predictions"]
        )

        base_predictions[target] = all_predictions

        export_model(
            target,
            model_data,
            feature_columns,
            script_dir
        )

        results[target] = {
            "accuracy": model_data["accuracy"],
            "training_rows": model_data["training_rows"],
        }

    # ------------------------------------------
    # 5. BUILD STAGE 2 FEATURES
    # OHLC + FIRST 9 PREDICTIONS
    # ------------------------------------------

    print("\n========== STAGE 2: SETUP ==========\n")

    X_setup = X_raw.copy()

    for target in BASE_TARGETS:

        X_setup = add_prediction_features(
            X_setup,
            target,
            base_predictions[target],
            models[target]["classes"]
        )

    setup_values, setup_valid = clean_labels(
        df[SETUP_TARGET]
    )

    setup_model_data = train_with_oof(
        SETUP_TARGET,
        X_setup.loc[setup_valid],
        setup_values.loc[setup_valid]
    )

    models[SETUP_TARGET] = setup_model_data

    # OOF setup predictions for training subsequent models.

    setup_predictions = pd.Series(
        setup_model_data["encoder"].inverse_transform(
            setup_model_data["model"].predict(
                X_setup
            ).astype(int)
        ),
        index=df.index
    )

    setup_predictions.loc[setup_valid] = (
        setup_model_data["oof_predictions"]
    )

    export_model(
        SETUP_TARGET,
        setup_model_data,
        list(X_setup.columns),
        script_dir
    )

    results[SETUP_TARGET] = {
        "accuracy": setup_model_data["accuracy"],
        "training_rows": setup_model_data["training_rows"],
    }

    # ------------------------------------------
    # 6. BUILD STAGE 3 FEATURES
    # OHLC + FIRST 9 + SETUP
    # ------------------------------------------

    print(
        "\n========== STAGE 3: MOMENTUM CANDLE ==========\n"
    )

    X_momentum = X_setup.copy()

    X_momentum = add_prediction_features(
        X_momentum,
        SETUP_TARGET,
        setup_predictions,
        setup_model_data["classes"]
    )

    momentum_values, momentum_valid = clean_labels(
        df[MOMENTUM_TARGET]
    )

    momentum_model_data = train_with_oof(
        MOMENTUM_TARGET,
        X_momentum.loc[momentum_valid],
        momentum_values.loc[momentum_valid]
    )

    models[MOMENTUM_TARGET] = momentum_model_data

    momentum_predictions = pd.Series(
        momentum_model_data["encoder"].inverse_transform(
            momentum_model_data["model"].predict(
                X_momentum
            ).astype(int)
        ),
        index=df.index
    )

    momentum_predictions.loc[momentum_valid] = (
        momentum_model_data["oof_predictions"]
    )

    export_model(
        MOMENTUM_TARGET,
        momentum_model_data,
        list(X_momentum.columns),
        script_dir
    )

    results[MOMENTUM_TARGET] = {
        "accuracy": momentum_model_data["accuracy"],
        "training_rows": momentum_model_data["training_rows"],
    }

    # ------------------------------------------
    # 7. BUILD STAGE 4 FEATURES
    # OHLC + FIRST 9 + SETUP + MOMENTUM
    # ------------------------------------------

    print("\n========== STAGE 4: DECISION ==========\n")

    X_decision = X_momentum.copy()

    X_decision = add_prediction_features(
        X_decision,
        MOMENTUM_TARGET,
        momentum_predictions,
        momentum_model_data["classes"]
    )

    decision_values, decision_valid = clean_labels(
        df[DECISION_TARGET]
    )

    decision_model_data = train_with_oof(
        DECISION_TARGET,
        X_decision.loc[decision_valid],
        decision_values.loc[decision_valid]
    )

    models[DECISION_TARGET] = decision_model_data

    export_model(
        DECISION_TARGET,
        decision_model_data,
        list(X_decision.columns),
        script_dir
    )

    results[DECISION_TARGET] = {
        "accuracy": decision_model_data["accuracy"],
        "training_rows": decision_model_data["training_rows"],
    }

    # ------------------------------------------
    # 8. SAVE TRAINING SUMMARY
    # ------------------------------------------

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

    print("\n========== TRAINING COMPLETE ==========\n")

    results_df = pd.DataFrame(results).T

    print(results_df)

    return results_df


if __name__ == "__main__":
    train_models_and_export_onnx()
