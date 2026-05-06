import json
import os
import socket
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, request, redirect, url_for

app = Flask(__name__)

CONFIG_PATH = os.environ.get("CONFIG_PATH", "/config/app.json")
DATA_DIR = os.environ.get("DATA_DIR", "/data")
NOTES_FILE = os.path.join(DATA_DIR, "notes.json")


def load_config():
    try:
        with open(CONFIG_PATH) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"title": "NKE Workshop", "theme_color": "#1a73e8"}


def load_notes():
    try:
        with open(NOTES_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []


def save_notes(notes):
    Path(DATA_DIR).mkdir(parents=True, exist_ok=True)
    with open(NOTES_FILE, "w") as f:
        json.dump(notes, f, indent=2)


@app.route("/", methods=["GET"])
def index():
    config = load_config()
    notes = load_notes()
    title = config.get("title", "NKE Workshop")
    color = config.get("theme_color", "#1a73e8")
    message = config.get("message", "Welcome to the NKE Kubernetes Workshop!")

    pod_name = os.environ.get("POD_NAME", "unknown")
    pod_ip = os.environ.get("POD_IP", "unknown")
    node_name = os.environ.get("NODE_NAME", "unknown")
    namespace = os.environ.get("POD_NAMESPACE", "unknown")
    hostname = socket.gethostname()

    notes_html = ""
    for note in reversed(notes):
        notes_html += f"""
        <div class="note">
            <span class="note-text">{note['text']}</span>
            <span class="note-meta">{note['timestamp']} &mdash; from {note.get('pod', 'unknown')}</span>
        </div>"""

    if not notes:
        notes_html = '<p class="empty">No notes yet. Add one above!</p>'

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
               background: #f5f5f5; color: #333; }}
        .header {{ background: {color}; color: white; padding: 2rem; text-align: center; }}
        .header h1 {{ font-size: 2rem; margin-bottom: 0.5rem; }}
        .header p {{ opacity: 0.9; font-size: 1.1rem; }}
        .container {{ max-width: 800px; margin: 2rem auto; padding: 0 1rem; }}
        .card {{ background: white; border-radius: 8px; padding: 1.5rem;
                 margin-bottom: 1.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }}
        .card h2 {{ color: {color}; margin-bottom: 1rem; font-size: 1.2rem; }}
        .info-grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }}
        .info-item {{ display: flex; flex-direction: column; }}
        .info-label {{ font-size: 0.8rem; color: #888; text-transform: uppercase; }}
        .info-value {{ font-family: monospace; font-size: 0.95rem; color: #333; }}
        form {{ display: flex; gap: 0.5rem; }}
        form input {{ flex: 1; padding: 0.75rem; border: 1px solid #ddd;
                      border-radius: 4px; font-size: 1rem; }}
        form button {{ padding: 0.75rem 1.5rem; background: {color}; color: white;
                       border: none; border-radius: 4px; cursor: pointer; font-size: 1rem; }}
        form button:hover {{ opacity: 0.9; }}
        .note {{ padding: 0.75rem 0; border-bottom: 1px solid #eee; }}
        .note:last-child {{ border-bottom: none; }}
        .note-text {{ display: block; margin-bottom: 0.25rem; }}
        .note-meta {{ font-size: 0.8rem; color: #999; }}
        .empty {{ color: #999; font-style: italic; }}
        .footer {{ text-align: center; padding: 2rem; color: #999; font-size: 0.85rem; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>{title}</h1>
        <p>{message}</p>
    </div>
    <div class="container">
        <div class="card">
            <h2>Pod Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Pod Name</span>
                    <span class="info-value">{pod_name}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Namespace</span>
                    <span class="info-value">{namespace}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Pod IP</span>
                    <span class="info-value">{pod_ip}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Node</span>
                    <span class="info-value">{node_name}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Hostname</span>
                    <span class="info-value">{hostname}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Config Source</span>
                    <span class="info-value">{CONFIG_PATH}</span>
                </div>
            </div>
        </div>
        <div class="card">
            <h2>Workshop Notes (stored on PVC)</h2>
            <form method="POST" action="/notes">
                <input type="text" name="text" placeholder="Add a note..." required>
                <button type="submit">Add</button>
            </form>
        </div>
        <div class="card">
            {notes_html}
        </div>
    </div>
    <div class="footer">
        NKE Workshop Demo App &mdash; Deployed on Nine Kubernetes Engine
    </div>
</body>
</html>"""


@app.route("/notes", methods=["POST"])
def add_note():
    text = request.form.get("text", "").strip()
    if text:
        notes = load_notes()
        notes.append({
            "text": text,
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
            "pod": os.environ.get("POD_NAME", socket.gethostname()),
        })
        save_notes(notes)
    return redirect(url_for("index"))


@app.route("/healthz")
def healthz():
    return {"status": "ok"}


@app.route("/readyz")
def readyz():
    config = load_config()
    data_dir_exists = os.path.isdir(DATA_DIR)
    return {
        "status": "ok" if data_dir_exists else "not ready",
        "config_loaded": bool(config),
        "data_dir": data_dir_exists,
    }, 200 if data_dir_exists else 503


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
