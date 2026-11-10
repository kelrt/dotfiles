# The music button's script, ~/.config/waybar/scripts/music, with stand-in players. Run it
# through ./go music. A private D-Bus whose only service is playerctld, so no real player is involved.
T=$OUT/run; rm -rf $T; mkdir -p $T/svc; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
cp /usr/share/dbus-1/services/org.mpris.MediaPlayer2.playerctld.service svc/
cat > bus.conf <<X
<busconfig>
  <type>session</type>
  <listen>unix:path=$T/bus</listen>
  <servicedir>$T/svc</servicedir>
  <policy context="default"><allow user="*"/><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy>
</busconfig>
X
export DBUS_SESSION_BUS_ADDRESS=unix:path=$T/bus   # before the daemon, so playerctld starts on it too
dbus-daemon --config-file=bus.conf --nofork --nopidfile & BUS=$!
sleep .4
playerctl -p playerctld status >/dev/null 2>&1   # starts playerctld, the way the bar's clicks do
PCD=$(gdbus call -e -d org.freedesktop.DBus -o /org/freedesktop/DBus -m org.freedesktop.DBus.GetConnectionUnixProcessID org.mpris.MediaPlayer2.playerctld 2>/dev/null | sed -E 's/.*uint32 ([0-9]+).*/\1/')
$HOME/.config/waybar/scripts/music > out.txt 2>err.txt & M=$!
sleep .8
FOLLOW=$(pgrep -P $M -x playerctl)
now() { sleep .8; tail -n1 out.txt; }
player() { python3 $H/fake-mpris.py "$@" 2>/dev/null & for i in $(seq 40); do playerctl -l 2>/dev/null | grep -qx "$1" && break; sleep .1; done; }
HIDDEN='{"text":"","class":""}'

say "--- when the button shows"
check "nothing open: no button" "$(tail -n1 out.txt)" ""
player spotify calls; A=$!
check "a player opens with a song, paused: shown, dimmed" "$(now)" '{"text":"spotify - song 1","class":"paused"}'
playerctl -p spotify play
check "it plays" "$(now)" '{"text":"spotify - song 1","class":"playing"}'
playerctl -p spotify stop
check "stopped: hidden" "$(now)" "$HIDDEN"
playerctl -p spotify play; sleep .3
player firefox calls noartist; B=$!; playerctl -p firefox play
check "a video with no artist plays: its title, every character kept" "$(now)" '{"text":"song 1 & <\"quotes\"> \\ tab\there","class":"playing"}'
# Through playerctld, playerName is always playerctld; the stand-in's track id names the player.
check "a click goes to that video" "$(playerctl -p playerctld metadata --format '{{ mpris:trackid }}' 2>/dev/null | tr -d "'")" /fake/firefox/1
kill $B; B=
check "the browser closes: back to the song" "$(now)" '{"text":"spotify - song 1","class":"playing"}'
check "and a click goes to the song" "$(playerctl -p playerctld metadata --format '{{ mpris:trackid }}' 2>/dev/null | tr -d "'")" /fake/spotify/1
kill $A; A=
check "the last player closes: hidden, not the last song" "$(now)" "$HIDDEN"
player audacious calls empty; C=$!
check "a player with nothing loaded: hidden" "$(now)" "$HIDDEN"
kill $C; C=; sleep .5

say "--- process life"
check "every line is JSON waybar can read" "$(jq -e . out.txt >/dev/null 2>&1 && echo yes)" yes
check "nothing on stderr" "$(wc -c < err.txt)" 0
kill $M; sleep .5
check "playerctl stops with the script" "$(kill -0 $FOLLOW 2>/dev/null && echo running || echo gone)" gone
[ -n "$PCD" ] && kill $PCD 2>/dev/null
kill $BUS 2>/dev/null
say "END"
swaymsg exit
