from flask import Flask, render_template_string
import csv, os

app = Flask(__name__)

BASE_DIR = r"C:\Users\nishw\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\MQL5\Files"

HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>MQL5 CSV Data</title>
    <style>
        body {
            background: #111827;
            color: #e5e7eb;
            font-family: Arial, sans-serif;
            margin: 25px;
        }

        h1 {
            color: #60a5fa;
        }

        h2 {
            color: #fbbf24;
            margin-top: 35px;
        }

        .table-container {
            overflow-x: auto;
            margin-bottom: 30px;
            border: 1px solid #374151;
            border-radius: 8px;
        }

        table {
            border-collapse: collapse;
            width: 100%;
            background: #1f2937;
            white-space: nowrap;
        }

        th {
            background: #2563eb;
            color: white;
            padding: 10px 14px;
            position: sticky;
            top: 0;
        }

        td {
            padding: 8px 14px;
            border-bottom: 1px solid #374151;
            text-align: center;
        }

        tr:hover {
            background: #374151;
        }

        .empty {
            color: #f87171;
            padding: 15px;
        }
    </style>
</head>

<body>

<h1>MQL5 CSV Data</h1>

{% for file in files %}

    <h2>{{ file.name }}</h2>

    {% if file.rows %}

    <div class="table-container">
        <table>
            <thead>
                <tr>
                    {% for column in file.columns %}
                        <th>{{ column }}</th>
                    {% endfor %}
                </tr>
            </thead>

            <tbody>
                {% for row in file.rows %}
                <tr>
                    {% for column in file.columns %}
                        <td>{{ row[column] }}</td>
                    {% endfor %}
                </tr>
                {% endfor %}
            </tbody>
        </table>
    </div>

    {% else %}

        <div class="empty">No data found.</div>

    {% endif %}

{% endfor %}

</body>
</html>
"""


@app.route("/")
def index():

    files = []

    for filename in os.listdir(BASE_DIR):

        if not filename.lower().endswith(".csv"):
            continue

        filepath = os.path.join(BASE_DIR, filename)

        try:
            with open(filepath, "r", encoding="utf-8-sig", newline="") as f:

                reader = csv.DictReader(f)

                columns = reader.fieldnames or []
                rows = list(reader)

                files.append({
                    "name": filename,
                    "columns": columns,
                    "rows": rows
                })

        except Exception as e:

            files.append({
                "name": filename,
                "columns": [],
                "rows": []
            })

    return render_template_string(HTML, files=files)


if __name__ == "__main__":
    print("========================================")
    print("MQL5 CSV Flask Viewer")
    print("========================================")
    print("Folder:", BASE_DIR)
    print("Open: http://127.0.0.1:5000")
    print("========================================")

    app.run(
        host="127.0.0.1",
        port=5000,
        debug=True
    )
