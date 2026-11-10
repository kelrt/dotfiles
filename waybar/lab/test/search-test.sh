# Which app wofi puts first for what you type. Run it through ./go search.
# It uses copies of your app entries whose Exec only writes down the app's name, so Return is
# safe, and a copy of your launch counts, so the order is the one you get.
T=$OUT/run; rm -rf $T; mkdir -p $T/data/applications $T/share; cd $T
R=$T/results.txt
say() { echo "$*" >> $R; }
check() { if [ "$2" = "$3" ]; then say "PASS  $1"; else say "FAIL  $1  (got '$2', want '$3')"; fi; }
kbd() { echo "$*" >&8; }
M=$HOME/.config/wofi/menu
# GTK still needs everything else in /usr/share to draw anything, just not the app entries.
for d in /usr/share/*; do [ "${d##*/}" = applications ] || ln -s "$d" share/; done
export WOFI=twofi XDG_DATA_HOME=$T/data XDG_DATA_DIRS=$T/share

printf '#!/bin/sh\necho "$1" >> %s/chosen\n' "$T" > stub; chmod +x stub
for dir in /usr/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/applications; do
    for f in "$dir"/*.desktop; do
        name=${f##*/}
        sed -E "s|^Exec=.*|Exec=$T/stub $name|; /^(TryExec|DBusActivatable)=/d" "$f" > data/applications/"$name"
    done
done
sed -E "s|^([0-9]+) .*/|\1 $T/data/applications/|" $HOME/.cache/wofi-drun > cache.orig

mkfifo key; python3 $H/vkbd.py < key > vkbd.log 2>&1 & KB=$!
exec 8>key
sleep .6

pick() {  # pick <text>: prints the entry Return launches
    cp cache.orig cache; : > chosen
    $M --show drun --sort-order alphabetical --cache-file $T/cache 2>/dev/null &
    sleep .8; kbd "text $1"; sleep $(echo "${#1} * .06 + .3" | bc); grim -g "660,362 600x476" "${1// /_}.png"
    kbd return; sleep .35
    [ -s chosen ] && sed 's/\.desktop$//' chosen || { kbd esc; sleep .2; echo nothing; }
}

say "--- the app you mean comes first"
while read -r want text; do check "'$text' finds $want" "$(pick "$text")" "$want"; done <<X
thunar t
thunar th
thunar thu
thunar thunar
thunar thunar f
thunar thunar fil
thunar thunar file manager
thunar thunar man
org.mozilla.firefox fir
org.mozilla.firefox fire
com.spotify.Client sp
steam st
com.bitwarden.desktop bi
io.missioncenter.MissionCenter mi
audacious au
audacious auda
audacity audacit
com.todoist.Todoist to
vesktop ve
wechat we
google-chrome chr
librewolf li
com.microsoft.VSCode vis
com.microsoft.VSCode code
com.microsoft.VSCode visual code
net.ankiweb.Anki an
foot fo
X

say "--- what name-only search gives up"
for text in fi ch vs browser music discord; do say "note: '$text' gives $(pick "$text")"; done
kill $KB
swaymsg -q exit
