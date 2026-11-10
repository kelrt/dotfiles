#!/usr/bin/python3
"""Sends Vesktop the same activity mprisence sends for Audacious and prints what Vesktop answers.
mprisence throws those answers away, which is why nothing shows up in its log.
It shows on your Discord profile for about 30 seconds, then clears itself."""
import glob, json, os, socket, struct, time, uuid
CLIENT = "1125084572166656031"  # the Audacious app id mprisence uses
ICON = "https://upload.wikimedia.org/wikipedia/commons/thumb/3/32/Audacious-2.4-logo.svg/1200px-Audacious-2.4-logo.svg.png"
s = socket.socket(socket.AF_UNIX); s.settimeout(8)
s.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], "discord-ipc-0"))
def send(op, obj):
    p = json.dumps(obj).encode(); s.sendall(struct.pack("<II", op, len(p)) + p)
def recv():
    h = b""
    while len(h) < 8:
        d = s.recv(8 - len(h))
        if not d: return None
        h += d
    op, n = struct.unpack("<II", h); b = b""
    while len(b) < n:
        d = s.recv(n - len(b))
        if not d: return None
        b += d
    return op, json.loads(b)
def answer():
    try:
        r = recv()
    except socket.timeout:
        return "no answer in 8 s"
    if r is None:
        return "Vesktop closed the connection"
    op, body = r
    if op == 2:
        return f"Vesktop closed the connection: {body}"
    if body.get("evt") == "ERROR":
        return f"REJECTED: {body.get('data')}"
    return "accepted"
def activity(image):
    now = int(time.time())
    return {"assets": {"large_image": image, "large_text": "Test album"}, "details": "Test title",
            "state": "Test artist", "status_display_type": 0,
            "timestamps": {"start": now, "end": now + 120}, "type": 2}
def set_activity(a):
    send(1, {"cmd": "SET_ACTIVITY", "args": {"pid": os.getpid(), "activity": a}, "nonce": str(uuid.uuid4())})
    return answer()
send(0, {"v": 1, "client_id": CLIENT})
r = recv()
print("handshake:", "ok" if r and r[1].get("evt") == "READY" else r)
print("with Audacious's icon:", set_activity(activity(ICON)))
print("Look at your Discord profile now: it should say Listening to Audacious, Test title.")
time.sleep(15)
covers = sorted((f for f in glob.glob(os.path.expanduser("~/.cache/mprisence/cover_art/*")) if not f.endswith(".bin")), key=os.path.getmtime)
if covers:
    url = json.load(open(covers[-1]))["url"]
    print("with an uploaded cover:", set_activity(activity(url)))
    print("Look again: same text, with your album cover.")
    time.sleep(15)
print("clearing:", set_activity(None))
send(2, {}); s.close()
