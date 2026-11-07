
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

        # 1. Identify editable columns dynamically from extra_columns.
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

        # 2. Save previous, current, and next annotations.
        rows = ["previous", "current", "next"]

        for row in rows:
            candle_id = request.POST.get(f"{row}_id")

            if not candle_id or candle_id == "None":
                continue

            try:
                candle_id = int(candle_id)
            except (TypeError, ValueError):
                continue

            fields = []
            values = []

            for column in editable_columns:
                # Expected form names:
                # previous_analysis, current_bias, next_setup, etc.
                form_field = f"{row}_{column}"

                # Skip fields that were not submitted.
                if form_field not in request.POST:
                    continue

                value = request.POST.get(form_field)

                fields.append(f"`{column}` = %s")
                values.append(value if value != "" else None)

            if fields:
                query = f"""
                    UPDATE `labeled_flatdata`
                    SET
                        {", ".join(fields)},
                        `edited` = TRUE,
                        `edittime` = NOW()
                    WHERE `id` = %s
                """

                values.append(candle_id)
                cursor.execute(query, tuple(values))

        # 3. Save key zones to the current candle.
        current_id = request.POST.get("current_id")

        if current_id and current_id != "None":
            current_id = int(current_id)

            key_zone_columns = [
                column
                for column in extra_columns
                if column.startswith("key_zone_")
            ]

            fields = []
            values = []

            for column in key_zone_columns:
                # Expected form names:
                # key_zone_high_1, key_zone_low_1, etc.
                if column not in request.POST:
                    continue

                value = request.POST.get(column)

                if value in (None, ""):
                    value = None
                else:
                    try:
                        value = float(value)
                    except (TypeError, ValueError):
                        value = None

                fields.append(f"`{column}` = %s")
                values.append(value)

            if fields:
                query = f"""
                    UPDATE `labeled_flatdata`
                    SET
                        {", ".join(fields)},
                        `edited` = TRUE,
                        `edittime` = NOW()
                    WHERE `id` = %s
                """

                values.append(current_id)
                cursor.execute(query, tuple(values))

        # 4. Commit all updates together.
        db.commit()

    except mysql.connector.Error as e:
        if db and db.is_connected():
            db.rollback()

        print("Database error:", e)
        raise

    except (TypeError, ValueError) as e:
        if db and db.is_connected():
            db.rollback()

        print("Invalid form data:", e)
        raise

    finally:
        if cursor:
            cursor.close()

        if db and db.is_connected():
            db.close()

    # 5. Redirect to the next candle.
    current_id = request.POST.get("current_id")

    if current_id and current_id != "None":
        return redirect(
            "interface",
            candleid=int(current_id) + 1,
        )

    return redirect("annotate", candleid=1)
