
import os
import math
import time
import uuid
import pandas as pd

from django.http import JsonResponse
from .sqlconnection import get_connection, close_connection


# Configuration
TABLE_NAME = "labeled_flatdata"
CHUNK_SIZE = 250

EXTRA_COLUMNS = {
    "decision": "VARCHAR(100) NULL",
    "edited": "TINYINT(1) NOT NULL DEFAULT 0",
    "edittime": "DATETIME NULL",
}
extra_columns = EXTRA_COLUMNS


def normalize_columns(columns):
    return [
        str(col).strip().replace(" ", "_")
        for col in columns
    ]


def convert_value(value):
    if pd.isna(value):
        return None

    if hasattr(value, "item"):
        value = value.item()

    if isinstance(value, float) and not math.isfinite(value):
        return None

    return value


def migrate_data(request):

    file_path = (
        r"C:\Users\nishw\AppData\Roaming\MetaQuotes\Tester"
        r"\D0E8209F77C8CF37AD8BF550E51FF075"
        r"\Agent-127.0.0.1-3000\MQL5\Files\labeled_flatdata.csv"
    )

    connection = None
    cursor = None

    # Unique staging and backup names prevent collisions.
    unique_id = uuid.uuid4().hex[:12]

    staging_table = f"{TABLE_NAME}_staging_{unique_id}"
    backup_table = f"{TABLE_NAME}_backup_{unique_id}"

    quoted_table = f"`{TABLE_NAME}`"
    quoted_staging = f"`{staging_table}`"
    quoted_backup = f"`{backup_table}`"

    start_time = time.perf_counter()

    inserted_rows = 0
    table_swapped = False

    try:

        # 1. Validate file.
        if not os.path.isfile(file_path):
            return JsonResponse({
                "success": False,
                "error": "CSV file not found."
            }, status=404)

        initial_stat = os.stat(file_path)

        file_size_mb = initial_stat.st_size / (1024 * 1024)

        print(f"Starting migration: {file_size_mb:.2f} MB")

        # 2. Read only a small sample to infer SQL column types.
        sample = pd.read_csv(
            file_path,
            nrows=2000,
            low_memory=False
        )

        if sample.empty:
            return JsonResponse({
                "success": False,
                "error": "CSV contains no data rows."
            }, status=400)

        columns = normalize_columns(sample.columns)

        if any(not col for col in columns):
            raise ValueError("CSV contains an empty column name.")

        if len(set(columns)) != len(columns):
            raise ValueError(
                "Duplicate columns found after normalization."
            )

        sample.columns = columns

        # 3. Build SQL schema.
        column_definitions = []

        for col in columns:

            dtype = sample[col].dtype

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

        # Add missing extra columns.
        for col, sql_type in EXTRA_COLUMNS.items():

            if col not in columns:

                column_definitions.append(
                    f"`{col}` {sql_type}"
                )

        # 4. Connect to database.
        connection = get_connection()

        if connection is None:
            raise RuntimeError(
                "Could not connect to MySQL database."
            )

        cursor = connection.cursor()

        # 5. Create staging table.
        cursor.execute(
            f"""
            CREATE TABLE {quoted_staging} (
                {", ".join(column_definitions)}
            ) ENGINE=InnoDB
              DEFAULT CHARSET=utf8mb4
              ROW_FORMAT=DYNAMIC
            """
        )

        connection.commit()

        # 6. Prepare insert query.
        csv_columns_sql = ", ".join(
            f"`{col.replace('`', '``')}`"
            for col in columns
        )

        placeholders = ", ".join(
            ["%s"] * len(columns)
        )

        insert_sql = (
            f"INSERT INTO {quoted_staging} "
            f"({csv_columns_sql}) "
            f"VALUES ({placeholders})"
        )

        # 7. Read CSV in chunks and insert.
        for chunk_number, chunk in enumerate(
            pd.read_csv(
                file_path,
                chunksize=CHUNK_SIZE,
                header=0,
                names=columns,
                low_memory=False
            ),
            start=1
        ):

            rows = [
                tuple(
                    convert_value(value)
                    for value in row
                )
                for row in chunk.itertuples(
                    index=False,
                    name=None
                )
            ]

            if rows:
                cursor.executemany(insert_sql, rows)

                # Commit each chunk.
                # A failed import will not affect the original table.
                connection.commit()

                inserted_rows += len(rows)

            elapsed = time.perf_counter() - start_time

            print(
                f"Chunk: {chunk_number} | "
                f"Inserted: {inserted_rows:,} | "
                f"Elapsed: {elapsed:.1f}s"
            )

        # 8. Confirm CSV has not changed during import.
        final_stat = os.stat(file_path)

        if (
            initial_stat.st_size != final_stat.st_size
            or initial_stat.st_mtime_ns != final_stat.st_mtime_ns
        ):
            raise RuntimeError(
                "CSV file changed during migration. "
                "Import cancelled."
            )

        # 9. Validate staging table.
        cursor.execute(
            f"SELECT COUNT(*) FROM {quoted_staging}"
        )

        database_rows = cursor.fetchone()[0]

        if database_rows != inserted_rows:
            raise RuntimeError(
                f"Row mismatch: inserted {inserted_rows}, "
                f"database contains {database_rows}."
            )

        if inserted_rows == 0:
            raise RuntimeError("No rows were imported.")

        # 10. Check whether original table exists.
        cursor.execute(
            """
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = DATABASE()
              AND table_name = %s
            """,
            (TABLE_NAME,)
        )

        original_exists = cursor.fetchone()[0] > 0

        # 11. Atomically replace original table.
        if original_exists:

            cursor.execute(
                f"""
                RENAME TABLE
                    {quoted_table} TO {quoted_backup},
                    {quoted_staging} TO {quoted_table}
                """
            )

        else:

            cursor.execute(
                f"""
                RENAME TABLE
                    {quoted_staging} TO {quoted_table}
                """
            )

        table_swapped = True

        # 12. Remove old backup only after successful replacement.
        if original_exists:

            cursor.execute(
                f"DROP TABLE {quoted_backup}"
            )

        connection.commit()

        # 13. Fetch a small preview.
        cursor.execute(
            f"SELECT * FROM {quoted_table} LIMIT 3"
        )

        result_rows = cursor.fetchall()

        result_columns = [
            item[0] for item in cursor.description
        ]

        preview = []

        for row in result_rows:

            row_dict = dict(zip(result_columns, row))

            # Prevent huge text fields from bloating the response.
            for key, value in row_dict.items():

                if hasattr(value, "isoformat"):
                    row_dict[key] = value.isoformat()

                elif isinstance(value, str) and len(value) > 500:
                    row_dict[key] = value[:500] + "... [truncated]"

            preview.append(row_dict)

        elapsed = time.perf_counter() - start_time

        print(
            f"Migration completed: {inserted_rows:,} rows "
            f"in {elapsed:.2f} seconds."
        )

        return JsonResponse({
            "success": True,
            "message": "CSV migration completed successfully.",
            "filename": os.path.basename(file_path),
            "file_size_mb": round(file_size_mb, 2),
            "database": "marketdata",
            "table": TABLE_NAME,
            "total_rows": inserted_rows,
            "verified_database_rows": database_rows,
            "chunk_size": CHUNK_SIZE,
            "elapsed_seconds": round(elapsed, 2),
            "rows_per_second": round(
                inserted_rows / elapsed, 2
            ) if elapsed > 0 else 0,
            "columns": columns,
            "preview": preview
        }, json_dumps_params={"default": str})

    except Exception as e:

        if connection:
            try:
                connection.rollback()
            except Exception:
                pass

        # Remove incomplete staging table.
        # The original table remains untouched unless the swap
        # has already completed.
        if cursor and not table_swapped:
            try:
                cursor.execute(
                    f"DROP TABLE IF EXISTS {quoted_staging}"
                )
                connection.commit()
            except Exception:
                pass

        return JsonResponse({
            "success": False,
            "error": str(e),
            "inserted_before_failure": inserted_rows,
            "elapsed_seconds": round(
                time.perf_counter() - start_time, 2
            )
        }, status=500)

    finally:

        if cursor:
            try:
                cursor.close()
            except Exception:
                pass

        if connection:
            close_connection(connection)

