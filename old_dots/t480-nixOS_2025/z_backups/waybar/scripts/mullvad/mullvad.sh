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

# Get Mullvad status
status=$(mullvad status 2>/dev/null)

if [ $? -ne 0 ]; then
    echo '{"text":"🔓","class":"error","tooltip":"Mullvad CLI not found"}'
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

    echo "{\"text\":\"󰌾 \",\"class\":\"connected\",\"tooltip\":\"$tooltip_escaped\"}"
else
    tooltip_escaped=$(json_escape "$status")
    echo "{\"text\":\" \",\"class\":\"disconnected\",\"tooltip\":\"$tooltip_escaped\"}"
fi

