
import mysql.connector
from mysql.connector import Error
from django.http import JsonResponse


def get_by_id_with_neighbors(request, id, timeframe="1m"):

    connection = None
    cursor = None

    timeframe_prefix = {
        "15m": "M15",
        "5m": "M5",
        "1m": "M1"
    }

    if timeframe not in timeframe_prefix:
        return JsonResponse({
            "status": "error",
            "message": f"Unsupported timeframe: {timeframe}"
        }, status=400)

    prefix = timeframe_prefix[timeframe]

    try:

        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",
            database="marketdata"
        )

        if not connection.is_connected():
            return JsonResponse({
                "status": "error",
                "message": "Database connection failed."
            }, status=500)

        cursor = connection.cursor(dictionary=True)

        # ------------------------------------------
        # 1. GET ALL COLUMN NAMES
        # ------------------------------------------

        cursor.execute("""
            SHOW COLUMNS FROM labeled_flatdata
        """)

        all_columns = [
            row["Field"]
            for row in cursor.fetchall()
        ]

        # ------------------------------------------
        # 2. FILTER COLUMNS BY TIMEFRAME
        # ------------------------------------------

        selected_columns = [
            col for col in all_columns
            if not (
                col.startswith("M1_")
                or col.startswith("M5_")
                or col.startswith("M15_")
            )
            or col.startswith(prefix + "_")
        ]

        # Always include ID
        if "id" not in selected_columns:
            selected_columns.insert(0, "id")

        # Escape column identifiers
        columns_sql = ", ".join(
            f"`{col}`" for col in selected_columns
        )

        # ------------------------------------------
        # 3. CURRENT ROW
        # ------------------------------------------

        cursor.execute(
            f"""
            SELECT {columns_sql}
            FROM labeled_flatdata
            WHERE id = %s
            """,
            (id,)
        )

        current_row = cursor.fetchone()

        if current_row is None:
            return JsonResponse({
                "status": "error",
                "message": f"Record with id {id} not found."
            }, status=404)

        # ------------------------------------------
        # 4. PREVIOUS ROW
        # ------------------------------------------

        cursor.execute(
            f"""
            SELECT {columns_sql}
            FROM labeled_flatdata
            WHERE id < %s
            ORDER BY id DESC
            LIMIT 1
            """,
            (id,)
        )

        previous_row = cursor.fetchone()

        # ------------------------------------------
        # 5. NEXT ROW
        # ------------------------------------------

        cursor.execute(
            f"""
            SELECT {columns_sql}
            FROM labeled_flatdata
            WHERE id > %s
            ORDER BY id ASC
            LIMIT 1
            """,
            (id,)
        )

        next_row = cursor.fetchone()

        # ------------------------------------------
        # 6. RESPONSE
        # ------------------------------------------

        return JsonResponse({
            "status": "success",
            "timeframe": timeframe,
            "previous": previous_row,
            "current": current_row,
            "next": next_row
        }, json_dumps_params={"default": str})

    except Error as e:

        return JsonResponse({
            "status": "error",
            "message": str(e)
        }, status=500)

    finally:

        if cursor:
            cursor.close()

        if connection and connection.is_connected():
            connection.close()
