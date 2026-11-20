
import mysql.connector
from mysql.connector import Error
from django.shortcuts import redirect

from .data.migratecsvtosql import extra_columns


def get_connection():
    try:
        return mysql.connector.connect(
            host="localhost",
            user="root",
            password="",
            database="marketdata",
        )
    except Error as e:
        print(f"Database connection error: {e}")
        return None


from django.http import JsonResponse
from django.views.decorators.http import require_POST
import json


@require_POST
def execute_sql(request):
    try:
        data = json.loads(request.body)

        query = data.get("query")
        params = data.get("params", [])

        if not query:
            return JsonResponse({
                "success": False,
                "message": "SQL query is required."
            }, status=400)

        result = sqlquery(query, params)

        if result is None:
            return JsonResponse({
                "success": False,
                "message": "SQL execution failed. Check Django terminal for the database error."
            }, status=500)

        return JsonResponse({
            "success": True,
            "data": result
        }, safe=False)

    except json.JSONDecodeError:
        return JsonResponse({
            "success": False,
            "message": "Invalid JSON."
        }, status=400)

    except Exception as e:
        return JsonResponse({
            "success": False,
            "message": str(e)
        }, status=500)



def sqlquery(query, params=None):
    connection = None
    cursor = None

    try:
        connection = get_connection()

        if connection is None or not connection.is_connected():
            raise Exception("Database connection failed.")

        cursor = connection.cursor(dictionary=True)
        cursor.execute(query, params or ())

        # SELECT queries
        if cursor.with_rows:
            return cursor.fetchall()

        # INSERT, UPDATE, DELETE queries
        connection.commit()

        return {
            "success": True,
            "affected_rows": cursor.rowcount,
            "lastrowid": cursor.lastrowid,
        }

    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()

        print(f"Database error: {e}")
        return None

    except Exception as e:
        print(f"Error: {e}")
        return None

    finally:
        if cursor:
            cursor.close()

        if connection and connection.is_connected():
            connection.close()


def execute_many(query, data):
    connection = None
    cursor = None

    try:
        connection = get_connection()

        if connection is None or not connection.is_connected():
            raise Exception("Database connection failed.")

        cursor = connection.cursor()
        cursor.executemany(query, data)
        connection.commit()

        return {
            "success": True,
            "affected_rows": cursor.rowcount,
        }

    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()

        print(f"Database error: {e}")
        return None

    except Exception as e:
        print(f"Error: {e}")
        return None

    finally:
        if cursor:
            cursor.close()

        if connection and connection.is_connected():
            connection.close()
