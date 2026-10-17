import subprocess
from pathlib import Path
from django.conf import settings
from django.http import JsonResponse
from django.shortcuts import render
import socket

BASE_FILES = Path(settings.BASE_DIR) / "workstation" / "files"

CSV_PATH = BASE_FILES / "bookmarks.csv"
NOTES_PATH = BASE_FILES / "notes.txt"


import csv
from collections import defaultdict
import csv
from collections import defaultdict
from django.shortcuts import render

def index(request):
    bookmarks_grouped = defaultdict(list)
    
    if CSV_PATH.exists():
        with open(CSV_PATH, mode="r", encoding="utf-8-sig") as f: # utf-8-sig handles Excel BOM characters
            # Detects your CSV delimiter automatically (comma, semicolon, or tab)
            try:
                dialect = csv.Sniffer().sniff(f.read(1024))
                f.seek(0)
                reader = csv.reader(f, dialect)
            except csv.Error:
                # Fallback to standard comma reader if file is too small to sniff
                f.seek(0)
                reader = csv.reader(f)

            for row in reader:
                # Skip empty lines or malformed rows (we need at least 3 columns: title, group, link)
                if not row or len(row) < 3:
                    continue
                
                # Header row protection: skip if this is the column header line
                if row[0].lower().strip() == "title" and row[1].lower().strip() == "group":
                    continue

                title = row[0].strip()
                group = row[1].strip()
                href = row[2].strip()
                
                # Basic validation: ensure all necessary fields are present
                if title and group and href:
                    # Grouping by the 'group' field so your template can iterate over categories
                    bookmarks_grouped[group].append({
                        "title": title,
                        "link": href
                    })
    
    notes_content = ""
    if NOTES_PATH.exists():
        notes_content = NOTES_PATH.read_text(encoding="utf-8")
    server_ip = socket.gethostbyname(socket.gethostname())

    context = {
        "groups": dict(bookmarks_grouped),
        "notes": notes_content,
        "server_ip": server_ip,
    }

    return render(request, "workstation/index.html", context)
import json
import logging
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt # Use this temporarily if CSRF is blocking you

# Setup a basic terminal logger to catch errors
logger = logging.getLogger(__name__)
from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def save_notes(request):
    if request.method == "POST":
        try:
            # 1. Decode and safely parse the incoming JSON data
            data = json.loads(request.body.decode('utf-8'))
            
            # Use data.get() with a default value of None so we can check if it exists
            new_notes = data.get("notes", None)
            
            if new_notes is None:
                return JsonResponse({"status": "error", "message": "No data found under 'notes' key."}, status=400)
            
            # 2. Ensure the destination directory exists
            NOTES_PATH.parent.mkdir(parents=True, exist_ok=True)
            
            # 3. Write the notes to your text file safely
            NOTES_PATH.write_text(new_notes, encoding="utf-8")
            
            print(f"--- SUCCESS: Wrote {len(new_notes)} characters to {NOTES_PATH} ---")
            return JsonResponse({"status": "success", "message": "Saved successfully"})
            
        except json.JSONDecodeError as je:
            print(f"--- JSON ERROR: Failed to parse request body. {str(je)} ---")
            return JsonResponse({"status": "error", "message": "Invalid JSON"}, status=400)
        except Exception as e:
            print(f"--- BACKEND ERROR: {str(e)} ---")
            return JsonResponse({"status": "error", "message": str(e)}, status=500)
            
    return JsonResponse({"status": "error", "message": "Method not allowed"}, status=405)

def save_csv(request):
    if request.method == "POST":
        CSV_PATH.write_text(request.POST.get("content", ""), encoding="utf-8")
        return JsonResponse({"status": "ok"})
import subprocess
from pathlib import Path

import os
from django.shortcuts import redirect
from django.contrib import messages
# Import your CSV_PATH variable wherever it is defined

def open_csv(request):
    """
    Opens the bookmark.csv file in Windows Notepad when the user visits the URL.
    """
    if CSV_PATH.exists():
        # os.startfile opens the file with its default app (usually Notepad for CSVs),
        # or you can force notepad.exe explicitly like this:
        os.system(f'notepad.exe "{CSV_PATH}"')
        
        # Optional: Add a success message if your template supports Django messages
        messages.success(request, "Opened CSV in Notepad!")
    else:
        messages.error(request, "CSV file not found.")

    # Redirect back to the index page (or wherever you want them to land)
    return redirect('index')


def camera(request):
    return render(request, "camera.html")


def view(request):
    return render(request, "view.html")




