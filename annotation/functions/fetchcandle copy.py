
import mysql.connector
from mysql.connector import Error
from django.http import JsonResponse


def get_by_id_with_neighbors(request, id,timeframe ="1m"):
    connection = None
    cursor = None


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

        # Current row
        cursor.execute(
            "SELECT * FROM labeled_flatdata WHERE id = %s",
            (id,)
        )
        current_row = cursor.fetchone()

        if current_row is None:
            return JsonResponse({
                "status": "error",
                "message": f"Record with id {id} not found."
            }, status=404)

        # Previous row
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

        # Next row
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

        return JsonResponse({   
            "status": "success",
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
