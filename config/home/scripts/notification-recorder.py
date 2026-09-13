#!/usr/bin/env python3
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

STATE_DIR = Path(
    os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")
) / "notification-history"
STORE = STATE_DIR / "history.jsonl"
PENDING = STATE_DIR / "pending.json"
MAX_ENTRIES = int(os.environ.get("NOTIFICATION_HISTORY_MAX", "500"))
IGNORED_APPS = {
    a.strip().casefold()
    for a in os.environ.get("NOTIFICATION_HISTORY_IGNORE", "").split(",")
    if a.strip()
}


def write_atomic(path, text):
    tmp = path.with_suffix(".tmp")
    tmp.write_text(text, encoding="utf-8")
    os.chmod(tmp, 0o600)
    tmp.replace(path)


def trim():
    try:
        lines = STORE.read_text(encoding="utf-8").splitlines()
    except OSError:
        return
    if len(lines) <= MAX_ENTRIES:
        return
    write_atomic(STORE, "\n".join(lines[-MAX_ENTRIES:]) + "\n")


def hint_value(hints, key, fallback):
    # busctl renders each hint as {"type": ..., "data": ...} rather than a bare value.
    if not isinstance(hints, dict):
        return fallback
    raw = hints.get(key)
    if isinstance(raw, dict):
        return raw.get("data", fallback)
    return fallback if raw is None else raw


def build_entry(fields):
    app, _replaces, icon, summary, text, _actions, hints, _timeout = fields[:8]
    if app.casefold() in IGNORED_APPS:
        return None
    return {
        "ts": time.time(),
        "app": app,
        "desktopEntry": hint_value(hints, "desktop-entry", ""),
        "icon": icon,
        "summary": summary,
        "body": text,
        "urgency": hint_value(hints, "urgency", 1),
    }


def append_history(entry):
    with STORE.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry, ensure_ascii=False) + "\n")


def save_pending(pending):
    write_atomic(PENDING, json.dumps(list(pending.values()), ensure_ascii=False))


def main():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(STATE_DIR, 0o700)
    STORE.touch()
    os.chmod(STORE, 0o600)

    # swaync keeps notifications in memory only, so anything the recorder did
    # not witness is unknowable; starting empty beats listing stale ids.
    pending = {}
    save_pending(pending)

    proc = subprocess.Popen(
        ["busctl", "--user", "monitor", "--json=short", "org.freedesktop.Notifications"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )

    def shutdown(*_):
        proc.terminate()
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    # The notification id only exists in swaync's reply, matched to the call by
    # (caller, cookie); waybar/eww polling floods the bus, hence the cheap
    # substring checks before any JSON parsing.
    awaiting = {}
    recorded = 0
    for line in proc.stdout:
        is_notify = '"Notify"' in line
        is_closed = '"NotificationClosed"' in line
        is_reply = bool(awaiting) and '"reply_cookie"' in line
        if not (is_notify or is_closed or is_reply):
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        kind = msg.get("type")
        data = msg.get("payload", {}).get("data")

        if is_notify and kind == "method_call" and msg.get("member") == "Notify":
            if not isinstance(data, list) or len(data) < 8:
                continue
            entry = build_entry(data)
            if entry is None:
                continue
            append_history(entry)
            recorded += 1
            if recorded % 50 == 0:
                trim()
            if len(awaiting) > 100:
                awaiting.clear()
            awaiting[(msg.get("sender"), msg.get("cookie"))] = entry
        elif is_closed and kind == "signal" and msg.get("member") == "NotificationClosed":
            if isinstance(data, list) and data and pending.pop(data[0], None):
                save_pending(pending)
        elif is_reply and kind == "method_return":
            entry = awaiting.pop((msg.get("destination"), msg.get("reply_cookie")), None)
            if entry is None or not isinstance(data, list) or not data:
                continue
            entry["id"] = data[0]
            pending[data[0]] = entry
            save_pending(pending)
    return proc.wait()


if __name__ == "__main__":
    sys.exit(main())
