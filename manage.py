#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""

from django.core.serializers import json
import os
import sys
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent


from django.http import HttpResponse


def index(request):
    return HttpResponse("hello")

def register_app(app_name):
    settings_file = BASE_DIR / "config" / "settings.py"

    content = settings_file.read_text(encoding="utf-8")

    if f'"{app_name}"' not in content and f"'{app_name}'" not in content:
        start = content.find("INSTALLED_APPS = [")
        if start != -1:
            end = content.find("]", start)

            if end != -1:
                content = (
                    content[:end]
                    + f'    "{app_name}",\n'
                    + content[end:]
                )

                settings_file.write_text(content, encoding="utf-8")
                print(f"Registered '{app_name}' in INSTALLED_APPS.")


def create_urls(app_path, app_name):
    urls_file = app_path / "urls.py"

    urls_file.write_text(
        f'''from django.urls import path
from . import views


urlpatterns = [
    path("index/", views.index, name="index"),
]
''',
        encoding="utf-8",
    )


def create_view(app_path, app_name):
    views_file = app_path / "views.py"

    views_file.write_text(
        f'''from django.shortcuts import render


def index(request):
    return render(request, "{app_name}/index.html")
''',
        encoding="utf-8",
    )


def create_template(app_path, app_name):
    template_dir = app_path / "templates" / app_name
    template_dir.mkdir(parents=True, exist_ok=True)

    index_file = template_dir / "index.html"

    index_file.write_text(
        f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{app_name}</title>
</head>
<body>

    <h1>{app_name}</h1>

</body>
</html>
''',
        encoding="utf-8",
    )


def register_urls(app_name):
    root_urls = BASE_DIR / "config" / "urls.py"

    if not root_urls.exists():
        print("config/urls.py not found.")
        return

    content = root_urls.read_text(encoding="utf-8")

    include_import = "from django.urls import include, path"

    if "from django.urls import include, path" not in content:
        content = content.replace(
            "from django.urls import path",
            include_import,
        )

    app_include = f'path("{app_name}/", include("{app_name}.urls")),'

    if app_include not in content:
        marker = "urlpatterns = ["

        if marker in content:
            content = content.replace(
                marker,
                f"{marker}\n    {app_include}",
                1,
            )
        else:
            content += f'''

urlpatterns = [
    {app_include}
]
'''

    root_urls.write_text(content, encoding="utf-8")


def setup_app(app_name):
    app_path = BASE_DIR / app_name

    if not app_path.exists():
        print(f"App directory '{app_name}' was not created.")
        return

    register_app(app_name)
    create_urls(app_path, app_name)
    create_view(app_path, app_name)
    create_template(app_path, app_name)
    register_urls(app_name)

    print()
    print(f"App '{app_name}' setup completed.")
    print()
    print(f"URL: http://127.0.0.1:8000/{app_name}/index/")
    print()


def main():
    """Run administrative tasks."""

    os.environ.setdefault(
        "DJANGO_SETTINGS_MODULE",
        "config.settings",
    )

    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed?"
        ) from exc

    is_startapp = (
        len(sys.argv) >= 3
        and sys.argv[1] == "startapp"
    )

    app_name = sys.argv[2] if is_startapp else None

    execute_from_command_line(sys.argv)

    if is_startapp:
        setup_app(app_name)


if __name__ == "__main__":
    main()
