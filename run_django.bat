@echo off
cd /d "%~dp0"

echo Starting Django...
".\.venv\Scripts\python.exe" manage.py runserver 0.0.0.0:8000

pause