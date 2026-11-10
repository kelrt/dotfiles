# The Rust crab in both states. Run it through ./go crab.
# The bar under test reads a stand-in status, so your real Rust progress isn't involved.
LAB=$OUT/lab
T=$OUT/run; rm -rf $T; mkdir -p $T; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
. $H/private-bus.sh
printf '#!/bin/sh\ncat %s/status\n' "$T" > stub; chmod +x stub
python3 - "$OUT/config.jsonc" "$T/stub" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
c["custom/rust"]["exec"] = sys.argv[2]
json.dump(c, open(sys.argv[1], "w"))
PY
set_status() { printf '{"text":"R","class":"%s","tooltip":"%s"}\n' "$1" "$1" > status; }
set_status pending
python3 $H/launch.py $LAB/try side > bar.out 2>&1 & TRY=$!
sleep 2.5
REVEAL=$(pgrep -g $TRY -f /reveal.py); WAYBAR=$(pgrep -g $TRY -x waybar | head -1)
kill -USR1 $REVEAL; sleep .6
# Counts the crab's colours in the bar's middle, and prints where the crab row is.
count() { grim -g "8,400 56x400" -t ppm "$1.ppm"; python3 - "$1.ppm" <<'PY'
import sys
d = open(sys.argv[1], "rb").read()
p = d.split(b"\n", 3); w, h = map(int, p[1].split()); px = p[3]
red = black = orange = 0
for i in range(0, len(px), 3):
    r, g, b = px[i], px[i + 1], px[i + 2]
    if abs(r - 0xe0) < 12 and abs(g - 0x1b) < 12 and abs(b - 0x24) < 12: red += 1
    elif r < 40 and g < 12 and b < 12: black += 1
    elif abs(r - 0xb8) < 16 and abs(g - 0x76) < 16 and abs(b - 0x5e) < 16: orange += 1
print(red, black, orange)
PY
}
set -- $(count pending); say "pending: red $1 black $2 orange $3"
check "pending is a red bubble" "$([ "$1" -gt 300 ] && echo yes)" yes
check "with a black crab on it" "$([ "$2" -gt 80 ] && echo yes)" yes
grim -g "8,400 56x400" pending.png
set_status done; kill -RTMIN+8 $WAYBAR; sleep .8
set -- $(count done); say "done: red $1 black $2 orange $3"
check "done has no red left" "$1" 0
check "and a faint orange crab" "$([ "$3" -gt 60 ] && echo yes)" yes
grim -g "8,400 56x400" done.png
set_status pending; kill -RTMIN+8 $WAYBAR; sleep .8
set -- $(count again); check "the next day it goes red again" "$([ "$1" -gt 300 ] && echo yes)" yes
kill $TRY 2>/dev/null; pkill -g $TRY 2>/dev/null
kill $ITEM $BUS 2>/dev/null
swaymsg -q exit
