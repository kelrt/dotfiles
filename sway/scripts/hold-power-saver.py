#!/usr/bin/python3
"""Hold the power-saver profile for as long as this runs.

tuned-ppd drops a hold when the process that asked for it goes away, and the profile you picked
comes back by itself. A hold doesn't change that saved pick, so a reboot can't leave the laptop
stuck in power saver. Picking a profile on the bar cancels the hold.
"""
import signal

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
bus.call_sync(
    "net.hadess.PowerProfiles",
    "/net/hadess/PowerProfiles",
    "net.hadess.PowerProfiles",
    "HoldProfile",
    GLib.Variant("(sss)", ("power-saver", "Battery at 20%", "low-battery.sh")),
    GLib.VariantType("(u)"),
    Gio.DBusCallFlags.NONE,
    -1,
)
signal.pause()
