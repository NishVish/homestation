
import os
import json
import time
import logging

import numpy as np
from sklearn.cluster import MiniBatchKMeans
from sklearn.metrics import silhouette_score

# =====================================================
# CONFIGURATION
# =====================================================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DATASET_DIR = os.path.join(BASE_DIR, "dataset")
CLUSTER_DIR = os.path.join(BASE_DIR, "clusters")
LOG_DIR = os.path.join(BASE_DIR, "logs")

os.makedirs(CLUSTER_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)

X_PATH = os.path.join(DATASET_DIR, "X_ohlc.npy")
Y_PATH = os.path.join(DATASET_DIR, "y.npy")
STATUS_PATH = os.path.join(DATASET_DIR, "status.npy")

N_CLUSTERS = 15
BATCH_SIZE = 10000
EPOCHS = 5
RANDOM_STATE = 42

# =====================================================
# LOGGING
# =====================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.FileHandler(
            os.path.join(LOG_DIR, "clustering.log")
        ),
        logging.StreamHandler()
    ]
)

log = logging.getLogger(__name__)

# =====================================================
# LOAD DATA
# =====================================================

log.info("Loading datasets using memory mapping")

X = np.load(X_PATH, mmap_mode="r")
y = np.load(Y_PATH, mmap_mode="r")
status = np.load(STATUS_PATH, mmap_mode="r")

N = X.shape[0]

assert X.shape == (N, 4, 20, 4)
assert X.dtype == np.float32
assert y.shape == (N,)
assert status.shape == (N,)

FEATURES = 4 * 20 * 4

log.info(f"Samples: {N:,}")
log.info(f"Features: {FEATURES}")
log.info(f"Clusters: {N_CLUSTERS}")

# =====================================================
# MODEL
# =====================================================

model = MiniBatchKMeans(
    n_clusters=N_CLUSTERS,
    batch_size=BATCH_SIZE,
    init="k-means++",
    random_state=RANDOM_STATE,
    n_init=3,
    reassignment_ratio=0.01
)

# =====================================================
# INCREMENTAL TRAINING
# =====================================================

log.info("Starting incremental clustering")

start = time.time()

for epoch in range(EPOCHS):

    log.info(f"Epoch {epoch + 1}/{EPOCHS}")

    for start_idx in range(0, N, BATCH_SIZE):

        end_idx = min(start_idx + BATCH_SIZE, N)

        batch = np.asarray(
            X[start_idx:end_idx],
            dtype=np.float32
        ).reshape(-1, FEATURES)

        if epoch == 0 and start_idx == 0:
            model.partial_fit(batch)
        else:
            model.partial_fit(batch)

        if start_idx % (BATCH_SIZE * 10) == 0:
            log.info(
                f"Processed epoch batch: "
                f"{end_idx:,}/{N:,}"
            )

    # Save checkpoint after each epoch
    import joblib

    joblib.dump(
        model,
        os.path.join(
            CLUSTER_DIR,
            f"kmeans_epoch_{epoch + 1}.pkl"
        )
    )

    log.info(f"Epoch {epoch + 1} checkpoint saved")

# =====================================================
# ASSIGN CLUSTERS
# =====================================================

log.info("Assigning cluster labels")

labels = np.lib.format.open_memmap(
    os.path.join(CLUSTER_DIR, "cluster_labels.npy"),
    mode="w+",
    dtype=np.int16,
    shape=(N,)
)

for start_idx in range(0, N, BATCH_SIZE):

    end_idx = min(start_idx + BATCH_SIZE, N)

    batch = np.asarray(
        X[start_idx:end_idx],
        dtype=np.float32
    ).reshape(-1, FEATURES)

    labels[start_idx:end_idx] = model.predict(batch)

    log.info(f"Assigned {end_idx:,}/{N:,}")

labels.flush()

# =====================================================
# SAVE CENTERS
# =====================================================

centers = model.cluster_centers_

np.save(
    os.path.join(CLUSTER_DIR, "cluster_centers.npy"),
    centers
)

# =====================================================
# CLUSTER POPULATIONS
# =====================================================

counts = np.bincount(
    labels,
    minlength=N_CLUSTERS
)

log.info("Cluster populations:")

for cluster_id, count in enumerate(counts):
    log.info(
        f"Cluster {cluster_id}: "
        f"{count:,} ({count / N * 100:.2f}%)"
    )

# =====================================================
# SILHOUETTE SCORE
# =====================================================

log.info("Calculating representative silhouette score")

rng = np.random.default_rng(RANDOM_STATE)

sample_indices = rng.choice(
    N,
    size=min(10000, N),
    replace=False
)

sample_X = np.asarray(
    X[sample_indices],
    dtype=np.float32
).reshape(-1, FEATURES)

sample_labels = np.asarray(labels[sample_indices])

silhouette = silhouette_score(
    sample_X,
    sample_labels,
    metric="euclidean"
)

# =====================================================
# LABEL DISTRIBUTION
# =====================================================

report = []

for cluster_id in range(N_CLUSTERS):

    mask = labels[:] == cluster_id

    cluster_y = np.asarray(y[mask])
    cluster_status = np.asarray(status[mask])

    report.append({
        "cluster": int(cluster_id),
        "count": int(counts[cluster_id]),
        "buy": int(np.sum(cluster_y == 1)),
        "sell": int(np.sum(cluster_y == -1)),
        "none": int(np.sum(cluster_status == 2))
    })

# =====================================================
# SAVE RESULTS
# =====================================================

results = {
    "samples": int(N),
    "features": int(FEATURES),
    "clusters": N_CLUSTERS,
    "epochs": EPOCHS,
    "batch_size": BATCH_SIZE,
    "inertia": float(model.inertia_),
    "silhouette_sample": float(silhouette),
    "cluster_populations": counts.tolist(),
    "cluster_report": report,
    "runtime_seconds": round(time.time() - start, 2)
}

with open(
    os.path.join(CLUSTER_DIR, "cluster_metrics.json"),
    "w"
) as f:
    json.dump(results, f, indent=4)

import csv

with open(
    os.path.join(CLUSTER_DIR, "cluster_report.csv"),
    "w",
    newline=""
) as f:

    writer = csv.DictWriter(
        f,
        fieldnames=report[0].keys()
    )

    writer.writeheader()
    writer.writerows(report)

joblib.dump(
    model,
    os.path.join(CLUSTER_DIR, "kmeans_final.pkl")
)

log.info("CLUSTERING COMPLETED")
log.info(f"Silhouette: {silhouette:.5f}")
log.info(f"Inertia: {model.inertia_:.4f}")
