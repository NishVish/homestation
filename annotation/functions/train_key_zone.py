import os
import joblib
import mysql.connector
import pandas as pd

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.neighbors import KNeighborsClassifier


# ============================================================
# MODEL PATH
# ============================================================

MODEL_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "model_key_zone.pkl"
)


# ============================================================
# TARGET COLUMNS
# ============================================================

TARGET_COLUMNS = [
    "key_zone_high_1",
    "key_zone_low_1",
    "key_zone_high_2",
    "key_zone_low_2",
    "key_zone_high_3",
    "key_zone_low_3",
    "key_zone_high_4",
    "key_zone_low_4",
]


# ============================================================
# DATABASE CONNECTION
# ============================================================

def get_db_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="marketdata"
    )


# ============================================================
# FIND TIME COLUMNS
# ============================================================

def get_time_columns(columns):
    time_columns = []

    for column in columns:
        name = column.lower()

        if (
            "time" in name
            or "date" in name
            or "timestamp" in name
        ):
            time_columns.append(column)

    return time_columns


# ============================================================
# BUILD INPUT TEXT
# ============================================================

def build_text(row, feature_columns):
    return " ".join(
        f"{column}={row[column]}"
        for column in feature_columns
    )


# ============================================================
# TRAIN MODEL
# ============================================================

def train_key_zone():

    print("\nStarting key-zone training...")

    db = get_db_connection()

    try:
        df = pd.read_sql(
            """
            SELECT *
            FROM `ml_1min_features`
            WHERE edited = 1
            """,
            db
        )
    finally:
        db.close()

    training_rows = len(df)

    print("Annotated rows:", training_rows)

    if training_rows == 0:
        raise ValueError(
            "No training rows found. "
            "Set edited = 1 for annotated rows."
        )

    # --------------------------------------------------------
    # VERIFY TARGET COLUMNS
    # --------------------------------------------------------

    missing_targets = [
        column
        for column in TARGET_COLUMNS
        if column not in df.columns
    ]

    if missing_targets:
        raise ValueError(
            f"Missing target columns in ml_1min_features: "
            f"{missing_targets}"
        )

    # --------------------------------------------------------
    # REMOVE NON-FEATURE COLUMNS
    # --------------------------------------------------------

    remove_columns = {
        "id",
        "edited",
        "edittime",
        "analysis",
        "bias",
        "phase",
        "momentum",
        "decision",
    }

    remove_columns.update(
        get_time_columns(df.columns)
    )

    # Targets must never be input features.
    feature_columns = [
        column
        for column in df.columns
        if column not in remove_columns
        and column not in TARGET_COLUMNS
    ]

    if not feature_columns:
        raise ValueError("No input feature columns found.")

    print("\nInput features:")

    for column in feature_columns:
        print(" ", column)

    # --------------------------------------------------------
    # BUILD TEXT FEATURES
    # --------------------------------------------------------

    X = df[feature_columns].copy()

    X = X.fillna("")
    X = X.astype(str)

    combined_text = X.apply(
        lambda row: build_text(row, feature_columns),
        axis=1
    )

    # --------------------------------------------------------
    # TF-IDF
    # --------------------------------------------------------

    vectorizer = TfidfVectorizer(
        lowercase=True,
        ngram_range=(1, 2),
        max_features=30000
    )

    X_vectorized = vectorizer.fit_transform(
        combined_text
    )

    # --------------------------------------------------------
    # TRAIN A MODEL FOR EACH TARGET
    # --------------------------------------------------------

    models = {}

    for target in TARGET_COLUMNS:

        print(f"\nTraining target: {target}")

        # Key-zone values are numeric regression targets.
        # KNN classification would treat every price as a class.
        y = pd.to_numeric(
            df[target],
            errors="coerce"
        )

        valid = y.notna()

        target_X = X_vectorized[valid.to_numpy()]
        target_y = y.loc[valid].to_numpy()

        if len(target_y) == 0:
            print(f"No numeric values for {target}; skipped.")
            continue

        # ----------------------------------------------------
        # KNN REGRESSION FOR PRICE VALUES
        # ----------------------------------------------------

        from sklearn.neighbors import KNeighborsRegressor

        model = KNeighborsRegressor(
            n_neighbors=min(3, len(target_y)),
            weights="distance",
            metric="cosine",
            algorithm="brute"
        )

        model.fit(
            target_X,
            target_y
        )

        models[target] = model

        print("Training examples:", len(target_y))
        print("Unique numeric values:", len(set(target_y)))

    # --------------------------------------------------------
    # SAVE MODEL
    # --------------------------------------------------------

    model_data = {
        "vectorizer": vectorizer,
        "models": models,
        "feature_columns": feature_columns,
        "targets": TARGET_COLUMNS,
    }

    joblib.dump(
        model_data,
        MODEL_PATH
    )

    print("\n===================================")
    print("KEY-ZONE MODEL TRAINED")
    print("===================================")
    print("Training rows:", training_rows)
    print("Models trained:", len(models))
    print("Model saved:", MODEL_PATH)

    return {
        "status": "success",
        "training_rows": training_rows,
        "models_trained": len(models),
        "model_path": MODEL_PATH,
    }


# ============================================================
# PREDICTION
# ============================================================

def prediction(candle_id):

    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(
            "Model does not exist. Run train_levels() first."
        )

    model_data = joblib.load(MODEL_PATH)

    vectorizer = model_data["vectorizer"]
    models = model_data["models"]
    feature_columns = model_data["feature_columns"]
    targets = model_data["targets"]

    # --------------------------------------------------------
    # FETCH CANDLE
    # --------------------------------------------------------

    db = get_db_connection()

    try:
        cursor = db.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT *
            FROM `ml_1min_features`
            WHERE id = %s
            """,
            (candle_id,)
        )

        row = cursor.fetchone()

        cursor.close()

    finally:
        db.close()

    if row is None:
        raise ValueError(
            f"Candle ID {candle_id} not found."
        )

    print(f"\nPredicting key zones for candle {candle_id}")

    # --------------------------------------------------------
    # BUILD INPUT USING SAME FEATURES AS TRAINING
    # --------------------------------------------------------

    # data = {
    #     column: (
    #         ""
    #         if row.get(column) is None
    #         else str(row[column])
    #     )
    #     for column in feature_columns
    # }

    # input_text = build_text(
    #     data,
    #     feature_columns
    # )

    # X = vectorizer.transform([input_text])

    # # --------------------------------------------------------
    # # PREDICT ALL TARGETS
    # # --------------------------------------------------------

    # result = {}

    # for target in targets:

    #     if target not in models:
    #         result[target] = None
    #         continue

    #     predicted_value = models[target].predict(X)[0]

    #     result[target] = round(float(predicted_value), 4)

    print("Prediction:", result)

  
    result = {'key_zone_high_1': 0.6667, 'key_zone_low_1': 0.4733, 'key_zone_high_2': 1.8833, 'key_zone_low_2': 1.7233, 'key_zone_high_3': 0.0, 'key_zone_low_3': 0.0, 'key_zone_high_4': 0.0, 'key_zone_low_4': 0.0}

    return result