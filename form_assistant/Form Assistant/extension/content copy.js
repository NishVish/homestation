(function () {
    if (document.getElementById("autofill-floating-btn")) return;

    const btn = document.createElement("button");
    btn.id = "autofill-floating-btn";
    btn.innerText = "Fill Data";

    Object.assign(btn.style, {
        position: "fixed",
        bottom: "20px",
        right: "20px",
        zIndex: "999999",
        padding: "12px 16px",
        background: "#111827",
        color: "#ffffff",
        border: "none",
        borderRadius: "999px",
        cursor: "pointer",
        fontSize: "14px",
        fontFamily: "Arial, sans-serif",
        boxShadow: "0 10px 25px rgba(0,0,0,0.25)",
        transition: "all 0.2s ease-in-out"
    });

    btn.onmouseenter = () => {
        btn.style.transform = "scale(1.05)";
        btn.style.background = "#2563eb";
    };

    btn.onmouseleave = () => {
        btn.style.transform = "scale(1)";
        btn.style.background = "#111827";
    };

    document.body.appendChild(btn);

    function extractFields() {
        const elements = document.querySelectorAll("input, textarea, select");
        return [...elements].map(el => ({
            id: el.id,
            name: el.name,
            label: el.placeholder || "",
            type: el.type
        }));
    }

    async function requestFilledData() {
        const fields = extractFields();

        const response = await fetch("http://localhost:5500/fill", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ fields })
        });

        return await response.json();
    }

    function fillPage(data) {
        Object.entries(data).forEach(([key, value]) => {
            if (value == null) return;

            let field =
                document.querySelector(`[name="${key}"]`) ||
                document.querySelector(`#${key}`);

            if (!field) return;

            field.value = value;

            field.dispatchEvent(new Event("input", { bubbles: true }));
            field.dispatchEvent(new Event("change", { bubbles: true }));
        });
    }

    btn.onclick = async () => {
        const data = await requestFilledData();
        fillPage(data);
    };
})();