
from django.urls import path

from . import views

from .functions.fetchcandle import (
    get_by_id_with_neighbors,
    fetch_candle_by_date,
)

from .functions.interface import interface
from .functions.savecandle import savecandle
from .functions.sql_operation import execute_sql

from .functions.dashboard import dashboard

from .functions.data.loadcsvtodf import loadcsvtodf
from .functions.data.migratecsvtosql import migrate_data


urlpatterns = [
    path("", dashboard, name="dashboard"),

    path("index/", views.index, name="index"),

    path("loadcsvtodf/", loadcsvtodf, name="loadcsvtodf"),
    path("migratecsvtosql/", migrate_data, name="migrate_data"),

    path(
        "candle/id/<int:id>/",
        get_by_id_with_neighbors,
        name="get_by_id_with_neighbors",
    ),
    path(
        "candle/id/<int:id>/",
        get_by_id_with_neighbors,
        name="get_by_id_with_neighbors",
    ),
    path(
    "fetch_candle_by_date/<str:date_str>/<str:time_str>/",
    fetch_candle_by_date,
    name="fetch_candle_by_date",
),

    path(
        "interface/<int:candleid>/",
        interface,
        name="interface",
    ),

    path("execute-sql/", execute_sql, name="execute_sql"),

    path("savecandle/", savecandle, name="savecandle"),
]
