from django.shortcuts import render
from pathlib import Path
import re
from django.http import JsonResponse
from django.views.decorators.http import require_POST
import json

LARAVEL_PROJECT = Path(
    r"C:\xampp\htdocs\iitm\base"
)


# -----------------------------
# FILE READER
# -----------------------------

def read_file(path):

    try:
        return Path(path).read_text(
            encoding="utf-8"
        )

    except:
        return ""



# -----------------------------
# CONTROLLERS
# -----------------------------

def get_controllers():

    path = (
        LARAVEL_PROJECT
        /
        "app"
        /
        "Http"
        /
        "Controllers"
    )

    controllers = []

    if path.exists():

        for file in path.rglob("*Controller.php"):

            controllers.append({

                "name": file.stem,

                "file": str(file),

                "relative": str(
                    file.relative_to(
                        LARAVEL_PROJECT
                    )
                )
            })

    return controllers



# -----------------------------
# MODELS
# -----------------------------

def get_models():

    path = (
        LARAVEL_PROJECT
        /
        "app"
        /
        "Models"
    )

    models = []

    if path.exists():

        for file in path.rglob("*.php"):

            models.append({

                "name": file.stem,

                "file": str(file),

                "relative": str(
                    file.relative_to(
                        LARAVEL_PROJECT
                    )
                )
            })

    return models



# -----------------------------
# EXTRACT REFERENCES
# -----------------------------

def extract_models(code):

    return list(
        set(
            re.findall(
                r"use\s+App\\Models\\(\w+);",
                code
            )
        )
    )



def extract_views(code):

    return list(
        set(
            re.findall(
                r"view\(['\"]([^'\"]+)",
                code
            )
        )
    )



def extract_controllers(code):

    return list(
        set(
            re.findall(
                r"use\s+App\\Http\\Controllers\\(\w+);",
                code
            )
        )
    )



# -----------------------------
# FIND RELATED FILES
# -----------------------------

def find_model_files(models):

    result = []

    for model in models:

        file = (
            LARAVEL_PROJECT
            /
            "app"
            /
            "Models"
            /
            f"{model}.php"
        )

        if file.exists():

            result.append({

                "name": model,

                "path": str(file),

                "code": read_file(file)

            })

    return result



def find_views(view_names):

    result = []

    view_path = (
        LARAVEL_PROJECT
        /
        "resources"
        /
        "views"
    )


    for name in view_names:

        file_name = (
            name.replace(
                ".",
                "/"
            )
            +
            ".blade.php"
        )


        file = (
            view_path
            /
            file_name
        )


        if file.exists():

            result.append({

                "name": name,

                "path": str(file),

                "code": read_file(file)

            })


    return result


def find_routes():

    routes = []

    for name in [
        "web.php",
        "api.php"
    ]:

        file = (
            LARAVEL_PROJECT
            /
            "routes"
            /
            name
        )

        if file.exists():

            routes.append({

                "name": name,

                "path": str(file),

                "code": read_file(file)

            })

    return routes



# -----------------------------
# LOAD CONTROLLER CONTEXT
# -----------------------------
def load_controller_context(controller_name):

    controller_code = ""
    controller_file = ""

    controller_path = (
        LARAVEL_PROJECT
        /
        "app"
        /
        "Http"
        /
        "Controllers"
    )

    for file in controller_path.rglob(
        controller_name + ".php"
    ):

        controller_code = read_file(file)
        controller_file = str(file)

    models = extract_models(
        controller_code
    )

    views = extract_views(
        controller_code
    )

    controllers = extract_controllers(
        controller_code
    )

    return {

        "current_controller":
            controller_name,

        "controller_code":
            controller_code,

        "controller_file":
            controller_file,

        "models":
            find_model_files(models),

        "views":
            find_views(views),

        "controllers":
            controllers,

        "routes":
            find_routes()

    }


# -----------------------------
# MAIN FUNCTION
# -----------------------------

def files_based_on_controller(
    current_controller=None
):

    data = {

        "controllers":
            get_controllers(),

        "context":
            {}

    }


    if current_controller:

        data["context"] = (
            load_controller_context(
                current_controller
            )
        )


    return data



# -----------------------------
# DJANGO VIEW
# -----------------------------
def index(request):

    selected = request.GET.get(
        "controller"
    )

    data = files_based_on_controller(
        selected
    )


    print("\n================")
    print("SELECTED:", selected)

    print(
        "CONTEXT KEYS:",
        data["context"].keys()
    )


    if "controller_code" in data["context"]:
        print(
            data["context"]["controller_code"][:200]
        )

    print("================\n")


    return render(
        request,
        "editor/index.html",
        {
            "controllers":
                data["controllers"],

            "selected":
                selected,

            "context":
                data["context"]
        }
    )
@require_POST
def save_file(request):

    try:

        data = json.loads(
            request.body
        )

        file_path = data.get("path")
        code = data.get("code")

        if not file_path:
            return JsonResponse({
                "success": False,
                "error": "No file path supplied"
            }, status=400)

        if code is None:
            return JsonResponse({
                "success": False,
                "error": "No code supplied"
            }, status=400)


        file_path = Path(file_path).resolve()
        project_path = LARAVEL_PROJECT.resolve()


        # SECURITY:
        # Only allow files inside the Laravel project.
        try:
            file_path.relative_to(project_path)

        except ValueError:

            return JsonResponse({
                "success": False,
                "error": "Invalid file path"
            }, status=403)


        file_path.write_text(
            code,
            encoding="utf-8"
        )


        return JsonResponse({
            "success": True,
            "message": f"Saved {file_path.name}"
        })


    except Exception as e:

        return JsonResponse({
            "success": False,
            "error": str(e)
        }, status=500)