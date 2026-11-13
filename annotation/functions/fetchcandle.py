
from django.http import JsonResponse

from mysql.connector import Error

from .sqlconnection import get_connection, close_connection


# Detect timeframes without querying database metadata.
TIMEFRAME_PREFIXES = (
    "M1",
    "M5",
    "M15",
    "M30",
    "H1",
    "H4",
    "H8",
    "H12",
    "D1",
    "W1",
    "MN1",
)


def serialize_row(row):

    if row is None:
        return None

    return {
        key: (
            value.isoformat()
            if hasattr(value, "isoformat")
            else value
        )
        for key, value in row.items()
    }


def get_by_id_with_neighbors(request, id, timeframe=None):

    connection = None
    cursor = None

    try:

        # -----------------------------------------
        # 1. DATABASE CONNECTION
        # -----------------------------------------

        connection = get_connection()

        if connection is None:
            return JsonResponse({
                "status": "error",
                "message": "Database connection failed."
            }, status=500)

        cursor = connection.cursor(dictionary=True)

        # -----------------------------------------
        # 2. FETCH CURRENT ROW
        # -----------------------------------------

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

        # -----------------------------------------
        # 3. FETCH PREVIOUS ROW
        # -----------------------------------------

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

        # -----------------------------------------
        # 4. FETCH NEXT ROW
        # -----------------------------------------

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

        # -----------------------------------------
        # 5. DETECT TIMEFRAMES FROM CURRENT ROW
        # -----------------------------------------

        available_timeframes = [
            prefix
            for prefix in TIMEFRAME_PREFIXES
            if any(
                column.startswith(prefix + "_")
                for column in current_row
            )
        ]

        # -----------------------------------------
        # 6. RETURN RESPONSE
        # -----------------------------------------

        return JsonResponse({

            "status": "success",

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
