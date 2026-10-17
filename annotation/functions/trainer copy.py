
import os
import joblib
import mysql.connector
import pandas as pd

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression


# ============================================================
# MODEL PATH
# ============================================================

MODEL_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "market_model.pkl"
)


# ============================================================
# TARGET COLUMNS
# These are what the model has to predict
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
# GET TIME COLUMNS
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

    print("\nConnecting to MySQL...")

    db = get_db_connection()

    try:

        # ----------------------------------------------------
        # ONLY USE EDITED = 1 ROWS
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

    print("Training rows:", len(df))

    if len(df) == 0:

        raise ValueError(
            "No rows with edited = 1 found."
        )

    # ========================================================
    # FIND COLUMNS THAT MUST NOT BE USED AS INPUT
    # ========================================================

    remove_columns = [
        "id",
        "edited",
        "edittime"
    ]

    # Remove all time/date columns
    remove_columns.extend(
        get_time_columns(df.columns)
    )

    remove_columns = list(
        set(remove_columns)
    )

    # ========================================================
    # MARKET DATA INPUT COLUMNS
    #
    # Everything except:
    # ID
    # time
    # edited
    # edittime
    # target columns
    # ========================================================

    feature_columns = [
        column
        for column in df.columns
        if column not in remove_columns
        and column not in TARGET_COLUMNS
    ]

    print("\nInput columns:")

    for column in feature_columns:

        print("  ", column)

    print("\nTargets:")

    for target in TARGET_COLUMNS:

        print("  ", target)

    # ========================================================
    # CREATE INPUT TEXT
    #
    # Since your other market columns can also contain text,
    # convert the complete market-data row into text.
    # ========================================================

    X = df[feature_columns].copy()

    X = X.fillna("")

    X = X.astype(str)

    combined_text = X.apply(
        lambda row: " ".join(
            f"{column}: {row[column]}"
            for column in feature_columns
        ),
        axis=1
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
        # Remove empty target rows
        # ----------------------------------------------------

        valid = y.str.strip() != ""

        target_X = combined_text[valid]
        target_y = y[valid]

        if len(target_y) == 0:

            print(
                "Skipping",
                target,
                "- no data"
            )

            continue

        # ----------------------------------------------------
        # TF-IDF
        # ----------------------------------------------------

        vectorizer = TfidfVectorizer(
            lowercase=True,
            ngram_range=(1, 2),
            max_features=20000
        )

        X_vectorized = vectorizer.fit_transform(
            target_X
        )

        # ----------------------------------------------------
        # MODEL
        # ----------------------------------------------------

        model = LogisticRegression(
            max_iter=3000
        )

        model.fit(
            X_vectorized,
            target_y
        )

        # ----------------------------------------------------
        # SAVE
        # ----------------------------------------------------

        models[target] = {
            "model": model,
            "vectorizer": vectorizer
        }

        print(
            "Classes:",
            list(model.classes_)
        )

    # ========================================================
    # SAVE COMPLETE MODEL
    # ========================================================

    model_data = {
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
        len(df)
    )
    print(
        "Saved:",
        MODEL_PATH
    )

    return {
        "status": "success",
        "training_rows": len(df),
        "model_path": MODEL_PATH
    }


# ============================================================
# PREDICT
# ============================================================

def predict_model(data):

    # --------------------------------------------------------
    # Check model
    # --------------------------------------------------------

    if not os.path.exists(MODEL_PATH):

        raise FileNotFoundError(
            "Model does not exist. "
            "Train the model first."
        )

    # --------------------------------------------------------
    # Load model
    # --------------------------------------------------------

    model_data = joblib.load(
        MODEL_PATH
    )

    models = model_data["models"]
    feature_columns = model_data["feature_columns"]

    # --------------------------------------------------------
    # Convert input into DataFrame
    # --------------------------------------------------------

    if isinstance(data, dict):

        df = pd.DataFrame([data])

    elif isinstance(data, pd.DataFrame):

        df = data.copy()

    else:

        raise ValueError(
            "data must be a dictionary "
            "or pandas DataFrame."
        )

    # ========================================================
    # CHECK REQUIRED MARKET DATA
    # ========================================================

    missing_columns = [
        column
        for column in feature_columns
        if column not in df.columns
    ]

    if missing_columns:

        raise ValueError(
            "Missing columns: "
            + ", ".join(missing_columns)
        )

    # ========================================================
    # KEEP ONLY MARKET DATA
    # ========================================================

    df = df[
        feature_columns
    ].copy()

    df = df.fillna("")

    df = df.astype(str)

    # ========================================================
    # CREATE SAME TEXT FORMAT AS TRAINING
    # ========================================================

    combined_text = df.apply(
        lambda row: " ".join(
            f"{column}: {row[column]}"
            for column in feature_columns
        ),
        axis=1
    )

    # ========================================================
    # PREDICT
    # ========================================================

    result = {}

    for target in TARGET_COLUMNS:

        # Target wasn't trainable
        if target not in models:

            result[target] = None

            continue

        model = models[target]["model"]

        vectorizer = models[target]["vectorizer"]

        # ----------------------------------------------------
        # Transform input
        # ----------------------------------------------------

        X = vectorizer.transform(
            combined_text
        )

        # ----------------------------------------------------
        # Prediction
        # ----------------------------------------------------

        prediction = model.predict(
            X
        )[0]

        result[target] = prediction

    return result
