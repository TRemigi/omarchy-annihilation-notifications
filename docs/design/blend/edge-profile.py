# Developer tool, not shipped. The shipped ring and body shaders over near-black, light and text backgrounds, printing the luminance profile across the toast edge (a one-second loop for judging the edge).
#   python3 docs/design/blend/edge-profile.py OUT.png ["from=>to" ...]   ("body:from=>to" patches the body shader; needs numpy, pillow, qsb, gcc, Mesa)
import math, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image
ROOT = os.path.abspath(os.path.dirname(__file__) + "/../../.."); OUT = sys.argv[1]
SUBS = [tuple(a.split("=>", 1)) for a in sys.argv[2:] if not a.startswith("body:")]
BSUBS = [tuple(a[5:].split("=>", 1)) for a in sys.argv[2:] if a.startswith("body:")]       # "from=>to" substitutions applied to toastring.frag (a quick experiment without touching the source)
tmp = tempfile.mkdtemp(); QSB = "/usr/lib/qt6/bin/qsb"
def build(name, subs=()):
    src = open(f"{ROOT}/shaders/{name}.frag").read()
    for a, b in subs: assert a in src, a; src = src.replace(a, b)
    open(f"{tmp}/{name}.frag", "w").write(src)
    subprocess.run([QSB, "--glsl", "100 es", "-o", f"{tmp}/{name}.qsb", f"{tmp}/{name}.frag"], check=True)
    subprocess.run([QSB, "-x", "glsl,100 es", "-o", f"{tmp}/{name}.glsl", f"{tmp}/{name}.qsb"], check=True); return f"{tmp}/{name}.glsl"
RING, BODY = build("toastring", SUBS), build("toastbody", BSUBS)
subprocess.run(["gcc", "-O2", f"{ROOT}/test/shader-harness.c", "-o", f"{tmp}/h", "-lEGL", "-lGLESv2"], check=True)
W, H = 960, 420; UI = 1.155; CW, CH = 404 * UI, 92 * UI; CARD = (W / 2 - CW / 2, 120, CW, CH)
def run(g, u):
    env = dict(os.environ, EGL_PLATFORM="surfaceless", LIBGL_ALWAYS_SOFTWARE="1")
    for k, v in u.items(): env["U_" + k] = ",".join(str(x) for x in v) if isinstance(v, (tuple, list)) else str(v)
    subprocess.run([f"{tmp}/h", g, str(W), str(H), f"{tmp}/o.pam"], env=env, check=True, stderr=subprocess.DEVNULL)
    d = open(f"{tmp}/o.pam", "rb").read(); e = d.index(b"ENDHDR\n") + 7
    return np.frombuffer(d[e:], dtype=np.uint8).reshape(H, W, 4).astype(float) / 255.0
def sc(f): return 1 - math.exp(-max(0, f) / 110)
REACH = 84.0; RC = 300; FULL = RC + 309
def frame(bg_rgb, t=2.0, bgarr=None):
    ring = run(RING, dict(seed=5, strength=1.0, reach=REACH, radius=4, time=t, resolution=(W, H), rect0=CARD, rect1=(0,0,0,0), rect2=(0,0,0,0),
        src0=(CARD[0] + CW / 2, CARD[1] + CH / 2, sc(FULL), FULL), src1=(0,0,0,0), src2=(0,0,0,0), ev0=(1.0, 1, 1.0, 0.0), ev1=(0,1,0,0), ev2=(0,1,0,0), shape=(1.04, 1.08, 0.35, 1.0)))[:, :, :3]
    body = run(BODY, dict(urgency=1, vividness=0.75, ui=UI, size=(W, H), card=CARD, shape=(1.04, 1.08, 0.35, 0.0), fill=(38/255, 34/255, 23/255, 0.95)))
    bg = (bgarr / 255.0) if bgarr is not None else np.ones((H, W, 3)) * np.array(bg_rgb) / 255.0
    img = bg + ring
    img = img * (1 - body[:, :, 3:4]) + body[:, :, :3]
    return np.clip(img, 0, 1)
lum = lambda a: 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
def textbg():
    from PIL import ImageDraw, ImageFont
    im = Image.new("RGB", (W, H), (34, 34, 26)); d = ImageDraw.Draw(im); f = ImageFont.truetype(f"{ROOT}/fonts/Jost.ttf", 15)
    import random; random.seed(3)
    words = "git fetch checkout notify-send Signal origin remote Enumerating objects done delta reused pack branch FETCH_HEAD config omarchy plugins annihilation".split()
    for y in range(4, H, 19):
        d.text((8, y), " ".join(random.choice(words) for _ in range(14)), font=f, fill=(185, 180, 150))
    return np.asarray(im).astype(float)
def frame_img(bgarr, t=2.0):
    return frame(None, t, bgarr)
dark, light = frame((14, 16, 18)), frame((200, 200, 205))
txt = frame(None, 2.0, textbg())
cx = int(W / 2); cy = CARD[1] + CH / 2; bottom = int(cy + CH / 2 * 1.2)      # the body's bottom outline at the middle
print("below the toast, luminance (0-255) every 6 px from 12 px inside the outline, flat dark bg 57:", [int(255 * lum(dark)[bottom + k, cx]) for k in range(-12, 140, 6)])
print("same on a light bg 200:", [int(255 * lum(light)[bottom + k, cx]) for k in range(-12, 140, 6)])
im = np.concatenate([dark, light, txt], axis=1)
Image.fromarray((im * 255).astype(np.uint8)).resize((im.shape[1] * 2 // 3, im.shape[0] * 2 // 3)).save(OUT)
