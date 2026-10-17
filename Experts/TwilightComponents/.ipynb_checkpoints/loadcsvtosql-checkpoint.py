import sys
import os
import pandas as pd

sys.path.append(os.getcwd())

from sqlconnection import get_connection, close_connection

def loadcsvtosql():
        
    filespath = r"C:\Users\nishw\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\MQL5\Files"
    
    conn = get_connection()
    cursor = conn.cursor()
    
    # =====================================================
    # STEP 1: DROP ALL TABLES
    # =====================================================
    
    cursor.execute("SET FOREIGN_KEY_CHECKS = 0")
    
    cursor.execute("SHOW TABLES")
    tables = cursor.fetchall()
    
    for t in tables:
        cursor.execute(f"DROP TABLE IF EXISTS `{t[0]}`")
    
    cursor.execute("SET FOREIGN_KEY_CHECKS = 1")
    conn.commit()

    print("old data removed")
    # =====================================================
    # STEP 2: LOAD ALL CSV FILES
    # =====================================================
    
    files = os.listdir(filespath)
    
    for f in files:
    
        if not f.endswith(".csv"):
            continue
    
        filepath = os.path.join(filespath, f)
    
        print(f"Loading {f}...")
    
        df = pd.read_csv(filepath)
    
        table_name = os.path.splitext(f)[0]
    
        cols = list(df.columns)
    
        col_defs = ", ".join([f"`{c}` TEXT" for c in cols])
    
        cursor.execute(
            f"CREATE TABLE IF NOT EXISTS `{table_name}` ({col_defs})"
        )
    
        placeholders = ",".join(["%s"] * len(cols))
    
        rows = [
            tuple("" if pd.isna(x) else str(x) for x in row)
            for row in df.values
        ]
    
        cursor.executemany(
            f"INSERT INTO `{table_name}` VALUES ({placeholders})",
            rows
        )
    
        conn.commit()
    
    # =====================================================
    # STEP 3: EXPLODE tradejournal COMMENT
    # =====================================================
    
    cursor.execute("""
    ALTER TABLE tradejournal
    ADD COLUMN timestamp DATETIME NULL,
    ADD COLUMN pips DECIMAL(10,2) NULL
    """)
    
    cursor.execute("""
    UPDATE tradejournal
    SET
        timestamp = STR_TO_DATE(
            TRIM(SUBSTRING_INDEX(Comment, '|', 1)),
            '%Y.%m.%d %H:%i'
        ),
        pips = CAST(
            TRIM(SUBSTRING_INDEX(Comment, '|', -1))
            AS DECIMAL(10,2)
        )
    """)
    
    conn.commit()
    
    # =====================================================
    # STEP 4: BUILD FEATURE TABLE
    # =====================================================
    
    cursor.execute("""
    DROP TABLE IF EXISTS multitimeframe_snapshot_features
    """)
    
    cursor.execute("""
    CREATE TABLE multitimeframe_snapshot_features AS
    SELECT
        m.*,
    
        MAX(CASE WHEN t.Type='BUY'  AND t.pips=10 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS buy_10,
        MAX(CASE WHEN t.Type='BUY'  AND t.pips=20 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS buy_20,
        MAX(CASE WHEN t.Type='BUY'  AND t.pips=30 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS buy_30,
        MAX(CASE WHEN t.Type='BUY'  AND t.pips=40 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS buy_40,
        MAX(CASE WHEN t.Type='BUY'  AND t.pips=50 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS buy_50,
        MAX(CASE WHEN t.Type='BUY'  AND t.pips=60 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS buy_60,
    
        MAX(CASE WHEN t.Type='SELL' AND t.pips=10 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS sell_10,
        MAX(CASE WHEN t.Type='SELL' AND t.pips=20 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS sell_20,
        MAX(CASE WHEN t.Type='SELL' AND t.pips=30 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS sell_30,
        MAX(CASE WHEN t.Type='SELL' AND t.pips=40 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS sell_40,
        MAX(CASE WHEN t.Type='SELL' AND t.pips=50 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS sell_50,
        MAX(CASE WHEN t.Type='SELL' AND t.pips=60 THEN CAST(t.Profit AS DECIMAL(10,2)) END) AS sell_60
    
    FROM multitimeframe_snapshot m
    
    LEFT JOIN tradejournal t
        ON t.timestamp = FROM_UNIXTIME(
            CAST(m.`15m_time` AS UNSIGNED)
        )
    
    GROUP BY m.`15m_time`
    """)
    
    conn.commit()
    
    print("Database rebuilt successfully.")
    
    close_connection(conn)