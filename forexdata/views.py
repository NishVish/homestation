import json

from django.http import JsonResponse
from django.shortcuts import render


def index(request):
    return render(
        request,
        "forexdata/index.html",
    )


def test(request):
    return JsonResponse(
        {
            "status": "ok",
            "message": "Django is reachable",
            "method": request.method,
        }
    )


def rawdata(request, timeframe):
    if request.method != "POST":
        return JsonResponse(
            {
                "error": "POST request required",
                "method": request.method,
                "timeframe": timeframe,
            },
            status=405,
        )

    try:
        data = json.loads(request.body)

        return JsonResponse(
            {
                "status": "ok",
                "message": "Raw data received",
                "timeframe": timeframe,
                "symbol": data.get("symbol"),
                "candles_count": len(
                    data.get("candles", [])
                ),
            }
        )

    except json.JSONDecodeError:
        return JsonResponse(
            {
                "error": "Invalid JSON"
            },
            status=400,
        )
