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
start_try() { python3 $H/launch.py $LAB/try > bar.out 2>&1 & TRY=$!; sleep 2.5; REVEAL=$(pgrep -g $TRY -f side/reveal.py); WAYBAR=$(pgrep -g $TRY -x waybar); }
gone() { sleep 1; n=$(pgrep -g $TRY | wc -l); [ "$n" = 0 ] && echo gone || { pgrep -ag $TRY | cut -c1-60 >> $R; echo "$n left"; }; }
# Counts this test's scratchpad watcher processes. They run outside the bar's process group, so gone() can't see them.
watchers() { n=0; for p in $(pgrep -f 'scratchpad-others|swaymsg -t subscribe'); do grep -qz "^SWAYSOCK=$SWAYSOCK\$" /proc/$p/environ 2>/dev/null && n=$((n+1)); done; echo $n; }
CLOSE=1.3   # 0.844 s delay, the 0.16 s slide and a margin

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
sleep .4; check "still open 0.5 s after leaving" "$(state $CLOSED)" open
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
ptr abs 0 500; sleep .5; walk 500 40 70 120 300; sleep .5; walk 500 200 120 70 36; sleep .3
check "back on the bar after 0.5 s" "$(state $CLOSED)" open
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
for i in 05 1 15 2 3 4 5 6; do
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
kill -USR1 $REVEAL; sleep .4; check "toggle during the wait closes it now" "$(state $CLOSED)" closed
sleep 2; ptr abs 0 500; sleep .6; check "opens normally after that" "$(state $CLOSED)" open
ptr abs 1400 600; sleep $CLOSE

say "--- hover sliders (hover only, no clicks or scrolling)"
VOL=$((TOG-318)); LIGHT=$((TOG-270))
ptr abs 0 500; sleep .5
ptr abs 36 $TOG; sleep .3; grim -g "0,640 80x460" 04a.png; CLOSEDROW=$(rust_row)
ptr click left; sleep .6; grim -g "0,640 80x460" 04b.png
[ "$(md5sum < 04a.png)" != "$(md5sum < 04b.png)" ] && say "PASS  toggle opens the drawer" || say "FAIL  toggle did not open the drawer"
OPENROW=$(rust_row)
say "note: Rust moves $((CLOSEDROW-OPENROW)) px up while the drawer is open"
ptr abs 36 420; sleep .3; grim -g "0,0 80x1200" 05-base.png   # an empty part of the bar
ptr abs 36 $VOL; sleep .6; grim -g "0,0 80x1200" 06a.png; sleep .7; grim -g "0,0 80x1200" 06b.png
check "volume drawer: picture steady, no flicker" "$(md5sum < 06a.png)" "$(md5sum < 06b.png)"
[ "$(md5sum < 05-base.png)" != "$(md5sum < 06b.png)" ] && say "PASS  volume drawer opened" || say "FAIL  volume drawer did not open"
grim 06c.png
ptr abs 36 420; sleep .4
check "the clock and Rust are back in place after the slider" "$(rust_row)" "$OPENROW"
ptr abs 1400 600; sleep $CLOSE; check "closes after using the drawers" "$(state $CLOSED)" closed
ptr abs 0 500; sleep .5; ptr abs 36 $TOG; sleep .3; grim -g "0,640 80x460" 07a.png
check "drawer is still open next time" "$(md5sum < 07a.png)" "$(md5sum < 04b.png)"
ptr click left; sleep .6; grim -g "0,640 80x460" 07b.png
check "toggle closes the drawer" "$(md5sum < 07b.png)" "$(md5sum < 04a.png)"
check "the clock and Rust are back in the centre once it closes" "$(rust_row)" "$CLOSEDROW"
ptr abs 1400 600; sleep $CLOSE; check "bar closes with the drawer shut" "$(state $CLOSED)" closed

say "--- a menu opened from the bar stays until Esc or a click"
ptr abs 0 500; sleep .5; ptr abs 36 $TOG; sleep .3; ptr click left; sleep .6
POWER=$(grim drawer.png; python3 $H/rows.py drawer.png | awk '{print $(NF-4)}'); say "power button y=$POWER"
ptr abs 36 $POWER; sleep .25; ptr click left; sleep 1.2
check "power button opens the menu" "$(menus)" 1
walk $POWER 70 100 130 170 210 300; sleep .4
check "menu stays when the pointer leaves the bar" "$(menus)" 1
ptr abs 1400 600; sleep .4
check "menu stays when the pointer crosses onto another window" "$(menus)" 1
sleep $CLOSE; check "the bar has closed" "$(state $CLOSED)" closed
check "menu stays after the bar closes" "$(menus)" 1
kbd esc; sleep .6; check "Esc closes it" "$(menus)" 0
ptr abs 0 500; sleep .5; ptr abs 36 $POWER; sleep .25; ptr click left; sleep 1.2
walk $POWER 70 100 170 300; ptr abs 1400 600; sleep $CLOSE
a=$(clicks right); ptr click left; sleep .6
check "a click on a window closes it" "$(menus)" 0
say "note: that click also reached the window: $(( $(clicks right) - a )) of 1"
ptr abs 300 600; sleep .4; check "focus follows the pointer again" "$(focused)" left
ptr abs 1400 600; sleep .4
ptr abs 0 500; sleep .5; ptr abs 36 $POWER; sleep .25; ptr click left; sleep 1.2
ptr click left; sleep .8; check "the same button closes it" "$(menus)" 0
ptr abs 36 $TOG; sleep .3; ptr click left; sleep .6
ptr abs 1400 600; sleep $CLOSE; check "bar closes after all that" "$(state $CLOSED)" closed

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
kill $VP $KB 2>/dev/null; exec 9>&- 8>&-
say "END"
swaymsg exit
