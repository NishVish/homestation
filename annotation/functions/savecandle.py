import mysql.connector
from django.shortcuts import redirect


def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="marketdata"
    )


def savecandle(request):
    if request.method != "POST":
        return redirect("annotate", candleid=1)

    print("POST DATA:", request.POST.dict())

    db = None
    cursor = None

    try:
        db = get_connection()
        cursor = db.cursor()

        # 1. Save previous, current, and next candle annotations
        rows = ["previous", "current", "next"]

        for row in rows:
            candle_id = request.POST.get(f"{row}_id")

            if not candle_id or candle_id == "None":
                continue

            analysis = request.POST.get(f"{row}_analysis", "")
            bias = request.POST.get(f"{row}_bias", "")
            phase = request.POST.get(f"{row}_phase", "")
            momentum = request.POST.get(f"{row}_momentum", "")
            decision = request.POST.get(f"{row}_decision", "")

            query = """
                UPDATE ml_1min_features
                SET
                    analysis = %s,
                    bias = %s,
                    phase = %s,
                    momentum = %s,
                    decision = %s,
                    edited = TRUE,
                    edittime = NOW()
                WHERE id = %s
            """

            cursor.execute(
                query,
                (
                    analysis,
                    bias,
                    phase,
                    momentum,
                    decision,
                    int(candle_id)
                )
            )

        # 2. Save key zone data to the current candle
        current_id = request.POST.get("current_id")

        if current_id and current_id != "None":
            fields = []
            values = []

            # Save key_zone_high_1, key_zone_low_1, through zone 4
            for i in range(1, 5):
                for prefix in ("high", "low"):
                    field = f"key_zone_{prefix}_{i}"
                    fields.append(f"`{field}` = %s")

                    value = request.POST.get(field)
                    values.append(value if value not in (None, "") else None)

            values.append(int(current_id))

            query = f"""
                UPDATE ml_1min_features
                SET
                    {", ".join(fields)},
                    edited = TRUE,
                    edittime = NOW()
                WHERE id = %s
            """

            cursor.execute(query, tuple(values))

        # 3. Commit all updates
        db.commit()

    except mysql.connector.Error as e:
        if db and db.is_connected():
            db.rollback()

        print("Database error:", e)
        raise

    finally:
        if cursor:
            cursor.close()

        if db and db.is_connected():
            db.close()

    # 4. Redirect to the next candle
    current_id = request.POST.get("current_id")

    return redirect(
        "interface",
        candleid=int(current_id) + 1
    )