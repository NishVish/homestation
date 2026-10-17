from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# =========================
# YOUR CV-BASED PROFILE
# =========================

PROFILE = {
    "firstName": "Nishant",
    "lastName": "Vishwakarma",
    "fullName": "Nishant Vishwakarma",

    "email": "nishwakarma3@gmail.com",
    "phone": "7909075195",
    "location": "Bengaluru, India",

    "linkedin": "linkedin.com/in/nishant-vishwakarma-5b39b9214",
    "portfolio": "nishvish.github.io/profile",

    "summary": "System-level developer building scalable backend systems, automation tools, and AI workflows.",

    "skills": "Python, PHP, Laravel, Django, JavaScript, SQL, MySQL, MongoDB, Docker, Linux, Ollama, AI Agents",

    "role": "Fullstack Developer",

    "company": "Sphere Travelmedia and Exhibitions"
}


# =========================
# ADVANCED MATCHER
# =========================

def normalize(text):
    return (text or "").lower().strip()


def match_field(field):

    text = normalize(
        " ".join([
            field.get("name", ""),
            field.get("id", ""),
            field.get("label", ""),
            field.get("placeholder", "")
        ])
    )

    rules = {
        "firstName": [
            "first name", "firstname", "fname", "given name"
        ],
        "lastName": [
            "last name", "lastname", "surname", "family name"
        ],
        "fullName": [
            "full name", "name", "your name", "candidate name"
        ],

        "email": [
            "email", "e-mail", "mail"
        ],

        "phone": [
            "phone", "mobile", "contact", "whatsapp", "tel"
        ],

        "location": [
            "location", "city", "address", "current location"
        ],

        "linkedin": [
            "linkedin", "linkedin url", "profile linkedin"
        ],

        "portfolio": [
            "portfolio", "website", "personal site", "url", "github"
        ],

        "summary": [
            "summary", "about", "bio", "description", "profile"
        ],

        "skills": [
            "skills", "technologies", "tech stack", "expertise"
        ],

        "company": [
            "company", "organization", "employer"
        ],

        "role": [
            "role", "position", "job title", "designation"
        ]
    }

    for key, keywords in rules.items():
        for kw in keywords:
            if kw in text:
                return PROFILE.get(key, "")

    return ""


# =========================
# API
# =========================

@app.route("/fill", methods=["POST"])
def fill():

    payload = request.json
    result = {}

    for field in payload.get("fields", []):

        value = match_field(field)

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