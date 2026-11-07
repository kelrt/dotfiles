# Copies the lab with every click action removed: bar buttons run real scripts even in the test sway.
import json, os, re, shutil, sys
scr = sys.argv[1]
src = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
dst = os.path.join(scr, "lab")
shutil.rmtree(dst, ignore_errors=True)
shutil.copytree(src, dst, ignore=shutil.ignore_patterns("previews", "test", "__pycache__"))
p = os.path.join(dst, "side", "config.jsonc")
text = open(p, encoding="utf8").read()
text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
text = re.sub(r"\s*// BAR_WIDTH.*$", "", text, flags=re.M)
c = json.loads(text)
removed = 0
for name, block in list(c.items()):
    if isinstance(block, dict):
        for key in [k for k in block if k.startswith("on-") or k == "actions"]:
            # These only talk to sway, and in the test that's the private sway.
            if not name.startswith("image#") and name != "custom/scratchpad":
                del block[key]; removed += 1
# The power button opens a harmless two-row menu through the real wrapper.
c["custom/power"]["on-click"] = (
    "printf 'one\\ntwo\\n' | WOFI=twofi ~/.config/wofi/menu --dmenu --hide-search --lines 2"
    " --width 220 --cache-file /dev/null > " + os.path.join(scr, "run", "menu.out")
)
# These two act on click by themselves, with no on-click key to remove.
for real, stand_in in (("power-profiles-daemon", ""), ("inhibitor", "")):
    fake = "custom/stand-in-" + real
    home = c["group/drawer"]["modules"]
    home[home.index(real)] = fake
    c[fake] = {"format": stand_in, "tooltip": False}
    del c[real]
css = os.path.join(dst, "side", "style.css")
s = open(css).read().replace("#power-profiles-daemon", "#custom-stand-in-power-profiles-daemon").replace("#inhibitor", "#custom-stand-in-inhibitor")
open(css, "w").write(s)
json.dump(c, open(p, "w", encoding="utf8"), indent=1)
left = [(n, k) for n, b in c.items() if isinstance(b, dict) for k in b if k.startswith("on-")]
print("removed", removed, "actions; click actions left:", left)
print("built-in click modules left:", [m for m in c["group/drawer"]["modules"] if m in ("power-profiles-daemon", "inhibitor", "pulseaudio", "backlight", "battery", "tray")])
