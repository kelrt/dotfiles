#!/usr/bin/env bash

# might need to add pkgs.networkmanagerapplet?
nm-applet --indicator &

#THE BARR
waybar &

# chinese keeb input
fcitx5 &

#dunst
dunst
