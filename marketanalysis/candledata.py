from django.db.models import query_utils
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





def candledata(request, id):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT *
        FROM multitimeframe_snapshot
        WHERE id = %s
    """, (id,))

    row = cursor.fetchone()
    columns = [desc[0] for desc in cursor.description]
    data = dict(zip(columns, row))

    def query(timeframe):
        """Fetch the last 50 candles for the given timeframe."""
        t = timeframe
        current_time = data[f"{t}_time"]   # <-- Use each timeframe's own current candle

        cursor.execute(f"""
            SELECT *
            FROM (
                SELECT
                    {t}_time, {t}_open, {t}_high, {t}_low, {t}_close,
                    {t}_dir, {t}_group, {t}_bias, {t}_phase,
                    {t}_momentum, {t}_pattern, {t}_atr, {t}_rsi
                FROM multitimeframe_snapshot
                WHERE {t}_time <= %s
                GROUP BY {t}_time
                ORDER BY {t}_time DESC
                LIMIT 50
            ) AS sub
            ORDER BY {t}_time ASC
        """, (current_time,))

        return cursor.fetchall()

    fourhour = remove_outlier(query("4h"))
    onehour  = remove_outlier(query("1h"))
    fifteen  = remove_outlier(query("15m"))

    cursor.close()
    conn.close()

    return JsonResponse({
        "current_time": data["15m_time"],
        "fourhour": fourhour,
        "onehour": onehour,
        "fifteen": fifteen,
    })


def remove_outlier(data):
    return data[1:] if len(data) > 1 else data