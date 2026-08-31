#!/usr/bin/env bash

# Display available countries
echo -e "\n\033[1mAvailable Mullvad Countries:\033[0m"
echo "us - United States     de - Germany"
echo "fr - France            se - Sweden"
echo "nl - Netherlands       gb - United Kingdom"
echo "ca - Canada            au - Australia"
echo "sg - Singapore         jp - Japan"
echo "ch - Switzerland       at - Austria"
echo ""

# Prompt for country code
read -p "Enter country code: " country

# Change location and notify
if mullvad relay set location "$country"; then
    notify-send -a "Mullvad VPN" "Location Changed" "Connected to $country" -t 3000
else
    notify-send -a "Mullvad VPN" "Error" "Failed to change location" -t 3000
fi

# Keep window open
read -p "Press Enter to close this window"
