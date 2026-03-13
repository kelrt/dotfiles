#!/usr/bin/env bash

# Scan and list available Wi-Fi networks
choices=$(nmcli -f SSID,SECURITY,SIGNAL dev wifi list | awk 'NR>1 {print $0}' | sed '/^--/d' | uniq | sort -k3 -nr)

# Use Rofi to select a network
network=$(echo "$choices" | rofi -dmenu -p "Select Wi-Fi" | awk '{print $1}')

# Exit if nothing selected
[ -z "$network" ] && exit

# Check if network requires a password
secured=$(nmcli -f SSID,SECURITY dev wifi list | grep "$network" | grep -v -- " --" | wc -l)

if [ "$secured" -gt 0 ]; then
  # Ask for password via Rofi
  password=$(rofi -dmenu -p "Enter password for $network" -password)
  nmcli dev wifi connect "$network" password "$password"
else
  nmcli dev wifi connect "$network"
fi

