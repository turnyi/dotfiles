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
