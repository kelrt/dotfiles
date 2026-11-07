#!/bin/sh
# Warn before the battery dies, and save power near the end. Nothing else on this system
# sends a notification, and UPower puts the laptop to sleep without warning at its critical level.
# The loop checks that sway is alive so a re-login does not leave a second copy running.
BAT=${BAT:-/sys/class/power_supply/BAT0}
HOLD=${HOLD:-$(dirname "$0")/hold-power-saver.py}
held=

while swaymsg -q -t get_version 2>/dev/null; do
    c=$(cat "$BAT/capacity")
    s=$(cat "$BAT/status")
    if [ "$s" = Discharging ] && [ "$c" -le 10 ]; then
        notify-send -u critical -r 9910 "Battery $c%" "Plug in soon"
    fi
    # Power saver from 20% until plugged in. It only asks once per discharge, so picking another
    # profile on the bar sticks. Stopping the hold brings your own profile back.
    if [ "$s" != Discharging ]; then
        [ -n "$held" ] && kill "$held" 2>/dev/null
        held=
    elif [ -z "$held" ] && [ "$c" -le 20 ]; then
        setpriv --pdeathsig TERM "$HOLD" &
        held=$!
        notify-send -r 9911 "Battery $c%" "Power saver is on until you plug in"
    fi
    sleep "${INTERVAL:-120}"
done
