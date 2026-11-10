# ~/.config/sway/scripts/scratch-app with stand-in apps. Run it through ./go scratchapp.
# The real for_window rules from sway/includes/window_rules; foot stands in for calcpad and a small
# GTK window for Mousepad, so no real app starts. Bitwarden is only checked with a dry run.
T=$OUT/run; rm -rf $T; mkdir -p $T/bin; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
cat > bin/notify-send <<X
#!/bin/sh
echo "\$*" >> $T/notify.log
X
chmod +x bin/notify-send; touch notify.log
export PATH=$T/bin:$PATH
cat > gtkwin.py <<'X'
import sys, gi
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk
GLib.set_prgname(sys.argv[1])   # the app_id sway sees
w = Gtk.Window(title=sys.argv[2])
w.set_default_size(300, 200)
if sys.argv[3:] == ["refuse"]:
    w.connect("delete-event", lambda *_: True)   # like Mousepad asking whether to save
else:
    w.connect("destroy", Gtk.main_quit)
w.show_all()
Gtk.main()
X
# Through swaymsg the rule's commands need quotes, or sway splits them at the commas and runs all
# but the first straight away. In the config file the whole line belongs to the rule.
grep -E '^for_window \[(app_id="calcpad"|app_id="mousepad")' $HOME/.config/sway/includes/window_rules \
    | sed -E 's/^(for_window \[[^]]*\]) +(.*)$/\1 "\2"/' > rules
while read -r line; do swaymsg -q "$line"; done < rules
say "note: $(wc -l < rules) rules copied from window_rules"

S=$HOME/.config/sway/scripts/scratch-app
export SCRATCH_APP_START_calc="foot --app-id=calcpad sh -c 'sleep 300'"
export SCRATCH_APP_START_notes="python3 $T/gtkwin.py mousepad 'notes.txt - Mousepad'"
tree() { swaymsg -t get_tree; }
state() {  # shown, hidden or none
    tree | jq -r --arg m "$1" '
        ([.. | objects | select(.name? == "__i3_scratch") | .floating_nodes[] | select(any(.marks[]?; . == $m))] | length) as $h
        | ([.. | objects | select(any(.marks[]?; . == $m))] | length) as $all
        | if $all == 0 then "none" elif $h > 0 then "hidden" else "shown" end'; }
conid() { tree | jq -r --arg m "$1" 'first(.. | objects | select(any(.marks[]?; . == $m)) | .id) // empty'; }
count() { tree | jq --arg m "$1" '[.. | objects | select(any(.marks[]?; . == $m))] | length'; }
focused_mark() { tree | jq -r '.. | objects | select(.focused? == true) | .marks[0] // .name'; }
swaymsg -q 'exec foot -T main sh -c "sleep 300"'; sleep 1

say "--- calculator, not running"
check "no calculator yet" "$(state calc)" none
$S calc; sleep .3
check "a press starts it and shows it" "$(state calc)" shown
check "focused" "$(focused_mark)" calc
check "with a notification" "$(grep -c '^-u low -r 9920 Starting Calculator' notify.log)" 1
$S calc; sleep .3; check "the next press hides it" "$(state calc)" hidden
$S calc; sleep .3; check "and the next shows it" "$(state calc)" shown
kill "$(tree | jq -r '.. | objects | select(any(.marks[]?; . == "calc")) | .pid')"; sleep .6
check "after a crash the window is gone" "$(state calc)" none
$S calc; sleep .3; check "a press after a crash starts it again and shows it" "$(state calc)" shown

say "--- right click: restart"
old=$(conid calc); $S calc restart; sleep .3
check "a fresh window, shown" "$(state calc) $([ -n "$old" ] && [ "$(conid calc)" != "$old" ] && echo fresh)" "shown fresh"
check "only one calculator" "$(count calc)" 1
$S calc; sleep .3   # hidden again
old=$(conid calc); $S calc restart; sleep .3
check "restart from hidden: fresh and shown" "$(state calc) $([ "$(conid calc)" != "$old" ] && echo fresh)" "shown fresh"

say "--- notes"
$S notes; sleep .5
check "notes starts and shows" "$(state notes)" shown
old=$(conid notes); $S notes restart; sleep .5
check "restart closes and reopens notes" "$(state notes) $([ "$(conid notes)" != "$old" ] && echo fresh)" "shown fresh"
swaymsg -q '[con_mark="notes"] kill'; sleep .8
export SCRATCH_APP_START_notes="python3 $T/gtkwin.py mousepad 'notes.txt - Mousepad' refuse"
$S notes; sleep .5
old=$(conid notes); $S notes restart
check "notes that won't close (asking to save): left alone" "$(conid notes)" "$old"
check "and it says why" "$(grep -c 'Notes is still open' notify.log)" 1

say "--- a key held or pressed fast while starting"
swaymsg -q '[con_mark="calc"] kill'; sleep .8
$S calc & $S calc & $S calc & wait; sleep .5
check "three presses at once start one calculator" "$(count calc)" 1
check "and it is showing" "$(state calc)" shown

say "--- the bar tests' dry run"
check "only prints what it would start" "$(SCRATCH_APP_DRY=1 $S bw)" "would start: flatpak run com.bitwarden.desktop"
check "an unknown name is refused" "$($S other 2>/dev/null; echo $?)" 2

pkill -f "$T/gtkwin.py" 2>/dev/null
say "END"
swaymsg exit
