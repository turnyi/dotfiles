#!/usr/bin/env bash
# pf — forward a remote port onto this machine's localhost over SSH, so you can
# talk to a service on another box (or a service that box can reach) as if it
# were running on your own localhost:<port>.
#
# It's the same trick as centinel-app's dev:tunnel, generalised: ssh -N -L.
#
# Usage:
#   pf <ssh-host> <port>                 # localhost:PORT  -> <ssh-host>:localhost:PORT
#   pf <ssh-host> <port> <port> ...      # forward several ports at once
#   pf <ssh-host> 8080:3000             # localhost:8080  -> <ssh-host>:localhost:3000
#   pf <ssh-host> db.internal:5432       # localhost:5432  -> db.internal:5432 (via <ssh-host>)
#   pf <ssh-host> 5432:db.internal:5432  # localhost:5432  -> db.internal:5432 (via <ssh-host>)
#
# Spec forms (mix freely):
#   PORT                      same port on the ssh host's localhost
#   LPORT:RPORT               local LPORT -> remote localhost:RPORT
#   RHOST:RPORT               remote host:port reachable *from* the ssh host, local = RPORT
#   LPORT:RHOST:RPORT         full control
#
# The ssh host can be anything ssh understands: a ~/.ssh/config alias, user@host,
# a Tailscale name, an IP. Stop with Ctrl-C.
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
fi
if [[ $# -lt 2 ]]; then
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 1
fi

HOST="$1"; shift

FORWARDS=()
for SPEC in "$@"; do
    IFS=':' read -ra P <<< "$SPEC"
    case "${#P[@]}" in
        1)  # PORT
            [[ "${P[0]}" =~ ^[0-9]+$ ]] || { echo "ERROR: bad port '$SPEC'" >&2; exit 1; }
            LPORT="${P[0]}"; RHOST="localhost"; RPORT="${P[0]}" ;;
        2)  if [[ "${P[0]}" =~ ^[0-9]+$ && "${P[1]}" =~ ^[0-9]+$ ]]; then
                # LPORT:RPORT
                LPORT="${P[0]}"; RHOST="localhost"; RPORT="${P[1]}"
            else
                # RHOST:RPORT
                [[ "${P[1]}" =~ ^[0-9]+$ ]] || { echo "ERROR: bad spec '$SPEC'" >&2; exit 1; }
                LPORT="${P[1]}"; RHOST="${P[0]}"; RPORT="${P[1]}"
            fi ;;
        3)  # LPORT:RHOST:RPORT
            [[ "${P[0]}" =~ ^[0-9]+$ && "${P[2]}" =~ ^[0-9]+$ ]] || { echo "ERROR: bad spec '$SPEC'" >&2; exit 1; }
            LPORT="${P[0]}"; RHOST="${P[1]}"; RPORT="${P[2]}" ;;
        *)  echo "ERROR: don't understand '$SPEC'" >&2; exit 1 ;;
    esac
    FORWARDS+=(-L "${LPORT}:${RHOST}:${RPORT}")
    echo "localhost:${LPORT}  ->  ${RHOST}:${RPORT}  (via ${HOST})"
done

echo "Tunneling to ${HOST} — Ctrl-C to stop."
exec ssh -N \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    "${FORWARDS[@]}" \
    "$HOST"
