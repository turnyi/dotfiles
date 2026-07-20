#!/usr/bin/env bash
# notif-count — how many notifications are sitting in Notification Center, plus
# a best-effort app-font glyph for the most recent one. Prints "<count>|<token>"
# e.g. "3|:slack:"  (token empty when the app is unknown or count is 0).
#
# The data lives in the protected `usernoted` database. On macOS 13+ reading it
# requires Full Disk Access for whatever process runs this (i.e. sketchybar). If
# access is denied we degrade to "0|" rather than erroring.
set -uo pipefail

DB="$HOME/Library/Group Containers/group.com.apple.usernoted/db2/db"

fail() { echo "0|"; exit 0; }
[ -f "$DB" ] || fail

# usernoted keeps the db open, so query a snapshot copy to dodge the lock.
TMP="$(mktemp -t notifdb.XXXXXX)" || fail
trap 'rm -f "$TMP" "$TMP-wal" "$TMP-shm" 2>/dev/null' EXIT
cp "$DB" "$TMP" 2>/dev/null || fail
[ -f "$DB-wal" ] && cp "$DB-wal" "$TMP-wal" 2>/dev/null
[ -f "$DB-shm" ] && cp "$DB-shm" "$TMP-shm" 2>/dev/null

count="$(sqlite3 "$TMP" "SELECT COUNT(*) FROM record;" 2>/dev/null)"
[[ "$count" =~ ^[0-9]+$ ]] || fail
[ "$count" -eq 0 ] && { echo "0|"; exit 0; }

# Bundle id of the app whose newest notification is on top of the stack.
bundle="$(sqlite3 "$TMP" \
  "SELECT a.identifier FROM record r JOIN app a ON a.app_id = r.app_id \
   ORDER BY r.delivered_date DESC LIMIT 1;" 2>/dev/null)"

# Map to a sketchybar-app-font token (same tokens used by aerospace_spaces.sh).
token=""
case "$bundle" in
  com.tinyspeck.slackmacgap)                 token=":slack:" ;;
  com.hnc.Discord)                           token=":discord:" ;;
  com.spotify.client)                        token=":spotify:" ;;
  net.whatsapp.WhatsApp*|*hnpfjngllnobngcgfapefoaidbinmjnm) token=":whats_app:" ;;
  com.apple.MobileSMS|com.apple.iChat)       token=":messages:" ;;
  com.apple.mail)                            token=":mail:" ;;
  com.apple.iCal|com.apple.CalendarAgent)    token=":calendar:" ;;
  com.apple.reminders)                       token=":reminders:" ;;
  md.obsidian)                               token=":obsidian:" ;;
  com.google.Chrome*)                        token=":google_chrome:" ;;
  com.apple.Music)                           token=":music:" ;;
  us.zoom.xos)                               token=":zoom:" ;;
  *)                                         token=":default:" ;;
esac

echo "${count}|${token}"
