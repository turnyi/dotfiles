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

keyring-locked() {
  local locked
  locked=$(busctl --user get-property org.freedesktop.secrets \
    /org/freedesktop/secrets/collection/login \
    org.freedesktop.Secret.Collection Locked 2>/dev/null)
  [[ "$locked" == "b true" ]]
}

keyring-unlock() {
  local pw

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
