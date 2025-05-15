#!/usr/bin/env bash
set -e

echo "🔧 Installing pacman hook and save script..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo mkdir -p /etc/pacman.d/hooks
sudo ln -sf "$SCRIPT_DIR/hooks/pacman/save-packages.hook" /etc/pacman.d/hooks/save-packages.hook

sudo install -Dm755 "$SCRIPT_DIR/hooks/pacman/save-packages.sh" /usr/local/bin/save-installed-packages

echo "✅ Pacman hook and save-packages script installed."
