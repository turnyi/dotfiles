#!/usr/bin/env bash
set -e

echo "🔧 Installing pacman hook and save script..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo mkdir -p /etc/pacman.d/hooks
sudo ln -sf "$SCRIPT_DIR/hooks/pacman/save-packages.hook" /etc/pacman.d/hooks/save-packages.hook

sudo install -Dm755 "$SCRIPT_DIR/hooks/pacman/save-packages.sh" /usr/local/bin/save-packages.sh

echo "✅ Pacman hook and save-packages script installed."

ETC_DIR="$SCRIPT_DIR/etc"

if [[ -d "$ETC_DIR/keyd" ]]; then
  echo "🔑 Stowing keyd config into /etc/keyd..."
  sudo mkdir -p /etc/keyd
  cd "$ETC_DIR"
  sudo stow --target=/etc/keyd keyd
  sudo systemctl enable --now keyd
else
  echo "⚠️  No keyd directory found at $ETC_DIR/keyd"
fi
