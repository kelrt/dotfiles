#!/usr/bin/env bash

LOCKFILE="/tmp/coffee.lock"

toggle() {
  if [ -f "$LOCKFILE" ]; then
    rm "$LOCKFILE"
  else
    touch "$LOCKFILE"
  fi
}

status() {
  if [ -f "$LOCKFILE" ]; then
    echo '{ "text": "☕", "tooltip": "Coffee mode enabled", "class": "enabled" }'
  else
    echo '{ "text": "caf ", "tooltip": "Coffee mode disabled", "class": "disabled" }'
  fi
}


case "$1" in
  toggle) toggle ;;
  *) status ;;
esac

