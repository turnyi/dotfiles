# Unlocking the login keyring from a session PAM never unlocked.
#
# pam_gnome_keyring is wired into /etc/pam.d/sddm and nowhere else, so a boot
# where nobody logs in graphically leaves the login keyring locked. SSH can't
# recover through PAM either: KbdInteractiveAuthentication is off, so no
# password ever reaches the stack for pam_gnome_keyring to reuse.
#
# The password only ever takes in a daemon that receives it on stdin at
# startup, and only when nothing else holds org.freedesktop.secrets. Neither
# gentler route works here: --unlock against a running daemon's control socket
# silently unlocks a throwaway process that then exits, and --replace is
# refused because systemd's copy never requested the name with
# ALLOW_REPLACEMENT. So the field has to be cleared first. systemd starts its
# own copy again at the next boot; this is a per-boot action either way.
#
# The daemon logs "failed to unlock login keyring on startup" whenever it
# actually tested a password. Absence of that line means the password never
# reached it — a different failure than a wrong one, worth telling apart.

# busctl's connection failure is indistinguishable from "no login collection"
# once the output is discarded, so the bus gets its own probe: without it a
# dead broker reads as an unlocked keyring and every caller gives the wrong hint.
keyring-bus-up() {
  busctl --user status >/dev/null 2>&1
}

keyring-bus-hint() {
  print -u2 "keyring: the user D-Bus broker is down (earlyoom kills it under memory pressure). run:"
  print -u2 "  systemctl --user reset-failed && systemctl --user restart dbus.socket dbus-broker.service"
  print -u2 "  keyring-unlock"
}

keyring-locked() {
  local locked
  locked=$(busctl --user get-property org.freedesktop.secrets \
    /org/freedesktop/secrets/collection/login \
    org.freedesktop.Secret.Collection Locked 2>/dev/null)
  [[ "$locked" == "b true" ]]
}

keyring-unlock() {
  local pw

  if ! keyring-bus-up; then
    keyring-bus-hint
    return 1
  fi

  if ! keyring-locked; then
    print "keyring: already unlocked"
    return 0
  fi

  IFS= read -rs "pw?keyring password: " || return 1
  print

  if [[ -z "$pw" ]]; then
    print -u2 "keyring: empty password, nothing sent"
    return 1
  fi

  systemctl --user stop gnome-keyring-daemon.service gnome-keyring-daemon.socket 2>/dev/null
  # Exact match on the truncated comm: -f would also match the shell running
  # this function, since the pattern appears in its own command line.
  pkill -x gnome-keyring-d
  sleep 1

  # -rn -- is load-bearing: a password starting with "-" is otherwise parsed as
  # print's own options and the daemon receives empty stdin.
  print -rn -- "$pw" | gnome-keyring-daemon --daemonize \
    --components=pkcs11,secrets --unlock >/dev/null 2>&1
  pw=
  sleep 1

  # /usr/share/dbus-1/services/org.freedesktop.secrets.service auto-starts a
  # daemon on any Secret Service request, so anything asking during the gap
  # above takes the name and the unlock lands in a process that then exits.
  local owner
  owner=$(busctl --user status org.freedesktop.secrets 2>/dev/null | sed -n 's/^CommandLine=//p')
  if [[ "$owner" != *--unlock* ]]; then
    print -u2 "keyring: another secret service took the bus first:"
    print -u2 "  ${owner:-<none>}"
    print -u2 "keyring: run keyring-unlock again"
    return 1
  fi

  if keyring-locked; then
    print -u2 "keyring: still locked — the daemon rejected that password"
    print -u2 "keyring: check it got one:"
    print -u2 "  journalctl --user -n 10 --no-pager | grep 'failed to unlock'"
    return 1
  fi

  print "keyring: unlocked"
}

# Make the login keyring passwordless, so it opens on its own at every boot.
#
# gnome-keyring stores a blank-password keyring unencrypted and unlocks it as
# soon as the daemon loads it, which retires keyring-unlock on this box. The
# tradeoff: login.keyring then sits on disk in plaintext, guarded only by its
# 0600 mode and whatever disk encryption is underneath.
#
# ChangeWithPrompt needs a GUI prompter, which SSH doesn't have, so this goes
# through gnome-keyring's master-password interface instead. The password is
# handed to python on stdin, never argv, so it doesn't show up in ps.
keyring-clear-password() {
  local pw keyrings="$HOME/.local/share/keyrings"

  if ! keyring-bus-up; then
    keyring-bus-hint
    return 1
  fi

  if keyring-locked; then
    IFS= read -rs "pw?current keyring password: " || return 1
    print
    if [[ -z "$pw" ]]; then
      print -u2 "keyring: empty password, nothing sent"
      return 1
    fi
  fi

  cp -p "$keyrings/login.keyring" "$keyrings/login.keyring.bak-$(date +%Y%m%d%H%M%S)" || return 1

  print -rn -- "$pw" | python3 -c '
import sys, dbus
pw = sys.stdin.buffer.read()
bus = dbus.SessionBus()
svc = bus.get_object("org.freedesktop.secrets", "/org/freedesktop/secrets")
_, session = dbus.Interface(svc, "org.freedesktop.Secret.Service").OpenSession("plain", dbus.String("", variant_level=1))
internal = dbus.Interface(svc, "org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface")
login = dbus.ObjectPath("/org/freedesktop/secrets/collection/login")
secret = lambda value: dbus.Struct((session, dbus.ByteArray(b""), dbus.ByteArray(value), "text/plain"), signature="oayays")
try:
    if pw:
        internal.UnlockWithMasterPassword(login, secret(pw))
    internal.ChangeWithMasterPassword(login, secret(pw), secret(b""))
except dbus.DBusException as e:
    sys.exit("keyring: " + e.get_dbus_message())
'
  local rc=$?
  pw=
  (( rc == 0 )) || return 1

  if keyring-locked; then
    print -u2 "keyring: password cleared but the collection is still locked"
    return 1
  fi

  print "keyring: password cleared — login keyring now unlocks itself at boot"
}
