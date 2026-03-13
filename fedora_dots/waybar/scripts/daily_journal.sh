#!/bin/bash

# Define the directory and today's date
JOURNAL_DIR="/home/relz/daily_journal"
TODAY=$(date +%Y-%m-%d)
FILE_PATH="$JOURNAL_DIR/$TODAY.md"

# Ensure the directory exists
mkdir -p "$JOURNAL_DIR"

# Launch Foot, tell it to run Fish, and open Neovim with today's file
foot fish -c "nvim '$FILE_PATH'"
