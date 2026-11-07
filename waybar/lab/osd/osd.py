#!/usr/bin/python3
"""Centered on-screen display for volume and brightness.

Uses only what is already installed (GTK3, gtk-layer-shell, pactl, wpctl). It watches
for changes itself, so the F-keys, scroll wheels and pavucontrol all trigger it with
no key bindings. Sway starts it at login, so it runs whichever bar is up.

  osd.py                     watch and show; Ctrl+C stops it
  osd.py --demo KIND VALUE   show one popup and exit (KIND: volume, muted, brightness)

Colours come from ~/.config/waybar/colors.css, so it follows matugen.
"""
import glob
import os
import signal
import subprocess
import sys

import cairo
import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell  # noqa: E402

HIDE_AFTER_MS = 1400
RESUBSCRIBE_MS = 2000  # how soon to try again when the audio server isn't there
COLORS = os.path.expanduser("~/.config/waybar/colors.css")
FALLBACK_COLORS = """
@define-color primary #ffb4ac;
@define-color surface #1a1110;
@define-color on_surface #f1dedc;
@define-color outline #a08c8a;
"""
CSS = """
window { background: transparent; }
#osd {
    background: alpha(@surface, 0.92);
    border: 1px solid alpha(@outline, 0.35);
    border-radius: 20px;
    padding: 16px 22px;
}
#icon { font-family: "Font Awesome 6 Free"; font-weight: 900; font-size: 22px; color: @primary; min-width: 34px; }
#percent { font-family: monospace; font-size: 15px; font-weight: bold; color: @on_surface; min-width: 46px; }
levelbar trough { background: alpha(@on_surface, 0.16); border: none; border-radius: 5px; min-height: 10px; }
levelbar block { border: none; border-radius: 5px; min-height: 10px; }
levelbar block.filled { background: @primary; }
levelbar block.empty { background: transparent; }
#osd.muted #icon { color: alpha(@on_surface, 0.5); }
#osd.muted levelbar block.filled { background: alpha(@on_surface, 0.35); }
"""
ICONS = {"high": "", "low": "", "off": "", "muted": "", "brightness": ""}


class Osd:
    def __init__(self):
        self.timer = 0
        self.colors_stamp = None
        self.provider = Gtk.CssProvider()
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), self.provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        self._style()
        self.win = Gtk.Window()
        screen = self.win.get_screen()
        if screen.get_rgba_visual():
            self.win.set_visual(screen.get_rgba_visual())
        self.win.set_app_paintable(True)

        GtkLayerShell.init_for_window(self.win)
        GtkLayerShell.set_namespace(self.win, "lab-osd")
        GtkLayerShell.set_layer(self.win, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self.win, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_exclusive_zone(self.win, -1)  # no anchors: centered on the focused output

        self.box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        self.box.set_name("osd")
        self.icon = Gtk.Label()
        self.icon.set_name("icon")
        self.bar = Gtk.LevelBar()
        self.bar.set_size_request(240, 10)
        self.bar.set_valign(Gtk.Align.CENTER)
        self.bar.set_min_value(0)
        self.bar.set_max_value(100)
        self.percent = Gtk.Label()
        self.percent.set_name("percent")
        self.box.pack_start(self.icon, False, False, 0)
        self.box.pack_start(self.bar, False, False, 0)
        self.box.pack_start(self.percent, False, False, 0)
        self.win.add(self.box)
        self.box.show_all()
        # Clicks pass straight through to whatever is underneath.
        self.win.connect("map", lambda w: w.input_shape_combine_region(cairo.Region()))

    def _style(self):
        """Load the colours, and load them again after a wallpaper change."""
        try:
            stamp = os.stat(COLORS).st_mtime_ns
            if stamp == self.colors_stamp:
                return
            with open(COLORS, encoding="utf-8") as f:
                colors = f.read()
        except OSError:
            stamp, colors = None, FALLBACK_COLORS
        self.colors_stamp = stamp
        self.provider.load_from_data((colors + CSS).encode())

    def show(self, kind, value, muted=False):
        self._style()
        value = max(0, min(100, int(round(value))))
        if kind == "brightness":
            glyph = ICONS["brightness"]
        elif muted:
            glyph = ICONS["muted"]
        else:
            glyph = ICONS["off"] if value == 0 else ICONS["low"] if value < 50 else ICONS["high"]
        self.icon.set_text(glyph)
        self.bar.set_value(value)
        self.percent.set_text(f"{value}%")
        ctx = self.box.get_style_context()
        ctx.add_class("muted") if muted else ctx.remove_class("muted")
        self.win.show()
        if self.timer:
            GLib.source_remove(self.timer)
        self.timer = GLib.timeout_add(HIDE_AFTER_MS, self._hide)

    def _hide(self):
        self.timer = 0
        self.win.hide()
        return GLib.SOURCE_REMOVE


class VolumeWatcher:
    """pactl subscribe wakes us only when something changes, so nothing polls."""

    def __init__(self, osd):
        self.osd = osd
        self.last = self._read()
        self.pending = 0
        self._subscribe()

    def _subscribe(self):
        # pdeathsig stops pactl if this process dies. Left alone it carries on with nobody reading.
        self.proc = subprocess.Popen(
            ["setpriv", "--pdeathsig", "TERM", "pactl", "subscribe"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )
        GLib.io_add_watch(self.proc.stdout, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, self._line)
        return GLib.SOURCE_REMOVE

    @staticmethod
    def _read():
        out = subprocess.run(
            ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True
        ).stdout.split()
        # "Volume: 0.90" or "Volume: 0.90 [MUTED]"
        if len(out) < 2 or out[0] != "Volume:":
            return None
        return (round(float(out[1]) * 100), "[MUTED]" in out)

    def _line(self, stream, condition):
        if condition & GLib.IO_HUP:
            # pactl stops if the audio server isn't up yet at login, or restarts later.
            self.proc.wait()
            GLib.timeout_add(RESUBSCRIBE_MS, self._subscribe)
            return GLib.SOURCE_REMOVE
        line = stream.readline()
        if "on sink #" in line or "on server" in line:
            if not self.pending:
                self.pending = GLib.timeout_add(40, self._check)
        return GLib.SOURCE_CONTINUE

    def _check(self):
        self.pending = 0
        now = self._read()
        if now and now != self.last:
            if self.last:  # with nothing to compare to, this is audio coming up at login
                self.osd.show("volume", now[0], now[1])
            self.last = now
        return GLib.SOURCE_REMOVE

    def stop(self):
        self.proc.terminate()


class BrightnessWatcher:
    """The kernel flags actual_brightness on every change, so poll() sleeps until then."""

    def __init__(self, osd):
        self.osd = osd
        self.fd = None
        paths = sorted(glob.glob("/sys/class/backlight/*"))
        if not paths:
            return
        with open(f"{paths[0]}/max_brightness", encoding="ascii") as f:
            self.max = int(f.read()) or 1
        self.fd = os.open(f"{paths[0]}/actual_brightness", os.O_RDONLY)
        self.last = self._read()
        GLib.unix_fd_add_full(
            GLib.PRIORITY_DEFAULT, self.fd, GLib.IOCondition.PRI | GLib.IOCondition.ERR, self._changed, None
        )

    def _read(self):
        os.lseek(self.fd, 0, os.SEEK_SET)
        return int(os.read(self.fd, 32))

    def _changed(self, fd, condition, data):
        now = self._read()
        if os.environ.get("OSD_DEBUG"):
            print(f"brightness event: {now}/{self.max}", flush=True)
        if now != self.last:
            self.last = now
            self.osd.show("brightness", now * 100 / self.max)
        return GLib.SOURCE_CONTINUE


def main():
    osd = Osd()
    if len(sys.argv) >= 4 and sys.argv[1] == "--demo":
        kind, value = sys.argv[2], float(sys.argv[3])
        osd.show("volume" if kind == "muted" else kind, value, kind == "muted")
        GLib.timeout_add(HIDE_AFTER_MS + 200, Gtk.main_quit)
        Gtk.main()
        return

    volume = VolumeWatcher(osd)
    BrightnessWatcher(osd)
    for sig in (signal.SIGINT, signal.SIGTERM):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, Gtk.main_quit)
    try:
        Gtk.main()
    finally:
        volume.stop()


if __name__ == "__main__":
    main()
