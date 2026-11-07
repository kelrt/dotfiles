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
chmod +x hold bin/notify-send bin/swaymsg
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

say "--- the real helper, on a private bus"
if command -v dbus-run-session >/dev/null; then
    dbus-run-session -- python3 $H/fake-ppd.py $HOME/.config/sway/scripts/hold-power-saver.py >> $R 2>> helper.err
else
    say "note: dbus-run-session not installed, skipped"
fi
say "END"
swaymsg exit
