#!/usr/bin/env bash

chosen=$(echo -e "Shutdown\nRestart\nHibernate\nSleep" | rofi -dmenu -i -p "Power Menu")

case "$chosen" in
    Shutdown)
        systemctl poweroff
        ;;
    Restart)
        systemctl reboot
        ;;
    Hibernate)
        systemctl hibernate
        ;;
    Sleep)
        systemctl suspend
        ;;
    *)
        exit 1
        ;;
esac

