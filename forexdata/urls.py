from django.urls import path
from . import views

urlpatterns = [
    path("", views.index, name="index"),
    path("index/", views.index, name="index"),

    path("test/", views.test, name="test"),

    path("raw/<str:timeframe>/", views.rawdata, name="rawdata"),
]
