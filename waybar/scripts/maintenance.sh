#!/bin/bash

# Run DNF, then drop to interactive Zsh shell
foot -e zsh -c "sudo dnf upgrade --refresh; exec zsh" &

# Run Flatpak, then drop to interactive Zsh shell
foot -e zsh -c "flatpak update; exec zsh" &

# Run the backup script, then drop to interactive Zsh shell
foot -e zsh -c "~/.config/waybar/scripts/backup-dots-and-commit.sh; exec zsh" &
