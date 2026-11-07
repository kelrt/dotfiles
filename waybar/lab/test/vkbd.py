#!/usr/bin/env python3
"""Virtual keyboard for a PRIVATE test compositor. Reads lines: 'mod4+d', 'esc', 'text abc'."""
import array, ctypes, os, socket, struct, sys, time
if os.environ.get("WLR_BACKENDS") != "headless" or "SWAYSOCK" not in os.environ:
    sys.exit("refusing: only runs inside the private test sway")
x = ctypes.CDLL("libxkbcommon.so.0")
x.xkb_context_new.restype = ctypes.c_void_p
x.xkb_keymap_new_from_names.restype = ctypes.c_void_p
x.xkb_keymap_new_from_names.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int]
x.xkb_keymap_get_as_string.restype = ctypes.c_char_p
x.xkb_keymap_get_as_string.argtypes = [ctypes.c_void_p, ctypes.c_int]
text = x.xkb_keymap_get_as_string(x.xkb_keymap_new_from_names(x.xkb_context_new(0), None, 0), 1) + b"\0"
fd = os.memfd_create("keymap"); os.write(fd, text)
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ["WAYLAND_DISPLAY"]))
nid = [1]
def new():
    nid[0] += 1
    return nid[0]
def send(obj, op, body=b"", fds=None):
    m = struct.pack("<IHH", obj, op, 8 + len(body)) + body
    if fds:
        s.sendmsg([m], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", fds))])
    else:
        s.sendall(m)
def wstr(t):
    b = t.encode() + b"\0"
    return struct.pack("<I", len(b)) + b + b"\0" * (-len(b) % 4)
reg, cb = new(), new()
send(1, 1, struct.pack("<I", reg)); send(1, 0, struct.pack("<I", cb))
buf, globs, done = b"", {}, False
while not done:
    buf += s.recv(65536)
    while len(buf) >= 8:
        obj, op, size = struct.unpack("<IHH", buf[:8])
        if len(buf) < size: break
        body, buf = buf[8:size], buf[size:]
        if obj == reg and op == 0:
            name, n = struct.unpack("<II", body[:8]); globs[body[8:8 + n - 1].decode()] = name
        elif obj == cb: done = True
seat = new(); send(reg, 0, struct.pack("<I", globs["wl_seat"]) + wstr("wl_seat") + struct.pack("<II", 1, seat))
g = "zwp_virtual_keyboard_manager_v1"
mgr = new(); send(reg, 0, struct.pack("<I", globs[g]) + wstr(g) + struct.pack("<II", 1, mgr))
kb = new(); send(mgr, 0, struct.pack("<II", seat, kb))
send(kb, 0, struct.pack("<II", 1, len(text)), [fd])
time.sleep(.3)
ms = lambda: int(time.monotonic() * 1000) & 0xffffffff
KEYS = {"d": 32, "esc": 1, "a": 30, "f": 33, "i": 23, "r": 19, "down": 108, "up": 103, "return": 28}
def key(code, down): send(kb, 1, struct.pack("<III", ms(), code, 1 if down else 0))
def mods(m): send(kb, 2, struct.pack("<IIII", m, 0, 0, 0))
print("ready", flush=True)
for line in sys.stdin:
    p = line.strip()
    if p.startswith("mod4+"):
        key(125, True); mods(0x40); time.sleep(.03)
        c = KEYS[p[5:]]; key(c, True); time.sleep(.05); key(c, False); time.sleep(.03)
        mods(0); key(125, False)
    elif p in KEYS:
        key(KEYS[p], True); time.sleep(.05); key(KEYS[p], False)
