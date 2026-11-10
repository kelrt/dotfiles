#!/bin/sh
# Warn before the battery dies, and save power near the end. Nothing else on this system
# sends a notification, and UPower puts the laptop to sleep without warning at its critical level.
# Also warns once when a Bluetooth keyboard's batteries run low (the HHKB).
# The loop checks that sway is alive so a re-login does not leave a second copy running.
BAT=${BAT:-/sys/class/power_supply/BAT0}
HOLD=${HOLD:-$(dirname "$0")/hold-power-saver.py}
held=
kb_warned=   # keyboards already warned about, so a low battery gets one warning

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
    # Bluetooth keyboards report their batteries through UPower while connected. One warning at
    # 20% or less (UPower's own "low"); it can warn again only after new batteries (50% or more).
    for kb in $(upower -e 2>/dev/null | grep /keyboard_); do
        info=$(upower -i "$kb" 2>/dev/null)
        echo "$info" | grep -q 'present: *yes' || continue
        echo "$info" | grep -q 'should be ignored' && continue
        p=$(echo "$info" | awk '/percentage:/ { print int($2); exit }')
        name=$(echo "$info" | awk '/model:/ { sub(/^ *model: */, ""); print; exit }')
        [ -n "$p" ] || continue
        case " $kb_warned " in
        *" $kb "*)
            [ "$p" -ge 50 ] && kb_warned=$(echo " $kb_warned " | sed "s| $kb | |") ;;
        *)
            if [ "$p" -le 20 ]; then
                notify-send -u critical -r 9912 "${name:-Keyboard} battery $p%" "Change its batteries soon"
                kb_warned="$kb_warned $kb"
            fi ;;
        esac
    done
    sleep "${INTERVAL:-120}"
done
