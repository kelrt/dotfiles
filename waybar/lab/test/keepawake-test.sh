# ~/.config/waybar/scripts/keep-awake with stand-ins for systemd-inhibit, swaymsg and pkill, so no
# real lock is taken and no real bar is signalled. Run it through ./go keepawake.
T=$OUT/run; rm -rf $T; mkdir -p $T/bin $T/rt; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
cat > bin/systemd-inhibit <<X
#!/bin/sh
# stand-in: note the options, then run the command after them and wait for it, as the real one does
echo "\$*" >> $T/inhibit.log
while [ "\${1#--}" != "\$1" ]; do shift; done
"\$@"
X
cat > bin/swaymsg <<X
#!/bin/sh
[ ! -e $T/session-ended ]
X
cat > bin/pkill <<X
#!/bin/sh
echo "\$*" >> $T/pkill.log
X
chmod +x bin/*
K="env PATH=$T/bin:$PATH XDG_RUNTIME_DIR=$T/rt KEEP_AWAKE_POLL=0.2 sh $HOME/.config/waybar/scripts/keep-awake"
state() { $K | jq -r .alt; }
held() { pgrep -f "$T/bin/systemd-inhibit" | wc -l; }

say "--- on and off"
check "starts off" "$(state)" deactivated
$K toggle >/dev/null; sleep .3
check "a click turns it on" "$(state)" activated
check "and holds one lock" "$(held)" 1
check "idle and sleep, blocking" "$(tail -1 inhibit.log | grep -c -- '--what=idle:sleep .*--mode=block')" 1
check "every bar is told to redraw" "$(tail -1 pkill.log)" "-RTMIN+9 -x waybar"
$K toggle >/dev/null; sleep .3
check "a second click turns it off" "$(state)" deactivated
check "and the lock and its loop are gone" "$(held) $(pgrep -f 'do sleep 0.2; done' | wc -l)" "0 0"

say "--- what can't break it"
sh -c "$K toggle >/dev/null"; sleep .3   # turned on from a shell that then exits, like a bar that restarts
pid=$(cat rt/keep-awake.pid)
check "stays on after the process that turned it on is gone" "$(state) $([ -d /proc/$pid ] && echo running)" "activated running"
echo $$ > rt/keep-awake.pid
check "a stale pid file pointing at something else reads as off" "$(state)" deactivated
echo "$pid" > rt/keep-awake.pid
touch session-ended; sleep .8
check "it ends by itself when sway is gone" "$(state) $(held)" "deactivated 0"

say "END"
swaymsg exit
