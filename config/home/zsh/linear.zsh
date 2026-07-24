# Linear MCP credential switcher.
#
# There is a single Linear MCP server registered in ~/.claude.json:
#
#   linear -> https://mcp.linear.app/mcp
#             Authorization: Bearer ${LINEAR_API_KEY}
#
# Claude Code expands ${LINEAR_API_KEY} from its own environment when it opens
# the connection, so pointing that variable at a different personal API key is
# enough to switch Linear workspaces. Personal API keys don't expire, so this
# never triggers a re-authentication.
#
# The keys live in the system keyring, never in this repo:
#
#   secret-tool store --label="Linear Centinel" linear centinel
#   secret-tool store --label="Linear OptiTask" linear optitask
#
# Matching is a case-insensitive substring test on the whole path rather than a
# registered list of directories, so new git worktrees are picked up with no
# extra setup wherever they live.

# Map a directory to the keyring slot holding its Linear key. optitask is the
# default, so it also wins when a path matches both projects.
_linear_slot_for_dir() {
  case "${1:l}" in
    *opti*)     print optitask ;;
    *centinel*) print centinel ;;
    *)          print optitask ;;
  esac
}

# Wrap claude so LINEAR_API_KEY is resolved fresh at launch. The assignment is
# scoped to the command, so the key never lingers in the interactive shell.
claude() {
  local slot key
  slot=$(_linear_slot_for_dir "$PWD")

  if [[ -z "$slot" ]]; then
    command claude "$@"
    return $?
  fi

  key=$(secret-tool lookup linear "$slot" 2>/dev/null)
  if [[ -z "$key" ]]; then
    print -u2 "linear: no key in keyring for '$slot'"
    print -u2 "linear: fix with: secret-tool store --label=\"Linear $slot\" linear $slot"
    command claude "$@"
    return $?
  fi

  LINEAR_API_KEY="$key" command claude "$@"
}

# Report which Linear identity the current directory resolves to.
linear-whoami() {
  local slot key
  slot=$(_linear_slot_for_dir "$PWD")

  if [[ -z "$slot" ]]; then
    print "linear: $PWD maps to no Linear workspace"
    return 1
  fi

  key=$(secret-tool lookup linear "$slot" 2>/dev/null)
  if [[ -z "$key" ]]; then
    print -u2 "linear: slot '$slot' matched but no key stored in the keyring"
    return 1
  fi

  print "slot: $slot"
  curl -s -X POST https://api.linear.app/graphql \
    -H "Authorization: $key" \
    -H "Content-Type: application/json" \
    -d '{"query":"{ viewer { email } organization { name } }"}'
  print
}
