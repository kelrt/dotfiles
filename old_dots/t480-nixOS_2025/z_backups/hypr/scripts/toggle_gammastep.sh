#!/usr/bin/env bash

# Inject the environment variables needed to connect to Wayland
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-1
export DISPLAY=:1

PGREP="/run/current-system/sw/bin/pgrep"
PKILL="/run/current-system/sw/bin/pkill"
GAMMASTEP="/run/current-system/sw/bin/gammastep"

if $PGREP -f "gammastep -O 3500" > /dev/null; then
    echo "Gammastep is running. Killing it..."
    $PKILL -f "gammastep -O 3500"
else
    echo "Gammastep is not running. Starting it..."
    $GAMMASTEP -O 3500 &
fi

