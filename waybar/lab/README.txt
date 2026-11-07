Waybar lab: four bars to try, plus a volume/brightness popup.
Nothing here changes your normal bar. Sway has two lines pointing here: the $mod+x shortcut
and the popup. If you delete this folder, the popup goes with it.

TRY ONE
  ~/.config/waybar/lab/try quick
  ~/.config/waybar/lab/try power
  ~/.config/waybar/lab/try dock
  ~/.config/waybar/lab/try side
  ~/.config/waybar/lab/try osd       the popup alone
Run it from a terminal. It appears alongside your normal bar. Ctrl+C stops it.
The bars also start the popup, unless it's already running, so press your volume or
brightness keys.
Pictures of each are in previews/.

THE BARS
  quick   Top bar, like other desktops ship. Hover sound, light or battery to slide out
          controls. Shows when your mic or screen is being captured, failed services,
          a reboot reminder, and the music title.
  power   Bottom instrument panel. Live battery watts and time left, CPU power (works on
          AC too), temperature, fan, memory, Wi-Fi signal. Hover the battery for health
          and stats since you unplugged. Use it for a day to see what drains the battery.
  dock    Floating centered dock with an icon per open app. Click to focus, middle-click
          to close.
  side    A full bar on the left, hidden until you rest the pointer on the screen edge for a
          moment. It closes just under a second after the pointer leaves. Under the workspaces
          are the calculator, notes and Bitwarden: a click does the same as $mod+c, $mod+n and
          $mod+b. A scratchpad icon appears below them only when something else is in the
          scratchpad. The Rust reminder is the crab below the clock: outlined in red until
          the day's lines are done, then dimmed. The sliders icon near the bottom opens a
          drawer with everything else: your current bar's buttons (Claude, wallpaper,
          maintenance, VPN), tray, network, power menu and more. The clock and crab slide up
          while it's open, because the drawer needs the room. Hover sound or brightness in
          there for a slider. Right-click sound for pavucontrol. Scroll on the music note to
          skip tracks.

THE SIDE BAR
  It stays out of fullscreen windows: the edge does nothing there, so videos and games are
  safe. After the pointer leaves, the bar waits just under a second so you can come back to it,
  and your windows work normally during the wait. While the bar is hidden you can't see the
  clock, battery or Rust reminder, so $mod+x opens it. That line lives in
  ~/.config/sway/includes/keybinds and does nothing unless the side bar is running:
    bindsym $mod+x exec pkill -USR1 -f 'python3 .*side/reveal\.py'
  Opened that way it stays open until you press the keys again, even over fullscreen.
  Change the feel at the top of side/reveal.py: CLOSE_DELAY_MS is the wait. The slide is at
  the top of side/style.css.

BUTTONS THAT REALLY DO SOMETHING
  Scales icon       Power profile. Click to cycle power-saver, balanced, performance.
                    On battery, balanced also saves more power by itself.
  Battery + 100%    Charge limit. A click tells UPower to stop charging early (the tooltip
                    shows where), which is kinder to a battery that stays plugged in. It
                    stays on until you click again, even after a reboot, so check it before
                    a day away from power.
  Eye icon          Keep awake. Blocks idle and sleep until you click again, like the
                    systemd-inhibit you used for the overnight run.

KEEPING SOMETHING YOU LIKE
  The popup already starts at login and runs whichever bar is up, from this line in
  ~/.config/sway/config:
    exec python3 ~/.config/waybar/lab/osd/osd.py
  A bar as your main bar: swaybar_command can't take arguments (sway then starts no bar at
  all), so delete the whole bar { } block from ~/.config/sway/config and add one of these:
    exec waybar -c ~/.config/waybar/lab/quick/config.jsonc -s ~/.config/waybar/lab/quick/style.css
    exec python3 ~/.config/waybar/lab/side/reveal.py waybar -c ~/.config/waybar/lab/side/config.jsonc -s ~/.config/waybar/lab/side/style.css
  Run sway -C first. It takes effect at your next login.
  Or copy just the modules you like into your own config.jsonc.

GOOD TO KNOW
  - Colours are read from ~/.config/waybar/colors.css, so these follow your wallpaper.
  - The music display uses playerctl in a separate process instead of waybar's mpris
    module, so it can't crash the bar (audit finding F7).
  - Icons are Font Awesome 6, which is what you have installed.
  - Your backup button includes this folder, because it mirrors all of ~/.config/waybar.
  - test/go checks the side bar's hover behaviour in a private, invisible sway. Run it
    after changing side/reveal.py. test/go popup does the same for osd/osd.py, test/go menu
    for ~/.config/wofi/menu, and test/go battery for power saver at 20%.
