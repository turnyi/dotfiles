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

# Install ccstatusline globally for Claude Code status line
echo -e "\n📊 Installing ccstatusline..."
if ! command -v ccstatusline &>/dev/null; then
  npm install -g ccstatusline@latest
  echo "  ✅ ccstatusline installed"
else
  echo "  ✅ ccstatusline already installed ($(ccstatusline --version 2>/dev/null || echo 'version unknown'))"
fi

# if grep -qi "arch" /etc/os-release; then
#   echo "🟢 Running on Arch Linux"
#   arch_install="$SCRIPT_DIR/install-arch.sh"
#   bash $arch_install
# fi
#
# echo -e "\n✅ Dotfiles setup completed successfully."
