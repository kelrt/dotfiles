# Tray menus opened from the drawer, with the bar's auto-hide running. Run it through ./go tray.
# A stand-in tray app on a private D-Bus, so the real nm-applet is never clicked.
LAB=$OUT/lab
T=$OUT/run; rm -rf $T; mkdir -p $T; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
. $H/private-bus.sh
export WOFI=twofi
ptr() { echo "$*" >&9; }
kbd() { echo "$*" >&8; }
pixel() { grim -g "36,500 1x1" -t ppm - | tail -c 3 | od -An -tx1 | tr -d ' '; }
state() { [ "$(pixel)" = "$1" ] && echo closed || echo open; }
open_win() { swaymsg -q "exec foot -T $1 sh -c \"printf '\\\\033[?1000h\\\\033[?1006h'; stty raw -echo; exec cat > $T/$1.clicks\""; for i in $(seq 60); do swaymsg -t get_tree | grep -q "\"name\": \"$1\"" && break; sleep .1; done; sleep .2; }
clicks() { tr -cd M < $T/$1.clicks | wc -c; }
# The box of pixels right of the bar that differ between two pictures: x0 y0 x1 y1.
bbox() { python3 -c '
import sys, gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf
a, b = [GdkPixbuf.Pixbuf.new_from_file(f) for f in sys.argv[1:3]]
pa, pb, rs, n = a.get_pixels(), b.get_pixels(), a.get_rowstride(), a.get_n_channels()
xs, ys = [], []
for y in range(0, a.get_height(), 2):
    for x in range(70, a.get_width(), 2):
        i = y * rs + x * n
        if pa[i:i + 3] != pb[i:i + 3]:
            xs.append(x); ys.append(y)
print(min(xs), min(ys), max(xs), max(ys)) if xs else print("none")' "$1" "$2"; }
CLOSE=1.3
mkfifo ptr key
python3 $H/vptr.py < ptr > vptr.log 2>&1 & VP=$!
python3 $H/vkbd.py < key > vkbd.log 2>&1 & KB=$!
exec 9>ptr; exec 8>key
sleep .5
open_win left
ptr abs 1400 600; sleep .3
python3 $H/launch.py $LAB/try > bar.out 2>&1 & TRY=$!
for i in $(seq 200); do grep -q 'Bar configured' bar.out && break; sleep .1; done
sleep 2
REVEAL=$(pgrep -g $TRY -f /reveal.py); WAYBAR=$(pgrep -g $TRY -x waybar)
CLOSED=$(pixel)
ptr abs 0 500; sleep .6; check "bar opens" "$(state $CLOSED)" open
ptr abs 36 420; sleep .3; grim 01.png; rows=$(python3 $H/rows.py 01.png); say "rows: $rows"
set -- $rows; shift $(($#-4)); TOG=$1
ptr abs 36 $TOG; sleep .6; grim 02.png
rows=$(python3 $H/rows.py 02.png); say "rows with the drawer open: $rows"
set -- $rows; shift $(($#-5)); ICON=$1; say "tray icon y=$ICON"
grim base.png
icon() { ptr abs 36 $TOG; sleep .5; ptr abs 36 $ICON; sleep .3; }   # through the sliders, which open the drawer

say "--- open, and what closes it"
# A click on an empty part of the bar closes a menu.
shut() { ptr abs 36 420; sleep .25; ptr click left; sleep .5; }
icon; ptr click left; sleep .7; grim m1.png
BOX=$(bbox base.png m1.png); say "menu box: $BOX"
check "left click on the icon opens its menu" "$([ "$BOX" != none ] && echo yes)" yes
sleep 2; check "the bar stays while the pointer is on the icon" "$(state $CLOSED)" open
kbd esc; sleep .5; grim m2.png
say "note: after Esc the menu is: $([ "$(bbox base.png m2.png)" = none ] && echo closed || echo 'still open, the bar has no keyboard focus')"
[ "$(bbox base.png m2.png)" = none ] || shut
grim m2b.png; check "a click on the bar closes the menu" "$(bbox base.png m2b.png)" none

say "--- the pointer goes into the menu"
icon; ptr click left; sleep .7; grim m3.png
set -- $(bbox base.png m3.png); X=$((($1+$3)/2)); Y=$((($2+$4)/2)); say "middle of the menu: $X $Y"
ptr abs 75 $Y; sleep .1; ptr abs $X $Y; sleep 2.2
check "the bar holds while the pointer is on the menu" "$(state $CLOSED)" open
grim m4.png; check "the menu is still there 2 s later" "$([ "$(bbox base.png m4.png)" != none ] && echo yes)" yes
ptr click left; sleep .6
check "a click on a row chooses it" "$(wc -l < picked 2>/dev/null)" 1
say "note: chosen: $(cat picked)"
# The compositor sends nothing until the pointer next moves, so the bar's wait starts then.
sleep $CLOSE; say "note: with the pointer still, the bar is: $(state $CLOSED)"
ptr abs $((X+6)) $Y; sleep $CLOSE; check "the bar closes once the pointer moves" "$(state $CLOSED)" closed
ptr abs 1400 600; sleep .3

say "--- the bar still works after that"
ptr abs 0 500; sleep .6; check "opens" "$(state $CLOSED)" open
icon; ptr click left; sleep .7; grim m7.png
check "the menu opens again" "$([ "$(bbox base.png m7.png)" != none ] && echo yes)" yes
shut; check "the bar is still open with the pointer on it" "$(state $CLOSED)" open
ptr abs 1400 600; sleep $CLOSE; check "and closes after it leaves" "$(state $CLOSED)" closed

say "--- an app that starts after the bar, as at login"
ptr abs 0 500; sleep .6; ptr abs 36 $TOG; sleep .6; grim before.png
python3 $H/fake-tray.py $T/picked2 > tray2.out 2>&1 & ITEM2=$!
sleep 2; ptr abs 36 $((TOG+1)); sleep .3; grim after.png
A=$(python3 $H/rows.py before.png | wc -w); B=$(python3 $H/rows.py after.png | wc -w)
check "its icon appears" "$((B-A))" 1
kill $ITEM2; sleep 1.5; grim gone.png
check "and goes when it quits" "$(python3 $H/rows.py gone.png | wc -w)" "$A"
ptr abs 1400 600; sleep $CLOSE

say "--- a click outside"
ptr abs 0 500; sleep .6; icon; ptr click left; sleep .7
a=$(clicks left); ptr abs 1400 600; sleep .3; ptr click left; sleep .6; grim m5.png
say "note: that click also reached the window: $(( $(clicks left) - a )) of 1"
sleep $CLOSE; check "a click on a window closes the menu, then the bar" "$(state $CLOSED)" closed
ptr abs 0 500; sleep .6; check "the bar opens again afterwards" "$(state $CLOSED)" open
icon; ptr click right; sleep .7; grim m6.png
check "right click opens the menu too" "$([ "$(bbox base.png m6.png)" != none ] && echo yes)" yes
shut
ptr abs 1400 600; sleep $CLOSE; check "bar closes at the end" "$(state $CLOSED)" closed

say "END"
kill $ITEM $VP $KB 2>/dev/null; pkill -g $TRY; exec 9>&- 8>&-
kill $BUS 2>/dev/null
swaymsg exit
