from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import json

app = Flask(__name__)
CORS(app)

RAG_URL = "http://127.0.0.1:8000/rag/chat/"


# =========================
# CALL YOUR RAG BRAIN
# =========================

def ask_rag(message):
    try:
        res = requests.post(
            RAG_URL,
            json={"message": message},
            timeout=60
        )

        data = res.json()
        return data.get("answer", "")

    except Exception as e:
        print("RAG ERROR:", e)
        return ""


# =========================
# FIELD MAPPING USING RAG ONLY
# =========================

def map_field(field):
    field_text = " ".join([
        field.get("name", ""),
        field.get("id", ""),
        field.get("label", ""),
        field.get("placeholder", "")
    ])

    prompt = f"""
You are a form field extractor.

Based on your knowledge, return ONLY the exact value that should fill this field.

Field:
{field_text}

If unknown, return empty string.
"""

    return ask_rag(prompt)


# =========================
# API
# =========================

@app.route("/fill", methods=["POST"])
def fill():
    payload = request.json
    result = {}

    for field in payload.get("fields", []):

        value = map_field(field)

        name = field.get("name") or field.get("id")

        if name and value:
            result[name] = value

    return jsonify(result)


# =========================
# RUN SERVER
# =========================

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5500,
        debug=True
    )