from django.contrib import messages
from django.contrib import messages
from django.views.decorators.csrf import csrf_exempt
import os
import json
import sqlite3
from django.http import JsonResponse
from PyPDF2 import PdfReader
import requests

DB_PATH = os.path.join(os.path.dirname(__file__), "rag.sqlite3")
PDF_PATH = os.path.join(os.path.dirname(__file__), "documents", "cv.pdf")

OLLAMA_EMBED_URL = "http://localhost:11434/api/embeddings"



def train(request):
    init_db()

    conn = sqlite3.connect(DB_PATH)

    reader = PdfReader(PDF_PATH)
    text = ""

    for page in reader.pages:
        page_text = page.extract_text()
        if page_text:
            text += page_text + "\n"

    chunks = chunk_text(text)
    conn.execute("DELETE FROM chunks")  # reset index

    for chunk in chunks:
        embedding = get_embedding(chunk)

        conn.execute(
            "INSERT INTO chunks(text, embedding) VALUES (?, ?)",
            (chunk, json.dumps(embedding))
        )

    conn.commit()
    conn.close()

    return JsonResponse({
        "message": "Training completed",
        "chunks": len(chunks)
    })



def get_embedding(text):
    try:
        response = requests.post(
            OLLAMA_EMBED_URL,
            json={
                "model": "nomic-embed-text",
                "prompt": text
            },
            timeout=30
        )

        response.raise_for_status()
        data = response.json()

        return data.get("embedding", [])

    except Exception as e:
        print("Embedding error:", e)
        return []

def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS chunks (
            id INTEGER PRIMARY KEY,
            text TEXT,
            embedding TEXT
        )
    """)
    conn.commit()
    conn.close()
def chunk_text(text, size=800, overlap=150):
    chunks = []
    start = 0

    while start < len(text):
        end = start + size
        chunks.append(text[start:end])
        start = end - overlap

    return chunks

def cosine(a, b):
    import numpy as np

    a = np.array(a)
    b = np.array(b)

    if len(a) == 0 or len(b) == 0:
        return 0.0

    denom = np.linalg.norm(a) * np.linalg.norm(b)
    if denom == 0:
        return 0.0

    return float(np.dot(a, b) / denom)


    
def ask(request):
    query = request.GET.get("q", "")

    query_embedding = get_embedding(query)

    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute("SELECT text, embedding FROM chunks").fetchall()
    conn.close()

    def cosine(a, b):
        import numpy as np
        a = np.array(a)
        b = np.array(b)
        return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))

    results = []

    for text, emb in rows:
        emb = json.loads(emb)
        score = cosine(query_embedding, emb)
        results.append((score, text))

    results.sort(reverse=True, key=lambda x: x[0])

    return JsonResponse({
        "query": query,
        "results": [
            {"score": r[0], "text": r[1]}
            for r in results[:5]
        ]
    })




@csrf_exempt
def chat(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST only"}, status=400)

    try:
        body = json.loads(request.body)
    except Exception:
        return JsonResponse({"error": "Invalid JSON"}, status=400)
    
    message = body.get("message", "")

    print("Message: ",message)

    # 1. Get embedding for query
    query_embedding = get_embedding(message)

    print(query_embedding)

    # 2. Fetch stored chunks
    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute("SELECT text, embedding FROM chunks").fetchall()
    conn.close()

    import numpy as np

    def cosine(a, b):
        a = np.array(a)
        b = np.array(b)
        return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))

    # 3. Score chunks
    scored = []
    for text, emb in rows:
        emb = json.loads(emb)
        score = cosine(query_embedding, emb)
        scored.append((score, text))

    scored.sort(reverse=True, key=lambda x: x[0])

    # 4. Take top context
    top_context = "\n\n".join([t[1] for t in scored[:3]])

    message =  f"""
You are a helpful assistant.

Use the following context to answer the question.

Context:
{top_context}

Question:
{message}

Give a clear, short, and correct answer.
"""


    OLLAMA_URL = "http://localhost:11434/api/generate"




    response = requests.post(
            OLLAMA_URL,
            json={
                "model": "llama3",
                "prompt": message,
                "stream": False

            
            }
        )

    print("top_context : ",top_context)
    print("message : ",message)

    # try:
    #     # response.raise_for_status()
        
    # except Exception as e:
    #     return JsonResponse({
    #         "error": "LLM request failed",
    #         "details": str(e),
    #         "raw": response.text if 'response' in locals() else None
    #     }, status=500)
    

    answer = response.json().get("response", "")
    print(response.json())
    print("answer : ",answer)
    
    # 6. Return final response
    return JsonResponse({
        "message": message,
        "answer": answer,
        "top_score": scored[0][0] if scored else 0
    })

from django.shortcuts import render

def chat_page(request):
    return render(request, "rag/chat.html")