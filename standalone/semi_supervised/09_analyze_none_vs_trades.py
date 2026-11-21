
import numpy as np
from collections import defaultdict

y = np.load("dataset/y.npy", mmap_mode="r")
status = np.load("dataset/status.npy", mmap_mode="r")
clusters = np.load("clusters/cluster_labels.npy", mmap_mode="r")

results = defaultdict(lambda: {
    "buy": 0,
    "sell": 0,
    "none": 0,
    "unseen": 0
})

for start in range(0, len(y), 50000):
    end = min(start + 50000, len(y))

    batch_y = y[start:end]
    batch_status = status[start:end]
    batch_clusters = clusters[start:end]

    for c in np.unique(batch_clusters):
        mask = batch_clusters == c
        r = results[int(c)]

        r["buy"] += int(np.sum(mask & (batch_y == 0)))
        r["sell"] += int(np.sum(mask & (batch_y == 1)))
        r["none"] += int(np.sum(mask & (batch_status == 1)))
        r["unseen"] += int(np.sum(mask & (batch_status == 0)))

print("\n========== NONE VS TRADING LABELS ==========")

for c in sorted(results):
    r = results[c]

    trades = r["buy"] + r["sell"]
    reviewed = trades + r["none"]

    print(
        f"Cluster {c:2d} | "
        f"BUY={r['buy']:3d} | "
        f"SELL={r['sell']:3d} | "
        f"NONE={r['none']:4d} | "
        f"UNSEEN={r['unseen']:6d} | "
        f"REVIEWED={reviewed:4d}"
    )

print("\nANALYSIS COMPLETED")
