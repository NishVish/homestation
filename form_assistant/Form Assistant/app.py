from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import re
from difflib import SequenceMatcher

app = Flask(__name__)
CORS(app)

# =========================
# LOAD CV JSON
# =========================

with open("data.json", "r", encoding="utf-8") as file:
    data = json.load(file)


# =========================
# NORMALIZER
# =========================

def normalize(text):
    return re.sub(r"[^a-z0-9\s]", "", (text or "").lower().strip())

def fuzzy_score(a, b):
    return SequenceMatcher(None, normalize(a), normalize(b)).ratio()


# =========================
# EDUCATION HELPERS
# =========================

DEGREE_HINTS = {
    "bachelor":    ["bachelor", "b.sc", "bsc", "b.tech", "btech", "b.e", "be ", "undergraduate", "ug", "b.a", "ba "],
    "master":      ["master", "m.sc", "msc", "m.tech", "mtech", "m.e", "me ", "postgraduate", "pg", "m.a", "ma ", "mba"],
    "phd":         ["phd", "ph.d", "doctorate", "doctoral", "doctor of"],
    "diploma":     ["diploma", "certificate", "cert "],
    "high_school": ["high school", "secondary", "ssc", "hsc", "12th", "10th", "matric"],
}

def detect_degree_level(text):
    t = normalize(text)
    for level, keywords in DEGREE_HINTS.items():
        if any(kw in t for kw in keywords):
            return level
    return None

def get_all_education():
    edu = data.get("education", [])
    if isinstance(edu, list):  return edu
    if isinstance(edu, dict):  return [edu]
    return []

def find_best_education_entry(field_text, field_index=None, total_fields=None):
    entries = get_all_education()
    if not entries:
        return None
    text = normalize(field_text)
    hint_level = detect_degree_level(text)
    scored = []
    for i, entry in enumerate(entries):
        score = 0.0
        if hint_level:
            entry_degree = normalize(entry.get("degree", "") + " " + entry.get("field", ""))
            if detect_degree_level(entry_degree) == hint_level:
                score += 0.5
        institution = entry.get("institution") or entry.get("university") or entry.get("college") or ""
        if institution:
            score += fuzzy_score(text, institution) * 0.3
        if field_index is not None and total_fields:
            expected = round((field_index / max(total_fields - 1, 1)) * (len(entries) - 1))
            if i == expected:
                score += 0.2
        score -= i * 0.05
        scored.append((score, entry))
    scored.sort(key=lambda x: x[0], reverse=True)
    return scored[0][1] if scored else entries[0]


# =========================
# DROPDOWN RESOLVER
# =========================

# Maps our internal field keys → how to extract the raw CV value for that dropdown type
DROPDOWN_CV_EXTRACTORS = {

    # "Overall Experience" → total years (integer or "X years" string)
    "exp_total_years": lambda: (
        str(data.get("totalExperience") or data.get("yearsOfExperience") or
            data.get("experience_years") or _compute_total_experience())
    ),

    # "Current Work Type" → Hybrid / On-site / Remote
    "work_type": lambda: (
        data.get("workType") or data.get("currentWorkType") or
        data.get("preferredWorkType") or ""
    ),

    # "Current Employment Type" → Permanent / Contract / Freelance …
    "employment_type": lambda: (
        data.get("employmentType") or data.get("currentEmploymentType") or
        data.get("jobType") or ""
    ),

    # Skill-specific experience years  (e.g. "CI/CD – X years")
    "skill_experience": lambda skill_name: _get_skill_experience(skill_name),

    # Degree level for dropdowns that list Bachelor/Master/PhD
    "edu_degree_level": lambda: (
        data.get("education", [{}])[0].get("degree") or ""
        if isinstance(data.get("education"), list) else ""
    ),

    # Notice period
    "notice_period": lambda: (
        str(data.get("noticePeriod") or data.get("notice_period") or "")
    ),

    # Current CTC / Expected CTC
    "current_ctc": lambda: str(data.get("currentCTC") or data.get("current_ctc") or ""),
    "expected_ctc": lambda: str(data.get("expectedCTC") or data.get("expected_ctc") or ""),

    # Gender
    "gender": lambda: (data.get("gender") or data.get("personal", {}).get("gender") or ""),

    # Country
    "country": lambda: (
        data.get("country") or
        data.get("personal", {}).get("country") or
        _extract_country_from_location()
    ),
}


def _compute_total_experience():
    """Sum experience durations if totalExperience not directly in JSON."""
    exps = data.get("experience") or data.get("workExperience") or []
    if not exps:
        return ""
    total = 0
    for exp in exps:
        dur = exp.get("duration") or exp.get("years") or 0
        try:
            total += int(str(dur).split()[0])
        except (ValueError, IndexError):
            pass
    return str(total) if total else ""


def _get_skill_experience(skill_name):
    """Look up years of experience for a specific skill."""
    skills = data.get("skillExperience") or data.get("skills_experience") or {}
    if isinstance(skills, dict):
        for key, val in skills.items():
            if fuzzy_score(key, skill_name) > 0.7:
                return str(val)
    # fallback: check skills list with experience field
    skills_list = data.get("skills") or []
    if isinstance(skills_list, list):
        for item in skills_list:
            if isinstance(item, dict):
                name = item.get("name") or item.get("skill") or ""
                if fuzzy_score(name, skill_name) > 0.7:
                    return str(item.get("years") or item.get("experience") or "")
    return ""


def _extract_country_from_location():
    loc = (
        data.get("personal", {}).get("location") or
        data.get("location") or ""
    )
    # Assume last comma-separated part is country
    parts = [p.strip() for p in loc.split(",")]
    return parts[-1] if len(parts) >= 2 else loc


# ------------------------------------
# Dropdown field intent detection
# ------------------------------------

DROPDOWN_FIELD_MAP = {
    "work_type":        ["work type", "workplace type", "work mode", "work arrangement", "hybrid", "remote", "onsite", "on-site"],
    "employment_type":  ["employment type", "job type", "contract type", "work contract", "employment mode", "c2h", "permanent", "freelance"],
    "exp_total_years":  ["overall experience", "total experience", "years of experience", "experience years", "total years"],
    "skill_experience": ["experience in", "years of experience in", "skill experience", "experience with"],
    "edu_degree_level": ["degree type", "level of education", "highest qualification", "qualification type"],
    "notice_period":    ["notice period", "joining time", "available from", "availability"],
    "current_ctc":      ["current ctc", "current salary", "current package", "ctc"],
    "expected_ctc":     ["expected ctc", "expected salary", "expected package"],
    "gender":           ["gender", "sex"],
    "country":          ["country", "nationality", "country of residence"],
}


def detect_dropdown_intent(field_text, options=None, skill_context=None):
    """
    Return the best matching dropdown key using 3 signals:
      1. skillContext present -> always skill_experience
      2. Label/field text keyword match
      3. Options content fingerprinting (when label is empty/wrong)
    """
    # Signal 1: skillContext beats everything
    if skill_context:
        return "skill_experience"

    # Signal 2: label text match
    text = normalize(field_text)
    best_key, best_score = None, 0.0
    for key, keywords in DROPDOWN_FIELD_MAP.items():
        for kw in keywords:
            kw_n = normalize(kw)
            if kw_n in text:
                s = 0.6 + len(kw_n) / (len(text) + 1) * 0.4
            else:
                sim = fuzzy_score(text, kw_n)
                s = sim * 0.55 if sim > 0.7 else 0
            if s > best_score:
                best_score, best_key = s, key

    if best_score >= 0.3:
        return best_key

    # Signal 3: fingerprint OPTIONS content when label gave no signal
    if options:
        option_labels = [
            normalize(o.get("label", "") if isinstance(o, dict) else str(o))
            for o in options
        ]
        joined = " ".join(option_labels[:5])

        # Pure year counts "1 year 2 years …" -> overall experience
        if all(re.match(r"^\d+ years?$", lbl) for lbl in option_labels[:3] if lbl):
            return "exp_total_years"

        # Hybrid / On-site / Remote
        if any(kw in joined for kw in ["hybrid", "onsite", "on site", "remote"]):
            return "work_type"

        # Contract / Permanent / Freelance
        if any(kw in joined for kw in ["permanent", "contract", "freelance", "internship", "c2h"]):
            return "employment_type"

        # Notice period options
        if any(kw in joined for kw in ["immediate", "15 days", "1 month", "2 months", "3 months"]):
            return "notice_period"

    return None


def best_option_match(cv_value, options, field_key=None):
    """
    Given a raw CV value and a list of option labels/values from the dropdown,
    return the single best-matching option value.

    Strategy (in priority order):
      1. Exact match (normalized)
      2. CV value is a number → match "N year(s)" style options
      3. Fuzzy match on option label
      4. CV value contained in option label or vice-versa
    """
    if not cv_value or not options:
        return None

    cv_n = normalize(str(cv_value))

    # --- Build list of (label, value) pairs ---
    pairs = []
    for opt in options:
        if isinstance(opt, dict):
            label = opt.get("label") or opt.get("text") or str(opt.get("value", ""))
            value = str(opt.get("value", label))
        else:
            label = value = str(opt)
        pairs.append((normalize(label), value, label))

    # 1. Exact match
    for label_n, val, label in pairs:
        if label_n == cv_n:
            return val

    # 2. Numeric year matching  ("5" → "5 years")
    try:
        cv_num = int(cv_n.split()[0])  # handles "5" or "5 years"
        for label_n, val, label in pairs:
            nums = re.findall(r"\d+", label_n)
            if nums and int(nums[0]) == cv_num:
                return val
    except (ValueError, IndexError):
        pass

    # 3. CV substring inside option or option inside CV
    for label_n, val, label in pairs:
        if cv_n in label_n or label_n in cv_n:
            return val

    # 4. Work-type / employment-type semantic aliases
    WORK_TYPE_ALIASES = {
        "hybrid":  ["hybrid"],
        "remote":  ["remote", "work from home", "wfh", "fully remote"],
        "onsite":  ["onsite", "on-site", "in office", "in-office", "office"],
    }
    EMPLOYMENT_ALIASES = {
        "permanent": ["permanent", "full time", "fulltime", "full-time", "fte"],
        "contract":  ["contract", "c2c", "contractual"],
        "c2h":       ["c2h", "contract to hire", "contract-to-hire"],
        "freelance": ["freelance", "freelancer", "independent"],
        "internship":["intern", "internship"],
    }

    alias_map = {}
    if field_key == "work_type":       alias_map = WORK_TYPE_ALIASES
    if field_key == "employment_type": alias_map = EMPLOYMENT_ALIASES

    for canonical, aliases in alias_map.items():
        if any(a in cv_n for a in aliases):
            # find option that matches canonical
            for label_n, val, label in pairs:
                if any(a in label_n for a in aliases):
                    return val

    # 5. Best fuzzy match (threshold 0.45)
    scored = [(fuzzy_score(cv_n, label_n), val) for label_n, val, _ in pairs]
    scored.sort(reverse=True)
    if scored and scored[0][0] >= 0.45:
        return scored[0][1]

    return None


# =========================
# FIELD INTENT MAP (text fields)
# =========================

FIELD_MAP = {
    "first_name":      ["first name", "firstname", "fname", "given name", "first"],
    "last_name":       ["last name", "lastname", "surname", "family name", "lname"],
    "full_name":       ["full name", "fullname", "your name", "name"],
    "email":           ["email", "e-mail", "mail", "electronic mail"],
    "phone":           ["phone", "mobile", "contact number", "whatsapp", "cell", "telephone"],
    "location":        ["location", "city", "address", "current city", "place"],
    "linkedin":        ["linkedin", "linkedin url", "linkedin profile"],
    "portfolio":       ["portfolio", "website", "github", "personal site", "personal url"],
    "summary":         ["summary", "about", "bio", "profile", "objective", "cover", "about me"],
    "job_title":       ["job title", "professional title", "designation", "current role", "role", "title", "position"],
    "company":         ["current company", "employer", "company", "organisation", "organization", "workplace"],
    "edu_institution": ["university", "institute", "institution", "college", "school", "alma mater",
                        "attended", "studied at", "education name", "educational institution",
                        "university name", "college name", "school name", "institute name"],
    "edu_degree":      ["degree", "qualification", "program", "programme", "course",
                        "major", "field of study", "specialization", "discipline"],
    "edu_start_year":  ["start year", "from year", "joining year", "year of joining", "admission year"],
    "edu_end_year":    ["end year", "graduation year", "passing year", "year of passing", "year of graduation", "to year"],
    "edu_year":        ["year", "batch"],
    "edu_gpa":         ["gpa", "cgpa", "grade", "percentage", "marks", "score"],
    "skills":          ["skills", "technologies", "tech stack", "expertise", "competencies"],
    "exp_company":     ["previous company", "last company", "past employer", "experience company"],
    "exp_title":       ["experience title", "past role", "previous role", "previous designation"],
    "exp_duration":    ["experience duration", "work duration", "years of experience", "total experience"],
}

EDU_KEYS = {"edu_institution", "edu_degree", "edu_start_year", "edu_end_year", "edu_year", "edu_gpa"}
EXP_KEYS = {"exp_company", "exp_title", "exp_duration"}

JSON_PATHS = {
    "first_name": ("personal", "firstName"),
    "last_name":  ("personal", "lastName"),
    "full_name":  ("personal", "fullName"),
    "email":      ("personal", "email"),
    "phone":      ("personal", "phone"),
    "location":   ("personal", "location"),
    "linkedin":   ("personal", "linkedin"),
    "portfolio":  ("personal", "portfolio"),
    "summary":    ("personal", "summary"),
    "job_title":  ("currentRole", "title"),
    "company":    ("currentRole", "company"),
    "skills":     ("skills",),
}


def score_field_key(field_text, keywords):
    text = normalize(field_text)
    best = 0.0
    for kw in keywords:
        kw_n = normalize(kw)
        if kw_n in text:
            best = max(best, 0.6 + len(kw_n) / (len(text) + 1) * 0.4)
        else:
            sim = fuzzy_score(text, kw_n)
            if sim > 0.7:
                best = max(best, sim * 0.55)
    return best


def get_value_by_path(path):
    ref = data
    for key in path:
        if isinstance(ref, dict):       ref = ref.get(key, "")
        elif isinstance(ref, list):
            try:                        ref = ref[int(key)]
            except (IndexError, ValueError): return ""
        else:                           return ""
    if isinstance(ref, list):
        return ", ".join(str(v) for v in ref)
    return ref if not isinstance(ref, (dict, list)) else ""


def resolve_education_field(key, field_text, field_meta):
    entry = find_best_education_entry(
        field_text,
        field_index=field_meta.get("edu_field_index"),
        total_fields=field_meta.get("edu_field_total"),
    )
    if not entry:
        return ""
    if key == "edu_institution":
        return entry.get("institution") or entry.get("university") or entry.get("college") or entry.get("school") or ""
    if key == "edu_degree":
        parts = [entry.get("degree", ""), entry.get("field", ""), entry.get("major", "")]
        return " ".join(p for p in parts if p).strip()
    if key == "edu_start_year":
        return str(entry.get("startYear") or entry.get("start_year") or entry.get("from") or "")
    if key == "edu_end_year":
        return str(entry.get("endYear") or entry.get("end_year") or entry.get("to") or entry.get("graduationYear") or "")
    if key == "edu_year":
        return str(entry.get("year") or entry.get("endYear") or entry.get("graduationYear") or "")
    if key == "edu_gpa":
        return str(entry.get("gpa") or entry.get("cgpa") or entry.get("grade") or entry.get("percentage") or "")
    return ""


def resolve_experience_field(key):
    exps = data.get("experience") or data.get("workExperience") or []
    if not exps:
        return ""
    latest = exps[0] if isinstance(exps, list) else exps
    if key == "exp_company":   return latest.get("company") or latest.get("employer") or ""
    if key == "exp_title":     return latest.get("title") or latest.get("role") or latest.get("designation") or ""
    if key == "exp_duration":
        start = latest.get("startYear") or latest.get("from") or ""
        end   = latest.get("endYear")   or latest.get("to")   or "Present"
        return f"{start} – {end}" if start else str(latest.get("duration") or "")
    return ""


# =========================
# MATCH FIELD (unified: text + dropdown)
# =========================

def match_field(field, field_meta=None):
    field_text = " ".join(filter(None, [
        field.get("name", ""),
        field.get("id", ""),
        field.get("label", ""),
        field.get("placeholder", ""),
        field.get("aria-label", ""),
    ]))

    options   = field.get("options")      # list of {label, value} or plain strings
    skill_ctx = field.get("skillContext") # e.g. "CI/CD" — the skill this dropdown is for

    # ── DROPDOWN PATH ──────────────────────────────────────────────────
    if options is not None:
        dropdown_key = detect_dropdown_intent(field_text, options=options, skill_context=skill_ctx)

        # Skill-specific experience dropdown (e.g. "CI/CD – years of experience")
        if dropdown_key == "skill_experience" or skill_ctx:
            skill_name = skill_ctx or _extract_skill_from_label(field_text)
            cv_value   = _get_skill_experience(skill_name) if skill_name else ""
            # If we still don't have a value, fall back to total experience
            if not cv_value:
                cv_value = DROPDOWN_CV_EXTRACTORS["exp_total_years"]()

        elif dropdown_key and dropdown_key in DROPDOWN_CV_EXTRACTORS:
            extractor = DROPDOWN_CV_EXTRACTORS[dropdown_key]
            cv_value  = extractor() if callable(extractor) else ""

        else:
            # No dropdown key detected — run normal text-field matching and
            # then snap the value to the closest option
            cv_value = _text_field_value(field, field_text, field_meta)

        return best_option_match(cv_value, options, field_key=dropdown_key) or ""

    # ── TEXT FIELD PATH ─────────────────────────────────────────────────
    return _text_field_value(field, field_text, field_meta)


def _text_field_value(field, field_text, field_meta):
    """Core text-field resolver (unchanged logic from previous version)."""
    best_key, best_score = None, 0.0
    for key, keywords in FIELD_MAP.items():
        s = score_field_key(field_text, keywords)
        if s > best_score:
            best_score, best_key = s, key

    if best_score < 0.3 or best_key is None:
        return ""

    if best_key in EDU_KEYS:
        return resolve_education_field(best_key, field_text, field_meta or {})
    if best_key in EXP_KEYS:
        return resolve_experience_field(best_key)

    path = JSON_PATHS.get(best_key)
    return get_value_by_path(path) if path else ""


def _extract_skill_from_label(text):
    """
    For labels like "CI/CD – Select years of experience",
    extract the skill name before the dash / 'select' keyword.
    """
    t = re.split(r"[-–—]|select|years|experience", text, flags=re.IGNORECASE)[0].strip()
    return t if len(t) > 1 else ""


# =========================
# EDUCATION FIELD GROUPER
# =========================

def annotate_edu_fields(fields):
    edu_indices = []
    for i, field in enumerate(fields):
        text = normalize(" ".join([
            field.get("name", ""), field.get("id", ""),
            field.get("label", ""), field.get("placeholder", ""),
        ]))
        for kw in FIELD_MAP["edu_institution"] + FIELD_MAP["edu_degree"]:
            if normalize(kw) in text:
                edu_indices.append(i)
                break
    return edu_indices


# =========================
# /fill  ENDPOINT
# =========================

@app.route("/fill", methods=["POST"])
def fill():
    payload = request.json or {}
    fields  = payload.get("fields", [])

    edu_indices = annotate_edu_fields(fields)
    total_edu   = len(edu_indices)
    result      = {}

    for i, field in enumerate(fields):
        meta = {}
        if i in edu_indices:
            meta["edu_field_index"] = edu_indices.index(i)
            meta["edu_field_total"] = total_edu

        value = match_field(field, meta)
        name  = field.get("name") or field.get("id")

        if name and value:
            result[name] = str(value).strip()

    return jsonify(result)


# =========================
# /debug  ENDPOINT
# =========================

@app.route("/debug", methods=["POST"])
def debug():
    payload = request.json or {}
    fields  = payload.get("fields", [])

    edu_indices = annotate_edu_fields(fields)
    total_edu   = len(edu_indices)
    details     = []

    for i, field in enumerate(fields):
        meta = {}
        if i in edu_indices:
            meta["edu_field_index"] = edu_indices.index(i)
            meta["edu_field_total"] = total_edu

        field_text = " ".join(filter(None, [
            field.get("name", ""), field.get("id", ""),
            field.get("label", ""), field.get("placeholder", ""),
        ]))

        is_dropdown = field.get("options") is not None
        dropdown_key = detect_dropdown_intent(field_text, options=field.get('options'), skill_context=field.get('skillContext')) if is_dropdown else None

        text_scores = {
            key: round(score_field_key(field_text, kws), 3)
            for key, kws in FIELD_MAP.items()
        }
        top_text = sorted(text_scores.items(), key=lambda x: x[1], reverse=True)[:5]

        value = match_field(field, meta)

        details.append({
            "field":           field,
            "is_dropdown":     is_dropdown,
            "dropdown_key":    dropdown_key,
            "top_text_candidates": top_text,
            "matched_value":   value,
        })

    return jsonify(details)


# =========================
# RUN
# =========================

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5500, debug=True)