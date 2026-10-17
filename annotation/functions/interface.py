import json

from django.shortcuts import render
from .fetchcandle import get_by_id_with_neighbors
from django.utils.html import format_html
from .train_key_zone import prediction

from .train_key_zone import train_key_zone



def echo(value):
    return format_html("<p>{}</p>", value)



def interface(request, candleid):
    train_key_zone()
    response = get_by_id_with_neighbors(request, candleid)
    records = json.loads(response.content)

    previous = records.get("previous")
    current = records.get("current")
    next_row = records.get("next")

    # ------------------------------------------------
    # BUILD CANDLE DATA
    # ------------------------------------------------

    def unflatten(row):
        if not row:
            return []

        return [
            {
                "number": i,
                "time": row.get(f"1min_raw_time_{i}"),
                "open": row.get(f"1min_raw_open_{i}"),
                "high": row.get(f"1min_raw_high_{i}"),
                "low": row.get(f"1min_raw_low_{i}"),
                "close": row.get(f"1min_raw_close_{i}"),
            }
            for i in range(1, 36)
        ]

    previous_candles = unflatten(previous)
    current_candles = unflatten(current)
    next_candles = unflatten(next_row)

    # ------------------------------------------------
    # ACTUAL MODEL PREDICTION
    # ------------------------------------------------

    try:
        prediction_values = prediction(candleid)
    except Exception as e:
        print(f"Prediction error for candle {candleid}: {e}")
        prediction_values = {}

        print(prediction_values)
    # ------------------------------------------------
    # RENDER TEMPLATE
    # ------------------------------------------------

    return render(
        request,
        "annotation/interface.html",
        {
            "previous": previous_candles,
            "current": current_candles,
            "next": next_candles,

            "previous_id": previous.get("id") if previous else None,
            "current_id": current.get("id") if current else None,
            "next_id": next_row.get("id") if next_row else None,

            # PREVIOUS
            "previous_analysis": previous.get("analysis", "") if previous else "",
            "previous_bias": previous.get("bias", "") if previous else "",
            "previous_phase": previous.get("phase", "") if previous else "",
            "previous_momentum": previous.get("momentum", "") if previous else "",
            "previous_decision": previous.get("decision", "") if previous else "",

            # CURRENT
            "current_analysis": current.get("analysis", "") if current else "",
            "current_bias": current.get("bias", "") if current else "",
            "current_phase": current.get("phase", "") if current else "",
            "current_momentum": current.get("momentum", "") if current else "",
            "current_decision": current.get("decision", "") if current else "",

            # EXISTING KEY ZONES
            **{
                f"key_zone_{level}_{i}": (
                    prediction_values.get(f"key_zone_{level}_{i}", 0.00)
                    if prediction_values else 0.00
                )
                for i in range(1, 5)
                for level in ("high", "low")
            },

            # **{
            #     f"key_zone_{level}_{i}": (
            #         current.get(f"key_zone_{level}_{i}", 0.00)
            #         if current else 0.00
            #     )
            #     for i in range(1, 5)
            #     for level in ("high", "low")
            # },
            # NEXT
            "next_analysis": next_row.get("analysis", "") if next_row else "",
            "next_bias": next_row.get("bias", "") if next_row else "",
            "next_phase": next_row.get("phase", "") if next_row else "",
            "next_momentum": next_row.get("momentum", "") if next_row else "",
            "next_decision": next_row.get("decision", "") if next_row else "",

            # ACTUAL MODEL PREDICTIONS
            "prediction_values": prediction_values,

            # Individual predicted values for the template
            **{
                f"prediction_{key}": value
                for key, value in prediction_values.items()
            },

            # STATUS
            "db_status": True,
        }
    )