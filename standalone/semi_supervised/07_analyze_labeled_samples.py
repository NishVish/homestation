
import numpy as np
import json

X = np.load("dataset/X_ohlc.npy", mmap_mode="r")
y = np.load("dataset/y.npy", mmap_mode="r")
status = np.load("dataset/status.npy", mmap_mode="r")
clusters = np.load("clusters/cluster_labels.npy", mmap_mode="r")

groups = {
    "BUY": np.flatnonzero(y == 0),
    "SELL": np.flatnonzero(y == 1),
    "REVIEWED_NONE": np.flatnonzero(status == 1),
    "UNSEEN": np.flatnonzero(status == 0)
}

print("\n========== SAMPLE DISTRIBUTION ==========")

for name, indices in groups.items():
    print(f"{name}: {len(indices):,}")

print("\n========== LABELED SAMPLE DETAILS ==========")

for name in ["BUY", "SELL"]:
    indices = groups[name]

    print(f"\n{name}")

    for idx in indices:
        features = np.asarray(X[idx]).reshape(-1)

        print(
            f"Index={idx}, "
            f"Cluster={int(clusters[idx])}, "
            f"Mean={features.mean():.4f}, "
            f"Std={features.std():.4f}, "
            f"Min={features.min():.4f}, "
            f"Max={features.max():.4f}"
        )

print("\n========== REVIEWED NONE SUMMARY ==========")

none_indices = groups["REVIEWED_NONE"]

if len(none_indices):
    none_features = np.asarray(X[none_indices])

    print("Mean:", float(none_features.mean()))
    print("Std:", float(none_features.std()))
    print("Min:", float(none_features.min()))
    print("Max:", float(none_features.max()))

print("\nANALYSIS COMPLETED")
