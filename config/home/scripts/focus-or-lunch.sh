#!/bin/bash
# focus-or-launch: focus an existing window or launch the app
# Mac: uses AeroSpace list-windows + aerospace focus for proper workspace switching
# Linux: uses hyprctl + gtk-launch

QUERY="$1"
TITLE_FILTER="$2"  # optional: filter by window title substring (e.g. Chrome profile name)
INDEX="${3:-1}"    # optional: which of the app's windows, 1-based (Super/Alt+S then 2 → second Slack)
if [ -z "$QUERY" ]; then
  echo "Usage: $0 app_name [title_filter] [index]"
  exit 1
fi

LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Match the app name column only. Grepping the whole line also searched
    # window titles, so a Chrome tab or terminal titled "... Slack ..." could
    # win over Slack itself. Titles are only consulted for TITLE_FILTER.
    # Numbered by workspace, then window id, so "2" keeps meaning the same window.
    WIN=$(aerospace list-windows --all --format '%{workspace}|%{window-id}|%{app-name}|%{window-title}' 2>/dev/null \
        | awk -F'|' -v q="$LOWER" -v t="$(echo "$TITLE_FILTER" | tr '[:upper:]' '[:lower:]')" \
            'index(tolower($3), q) && (t == "" || index(tolower($4), t)) { print $1 "|" $2 }' \
        | sort -t'|' -k1,1 -k2,2n \
        | sed -n "${INDEX}p" | cut -d'|' -f2)
    # Arm the Alt+digit chord for focus-nth-or-workspace.sh.
    printf '%s\t%s\n' "$QUERY" "$TITLE_FILTER" > "${TMPDIR:-/tmp}/focus-or-lunch.chord"
    if [ -n "$WIN" ]; then
        aerospace focus --window-id "$WIN"
    elif [ "$INDEX" -eq 1 ]; then
        open -a "$QUERY"
    fi
    exit 0
fi

# Linux (Hyprland)

# grep returns matches in readdir order, which is not stable: with two entries
# for one app (e.g. a Chrome PWA and a leftover firefoxpwa one) consecutive runs
# disagree on which comes first. Sort, then prefer an exact "Name=" hit over a
# substring one, so the same launcher wins every time. -R, not -r: launchers
# from dotfiles are symlinks, and -r silently skips symlinked files.
mapfile -t MATCHES < <(grep -Ril --include="*.desktop" "Name=$QUERY" \
    ~/.local/share/applications /usr/share/applications 2>/dev/null | sort)

# Window classes this app can show up as, matched exactly. Titles are never
# used: substring-matching them let any window titled "... Slack ..." (a Chrome
# tab, a terminal, a Claude session) steal the focus from Slack itself.
#   - the query itself, for binds that already name a class (kitty, discord)
#   - each launcher's StartupWMClass (Slack, FFPWA-<id>, crx_<id> on X11)
#   - each launcher's basename: Chrome PWAs map as chrome-<id>-<Profile> on
#     Wayland, which is exactly the .desktop name Chrome generated for them
CLASSES=("$LOWER")
for m in "${MATCHES[@]}"; do
    CLASSES+=("$(basename "$m" .desktop)")
    wm=$(grep -m1 "^StartupWMClass=" "$m" | cut -d= -f2-)
    [ -n "$wm" ] && CLASSES+=("$wm")
done

# Numbered by workspace, then on-screen position, so "2" keeps meaning the
# same window instead of following Hyprland's focus history.
WINDOW_ID=$(hyprctl clients -j | jq -r --argjson n "$INDEX" --args \
  '($ARGS.positional | map(ascii_downcase)) as $want
   | [.[] | select([.class, .initialClass] | map(. // "" | ascii_downcase) | any(IN($want[])))]
   | sort_by([.workspace.id, .at[0], .at[1]])
   | .[$n - 1].address // empty' "${CLASSES[@]}")

if [ -n "$WINDOW_ID" ]; then
    # A lua hyprland.conf makes `dispatch` a lua expression and rejects the
    # legacy "focuswindow address:..." form outright (exit 7), so try that shape
    # first and fall back for a session still running the old .conf parser.
    # Either way focuswindow follows the window to its workspace and monitor.
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$WINDOW_ID\" })" >/dev/null 2>&1 \
      || hyprctl dispatch focuswindow "address:$WINDOW_ID" >/dev/null 2>&1
    exit 0
fi

# Asked for window N of an app that has fewer: stay put rather than launch another.
[ "$INDEX" -gt 1 ] && exit 0

if [ ${#MATCHES[@]} -eq 0 ]; then
    echo "No .desktop file found for '$QUERY'"
    exit 1
fi
DESKTOP_PATH="${MATCHES[0]}"
for m in "${MATCHES[@]}"; do
    if grep -qix "Name=$QUERY" "$m"; then
        DESKTOP_PATH="$m"
        break
    fi
done
DESKTOP_NAME=$(basename "$DESKTOP_PATH" .desktop)
# Detach: the hyprland bind runs this via a throwaway `sh -c`, and a launcher
# left as its child dies with it before the window ever maps.
setsid -f gtk-launch "$DESKTOP_NAME" >/dev/null 2>&1
