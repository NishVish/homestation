import os
import pandas as pd
from django.http import JsonResponse
from django.db import connection, transaction

# Path to your files
filespath = r"C:\Users\nishw\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\MQL5\Files"

def update_data(request):
    print("=== UPDATE DATA START ===")
    
    if not os.path.exists(filespath):
        return JsonResponse({"status": "error", "message": "Directory not found"}, status=404)

    try:
        files = os.listdir(filespath)
        print("FILES FOUND:", files)

        # 1. Use an atomic transaction block so data actually saves to the database
        with transaction.atomic():
            with connection.cursor() as cursor:
                
                # 2. Automatically detect placeholder style (%s for PostgreSQL/MySQL, ? for SQLite)
                db_engine = connection.settings_dict['ENGINE']
                placeholder = "?" if "sqlite" in db_engine else "%s"

                for f in files:
                    if not f.endswith(".csv"):
                        continue

                    path = os.path.join(filespath, f)
                    
                    # Read CSV and handle empty cells
                    df = pd.read_csv(path).fillna("")
                    table_name = os.path.splitext(f)[0]
                    cols = list(df.columns)

                    if not cols:
                        continue  

                    # Dynamically build and execute table creation
                    col_defs = ", ".join([f'"{c}" TEXT' for c in cols])
                    cursor.execute(f'CREATE TABLE IF NOT EXISTS "{table_name}" ({col_defs})')

                    # Prepare SQL strings
                    cols_sql = ", ".join([f'"{c}"' for c in cols])
                    placeholders = ", ".join([placeholder] * len(cols))
                    query = f'INSERT INTO "{table_name}" ({cols_sql}) VALUES ({placeholders})'

                    # 3. Optimize: Use executemany instead of a slow python loop for inserts
                    batch_data = []
                    for row in df.itertuples(index=False, name=None):
                        values = tuple("" if x is None else str(x) for x in row)
                        
                        if len(values) == len(cols):
                            batch_data.append(values)
                    
                    if batch_data:
                        cursor.executemany(query, batch_data)
                        print(f"Successfully inserted {len(batch_data)} rows into {table_name}")

        return JsonResponse({"status": "success", "message": "Data imported successfully"})

    except Exception as e:
        print(f"ERROR OCCURRED: {str(e)}")
        return JsonResponse({"status": "error", "message": str(e)}, status=500)