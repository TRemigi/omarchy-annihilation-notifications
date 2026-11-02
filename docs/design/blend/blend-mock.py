# Developer tool, not shipped. Mock-up: four treatments of the toast body over the real arrival ring (shaders/toastring.frag), on a frame of a screen recording.
#   python3 docs/design/blend/blend-mock.py OUT.png BACKGROUND_FRAME.png   (a 1920x1200 frame with no toast; needs numpy, pillow, qsb, gcc and Mesa, as arrival-mock.py)
import math, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.abspath(os.path.dirname(__file__) + "/../../.."); OUT = sys.argv[1]; BG = sys.argv[2]
tmp = tempfile.mkdtemp(); QSB = "/usr/lib/qt6/bin/qsb"
W, H = 760, 300; CARD = (313, 8, 439, 93); RAD = 4
# the ring shader with the card's hiding mask removed (the body decides what covers the glow, not the shader)
src = open(f"{ROOT}/shaders/toastring.frag").read()
a = "    float outside = smoothstep(-2.5, -0.5, sd);\n    if (outside <= 0.0) return vec3(0.0);"; assert a in src
open(f"{tmp}/r.frag", "w").write(src.replace(a, "    float outside = 1.0;"))
subprocess.run([QSB, "--glsl", "100 es", "-o", f"{tmp}/r.qsb", f"{tmp}/r.frag"], check=True)
subprocess.run([QSB, "-x", "glsl,100 es", "-o", f"{tmp}/r.glsl", f"{tmp}/r.qsb"], check=True)
subprocess.run(["gcc", "-O2", f"{ROOT}/test/shader-harness.c", "-o", f"{tmp}/h", "-lEGL", "-lGLESv2"], check=True)
def sc(f): return 1 - math.exp(-max(0, f) / 110)
REACH = 84.0; RC = math.hypot(CARD[2] / 2, CARD[3] / 2) + 30; FULL = RC + 309
def ring(t=2.0, amp=1.0, strength=1.0):
    env = dict(os.environ, EGL_PLATFORM="surfaceless", LIBGL_ALWAYS_SOFTWARE="1")
    u = dict(seed=5, strength=strength, reach=REACH, radius=RAD, time=t, resolution=(W, H), rect0=CARD, rect1=(0,0,0,0), rect2=(0,0,0,0),
             src0=(CARD[0] + CARD[2] / 2, CARD[1] + CARD[3] / 2, sc(FULL), FULL), src1=(0,0,0,0), src2=(0,0,0,0), ev0=(1.0, 1, amp, 0.0), ev1=(0,1,0,0), ev2=(0,1,0,0))
    for k, v in u.items(): env["U_" + k] = ",".join(str(x) for x in v) if isinstance(v, (tuple, list)) else str(v)
    subprocess.run([f"{tmp}/h", f"{tmp}/r.glsl", str(W), str(H), f"{tmp}/o.pam"], env=env, check=True, stderr=subprocess.DEVNULL)
    d = open(f"{tmp}/o.pam", "rb").read(); e = d.index(b"ENDHDR\n") + 7
    return np.frombuffer(d[e:], dtype=np.uint8).reshape(H, W, 4)[:, :, :3].astype(float)
bg = np.asarray(Image.open(BG).convert("RGB").crop((1160, 0, 1160 + W, H))).astype(float)
yy, xx = np.mgrid[0:H, 0:W].astype(float)
cx, cy = CARD[0] + CARD[2] / 2, CARD[1] + CARD[3] / 2
def rsd(radius, shrink=0.0):
    hx, hy = CARD[2] / 2 - shrink, CARD[3] / 2 - shrink
    qx, qy = np.abs(xx - cx) - (hx - radius), np.abs(yy - cy) - (hy - radius)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - radius
def sstep(a, b, x): t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)
TEAL = np.array([51, 196, 208.]); VIO = np.array([112, 117, 250.]); FILL = np.array([27, 22, 17.])
ax_, ay_ = CARD[2] / 2 + 0.55 * REACH, CARD[3] / 2 + 0.8 * REACH
k0 = np.hypot((xx - cx) / ax_, (yy - cy) / ay_)
ringimg = ring()
fa = ImageFont.truetype(f"{ROOT}/fonts/Cinzel.ttf", 13); fj = ImageFont.truetype(f"{ROOT}/fonts/Jost.ttf", 17); fb = ImageFont.truetype(f"{ROOT}/fonts/Jost.ttf", 20)
def text(img, ox, oy, fade=1.0):
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    d.text((ox, oy + 2), "SIGNAL", font=fa, fill=(232, 160, 24)); d.text((ox + 404, oy + 2), "now", font=ImageFont.truetype(f"{ROOT}/fonts/Jost.ttf", 13), fill=(150, 140, 130))
    d.text((ox, oy + 26), "test", font=fj, fill=(245, 242, 236)); d.text((ox, oy + 52), "hello", font=fb, fill=(170, 160, 148))
    return im
def over(base, color, alpha):
    a = alpha[..., None]; return base * (1 - a) + color * a
def rimcol():
    t = np.clip((xx - CARD[0]) / CARD[2], 0, 1)[..., None]; return TEAL * (1 - t) + VIO * t
panels = []
def ovalsd(n, kx, ky):
    # first-order distance to a superellipse centred on the card with semi-axes (kx, ky) times the card's half-size (n = 2 is an ellipse)
    a, b = CARD[2] / 2 * kx, CARD[3] / 2 * ky
    ux, uy = np.abs(xx - cx) / a + 1e-6, np.abs(yy - cy) / b + 1e-6
    g = (ux ** n + uy ** n) ** (1 / n)
    gx = g ** (1 - n) * ux ** (n - 1) / a; gy = g ** (1 - n) * uy ** (n - 1) / b
    return (g - 1) / np.hypot(gx, gy)
def body(label, sd, textx=14, rim=0.16):
    img = bg + ringimg
    img = over(img, FILL, 0.95 * (1 - sstep(-16, 10, sd)))      # A's feather: 26 px, unchanged
    img = img + rimcol() * (np.exp(-((sd + 4) / 9) ** 2) * rim)[..., None]
    panels.append((label, text(img, CARD[0] + textx, CARD[1] + 11)))
body("A as chosen: the card, 26 px feather", rsd(RAD + 6))
body("O1 ellipse: 1.30 x 1.35 of the card (570 x 126 px)", ovalsd(2, 1.30, 1.35))
body("O2 superellipse n=3: 1.12 x 1.20 (492 x 112 px)", ovalsd(3, 1.12, 1.20))
body("O3 superellipse n=4: 1.06 x 1.14 (465 x 106 px)", ovalsd(4, 1.06, 1.14))
sheet = Image.new("RGB", (W * 2, H * 2))
for i, (lab, im) in enumerate(panels):
    ImageDraw.Draw(im).text((8, H - 20), lab, fill=(255, 255, 255), font=ImageFont.truetype(f"{ROOT}/fonts/Jost.ttf", 15)); sheet.paste(im, ((i % 2) * W, (i // 2) * H))
sheet.save(OUT)
