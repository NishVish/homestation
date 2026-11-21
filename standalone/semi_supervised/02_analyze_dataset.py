
import os
import json
import numpy as np

DIR = "dataset"
CHUNK = 20000

with open(os.path.join(DIR, "metadata.json")) as f:
    meta = json.load(f)

N = meta["valid_rows"]

X = np.load(
    os.path.join(DIR, "X_ohlc.npy"),
    mmap_mode="r"
)

y = np.load(
    os.path.join(DIR, "y.npy"),
    mmap_mode="r"
)

status = np.load(
    os.path.join(DIR, "status.npy"),
    mmap_mode="r"
)

print("\n========== FILE VALIDATION ==========")

print("X:", X.shape, X.dtype)
print("y:", y.shape, y.dtype)
print("status:", status.shape, status.dtype)

assert X.shape[0] >= N
assert X.shape[1:] == (4, 20, 4)
assert len(y) >= N
assert len(status) >= N

print("\n========== LABEL VALIDATION ==========")

labels = y[:N]
statuses = status[:N]

for name, value in [
    ("BUY", 0),
    ("SELL", 1),
    ("UNLABELED", -1)
]:
    print(name, int(np.sum(labels == value)))

print("\n========== STATUS VALIDATION ==========")

for name, value in [
    ("UNSEEN", 0),
    ("REVIEWED NONE", 1),
    ("REVIEWED BUY", 2),
    ("REVIEWED SELL", 3)
]:
    print(name, int(np.sum(statuses == value)))

print("\n========== OHLC VALIDATION ==========")

global_min = float("inf")
global_max = float("-inf")
invalid = 0

for start in range(0, N, CHUNK):

    end = min(start + CHUNK, N)

    chunk = X[start:end]

    invalid += int(
        (~np.isfinite(chunk)).sum()
    )

    global_min = min(
        global_min,
        float(chunk.min())
    )

    global_max = max(
        global_max,
        float(chunk.max())
    )

print("Invalid values:", invalid)
print("Minimum:", global_min)
print("Maximum:", global_max)

print("\n========== STORAGE ==========")

for filename in [
    "X_ohlc.npy",
    "y.npy",
    "status.npy",
    "metadata.json"
]:

    path = os.path.join(DIR, filename)

    print(
        filename,
        round(os.path.getsize(path) / 1024**2, 2),
        "MB"
    )

print("\nDATASET VALIDATION COMPLETED")
