# $mod+minus through ~/.config/sway/scripts/scratchpad-cycle. Run it through ./go scratch.
# Only the private sway's windows are involved.
T=$OUT/run; rm -rf $T; mkdir -p $T; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
C=$HOME/.config/sway/scripts/scratchpad-cycle
open_win() { swaymsg -q "exec foot -T $1 sh -c 'sleep 300'"; for i in $(seq 60); do swaymsg -t get_tree | grep -q "\"name\": \"$1\"" && break; sleep .1; done; sleep .2; }
# Scratchpad windows that are showing, by title, sorted.
shown() { swaymsg -t get_tree | jq -r '[.. | objects | select(.name? == "__i3_scratch") | .floating_nodes[].id] as $h
    | [.. | objects | select((.scratchpad_state? // "none") != "none") | select(.id as $i | $h | index($i) | not) | .name] | sort | join(" ")'; }
focused() { swaymsg -t get_tree | jq -r '.. | objects | select(.focused? == true) | .name'; }
ws_of() { swaymsg -t get_tree | jq -r --arg n "$1" '.. | objects | select(.type? == "workspace") | . as $w | .. | objects | select(.name? == $n) | $w.name' | head -1; }
press() { bash $C; sleep .25; }

open_win main
for m in calc notes bw; do open_win $m; swaymsg -q "[title=\"^$m\$\"] mark $m, floating enable, move scratchpad"; done
for w in one two; do open_win $w; swaymsg -q "[title=\"^$w\$\"] floating enable, move scratchpad"; done
swaymsg -q '[title="^main$"] focus'; sleep .3

say "--- spamming the key"
press; check "1st press shows one of the others" "$(shown)" one
check "and focuses it" "$(focused)" one
press; check "2nd press hides it" "$(shown)" ""
press; check "3rd press shows the next one" "$(shown)" two
press; press; check "and round again" "$(shown)" one
press; check "hidden again" "$(shown)" ""
say "note: calc, notes and bw were never shown by those presses"

say "--- with one of the three open"
swaymsg -q '[con_mark="calc"] scratchpad show'; sleep .3
check "calc is showing and focused" "$(shown) $(focused)" "calc calc"
press; check "a press leaves calc and shows the next of the others" "$(shown)" "calc two"
press; check "the next press hides that one, calc stays" "$(shown)" calc
swaymsg -q '[con_mark="calc"] scratchpad show'; sleep .3
check "\$mod+c's command still hides calc" "$(shown)" ""

say "--- another workspace"
press; W=$(shown); swaymsg -q workspace 2; sleep .3
press; check "a window showing elsewhere comes to this workspace" "$(ws_of $W)" 2
press; check "and the next press hides it" "$(shown)" ""
swaymsg -q workspace 1; sleep .3

say "--- held key: many presses at once"
for i in 1 2 3 4 5 6; do bash $C & done; wait; sleep .3
check "six at once end like six in a row: nothing showing" "$(shown)" ""
for i in 1 2 3; do bash $C & done; wait; sleep .3
check "three at once: one showing" "$(shown | wc -w)" 1

say "--- nothing else in the scratchpad"
swaymsg -q '[title="^(one|two)$"] kill'; sleep .5
press; check "a press with only the three: nothing shows" "$(shown)" ""
check "and no error" "$(bash $C 2>&1 | wc -c)" 0
say "END"
swaymsg exit
