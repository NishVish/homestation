
import numpy as np
from collections import defaultdict

y = np.load("dataset/y.npy", mmap_mode="r")
status = np.load("dataset/status.npy", mmap_mode="r")
clusters = np.load("clusters/cluster_labels.npy", mmap_mode="r")

buy = np.flatnonzero(y == 0)
sell = np.flatnonzero(y == 1)

print("\n========== LABEL INDEX GAPS ==========")

for name, indices in [("BUY", buy), ("SELL", sell)]:
    print(f"\n{name}:")
    print("Indices:", indices.tolist())

    if len(indices) > 1:
        gaps = np.diff(indices)
        print("Minimum gap:", int(gaps.min()))
        print("Median gap:", float(np.median(gaps)))
        print("Maximum gap:", int(gaps.max()))

print("\n========== CLUSTER LABEL DISTRIBUTION ==========")

for name, indices in [("BUY", buy), ("SELL", sell)]:
    counts = defaultdict(int)

    for idx in indices:
        counts[int(clusters[idx])] += 1

    print(f"\n{name}:")
    for cluster, count in sorted(counts.items()):
        print(f"Cluster {cluster}: {count}")

print("\n========== CONSECUTIVE LABEL CHECK ==========")

labeled = np.flatnonzero((y == 0) | (y == 1))

if len(labeled) > 1:
    gaps = np.diff(labeled)
    print("Adjacent labeled pairs:", int(np.sum(gaps == 1)))
    print("Labeled examples:", len(labeled))

print("\n========== STATUS VERIFICATION ==========")

for s in [0, 1, 2, 3]:
    print(f"Status {s}: {int(np.sum(status == s))}")

print("\nANALYSIS COMPLETED")
