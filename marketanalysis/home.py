import os
import glob
import pandas as pd
import sqlalchemy
import traceback
from django.http import JsonResponse
from django.shortcuts import render
from .sqlconnection import get_connection, close_connection


def index(request):
    return render(request, "home.html")


def loadcsvtodf(request):
    filespath = r"C:\Users\nishw\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\MQL5\Files"
    
    search_pattern = os.path.join(filespath, "*_ml_dataset.csv")
    csv_files = glob.glob(search_pattern)
    
    if not csv_files:
        return JsonResponse({"status": "error", "message": "No CSV dataset file found."}, status=404)
    
    latest_file = max(csv_files, key=os.path.getmtime)
    df = pd.read_csv(latest_file)
    
    return JsonResponse({
        "status": "success",
        "filename": os.path.basename(latest_file),
        "head": df.head().to_dict(orient="records")
    })


def migratedatatodb(request):
    filespath = r"C:\Users\nishw\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\MQL5\Files"
    
    search_pattern = os.path.join(filespath, "*_ml_dataset.csv")
    csv_files = glob.glob(search_pattern)
    
    if not csv_files:
        return JsonResponse({"status": "error", "message": "No CSV dataset file found."}, status=404)
    
    latest_file = max(csv_files, key=os.path.getmtime)
    df = pd.read_csv(latest_file)
    
    # Filter columns: keep 'id' and any column containing '1min'
    cols_to_keep = ['id'] + [col for col in df.columns if '1min' in col]
    df_filtered = df[cols_to_keep].copy()
    
    # Add annotation columns with default initial values so they exist in MySQL after migration
    df_filtered['analysis'] = ""
    df_filtered['bias'] = ""
    df_filtered['phase'] = ""
    df_filtered['momentum'] = ""
    df_filtered['decision'] = ""
    df_filtered['edited'] = False
    df_filtered['edittime'] = None
    
    table_name = "ml_1min_features"
    
    try:
        # Create SQLAlchemy engine using your custom get_connection function as the creator
        engine = sqlalchemy.create_engine(
            "mysql+mysqlconnector://",
            creator=get_connection
        )
        
        # Insert filtered DataFrame into the database table
        df_filtered.to_sql(table_name, con=engine, if_exists='replace', index=False)
        
    except Exception as e:
        print("=== MIGRATION ERROR ===")
        traceback.print_exc()
        return JsonResponse({"status": "error", "message": str(e)}, status=500)
    
    column_count = len(df_filtered.columns)
    entry_count = len(df_filtered)
    head_data = df_filtered.head().to_dict(orient="records")
    
    return JsonResponse({
        "status": "success",
        "message": f"Successfully migrated data into table '{table_name}' with annotation columns.",
        "column_count": column_count,
        "entry_count": entry_count,
        "head": head_data
    })