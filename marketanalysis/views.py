from django.shortcuts import render
from django.http import JsonResponse
import sys
import os
import pandas as pd
# pyrefly: ignore [missing-import]
import mysql.connector
# pyrefly: ignore [missing-import]
from mysql.connector import Error

from django.http import HttpResponse



sys.path.append(os.getcwd())

from .sqlconnection import get_connection, close_connection
from .loadcsvtosql import loadcsvtosql
from .loadsqltodf import loadsqltodf


conn = get_connection()

def updatedata(request):
    print("--- UPDATING DATA ---")
    loadcsvtosql()
    print("--- DATA UPDATED ---")
    return JsonResponse({"status": "success"})

def buildtable(request):
    print("--- BUILDING TABLE ---")
    df = loadsqltodf()
    return JsonResponse({"status": "success"})

def dashboard(request):
    return render(request, "system.html")

import json

# def data(request, timeframe):
#     conn = get_connection()
#     cursor = conn.cursor()

#     cursor.execute(f"SELECT `{timeframe}` FROM jsonformat LIMIT 10")

#     rows = cursor.fetchall()

#     cursor.close()
#     conn.close()

#     data = [json.loads(row[0]) for row in rows]

#     return JsonResponse({"data": data})



from django.http import JsonResponse

def data(request):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM multitimeframe_snapshot LIMIT 10")
    rows = cursor.fetchall()

    # get column names (headers)
    columns = [desc[0] for desc in cursor.description]

    cursor.close()
    conn.close()

    # convert rows into list of dicts
    data = [dict(zip(columns, row)) for row in rows]

    return JsonResponse({
        # "columns": columns,
        "data": data
    })


def databyidview(request, id):
    data = databyid(request, id)
    previous = data[0]
    current = data[1]
    if(len(data)==3):
        next = data[2]
    else:
        next = None

    
    # print(current)
    # return JsonResponse({"data":data})
    return render(request, "system.html",{"previous":previous,"current":current,"next":next})


def databyid(request, id):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT * 
        FROM multitimeframe_snapshot
        WHERE id IN (%s, %s, %s)
    """, (id - 1, id, id + 1))

    rows = cursor.fetchall()
    columns = [desc[0] for desc in cursor.description]

    cursor.close()
    conn.close()


    data = [dict(zip(columns, row)) for row in rows]

    return data


# loadcsvtosql()
# df = loadsqltodf()
