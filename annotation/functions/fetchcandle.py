
from django.http import JsonResponse
from mysql.connector import Error
from django.shortcuts import redirect

from .sqlconnection import get_connection, close_connection


TIMEFRAME_PREFIXES = (
    "M1", "M5", "M15", "M30",
    "H1", "H4", "H8", "H12",
    "D1", "W1", "MN1",
)


def serialize_row(row):
    if row is None:
        return None

    return {
        key: value.isoformat() if hasattr(value, "isoformat") else value
        for key, value in row.items()
    }


def fetch_candle_by_date(request, date_str, time_str):
    connection = None
    cursor = None

    try:
        connection = get_connection()

        if connection is None:
            return JsonResponse({
                "status": "error",
                "message": "Database connection failed."
            }, status=500)

        cursor = connection.cursor(dictionary=True)

        # Match using H4_01_time, NOT snapshot_time.
        # Stored format: YYYY.MM.DD HH:MM

        cursor.execute(
            """
            SELECT id
            FROM labeled_flatdata
            WHERE STR_TO_DATE(H4_01_time, '%Y.%m.%d %H:%i') = %s
            ORDER BY id ASC
            LIMIT 1
            """,
            (f"{date_str} {time_str}",)
        )

        candle_row = cursor.fetchone()

        if candle_row is None:
            return JsonResponse({
                "status": "error",
                "message": f"No H4 candle found for {date_str} {time_str}."
            }, status=404)

        found_id = candle_row["id"]

    except Error as e:
        return JsonResponse({
            "status": "error",
            "message": str(e)
        }, status=500)

    except Exception as e:
        return JsonResponse({
            "status": "error",
            "message": str(e)
        }, status=500)

    finally:
        if cursor:
            cursor.close()

        if connection:
            close_connection(connection)


    return redirect(f"/annotation/interface/{found_id}/")

def get_by_id_with_neighbors(request, id, timeframe=None):
    connection = None
    cursor = None

    try:
        connection = get_connection()

        if connection is None:
            return JsonResponse({
                "status": "error",
                "message": "Database connection failed."
            }, status=500)

        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT *
            FROM labeled_flatdata
            WHERE id = %s
            LIMIT 1
            """,
            (id,)
        )

        current_row = cursor.fetchone()

        if current_row is None:
            return JsonResponse({
                "status": "error",
                "message": f"Record with id {id} not found."
            }, status=404)

        cursor.execute(
            """
            SELECT *
            FROM labeled_flatdata
            WHERE id < %s
            ORDER BY id DESC
            LIMIT 1
            """,
            (id,)
        )

        previous_row = cursor.fetchone()

        cursor.execute(
            """
            SELECT *
            FROM labeled_flatdata
            WHERE id > %s
            ORDER BY id ASC
            LIMIT 1
            """,
            (id,)
        )

        next_row = cursor.fetchone()

        available_timeframes = [
            prefix
            for prefix in TIMEFRAME_PREFIXES
            if any(
                column.startswith(prefix + "_")
                for column in current_row
            )
        ]

        return JsonResponse({
            "status": "success",
            "id": current_row["id"],
            "available_timeframes": available_timeframes,
            "previous": serialize_row(previous_row),
            "current": serialize_row(current_row),
            "next": serialize_row(next_row),
        })

    except Error as e:
        return JsonResponse({
            "status": "error",
            "message": str(e)
        }, status=500)

    except Exception as e:
        return JsonResponse({
            "status": "error",
            "message": str(e)
        }, status=500)

    finally:
        if cursor:
            cursor.close()

        if connection:
            close_connection(connection)
