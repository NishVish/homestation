from django.shortcuts import redirect
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

from .views import databyid
from django.shortcuts import redirect
from django.shortcuts import redirect

def updatebyid(request, id):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        UPDATE multitimeframe_snapshot
        SET
            `4h_time` = %s,
            `4h_open` = %s,
            `4h_high` = %s,
            `4h_low` = %s,
            `4h_close` = %s,
            `4h_dir` = %s,
            `4h_group` = %s,
            `4h_bias` = %s,
            `4h_phase` = %s,
            `4h_momentum` = %s,
            `4h_pattern` = %s,
            `4h_atr` = %s,
            `4h_rsi` = %s,

            `1h_time` = %s,
            `1h_open` = %s,
            `1h_high` = %s,
            `1h_low` = %s,
            `1h_close` = %s,
            `1h_dir` = %s,
            `1h_group` = %s,
            `1h_bias` = %s,
            `1h_phase` = %s,
            `1h_momentum` = %s,
            `1h_pattern` = %s,
            `1h_atr` = %s,
            `1h_rsi` = %s,

            `15m_time` = %s,
            `15m_open` = %s,
            `15m_high` = %s,
            `15m_low` = %s,
            `15m_close` = %s,
            `15m_dir` = %s,
            `15m_group` = %s,
            `15m_bias` = %s,
            `15m_phase` = %s,
            `15m_momentum` = %s,
            `15m_pattern` = %s,
            `15m_atr` = %s,
            `15m_rsi` = %s,

            `analysis` = %s,
            `action` = %s,
            `takeprofit` = %s,
            `stoploss` = %s,
            `verified_id` = %s,
            `result` = %s

        WHERE id = %s
    """, (
        # 4H
        request.POST.get("4h_time"),
        request.POST.get("4h_open"),
        request.POST.get("4h_high"),
        request.POST.get("4h_low"),
        request.POST.get("4h_close"),
        request.POST.get("4h_dir"),
        request.POST.get("4h_group"),
        request.POST.get("4h_bias"),
        request.POST.get("4h_phase"),
        request.POST.get("4h_momentum"),
        request.POST.get("4h_pattern"),
        request.POST.get("4h_atr"),
        request.POST.get("4h_rsi"),

        # 1H
        request.POST.get("1h_time"),
        request.POST.get("1h_open"),
        request.POST.get("1h_high"),
        request.POST.get("1h_low"),
        request.POST.get("1h_close"),
        request.POST.get("1h_dir"),
        request.POST.get("1h_group"),
        request.POST.get("1h_bias"),
        request.POST.get("1h_phase"),
        request.POST.get("1h_momentum"),
        request.POST.get("1h_pattern"),
        request.POST.get("1h_atr"),
        request.POST.get("1h_rsi"),

        # 15M
        request.POST.get("15m_time"),
        request.POST.get("15m_open"),
        request.POST.get("15m_high"),
        request.POST.get("15m_low"),
        request.POST.get("15m_close"),
        request.POST.get("15m_dir"),
        request.POST.get("15m_group"),
        request.POST.get("15m_bias"),
        request.POST.get("15m_phase"),
        request.POST.get("15m_momentum"),
        request.POST.get("15m_pattern"),
        request.POST.get("15m_atr"),
        request.POST.get("15m_rsi"),

        # extra fields
        request.POST.get("analysis"),
        request.POST.get("action"),
        request.POST.get("takeprofit"),
        request.POST.get("stoploss"),
        request.POST.get("verified_id"),
        request.POST.get("result"),

        # WHERE
        id
    ))

    conn.commit()
    cursor.close()
    conn.close()

    return redirect(f"/marketanalysis/{id + 1}/")