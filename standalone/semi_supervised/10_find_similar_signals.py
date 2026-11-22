
import numpy as np
import pandas as pd
import os

from sklearn.preprocessing import normalize
from sklearn.neighbors import NearestNeighbors

# Configuration
TOP_K = 20
BATCH_SIZE = 10000

# Load datasets
X = np.load("dataset/X_ohlc.npy", mmap_mode="r")
y = np.load("dataset/y.npy")
status = np.load("dataset/status.npy")

# Reference trading signals
buy_idx = np.where((status == 2) & (y == 0))[0]
sell_idx = np.where((status == 3) & (y == 1))[0]

# Unseen samples only
unseen_idx = np.where(status == 0)[0]

print("BUY references:", len(buy_idx))
print("SELL references:", len(sell_idx))
print("Unseen samples:", len(unseen_idx))

# Flatten OHLC data
X_flat = X.reshape(len(X), -1)

# Normalize each sample to remove absolute price scale.
# Use the same transformation for references and unseen data.
def prepare_features(indices):
    data = np.asarray(X_flat[indices], dtype=np.float32)

    # Normalize OHLC values relative to each sample's
    # first opening price.
    data = data.reshape(-1, 4, 20, 4)

    base = data[:, :, 0, 0][:, :, None, None]
    base = np.where(np.abs(base) < 1e-8, 1.0, base)

    data = (data - base) / np.maximum(np.abs(base), 1e-8)

    return normalize(
        data.reshape(len(indices), -1),
        norm="l2"
    ).astype(np.float32)


# Prepare reference features
buy_X = prepare_features(buy_idx)
sell_X = prepare_features(sell_idx)

# Prepare search model separately for BUY and SELL
os.makedirs("similarity", exist_ok=True)

def search_signals(reference_X, reference_idx, signal_name):

    model = NearestNeighbors(
        n_neighbors=min(TOP_K, len(reference_idx)),
        metric="cosine",
        algorithm="brute",
        n_jobs=-1
    )

    # Process unseen data in batches
    results = []

    for start in range(0, len(unseen_idx), BATCH_SIZE):

        batch_idx = unseen_idx[start:start+BATCH_SIZE]
        batch_X = prepare_features(batch_idx)

        model.fit(reference_X)

        distances, neighbors = model.kneighbors(batch_X)

        for i, unseen_id in enumerate(batch_idx):
            for j in range(len(neighbors[i])):

                similarity = 1.0 - distances[i][j]

                results.append({
                    "unseen_dataset_index": int(unseen_id),
                    "reference_dataset_index": int(
                        reference_idx[neighbors[i][j]]
                    ),
                    "signal": signal_name,
                    "similarity": float(similarity)
                })

        print(
            signal_name,
            min(start + BATCH_SIZE, len(unseen_idx)),
            "/",
            len(unseen_idx)
        )

    return pd.DataFrame(results)


# Search both signal classes
buy_results = search_signals(
    buy_X, buy_idx, "BUY"
)

sell_results = search_signals(
    sell_X, sell_idx, "SELL"
)

# Save results
buy_results.to_csv(
    "similarity/buy_matches.csv",
    index=False
)

sell_results.to_csv(
    "similarity/sell_matches.csv",
    index=False
)

# Combine results
combined = pd.concat(
    [buy_results, sell_results],
    ignore_index=True
)

combined.to_csv(
    "similarity/all_signal_matches.csv",
    index=False
)

print("\nSIMILARITY SEARCH COMPLETED")
print("BUY matches:", len(buy_results))
print("SELL matches:", len(sell_results))
print("Files saved in similarity/")
