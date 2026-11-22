
import mysql.connector
from django.shortcuts import redirect

from .data.migratecsvtosql import extra_columns


def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="marketdata",
    )


def savecandle(request):

    if request.method != "POST":
        return redirect("annotate", candleid=1)

    db = None
    cursor = None

    try:
        db = get_connection()
        cursor = db.cursor()

        excluded_fields = {
            "id",
            "edited",
            "edittime",
        }

        editable_columns = [
            column
            for column in extra_columns
            if column not in excluded_fields
            and not column.startswith("key_zone_")
        ]

        key_zone_columns = [
            column
            for column in extra_columns
            if column.startswith("key_zone_")
        ]

        # Build updates for previous, current and next.
        rows = ["previous", "current", "next"]

        for row in rows:

            candle_id = request.POST.get(f"{row}_id")

            if not candle_id or candle_id == "None":
                continue

            candle_id = int(candle_id)

            updates = {}
            columns = (
                editable_columns
                + (key_zone_columns if row == "current" else [])
            )

            for column in columns:

                form_field = (
                    column if column.startswith("key_zone_")
                    else f"{row}_{column}"
                )

                if form_field not in request.POST:
                    continue

                value = request.POST.get(form_field)

                if row == "current" and (value is None or value == ""):
                    value = "none"
                elif value == "":
                    value = None

                if column.startswith("key_zone_") and value is not None:
                    try:
                        value = float(value)
                    except (TypeError, ValueError):
                        value = None

                updates[column] = value

            if not updates:
                continue

            assignments = [
                f"`{column}` = %s"
                for column in updates
            ]

            query = f"""
                UPDATE `labeled_flatdata`
                SET
                    {", ".join(assignments)},
                    `edited` = TRUE,
                    `edittime` = NOW()
                WHERE `id` = %s
                LIMIT 1
            """

            values = list(updates.values())
            values.append(candle_id)

            cursor.execute(query, tuple(values))

        db.commit()

    except Exception as e:

        if db and db.is_connected():
            db.rollback()

        print("Database error:", e)
        raise

    finally:

        if cursor:
            cursor.close()

        if db and db.is_connected():
            db.close()

    current_id = request.POST.get("current_id")

    if current_id and current_id != "None":
        return redirect(
            "interface",
            candleid=int(current_id) + 1,
        )

    return redirect("annotate", candleid=1)
