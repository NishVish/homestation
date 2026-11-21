
import csv
import numpy as np
from collections import defaultdict

CLUSTER_FILE = "clusters/cluster_labels.npy"
Y_FILE = "dataset/y.npy"
STATUS_FILE = "dataset/status.npy"

clusters = np.load(CLUSTER_FILE, mmap_mode="r")
y = np.load(Y_FILE, mmap_mode="r")
status = np.load(STATUS_FILE, mmap_mode="r")

results = defaultdict(lambda: {
    "total": 0,
    "buy": 0,
    "sell": 0,
    "none": 0,
    "unseen": 0
})

for start in range(0, len(y), 50000):
    end = min(start + 50000, len(y))

    c = clusters[start:end]
    labels = y[start:end]
    s = status[start:end]

    for cluster in np.unique(c):
        mask = c == cluster

        r = results[int(cluster)]
        r["total"] += int(mask.sum())
        r["buy"] += int(np.sum(mask & (labels == 0)))
        r["sell"] += int(np.sum(mask & (labels == 1)))
        r["none"] += int(np.sum(mask & (s == 1)))
        r["unseen"] += int(np.sum(mask & (s == 0)))

with open("clusters/cluster_analysis.csv", "w", newline="") as f:
    writer = csv.writer(f)

    writer.writerow([
        "cluster", "total", "buy", "sell",
        "none", "unseen", "labeled",
        "buy_pct", "sell_pct"
    ])

    for cluster in sorted(results):
        r = results[cluster]
        labeled = r["buy"] + r["sell"]

        writer.writerow([
            cluster,
            r["total"],
            r["buy"],
            r["sell"],
            r["none"],
            r["unseen"],
            labeled,
            round(r["buy"] / max(r["total"], 1) * 100, 5),
            round(r["sell"] / max(r["total"], 1) * 100, 5)
        ])

print("Analysis saved: clusters/cluster_analysis.csv")
print("Total BUY:", sum(r["buy"] for r in results.values()))
print("Total SELL:", sum(r["sell"] for r in results.values()))
print("Total NONE:", sum(r["none"] for r in results.values()))
print("Total UNSEEN:", sum(r["unseen"] for r in results.values()))
