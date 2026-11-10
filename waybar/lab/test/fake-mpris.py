#!/usr/bin/env python3
"""Stand-in MPRIS media player for the PRIVATE test D-Bus only.
Usage: fake-mpris.py <name> <log file> [empty | noartist]
Each control call is written to the log as "<name> <Method>"; Play/Pause, Stop and Next/Previous
change its state the way a real player's would, and announce it, so playerctld sees the activity.
empty: nothing loaded, like a player with an empty playlist. noartist: a title with no artist,
like a browser video, with characters that need escaping."""
import os
import sys

from gi.repository import Gio, GLib

if "side-bar-test" not in os.environ.get("DBUS_SESSION_BUS_ADDRESS", ""):
    sys.exit("refusing: only runs on the private test bus")

NAME, LOG = sys.argv[1], sys.argv[2]
PATH = "/org/mpris/MediaPlayer2"
XML = """<node>
<interface name="org.mpris.MediaPlayer2">
 <method name="Raise"/><method name="Quit"/>
 <property name="Identity" type="s" access="read"/>
 <property name="CanQuit" type="b" access="read"/>
 <property name="CanRaise" type="b" access="read"/>
 <property name="HasTrackList" type="b" access="read"/>
 <property name="SupportedUriSchemes" type="as" access="read"/>
 <property name="SupportedMimeTypes" type="as" access="read"/>
</interface>
<interface name="org.mpris.MediaPlayer2.Player">
 <method name="Next"/><method name="Previous"/><method name="Pause"/><method name="PlayPause"/>
 <method name="Stop"/><method name="Play"/>
 <method name="Seek"><arg type="x" direction="in"/></method>
 <method name="SetPosition"><arg type="o" direction="in"/><arg type="x" direction="in"/></method>
 <method name="OpenUri"><arg type="s" direction="in"/></method>
 <signal name="Seeked"><arg type="x"/></signal>
 <property name="PlaybackStatus" type="s" access="read"/>
 <property name="LoopStatus" type="s" access="read"/>
 <property name="Rate" type="d" access="read"/>
 <property name="Shuffle" type="b" access="read"/>
 <property name="Metadata" type="a{sv}" access="read"/>
 <property name="Volume" type="d" access="read"/>
 <property name="Position" type="x" access="read"/>
 <property name="MinimumRate" type="d" access="read"/>
 <property name="MaximumRate" type="d" access="read"/>
 <property name="CanGoNext" type="b" access="read"/>
 <property name="CanGoPrevious" type="b" access="read"/>
 <property name="CanPlay" type="b" access="read"/>
 <property name="CanPause" type="b" access="read"/>
 <property name="CanSeek" type="b" access="read"/>
 <property name="CanControl" type="b" access="read"/>
</interface>
</node>"""
state = {"status": "Paused", "track": 1}
EMPTY = len(sys.argv) > 3 and sys.argv[3] == "empty"
NOARTIST = len(sys.argv) > 3 and sys.argv[3] == "noartist"


def metadata():
    if EMPTY:
        return GLib.Variant("a{sv}", {"mpris:trackid": GLib.Variant("o", "/org/mpris/MediaPlayer2/TrackList/NoTrack")})
    return GLib.Variant("a{sv}", {
        "mpris:trackid": GLib.Variant("o", f"/fake/{NAME}/{state['track']}"),
        "xesam:title": GLib.Variant("s", f"song {state['track']} & <\"quotes\"> \\ tab\there" if NOARTIST else f"song {state['track']}"),
        **({} if NOARTIST else {"xesam:artist": GLib.Variant("as", [NAME])}),
        "mpris:length": GLib.Variant("x", 200_000_000),
    })


def get_property(_conn, _sender, _path, iface, prop):
    if iface == "org.mpris.MediaPlayer2":
        values = {"Identity": GLib.Variant("s", NAME), "SupportedUriSchemes": GLib.Variant("as", []),
                  "SupportedMimeTypes": GLib.Variant("as", [])}
        return values.get(prop, GLib.Variant("b", False))
    values = {"PlaybackStatus": GLib.Variant("s", state["status"]), "LoopStatus": GLib.Variant("s", "None"),
              "Rate": GLib.Variant("d", 1.0), "MinimumRate": GLib.Variant("d", 1.0),
              "MaximumRate": GLib.Variant("d", 1.0), "Volume": GLib.Variant("d", 1.0),
              "Position": GLib.Variant("x", 0), "Shuffle": GLib.Variant("b", False),
              "Metadata": metadata()}
    return values.get(prop, GLib.Variant("b", True))  # every Can* is true


def method_call(conn, _sender, _path, _iface, method, _args, invocation):
    with open(LOG, "a") as f:
        f.write(f"{NAME} {method}\n")
    changed = {}
    if method in ("Play", "Pause", "PlayPause", "Stop"):
        new = {"Play": "Playing", "Pause": "Paused", "Stop": "Stopped",
               "PlayPause": "Paused" if state["status"] == "Playing" else "Playing"}[method]
        state["status"] = new
        changed["PlaybackStatus"] = GLib.Variant("s", new)
    elif method in ("Next", "Previous"):
        state["track"] += 1 if method == "Next" else -1
        changed["Metadata"] = metadata()
    invocation.return_value(None)
    if changed:
        conn.emit_signal(None, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                         GLib.Variant("(sa{sv}as)", ("org.mpris.MediaPlayer2.Player", changed, [])))


def acquired(conn, _name):
    for info in Gio.DBusNodeInfo.new_for_xml(XML).interfaces:
        conn.register_object(PATH, info, method_call, get_property, None)


Gio.bus_own_name(Gio.BusType.SESSION, "org.mpris.MediaPlayer2." + NAME, Gio.BusNameOwnerFlags.NONE,
                 acquired, None, None)
GLib.MainLoop().run()
