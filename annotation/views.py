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

    db = mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="marketdata"
    )

    cursor = db.cursor()

    cursor.execute("SELECT * FROM `ml_1min_features`")

    rows = cursor.fetchall()
    columns = [column[0] for column in cursor.description]

    cursor.close()
    db.close()

    html = """
    <html>
    <head>
        <title>1min Data</title>
        <style>
            table {
                border-collapse: collapse;
                width: 100%;
            }

            th, td {
                border: 1px solid #ccc;
                padding: 8px;
                text-align: left;
            }

            th {
                background: #f2f2f2;
            }
        </style>
    </head>

    <body>

        <h2>1min Data</h2>

        <table>
            <thead>
                <tr>
    """

    for column in columns:
        html += f"<th>{column}</th>"

    html += """
                </tr>
            </thead>

            <tbody>
    """

    for row in rows:
        html += "<tr>"

        for value in row:
            html += f"<td>{value}</td>"

        html += "</tr>"

    html += """
            </tbody>
        </table>

    </body>
    </html>
    """

    return HttpResponse(html)


