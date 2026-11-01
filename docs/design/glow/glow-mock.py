#!/usr/bin/env python3
# Mock-ups of toasts lit by the same light as the theme's window glow. Developer tool, not shipped.
#   python3 docs/design/glow/glow-mock.py OUTDIR [seed] [time]
# Needs numpy and pillow, qsb (qt6-shadertools), gcc and Mesa's software GL (see test/shader-harness.c).
# The windows are lit by the theme's real windowglow.frag (only the two lines that map a pixel to the screen are changed, so a
# crop of the screen can be rendered); the toasts by glow-mock.frag, which reuses that shader's colour field and band profile.
# The scene is a 1880x1190 screen with a bar, and the toasts sit where Omarchy puts them (gapsOut from the right, below the bar).
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(HERE + "/../../..")
THEME = os.path.expanduser("~/dev/omarchy-annihilation-theme/extras/plugin/annihilation.shimmer")
OUT = sys.argv[1]; SEED = float(sys.argv[2]) if len(sys.argv) > 2 else 53.0; TIME = float(sys.argv[3]) if len(sys.argv) > 3 else 40.0
os.makedirs(OUT, exist_ok=True)
S = 2
SCREEN = (1880, 1190)
tmp = tempfile.mkdtemp()
QSB = "/usr/lib/qt6/bin/qsb"

def build(src_text, name):
    f = f"{tmp}/{name}.frag"; open(f, "w").write(src_text)
    subprocess.run([QSB, "--glsl", "100 es", "-o", f"{tmp}/{name}.qsb", f], check=True)
    subprocess.run([QSB, "-x", "glsl,100 es", "-o", f"{tmp}/{name}.glsl", f"{tmp}/{name}.qsb"], check=True)
    return f"{tmp}/{name}.glsl"

harness = tmp + "/harness"
subprocess.run(["gcc", "-O2", ROOT + "/test/shader-harness.c", "-o", harness, "-lEGL", "-lGLESv2"], check=True)

wg = open(THEME + "/shaders/windowglow.frag").read()
wg = wg.replace("    vec4 win5;\n} ubuf;", "    vec4 win5;\n    vec2 origin;\n    vec2 cropSize;\n} ubuf;")
wg = wg.replace("vec2 uv = qt_TexCoord0;\n    vec2 px = uv * ubuf.resolution;",
                "vec2 uv = (ubuf.origin + qt_TexCoord0 * ubuf.cropSize) / ubuf.resolution;\n    vec2 px = uv * ubuf.resolution;")
assert "ubuf.origin" in wg
WINDOW_GLSL = build(wg, "windowglow")
MOCK_GLSL = build(open(HERE + "/glow-mock.frag").read(), "glowmock")
RIM_GLSL = f"{tmp}/toastrim.glsl"
subprocess.run([QSB, "-x", "glsl,100 es", "-o", RIM_GLSL, ROOT + "/shaders/toastrim.frag.qsb"], check=True)

def render(glsl, w, h, **u):
    env = dict(os.environ, EGL_PLATFORM="surfaceless", LIBGL_ALWAYS_SOFTWARE="1")
    for k, v in u.items():
        env["U_" + k] = ",".join(str(x) for x in v) if isinstance(v, (tuple, list)) else str(v)
    pam = tmp + "/o.pam"
    subprocess.run([harness, glsl, str(w), str(h), pam], env=env, check=True, stderr=subprocess.DEVNULL)
    raw = open(pam, "rb").read(); e = raw.index(b"ENDHDR\n") + 7
    return np.frombuffer(raw[e:], np.uint8).reshape(h, w, 4).astype(np.float32) / 255.0

def over(img, layer):               # premultiplied light/body over img
    return np.clip(layer[..., :3] + img * (1 - layer[..., 3:4]), 0, 1)

# ---------------------------------------------------------------- the scene
TOAST_DEPTH = float(os.environ.get('TDEPTH', 0.13))
RIM = max(16, min(44, SCREEN[1] * 0.026)); ROUND = 4; INTENSITY = 0.44
WIN = (940, 44, 930, 1136)          # the window the toasts sit over (x, y, w, h); right edge = screen - gapsOut
BAR = 34
FONTS = THEME + "/fonts/"
def font(name, px, wght):
    f = ImageFont.truetype(FONTS + name, int(round(px * S)))
    try: f.set_variation_by_axes([wght])
    except Exception: pass
    return f

def scene(x0, y0, cw, ch):
    W, H = cw * S, ch * S
    YY, XX = np.mgrid[0:H, 0:W].astype(np.float32); XX = XX / S + x0; YY = YY / S + y0
    img = np.zeros((H, W, 3), np.float32) + np.array([19, 17, 12], np.float32) / 255
    def blob(cx, cy, r, col, a):
        g = np.exp(-(((XX - cx) ** 2 + (YY - cy) ** 2) / (r * r)))
        return g[..., None] * np.array(col, np.float32) / 255 * a
    img += blob(1790, 150, 360, (40, 120, 120), 0.20) + blob(1480, 380, 300, (70, 60, 140), 0.14) + blob(1700, 560, 240, (40, 100, 90), 0.10)
    img[YY < BAR] = np.array([12, 11, 8], np.float32) / 255
    # the window
    wx, wy, ww, wh = WIN
    qx = np.abs(XX - (wx + ww / 2)) - (ww / 2 - ROUND); qy = np.abs(YY - (wy + wh / 2)) - (wh / 2 - ROUND)
    d = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - ROUND
    a = np.clip(0.5 - d * S * 0.5, 0, 1)[..., None]
    img = img * (1 - a) + np.array([24, 22, 15], np.float32) / 255 * a
    # text bars, as in the other mock-ups
    rng = np.random.default_rng(5); im = Image.new("L", (W, H), 0); dr = ImageDraw.Draw(im)
    y = 66
    while y < 1000:
        x = wx + 22 + int(rng.integers(0, 3)) * 6
        for _ in range(int(rng.integers(2, 6))):
            wlen = int(rng.integers(30, 260)); a_ = float(rng.uniform(0.5, 1.0))
            dr.rectangle([(x - x0) * S, (y - y0) * S, (x + wlen - x0) * S, (y + 7 - y0) * S], fill=int(255 * a_ * 0.55))
            x += wlen + int(rng.integers(10, 26))
            if x > wx + ww - 30: break
        y += 19
    t = np.asarray(im).astype(np.float32)[..., None] / 255
    img = img * (1 - t) + np.array([112, 104, 74], np.float32) / 255 * t * 0.75
    return img

CARDS = [dict(app="SIGNAL", when="now", title="Lena", body="Found something in the water. Call me.", urgency=1),
         dict(app="POWER", when="2 min", title="Battery critically low", body="4% remaining. Plug in now.", urgency=2),
         dict(app="UPDATES", when="5 min", title="Three packages ready", body="linux, mesa and qt6-base.", urgency=0)]

def draw_text(img, x0, y0, rects, cards, alpha=None):
    f_cap = font("Cinzel.ttf", 10.5, 600); f_when = font("Jost.ttf", 10.5, 400); f_title = font("Jost.ttf", 16.5, 500); f_body = font("Jost.ttf", 13.5, 380)
    H, W = img.shape[:2]
    for (x, y, w, h), c in zip(rects, cards):
        for (dx, dy, s, f, col, tr) in [(66, 11, c["app"], f_cap, (150, 140, 96), 2.0), (66, 27, c["title"], f_title, (236, 226, 200), 0), (66, 49, c["body"], f_body, (190, 178, 148), 0)]:
            im = Image.new("L", (W, H), 0); d = ImageDraw.Draw(im); cx = (x + dx - x0) * S
            for ch in s:
                d.text((cx, (y + dy - y0) * S), ch, font=f, fill=255); cx += f.getlength(ch) + tr * S
            m = np.asarray(im).astype(np.float32)[..., None] / 255
            img = img * (1 - m) + np.array(col, np.float32) / 255 * m
        wl = f_when.getlength(c["when"]) / S
        im = Image.new("L", (W, H), 0); ImageDraw.Draw(im).text(((x + w - 16 - wl - x0) * S, (y + 11 - y0) * S), c["when"], font=f_when, fill=255)
        m = np.asarray(im).astype(np.float32)[..., None] / 255
        img = img * (1 - m) + np.array((120, 112, 80), np.float32) / 255 * m
    return img

def window_layer(x0, y0, cw, ch):
    return render(WINDOW_GLSL, cw * S, ch * S, time=TIME, intensity=INTENSITY, seed=SEED, additive=1, rimWidth=RIM, rounding=ROUND,
                  resolution=SCREEN, usable=(0, BAR, SCREEN[0], SCREEN[1] - BAR), cursor=(0, 0, 0, 0), cursorSpan=1.98, depth=0.21, centerGain=0.98,
                  nearest=(0, 0, 1, 0), nearestPrev=(0, 0, 1, 0), pools=(0, 0, 0, 0), win0=WIN, win1=(0, 0, 0, 0), win2=(0, 0, 0, 0), win3=(0, 0, 0, 0),
                  win4=(0, 0, 0, 0), win5=(0, 0, 0, 0), origin=(x0, y0), cropSize=(cw, ch))

def mock_layer(x0, y0, cw, ch, rects, urgencies, mode, radius, neck=26, wave=-1):
    pad = lambda r: tuple(r) if r else (0, 0, 0, 0)
    rs = list(rects) + [None] * (3 - len(rects)); us = list(urgencies) + [1] * (3 - len(urgencies))
    return render(MOCK_GLSL, cw * S, ch * S, time=TIME, intensity=INTENSITY, seed=SEED, rimWidth=RIM, depth=TOAST_DEPTH, mode=mode, radius=radius, wave=wave, neck=neck,
                  resolution=SCREEN, origin=(x0, y0), cropSize=(cw, ch), c0=pad(rs[0]), c1=pad(rs[1]), c2=pad(rs[2]), urg=(us[0], us[1], us[2], 1))

def today_layer(x0, y0, cw, ch, rects, urgencies):
    out = np.zeros((ch * S, cw * S, 4), np.float32)
    for (x, y, w, h), u in zip(rects, urgencies):
        m = 110 if False else 24
        ox, oy = x - m, y - m; ow, oh = w + 2 * m, h + 2 * m
        o = render(RIM_GLSL, ow * S, oh * S, time=3, spores=0, seed=7, growth=1, energy=1, vividness=0.75, urgency=u, radius=5, size=(ow, oh),
                   card=(m, m, w, h), icon=(m + 32, m + h / 2, 15), remaining=0.62 if u == 1 else (-1 if u == 2 else 0.9))
        # card body under the rim: dark, 90% opaque, drawn here
        YY, XX = np.mgrid[0:oh * S, 0:ow * S].astype(np.float32)
        qx = np.abs(XX / S - (m + w / 2)) - (w / 2 - 5); qy = np.abs(YY / S - (m + h / 2)) - (h / 2 - 5)
        d = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - 5
        cov = np.clip(0.5 - d * S * 0.5, 0, 1)[..., None] * 0.90
        layer = np.concatenate([np.array([36, 32, 21], np.float32) / 255 * cov + o[..., :3], cov], axis=2)
        sx, sy = (ox - x0) * S, (oy - y0) * S                      # the margin may run past the crop
        cx0, cy0 = max(sx, 0), max(sy, 0); cx1, cy1 = min(sx + ow * S, cw * S), min(sy + oh * S, ch * S)
        layer = layer[cy0 - sy:cy1 - sy, cx0 - sx:cx1 - sx]
        out[cy0:cy1, cx0:cx1] = layer + out[cy0:cy1, cx0:cx1] * (1 - layer[..., 3:4])
    return out

REAL_GLSL = f"{tmp}/toastglow.glsl"
subprocess.run([QSB, "-x", "glsl,100 es", "-o", REAL_GLSL, ROOT + "/shaders/toastglow.frag.qsb"], check=True)
def real_layer(x0, y0, cw, ch, rects, urgencies, front=-1, icon_r=17):
    """The shipped shaders/toastglow.frag as an overlay per card (margin 48, as components/GlowRim.qml), over a dark card body."""
    out = np.zeros((ch * S, cw * S, 4), np.float32); m = 48
    for (x, y, w, h), u in zip(rects, urgencies):
        ox, oy = x - m, y - m; ow, oh = w + 2 * m, h + 2 * m
        o = render(REAL_GLSL, ow * S, oh * S, time=TIME, intensity=INTENSITY, seed=SEED, rimWidth=RIM, depth=0.21 * 0.62, urgency=u, radius=4, front=front,
                   resolution=SCREEN, origin=(ox, oy), size=(ow, oh), card=(m, m, w, h), icon=(m + 34, m + h / 2, icon_r))
        YY, XX = np.mgrid[0:oh * S, 0:ow * S].astype(np.float32)
        qx = np.abs(XX / S - (m + w / 2)) - (w / 2 - 4); qy = np.abs(YY / S - (m + h / 2)) - (h / 2 - 4)
        d = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - 4
        cov = np.clip(0.5 - d * S * 0.5, 0, 1)[..., None] * 0.93
        if front >= 0:                                           # the card is revealed by the same front (cardreveal.frag)
            ic = np.array([m + 34, m + h / 2]); dist = np.hypot(XX / S - ic[0], YY / S - ic[1])
            t = np.clip((dist - (front - 16)) / 26, 0, 1); cov = cov * (1 - t * t * (3 - 2 * t))[..., None]
        layer = np.concatenate([np.array([36, 32, 21], np.float32) / 255 * cov + o[..., :3], cov], axis=2)
        sx, sy = (ox - x0) * S, (oy - y0) * S
        cx0, cy0 = max(sx, 0), max(sy, 0); cx1, cy1 = min(sx + ow * S, cw * S), min(sy + oh * S, ch * S)
        layer = layer[cy0 - sy:cy1 - sy, cx0 - sx:cx1 - sx]
        out[cy0:cy1, cx0:cx1] = layer + out[cy0:cy1, cx0:cx1] * (1 - layer[..., 3:4])
    return out

def save(img, name):
    p = f"{OUT}/{name}.png"; Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(p); print(p); return p

def label(img, text):
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    d.text((14, 8), text, font=font("Jost.ttf", 11, 500), fill=(170, 165, 140))
    return np.asarray(im).astype(np.float32) / 255

X0, Y0, CW, CH = 1260, 0, 620, 300
if os.environ.get("SCAN"):                                  # contact sheet of the window glow for several seeds
    tiles = []
    for sd in [float(v) for v in os.environ["SCAN"].split(",")]:
        SEED = sd; t = over(scene(X0, Y0, CW, CH), window_layer(X0, Y0, CW, CH)); tiles.append(label(t, f"seed {sd:g}"))
    while len(tiles) % 3: tiles.append(np.zeros_like(tiles[0]))
    save(np.concatenate([np.concatenate(tiles[i:i + 3], axis=1) for i in range(0, len(tiles), 3)], axis=0), "scan"); sys.exit()
base = scene(X0, Y0, CW, CH)
wglow = window_layer(X0, Y0, CW, CH)
base = over(base, wglow)
save(base, "scene")                                        # the window glow alone: the light the toasts have to belong to

def cards_at(x, y0, gap, n=3, h=78): return [(x, y0 + i * (h + gap), 380, h) for i in range(n)]
variants = {}
r = cards_at(1490, 44, 8)
b = over(base, today_layer(X0, Y0, CW, CH, r, [1, 2, 0])); b = draw_text(b, X0, Y0, r, CARDS); variants["0-today"] = label(b, "TODAY: card with its own rim")
b = over(base, mock_layer(X0, Y0, CW, CH, r, [1, 2, 0], 0, 4)); b = draw_text(b, X0, Y0, r, CARDS); variants["1-windowed"] = label(b, "1  WINDOWED: lit by the window glow's own light")
r2 = cards_at(1490, 44, 5)
b = over(base, mock_layer(X0, Y0, CW, CH, r2, [1, 2, 0], 1, 7, neck=40)); b = draw_text(b, X0, Y0, r2, CARDS); variants["2-one-body"] = label(b, "2  ONE BODY: the stack as a single shape")
r3 = [(x + 16, y, w + 16, h) for (x, y, w, h) in cards_at(1490, 44, 5)]
b = over(base, mock_layer(X0, Y0, CW, CH, r3, [1, 2, 0], 1, 7, neck=40)); b = draw_text(b, X0, Y0, [(x, y, 380, h) for (x, y, w, h) in r3], CARDS); variants["3-docked"] = label(b, "3  DOCKED: the body grows out of the screen edge")
b = over(base, real_layer(X0, Y0, CW, CH, r, [1, 2, 0])); b = draw_text(b, X0, Y0, r, CARDS); variants["4-shipped"] = label(b, "4  THE SHIPPED SHADER (toastglow.frag), look=glow")
for k, v in variants.items(): save(v, "glow-" + k)

# the arrival of the first toast, as one event with the light
AX0, AY0, ACW, ACH = 1300, 0, 580, 170
abase = over(scene(AX0, AY0, ACW, ACH), window_layer(AX0, AY0, ACW, ACH))
frames = []
for wv in (0.05, 0.14, 0.26, 0.42, 0.62, 0.95, -1):
    one = [(1490, 44, 380, 78)]
    f = over(abase, mock_layer(AX0, AY0, ACW, ACH, one, [1], 0, 4, wave=wv))
    if wv < 0 or wv > 0.3: f = draw_text(f, AX0, AY0, one, CARDS[:1])
    frames.append(label(f, "wave %.2f" % wv if wv >= 0 else "settled"))
while len(frames) % 2: frames.append(np.zeros_like(frames[0]))
rows = [np.concatenate(frames[i:i + 2], axis=1) for i in range(0, len(frames), 2)]
save(np.concatenate(rows, axis=0), "glow-arrival")
frames = []
for fr in (20, 60, 110, 170, 250, 340, -1):
    one = [(1490, 44, 380, 78)]
    f = over(abase, real_layer(AX0, AY0, ACW, ACH, one, [1]))   # placeholder replaced below
    f = over(abase, real_layer(AX0, AY0, ACW, ACH, one, [1], front=fr))
    if fr < 0 or fr > 100: f = draw_text(f, AX0, AY0, one, CARDS[:1])
    frames.append(label(f, "front %d px" % fr if fr >= 0 else "settled"))
while len(frames) % 2: frames.append(np.zeros_like(frames[0]))
rows = [np.concatenate(frames[i:i + 2], axis=1) for i in range(0, len(frames), 2)]
save(np.concatenate(rows, axis=0), "glow-arrival-shipped")
