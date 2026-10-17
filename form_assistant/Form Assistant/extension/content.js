(function () {
    if (document.getElementById("autofill-floating-btn")) return;

    // ─── FLOATING BUTTON ────────────────────────────────────────────────────────
    const btn = document.createElement("button");
    btn.id = "autofill-floating-btn";
    btn.innerText = "✦ AI Fill";

    Object.assign(btn.style, {
        position: "fixed", bottom: "20px", right: "20px", zIndex: "999999",
        padding: "12px 20px", background: "#111827", color: "#ffffff",
        border: "none", borderRadius: "999px", cursor: "pointer",
        fontSize: "14px", fontFamily: "Arial, sans-serif",
        boxShadow: "0 10px 25px rgba(0,0,0,0.25)", transition: "all 0.2s ease-in-out"
    });

    btn.onmouseenter = () => { btn.style.transform = "scale(1.05)"; btn.style.background = "#2563eb"; };
    btn.onmouseleave = () => { btn.style.transform = "scale(1)";    btn.style.background = "#111827"; };
    document.body.appendChild(btn);


    // ─── HELPERS ────────────────────────────────────────────────────────────────

    // Returns true if this element is a "section boundary" — we stop walking at these
    function isBoundary(el) {
        const tag  = el.tagName?.toLowerCase();
        const role = el.getAttribute("role") || "";
        // Stop at form, fieldset, main, section, article, or large containers
        if (["form", "fieldset", "main", "section", "article", "header", "footer", "nav"].includes(tag)) return true;
        if (["form", "main", "region", "dialog"].includes(role)) return true;
        // Stop if the element contains more than 2 <select> or <input> — it's too wide
        if (el.querySelectorAll("select, input").length > 2) return true;
        return false;
    }

    // Checks if text looks like a real field label (not a button/nav/heading)
    function isLabelLike(text) {
        if (!text || text.length === 0 || text.length > 80) return false;
        // Reject obvious non-labels
        if (/submit|apply|back|next|sign in|log in|register|upload|browse|consent|privacy|terms/i.test(text)) return false;
        // Reject if it has too many words (probably a sentence/paragraph)
        if (text.split(/\s+/).length > 8) return false;
        return true;
    }

    // ─── LABEL DETECTION ────────────────────────────────────────────────────────
    function getLabel(el) {
        // 1. Explicit <label for="id">
        if (el.id) {
            const lbl = document.querySelector(`label[for="${CSS.escape(el.id)}"]`);
            if (lbl) return lbl.innerText.trim();
        }

        // 2. Wrapping <label>
        const wrap = el.closest("label");
        if (wrap) {
            const t = wrap.innerText.replace(el.value || "", "").trim();
            if (isLabelLike(t)) return t;
        }

        // 3. aria-label
        const aria = el.getAttribute("aria-label");
        if (aria && isLabelLike(aria.trim())) return aria.trim();

        // 4. aria-labelledby
        const lblId = el.getAttribute("aria-labelledby");
        if (lblId) {
            const ref = document.getElementById(lblId);
            const t   = ref?.innerText?.trim();
            if (t && isLabelLike(t)) return t;
        }

        // 5. Walk up DOM — max 5 levels, stop at section boundaries
        let node = el.parentElement;
        for (let i = 0; i < 5 && node; i++) {
            if (isBoundary(node)) break;

            // data-label attrs
            const attr = node.getAttribute("data-label") || node.getAttribute("data-field-label");
            if (attr && isLabelLike(attr.trim())) return attr.trim();

            // Previous sibling with text
            const prev = closestPrevSiblingText(node);
            if (prev && isLabelLike(prev)) return prev;

            node = node.parentElement;
        }

        // 6. Placeholder as last resort
        return el.placeholder || "";
    }

    function closestPrevSiblingText(el) {
        // Only look at IMMEDIATE previous siblings (don't scan the whole subtree)
        let sib = el.previousElementSibling;
        let checked = 0;
        while (sib && checked < 3) {
            const tag = sib.tagName?.toLowerCase();
            if (["label", "span", "p", "legend", "h1", "h2", "h3", "h4", "li"].includes(tag)) {
                // Get direct text only — not text from nested inputs/selects
                const clone = sib.cloneNode(true);
                clone.querySelectorAll("input, select, textarea, button").forEach(n => n.remove());
                const t = clone.innerText?.trim();
                if (t && isLabelLike(t)) return t;
            }
            // For divs: only use if they have short direct text (not a whole sub-section)
            if (tag === "div") {
                const clone = sib.cloneNode(true);
                clone.querySelectorAll("input, select, textarea, button, select").forEach(n => n.remove());
                const t = clone.innerText?.trim();
                if (t && isLabelLike(t) && t.split(/\s+/).length <= 5) return t;
            }
            sib = sib.previousElementSibling;
            checked++;
        }
        return null;
    }


    // ─── SKILL CONTEXT ──────────────────────────────────────────────────────────
    // Only look within the IMMEDIATE parent row — don't walk up more than 3 levels.
    // A skill name is the text node/span that sits beside the <select> in the same row.
    function getSkillContext(selectEl) {
        let node = selectEl.parentElement;

        for (let depth = 0; depth < 3 && node; depth++) {
            // Stop if this container is too big (has multiple selects — it's a section, not a row)
            const selectsInNode = node.querySelectorAll("select").length;
            if (selectsInNode > 1) {
                node = node.parentElement;
                continue;
            }

            // Look at siblings of `node` within node.parentElement
            const parent = node.parentElement;
            if (!parent) break;

            const siblings = [...parent.children].filter(c => c !== node);
            for (const sib of siblings) {
                // Clone to strip nested controls
                const clone = sib.cloneNode(true);
                clone.querySelectorAll("input, select, textarea, button").forEach(n => n.remove());
                const t = clone.innerText?.trim();

                if (!t || t.length === 0) continue;
                // Must be short (skill name), no meta-words
                if (t.length > 35) continue;
                if (/select|year|experience|month|notice|type|employer|salary|ctc|offer|relocate|submit|apply|overall|preferred/i.test(t)) continue;
                // Must look like a tech skill — allow letters, digits, spaces, / . + # -
                if (/^[a-zA-Z0-9 /.\-+#_]+$/.test(t)) return t;
            }

            node = node.parentElement;
        }

        return null;
    }


    // ─── FIELD EXTRACTION ───────────────────────────────────────────────────────
    function extractFields() {
        const elements = document.querySelectorAll("input, textarea, select");
        const fields = [];

        elements.forEach(el => {
            const type  = el.type || el.tagName.toLowerCase();
            const label = getLabel(el);

            // Skip file inputs, hidden, submit, button
            if (["file", "hidden", "submit", "button", "reset"].includes(type)) return;

            const field = {
                id:          el.id          || "",
                name:        el.name        || "",
                label:       label,
                placeholder: el.placeholder || "",
                type:        type,
            };

            // ── SELECT: collect options + detect skill context ──
            if (el.tagName === "SELECT") {
                field.options = [...el.options]
                    .filter(o => {
                        const t = o.text.trim();
                        return t && !/^select\b/i.test(t) && o.value !== "";
                    })
                    .map(o => ({ label: o.text.trim(), value: o.value || o.text.trim() }));

                const skill = getSkillContext(el);
                if (skill) field.skillContext = skill;
            }

            // ── RADIO group: collect all options in the group ──
            if (type === "radio") {
                field.radioValue = el.value;
                field.radioGroup = el.name;
            }

            fields.push(field);
        });

        return fields;
    }


    // ─── FILL PAGE ───────────────────────────────────────────────────────────────
    // React / Vue / Angular all intercept native value changes differently.
    // We must set value via the native input descriptor AND fire synthetic events.
    function nativeSet(el, value) {
        const proto = Object.getPrototypeOf(el);
        const descriptor =
            Object.getOwnPropertyDescriptor(proto, "value") ||
            Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value");

        if (descriptor && descriptor.set) {
            descriptor.set.call(el, value);
        } else {
            el.value = value;
        }
    }

    function triggerEvents(el) {
        ["input", "change", "blur"].forEach(evtName => {
            el.dispatchEvent(new Event(evtName, { bubbles: true }));
        });
        // React 16+ synthetic event
        el.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText" }));
    }

    function fillSelect(el, value) {
        // Try exact value match first, then label match
        let matched = [...el.options].find(o => o.value === value || o.text.trim() === value);
        if (!matched) {
            // Fuzzy: find option whose text contains the value or vice versa
            const v = value.toLowerCase();
            matched = [...el.options].find(o =>
                o.text.toLowerCase().includes(v) || v.includes(o.text.toLowerCase().trim())
            );
        }
        if (matched) {
            nativeSet(el, matched.value);
            triggerEvents(el);
            return true;
        }
        return false;
    }

    function fillRadio(el, value) {
        // value is the radio value to select
        if (el.value === value || el.value.toLowerCase() === value.toLowerCase()) {
            el.checked = true;
            triggerEvents(el);
            return true;
        }
        return false;
    }

    function fillPage(data) {
        Object.entries(data).forEach(([key, value]) => {
            if (value == null || value === "") return;

            // Find element by name, id, or data-field-id
            const selectors = [
                `[name="${CSS.escape(key)}"]`,
                `#${CSS.escape(key)}`,
                `[data-field-id="${CSS.escape(key)}"]`,
            ];

            let el = null;
            for (const sel of selectors) {
                try { el = document.querySelector(sel); } catch (_) {}
                if (el) break;
            }

            if (!el) return;

            if (el.tagName === "SELECT") {
                fillSelect(el, value);
            } else if (el.type === "radio") {
                // Fill all radios in the group
                document.querySelectorAll(`[name="${CSS.escape(key)}"]`).forEach(r => fillRadio(r, value));
            } else if (el.type === "checkbox") {
                const checked = ["yes", "true", "1"].includes(String(value).toLowerCase());
                el.checked = checked;
                triggerEvents(el);
            } else {
                nativeSet(el, value);
                triggerEvents(el);
            }
        });
    }


    // ─── MAIN FLOW ───────────────────────────────────────────────────────────────
    btn.onclick = async () => {
        btn.innerText = "⏳ Filling…";
        btn.disabled = true;

        try {
            const fields = extractFields();

            console.log("[AutoFill] Sending fields:", JSON.stringify(fields, null, 2));

            const response = await fetch("http://localhost:5500/fill", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ fields })
            });

            const data = await response.json();
            console.log("[AutoFill] Received data:", data);

            fillPage(data);

            btn.innerText = "✅ Done";
            setTimeout(() => { btn.innerText = "✦ AI Fill"; btn.disabled = false; }, 2000);

        } catch (err) {
            console.error("[AutoFill] Error:", err);
            btn.innerText = "❌ Error";
            setTimeout(() => { btn.innerText = "✦ AI Fill"; btn.disabled = false; }, 2000);
        }
    };
})();