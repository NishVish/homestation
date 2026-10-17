from django.urls import path
from . import views

from .functions.fetchcandle import get_by_id_with_neighbors
from .functions.interface import interface
from .functions.savecandle import savecandle
from .functions.dashboard import dashboard


urlpatterns = [
    path("", views.index, name="index"),

    path("<int:id>/", get_by_id_with_neighbors, name="get_by_id_with_neighbors"),
    
    
    path(
        "interface/<int:candleid>/",
        interface,
        name="interface"
    ),

    path("savecandle/", savecandle, name="savecandle"),
        path("", dashboard, name="dashboard"),

]   

