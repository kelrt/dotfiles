# Sourced by the tests that start a bar, from their run folder ($T).
# A private D-Bus with no service files, so nothing real starts on it, and a stand-in tray app that
# also answers as the desktop portal.
# This is what keeps a test away from your real tray. Every waybar that starts claims the tray's
# watcher name, and every other bar empties its tray when that happens, then refills it when the
# name comes back. On the real bus a test bar would do that to your real bar each time it started
# and stopped, and it could miss icons itself.
cat > bus.conf <<X
<busconfig>
  <type>session</type>
  <listen>unix:path=$T/bus</listen>
  <policy context="default"><allow user="*"/><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy>
</busconfig>
X
dbus-daemon --config-file=bus.conf --nofork --nopidfile & BUS=$!
export DBUS_SESSION_BUS_ADDRESS=unix:path=$T/bus NO_AT_BRIDGE=1
sleep .4
python3 $H/fake-tray.py $T/picked > tray.out 2>&1 & ITEM=$!
sleep 1
