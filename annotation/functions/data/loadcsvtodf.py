import os
import pandas as pd

from django.http import JsonResponse


def loadcsvtodf(request):
    file_path = (
        r"C:\Users\nishw\AppData\Roaming\MetaQuotes\Tester"
        r"\D0E8209F77C8CF37AD8BF550E51FF075"
        r"\Agent-127.0.0.1-3000\MQL5\Files\labeled_flatdata.csv"
    )

    try:
        df = pd.read_csv(file_path)

        return JsonResponse({
            "filename": os.path.basename(file_path),
            "total_rows": len(df),
            "columns": df.columns.tolist(),
            "data": df.head(10).to_dict(orient="records"),
        }, safe=True)

    except Exception as e:
        return JsonResponse({
            "error": str(e)
        }, status=500)