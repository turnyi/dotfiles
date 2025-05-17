#!/usr/bin/env bash
set -e

# PATTERN="$1"
#
# echo "🔧 Installing system-wide and user-specific configurations..."
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_FILE="$SCRIPT_DIR/utils.sh"

echo $UTILS_FILE
source "$UTILS_FILE"
#
ETC_SOURCE="$SCRIPT_DIR/etc"
LOCAL_SHARE_SOURCE="$SCRIPT_DIR/.local/share"

echo "📁 Stowing system configurations..."
process_path "$ETC_SOURCE/keyd" "/etc/keyd" "keyd"
process_path "$ETC_SOURCE/pacman.d/hooks" "/etc/pacman.d/hooks" "pacman hooks"

# Process user-specific launchers
echo "🎯 Stowing application launchers to ~/.local/share/applications..."
mkdir -p "$HOME/.local/share/applications"
process_path "$LOCAL_SHARE_SOURCE/applications" "$HOME/.local/share/applications" "user applications"

# Enable keyd if present
if command -v keyd &>/dev/null; then
  echo "🔑 Enabling keyd service..."
  sudo systemctl enable --now keyd
fi

echo "✅ System-wide and user dotfiles installed successfully."
