from django.core.serializers import json
import os
import duckdb
from django.http import JsonResponse
from django.shortcuts import render
from django.http import HttpResponse

# Path to the DuckDB file

import mysql.connector
from django.http import HttpResponse


def index(request):

 return render(request, "annotation/home/index.html")