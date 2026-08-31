#!/usr/bin/env bash

# Set the path to your Wallhaven stash
WALL_DIR="$HOME/Pictures/wallpapers"

# List files, pass them to wofi in dmenu mode, and save the choice
# The -i flag makes your typing case-insensitive
SELECTED=$(ls -1 "$WALL_DIR" | wofi --show dmenu --prompt "Select Wallpaper:" -i)

# If you actually picked something (and didn't just hit Esc), set it!
if [ -n "$SELECTED" ]; then
    swaymsg "output * bg '$WALL_DIR/$SELECTED' fill"
fi
