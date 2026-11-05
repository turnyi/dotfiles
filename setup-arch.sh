#!/usr/bin/env bash
set -e

echo "🏗️ Installing Arch Linux packages..."

SYNC_ONLY=false
if [[ "$1" == "--sync" ]]; then
  SYNC_ONLY=true
  echo "🔁 Sync-only mode enabled — skipping post-install script."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACMAN_FILE="$SCRIPT_DIR/packages/pacman-packages.txt"
YAY_FILE="$SCRIPT_DIR/packages/yay-packages.txt"

# if [[ -f "$PACMAN_FILE" ]]; then
#   echo "📦 Installing pacman packages from $PACMAN_FILE..."
#   sudo pacman -Syu --needed --noconfirm $(<"$PACMAN_FILE")
# else
#   echo "⚠️  No pacman package list found at $PACMAN_FILE"
# fi
#
if ! command -v yay &>/dev/null; then
  echo "🔧 yay not found — installing yay..."
  sudo pacman -S --needed --noconfirm git base-devel
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
  rm -rf /tmp/yay
fi

if [[ -f "$YAY_FILE" ]]; then
  echo "📦 Installing yay (AUR) packages from $YAY_FILE..."
  yay -S --needed --noconfirm $(<"$YAY_FILE")
else
  echo "⚠️  No yay package list found at $YAY_FILE"
fi

HYPRVIM_DIR="$HOME/.local/share/hyprland/lua/plugins/hyprvim"
if [[ ! -d "$HYPRVIM_DIR" ]]; then
  echo "⌨️  Installing HyprVim..."
  git clone https://github.com/uhs-robert/hyprvim "$HYPRVIM_DIR"
fi

if [[ "$SYNC_ONLY" = false ]]; then
  echo "✅ Arch setup complete."
  exit 0
fi

POST_INSTALL="$SCRIPT_DIR/config/install.sh"
if [[ -f "$POST_INSTALL" ]]; then
  echo "🚀 Running $POST_INSTALL..."
  bash "$POST_INSTALL"
else
  echo "⚠️  No post-install script found at $POST_INSTALL"
fi
echo "✅ Arch setup complete."
