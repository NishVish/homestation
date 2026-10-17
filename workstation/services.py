from pathlib import Path
from django.conf import settings

BASE_DIR = Path(settings.BASE_DIR)

CSV_PATH = BASE_DIR / "workstation" / "files" / "bookmarks.csv"
TXT_PATH = BASE_DIR / "workstation" / "files" / "notes.txt"


def read_csv():
    return CSV_PATH.read_text(encoding="utf-8")


def write_csv(content):
    CSV_PATH.write_text(content, encoding="utf-8")


def read_notes():
    return TXT_PATH.read_text(encoding="utf-8")


def write_notes(content):
    TXT_PATH.write_text(content, encoding="utf-8")
