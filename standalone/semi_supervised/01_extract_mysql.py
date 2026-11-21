
# 01_extract_mysql.py

import os
import json
import gc
import numpy as np
import mysql.connector
from tqdm import tqdm

# ============================================
# CONFIGURATION
# ============================================

TABLE_NAME = "labeled_flatdata"
BATCH_SIZE = 5000

OUTPUT_DIR = "dataset"

TIMEFRAMES = ["H4", "H1", "M15", "M5"]
OHLC = ["open", "high", "low", "close"]

FEATURE_COUNT = 320

os.makedirs(OUTPUT_DIR, exist_ok=True)


# ============================================
# MYSQL
# ============================================

def get_connection():

    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="marketdata",
        connection_timeout=30
    )


# ============================================
# COLUMN GENERATION
# ============================================

def get_ohlc_columns():

    columns = []

    for tf in TIMEFRAMES:

        for candle in range(1, 21):

            for feature in OHLC:

                columns.append(
                    f"`{tf}_{candle:02d}_{feature}`"
                )

    return columns


# ============================================
# MAIN EXTRACTION
# ============================================

def extract_dataset():

    conn = get_connection()
    cursor = conn.cursor(buffered=False)

    try:

        # Count rows

        count_cursor = conn.cursor()

        count_cursor.execute(
            f"SELECT COUNT(*) FROM `{TABLE_NAME}`"
        )

        total_rows = count_cursor.fetchone()[0]
        count_cursor.close()

        print("Database rows:", total_rows)

        # Select only necessary columns

        columns = get_ohlc_columns()

        query = f"""
            SELECT
                {",".join(columns)},
                `edited`,
                `decision`
            FROM `{TABLE_NAME}`
            ORDER BY `id` ASC
        """

        cursor.execute(query)

        # Allocate disk-backed arrays

        X = np.lib.format.open_memmap(
            f"{OUTPUT_DIR}/X_ohlc.npy",
            mode="w+",
            dtype=np.float32,
            shape=(total_rows, 4, 20, 4)
        )

        y = np.lib.format.open_memmap(
            f"{OUTPUT_DIR}/y.npy",
            mode="w+",
            dtype=np.int8,
            shape=(total_rows,)
        )

        status = np.lib.format.open_memmap(
            f"{OUTPUT_DIR}/status.npy",
            mode="w+",
            dtype=np.uint8,
            shape=(total_rows,)
        )

        # Status:
        # 0 = unseen
        # 1 = reviewed, no decision
        # 2 = reviewed BUY
        # 3 = reviewed SELL

        # Labels:
        # 0 = BUY
        # 1 = SELL
        # -1 = UNLABELED

        counts = {
            "buy": 0,
            "sell": 0,
            "reviewed_none": 0,
            "unseen": 0,
            "invalid_ohlc": 0,
            "unexpected_decisions": {}
        }

        # Reusable batch buffers

        batch_X = np.empty(
            (BATCH_SIZE, 4, 20, 4),
            dtype=np.float32
        )

        batch_y = np.empty(
            BATCH_SIZE,
            dtype=np.int8
        )

        batch_status = np.empty(
            BATCH_SIZE,
            dtype=np.uint8
        )

        position = 0
        progress = tqdm(total=total_rows)

        while True:

            rows = cursor.fetchmany(BATCH_SIZE)

            if not rows:
                break

            batch_count = 0

            for row in rows:

                # Convert OHLC

                try:

                    values = np.asarray(
                        row[:FEATURE_COUNT],
                        dtype=np.float32
                    )

                    if not np.isfinite(values).all():
                        counts["invalid_ohlc"] += 1
                        continue

                except (ValueError, TypeError):

                    counts["invalid_ohlc"] += 1
                    continue

                edited = row[FEATURE_COUNT]
                decision = row[FEATURE_COUNT + 1]

                decision = (
                    str(decision).strip().lower()
                    if decision is not None
                    else ""
                )

                # ------------------------
                # LABEL LOGIC
                # ------------------------

                if edited == 1:

                    if decision == "buy":

                        label = 0
                        sample_status = 2

                        counts["buy"] += 1

                    elif decision == "sell":

                        label = 1
                        sample_status = 3

                        counts["sell"] += 1

                    else:

                        label = -1
                        sample_status = 1

                        counts["reviewed_none"] += 1

                        if decision not in ("", "none"):

                            unexpected = counts[
                                "unexpected_decisions"
                            ]

                            unexpected[decision] = (
                                unexpected.get(decision, 0) + 1
                            )

                else:

                    label = -1
                    sample_status = 0

                    counts["unseen"] += 1

                # Store directly in reusable buffers

                batch_X[batch_count] = values.reshape(
                    4, 20, 4
                )

                batch_y[batch_count] = label

                batch_status[batch_count] = sample_status

                batch_count += 1

            # ------------------------
            # WRITE TO DISK
            # ------------------------

            if batch_count > 0:

                end = position + batch_count

                X[position:end] = batch_X[:batch_count]

                y[position:end] = batch_y[:batch_count]

                status[position:end] = (
                    batch_status[:batch_count]
                )

                position = end

            progress.update(len(rows))

            del rows

        progress.close()

        # Flush disk-backed arrays

        X.flush()
        y.flush()
        status.flush()

        # ------------------------
        # METADATA
        # ------------------------

        labeled = counts["buy"] + counts["sell"]

        unlabeled = (
            counts["reviewed_none"] + counts["unseen"]
        )

        metadata = {

            "total_database_rows": total_rows,

            "valid_rows": position,

            "input_shape": [4, 20, 4],

            "features": FEATURE_COUNT,

            "labels": {
                "buy": 0,
                "sell": 1,
                "unlabeled": -1
            },

            "status": {
                "unseen": 0,
                "reviewed_none": 1,
                "reviewed_buy": 2,
                "reviewed_sell": 3
            },

            "counts": counts,

            "labeled": labeled,

            "unlabeled": unlabeled

        }

        with open(
            f"{OUTPUT_DIR}/metadata.json",
            "w"
        ) as f:

            json.dump(metadata, f, indent=4)

        # ------------------------
        # REPORT
        # ------------------------

        print("\n" + "=" * 55)
        print("EXTRACTION COMPLETED")
        print("=" * 55)

        print("Valid rows:", position)

        print("BUY:", counts["buy"])
        print("SELL:", counts["sell"])

        print(
            "Reviewed, no decision:",
            counts["reviewed_none"]
        )

        print("Unseen:", counts["unseen"])

        print("Invalid OHLC:", counts["invalid_ohlc"])

        print("-" * 55)

        print("Total labeled:", labeled)
        print("Total unlabeled:", unlabeled)

        print("-" * 55)

        print("X shape:", (position, 4, 20, 4))

        print("BUY ratio:",
              counts["buy"] / max(position, 1))

        print("SELL ratio:",
              counts["sell"] / max(position, 1))

        print("\nFiles saved in:", OUTPUT_DIR)

        if counts["unexpected_decisions"]:
            print(
                "Unexpected decisions:",
                counts["unexpected_decisions"]
            )

        del X, y, status

        gc.collect()

    finally:

        cursor.close()
        conn.close()


if __name__ == "__main__":

    extract_dataset()
