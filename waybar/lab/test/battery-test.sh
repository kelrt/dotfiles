# The 20% power saver in sway/scripts/low-battery.sh, with a fake battery, a fake hold and fake
# notifications, then the real helper against a fake tuned-ppd. Run it through ./go battery.
T=$OUT/run; rm -rf $T; mkdir -p $T/bat $T/bin; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
level() { printf %s "$1" > bat/capacity; printf %s "$2" > bat/status; sleep .7; }
starts() { grep -c start hold.log; }
stops() { grep -c stop hold.log; }
warned() { grep -c 'Power saver' notify.log; }
touch hold.log notify.log
cat > hold <<X
#!/bin/sh
echo start >> $T/hold.log
trap 'echo stop >> $T/hold.log; kill \$!; exit' TERM
sleep 1000 & wait
X
cat > bin/notify-send <<X
#!/bin/sh
echo "\$*" >> $T/notify.log
X
cat > bin/swaymsg <<X
#!/bin/sh
[ ! -e $T/session-ended ]
X
# Stand-in for upower: one Bluetooth keyboard whose level is in $T/kb ("gone" when asleep), none
# while that file is missing, so the real HHKB never takes part.
cat > bin/upower <<X
#!/bin/sh
case \$1 in
-e) echo /org/freedesktop/UPower/devices/line_power_AC
    [ -e $T/kb ] && echo /org/freedesktop/UPower/devices/keyboard_dev_TEST ;;
-i) k=\$(cat $T/kb)
    if [ "\$k" = gone ]; then pr=no; pc="0% (should be ignored)"; else pr=yes; pc="\$k%"; fi
    printf '  model:                Test-Keyboard\n  keyboard\n    present:             %s\n    percentage:          %s\n' "\$pr" "\$pc" ;;
esac
X
chmod +x hold bin/notify-send bin/swaymsg bin/upower
run() { BAT=$T/bat HOLD=$T/hold INTERVAL=0.2 PATH=$T/bin:$PATH sh $HOME/.config/sway/scripts/low-battery.sh & P=$!; }

say "--- the logic"
level 50 Discharging; run; sleep .7; check "50% does nothing" "$(starts)" 0
level 21 Discharging; check "21% does nothing" "$(starts)" 0
level 20 Discharging; check "20% starts power saver" "$(starts)" 1
check "and says so" "$(warned)" 1
level 19 Discharging; level 15 Discharging; check "it only asks once" "$(starts)" 1
check "and only says so once" "$(warned)" 1
level 10 Discharging; check "the 10% warning still fires" "$(grep -c 'Plug in soon' notify.log | grep -cv '^0$')" 1
level 10 Charging; check "plugging in ends it" "$(stops)" 1
level 10 Discharging; check "unplugging while low starts it again" "$(starts)" 2
level 11 "Not charging"; check "a charge limit stop counts as plugged in" "$(stops)" 2
level 95 Full; level 95 Discharging; check "unplugged at 95% does nothing" "$(starts)" 2
level 20 Discharging; check "next time it starts again" "$(starts)" 3
kill -9 $P; sleep .5; check "script crash: the hold ends too" "$(stops)" 3
level 15 Discharging; run; sleep .7; check "started on low battery: on straight away" "$(starts)" 4
touch session-ended; sleep .8; check "session ends: the hold ends too" "$(stops)" 4

say "--- a Bluetooth keyboard's batteries"
kbw() { grep -c 'Change its batteries' notify.log; }
kb() { echo "$1" > kb; sleep .7; }
rm -f session-ended; level 50 Discharging; echo 100 > kb; run; sleep .7
check "keyboard at 100%: nothing" "$(kbw)" 0
kb 25; check "25%: nothing" "$(kbw)" 0
kb 20; check "20%: one warning" "$(kbw)" 1
check "critical, with its name and level" "$(grep -c '^-u critical -r 9912 Test-Keyboard battery 20% ' notify.log)" 1
kb 15; kb 10; check "it warns only once" "$(kbw)" 1
kb gone; kb 10; check "asleep and back, still low: no second warning" "$(kbw)" 1
kb 100; kb 20; check "new batteries, low again later: warns again" "$(kbw)" 2
kb 100; kb gone; check "a keyboard that isn't connected never warns" "$(kbw)" 2
check "the laptop's warnings are untouched" "$(grep -c 'Plug in soon' notify.log | grep -cv '^0$') $(starts)" "1 4"
kill $P

say "--- the real helper, on a private bus"
if command -v dbus-run-session >/dev/null; then
    dbus-run-session -- python3 $H/fake-ppd.py $HOME/.config/sway/scripts/hold-power-saver.py >> $R 2>> helper.err
else
    say "note: dbus-run-session not installed, skipped"
fi
say "END"
swaymsg exit
