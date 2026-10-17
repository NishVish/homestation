from django.urls import path
from . import views
from . import qr
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('', views.index),

    path('save-notes/', views.save_notes, name='save_notes'),
    path('save-csv/', views.save_csv, name='save_csv'),
    path('open-csv/', views.open_csv, name='open_csv'),

    path("qr/", qr.qr_page, name="qr_page"),
    path("qr/upload/", qr.qr_upload, name="qr_upload"),

        path("qr/last/", qr.last_qr),
    path("qr/all/", qr.all_qr),
# 👇 ADD THIS AT THE END ONLY
]
