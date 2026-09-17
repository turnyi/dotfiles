#!/usr/bin/env python3
"""claude-board.py — local web kanban over the Claude fleet.

  claude-board.py          serve http://127.0.0.1:4821 in the foreground
  claude-board.py --open   start the server if it is not running, open the browser

Every column of data is what claude-fleet.sh already computes (cards under
$XDG_RUNTIME_DIR/claude-fleet/cards), joined with the session's task list,
action log and the tail of its transcript. Nothing here is narrated by a model.
"""
import glob
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get("CLAUDE_BOARD_PORT", "4821"))
HERE = Path(__file__).resolve().parent
FLEET = HERE / "claude-fleet.sh"
GOTO = HERE / "claude-agents-goto.sh"
PAGE = HERE / "claude-board.html"
RUN = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "claude-fleet"
CARDS = RUN / "cards"
PROJECTS = Path.home() / ".claude" / "projects"
REFRESH_SECONDS = 8
TRANSCRIPT_TAIL_BYTES = 400_000

ETA_CLOCK = re.compile(r"\bETA\b[^0-9]{0,12}(\d{1,2}:\d{2})", re.I)
ETA_SPAN = re.compile(r"\bETA\b[^~\d]{0,20}~?\s*(\d+)\s*(min|m|h|hr|hours?|minutes?)\b", re.I)

COLUMN_OF = {
    "answer": "needs_you",
    "approve": "needs_you",
    "working": "working",
    "open PR": "action",
    "merge": "action",
    "fix CI": "action",
    "triage review": "action",
    "review diff": "action",
    "wait CI": "action",
    "reap": "idle",
    "idle": "idle",
}

state = {"generated": 0, "cards": [], "refreshing": False}
lock = threading.Lock()


def sh(*args, timeout=20):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout
    except (subprocess.SubprocessError, OSError):
        return ""


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text")
    return ""


def read_transcript(session_id):
    if not session_id:
        return {}
    matches = glob.glob(str(PROJECTS / "*" / f"{session_id}.jsonl"))
    if not matches:
        return {}
    path = matches[0]
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        size = f.tell()
        f.seek(max(0, size - TRANSCRIPT_TAIL_BYTES))
        raw = f.read().decode("utf-8", "replace")
    lines = raw.split("\n")[1:] if size > TRANSCRIPT_TAIL_BYTES else raw.split("\n")

    last_assistant = ""
    last_prompt = ""
    last_ts = ""
    tools_this_turn = 0
    turns = 0
    for line in lines:
        if not line.startswith("{"):
            continue
        try:
            rec = json.loads(line)
        except ValueError:
            continue
        kind = rec.get("type")
        msg = rec.get("message") or {}
        content = msg.get("content")
        if kind == "user":
            prompt = text_of(content).strip()
            is_tool_result = isinstance(content, list) and any(
                isinstance(b, dict) and b.get("type") == "tool_result" for b in content
            )
            if prompt and not is_tool_result and not prompt.startswith("<"):
                last_prompt = prompt
                tools_this_turn = 0
                turns += 1
        elif kind == "assistant":
            if isinstance(content, list):
                tools_this_turn += sum(1 for b in content if isinstance(b, dict) and b.get("type") == "tool_use")
            text = text_of(content).strip()
            if text:
                last_assistant = text
        ts = rec.get("timestamp")
        if ts:
            last_ts = ts

    return {
        "last_assistant": last_assistant,
        "last_prompt": last_prompt,
        "last_ts": last_ts,
        "tools_this_turn": tools_this_turn,
        "turns_seen": turns,
        "eta": find_eta(last_assistant),
    }


def find_eta(text):
    if not text:
        return ""
    clock = ETA_CLOCK.search(text)
    span = ETA_SPAN.search(text)
    if clock and span:
        return f"{clock.group(1)} (~{span.group(1)}{span.group(2)[0]})"
    if clock:
        return clock.group(1)
    if span:
        return f"~{span.group(1)}{span.group(2)[0]}"
    return ""


def read_tasks(session_id):
    path = RUN / "tasks" / f"{session_id}.json"
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return []
    return [{"id": k, **v} for k, v in data.items()]


def read_actions(session_id, n=8):
    path = RUN / "actions" / f"{session_id}.log"
    try:
        rows = path.read_text().rstrip("\n").split("\n")[-n:]
    except OSError:
        return []
    out = []
    for row in rows:
        parts = row.split("\t", 2)
        if len(parts) == 3:
            out.append({"at": int(parts[0]), "tool": parts[1], "detail": parts[2]})
    return out


def refresh():
    started = time.time()
    sh(str(FLEET), "--rows", timeout=60)
    cards = []
    for path in CARDS.glob("*.json"):
        if path.stat().st_mtime < started - 1:
            continue
        try:
            card = json.loads(path.read_text())
        except ValueError:
            continue
        if card.get("next") in ("—", "", None):
            continue
        sid = card.get("sess_id") or ""
        card["column"] = COLUMN_OF.get(card.get("next"), "idle")
        card["name"] = os.path.basename(card.get("wt") or card.get("bg_name") or card.get("key") or "")
        card["tasks_list"] = read_tasks(sid) if sid else []
        card["actions"] = read_actions(sid) if sid else []
        card["transcript"] = read_transcript(sid)
        cards.append(card)
    order = {"needs_you": 0, "working": 1, "action": 2, "idle": 3}
    cards.sort(key=lambda c: (order[c["column"]], c.get("name", "")))
    with lock:
        state["cards"] = cards
        state["generated"] = int(time.time())


def refresher():
    while True:
        try:
            refresh()
        except Exception as exc:
            print(f"refresh failed: {exc}", file=sys.stderr)
        time.sleep(REFRESH_SECONDS)


def goto(pane):
    sh(str(GOTO), pane)
    sh("hyprctl", "dispatch", "focuswindow", "class:^(kitty)$")


def pane_tail(pane, lines=30):
    return sh("tmux", "capture-pane", "-p", "-J", "-t", pane, "-S", f"-{lines}")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", f"{ctype}; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlparse(self.path)
        q = parse_qs(url.query)
        if url.path == "/":
            self.send(200, PAGE.read_bytes(), "text/html")
        elif url.path == "/api/board":
            with lock:
                self.send(200, json.dumps({"now": int(time.time()), **state}))
        elif url.path == "/api/tail":
            self.send(200, json.dumps({"tail": pane_tail(q.get("pane", [""])[0])}))
        else:
            self.send(404, "{}")

    def do_POST(self):
        url = urlparse(self.path)
        q = parse_qs(url.query)
        if url.path == "/api/goto":
            goto(q.get("pane", [""])[0])
            self.send(200, "{}")
        elif url.path == "/api/refresh":
            threading.Thread(target=refresh, daemon=True).start()
            self.send(202, "{}")
        else:
            self.send(404, "{}")


def port_open():
    with socket.socket() as s:
        return s.connect_ex(("127.0.0.1", PORT)) == 0


def serve():
    threading.Thread(target=refresher, daemon=True).start()
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()


if __name__ == "__main__":
    if "--open" in sys.argv:
        if not port_open():
            subprocess.Popen(
                [sys.executable, __file__],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            for _ in range(50):
                if port_open():
                    break
                time.sleep(0.1)
        webbrowser.open(f"http://127.0.0.1:{PORT}/")
    else:
        serve()
