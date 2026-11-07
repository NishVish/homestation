
import os
import math
import pandas as pd

from django.http import JsonResponse
from .sqlconnection import get_connection, close_connection


# Additional columns required in the migrated table.
# Defined outside the function so it can be reused in this module.
extra_columns = {
    "high_direction": "VARCHAR(100) NULL",
    "high_bias": "VARCHAR(100) NULL",
    "high_phase": "VARCHAR(100) NULL",
    "high_volatility": "VARCHAR(50) NULL",
    "high_momentum_direction": "VARCHAR(100) NULL",
    "high_momentum_strength": "VARCHAR(100) NULL",
    "high_setup": "VARCHAR(100) NULL",
    "high_entry_candle": "VARCHAR(100) NULL",
    "high_decision": "VARCHAR(100) NULL",

    "low_direction": "VARCHAR(100) NULL",
    "low_bias": "VARCHAR(100) NULL",
    "low_phase": "VARCHAR(100) NULL",
    "low_volatility": "VARCHAR(50) NULL",
    "low_momentum_direction": "VARCHAR(100) NULL",
    "low_momentum_strength": "VARCHAR(100) NULL",
    "low_setup": "VARCHAR(100) NULL",
    "low_entry_candle": "VARCHAR(100) NULL",
    "low_decision": "VARCHAR(100) NULL",

    "edited": "TINYINT(1) NOT NULL DEFAULT 0",
    "edittime": "DATETIME NULL",
}

def migrate_data(request):
    file_path = (
        r"C:\Users\nishw\AppData\Roaming\MetaQuotes\Tester"
        r"\D0E8209F77C8CF37AD8BF550E51FF075"
        r"\Agent-127.0.0.1-3000\MQL5\Files\labeled_flatdata.csv"
    )

    connection = None
    cursor = None
    table_name = "labeled_flatdata"
    quoted_table = f"`{table_name}`"

    try:
        # 1. Check whether the CSV file exists.
        if not os.path.isfile(file_path):
            return JsonResponse({
                "success": False,
                "error": f"CSV file not found: {file_path}",
            }, status=404)

        # 2. Read the CSV.
        df = pd.read_csv(file_path)

        if df.empty:
            return JsonResponse({
                "success": False,
                "message": "CSV file contains no data rows.",
                "filename": os.path.basename(file_path),
            }, status=400)

        # 3. Normalize CSV column names.
        df.columns = [
            str(col).strip().replace(" ", "_")
            for col in df.columns
        ]

        if any(not col for col in df.columns):
            return JsonResponse({
                "success": False,
                "error": "CSV contains an empty column name.",
            }, status=400)

        if len(set(df.columns)) != len(df.columns):
            return JsonResponse({
                "success": False,
                "error": (
                    "CSV contains duplicate column names "
                    "after normalization."
                ),
            }, status=400)

        # Extra columns already present in the CSV are not
        # added a second time.
        duplicate_extra = set(df.columns) & set(extra_columns)

        # 4. Connect to MySQL/MariaDB.
        connection = get_connection()

        if connection is None:
            return JsonResponse({
                "success": False,
                "error": "Could not connect to MySQL database.",
            }, status=500)

        cursor = connection.cursor()

        # 5. Infer SQL types for CSV columns.
        column_definitions = []

        for col in df.columns:
            dtype = df[col].dtype

            if pd.api.types.is_bool_dtype(dtype):
                sql_type = "TINYINT(1)"
            elif pd.api.types.is_integer_dtype(dtype):
                sql_type = "BIGINT"
            elif pd.api.types.is_float_dtype(dtype):
                sql_type = "DOUBLE"
            else:
                sql_type = "LONGTEXT"

            safe_col = f"`{col.replace('`', '``')}`"

            column_definitions.append(
                f"{safe_col} {sql_type} NULL"
            )

        # 6. Add extra columns missing from the CSV.
        for col, sql_type in extra_columns.items():
            if col not in df.columns:
                safe_col = f"`{col.replace('`', '``')}`"
                column_definitions.append(
                    f"{safe_col} {sql_type}"
                )

        # 7. Drop the existing table.
        # WARNING: This permanently deletes the old table and its data.
        cursor.execute(
            f"DROP TABLE IF EXISTS {quoted_table}"
        )

        # 8. Create the new table.
        cursor.execute(
            f"CREATE TABLE {quoted_table} ("
            + ", ".join(column_definitions)
            + ") ENGINE=InnoDB"
        )

        # 9. Prepare the CSV insert statement.
        csv_columns_sql = ", ".join(
            f"`{col.replace('`', '``')}`"
            for col in df.columns
        )

        placeholders = ", ".join(
            ["%s"] * len(df.columns)
        )

        insert_sql = (
            f"INSERT INTO {quoted_table} "
            f"({csv_columns_sql}) "
            f"VALUES ({placeholders})"
        )

        # Convert Pandas values to database-compatible values.
        def convert_value(value):
            if pd.isna(value):
                return None

            if hasattr(value, "item"):
                value = value.item()

            if isinstance(value, float) and not math.isfinite(value):
                return None

            return value

        # 10. Insert rows in batches.
        batch_size = 1000
        inserted_rows = 0

        for start in range(0, len(df), batch_size):
            batch = df.iloc[start:start + batch_size]

            rows = [
                tuple(convert_value(value) for value in row)
                for row in batch.itertuples(
                    index=False,
                    name=None
                )
            ]

            cursor.executemany(insert_sql, rows)
            inserted_rows += len(rows)

        # 11. Initialize edit tracking fields.
        # These columns are guaranteed to exist because they are
        # defined in extra_columns unless already supplied by the CSV.
        if "edited" in df.columns:
            cursor.execute(
                f"UPDATE {quoted_table} SET `edited` = 0"
            )
        else:
            cursor.execute(
                f"UPDATE {quoted_table} SET `edited` = 0"
            )

        if "edittime" not in df.columns:
            cursor.execute(
                f"UPDATE {quoted_table} SET `edittime` = NULL"
            )

        # 12. Commit changes.
        connection.commit()

        # 13. Fetch a preview of the migrated data.
        cursor.execute(
            f"SELECT * FROM {quoted_table} LIMIT 10"
        )

        result_rows = cursor.fetchall()
        result_columns = [
            item[0] for item in cursor.description
        ]

        preview = []

        for row in result_rows:
            row_dict = dict(zip(result_columns, row))

            for key, value in row_dict.items():
                if hasattr(value, "isoformat"):
                    row_dict[key] = value.isoformat()

            preview.append(row_dict)

        # 14. Return the response.
        return JsonResponse({
            "success": True,
            "message": (
                "Old table dropped, new table created, "
                "and CSV data imported successfully."
            ),
            "filename": os.path.basename(file_path),
            "database": "marketdata",
            "table": table_name,
            "total_csv_rows": len(df),
            "inserted_rows": inserted_rows,
            "columns": df.columns.tolist(),
            "additional_columns": [
                col for col in extra_columns
                if col not in df.columns
            ],
            "preview": preview,
        }, json_dumps_params={"default": str})

    except Exception as e:
        if connection:
            try:
                connection.rollback()
            except Exception:
                pass

        return JsonResponse({
            "success": False,
            "error": str(e),
        }, status=500)

    finally:
        if cursor:
            try:
                cursor.close()
            except Exception:
                pass

        if connection:
            close_connection(connection)
