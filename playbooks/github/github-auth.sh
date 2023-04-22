#!/bin/bash

source .env

cd ~/Documents


git config --global user.name  $GITHUB_USER
git config --global user.email $GITHUB_EMAIL
echo "https://github.com/$GITHUB_USER/$REPOSITORY_NAME.git"

# Set Git credentials helper to store
git config --global credential.helper store

# Set Git credentials to use token instead of password
echo "https://$username:$token@github.com" | git credential-store store

# Set Git credential caching to 1 hour (3600 seconds)
git config --global credential.helper"
