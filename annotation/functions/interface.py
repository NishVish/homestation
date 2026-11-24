
import json

from django.shortcuts import render
from django.utils.html import format_html

from .data.migratecsvtosql import extra_columns
from .fetchcandle import get_by_id_with_neighbors
from .model.prediction_function import prediction
from .model.trainer import train_models_and_export_onnx


# ==================================================
# PARAMETERS
# ==================================================

def get_parameters():
    return extra_columns


def echo(value):
    return format_html("<p>{}</p>", value)


# ==================================================
# VALUE PARSER
# ==================================================

def parse_value(value):

    if value is None:
        return None

    try:

        parts = str(value).split("|", 1)

        if len(parts) == 2:
            return float(parts[1])

        return float(parts[0])

    except (ValueError, TypeError):
        return None


# ==================================================
# DYNAMIC UNFLATTEN
# ==================================================

def unflatten(row, prefix):

    if not row:
        return []

    candles = []

    candle_numbers = sorted({
        int(parts[1])
        for col in row.keys()
        if col.startswith(prefix + "_")
        for parts in [col.split("_")]
        if len(parts) >= 3 and parts[1].isdigit()
    })

    for i in candle_numbers:

        candle_key = f"{prefix}_{i:02d}_"

        candles.append({
            "number": i,
            "time": row.get(candle_key + "time"),
            "open": parse_value(row.get(candle_key + "open")),
            "high": parse_value(row.get(candle_key + "high")),
            "low": parse_value(row.get(candle_key + "low")),
            "close": parse_value(row.get(candle_key + "close")),
        })

    return candles


# ==================================================
# DYNAMIC TIMEFRAME DETECTION
# ==================================================

def detect_timeframes(records):

    if not records:
        return []

    current = records.get("current")

    if not current:
        return []

    prefixes = (
        "M1", "M5", "M15", "M30",
        "H1", "H4", "H8", "H12",
        "D1", "W1", "MN1",
    )

    available = []

    for prefix in prefixes:

        if any(
            col.startswith(prefix + "_")
            for col in current.keys()
        ):
            available.append(prefix)

    return available


# ==================================================
# MAIN INTERFACE
# ==================================================

def interface(request, candleid):

    # training_result = train_models_and_export_onnx()

    # prediction_result = prediction(candleid)

    # print("\n========== Prediction  training_result ==========")
    # print(training_result)

    # print("\n========== Prediction  RESULT ==========")
    # print(prediction_result)

    # ------------------------------------------
    # 1. FETCH ALL DATA ONCE
    # ------------------------------------------

    response = get_by_id_with_neighbors(
        request,
        candleid
    )

    records = json.loads(response.content)

    # ------------------------------------------
    # 2. CHECK DATABASE STATUS
    # ------------------------------------------

    if response.status_code != 200 or records.get("status") != "success":

        return render(
            request,
            "annotation/interface.html",
            {
                "db_status": False,
                "error": records.get(
                    "message",
                    "Unable to fetch candle data."
                ),
                "previous": [],
                "current": [],
                "next": [],
                "timeframe_data": {},
                "available_timeframes": [],
                "prediction_values": {},
                "form_parameters": extra_columns,
                "form_parameter_names": [
                    "id",
                    *[
                        name
                        for name in extra_columns
                        if not name.startswith("key_zone_")
                    ],
                ],
                "annotation_fields": [],
            },
            status=200,
        )

    # ------------------------------------------
    # 3. EXTRACT ROWS
    # ------------------------------------------

    previous_row = records.get("previous")
    current_row = records.get("current")
    next_row = records.get("next")

    # ------------------------------------------
    # 4. DETECT AVAILABLE TIMEFRAMES
    # ------------------------------------------

    available_timeframes = detect_timeframes(records)

    print("\n========== AVAILABLE TIMEFRAMES ==========")
    print(available_timeframes)

    # ------------------------------------------
    # 5. BUILD ALL TIMEFRAME CANDLE DATA
    # ------------------------------------------

    timeframe_data = {}

    for prefix in available_timeframes:

        timeframe = prefix.lower()

        timeframe_data[timeframe] = {

            "prefix": prefix,

            "previous": unflatten(
                previous_row,
                prefix
            ),

            "current": unflatten(
                current_row,
                prefix
            ),

            "next": unflatten(
                next_row,
                prefix
            ),
        }


    # ------------------------------------------
    # 6. DUMMY PREDICTIONS FOR ALL TIMEFRAMES
    # ------------------------------------------

    # prediction_values = {}

    # for timeframe in timeframe_data.keys():

    #     try:

    #         print(
    #             f"\n========== {timeframe} DUMMY PREDICTION =========="
    #         )

    #         prediction_values[timeframe] = dummy_prediction(
    #             candleid,
    #             timeframe
    #         )

    #     except Exception as e:

    #         print(
    #             f"Dummy prediction error for {timeframe}: {e}"
    #         )

    #         prediction_values[timeframe] = {}

            
    # ------------------------------------------
    # 6. PREDICTIONS FOR ALL TIMEFRAMES
    # ------------------------------------------

    # prediction_values = {}

    # for timeframe in timeframe_data.keys():

    #     try:

    #         print(
    #             f"\n========== {timeframe} PREDICTION =========="
    #         )

    #         prediction_values[timeframe] = prediction(
    #             candleid,
    #             timeframe=timeframe
    #         ) or {}

    #     except Exception as e:

    #         print(
    #             f"Prediction error for {timeframe}: {e}"
    #         )

    #         prediction_values[timeframe] = {}

    # ------------------------------------------
    # 7. FORM PARAMETERS
    # ------------------------------------------

    form_parameters = extra_columns

    form_parameter_names = [
        "id",
        *[
            name
            for name in extra_columns
            if not name.startswith("key_zone_")
            and name not in ("edited", "edittime")
        ],
    ]

    # ------------------------------------------
    # 8. ANNOTATION FIELDS
    # ------------------------------------------

    annotation_fields = []

    for column in form_parameter_names:

        if column == "id":
            continue

        annotation_fields.append({

            "name": column,

            "label": column.replace(
                "_", " "
            ).title(),

            "previous_value": (
                previous_row.get(column, "")
                if previous_row else ""
            ),

            "current_value": (
                current_row.get(column, "")
                if current_row else ""
            ),

            "next_value": (
                next_row.get(column, "")
                if next_row else ""
            ),
        })

    # ------------------------------------------
    # 9. BACKWARD COMPATIBILITY - M1
    # ------------------------------------------

    m1_data = timeframe_data.get("m1", {})

    previous_1m = m1_data.get("previous", [])
    current_1m = m1_data.get("current", [])
    next_1m = m1_data.get("next", [])

    # ------------------------------------------
    # 10. DEBUG
    # ------------------------------------------

    print("\n========== ALL TIMEFRAME PREDICTIONS ==========")

    # print(json.dumps(
    #     prediction_values,
    #     indent=4,
    #     default=str
    # ))
    # print(timeframe_data)
    h4_time = timeframe_data["h4"]["current"][-1]["time"]
    print(h4_time)
    # ------------------------------------------
    # 11. RENDER TEMPLATE
    # ------------------------------------------

    previous_decision = ""

    if previous_row:

        previous_decision = str(
            previous_row.get("decision") or ""
        ).strip().lower()

    training_result = None

    if previous_decision in ("buy", "sell"):

        print(
            "\n========== PREVIOUS DECISION:",
            previous_decision,
            "=========="
        )

        print("\n========== START MODEL TRAINING ==========")

        # training_result = train_models_and_export_onnx()

        print("\n========== TRAINING RESULT ==========")
        print(training_result)

    else:

        print(
            "\n========== TRAINING SKIPPED =========="
        )

        print(
            "Previous decision:",
            previous_decision or "EMPTY"
        )


    prediction_result = prediction(candleid)

    # Decision
    predicted_decision = prediction_result.get("decision")

    # Decision probabilities
    decision_probabilities = prediction_result.get(
        "probabilities", {}
    )

    # Highest probability class
    highest_decision = max(
        decision_probabilities,
        key=decision_probabilities.get
    ) if decision_probabilities else None

    highest_decision_probability = (
        decision_probabilities[highest_decision]
        if highest_decision else None
    )

    print("Predicted Decision:", predicted_decision)
    print("Highest Probability Decision:", highest_decision)
    print("Highest Decision Probability:", highest_decision_probability)

        
    return render(
        request,
        "annotation/interface.html",
        {
            #Prediction 
            "predicted_decision": predicted_decision,
            # FORM
            "form_parameters": form_parameters,
            "form_parameter_names": form_parameter_names,
            "annotation_fields": annotation_fields,

            # DYNAMIC TIMEFRAMES
            "available_timeframes": [
                tf.lower()
                for tf in available_timeframes
            ],

            "timeframe_data": timeframe_data,
            "timeoflastcandle":h4_time,

            # BACKWARD COMPATIBILITY - M1
            "previous": previous_1m,
            "current": current_1m,
            "next": next_1m,

            # ROW IDS
            "previous_id": (
                previous_row.get("id")
                if previous_row else None
            ),

            "current_id": (
                current_row.get("id")
                if current_row else None
            ),

            "next_id": (
                next_row.get("id")
                if next_row else None
            ),

            # PREDICTIONS
            # "prediction_values": prediction_values,

            # STATUS
            "db_status": True,
        },
    )


def dummy_prediction(candleid, timeframe):

    return {
        "prediction": "BUY",
        "confidence": 85.5,
        "timeframe": timeframe,
        "candleid": candleid,
        "target": 1.08500,
        "stop_loss": 1.07800,
        "entry_price": 1.08100,
        "status": "dummy"
    }