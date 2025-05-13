#!/bin/bash

QUERY="$1"

if [ -z "$QUERY" ]; then
  echo "Usage: $0 search_term"
  exit 1
fi

# Convertir a minúsculas para comparación
LOWER_QUERY=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

# Buscar ventana cuyo title contenga el término (case-insensitive)
WINDOW_ID=$(hyprctl clients -j | jq -r --arg q "$LOWER_QUERY" '.[] | select(.title | ascii_downcase | contains($q)) | .address' | head -n 1)

if [ -n "$WINDOW_ID" ]; then
  hyprctl dispatch focuswindow address:$WINDOW_ID
  exit 0
fi

# Buscar .desktop file que contenga el nombre
DESKTOP_PATH=$(grep -ril --include="*.desktop" "Name=WhatsApp Web" ~/.local/share/applications /usr/share/applications)

if [ -z "$DESKTOP_PATH" ]; then
  echo "No matching .desktop file found for '$QUERY'"
  exit 1
fi

# Extraer el filename sin la ruta ni extensión
DESKTOP_NAME=$(basename "$DESKTOP_PATH" .desktop)

# Lanzar la app
gtk-launch "$DESKTOP_NAME"
