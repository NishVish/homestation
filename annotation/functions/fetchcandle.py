import mysql.connector
from mysql.connector import Error
from django.http import JsonResponse

def get_by_id_with_neighbors(request, id):
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
            return JsonResponse({"status": "error", "message": "Database connection failed."}, status=500)
        
        cursor = connection.cursor(dictionary=True)
        
        # 1. Fetch Current Row from the correct table
        cursor.execute("SELECT * FROM ml_1min_features WHERE id = %s", (id,))
        current_row = cursor.fetchone()
        
        if not current_row:
            return JsonResponse({"status": "error", "message": f"Record with id {id} not found."}, status=404)
        
        # 2. Fetch Previous Row
        cursor.execute("SELECT * FROM ml_1min_features WHERE id < %s ORDER BY id DESC LIMIT 1", (id,))
        previous_row = cursor.fetchone()
        
        # 3. Fetch Next Row
        cursor.execute("SELECT * FROM ml_1min_features WHERE id > %s ORDER BY id ASC LIMIT 1", (id,))
        next_row = cursor.fetchone()
        
    except Error as e:
        return JsonResponse({"status": "error", "message": str(e)}, status=500)
        
    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()
    
    return JsonResponse({
        "status": "success",
        "previous": previous_row if previous_row else None,
        "current": current_row,
        "next": next_row if next_row else None
    })