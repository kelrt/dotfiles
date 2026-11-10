Waybar lab: bars to try, the volume/brightness popup and the tests.
Your main bar is one level up: ~/.config/waybar/config.jsonc, style.css and reveal.py.
It still uses two folders here, so keep them: shared/ (its button scripts, lab.css, the crab
pictures) and osd/ (the popup, which sway starts). If you delete those, the bar's buttons and
the popup go with them.

TRY ONE
  ~/.config/waybar/lab/try quick
  ~/.config/waybar/lab/try power
  ~/.config/waybar/lab/try dock
  ~/.config/waybar/lab/try old       your previous main bar
  ~/.config/waybar/lab/try osd       the popup alone
Run it from a terminal. It appears alongside your main bar. Ctrl+C stops it.
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
  old     Your previous main bar, on the right. It only picks up a new wallpaper's colours
          when it starts, and its mpris module has crashed waybar before (audit finding F7).

THE MAIN BAR
  On the left, hidden until you rest the pointer on the screen edge for a moment. It closes
  0.6 s after the pointer leaves, and waits while a wofi menu is open. Under the workspaces are
  the calculator, notes and Bitwarden: a click does the same as $mod+c, $mod+n and $mod+b, which
  start the app first if it isn't running (after a crash, say), and a right click restarts it. A
  scratchpad icon appears below them only when something else is in the scratchpad. The Rust
  reminder is the crab below the clock: black on red until the day's lines are done, then faint
  orange. Hover the clock for the calendar: left click for the previous month, right click for
  the next.
  A music note sits below the crab while something is playing, dimmed while it is paused,
  and it is gone once the player stops or closes. Click it to play or pause, right-click for
  the next song, middle-click for the previous one; scrolling on it skips too. It controls the
  player you used last. Hover the sliders icon near the bottom for a drawer with the tray; it
  closes when the pointer leaves. Wi-Fi and Bluetooth are nm-applet's and blueman's icons in
  that tray. Click the dots at the top of that drawer for everything else: VPN, sound, power profile, charge limit,
  keep awake, wallpaper, maintenance, Claude and the power menu. The dots stay open until you
  click them again, even after the bar closes. Click sound
  for pavucontrol, right-click it to mute, scroll on it for volume. The clock and crab slide up a
  little while the dots are open, because that drawer needs the room.

  It stays out of fullscreen windows: the edge does nothing there, so videos and games are
  safe. After the pointer leaves, the bar waits about half a second so you can come back to it,
  and your windows work normally during the wait. An open wofi menu holds the bar, and the wait
  starts again when the menu closes. While the bar is hidden you can't see the
  clock, battery or Rust reminder, so a tap on Super opens it: press and let go of Super with no
  other key. The lines are at the end of ~/.config/sway/includes/keybinds, one per real keyboard.
  fcitx5's own keyboard is left out on purpose, or every Super+key shortcut would toggle the bar.
  A new keyboard needs its own line. Letting go of Super after a Super+mouse drag also toggles it.
  Opened that way it stays open until you tap Super again, even over fullscreen.
  The calculator, notes and Bitwarden go with it. A tap that closes the bar also hides any of
  them that are on screen, and the next tap brings them back, with the one you were in focused.
  If one of them is on screen while the bar is closed, a tap hides it, so one tap always clears
  everything away. Over a fullscreen window the bar opens alone, so the window stays
  fullscreen; they come back with a later tap. $mod+c, $mod+n and $mod+b still show or hide
  each one on its own, and the bar's hover closing never hides them.
  Change the feel at the top of reveal.py: CLOSE_DELAY_MS is the wait. The slides are near the
  top of style.css: the window#waybar > box rule opens, the .mode-invisible rule closes.

BUTTONS THAT REALLY DO SOMETHING
  Scales icon       Power profile. Click to cycle power-saver, balanced, performance.
                    On battery, balanced also saves more power by itself.
  Battery + 100%    Charge limit. A click tells UPower to stop charging early (the tooltip
                    shows where), which is kinder to a battery that stays plugged in. It
                    stays on until you click again, even after a reboot, so check it before
                    a day away from power.
  Eye icon          Keep awake. No screen lock, screen-off or sleep from idling until you click
                    again, like the systemd-inhibit you used for the overnight run. It runs
                    ../scripts/keep-awake, so unplugging a screen or restarting the bar doesn't
                    break or end it; logging out does.

CHANGING THE MAIN BAR
  style.css reloads by itself. After changing config.jsonc or reveal.py, restart the bar:
    pkill -f '^python3 .*/reveal\.py'
    swaymsg exec 'python3 ~/.config/waybar/reveal.py waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css'
  The same second line brings it back if it ever stops. To read its log instead, run
  ~/.config/waybar/lab/try side from a terminal.
  Sway starts it from a plain exec line in ~/.config/sway/config, because swaybar_command can't
  take arguments. To use another bar, change that line to one of these, run sway -C, and it
  takes effect at your next login:
    exec waybar -c ~/.config/waybar/lab/old/config.jsonc -s ~/.config/waybar/lab/old/style.css
    exec waybar -c ~/.config/waybar/lab/quick/config.jsonc -s ~/.config/waybar/lab/quick/style.css

GOOD TO KNOW
  - Colours are read from ~/.config/waybar/colors.css, so these follow your wallpaper.
  - The music note runs ~/.config/waybar/scripts/music, a separate process instead of
    waybar's mpris module, so it can't crash the bar (audit finding F7). The script follows
    the players themselves: playerctld stays on the bus after the last player quits, so
    following it kept the last song showing. The clicks go through playerctld (-p playerctld),
    which acts on the player you used last; plain playerctl takes the first one it finds,
    which can be a browser tab.
  - Icons are Font Awesome 6, which is what you have installed.
  - Your backup button includes this folder, because it mirrors all of ~/.config/waybar.
  - test/go checks the main bar's hover behaviour in a private, invisible sway. Run it after
    changing config.jsonc or reveal.py. test/go tray does the same for tray menus, test/go popup
    for osd/osd.py, test/go menu for ~/.config/wofi/menu, test/go battery for power saver at
    20%, test/go search for what wofi puts first, test/go notify for ~/.config/dunst/dunstrc, and
    test/go crab for the crab's colours, test/go scratch for $mod+minus, test/go music for
    when the music note shows, test/go scratchapp for the three app buttons and keys, and
    test/go keepawake for the keep-awake button.
