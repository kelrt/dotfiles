#!/usr/bin/env bash
# Select a random file from the wallpapers directory and set it
WALLPAPER=$(find "$HOME/Pictures/wallpapers" -maxdepth 1 -type f | shuf -n 1)
swaymsg "output * bg '$WALLPAPER' fill"

# Generate colors automatically based on the most saturated option
matugen image "$WALLPAPER" --prefer saturation