# Wofi menus, through the real ~/.config/wofi/menu and wofi config. Run it through ./go menu.
# wofi runs as twofi, a link to the same program, so nothing here can touch a real menu.
T=$OUT/run; rm -rf $T; mkdir -p $T; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
export WOFI=twofi
M=$HOME/.config/wofi/menu
menus() { pgrep -x twofi | wc -l; }
focused() { swaymsg -t get_tree | jq -r '.. | objects | select(.focused? == true) | .name'; }
open_win() { swaymsg -q "exec foot -T $1 sh -c 'sleep 300'"; for i in $(seq 60); do swaymsg -t get_tree | grep -q "\"name\": \"$1\"" && break; sleep .1; done; sleep .2; }
list() { printf 'one\ntwo\n' | $M --dmenu --cache-file /dev/null > menu.out 2>/dev/null; }
ptr() { echo "$*" >&9; }
kbd() { echo "$*" >&8; }
mkfifo ptr key
python3 $H/vptr.py < ptr > vptr.log 2>&1 & VP=$!
python3 $H/vkbd.py < key > vkbd.log 2>&1 & KB=$!
exec 9>ptr; exec 8>key
sleep 1
open_win left; open_win right
ptr abs 300 300; sleep .4

say "--- stays open"
list & sleep 1.2; check "a menu opens" "$(menus)" 1
ptr abs 320 340; sleep .5; check "pointer moves inside a window" "$(menus)" 1
ptr abs 1500 300; sleep .6; check "pointer crosses onto another window" "$(menus)" 1
ptr abs 960 600; sleep .4; ptr abs 1500 900; sleep .5; check "pointer crosses the menu and leaves" "$(menus)" 1
python3 $HOME/.config/waybar/lab/osd/osd.py --demo volume 50 & sleep 2.1; check "the volume popup comes and goes" "$(menus)" 1
ptr abs 960 600; sleep .4; ptr click left; sleep .5; check "one click on a row keeps it open" "$(menus)" 1

say "--- closes"
kbd esc; sleep .6; check "Esc closes it" "$(menus)" 0
check "Esc chooses nothing" "$(cat menu.out)" ""
ptr abs 300 300; sleep .4; ptr abs 1500 300; sleep .4; check "focus follows the pointer afterwards" "$(focused)" right
ptr abs 300 300; sleep .4; check "and back" "$(focused)" left
list & sleep 1.2; ptr abs 1500 300; sleep .5; ptr click left; sleep .6
check "a click on another window closes it" "$(menus)" 0
check "and focuses that window" "$(focused)" right
ptr abs 300 300; sleep .4
list & sleep 1.2; ptr click left; sleep .6; check "a click on the window that had focus closes it" "$(menus)" 0
swaymsg -q workspace 2; sleep .3
list & sleep 1.2; ptr abs 60 60; sleep .4; check "pointer moves on an empty workspace" "$(menus)" 1
ptr click left; sleep .6; check "a click on an empty workspace closes it" "$(menus)" 0
swaymsg -q workspace 1; sleep .3; ptr abs 300 300; sleep .4
list & sleep 1.2; kbd down; sleep .2; kbd return; sleep .6
check "keyboard choice comes out of the wrapper" "$(cat menu.out)" two

say "--- the same key closes it"
kbd mod4+d; sleep 1.4; check "\$mod+d opens the launcher" "$(menus)" 1
kbd mod4+d; sleep .8; check "\$mod+d closes it" "$(menus)" 0
kbd mod4+d; sleep 1.4; kbd esc; sleep .6; check "Esc still closes the launcher" "$(menus)" 0
list & sleep 1.2; kbd mod4+d; sleep .9; check "\$mod+d closes any menu and opens nothing" "$(menus)" 0
ptr abs 1500 300; sleep .4; check "focus follows the pointer after that too" "$(focused)" right

say "--- launching apps gives focus back straight away"
mkdir -p data/applications
# GIO needs a terminal it recognises, or a Terminal=true app wouldn't start at all.
printf '#!/bin/sh\nexec foot -T labterm "$@"\n' > $OUT/bin/xdg-terminal-exec; chmod +x $OUT/bin/xdg-terminal-exec
cat > data/applications/labgui.desktop <<X
[Desktop Entry]
Type=Application
Name=Labgui
Exec=foot -T labgui sleep 31.4159
X
cat > data/applications/labterm.desktop <<X
[Desktop Entry]
Type=Application
Name=Labterm
Terminal=true
Exec=sleep 31.4159
X
for app in Labgui Labterm; do
    XDG_DATA_HOME=$T/data $M --show drun --cache-file /dev/null --search $app -D drun-ignore_metadata=true & W=$!
    sleep 1.4; kbd return; sleep 1.2
    if kill -0 $W 2>/dev/null; then say "FAIL  $app: the wrapper is still waiting"; else say "PASS  $app: the wrapper has finished"; fi
    say "note: windows after $app: $(swaymsg -t get_tree | jq -r '[.. | objects | select(.pid? and .type? == "con") | .app_id] | join(" ")')"
    n=$(swaymsg -t get_seats >/dev/null; pgrep -f 'sleep 31[.]4159' | wc -l); say "note: $app processes running: $n"
    ptr abs 300 300; sleep .4; ptr abs 1500 300; sleep .4; a=$(focused); ptr abs 300 300; sleep .4; b=$(focused)
    [ "$a" != "$b" ] && say "PASS  $app: focus follows the pointer while the app runs" || say "FAIL  $app: focus stuck on $a"
    pkill -f 'sleep 31[.]4159'; sleep .5
done
ptr abs 1500 300; sleep .4

say "--- fullscreen"
swaymsg -q fullscreen enable; sleep .5
grim -g "800,500 300x200" fs-a.png
list & sleep 1.2; grim -g "800,500 300x200" fs-b.png
[ "$(md5sum < fs-a.png)" != "$(md5sum < fs-b.png)" ] && say "PASS  menu shows over a fullscreen window" || say "FAIL  menu is hidden behind the fullscreen window"
kbd esc; sleep .6; check "Esc closes it there" "$(menus)" 0
say "END"
kill $VP $KB 2>/dev/null; exec 9>&- 8>&-
swaymsg exit
