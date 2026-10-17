from django.shortcuts import render
from django.http import JsonResponse
import cv2
import numpy as np


# -------- QR Decode Function --------
def decode_qr(image_bytes):
    npimg = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

    detector = cv2.QRCodeDetector()
    data, bbox, _ = detector.detectAndDecode(img)

    if data:
        save_qr_log(data)

    return data if data else None

# -------- Page View --------
def qr_page(request):
    return render(request, "qr.html")


# -------- API View --------
from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def qr_upload(request):
    if request.method == "POST":
        if "image" not in request.FILES:
            return JsonResponse({"result": None, "error": "No file"})

        file = request.FILES["image"]
        result = decode_qr(file.read())

        return JsonResponse({"result": result})

    return JsonResponse({"error": "POST only"})



import csv
import os
from datetime import datetime

CSV_FILE = "qr_logs.csv"


# create file if not exists
if not os.path.exists(CSV_FILE):
    with open(CSV_FILE, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["timestamp", "qr_data"])


def save_qr_log(data):
    if not data:
        return

    with open(CSV_FILE, "a", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            data
        ])






from django.http import JsonResponse

def last_qr(request):
    try:
        with open(CSV_FILE, "r") as f:
            rows = list(csv.reader(f))

        if len(rows) <= 1:
            return JsonResponse({"last_qr": None})

        last = rows[-1]
        return JsonResponse({
            "timestamp": last[0],
            "qr_data": last[1]
        })

    except Exception as e:
        return JsonResponse({"error": str(e)})


def all_qr(request):
    try:
        with open(CSV_FILE, "r") as f:
            reader = csv.DictReader(f)
            data = list(reader)

        return JsonResponse({"logs": data})

    except Exception as e:
        return JsonResponse({"error": str(e)})



