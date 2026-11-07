from django.urls import path
from . import views

from .functions.fetchcandle import get_by_id_with_neighbors
from .functions.interface import interface
from .functions.savecandle import savecandle
from .functions.dashboard import dashboard
from .functions.data.loadcsvtodf import loadcsvtodf
from .functions.data.migratecsvtosql import migrate_data

urlpatterns = [
    path("", views.index, name="index"),

    path("loadcsvtodf/", loadcsvtodf, name="loadcsvtodf"),
    path("migratecsvtosql/", migrate_data, name="migrate_data"),

    path("<int:id>/", get_by_id_with_neighbors, name="get_by_id_with_neighbors"),
    
    
    path(
        "interface/<int:candleid>/",
        interface,
        name="interface"
    ),

    path("savecandle/", savecandle, name="savecandle"),
        path("", dashboard, name="dashboard"),

]   

