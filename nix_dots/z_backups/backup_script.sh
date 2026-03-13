#!/usr/bin/env bash

# List of folders to back up
folders_to_copy=(
    "/home/relz/.config/hypr"
    "/home/relz/.config/waybar"
    "/home/relz/.config/rofi"
    "/home/relz/.config/kitty"
)

# Backup destination
backup_destination="/home/relz/.dotfiles/z_backups"

# Ensure backup destination exists
mkdir -p "$backup_destination"

# Loop over each folder and copy it to the destination
for folder in "${folders_to_copy[@]}"; do
    folder_name=$(basename "$folder")

    # If the destination folder exists, remove it
    if [ -d "$backup_destination/$folder_name" ]; then
        echo "Removing existing folder: $backup_destination/$folder_name"
        rm -rf "$backup_destination/$folder_name"
    fi

    # Copy the folder
    echo "Copying $folder to $backup_destination/"
    cp -r "$folder" "$backup_destination/"
done

echo "Backup complete."

