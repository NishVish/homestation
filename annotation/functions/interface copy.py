
import json

from django.shortcuts import render
from django.utils.html import format_html

from .data.migratecsvtosql import extra_columns
from .fetchcandle import get_by_id_with_neighbors
from .model.trainer import train_models_and_export_onnx
from .model.prediction_function import prediction


def get_parameters():
    return extra_columns


def echo(value):
    return format_html("<p>{}</p>", value)


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

def unflatten(row, timeframe="1m"):

    if not row:
        return []

    timeframe_prefix = {
        "15m": "M15",
        "5m": "M5",
        "1m": "M1"
    }

    prefix = timeframe_prefix.get(timeframe)

    if prefix is None:
        raise ValueError(f"Unsupported timeframe: {timeframe}")

    candles = []

    # Automatically detect available candle numbers
    candle_numbers = sorted({
        int(col.split("_")[1])
        for col in row.keys()
        if col.startswith(prefix + "_")
        and col.split("_")[1].isdigit()
    })

    for i in candle_numbers:

        candles.append({
            "number": i,
            "time": row.get(f"{prefix}_{i:02d}_time"),
            "open": parse_value(row.get(f"{prefix}_{i:02d}_open")),
            "high": parse_value(row.get(f"{prefix}_{i:02d}_high")),
            "low": parse_value(row.get(f"{prefix}_{i:02d}_low")),
            "close": parse_value(row.get(f"{prefix}_{i:02d}_close")),
        })

    return candles


# ==================================================
# MAIN INTERFACE
# ==================================================

def interface(request, candleid):

    # train_models_and_export_onnx()

    # ------------------------------------------
    # 1. FETCH ALL THREE TIMEFRAMES
    # ------------------------------------------

    response_15m = get_by_id_with_neighbors(
        request, candleid, "15m"
    )

    response_5m = get_by_id_with_neighbors(
        request, candleid, "5m"
    )

    response_1m = get_by_id_with_neighbors(
        request, candleid, "1m"
    )

    # ------------------------------------------
    # 2. PARSE RESPONSES
    # ------------------------------------------

    records_15m = json.loads(response_15m.content)
    records_5m = json.loads(response_5m.content)
    records_1m = json.loads(response_1m.content)

    # Check for database errors
    for records in [records_15m, records_5m, records_1m]:

        if records.get("status") == "error":

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
                    "previous_15m": [],
                    "current_15m": [],
                    "next_15m": [],
                    "previous_5m": [],
                    "current_5m": [],
                    "next_5m": [],
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
            )

    # ------------------------------------------
    # 3. EXTRACT ROWS
    # ------------------------------------------

    previous_15m = records_15m.get("previous")
    current_15m = records_15m.get("current")
    next_15m = records_15m.get("next")

    previous_5m = records_5m.get("previous")
    current_5m = records_5m.get("current")
    next_5m = records_5m.get("next")

    previous_1m = records_1m.get("previous")
    current_1m = records_1m.get("current")
    next_1m = records_1m.get("next")

    # ------------------------------------------
    # 4. BUILD CANDLE DATA
    # ------------------------------------------

    # 15 MINUTES
    previous_candles_15m = unflatten(previous_15m, "15m")
    current_candles_15m = unflatten(current_15m, "15m")
    next_candles_15m = unflatten(next_15m, "15m")

    # 5 MINUTES
    previous_candles_5m = unflatten(previous_5m, "5m")
    current_candles_5m = unflatten(current_5m, "5m")
    next_candles_5m = unflatten(next_5m, "5m")

    # 1 MINUTE
    previous_candles_1m = unflatten(previous_1m, "1m")
    current_candles_1m = unflatten(current_1m, "1m")
    next_candles_1m = unflatten(next_1m, "1m")

    # ------------------------------------------
    # 5. PREDICTIONS FOR ALL TIMEFRAMES
    # ------------------------------------------

    prediction_values = {}

    # for timeframe in ["15m", "5m", "1m"]:
    for timeframe in ["5m", "1m"]:

        try:

            print(
                f"\n========== {timeframe} PREDICTION =========="
            )

            prediction_values[timeframe] = prediction(
                candleid,
                timeframe=timeframe
            ) or {}

        except Exception as e:

            print(
                f"Prediction error for {timeframe}: {e}"
            )

            prediction_values[timeframe] = {}

    # ------------------------------------------
    # 6. FORM PARAMETERS
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
    # 7. ANNOTATION FIELDS
    # ------------------------------------------

    annotation_fields = []

    # Use 1m data for annotation fields
    for column in form_parameter_names:

        if column == "id":
            continue

        annotation_fields.append({
            "name": column,
            "label": column.replace("_", " ").title(),
            "previous_value": previous_1m.get(column, "") if previous_1m else "",
            "current_value": current_1m.get(column, "") if current_1m else "",
            "next_value": next_1m.get(column, "") if next_1m else "",
        })

    # ------------------------------------------
    # 8. DEBUG
    # ------------------------------------------

    print("\n========== ALL TIMEFRAME PREDICTIONS ==========")

    print(json.dumps(
        prediction_values,
        indent=4,
        default=str
    ))

    # ------------------------------------------
    # 9. RENDER TEMPLATE
    # ------------------------------------------

    return render(
        request,
        "annotation/interface.html",
        {
            "form_parameters": form_parameters,
            "form_parameter_names": form_parameter_names,
            "annotation_fields": annotation_fields,

            # 15 MINUTE DATA
            "previous_15m": previous_candles_15m,
            "current_15m": current_candles_15m,
            "next_15m": next_candles_15m,

            # 5 MINUTE DATA
            "previous_5m": previous_candles_5m,
            "current_5m": current_candles_5m,
            "next_5m": next_candles_5m,

            # 1 MINUTE DATA
            "previous": previous_candles_1m,
            "current": current_candles_1m,
            "next": next_candles_1m,

            # ROW IDS
            "previous_id": previous_1m.get("id") if previous_1m else None,
            "current_id": current_1m.get("id") if current_1m else None,
            "next_id": next_1m.get("id") if next_1m else None,

            # ALL PREDICTIONS
            "prediction_values": prediction_values,

            "db_status": True,
        },
    )
