# A stand-in for tuned-ppd on a private bus: checks what hold-power-saver.py sends, and that
# the hold ends when that process stops. Run under dbus-run-session. Prints PASS or FAIL lines.
import os, signal, subprocess, sys
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

XML = """<node><interface name="net.hadess.PowerProfiles"><method name="HoldProfile">
<arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="s" direction="in"/>
<arg type="u" direction="out"/></method></interface></node>"""
env = dict(os.environ, DBUS_SYSTEM_BUS_ADDRESS=os.environ["DBUS_SESSION_BUS_ADDRESS"])
loop = GLib.MainLoop()
helper = None
held = False

def done(*_):
    print("FAIL  no hold arrived" if not held else "FAIL  hold didn't end with the process", flush=True)
    loop.quit()

def vanished(*_):
    print("PASS  the hold ends when the helper stops", flush=True)
    loop.quit()

def call(conn, sender, path, iface, method, args, inv):
    global held
    held = True
    ok = method == "HoldProfile" and args.unpack()[0] == "power-saver"
    print(("PASS" if ok else "FAIL") + "  helper asks to hold power-saver", flush=True)
    Gio.bus_watch_name_on_connection(conn, sender, Gio.BusNameWatcherFlags.NONE, None, vanished)
    inv.return_value(GLib.Variant("(u)", (7,)))
    GLib.timeout_add(1200, lambda: helper.terminate() or False)

def acquired(conn, name):
    global helper
    info = Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0]
    conn.register_object("/net/hadess/PowerProfiles", info, call)
    helper = subprocess.Popen(sys.argv[1:], env=env)

Gio.bus_own_name(Gio.BusType.SESSION, "net.hadess.PowerProfiles", Gio.BusNameOwnerFlags.NONE, None, acquired)
GLib.timeout_add(8000, done)
loop.run()
