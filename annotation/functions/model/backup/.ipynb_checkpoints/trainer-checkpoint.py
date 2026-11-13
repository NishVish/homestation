import json
import mysql.connector
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder

# ONNX specific imports
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType


def get_connection():
  return mysql.connector.connect(
      host="localhost",
      user="root",
      password="",
      database="marketdata",
  )


def train_models_and_export_onnx():
  """Fetches annotated data where edited = '1', trains Random Forest models

  for each annotation target, exports them to .onnx, and saves their label classes.
  """
  # ------------------------------------------
  # 1. FETCH DATA FROM MYSQL WITH CONSTRAINT
  # ------------------------------------------
  try:
    db = get_connection()
    query = 'SELECT * FROM `labeled_flatdata` WHERE `edited` = "1"'
    df = pd.read_sql(query, db)
    print(
        f"Successfully loaded {len(df)} filtered rows (edited = '1') from MySQL"
        " database."
    )
  except Exception as e:
    print(f"Database connection or query failed: {e}")
    df = pd.DataFrame()
    return
  finally:
    if "db" in locals() and db.is_connected():
      db.close()

  # ------------------------------------------
  # 2. PROCEED ONLY IF DATA IS LOADED
  # ------------------------------------------
  if df.empty:
    print(
        "DataFrame is empty. Check your database connection, credentials, and"
        " whether any rows have edited = '1'."
    )
    return

  annotation_columns = [
      "was",
      "then",
      "currently",
      "future",
      "volatility",
      "bias",
      "phase",
      "momentum_direction",
      "momentum_strength",
      "setup",
      "momentum_candle",
      "decision",
  ]

  valid_targets = [col for col in annotation_columns if col in df.columns]
  print(f"Valid target columns found: {valid_targets}\n")

  # ------------------------------------------
  # 3. INPUT FEATURES: M1 PRICE COLUMNS
  # ------------------------------------------
  feature_columns = [
      col
      for col in df.columns
      if col.startswith("M1_")
      and not col.endswith("_time")
      and col.rsplit("_", 1)[-1] in {"open", "high", "low", "close"}
  ]

  X = df[feature_columns].copy()
  X = X.apply(pd.to_numeric, errors="coerce")
  X = X.replace([np.inf, -np.inf], np.nan)

  # ------------------------------------------
  # 4. TRAIN, EXPORT ONNX, & SAVE CLASSES JSON
  # ------------------------------------------
  models = {}
  label_encoders = {}
  results = {}

  for target in valid_targets:
    y_series = df[target].fillna("").astype(str).str.strip()
    valid = (
        df[target].notna()
        & y_series.ne("")
        & y_series.ne("nan")
        & y_series.ne("None")
        & y_series.ne("NULL")
    )

    X_target = X.loc[valid]
    y_raw = y_series.loc[valid]

    print(f"Target '{target}': found {len(y_raw)} valid labeled rows.")

    if len(y_raw) < 2:
      print(
          f"Skipping {target}: insufficient labeled rows ({len(y_raw)} found,"
          " need at least 2)."
      )
      continue

    encoder = LabelEncoder()
    y = encoder.fit_transform(y_raw)

    if len(encoder.classes_) < 2:
      print(
          f"Skipping {target}: only one unique label found ({encoder.classes_}).\n"
      )
      continue

    class_counts = pd.Series(y).value_counts()
    stratify = y if class_counts.min() >= 2 else None
    test_size = 0.2 if len(X_target) >= 5 else 0.5

    X_train, X_test, y_train, y_test = train_test_split(
        X_target,
        y,
        test_size=test_size,
        random_state=42,
        stratify=stratify,
    )

    model = Pipeline([
        ("imputer", SimpleImputer(strategy="median")),
        (
            "classifier",
            RandomForestClassifier(
                n_estimators=100,
                random_state=42,
                class_weight="balanced",
                n_jobs=-1,
            ),
        ),
    ])

    model.fit(X_train, y_train)

    predictions = model.predict(X_test)
    accuracy = accuracy_score(y_test, predictions)

    models[target] = model
    label_encoders[target] = encoder

    results[target] = {
        "accuracy": accuracy,
        "training_rows": len(X_train),
        "testing_rows": len(X_test),
        "classes": list(encoder.classes_),
    }

    print(f"\n{'=' * 50}")
    print(f"TARGET: {target}")
    print(f"Accuracy: {accuracy:.2%}")

    # 1. Export ONNX Model
    try:
      initial_type = [("float_input", FloatTensorType([None, X_target.shape[1]]))]
      onnx_model = convert_sklearn(model, initial_types=initial_type)

      onnx_filename = f"model_{target}.onnx"
      with open(onnx_filename, "wb") as f:
        f.write(onnx_model.SerializeToString())

      # 2. Save corresponding class labels JSON
      classes_filename = f"classes_{target}.json"
      with open(classes_filename, "w") as f:
        json.dump(list(encoder.classes_), f)

      print(f"Successfully exported '{onnx_filename}' and '{classes_filename}'")
    except Exception as e:
      print(f"Failed to export {target}: {e}")

    print("-" * 50 + "\n")

  if results:
    results_df = pd.DataFrame(results).T
    return results_df
  
  return None