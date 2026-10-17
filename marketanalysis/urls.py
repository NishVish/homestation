from django.urls import path
from . import views
from . import updatebyid
from . import home
from . import loadcsvtosql
from . import candledata

urlpatterns = [
    path("", home.index),
    path("migration/", loadcsvtosql.loadcsvtosql),
    
    # New paths for loadcsvtodf and migratedatatodb
    path("load-csv-df/", home.loadcsvtodf),
    path("migrate-db/", home.migratedatatodb),

    path("<int:id>/", views.databyidview),
    path("updatedata/", views.updatedata),
    path("data/", views.data),
    path("candledata/<int:id>/", candledata.candledata),
    path("updatebyid/<int:id>/", updatebyid.updatebyid),
]