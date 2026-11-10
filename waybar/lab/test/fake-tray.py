#!/usr/bin/env python3
"""A stand-in tray app with a menu, built like nm-applet's. Choosing a row writes it to the file
given as the first argument. For a private D-Bus only: the tests never touch the real nm-applet,
because a wrong click in its menu could drop the connection.

It also answers as the desktop portal, because waybar quits without one on the bus."""
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("AppIndicator3", "0.1")
from gi.repository import AppIndicator3 as Indicator, Gio, GLib, Gtk  # noqa: E402

PORTAL = """<node><interface name="org.freedesktop.portal.Settings">
<method name="Read"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="out"/></method>
<method name="ReadOne"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="out"/></method>
</interface></node>"""


def portal_call(_bus, _sender, _path, _iface, method, _args, call):
    dark = GLib.Variant("u", 1)
    call.return_value(GLib.Variant("(v)", (GLib.Variant("v", dark) if method == "Read" else dark,)))


def portal_up(bus, _name):
    info = Gio.DBusNodeInfo.new_for_xml(PORTAL).interfaces[0]
    bus.register_object("/org/freedesktop/portal/desktop", info, portal_call, None, None)


Gio.bus_own_name(
    Gio.BusType.SESSION, "org.freedesktop.portal.Desktop", Gio.BusNameOwnerFlags.NONE, portal_up
)


def picked(_item, name):
    with open(sys.argv[1], "a") as f:
        f.write(name + "\n")


app = Indicator.Indicator.new(
    "fake-wifi", "network-wireless-symbolic", Indicator.IndicatorCategory.SYSTEM_SERVICES
)
menu = Gtk.Menu()
for row in ("First network", "Second network", "Third network", "Edit connections"):
    item = Gtk.MenuItem(label=row)
    item.connect("activate", picked, row)
    menu.append(item)
menu.show_all()
app.set_menu(menu)
app.set_status(Indicator.IndicatorStatus.ACTIVE)
Gtk.main()
