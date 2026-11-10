# Full behaviour test of the side bar. Run it through ./go, which sets $H and $OUT.
LAB=$OUT/lab   # copy with no click actions, built-in toggles replaced by stand-ins
T=$OUT/run; rm -rf $T; mkdir -p $T; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
focused() { swaymsg -t get_tree | python3 -c 'import json,sys
def w(n):
    if n.get("focused"): print(n.get("name"))
    for c in n.get("nodes",[])+n.get("floating_nodes",[]): w(c)
w(json.load(sys.stdin))'; }
in_scratch() { swaymsg -t get_tree | jq -r '.. | objects | select(.name? == "__i3_scratch") | .floating_nodes[].name' | grep -c "^$1\$"; }
cur_ws() { swaymsg -t get_workspaces | python3 -c 'import json,sys;print([w["name"] for w in json.load(sys.stdin) if w["focused"]][0])'; }
# Each window asks foot for mouse reports and writes them to a file, so a click reaching it is counted.
open_win() { swaymsg -q "exec foot -T $1 sh -c \"printf '\\\\033[?1000h\\\\033[?1006h'; stty raw -echo; exec cat > $T/$1.clicks\""; for i in $(seq 60); do swaymsg -t get_tree | grep -q "\"name\": \"$1\"" && break; sleep .1; done; sleep .2; }
clicks() { tr -cd M < $T/$1.clicks | wc -c; }
pixel() { grim -g "36,500 1x1" -t ppm - | tail -c 3 | od -An -tx1 | tr -d ' '; }
state() { [ "$(pixel)" = "$1" ] && echo closed || echo open; }
ptr() { echo "$*" >&9; }
kbd() { echo "$*" >&8; }
menus() { pgrep -x twofi | wc -l; }
rust_row() { grim rust.png; set -- $(python3 $H/rows.py rust.png); echo ${10}; }
walk() { y=$1; shift; for x in "$@"; do ptr abs $x $y; sleep .012; done; }
start_try() { python3 $H/launch.py $LAB/try > bar.out 2>&1 & TRY=$!; sleep 2.5; REVEAL=$(pgrep -g $TRY -f /reveal.py); WAYBAR=$(pgrep -g $TRY -x waybar); }
gone() { sleep 1; n=$(pgrep -g $TRY | wc -l); [ "$n" = 0 ] && echo gone || { pgrep -ag $TRY | cut -c1-60 >> $R; echo "$n left"; }; }
# Counts this test's scratchpad watcher processes. They run outside the bar's process group, so gone() can't see them.
watchers() { n=0; for p in $(pgrep -f 'scratchpad-others|swaymsg -t subscribe'); do grep -qz "^SWAYSOCK=$SWAYSOCK\$" /proc/$p/environ 2>/dev/null && n=$((n+1)); done; echo $n; }
. $H/private-bus.sh
CLOSE=1.3   # 0.6 s delay, the 0.3 s slide and a margin
export WOFI=twofi   # reveal.py watches for this name instead of a real menu

swaymsg -q workspace 3; open_win fs; swaymsg -q fullscreen enable
swaymsg -q workspace 2; open_win two
swaymsg -q workspace 1; open_win left; open_win right
# The three scratchpad apps, marked the way sway/includes/window_rules marks them.
for m in calc notes bw; do open_win $m; swaymsg -q "[title=\"^$m\$\"] mark $m, floating enable, move scratchpad"; done
mkfifo ptr; python3 $H/vptr.py < ptr > vptr.log 2>&1 & VP=$!
exec 9>ptr
# Wofi can only lose focus if there's a keyboard to hold focus for.
mkfifo key; python3 $H/vkbd.py < key > vkbd.log 2>&1 & KB=$!
exec 8>key
ptr abs 1400 600; sleep .3
start_try
sleep 1
say "started: reveal=$REVEAL waybar=$WAYBAR workspaces=$(swaymsg -t get_workspaces | grep -c '"name"')"

say "--- hidden"
CLOSED=$(pixel); grim 01-hidden.png
a=$(clicks right); ptr click left; sleep .3; check "click reaches a window" "$(( $(clicks right) - a ))" 1
a=$(clicks left); ptr abs 30 600; sleep .2; ptr click left; sleep .3
check "click at x=30 with the bar hidden reaches the window" "$(( $(clicks left) - a ))" 1

say "--- opening"
ptr abs 0 600; sleep .05; ptr abs 300 600; sleep .5
check "quick flick over the edge does not open" "$(state $CLOSED)" closed
ptr abs 0 500; sleep .5
check "resting on the edge opens" "$(state $CLOSED)" open
sleep 2.5; check "stays open with the pointer perfectly still" "$(state $CLOSED)" open
grim 03-open.png
set -- $(python3 $H/rows.py 03-open.png); say "rows: $*"
WS1=$2; WS2=$3; WS3=$4; IC1=$5; IC2=$6; IC3=$7; CLOCK=$8; RUST=${10}
TOG=$(python3 $H/rows.py 03-open.png | awk '{print $(NF-3)}')   # bottom rows: toggle, battery icon, percent, frame
say "drawer toggle y=$TOG"
say "(launcher, ws1=$WS1 ws2=$WS2 ws3=$WS3, scratchpad=$IC1 $IC2 $IC3, clock=$CLOCK, rust=$RUST)"
if [ "$WS3" -lt 120 ] || [ "$IC3" -gt 420 ] || [ "$CLOCK" -lt 500 ] || [ "$RUST" -le "$CLOCK" ]; then say "ABORT: unexpected layout, no clicks made"; kill $(pgrep -g $TRY); swaymsg exit; exit; fi

say "--- clicking inside the bar"
for pair in "$IC1 calc" "$IC2 notes" "$IC3 bw"; do
    set -- $pair
    ptr abs 36 $1; sleep .2; ptr click left; sleep .35; check "$2 button brings that window back" "$(focused)" $2
    ptr click left; sleep .35; check "$2 button hides it again" "$(in_scratch $2)" 1
done
ptr abs 36 $WS2; sleep .2; ptr click left; sleep .35; check "workspace 2 button" "$(cur_ws)" 2
ptr abs 36 $WS1; sleep .2; ptr click left; sleep .35; check "workspace 1 button" "$(cur_ws)" 1
check "bar stayed open through all those clicks" "$(state $CLOSED)" open

say "--- scratchpad icon for other windows"
ptr abs 36 420; sleep .5   # an empty part of the bar, so no tooltip covers the icon
grim -g "16,$((IC3+18)) 40x50" 02a.png
open_win other; swaymsg -q '[title="^other$"] move scratchpad'; sleep .6
grim -g "16,$((IC3+18)) 40x50" 02b.png
[ "$(md5sum < 02a.png)" != "$(md5sum < 02b.png)" ] && say "PASS  icon appears for a window with no button" || say "FAIL  icon did not appear"
grim 02c.png; set -- $(python3 $H/rows.py 02c.png); OTHER=$8
ptr abs 36 $OTHER; sleep .2; ptr click left; sleep .5
check "clicking it brings that window back" "$(focused)" other
grim -g "16,$((IC3+18)) 40x50" 02d.png
check "icon is gone again with only the three apps left" "$(md5sum < 02d.png)" "$(md5sum < 02a.png)"
swaymsg -q '[title="^other$"] kill'; sleep .4

say "--- the wait after leaving"
ptr abs 36 500; sleep .2
walk 500 60 90 130 200 400; sleep .1; ptr abs 1400 600
sleep .2; check "still open 0.3 s after leaving" "$(state $CLOSED)" open
sleep 1.5; check "closed 2 s after leaving" "$(state $CLOSED)" closed

say "--- windows work during the wait"
ptr abs 0 500; sleep .5
a=$(clicks left); walk 600 40 70 100 130 170 210; sleep .1; ptr click left; sleep .2
check "click 0.1 s after moving off the bar reaches the window" "$(( $(clicks left) - a ))" 1
check "that click leaves the bar waiting" "$(state $CLOSED)" open
check "pointer focus follows onto the window during the wait" "$(focused)" left
walk 600 400 800 1200 1400; sleep .1
check "focus follows on to the next window during the wait" "$(focused)" right
a=$(clicks right); ptr click left; sleep .2
check "a second click during the wait reaches the window" "$(( $(clicks right) - a ))" 1
sleep $CLOSE; check "closes on time after those clicks" "$(state $CLOSED)" closed
a=$(clicks right); ptr click left; sleep .3
check "first click after it closes reaches the window" "$(( $(clicks right) - a ))" 1
ptr abs 30 600; sleep .2; a=$(clicks left); ptr click left; sleep .3
check "x=30 clear after it closes" "$(( $(clicks left) - a ))" 1
ptr abs 1400 600; sleep .2

say "--- coming back"
ptr abs 0 500; sleep .5; walk 500 40 70 120 300; sleep .3; walk 500 200 120 70 36; sleep .3
check "back on the bar after 0.3 s" "$(state $CLOSED)" open
sleep 2; check "stays open 2 s after coming back" "$(state $CLOSED)" open
ptr abs 36 $WS2; sleep .2; ptr click left; sleep .35; check "a bar button works right after coming back" "$(cur_ws)" 2
ptr abs 36 $WS1; sleep .2; ptr click left; sleep .35
ptr abs 36 500; sleep .2
walk 500 70 100 70 36 70 100 70 36 70 100 70 36; sleep .3
check "wobbling across the bar's edge stays open" "$(state $CLOSED)" open
sleep 2; check "still open after the wobble" "$(state $CLOSED)" open
walk 500 70 200 1400; sleep $CLOSE; check "leaving after that closes on time" "$(state $CLOSED)" closed
ptr abs 1400 600; sleep .2

say "--- coming back, again and again"
ok=0
for i in 05 1 15 2 25 3 35 4; do
    ptr abs 0 500; sleep .5
    walk 500 40 70 120 300; sleep .$i; walk 500 200 120 70 36; sleep 1.8
    [ "$(state $CLOSED)" = open ] && ok=$((ok+1))
    walk 500 70 200 1400; sleep $CLOSE
done
check "left and came back 8 times with different gaps: stayed open each time" "$ok" 8
check "closed after the last one" "$(state $CLOSED)" closed
ptr abs 0 500; sleep .08; ptr abs 36 500; sleep .05; ptr abs 300 500; sleep 2.2
check "left within 0.15 s of opening: still closes" "$(state $CLOSED)" closed
ptr abs 1400 600; sleep .2

say "--- worst cases, one jump with no motion after it"
ptr abs 0 500; sleep .5; a=$(clicks left); ptr abs 200 600; sleep .2; ptr click left; sleep .25
say "note: jump, stop, click 0.2 s later reached the window: $(( $(clicks left) - a )) of 1, bar then: $(state $CLOSED)"
sleep $CLOSE; check "bar closed after that" "$(state $CLOSED)" closed
ptr abs 1400 600; sleep .2
ptr abs 0 500; sleep .6; check "opens again after that" "$(state $CLOSED)" open
ptr abs 1400 600; sleep $CLOSE; check "closes again" "$(state $CLOSED)" closed
ok=0
for i in 1 2 3 4 5 6 7 8 9 10; do
    ptr abs 0 500; sleep .45
    [ "$(state $CLOSED)" = open ] && ok=$((ok+1))
    printf 'abs 200 600\ndown left\nup left\n' >&9
    sleep $CLOSE; ptr abs 1400 600; sleep .1
done
check "press in the same instant as leaving, 10 times: hover still works each time" "$ok" 10
ptr abs 0 500; sleep .5; ptr abs 200 600; sleep .05; ptr down left; sleep .3
sleep 1.9; say "note: button held during the wait, bar: $(state $CLOSED)"
ptr up left; sleep .3; ptr abs 1400 600; sleep $CLOSE
check "closed after a held button" "$(state $CLOSED)" closed
ptr abs 0 500; sleep .6; check "opens after a held button" "$(state $CLOSED)" open
ptr abs 1400 600; sleep $CLOSE
ptr abs 0 500; ptr down left; sleep .4; ptr up left; sleep .5; check "button held on the edge still opens it" "$(state $CLOSED)" open
ptr abs 1400 600; sleep $CLOSE; check "and closes" "$(state $CLOSED)" closed
ptr abs 0 500; sleep .6; check "opens again after that" "$(state $CLOSED)" open
ptr abs 1400 600; sleep $CLOSE

say "--- fullscreen"
swaymsg -q workspace 3; ptr abs 900 600; sleep .3; CLOSEDFS=$(pixel)
check "on the fullscreen workspace" "$(focused)" fs
ptr abs 0 500; sleep .8; check "edge does nothing over a fullscreen window" "$(state $CLOSEDFS)" closed
kill -USR1 $REVEAL; sleep .5; check "keyboard toggle opens over fullscreen" "$(state $CLOSEDFS)" open
ptr abs 900 600; sleep $CLOSE; check "opened by keyboard, it stays when the pointer is away" "$(state $CLOSEDFS)" open
kill -USR1 $REVEAL; sleep .5; check "second toggle closes it" "$(state $CLOSEDFS)" closed
swaymsg -q workspace 1; ptr abs 1400 600; sleep .3
ptr abs 0 500; sleep .5; ptr abs 36 $WS3; sleep .2; ptr click left; sleep .4
check "opened by hover, switched to a fullscreen workspace" "$(cur_ws)" 3
check "bar is still showing there" "$(state $CLOSEDFS)" open
a=$(clicks fs); ptr abs 900 600; sleep .2; ptr abs 910 610; sleep .1; ptr click left; sleep .2
check "the fullscreen window gets clicks during the wait" "$(( $(clicks fs) - a ))" 1
sleep $CLOSE; check "not stuck open over fullscreen after leaving" "$(state $CLOSEDFS)" closed
ptr abs 0 500; sleep .2; ptr abs 900 600
kill -USR1 $REVEAL; sleep .3; ptr abs 910 600; sleep .1; kill -USR1 $REVEAL; sleep .5
check "keyboard toggles during fullscreen leave it closed" "$(state $CLOSEDFS)" closed
swaymsg -q workspace 1; ptr abs 1400 600; sleep .3

say "--- keyboard during the wait"
ptr abs 0 500; sleep .5; walk 500 40 100 300; sleep .2
kill -USR1 $REVEAL; sleep .6; check "toggle during the wait closes it now" "$(state $CLOSED)" closed
sleep 2; ptr abs 0 500; sleep .6; check "opens normally after that" "$(state $CLOSED)" open
ptr abs 1400 600; sleep $CLOSE

say "--- Super on its own"
ptr abs 1400 600; sleep .3
kbd super; sleep .6; check "a tap on Super opens the bar" "$(state $CLOSED)" open
ptr abs 1300 600; sleep $CLOSE; check "it stays open with the pointer away" "$(state $CLOSED)" open
kbd super; sleep .7; check "another tap closes it" "$(state $CLOSED)" closed
kbd mod4+d; sleep 1.4; check "Super+d opens the menu and leaves the bar alone" "$(menus) $(state $CLOSED)" "1 closed"
kbd esc; sleep .6
kbd superdown; sleep .15; ptr click left; sleep .15; kbd superup; sleep .7
SC=$(state $CLOSED); say "note: Super held through a mouse click, then let go: the bar is $SC"
[ "$SC" = open ] && { kbd super; sleep .7; }
check "closed again" "$(state $CLOSED)" closed

say "--- Super with the calculator, notes and Bitwarden"
# A tap that closes the bar hides those of the three on screen; the next tap that opens it
# brings them back. With one on screen and the bar closed, a tap hides it.
hidden3() { echo "$(in_scratch notes)$(in_scratch calc)$(in_scratch bw)"; }
kbd super; sleep .6; swaymsg -q '[con_mark="notes"] scratchpad show'; sleep .4
check "bar open and the notes showing" "$(state $CLOSED) $(hidden3)" "open 011"
kbd super; sleep .7; check "a tap hides both" "$(state $CLOSED) $(hidden3)" "closed 111"
kbd super; sleep .7; check "the next tap brings both back, notes focused" "$(state $CLOSED) $(hidden3) $(focused)" "open 011 notes"
swaymsg -q '[con_mark="calc"] scratchpad show'; sleep .4
kbd super; sleep .7; check "with calc focused too, a tap hides all of it" "$(state $CLOSED) $(hidden3)" "closed 111"
kbd super; sleep .7; check "both come back, calc focused as before" "$(state $CLOSED) $(hidden3) $(focused)" "open 001 calc"
kbd super; sleep .7; check "and away again" "$(state $CLOSED) $(hidden3)" "closed 111"
swaymsg -q '[con_mark="bw"] scratchpad show'; sleep .4
kbd super; sleep .7; check "bar closed, Bitwarden showing: a tap hides it, bar stays closed" "$(state $CLOSED) $(hidden3)" "closed 111"
kbd super; sleep .7; check "the next tap opens the bar with all three, Bitwarden focused" "$(state $CLOSED) $(hidden3) $(focused)" "open 000 bw"
kbd super; sleep .7; check "one more tap clears all of it" "$(state $CLOSED) $(hidden3)" "closed 111"
swaymsg -q workspace 3; ptr abs 900 600; sleep .3
kbd super; sleep .7; check "over fullscreen a tap opens the bar alone" "$(state $CLOSEDFS) $(hidden3) $(focused)" "open 111 fs"
kbd super; sleep .7; check "and the next closes it" "$(state $CLOSEDFS)" closed
swaymsg -q workspace 1; ptr abs 1400 600; sleep .3
kbd super; sleep .7; check "off fullscreen, a tap brings the three back" "$(state $CLOSED) $(hidden3)" "open 000"
kbd super; sleep .7; check "and a tap clears them" "$(state $CLOSED) $(hidden3)" "closed 111"

say "--- calendar"
# Counts the pixels of the today marker, a #2b2b2b background only the current month has.
# The whole width counts: the calendar can open over the bar, and on a Sunday or Monday today's
# square sits there. The bar has a pixel or so of that colour itself, so another month is "under 20".
today_px() { grim -g "0,0 964x1200" -t ppm cal.ppm; python3 -c '
d = open("cal.ppm", "rb").read()
px = d.split(b"\n", 3)[3]
print(sum(1 for i in range(0, len(px), 3) if px[i] == px[i + 1] == px[i + 2] == 0x2b))'; }
cal() { sleep .3; ptr abs $1 $CLOCK; sleep 1.1; }
ptr abs 0 500; sleep .5; ptr abs 34 $CLOCK; sleep 1.2; NOW=$(today_px); grim cal-now.png
check "this month: today is highlighted" "$([ "$NOW" -gt 40 ] && echo yes)" yes
ptr click left; cal 36; BACK=$(today_px); grim cal-back.png
check "left click: another month, with no today in it" "$([ "$BACK" -lt 20 ] && echo yes)" yes
ptr click right; cal 34; check "right click: back to this month" "$(today_px)" "$NOW"
ptr click right; cal 36; NEXT=$(today_px); grim cal-next.png
check "right click again: the next month" "$([ "$NEXT" -lt 20 ] && echo yes)" yes
[ "$(md5sum < cal-back.png)" != "$(md5sum < cal-next.png)" ] && say "PASS  left and right go different ways" || say "FAIL  left and right show the same month"
ptr click left; cal 34; check "left click: back to this month again" "$(today_px)" "$NOW"
ptr abs 1400 600; sleep $CLOSE

say "--- the slide"
# Finds where the bar's right edge is, with the closed screen's colour as the base.
edge() { grim -g "0,500 80x1" -t ppm - | python3 -c '
import sys
d = sys.stdin.buffer.read().split(b"\n", 3)[3]
base = bytes.fromhex(sys.argv[1])
print(max([x for x in range(80) if sum(abs(d[3 * x + k] - base[k]) for k in range(3)) > 12] + [0]))' $CLOSED; }
slide() { s=$(date +%s%3N); while :; do n=$(date +%s%3N); e=$(edge); echo "$((n-s)) $e"; [ $((n-s)) -gt 800 ] && break; done; }
ptr abs 0 500; sleep .8; kill -USR1 $REVEAL; slide > close.txt; sleep .3
say "closing, ms and edge: $(tr '\n' ',' < close.txt | cut -c1-230)"
GONE=$(awk '$2 <= 2 { print $1; exit }' close.txt); say "note: closing took about $GONE ms"   # the window border sits at x=0 to 1
check "closing takes about 0.3 s" "$([ "${GONE:-0}" -ge 220 ] && [ "${GONE:-0}" -le 460 ] && echo yes)" yes
ptr abs 900 600; sleep .3; ptr abs 0 500; slide > open.txt
say "opening, ms and edge: $(tr '\n' ',' < open.txt | cut -c1-200)"
ptr abs 1400 600; sleep $CLOSE

say "--- drawers (no volume changes, the sound button only leaves a mark)"
# Rows in the second picture with no row near them in the first.
new_rows() { python3 -c '
import subprocess, sys
r = lambda f: [int(x) for x in subprocess.run(["python3", sys.argv[3] + "/rows.py", f], capture_output=True, text=True).stdout.split()]
a = r(sys.argv[1])
for y in r(sys.argv[2]):
    if not any(abs(y - o) < 6 for o in a):
        print(y)' "$1" "$2" "$H"; }
rows_of() { python3 $H/rows.py "$1"; }
above() { rows_of "$1" | tr ' ' '\n' | awk -v l=$LEADER '$1 < l - 6 && $1 > l - 520' | wc -l; }
vwalk() { for y in $(seq $1 -12 $2); do ptr abs 36 $y; sleep .012; done; ptr abs 36 $2; }   # up the bar, staying on it
ptr abs 0 500; sleep .5
ptr abs 36 420; sleep .4; grim -g "8,640 72x460" 04a.png; grim closed.png; CLOSEDROW=$(rust_row)
ptr abs 36 $TOG; sleep .6; grim -g "8,640 72x460" 04b.png; grim 05-base.png
[ "$(md5sum < 04a.png)" != "$(md5sum < 04b.png)" ] && say "PASS  hovering the sliders opens the first drawer" || say "FAIL  hovering the sliders did not open the first drawer"
check "the first drawer alone leaves the clock where it was" "$(rust_row)" "$CLOSEDROW"
# Alert icons sit above the drawer and ride up with it, so the dots come after them.
ALERTS=$(rows_of closed.png | tr ' ' '\n' | awk -v r=$RUST -v t=$TOG '$1 > r + 20 && $1 < t - 6' | wc -l)
LEADER=$(rows_of 05-base.png | tr ' ' '\n' | awk -v r=$RUST '$1 > r + 20' | sed -n "$((ALERTS+1))p"); say "alerts=$ALERTS, dots y=$LEADER"
[ -n "$LEADER" ] && [ "$LEADER" -gt 620 ] && [ "$LEADER" -lt "$TOG" ] || { say "ABORT: no dots found, no clicks made"; kill $(pgrep -g $TRY); swaymsg exit; exit; }
vwalk $TOG $LEADER; sleep .4; grim 05b.png
check "it stays open on the way up to the dots" "$(rows_of 05b.png | tr ' ' '\n' | awk -v l=$LEADER '$1 > l - 6 && $1 < l + 6' | wc -l)" 1
ptr click left; sleep .7; grim 06a.png; sleep .7; grim 06b.png
check "second drawer: picture steady, no flicker" "$(md5sum < 06a.png)" "$(md5sum < 06b.png)"
MORE=$(new_rows 05b.png 06b.png | awk -v l=$LEADER '$1 < l'); say "rows the second drawer added: $(echo $MORE)"
[ "$(echo "$MORE" | wc -w)" -ge 8 ] && say "PASS  a click on the dots opens the second drawer" || say "FAIL  second drawer did not open"
check "the dots stay under the pointer" "$(rows_of 06b.png | tr ' ' '\n' | awk -v l=$LEADER '$1 > l - 6 && $1 < l + 6' | wc -l)" 1
say "note: Rust moves $((CLOSEDROW-$(rust_row))) px up while both drawers are open"
OPEN=$(above 06b.png)
# Counted up from the dots: power, Claude, maintenance, wallpaper, keep awake, charge, profile, volume.
ABOVE=$(rows_of 06b.png | tr ' ' '\n' | awk -v l=$LEADER '$1 < l - 6')
POWER=$(echo "$ABOVE" | tail -1); VOL=$(echo "$ABOVE" | tail -8 | head -1)
say "power button y=$POWER, volume y=$VOL"
ptr abs 36 $POWER; sleep .4; grim 06d.png
check "both stay open along the second drawer's buttons" "$(above 06d.png)" "$OPEN"
ptr abs 36 $VOL; sleep .3; ptr click left; sleep .5
check "left click on the volume opens sound settings" "$(ls sound-settings 2>/dev/null)" sound-settings
ptr click right; sleep .5
check "right click on the volume mutes" "$(ls sound-mute 2>/dev/null)" sound-mute
grim 06e.png; check "those clicks leave both drawers open" "$(above 06e.png)" "$OPEN"
ptr abs 36 $LEADER; sleep .3; ptr click left; sleep .6; grim 06f.png
check "a second click on the dots closes the second drawer" "$(rows_of 06f.png)" "$(rows_of 05b.png)"
ptr click left; sleep .6   # open it again, to see that it stays open
ptr abs 36 420; sleep .6; grim 06g.png
check "leaving the drawer closes it" "$(rows_of 06g.png)" "$(rows_of closed.png)"
check "the clock and Rust are back in the centre once it closes" "$(rust_row)" "$CLOSEDROW"
ptr abs 1400 600; sleep $CLOSE; check "the bar closes with the pointer away" "$(state $CLOSED)" closed
ptr abs 0 500; sleep .5; ptr abs 36 $TOG; sleep .6; grim 07a.png
check "next time, the second drawer is still open" "$(above 07a.png)" "$OPEN"
ptr abs 1400 600; sleep $CLOSE; check "bar closes again" "$(state $CLOSED)" closed

say "--- a menu opened from the bar stays until Esc or a click, and holds the bar"
# The second drawer is still open from above, so hovering the sliders shows the power button.
to_power() { ptr abs 36 $TOG; sleep .5; vwalk $TOG $POWER; sleep .25; ptr click left; sleep 1.2; }
ptr abs 0 500; sleep .5
to_power
check "power button opens the menu" "$(menus)" 1
walk $POWER 70 100 130 170 210 300; sleep .4
check "menu stays when the pointer leaves the bar" "$(menus)" 1
ptr abs 1400 600; sleep .4
check "menu stays when the pointer crosses onto another window" "$(menus)" 1
sleep $CLOSE; sleep 1; check "the menu holds the bar open" "$(state $CLOSED)" open
check "the menu is still there" "$(menus)" 1
kbd esc; sleep .3; check "Esc closes it" "$(menus)" 0
check "the bar still waits just after the menu closes" "$(state $CLOSED)" open
sleep $CLOSE; check "then the bar closes" "$(state $CLOSED)" closed

ptr abs 0 500; sleep .5; to_power
walk $POWER 70 100 170 300; ptr abs 1400 600; sleep 1.2
walk $POWER 300 170 100 70 36; sleep .3
kbd esc; sleep .4; check "Esc with the pointer back on the bar" "$(menus)" 0
sleep $CLOSE; check "the bar stays while the pointer is on it" "$(state $CLOSED)" open
walk $POWER 70 100 170 300; ptr abs 1400 600; sleep $CLOSE; check "and closes after it leaves" "$(state $CLOSED)" closed

ptr abs 0 500; sleep .5; to_power
walk $POWER 70 100 170 300; ptr abs 1400 600; sleep $CLOSE
a=$(clicks right); ptr click left; sleep .3
check "a click on a window closes it" "$(menus)" 0
say "note: that click also reached the window: $(( $(clicks right) - a )) of 1"
check "the bar still waits after that click" "$(state $CLOSED)" open
sleep $CLOSE; check "then the bar closes" "$(state $CLOSED)" closed
ptr abs 300 600; sleep .4; check "focus follows the pointer again" "$(focused)" left
ptr abs 1400 600; sleep .4
ptr abs 0 500; sleep .5; to_power
ptr click left; sleep .8; check "the same button closes it" "$(menus)" 0
ptr abs 36 $LEADER; sleep .3; ptr click left; sleep .6   # shut the second drawer
ptr abs 1400 600; sleep $CLOSE; check "bar closes after all that" "$(state $CLOSED)" closed
kbd mod4+d; sleep 1.4; check "\$mod+d opens a menu with the bar closed" "$(menus)" 1
check "that leaves the bar closed" "$(state $CLOSED)" closed
kbd esc; sleep .6

say "--- second screen"
swaymsg -q create_output; sleep 1.5
ptr size 3840 1200
ptr abs 1920 500; sleep .7; check "no edge on the inner side of the second screen" "$(state $CLOSED)" closed
ptr abs 0 500; sleep .7; check "main edge still works" "$(state $CLOSED)" open
ptr abs 2500 600; sleep $CLOSE; check "leaving onto the second screen closes it" "$(state $CLOSED)" closed
ptr abs 0 500; sleep .7; ptr abs 1400 600; sleep .3
swaymsg -q output HEADLESS-2 unplug; sleep .9
ptr size 1920 1200
sleep 1; check "screen unplugged during the wait: not stuck open" "$(state $CLOSED)" closed
ptr abs 1400 600; sleep .2; ptr abs 0 500; sleep .7; check "works after the screen is unplugged" "$(state $CLOSED)" open
ptr abs 1400 600; sleep $CLOSE; check "closes after the screen is unplugged" "$(state $CLOSED)" closed

say "--- process life"
[ "$(watchers)" -gt 0 ] && say "PASS  scratchpad watcher is running" || say "FAIL  no scratchpad watcher found"
a=$(awk '{print $14+$15}' /proc/$REVEAL/stat); w=$(awk '{print $14+$15}' /proc/$WAYBAR/stat); sleep 5
b=$(awk '{print $14+$15}' /proc/$REVEAL/stat); x=$(awk '{print $14+$15}' /proc/$WAYBAR/stat)
say "idle CPU over 5 s: reveal.py $((b-a)) ticks, waybar $((x-w)) ticks (100 ticks = 1 s)"
say "reveal.py memory: $(awk '/VmRSS/{print int($2/1024)" MB"}' /proc/$REVEAL/status)"
kill -9 $WAYBAR; check "waybar crash: everything stops" "$(gone)" gone
check "waybar crash: no scratchpad watcher left" "$(watchers)" 0
ptr abs 1400 600
start_try; kill -9 $REVEAL; check "helper crash: waybar stops too, no bar left hidden" "$(gone)" gone
start_try; kill -INT -$TRY; check "Ctrl+C: nothing left running" "$(gone)" gone
check "Ctrl+C: no scratchpad watcher left" "$(watchers)" 0
kill $VP $KB $ITEM $BUS 2>/dev/null; exec 9>&- 8>&-
say "END"
swaymsg exit
