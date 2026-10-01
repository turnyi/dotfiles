#!/usr/bin/env bash
set -euo pipefail

VERSION="3.2.0"
RELEASE_URL="https://github.com/Sathvik-Rao/ClipCascade/releases/download/$VERSION"
LINUX_ASSET="ClipCascade_Linux.zip"
LINUX_SHA256="5c42d3bec6efb79acae6f86e662d14b0be6162b7321aec64915775568913fbbd"
MAC_ARM_ASSET="ClipCascade-Apple_macOS.ARM_M-Series.zip"
MAC_ARM_SHA256="8e28bf0a16b03f8673d4ed6f9536166762bdb17417831655e2a07349afd73c73"
MAC_INTEL_ASSET="ClipCascade-Apple_macOS.Intel-Series.zip"
MAC_INTEL_SHA256="d8d04ef308cbd660323e3043fca37aa3a984fdb19462aabd851178ad2dd4b8cb"
PYTHON_VERSION="3.12"
PORT=8686
SERVER_HOST="${CLIPCASCADE_HOST:-turny.tail02a788.ts.net}"
SERVER_SSH="${CLIPCASCADE_SSH:-turny@$SERVER_HOST}"
USERNAME="admin"
DEFAULT_PASSWORD="admin123"

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
COMPOSE_SOURCE="$(cd "$SCRIPT_DIR/../.." && pwd)/.config/clipcascade/docker-compose.yml"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/clipcascade"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/clipcascade"
CLIENT_DIR="$DATA_DIR/ClipCascade"
VENV_PYTHON="$DATA_DIR/venv/bin/python"
PASSWORD_FILE="$CONFIG_DIR/password"
MAC_APP="/Applications/ClipCascade.app"
MAC_DATA_DIR="$HOME/Library/Application Support/ClipCascade"

is_server_host() {
  [ "$(uname -s)" = "Linux" ] && [ "$(uname -n)" = "${SERVER_HOST%%.*}" ]
}

if is_server_host; then
  SERVER_URL="http://127.0.0.1:$PORT"
else
  SERVER_URL="https://$SERVER_HOST:$PORT"
fi

sha3() {
  python3 -c "import hashlib, sys; print(hashlib.sha3_512(sys.stdin.buffer.read()).hexdigest())"
}

password_hash() {
  tr -d "\n" <"$PASSWORD_FILE" | sha3
}

sha256() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1"
  else
    shasum -a 256 "$1"
  fi | cut -d " " -f 1
}

download() {
  local asset="$1" expected="$2" target="$3"
  curl -fsSL -o "$target" "$RELEASE_URL/$asset"
  if [ "$(sha256 "$target")" != "$expected" ]; then
    echo "Checksum mismatch for $asset" >&2
    return 1
  fi
}

wait_for_server() {
  until curl -fs -o /dev/null "$SERVER_URL/health"; do
    sleep 2
  done
}

login() {
  local jar="$1" hash="$2" token
  token="$(curl -fs -c "$jar" "$SERVER_URL/login" | grep -o 'name="_csrf"[^>]*value="[^"]*"' | sed 's/.*value="//;s/"//')"
  curl -fs -b "$jar" -c "$jar" -o /dev/null -w "%{redirect_url}" \
    -d "username=$USERNAME" -d "password=$hash" --data-urlencode "_csrf=$token" "$SERVER_URL/login"
}

replace_default_password() {
  [ -s "$PASSWORD_FILE" ] && return 0
  local jar csrf token header
  jar="$(mktemp)"
  if [[ "$(login "$jar" "$(printf %s "$DEFAULT_PASSWORD" | sha3)")" == *"/login?error" ]]; then
    rm -f "$jar"
    echo "The server no longer uses the default password; write the current one to $PASSWORD_FILE" >&2
    return 1
  fi
  (umask 077 && python3 -c "import secrets; print(secrets.token_urlsafe(18))" >"$PASSWORD_FILE")
  csrf="$(curl -fs -b "$jar" "$SERVER_URL/csrf-token")"
  token="$(python3 -c "import json, sys; print(json.loads(sys.argv[1])['token'])" "$csrf")"
  header="$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get('headerName') or 'X-CSRF-TOKEN')" "$csrf")"
  curl -fs -b "$jar" -o /dev/null -X PUT -H "Content-Type: application/json" -H "$header: $token" \
    -d "{\"newPassword\":\"$(password_hash)\"}" "$SERVER_URL/update-password"
  rm -f "$jar"
}

fetch_password() {
  [ -s "$PASSWORD_FILE" ] && return 0
  (umask 077 && ssh "$SERVER_SSH" "cat .config/clipcascade/password" >"$PASSWORD_FILE")
}

start_server() {
  ln -sfn "$COMPOSE_SOURCE" "$CONFIG_DIR/docker-compose.yml"
  docker compose -f "$CONFIG_DIR/docker-compose.yml" up -d
  wait_for_server
  replace_default_password
  tailscale serve --bg --https="$PORT" "$SERVER_URL" >/dev/null
}

# The client only re-logs in unattended when encryption is off and the password hash
# is saved; an empty (non-null) cookie sends it down that path on first run.
seed_login() {
  local data_file="$1"
  [ -f "$data_file" ] && return 0
  (
    umask 077
    cat >"$data_file" <<EOF
{
  "cipher_enabled": false,
  "save_password": true,
  "server_url": "$SERVER_URL",
  "username": "$USERNAME",
  "password": "$(password_hash)",
  "cookie": {}
}
EOF
  )
}

install_linux_client() {
  [ -f "$DATA_DIR/version" ] && [ "$(<"$DATA_DIR/version")" = "$VERSION" ] && return 0
  local tmp
  tmp="$(mktemp -d)"
  download "$LINUX_ASSET" "$LINUX_SHA256" "$tmp/client.zip"
  unzip -q -o "$tmp/client.zip" -d "$DATA_DIR"
  rm -rf "$tmp"
  uv venv --quiet --allow-existing --python "$PYTHON_VERSION" "$DATA_DIR/venv"
  uv pip install --quiet --python "$VENV_PYTHON" -r "$CLIENT_DIR/requirements.txt"
  echo "$VERSION" >"$DATA_DIR/version"
}

install_mac_client() {
  [ -d "$MAC_APP" ] && return 0
  local tmp asset="$MAC_INTEL_ASSET" sha256="$MAC_INTEL_SHA256"
  if [ "$(uname -m)" = "arm64" ]; then
    asset="$MAC_ARM_ASSET"
    sha256="$MAC_ARM_SHA256"
  fi
  tmp="$(mktemp -d)"
  download "$asset" "$sha256" "$tmp/client.zip"
  unzip -q "$tmp/client.zip" -d "$tmp"
  mv "$(find "$tmp" -maxdepth 2 -name "ClipCascade.app" -not -path "*/__MACOSX/*")" "$MAC_APP"
  rm -rf "$tmp"
}

setup_mac() {
  fetch_password
  install_mac_client
  mkdir -p "$MAC_DATA_DIR"
  seed_login "$MAC_DATA_DIR/DATA"
  osascript -e 'tell application "System Events" to if not (exists login item "ClipCascade") then make login item at end with properties {path:"'"$MAC_APP"'", hidden:true}' >/dev/null
  open "$MAC_APP"
}

setup_linux() {
  if is_server_host; then
    start_server
  else
    fetch_password
  fi
  install_linux_client
  seed_login "$CLIENT_DIR/DATA"
}

setup() {
  mkdir -p "$CONFIG_DIR" "$DATA_DIR"
  if [ "$(uname -s)" = "Darwin" ]; then
    setup_mac
  else
    setup_linux
  fi
}

session_is_valid() {
  local session status
  session="$("$VENV_PYTHON" -c "import json, sys; print((json.load(open(sys.argv[1])).get('cookie') or {}).get('JSESSIONID', ''))" "$CLIENT_DIR/DATA")"
  status="$(curl -s -o /dev/null -w "%{http_code}" -H "Cookie: JSESSIONID=$session" "$SERVER_URL/max-message-size" || true)"
  [ "$status" != "302" ]
}

stop_client() {
  [ -n "${CLIENT_PID:-}" ] && kill -- "-$CLIENT_PID" 2>/dev/null
  return 0
}

run_client() {
  mkdir -p "$DATA_DIR"
  exec 9>"$DATA_DIR/launcher.lock"
  flock -n 9 || exit 0
  install_linux_client
  seed_login "$CLIENT_DIR/DATA"
  [ -p "$DATA_DIR/stdin" ] || mkfifo "$DATA_DIR/stdin"
  cd "$CLIENT_DIR"
  trap stop_client EXIT
  trap "exit 0" TERM INT

  # The server keeps sessions in memory, and after it restarts the client retries
  # its dead cookie forever instead of logging in again; only a fresh start does.
  while true; do
    wait_for_server
    # CLI mode blocks on a menu prompt and quits on EOF; a FIFO opened read-write
    # never reports EOF, so the client keeps running without a terminal.
    # With XWayland up the client assumes X11 and polls; --xmode false makes it
    # use the event-driven `wl-paste --watch` instead.
    setsid "$VENV_PYTHON" main.py --gui false --xmode false <>"$DATA_DIR/stdin" >/dev/null 9>&- &
    CLIENT_PID=$!
    while kill -0 "$CLIENT_PID" 2>/dev/null; do
      sleep 60 &
      wait $! || true
      if ! session_is_valid; then
        stop_client
        wait "$CLIENT_PID" || true
      fi
    done
  done
}

case "${1:-client}" in
  client) run_client ;;
  setup) setup ;;
  *) echo "Usage: $0 [client|setup]" >&2; exit 1 ;;
esac
