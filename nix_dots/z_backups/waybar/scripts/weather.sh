#!/usr/bin/env bash
# Default location (used if IP lookup fails)
DEFAULT_CITY="Chattanooga"

# Get location via IP
CITY=$(curl -sf https://ipinfo.io/city)

# Fallback if city detection fails
if [[ -z "$CITY" ]]; then
    CITY="$DEFAULT_CITY"
fi

# Remove whitespace (some cities have trailing newlines)
CITY=$(echo "$CITY" | tr -d '\n' | sed 's/ /%20/g')

# Get concise one-liner for Waybar display (without city name)
# Added 'u' parameter to use Fahrenheit
SUMMARY=$(curl -sf "wttr.in/${CITY}?format=%C+%c+%t&u")

if [[ -z "$SUMMARY" ]]; then
    SUMMARY="Weather unavailable"
fi

# If clicked, show detailed popup
if [[ "$1" == "--popup" ]]; then
    # Added 'u' parameter to use Fahrenheit
    DETAILS=$(curl -sf "wttr.in/${CITY}?0&n&T&u")
    if [[ -z "$DETAILS" ]]; then
        DETAILS="Unable to fetch weather."
    fi

    echo "$DETAILS" | rofi -dmenu \
        -theme-str 'window { location: north east; anchor: northeast; x-offset: -100px; y-offset: 35px; width: 350px; height: 250px; } listview { lines: 20; }' \
        -p "Weather in ${CITY//%20/ }"
else
    echo "{\"text\": \"$SUMMARY\", \"tooltip\": \"Click to view full weather for ${CITY//%20/ }\"}"
fi
