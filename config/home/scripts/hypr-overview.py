#!/usr/bin/env python3
import configparser
import json
import os
import subprocess
import sys
import time
from pathlib import Path

CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "hypr-overview" / "icons.json"
FALLBACK_ICON = "application-x-executable"
ICON_SIZE = 64


def hyprctl(what):
    out = subprocess.run(["hyprctl", "-j", what], capture_output=True, text=True, timeout=2)
    return json.loads(out.stdout or "null")


def application_dirs():
    data_home = os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    for base in [data_home, *data_dirs, "/var/lib/flatpak/exports/share"]:
        path = Path(base) / "applications"
        if path.is_dir():
            yield path


def desktop_index():
    index = {}
    for directory in application_dirs():
        for entry in directory.glob("*.desktop"):
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                parser.read(entry, encoding="utf-8")
                section = parser["Desktop Entry"]
            except (configparser.Error, KeyError, UnicodeDecodeError):
                continue
            icon = section.get("Icon", "").strip()
            if not icon:
                continue
            keys = [entry.stem.lower(), entry.stem.lower().split(".")[-1]]
            wm_class = section.get("StartupWMClass", "").strip().lower()
            if wm_class:
                keys.append(wm_class)
            for key in keys:
                index.setdefault(key, icon)
    return index


def resolve_icon_file(name):
    if name.startswith("/"):
        return name if Path(name).is_file() else None
    import gi

    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk

    info = Gtk.IconTheme.get_default().lookup_icon(name, ICON_SIZE, 0)
    return info.get_filename() if info else None


def load_cache():
    try:
        return json.loads(CACHE.read_text())
    except (OSError, ValueError):
        return {}


def save_cache(cache):
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(cache))


def icons_for(classes):
    cache = load_cache()
    missing = [c for c in classes if c not in cache or not Path(cache[c]).is_file()]
    if missing:
        index = desktop_index()
        for wm_class in missing:
            key = wm_class.lower()
            candidates = [index.get(key), index.get(key.split(".")[-1]), key, FALLBACK_ICON]
            for name in candidates:
                path = name and resolve_icon_file(name)
                if path:
                    cache[wm_class] = path
                    break
            else:
                cache[wm_class] = ""
        save_cache(cache)
    return {c: cache.get(c, "") for c in classes}


def build():
    monitors = hyprctl("monitors") or []
    workspaces = [w for w in hyprctl("workspaces") or [] if w["id"] > 0]
    clients = [c for c in hyprctl("clients") or [] if c.get("mapped", True) and c["workspace"]["id"] > 0]
    active = hyprctl("activewindow") or {}

    visible = {m["activeWorkspace"]["id"] for m in monitors}
    focused_ws = next((m["activeWorkspace"]["id"] for m in monitors if m.get("focused")), None)
    focused_addr = active.get("address")
    icons = icons_for(sorted({c["class"] for c in clients if c.get("class")}))

    by_ws = {}
    for client in sorted(clients, key=lambda c: (c["at"][0], c["at"][1])):
        wm_class = client.get("class") or "unknown"
        apps = by_ws.setdefault(client["workspace"]["id"], {})
        app = apps.setdefault(wm_class, {"icon": icons.get(wm_class, ""), "count": 0, "focused": False})
        app["count"] += 1
        app["focused"] = app["focused"] or client["address"] == focused_addr
        app["dots"] = "\u25cf" * min(app["count"], 4)

    cards = []
    for ws in sorted(workspaces, key=lambda w: w["id"]):
        apps = list(by_ws.get(ws["id"], {}).values())
        cards.append({
            "id": ws["id"],
            "name": ws["name"],
            "monitor": ws["monitor"],
            "active": ws["id"] == focused_ws,
            "visible": ws["id"] in visible,
            "apps": apps,
            "empty": not apps,
        })

    title = active.get("title") or ""
    return {
        "time": time.strftime("%H:%M"),
        "date": time.strftime("%A %d %B"),
        "title": title,
        "app": active.get("class") or "",
        "workspaces": cards,
    }


if __name__ == "__main__":
    json.dump(build(), sys.stdout, ensure_ascii=False)
