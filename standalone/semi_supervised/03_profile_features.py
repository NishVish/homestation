
import numpy as np
import os

PATH = "dataset/X_ohlc.npy"

X = np.load(PATH, mmap_mode="r")

N = len(X)
rng = np.random.default_rng(42)

# Deterministic sample: 100K rows
indices = rng.choice(
    N,
    size=min(100000, N),
    replace=False
)

sample = np.asarray(X[indices])

print("\n========== FEATURE DISTRIBUTION ==========")

for tf, name in enumerate(["H4", "H1", "M15", "M5"]):

    data = sample[:, tf, :, :]

    print(f"\n--- {name} ---")

    for j, col in enumerate(
        ["OPEN", "HIGH", "LOW", "CLOSE"]
    ):

        values = data[:, :, j].ravel()

        print(
            f"{col:6s}",
            "mean:", round(float(values.mean()), 4),
            "std:", round(float(values.std()), 4),
            "p01:", round(float(np.percentile(values, 1)), 4),
            "p50:", round(float(np.percentile(values, 50)), 4),
            "p99:", round(float(np.percentile(values, 99)), 4)
        )

print("\n========== EXTREME VALUE ANALYSIS ==========")

abs_values = np.abs(sample)

print("Absolute value percentiles:")

for p in [50, 90, 95, 99, 99.9, 100]:

    print(
        f"P{p}:",
        float(np.percentile(abs_values, p))
    )

print("\n========== OHLC STRUCTURE ==========")

for tf, name in enumerate(["H4", "H1", "M15", "M5"]):

    data = sample[:, tf, :, :]

    open_ = data[:, :, 0]
    high = data[:, :, 1]
    low = data[:, :, 2]
    close = data[:, :, 3]

    high_violations = np.mean(
        high < np.maximum(open_, close)
    )

    low_violations = np.mean(
        low > np.minimum(open_, close)
    )

    print(
        name,
        "High violations:", round(float(high_violations * 100), 4), "%",
        "Low violations:", round(float(low_violations * 100), 4), "%"
    )

print("\n========== ROW MAGNITUDE ==========")

row_norm = np.sqrt(
    np.mean(sample ** 2, axis=(1, 2, 3))
)

for p in [50, 90, 95, 99, 99.9, 100]:

    print(
        f"P{p}:",
        float(np.percentile(row_norm, p))
    )

print("\nPROFILE COMPLETED")
