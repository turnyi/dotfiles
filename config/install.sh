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

# if grep -qi "arch" /etc/os-release; then
#   echo "🟢 Running on Arch Linux"
#   arch_install="$SCRIPT_DIR/install-arch.sh"
#   bash $arch_install
# fi
#
# echo -e "\n✅ Dotfiles setup completed successfully."
