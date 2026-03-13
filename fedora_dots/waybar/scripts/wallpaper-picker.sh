#!/usr/bin/env bash

# --- Configuration ---
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
# ---------------------

# Verify directory exists
if [[ ! -d "$WALLPAPER_DIR" ]]; then
    notify-send "Wallpaper Picker" "Directory not found: $WALLPAPER_DIR"
    exit 1
fi

# Find wallpapers (jpg, jpeg, png)
mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort)

if [[ ${#WALLPAPERS[@]} -eq 0 ]]; then
    notify-send "Wallpaper Picker" "No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

# Generate list of filenames for Rofi
OPTIONS=$(printf "%s\n" "${WALLPAPERS[@]##*/}")

# Open Rofi to select
SELECTED_NAME=$(echo "$OPTIONS" | rofi -dmenu -p "Select wallpaper" -i)

if [[ -n "$SELECTED_NAME" ]]; then
    # Find the full path of the selected file
    for WALL in "${WALLPAPERS[@]}"; do
        if [[ "${WALL##*/}" == "$SELECTED_NAME" ]]; then
            SELECTED="$WALL"
            break
        fi
    done

    if [[ -n "$SELECTED" ]]; then
        # --- Sway Specific Command ---
        # "output *" applies to all monitors. 
        # "fill" scales the image to cover the screen.
        swaymsg output "*" bg "$SELECTED" fill

        # Generate pywal colors
        wal -i "$SELECTED"

        # Reload Waybar to pick up new colors
        pkill -SIGUSR2 waybar
        
        # Optional: Send notification
        notify-send "Wallpaper" "Set to $SELECTED_NAME"
    fi
else
    echo "No wallpaper selected."
fi
