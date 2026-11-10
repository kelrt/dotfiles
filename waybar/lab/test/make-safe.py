# Copies the bar and the lab with every click action removed: bar buttons run real scripts even in
# the test sway. BAR_SRC tries out a copy of the bar's three files instead of the real ones.
import json, os, re, shutil, sys
scr = sys.argv[1]
src = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
main = os.environ.get("BAR_SRC") or os.path.dirname(src)
dst = os.path.join(scr, "lab")
shutil.rmtree(dst, ignore_errors=True)
shutil.copytree(src, dst, ignore=shutil.ignore_patterns("previews", "test", "__pycache__", "side"))
for name in ("config.jsonc", "style.css", "reveal.py"):
    shutil.copy(os.path.join(main, name), os.path.join(scr, name))
p = os.path.join(scr, "config.jsonc")
text = open(p, encoding="utf8").read()
text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
text = re.sub(r"\s*// BAR_WIDTH.*$", "", text, flags=re.M)
c = json.loads(text)
removed = 0
for name, block in list(c.items()):
    if isinstance(block, dict):
        for key in [k for k in block if k.startswith("on-") or k == "actions"]:
            # These only talk to the private sway, turn the calendar's page, or do nothing.
            if not name.startswith("image#") and name not in ("custom/scratchpad", "clock", "custom/more"):
                del block[key]; removed += 1
# The app buttons run sway/scripts/scratch-app. A click only shows or hides the test windows, and
# SCRATCH_APP_DRY stops it starting a real app if one is missing; a right click would restart one.
for name in [n for n in c if n.startswith("image#")]:
    if c[name].pop("on-click-right", None) is not None:
        removed += 1
    if "scratch-app" in c[name].get("on-click", ""):
        c[name]["on-click"] = "SCRATCH_APP_DRY=1 " + c[name]["on-click"]
# The power button opens a harmless two-row menu through the real wrapper.
c["custom/power"]["on-click"] = (
    "printf 'one\\ntwo\\n' | WOFI=twofi ~/.config/wofi/menu --dmenu --hide-search --lines 2"
    " --width 220 --cache-file /dev/null > " + os.path.join(scr, "run", "menu.out")
)
# Tooltips on the two drawer buttons would drift into the screenshots of the rows.
for m in ("custom/drawer-toggle", "custom/more"):
    c[m]["tooltip"] = False
# Clicks on the sound button only leave a mark.
for key, mark in (("on-click", "sound-settings"), ("on-click-right", "sound-mute")):
    c["pulseaudio"][key] = "touch " + os.path.join(scr, "run", mark)
# These two act on click by themselves, with no on-click key to remove.
for real, stand_in in (("power-profiles-daemon", ""),):
    fake = "custom/stand-in-" + real
    home = c["group/more"]["modules"]
    home[home.index(real)] = fake
    c[fake] = {"format": stand_in, "tooltip": False}
    del c[real]
css = os.path.join(scr, "style.css")
s = open(css).read().replace("#power-profiles-daemon", "#custom-stand-in-power-profiles-daemon").replace("#inhibitor", "#custom-stand-in-inhibitor")
open(css, "w").write(s)
json.dump(c, open(p, "w", encoding="utf8"), indent=1)
left = [(n, k) for n, b in c.items() if isinstance(b, dict) for k in b if k.startswith("on-")]
print("removed", removed, "actions; click actions left:", left)
print("built-in click modules left:", [m for m in c["group/more"]["modules"] + c["group/drawer"]["modules"] if m in ("power-profiles-daemon", "inhibitor", "pulseaudio", "backlight", "battery", "tray")])
