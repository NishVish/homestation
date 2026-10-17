import sys
import os
import pandas as pd
from django.http import HttpResponse

sys.path.append(os.getcwd())

from .sqlconnection import get_connection, close_connection


def loadcsvtosql(request):

    filespath = r"C:\Users\nishw\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\MQL5\Files"

    conn = get_connection()
    cursor = conn.cursor()

    try:

        # =====================================================
        # STEP 1: WIPE EVERYTHING
        # =====================================================

        cursor.execute("SET FOREIGN_KEY_CHECKS = 0")

        cursor.execute("SHOW TABLES")
        tables = cursor.fetchall()

        for table in tables:
            cursor.execute(
                f"DROP TABLE IF EXISTS `{table[0]}`"
            )

        cursor.execute("SET FOREIGN_KEY_CHECKS = 1")
        conn.commit()

        # =====================================================
        # STEP 2: LOAD THE ONLY CSV INTO SQL
        # =====================================================

        csv_files = [
            f for f in os.listdir(filespath)
            if f.lower().endswith(".csv")
        ]

        if len(csv_files) != 1:
            raise Exception(
                f"Expected exactly one CSV file, found {len(csv_files)}"
            )

        csv_file = csv_files[0]
        csv_path = os.path.join(filespath, csv_file)

        df = pd.read_csv(csv_path)

        source_table = os.path.splitext(csv_file)[0]

        columns = list(df.columns)

        column_definitions = ", ".join(
            f"`{column}` TEXT"
            for column in columns
        )

        cursor.execute(
            f"""
            CREATE TABLE `{source_table}` (
                {column_definitions}
            )
            """
        )

        placeholders = ", ".join(
            ["%s"] * len(columns)
        )

        rows = [
            tuple(
                "" if pd.isna(value) else str(value)
                for value in row
            )
            for row in df.itertuples(
                index=False,
                name=None
            )
        ]

        cursor.executemany(
            f"""
            INSERT INTO `{source_table}`
            VALUES ({placeholders})
            """,
            rows
        )

        conn.commit()

        # =====================================================
        # STEP 3: GET ONLY 1min COLUMNS
        # =====================================================

        cursor.execute(
            """
            SELECT COLUMN_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = %s
              AND COLUMN_NAME LIKE '1min_%%'
            ORDER BY ORDINAL_POSITION
            """,
            (source_table,)
        )

        one_min_columns = [
            row[0]
            for row in cursor.fetchall()
        ]

        if not one_min_columns:
            raise Exception("No 1min columns found.")

        if "1min_raw_time_1" not in one_min_columns:
            raise Exception(
                "1min_raw_time_1 column not found."
            )

        # =====================================================
        # STEP 4: CREATE 1min
        #
        # SORT FIRST:
        #     1min_raw_time_1 ASCENDING
        #
        # THEN ID:
        #     1, 2, 3, ... in that SAME ascending order
        #
        # ID IS THE FIRST COLUMN
        # =====================================================

        cursor.execute("""
            DROP TABLE IF EXISTS `1min`
        """)

        column_list = ", ".join(
            f"`{column}`"
            for column in one_min_columns
        )

        cursor.execute(
            f"""
            CREATE TABLE `1min` AS
            SELECT
                {column_list}
            FROM `{source_table}`
            ORDER BY
                CAST(`1min_raw_time_1` AS UNSIGNED) ASC
            """
        )

        conn.commit()

        # =====================================================
        # STEP 5: ADD ID
        # =====================================================

        cursor.execute("""
            ALTER TABLE `1min`
            ADD COLUMN `id` INT NULL
        """)

        cursor.execute("""
            SET @id = 0
        """)

        # Assign ID according to ASCENDING time order
        cursor.execute("""
            UPDATE `1min`
            SET `id` = (@id := @id + 1)
            ORDER BY
                CAST(`1min_raw_time_1` AS UNSIGNED) ASC
        """)

        # =====================================================
        # STEP 6: REBUILD TABLE SO ID IS FIRST COLUMN
        # =====================================================

        cursor.execute("""
            ALTER TABLE `1min`
            MODIFY COLUMN `id` INT NOT NULL FIRST
        """)

        cursor.execute("""
            ALTER TABLE `1min`
            ADD PRIMARY KEY (`id`)
        """)

        conn.commit()

        print("1min table created successfully.")

        return HttpResponse(
            "Database rebuilt successfully."
        )

    except Exception as e:

        conn.rollback()

        print(f"Database migration failed: {e}")

        return HttpResponse(
            f"Database migration failed:<br><br>{e}",
            status=500
        )

    finally:

        close_connection(conn)
