# Info


### System:
- Hyprland
- NixOS 25.05
- Waybar
- Rofi-wayland
- Thinkpad T480

I use pywall for themeing my system. The terminal and waybar are the only things that pull colors from it's cache though. I did not want things changing too much with the wallpapers.

Clicking on the gallery icon in the waybar opens a rofi window where you can select an image from the defined wallpaper folder. It is powered by Hyprpaper. The colors change immediately along with the wallpaper. (probably wont upload my wallpapers folder as some are slightly sketch and this repo is public lol)
![wallpaper picker](nix_dots/assets/nitch.png)

I use cmus for my music playing needs. I got the config from u/imnitwit a while back. Here is the original [post](https://www.reddit.com/r/cmus/comments/ghw9m0/i_made_a_cmus_theme/).
![cmus display](/assets/cmus.png)
![cmus displaytest](https://github.com/kelrt/dotfiles/blob/master/nix_dots/assets/cmus.png)

This is my rofi launcher.
![rofi launcher](/assets/rofi.png)

>I do not use home manager. I am happy with my hierarchy at the moment and dont plan on implementing it anytime soon.

>The contents of ~/.config that i care about are periodically backed up to /z_backups. (manually)

>Any programs that i have configured via nix are contained inside the /programs directory.



I have a near endless todo list that i have set aside for now so that i can achieve some semblance of productivity, but here are some of the main things i need to get around to when i have a surplus of time:

- ftLoG..implement something to stop all audio playback when BT/3.5mm is disconnected. essential for...reasons
- theme rofi windows with pywal (power menu and wallpicker)
- i *think* there is a bug with the waybar tray module when mullvad is connected...
- theme dolphin and/or switch to thunar
- get the nm-applet css working properly
- make sure the laptop battery dies gracefully
- implement some sort of fan control software
- cpu undervolting when off charger
- fcitx5 setup for typing in chinese. (bind to f11 key?)
- color palette previews inside the wallpicker rofi menu? i think this isnt possible with rofi
- controller / bluetooth support
- change pgup/pgdn into media skip/replay binds
- setup shells for development and cyber
    - kali packages shell
    - rust shell
    - python shell
    - flutter shell
- need a waybar widget for power profile
- bluetooth widget also necesary now
 
*Current daily driver is Fedora/KDE*
