#!/usr/bin/env bash
set -e

# Where to store the hook
HOOK_PATH="/etc/pacman.d/hooks/save-packages.hook"
SCRIPT_PATH="/usr/local/bin/save-installed-packages"

echo "🔧 Setting up pacman hook to auto-save package lists..."

# Create the update script
sudo tee "$SCRIPT_PATH" >/dev/null <<'EOF'
#!/usr/bin/env bash

# Save package lists to user's dotfiles
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
DOTFILES="$USER_HOME/Projects/dotfiles/packages"

mkdir -p "$DOTFILES"

# Save explicitly installed packages (non-AUR)
comm -23 <(pacman -Qq | sort) <(pacman -Qqm | sort) > "$DOTFILES/pacman-packages.txt"

# Save AUR packages
pacman -Qmq > "$DOTFILES/yay-packages.txt"
EOF

# Make the script executable
sudo chmod +x "$SCRIPT_PATH"

# Create the pacman hook
sudo tee "$HOOK_PATH" >/dev/null <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Saving installed packages to dotfiles...
When = PostTransaction
Exec = $SCRIPT_PATH
EOF

echo "✅ Hook installed at $HOOK_PATH"
