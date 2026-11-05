#!/usr/bin/env bash
set -euo pipefail

CHROME="google-chrome-stable"

url="${1:-}"
host="${url#*://}"
host="${host%%/*}"
host="${host%%:*}"

# --app-launch-url-for-shortcuts-menu-item is the only switch that opens an arbitrary in-scope URL inside an
# installed PWA; --app=URL spawns a generic app window with a different class that focus-or-launch can't find.
open_in_app() {
  exec "$CHROME" "--profile-directory=$1" --app-id="$2" --app-launch-url-for-shortcuts-menu-item="$url"
}

case "$host" in
  linear.app) open_in_app "Profile 5" "bgdbmehlmdmddlgneophbcddadgknlpm" ;;
  web.whatsapp.com) open_in_app "Default" "hnpfjngllnobngcgfapefoaidbinmjnm" ;;
esac

exec "$CHROME" "$@"
