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
MAX_ENTRIES = int(os.environ.get("NOTIFICATION_HISTORY_MAX", "500"))
IGNORED_APPS = {
    a.strip().casefold()
    for a in os.environ.get("NOTIFICATION_HISTORY_IGNORE", "").split(",")
    if a.strip()
}


def trim():
    try:
        lines = STORE.read_text(encoding="utf-8").splitlines()
    except OSError:
        return
    if len(lines) <= MAX_ENTRIES:
        return
    tmp = STORE.with_suffix(".tmp")
    tmp.write_text("\n".join(lines[-MAX_ENTRIES:]) + "\n", encoding="utf-8")
    os.chmod(tmp, 0o600)
    tmp.replace(STORE)


def hint_value(hints, key, fallback):
    # busctl renders each hint as {"type": ..., "data": ...} rather than a bare value.
    if not isinstance(hints, dict):
        return fallback
    raw = hints.get(key)
    if isinstance(raw, dict):
        return raw.get("data", fallback)
    return fallback if raw is None else raw


def record(seq, fields):
    app, _replaces, icon, summary, text, _actions, hints, _timeout = fields[:8]
    if app.casefold() in IGNORED_APPS:
        return False
    urgency = hint_value(hints, "urgency", 1)
    desktop_entry = hint_value(hints, "desktop-entry", "")
    with STORE.open("a", encoding="utf-8") as fh:
        fh.write(
            json.dumps(
                {
                    "seq": seq,
                    "ts": time.time(),
                    "app": app,
                    "desktopEntry": desktop_entry,
                    "icon": icon,
                    "summary": summary,
                    "body": text,
                    "urgency": urgency,
                },
                ensure_ascii=False,
            )
            + "\n"
        )
    return True


def main():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(STATE_DIR, 0o700)
    STORE.touch()
    os.chmod(STORE, 0o600)

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

    seq = 0
    for line in proc.stdout:
        line = line.strip()
        if '"Notify"' not in line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if msg.get("member") != "Notify":
            continue
        if msg.get("interface") != "org.freedesktop.Notifications":
            continue
        if msg.get("type") != "method_call":
            continue
        fields = msg.get("payload", {}).get("data")
        if not isinstance(fields, list) or len(fields) < 8:
            continue
        seq += 1
        if record(seq, fields) and seq % 50 == 0:
            trim()
    return proc.wait()


if __name__ == "__main__":
    sys.exit(main())
