#!/usr/bin/python3
"""Hover to reveal for a waybar on the left screen edge.

Waybar has no auto-hide of its own, so this runs it as a child and tells it when to open:

  reveal.py waybar -c config.jsonc -s style.css

A Wayland program can't ask where the pointer is, so two invisible surfaces sense it:

  edge     a 1 px strip on the left of each screen. Resting on it opens the bar.
  catcher  the whole screen, only while the bar is open. It takes the pointer everywhere
           except the bar, so it sees the pointer leave. Then it swaps to taking the pointer
           only over the bar, so your windows work as usual and it sees the pointer come
           back. If the pointer stays away for CLOSE_DELAY_MS, the bar closes.

An open wofi menu holds the bar, so it can't vanish while you read your options. The wait
starts again when the menu closes.

The edge sits under fullscreen windows, so videos and games never open the bar.
SIGUSR1 to this process opens the bar from the keyboard (sway sends it on a tap of Super).
Opened that way it stays open until the next SIGUSR1.

The calculator, notes and Bitwarden go with the bar on that tap. A tap that closes the bar also
hides whichever of them are on screen, and the next tap that opens it brings them back, with
the one you were in focused again. If one of them is on screen while the bar is closed, the
tap hides it, so one tap always clears everything away. Over a fullscreen window the bar opens
alone, because showing one of them there would end the fullscreen; they come back with a
later tap.
"""
import json
import os
import signal
import subprocess
import sys

import cairo
import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell as Shell  # noqa: E402

BAR_WIDTH = 64  # same as "width" in config.jsonc
OPEN_DELAY_MS = 120  # passing quickly over the edge doesn't open the bar
CLOSE_DELAY_MS = 600  # how long the bar stays after the pointer leaves it
MENU_CHECK_MS = 200  # how often to look again while a menu is holding the bar open
BAR_SETTLE_MS = 200  # waybar has finished opening by then
MONITOR_SETTLE_MS = 500  # a new screen's position arrives just after it appears
MENU = os.environ.get("WOFI", "wofi")  # same variable as ~/.config/wofi/menu, for the tests
APPS = ("calc", "notes", "bw")  # marks sway/includes/window_rules gives the three scratchpad apps

CLOSED, HOVERED, LEAVING, PINNED = range(4)
SENSOR_EVENTS = Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK
ANY_BUTTON = (
    Gdk.ModifierType.BUTTON1_MASK | Gdk.ModifierType.BUTTON2_MASK | Gdk.ModifierType.BUTTON3_MASK
)
ON_BAR = cairo.Region(cairo.RectangleInt(0, 0, BAR_WIDTH, 1 << 15))
OFF_BAR = cairo.Region(cairo.RectangleInt(BAR_WIDTH, 0, 1 << 15, 1 << 15))


def menu_open():
    return subprocess.run(["pgrep", "-x", MENU], stdout=subprocess.DEVNULL).returncode == 0


def sway(*args):
    """swaymsg's reply, or None if sway can't be reached."""
    try:
        done = subprocess.run(["swaymsg", *args], capture_output=True, text=True, timeout=2)
        return json.loads(done.stdout)
    except (OSError, subprocess.SubprocessError, ValueError):
        return None


def nodes(node, workspace=None):
    """Every node in sway's tree, with the workspace it is on."""
    if node.get("type") == "workspace":
        workspace = node
    yield node, workspace
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        yield from nodes(child, workspace)


def apps():
    """The apps on screen (the focused one last), the apps that are open at all, and whether a
    fullscreen window covers the focused workspace."""
    tree = sway("-t", "get_tree")
    if not isinstance(tree, dict):
        return [], set(), False
    everything = list(nodes(tree))
    here = next((ws for node, ws in everything if node.get("focused")), None)
    shown, present, fullscreen = [], set(), False
    for node, ws in everything:
        if node.get("type") not in ("con", "floating_con"):
            continue  # sway reports every workspace as fullscreen_mode 1
        mark = next((m for m in node.get("marks", []) if m in APPS), None)
        if mark:
            present.add(mark)
            if node.get("visible"):
                shown.append((bool(node.get("focused")), mark))
        mode = node.get("fullscreen_mode")
        if mode == 2 or (mode == 1 and ws is here):
            fullscreen = True
    return [mark for _, mark in sorted(shown)], present, fullscreen


class Reveal:
    def __init__(self, command):
        # pdeathsig stops waybar if this process dies, so the bar can't stay hidden with
        # nothing left to open it.
        self.bar = subprocess.Popen(["setpriv", "--pdeathsig", "TERM", *command])
        GLib.child_watch_add(GLib.PRIORITY_DEFAULT, self.bar.pid, lambda *_: Gtk.main_quit())

        self.state = CLOSED
        self.timer = None
        self.put_away = []  # apps a tap hid, brought back by the next tap that opens the bar
        self.edges = []
        self.catchers = []
        self.display = Gdk.Display.get_default()
        for change in ("monitor-added", "monitor-removed"):
            self.display.connect(
                change, lambda *_: GLib.timeout_add(MONITOR_SETTLE_MS, self.build_sensors)
            )
        self.build_sensors()

    def build_sensors(self):
        self.cancel()
        for win in self.edges + self.catchers:
            win.destroy()
        monitors = [self.display.get_monitor(i) for i in range(self.display.get_n_monitors())]
        rects = [monitor.get_geometry() for monitor in monitors]
        # A screen with another one to its left has no wall to push the pointer against,
        # so an edge there would only get in the way of crossing between screens.
        self.edges = [
            self.edge(monitor)
            for monitor, rect in zip(monitors, rects)
            if not any(other.x + other.width == rect.x for other in rects)
        ]
        self.catchers = [self.catcher(monitor) for monitor in monitors]
        self.show_all(self.edges)
        if self.state == HOVERED:
            self.show_all(self.catchers)
        elif self.state == LEAVING:
            self.close()
        return GLib.SOURCE_REMOVE

    def sensor(self, monitor, namespace, layer):
        win = Gtk.Window()
        win.set_visual(win.get_screen().get_rgba_visual())
        win.set_app_paintable(True)
        Shell.init_for_window(win)
        Shell.set_monitor(win, monitor)
        Shell.set_namespace(win, namespace)
        Shell.set_layer(win, layer)
        Shell.set_keyboard_mode(win, Shell.KeyboardMode.NONE)
        Shell.set_exclusive_zone(win, -1)  # ignore other bars' reserved space
        for edge in (Shell.Edge.LEFT, Shell.Edge.TOP, Shell.Edge.BOTTOM):
            Shell.set_anchor(win, edge, True)
        win.add_events(SENSOR_EVENTS)
        return win

    def edge(self, monitor):
        win = self.sensor(monitor, "lab-edge", Shell.Layer.TOP)
        win.set_size_request(1, -1)
        win.connect("enter-notify-event", lambda *_: self.edge_touched())
        win.connect("leave-notify-event", lambda *_: self.edge_left())
        return win

    def catcher(self, monitor):
        win = self.sensor(monitor, "lab-catcher", Shell.Layer.OVERLAY)
        Shell.set_anchor(win, Shell.Edge.RIGHT, True)
        win.input_shape_combine_region(OFF_BAR)
        win.add_events(
            Gdk.EventMask.POINTER_MOTION_MASK
            | Gdk.EventMask.BUTTON_PRESS_MASK
            | Gdk.EventMask.BUTTON_RELEASE_MASK
        )
        # The compositor only moves the pointer off this surface on the next motion after its
        # shape changes, so motion here counts as much as entering it.
        win.connect("enter-notify-event", self.pointer_moved)
        win.connect("motion-notify-event", self.pointer_moved)
        # Hiding a window with a button held would leave GTK waiting for a release that never
        # comes, and it would ignore the pointer from then on. So a click closes on release.
        win.connect("button-press-event", lambda *_: self.cancel())
        win.connect("button-release-event", lambda *_: self.button_released())
        return win

    def watch(self, region):
        for win in self.catchers:
            win.input_shape_combine_region(region)
            win.queue_draw_area(0, 0, 1, 1)  # GTK only sends a new shape along with a redraw

    def pointer_moved(self, _win, event):
        if event.state & ANY_BUTTON:
            return
        on_bar = event.x < BAR_WIDTH
        if self.state == HOVERED and not on_bar:
            self.state = LEAVING
            self.watch(ON_BAR)
            self.after(CLOSE_DELAY_MS, self.wait_over)
        elif self.state == LEAVING and on_bar:
            self.cancel()
            self.state = HOVERED
            self.watch(OFF_BAR)

    def wait_over(self):
        if menu_open():
            self.after(MENU_CHECK_MS, self.check_menu)
        else:
            self.close()

    def check_menu(self):
        if menu_open():
            self.after(MENU_CHECK_MS, self.check_menu)
        else:
            self.after(CLOSE_DELAY_MS, self.wait_over)

    def button_released(self):
        if self.state == LEAVING:
            self.close()

    def show_all(self, windows):
        for win in windows:
            win.show_all()

    def after(self, delay, action):
        self.cancel()
        self.timer = GLib.timeout_add(delay, self.fire, action)

    def fire(self, action):
        self.timer = None
        action()
        return GLib.SOURCE_REMOVE

    def cancel(self):
        if self.timer:
            GLib.source_remove(self.timer)
            self.timer = None

    def edge_touched(self):
        if self.state == CLOSED:
            self.after(OPEN_DELAY_MS, self.hover_open)

    def edge_left(self):
        if self.state == CLOSED:
            self.cancel()

    def open(self, state):
        self.cancel()
        self.state = state
        self.bar.send_signal(signal.SIGUSR1)

    def hover_open(self):
        self.open(HOVERED)
        self.watch(OFF_BAR)
        # Waybar moves up to the overlay layer as it opens. Mapping the catcher after that puts
        # it above the bar, where it has to be to see the pointer come back.
        self.after(BAR_SETTLE_MS, lambda: self.show_all(self.catchers))

    def close(self):
        self.cancel()
        self.state = CLOSED
        self.bar.send_signal(signal.SIGUSR2)
        for win in self.catchers:
            win.hide()

    def toggle(self):
        shown, present, fullscreen = apps()
        if self.state != CLOSED or shown:
            if self.state != CLOSED:
                self.close()
            if shown:
                # The one you were in goes last, so it is focused again when they come back.
                self.put_away = [m for m in self.put_away if m not in shown] + shown
                sway("; ".join(f'[con_mark="{m}"] move scratchpad' for m in shown))
        else:
            self.open(PINNED)
            if not fullscreen:
                back = [m for m in self.put_away if m in present]
                self.put_away = []
                if back:
                    sway("; ".join(f'[con_mark="{m}"] scratchpad show' for m in back))
        return GLib.SOURCE_CONTINUE


if len(sys.argv) < 2:
    sys.exit(__doc__)

reveal = Reveal(sys.argv[1:])
for stop in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, stop, Gtk.main_quit)
GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, reveal.toggle)
Gtk.main()
reveal.bar.terminate()
