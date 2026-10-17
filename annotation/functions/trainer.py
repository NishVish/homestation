
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
    "market_model.pkl"
)


# ============================================================
# TARGET COLUMNS
# These are what the model predicts
# ============================================================

TARGET_COLUMNS = [
    "analysis",
    "bias",
    "phase",
    "momentum"
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
# TRAIN MODEL
# ============================================================

def train_model():

    print("\nStarting training...")

    db = get_db_connection()

    try:

        # ----------------------------------------------------
        # ONLY COMPLETED / ANNOTATED ROWS
        # ----------------------------------------------------

        df = pd.read_sql(
            """
            SELECT *
            FROM `1min`
            WHERE edited = 1
            """,
            db
        )

    finally:

        db.close()

    training_rows = len(df)

    print(
        "Rows ready for training:",
        training_rows
    )

    if training_rows == 0:

        raise ValueError(
            "No rows with edited = 1."
        )

    # ========================================================
    # REMOVE NON-MODEL COLUMNS
    # ========================================================

    remove_columns = [
        "id",
        "edited",
        "edittime"
    ]

    # Remove every time/date column
    remove_columns.extend(
        get_time_columns(df.columns)
    )

    remove_columns = set(
        remove_columns
    )

    # ========================================================
    # INPUT FEATURES
    #
    # Everything except:
    # - ID
    # - time
    # - edited
    # - edittime
    # - prediction targets
    # ========================================================

    feature_columns = [
        column
        for column in df.columns
        if column not in remove_columns
        and column not in TARGET_COLUMNS
    ]

    print("\nFeatures:")

    for column in feature_columns:

        print(" ", column)

    # ========================================================
    # CREATE TEXT REPRESENTATION OF EACH CANDLE
    # ========================================================

    X = df[feature_columns].copy()

    X = X.fillna("")

    X = X.astype(str)

    combined_text = X.apply(
        lambda row: " ".join(
            f"{column}={row[column]}"
            for column in feature_columns
        ),
        axis=1
    )

    # ========================================================
    # TF-IDF
    # ========================================================

    vectorizer = TfidfVectorizer(
        lowercase=True,
        ngram_range=(1, 2),
        max_features=30000
    )

    X_vectorized = vectorizer.fit_transform(
        combined_text
    )

    # ========================================================
    # TRAIN ONE MODEL FOR EACH TARGET
    # ========================================================

    models = {}

    for target in TARGET_COLUMNS:

        print(
            "\nTraining:",
            target
        )

        y = df[target].fillna("").astype(str)

        # ----------------------------------------------------
        # Remove rows with empty target
        # ----------------------------------------------------

        valid = (y.str.strip() != "").to_numpy()

        target_X = X_vectorized[valid]
        target_y = y.iloc[valid]

        if len(target_y) == 0:

            print(
                "No values for:",
                target
            )

            continue

        # ----------------------------------------------------
        # 1-nearest-neighbor
        #
        # Works even with only ONE training row.
        # ----------------------------------------------------

        model = KNeighborsClassifier(
            n_neighbors=1,
            metric="cosine"
        )

        model.fit(
            target_X,
            target_y
        )

        models[target] = model

        print(
            "Training examples:",
            len(target_y)
        )

        print(
            "Unique values:",
            target_y.nunique()
        )

    # ========================================================
    # SAVE MODEL
    # ========================================================

    model_data = {
        "vectorizer": vectorizer,
        "models": models,
        "feature_columns": feature_columns,
        "targets": TARGET_COLUMNS
    }

    joblib.dump(
        model_data,
        MODEL_PATH
    )

    print("\n===================================")
    print("MODEL TRAINED")
    print("===================================")
    print(
        "Training rows:",
        training_rows
    )
    print(
        "Model saved:",
        MODEL_PATH
    )

    return {
        "status": "success",
        "training_rows": training_rows,
        "model_path": MODEL_PATH
    }


# ============================================================
# PREDICTION
# ============================================================

def prediction(candle_id):

    # ========================================================
    # LOAD MODEL
    # ========================================================

    if not os.path.exists(MODEL_PATH):

        raise FileNotFoundError(
            "Model does not exist. "
            "Run train_model() first."
        )

    model_data = joblib.load(
        MODEL_PATH
    )

    vectorizer = model_data["vectorizer"]

    models = model_data["models"]

    feature_columns = model_data["feature_columns"]

    # ========================================================
    # GET CANDLE FROM MYSQL
    # ========================================================

    db = get_db_connection()

    try:

        cursor = db.cursor(
            dictionary=True
        )

        cursor.execute(
            """
            SELECT *
            FROM `1min`
            WHERE id = %s
            """,
            (candle_id,)
        )

        row = cursor.fetchone()

    finally:

        db.close()

    # ========================================================
    # CHECK CANDLE
    # ========================================================

    if row is None:

        raise ValueError(
            f"Candle ID {candle_id} not found."
        )

    print(
        "\nPredicting candle:",
        candle_id
    )

    # ========================================================
    # ONLY USE MODEL FEATURES
    # ========================================================

    data = {}

    for column in feature_columns:

        data[column] = row.get(
            column,
            ""
        )

    # ========================================================
    # CREATE SAME TEXT FORMAT USED DURING TRAINING
    # ========================================================

    input_text = " ".join(
        f"{column}={str(data[column])}"
        for column in feature_columns
    )

    # ========================================================
    # TF-IDF TRANSFORMATION
    # ========================================================

    X = vectorizer.transform(
        [input_text]
    )

    # ========================================================
    # PREDICT ALL FOUR TARGETS
    # ========================================================

    result = {}

    for target in TARGET_COLUMNS:

        if target not in models:

            result[target] = ""

            continue

        model = models[target]

        prediction_value = model.predict(
            X
        )[0]

        result[target] = prediction_value

    # ========================================================
    # RETURN
    # ========================================================

    print(
        "Prediction:",
        result
    )

    return result
