#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/wallpapers"
SELECTED=$(ls -1 "$WALL_DIR" | wofi --show dmenu --prompt "Select Wallpaper:" -i)

if [ -n "$SELECTED" ]; then
    swaymsg "output * bg '$WALL_DIR/$SELECTED' fill"
    
    # Generate colors automatically based on the most saturated option
    matugen image "$WALL_DIR/$SELECTED" --prefer saturation
fi