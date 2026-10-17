
import mysql.connector


# ============================================================
# TARGET COLUMNS
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
# TRAIN MODEL
# ============================================================

def train_model():

    db = get_db_connection()

    try:

        cursor = db.cursor()

        cursor.execute(
            """
            SELECT COUNT(*)
            FROM `1min`
            WHERE edited = 1
            """
        )

        training_rows = cursor.fetchone()[0]

    finally:

        db.close()

    print(
        "Rows ready for training:",
        training_rows
    )

    return training_rows


# ============================================================
# PREDICTION
# ============================================================

def prediction(candle_id):

    db = get_db_connection()

    try:

        cursor = db.cursor(dictionary=True)

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

    if row is None:

        raise ValueError(
            f"Candle ID {candle_id} not found."
        )

    print("Prediction data:")
    # print(row)

    # --------------------------------------------------------
    # DUMMY PREDICTION FOR NOW
    # --------------------------------------------------------

    return {
        "analysis": "hello",
        "bias": "hello",
        "phase": "hello",
        "momentum": "hello"
    }

