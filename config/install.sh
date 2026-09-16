#!/usr/bin/env bash
set -e
PATTERN="$1"
DOTFILES_DIR=~/Projects/dotfiles
CONFIG_PATH="$DOTFILES_DIR/config/.config"
HOME_SOURCE="$DOTFILES_DIR/config/home"
CONFIG_DIR="$HOME/.config"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/utils.sh"

echo "🔧 Starting dotfiles setup..."

# process_path "$CONFIG_PATH" "$CONFIG_DIR" ".config"
process_path "$HOME_SOURCE" "$HOME" "HOME"

# Link the global Claude Code instructions. Deliberately NOT under config/home:
# process_directories rm -rf's each target dir before stowing, which would wipe
# ~/.claude (settings.json, projects/, bookmarks.tsv) on every run.
echo -e "\n🧠 Linking Claude Code instructions..."
mkdir -p "$HOME/.claude"
ln -sfn "$SCRIPT_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
echo "  ✅ ~/.claude/CLAUDE.md → config/claude/CLAUDE.md"

# Link each skill individually — ~/.claude/skills also holds skills installed
# by Claude itself (canvas, handoff), so the directory can't be a symlink.
mkdir -p "$HOME/.claude/skills"
for skill in "$SCRIPT_DIR"/claude/skills/*/; do
  [ -d "$skill" ] || continue
  name="$(basename "$skill")"
  ln -sfn "${skill%/}" "$HOME/.claude/skills/$name"
  echo "  ✅ ~/.claude/skills/$name → config/claude/skills/$name"
done

# Register the custom Claude Code status line (★ bookmark marker + dir ·
# branch · model — see scripts/claude-statusline.sh, linked by the stow above)
echo -e "\n📊 Registering Claude Code status line..."
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
[ -s "$CLAUDE_SETTINGS" ] || echo '{}' >"$CLAUDE_SETTINGS"
tmp="$(mktemp)"
jq '.statusLine = {type: "command", command: "~/scripts/claude-statusline.sh"}' \
  "$CLAUDE_SETTINGS" >"$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
echo "  ✅ statusLine → ~/scripts/claude-statusline.sh"

# Report each agent's state onto its tmux pane (see scripts/claude-hook-state.sh).
# Registration filters our own command out of each event before re-adding it, so
# reruns stay idempotent without disturbing hooks owned by other projects.
echo -e "\n🚦 Registering Claude agent state hooks..."
tmp="$(mktemp)"
jq --arg cmd "~/scripts/claude-hook-state.sh" '
  def entry($matcher):
    (if $matcher == null then {} else {matcher: $matcher} end)
    + {hooks: [{type: "command", command: $cmd, timeout: 5, async: true}]};
  def register($event; $matcher):
    .hooks[$event] = (
      ((.hooks[$event] // []) | map(select([.hooks[].command] | index($cmd) | not)))
      + [entry($matcher)]
    );
  register("PreToolUse"; "*")
  | register("PostToolUse"; "TaskCreate")
  | register("Notification"; null)
  | register("Stop"; null)
  | register("UserPromptSubmit"; null)
  | register("SessionStart"; null)
  | register("SessionEnd"; null)
  | register("SubagentStart"; null)
  | register("SubagentStop"; null)
' "$CLAUDE_SETTINGS" >"$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
echo "  ✅ PreToolUse/Notification/Stop/UserPromptSubmit/Session*/Subagent* → ~/scripts/claude-hook-state.sh"

# Start every session in bypassPermissions. skipDangerousModePermissionPrompt
# suppresses the confirmation dialog that mode otherwise shows on each startup.
echo -e "\n🔓 Setting default permission mode..."
tmp="$(mktemp)"
jq '.permissions.defaultMode = "bypassPermissions"
    | .skipDangerousModePermissionPrompt = true' \
  "$CLAUDE_SETTINGS" >"$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
echo "  ✅ permissions.defaultMode → bypassPermissions"

# Register the Linear MCP server. A single entry serves both workspaces: the
# Authorization header is expanded from LINEAR_API_KEY at connect time, and
# zsh/linear.zsh sets that per project directory. See that file for details.
echo -e "\n📋 Registering Linear MCP server..."
CLAUDE_JSON="$HOME/.claude.json"
[ -s "$CLAUDE_JSON" ] || echo '{}' >"$CLAUDE_JSON"
tmp="$(mktemp)"
jq '.mcpServers.linear = {
      type: "http",
      url: "https://mcp.linear.app/mcp",
      headers: {Authorization: "Bearer ${LINEAR_API_KEY}"}
    }' "$CLAUDE_JSON" >"$tmp" && mv "$tmp" "$CLAUDE_JSON"
echo "  ✅ mcpServers.linear → https://mcp.linear.app/mcp"

# The API keys themselves are per-machine and live in the system keyring, not
# in this repo. Warn rather than fail: the rest of the setup is still valid.
for slot in centinel optitask; do
  if secret-tool lookup linear "$slot" >/dev/null 2>&1; then
    echo "  ✅ keyring: linear/$slot"
  else
    echo "  ⚠️  keyring: linear/$slot missing — run:"
    echo "      secret-tool store --label=\"Linear ${slot}\" linear $slot"
  fi
done

# if grep -qi "arch" /etc/os-release; then
#   echo "🟢 Running on Arch Linux"
#   arch_install="$SCRIPT_DIR/install-arch.sh"
#   bash $arch_install
# fi
#
# echo -e "\n✅ Dotfiles setup completed successfully."
