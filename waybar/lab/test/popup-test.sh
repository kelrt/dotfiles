# Popup as a whole-session process. Fake pactl and wpctl, so real audio is never touched,
# and a scratch colours file, so the real one isn't either.
# Run it through ./go popup, which sets $OUT.
T=$OUT/run; rm -rf $T; mkdir -p $T/stub; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
differs() { if [ "$2" != "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (picture did not change)"; fi; }

cat > stub/wpctl <<EOF
#!/bin/sh
[ -f $T/audio-up ] || exit 1
cat $T/volume
EOF
cat > stub/pactl <<EOF
#!/bin/bash
[ -f $T/audio-up ] || { echo "Connection failure: Connection refused" >&2; exit 1; }
echo \$\$ > $T/pactl.pid
exec tail -n0 -f $T/events
EOF
chmod +x stub/*
touch events
echo "Volume: 0.50" > volume
cp ~/.config/waybar/lab/osd/osd.py osd.py
cp ~/.config/waybar/colors.css colors.css
sed -i "s#^COLORS = .*#COLORS = \"$T/colors.css\"#" osd.py

shot() { grim -g "760,550 400x100" -t ppm - | md5sum; }
event() { echo "Event 'change' on sink #53" >> events; }
setvol() { echo "Volume: $1" > volume; event; }
hide_wait() { sleep 1.7; }
sleep 2.5   # let the wallpaper finish loading first
BASE=$(shot)

say "--- login with audio not up yet"
PATH=$T/stub:$PATH python3 osd.py > osd.out 2>&1 & OSD=$!
sleep 3
kill -0 $OSD 2>/dev/null && check "still running with no audio" yes yes || check "still running with no audio" no yes
touch audio-up; sleep 2.6
check "fake pactl was started again" "$([ -s pactl.pid ] && echo yes)" yes
event; sleep .4
check "audio coming up shows no popup" "$(shot)" "$BASE"

say "--- normal use"
setvol 0.55; sleep .35; A=$(shot)
differs "a volume change shows the popup" "$BASE" "$A"
hide_wait; check "popup hides" "$(shot)" "$BASE"
event; sleep .4; check "an event with the same volume shows nothing" "$(shot)" "$BASE"

say "--- audio server restarts"
kill $(cat pactl.pid); sleep 2.6
setvol 0.60; sleep .35; differs "popup works after a restart" "$BASE" "$(shot)"
hide_wait
rm audio-up; kill $(cat pactl.pid); sleep 6.5; touch audio-up; sleep 2.2
setvol 0.65; sleep .35; differs "popup works after audio was gone for 6 s" "$BASE" "$(shot)"
hide_wait; check "hidden again" "$(shot)" "$BASE"

say "--- new wallpaper"
setvol 0.55; sleep .35; OLD=$(shot); grim -g "760,550 400x100" old.png; hide_wait
sed -i -E 's/#[0-9a-fA-F]{6}/#00cc66/g' colors.css
setvol 0.60; sleep .4; hide_wait
setvol 0.55; sleep .35; NEW=$(shot); grim -g "760,550 400x100" new.png
differs "new colours show without a restart" "$OLD" "$NEW"
hide_wait
mv colors.css colors.gone; setvol 0.60; sleep .35; differs "colours file missing: still shows" "$BASE" "$(shot)"
hide_wait; mv colors.gone colors.css

say "--- process life"
a=$(awk '{print $14+$15}' /proc/$OSD/stat); sleep 5; b=$(awk '{print $14+$15}' /proc/$OSD/stat)
say "idle CPU over 5 s: $((b-a)) ticks (100 ticks = 1 s); memory $(awk '/VmRSS/{print int($2/1024)" MB"}' /proc/$OSD/status)"
P=$(cat pactl.pid)
kill -0 $P 2>/dev/null && say "pactl alive before the crash: yes"
kill -9 $OSD; sleep .6
kill -0 $P 2>/dev/null && check "popup crash leaves no pactl behind" left gone || check "popup crash leaves no pactl behind" gone gone
PATH=$T/stub:$PATH python3 osd.py > osd2.out 2>&1 & OSD=$!
sleep 1.5; P=$(cat pactl.pid); kill $OSD; sleep .6
kill -0 $P 2>/dev/null && check "normal stop leaves no pactl behind" left gone || check "normal stop leaves no pactl behind" gone gone
cat osd.out osd2.out | grep -v '^$' | cut -c1-120 | sort | uniq -c | head -8 >> $R
say "END"
swaymsg exit
