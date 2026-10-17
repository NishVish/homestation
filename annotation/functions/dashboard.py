
import mysql.connector
from django.http import HttpResponse


def dashboard(request):

    db = mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="marketdata"
    )

    cursor = db.cursor(dictionary=True)

    # Pagination
    page = int(request.GET.get("page", 1))
    per_page = 50

    offset = (page - 1) * per_page

    # Total rows
    cursor.execute("SELECT COUNT(*) AS total FROM `1min`")
    total_rows = cursor.fetchone()["total"]

    total_pages = (total_rows + per_page - 1) // per_page

    # Only required columns
    cursor.execute(
        f"""
        SELECT
            id,
            1min_raw_time_1,
            analysis,
            bias,
            phase,
            momentum,
            decision,
            edited,
            edittime
        FROM `1min`
        LIMIT {per_page} OFFSET {offset}
        """
    )

    rows = cursor.fetchall()

    # Exact columns to display
    columns = [
        "id",
        "1min_raw_time_1",
        "analysis",
        "bias",
        "phase",
        "momentum",
        "decision",
        "edited",
        "edittime"
    ]

    cursor.close()
    db.close()

    # Build table header
    table_header = "".join(
        f"<th>{column}</th>" for column in columns
    )

    # Build table rows
    table_rows = ""

    for row in rows:

        table_rows += "<tr>"

        for column in columns:

            if column == "id":
                table_rows += f"""
                    <td>
                        <a href=" interface/{row[column]}/">
                            {row[column]}
                        </a>
                    </td>
                """
            else:
                table_rows += f"<td>{row[column]}</td>"

        table_rows += "</tr>"


    # Pagination
    pagination = ""

    if page > 1:
        pagination += f'<a href="?page={page - 1}">← Previous</a>'

    pagination += f"""
        <span style="margin: 0 15px;">
            Page {page} of {total_pages}
        </span>
    """

    if page < total_pages:
        pagination += f'<a href="?page={page + 1}">Next →</a>'

    html = f"""
    <!DOCTYPE html>

    <html>

    <head>

        <title>Market Data Dashboard</title>

        <style>

            body {{
                font-family: Arial, sans-serif;
                margin: 0;
                padding: 30px;
                background: #f5f5f5;
            }}

            h1 {{
                margin-bottom: 20px;
            }}

            .info {{
                margin-bottom: 15px;
                color: #555;
            }}

            .table-container {{
                background: white;
                overflow-x: auto;
                border-radius: 8px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            }}

            table {{
                width: 100%;
                border-collapse: collapse;
            }}

            th {{
                background: #222;
                color: white;
                padding: 10px;
                text-align: left;
                position: sticky;
                top: 0;
            }}

            td {{
                padding: 9px 10px;
                border-bottom: 1px solid #ddd;
                white-space: nowrap;
            }}

            tr:hover {{
                background: #f1f1f1;
            }}

            .pagination {{
                margin-top: 20px;
                text-align: center;
            }}

            .pagination a {{
                display: inline-block;
                padding: 8px 15px;
                background: #222;
                color: white;
                text-decoration: none;
                border-radius: 5px;
            }}

            .pagination a:hover {{
                background: #444;
            }}

        </style>

    </head>

    <body>

        <h1>Market Data Dashboard</h1>

        <div class="info">
            Total Rows: {total_rows}
        </div>

        <div class="table-container">

            <table>

                <thead>
                    <tr>
                        {table_header}
                    </tr>
                </thead>

                <tbody>
                    {table_rows}
                </tbody>

            </table>

        </div>

        <div class="pagination">
            {pagination}
        </div>

    </body>

    </html>
    """

    return HttpResponse(html)
