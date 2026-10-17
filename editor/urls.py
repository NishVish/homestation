from django.urls import path
from . import views


urlpatterns = [
    path("", views.index, name="index"),
    path("save-file/", views.save_file, name="save_file"),
]