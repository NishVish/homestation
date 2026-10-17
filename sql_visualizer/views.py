from django.http import JsonResponse
from django.db import connection


def index(request):
    result = {
        "database": connection.settings_dict["NAME"],
        "tables": {},
    }

    with connection.cursor() as cursor:
        cursor.execute("SHOW TABLES")
        tables = [row[0] for row in cursor.fetchall()]

        for table_name in tables:
            cursor.execute(f"DESCRIBE `{table_name}`")
            columns = cursor.fetchall()

            result["tables"][table_name] = {
                "columns": [
                    {
                        "field": row[0],
                        "type": row[1],
                        "null": row[2],
                        "key": row[3],
                        "default": row[4],
                        "extra": row[5],
                    }
                    for row in columns
                ]
            }

    return JsonResponse(result)