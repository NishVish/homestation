from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

PROFILE = {
    "firstName": "John",
    "lastName": "Smith",
    "email": "john@example.com",
    "phone": "+91 9876543210"
}

def match_field(field):

    text = (
        field.get("name", "")
        + " "
        + field.get("label", "")
    ).lower()

    if "first" in text:
        return PROFILE["firstName"]

    if "last" in text:
        return PROFILE["lastName"]

    if "email" in text:
        return PROFILE["email"]

    if "phone" in text:
        return PROFILE["phone"]

    return ""

@app.route("/fill", methods=["POST"])
def fill():

    payload = request.json

    result = {}

    for field in payload["fields"]:

        value = match_field(field)

        if value:
            result[field["name"]] = value

    return jsonify(result)

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5500,
        debug=True
    )
