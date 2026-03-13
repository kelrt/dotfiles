#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
MONITORS=$(hyprctl monitors | awk '/Monitor/ {print $2}')

# Find wallpapers
mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort)

if [[ ${#WALLPAPERS[@]} -eq 0 ]]; then
    notify-send "Wallpaper Picker" "No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

OPTIONS=$(printf "%s\n" "${WALLPAPERS[@]##*/}")
SELECTED_NAME=$(echo "$OPTIONS" | rofi -dmenu -p "Select wallpaper" )

if [[ -n "$SELECTED_NAME" ]]; then
    for WALL in "${WALLPAPERS[@]}"; do
        if [[ "${WALL##*/}" == "$SELECTED_NAME" ]]; then
            SELECTED="$WALL"
            break
        fi
    done

    if [[ -n "$SELECTED" ]]; then
        # Ensure hyprpaper is running
        pgrep -x hyprpaper >/dev/null || hyprpaper &
        sleep 0.3

        # Set wallpaper on all monitors
        hyprctl hyprpaper unload all
        hyprctl hyprpaper preload "$SELECTED"
        for MON in $MONITORS; do
            hyprctl hyprpaper wallpaper "$MON,$SELECTED"
        done

        # Generate pywal colors
        wal -i "$SELECTED"

        # Reload Waybar
        pkill -SIGUSR2 waybar
    fi
else
    echo "No wallpaper selected."
fi

