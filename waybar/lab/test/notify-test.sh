# Notifications with ~/.config/dunst/dunstrc. Run it through ./go notify.
# A private dunst on a private D-Bus, so your real one and your real popups aren't involved.
T=$OUT/run; rm -rf $T; mkdir -p $T; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
near() { if [ "$2" -ge "$3" ] && [ "$2" -le "$4" ]; then say "PASS  $1 ($2 ms)"; else say "FAIL  $1  ($2 ms, want $3 to $4)"; fi; }
eval "$(dbus-launch --sh-syntax --exit-with-session 2>/dev/null)"
dunst > dunst.log 2>&1 & D=$!   # no -conf, so it finds the file the way the real one does
sleep 1
shown() { dunstctl count displayed; }
ms() { date +%s%3N; }
gone_after() {  # gone_after <limit ms>: how long until the shown count drops
    s=$(ms); n=$(shown)
    while [ "$(shown)" = "$n" ]; do
        [ $(( $(ms) - s )) -gt "$1" ] && break
        sleep .05
    done
    echo $(( $(ms) - s ))
}

say "--- how long they stay"
notify-send -u low Quick "Track change, the Audacious kind"; t=$(gone_after 9000)
near "low goes after about 3 s" "$t" 2500 3700
notify-send Normal "A message"; t=$(gone_after 9000)
near "normal goes after about 5 s" "$t" 4500 5700
notify-send -u critical Battery "Plug in soon"; sleep 7
check "critical stays" "$(shown)" 1
dunstctl close; sleep .4
check "dunstctl close dismisses it" "$(shown)" 0
dunstctl history-pop; sleep .4
check "history brings one back" "$(shown)" 1
dunstctl close-all; sleep .3

say "--- how they look"
icon=/usr/share/icons/hicolor/48x48/apps/audacious.png; [ -f $icon ] || icon=audio-x-generic
notify-send -u low -a Audacious -i $icon "Song title here" "Artist name\nAlbum name"
notify-send -a blueman -i bluetooth-active "Connected" "HHKB-Hybrid_1"
notify-send -a Vesktop "Someone in a server" "A longer message so the text has to wrap across more than a single line of the box, the way a real chat message does."
notify-send -u critical -i battery-caution "Battery 9%" "Plug in soon"
notify-send -a Volume -h int:value:60 "A progress bar" "60%"
sleep .6
grim -g "1460,0 460x620" notify.png
check "five showing at once" "$(shown)" 5
dunstctl close-all

say "--- hover"
mkfifo ptr; python3 $H/vptr.py < ptr > vptr.log 2>&1 & VP=$!
exec 9>ptr
ptr() { echo "$*" >&9; }
ptr abs 400 600; sleep .4
notify-send Normal "Hover over me"; sleep .5
ptr abs 1740 40; sleep 7   # on the notification, past its 5 s
check "a normal one stays while the pointer is on it" "$(shown)" 1
ptr abs 400 600; t=$(gone_after 9000)
near "and goes once the pointer leaves" "$t" 200 5700
# Audacious marks its song notifications transient. Without the rule in dunstrc, dunst never pauses those.
ptr abs 400 600; sleep .4
notify-send -u low -a Audacious --hint=boolean:transient:true "Song title" "Artist"; sleep .5
ptr abs 1740 40; sleep 5   # on the notification, past its 3 s
check "an Audacious song (transient) stays while the pointer is on it" "$(shown)" 1
ptr abs 400 600; t=$(gone_after 9000)
near "and goes once the pointer leaves" "$t" 200 3700
kill $VP
kill $D $DBUS_SESSION_BUS_PID
swaymsg -q exit
