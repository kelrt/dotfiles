#!/usr/bin/env bash

# Function for JSON escaping
json_escape() {
    local str="$1"
    str=${str//\\/\\\\}
    str=${str//\"/\\\"}
    str=$(echo "$str" | awk '{printf "%s\\n", $0}' | tr -d '\n')
    str=${str%\\n}
    echo "$str"
}

# Notification function
notify() {
    notify-send -a "Mullvad VPN" "$1" "$2" -t 3000
}

# Get Mullvad status
status=$(mullvad status 2>/dev/null)

if [ $? -ne 0 ]; then
    echo '{"text":" VPN Error","class":"error","tooltip":"Mullvad CLI not found"}'
    exit 0
fi

if [[ "$status" == *"Connected"* ]]; then
    # Extract connection details
    relay_host=$(echo "$status" | awk '/Relay:/ {print $2}')
    ip=$(echo "$status" | grep -oP 'IPv4: \K[0-9.]+')
    full_location=$(echo "$status" | grep -oP 'Visible location: \K[^\.]+' | xargs)
    protocol=$(mullvad relay get 2>/dev/null | awk '/Tunnel protocol:/ {print $3}')

    # Create tooltip
    tooltip_lines=(
        "Location: $full_location"
        "IP: $ip"
        "Relay: $relay_host"
        "Protocol: $protocol"
    )
    
    tooltip_content=$(printf "%s\n" "${tooltip_lines[@]}")
    tooltip_escaped=$(json_escape "$tooltip_content")

    # Get country for main display
    country_code=$(mullvad relay get 2>/dev/null | awk '/Location:/ {print $3}')
    declare -A country_map=(
        ["se"]="SE" ["us"]="US" ["de"]="DE"
        ["gb"]="UK" ["fr"]="FR" ["nl"]="NL"
        ["ca"]="CA" ["au"]="AU" ["sg"]="SG"
        ["jp"]="JP" ["ch"]="CH" ["at"]="AT"
    )
    country_name=${country_map["$country_code"]:-"$country_code"}

    printf '{"text":" %s","class":"connected","tooltip":"%s"}\n' \
           "$country_name" "$tooltip_escaped"
else
    tooltip_escaped=$(json_escape "$status")
    echo "{\"text\":\" \",\"class\":\"disconnected\",\"tooltip\":\"$tooltip_escaped\"}"
fi
