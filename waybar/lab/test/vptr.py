#!/usr/bin/env python3
"""Virtual pointer for a PRIVATE test compositor. Pure Wayland wire protocol, no dependencies.
Reads lines from stdin: 'abs X Y', 'click left|right|middle', 'scroll N'."""
import os, socket, struct, sys, time
W, H = int(os.environ.get("VW", 1920)), int(os.environ.get("VH", 1200))
if os.environ.get("WLR_BACKENDS") != "headless" or "SWAYSOCK" not in os.environ:
    sys.exit("refusing: only runs inside the private test sway")
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ["WAYLAND_DISPLAY"]))
nid = [1]
def new():
    nid[0] += 1
    return nid[0]
def send(obj, op, body=b""):
    s.sendall(struct.pack("<IHH", obj, op, 8 + len(body)) + body)
def wstr(t):
    b = t.encode() + b"\0"
    return struct.pack("<I", len(b)) + b + b"\0" * (-len(b) % 4)
reg, cb = new(), new()
send(1, 1, struct.pack("<I", reg))
send(1, 0, struct.pack("<I", cb))
buf, globs, done = b"", {}, False
while not done:
    buf += s.recv(65536)
    while len(buf) >= 8:
        obj, op, size = struct.unpack("<IHH", buf[:8])
        if len(buf) < size:
            break
        body, buf = buf[8:size], buf[size:]
        if obj == reg and op == 0:
            name, n = struct.unpack("<II", body[:8])
            globs[body[8:8 + n - 1].decode()] = name
        elif obj == cb:
            done = True
g = "zwlr_virtual_pointer_manager_v1"
mgr = new()
send(reg, 0, struct.pack("<I", globs[g]) + wstr(g) + struct.pack("<II", 1, mgr))
vp = new()
send(mgr, 0, struct.pack("<II", 0, vp))
ms = lambda: int(time.monotonic() * 1000) & 0xffffffff
for line in sys.stdin:
    p = line.split()
    if not p or (p[0] == "abs" and len(p) != 3):
        print("ignored:", line.strip(), flush=True)
        continue
    if p[0] == "size":
        W, H = int(p[1]), int(p[2])
    elif p[0] == "abs":
        send(vp, 1, struct.pack("<IIIII", ms(), int(p[1]), int(p[2]), W, H)); send(vp, 4)
    elif p[0] == "click":
        b = {"left": 272, "right": 273, "middle": 274}[p[1]]
        send(vp, 2, struct.pack("<III", ms(), b, 1)); send(vp, 4)
        time.sleep(0.05)
        send(vp, 2, struct.pack("<III", ms(), b, 0)); send(vp, 4)
    elif p[0] in ("down", "up"):
        send(vp, 2, struct.pack("<III", ms(), {"left": 272}[p[1]], p[0] == "down")); send(vp, 4)
    elif p[0] == "scroll":
        send(vp, 3, struct.pack("<IIi", ms(), 0, int(p[1]) * 256)); send(vp, 4)
