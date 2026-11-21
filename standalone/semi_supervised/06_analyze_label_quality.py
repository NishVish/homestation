
import numpy as np
import csv
from collections import defaultdict

# ============================================
# CONFIGURATION
# ============================================

DATASET = "dataset"
CLUSTERS = "clusters"

X_FILE = f"{DATASET}/X_ohlc.npy"
Y_FILE = f"{DATASET}/y.npy"
STATUS_FILE = f"{DATASET}/status.npy"
CLUSTER_FILE = f"{CLUSTERS}/cluster_labels.npy"

OUTPUT_FILE = f"{CLUSTERS}/label_quality.csv"

BATCH_SIZE = 50000

# ============================================
# LOAD ARRAYS
# ============================================

print("Loading datasets...")

X = np.load(X_FILE, mmap_mode="r")
y = np.load(Y_FILE, mmap_mode="r")
status = np.load(STATUS_FILE, mmap_mode="r")
clusters = np.load(CLUSTER_FILE, mmap_mode="r")

assert len(X) == len(y) == len(status) == len(clusters)

# ============================================
# GROUP DEFINITIONS
# ============================================

results = defaultdict(lambda: {
    "total": 0,
    "buy": 0,
    "sell": 0,
    "reviewed_none": 0,
    "unseen": 0
})

# ============================================
# ANALYSIS
# ============================================

print("Analyzing label distribution...")

for start in range(0, len(y), BATCH_SIZE):

    end = min(start + BATCH_SIZE, len(y))

    batch_y = y[start:end]
    batch_status = status[start:end]
    batch_clusters = clusters[start:end]

    for cluster in np.unique(batch_clusters):

        mask = batch_clusters == cluster

        r = results[int(cluster)]

        r["total"] += int(mask.sum())

        r["buy"] += int(np.sum(mask & (batch_y == 0)))
        r["sell"] += int(np.sum(mask & (batch_y == 1)))

        r["reviewed_none"] += int(
            np.sum(mask & (batch_status == 1))
        )

        r["unseen"] += int(
            np.sum(mask & (batch_status == 0))
        )

# ============================================
# SAVE REPORT
# ============================================

with open(OUTPUT_FILE, "w", newline="") as f:

    writer = csv.writer(f)

    writer.writerow([
        "cluster",
        "total",
        "buy",
        "sell",
        "reviewed_none",
        "unseen",
        "total_reviewed",
        "total_trading_labels"
    ])

    for cluster in sorted(results):

        r = results[cluster]

        writer.writerow([
            cluster,
            r["total"],
            r["buy"],
            r["sell"],
            r["reviewed_none"],
            r["unseen"],
            r["buy"] + r["sell"] + r["reviewed_none"],
            r["buy"] + r["sell"]
        ])

# ============================================
# SUMMARY
# ============================================

totals = {
    key: sum(r[key] for r in results.values())
    for key in [
        "total",
        "buy",
        "sell",
        "reviewed_none",
        "unseen"
    ]
}

print("\n========== LABEL QUALITY REPORT ==========")

for key, value in totals.items():
    print(f"{key}: {value:,}")

print("\nClusters:", len(results))

print("\nReport saved:", OUTPUT_FILE)
print("\nANALYSIS COMPLETED")
