

# step 1
import pandas as pd

# Define path
file_path = r"C:\Users\nishw\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\MQL5\Files\EURUSD_PERIOD_CURRENT_ml_dataset.json"

# Load the JSON dataset
df = pd.read_json(file_path)

# View first few rows and summary info
print(df.head())
print(df.info())


# step 2


# 1. Access row1 dictionary from 'samples'
row1 = df['samples'].iloc[0]

# 2. Convert nested lists to DataFrames
df_raw = pd.json_normalize(row1['raw_data'])
df_candles = pd.json_normalize(row1['continuous_candle_group'])
df_market = pd.json_normalize(row1['market_analysis'])

# 3. Helper function to unstack rows into single row columns
def flatten_to_single_row(df_input, prefix=""):
    if df_input.empty:
        return pd.DataFrame()
    unstacked = df_input.unstack()
    new_cols = [f"{prefix}{col}_{idx}" for col, idx in unstacked.index]
    return pd.DataFrame([unstacked.values], columns=new_cols)

# 4. Flatten all sub-DataFrames
df_raw_1row = flatten_to_single_row(df_raw, prefix="raw_")
df_candles_1row = flatten_to_single_row(df_candles, prefix="group_")
df_market_1row = flatten_to_single_row(df_market, prefix="market_")

# 5. Concatenate side-by-side into 1 single row
master_single_row = pd.concat([df_raw_1row, df_candles_1row, df_market_1row], axis=1)

# 6. Export to CSV (index=False avoids adding an unneeded row index)
master_single_row.to_csv("flattened_ml_dataset.csv", index=False)

print("Dataset exported successfully!")

# step 3

insert that into sql databse
