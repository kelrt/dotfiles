#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/wallpapers"
SELECTED=$(ls -1 "$WALL_DIR" | ~/.config/wofi/menu --show dmenu --prompt "Select Wallpaper:" -i)

if [ -n "$SELECTED" ]; then
    swaymsg "output * bg '$WALL_DIR/$SELECTED' fill"
    # sway/config loads this link at login, so the next login shows this picture too
    ln -sfn "$WALL_DIR/$SELECTED" "$HOME/.config/sway/wallpaper"
    
    # Generate colors automatically based on the most saturated option
    matugen image "$WALL_DIR/$SELECTED" --prefer saturation
fi