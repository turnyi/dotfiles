#!/usr/bin/env bash

set -e

# Install link of home files
rm -rf ~/scripts ~/zsh ~/.tmux.conf ~/.zprofile ~/.zshrc ~/.DS_Store ~/Notes

echo "$(pwd)"
stow -t ~ home

# Install config files
rm -rf ~/.config/ohmyposh
cd .config &&  mkdir ~/.config/ohmyposh && stow -t ~/.config/ohmyposh ohmyposh 
mkdir ~/.config/nvim && stow -t ~/.config/nvim nvim 

