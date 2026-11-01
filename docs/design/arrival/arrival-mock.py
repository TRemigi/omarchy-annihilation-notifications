#!/usr/bin/env python3
# Renders the arrival (shaders/toastring.frag, toastflare.frag, cardreveal.frag) through the harness over a scene lit by the theme's real window glow. Developer tool, not shipped.
#   python3 docs/design/arrival/arrival-mock.py OUTDIR [seed] [time]
# Needs numpy and pillow, qsb (qt6-shadertools), gcc and Mesa's software GL (see test/shader-harness.c).
# The windows are lit by the theme's real windowglow.frag (only the two lines that map a pixel to the screen are changed, so a
# crop of the screen can be rendered); the toasts by glow-mock.frag, which reuses that shader's colour field and band profile.
# The scene is a 1880x1190 screen with a bar, and the toasts sit where Omarchy puts them (gapsOut from the right, below the bar).
import math, os, subprocess, sys, tempfile
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


def save(img, name):
    p = f"{OUT}/{name}.png"; Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(p); print(p); return p

def label(img, text):
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    d.text((14, 8), text, font=font("Jost.ttf", 11, 500), fill=(170, 165, 140))
    return np.asarray(im).astype(np.float32) / 255

def extract(name):
    out = f"{tmp}/{name}.glsl"; subprocess.run([QSB, "-x", "glsl,100 es", "-o", out, f"{ROOT}/shaders/{name}.frag.qsb"], check=True); return out
RING, FLARE, REVEAL = extract("toastring"), extract("toastflare"), extract("cardreveal")
ICON = (34, 39, 17)                                           # icon centre and ring radius in a 380x78 card, as the real card reports for a glyph

def reach_card(w, h, ix, iy): return math.hypot(max(ix, w - ix), max(iy, h - iy)) + 30
RING_REACH = max(180, min(340, SCREEN[1] * 0.26))
def travel(p): return 1 - (1 - p) ** 3
def front_at(p, rc): return (rc + RING_REACH) * travel(p)
def dur_for(u): return 3200 if u == 0 else (6000 if u == 2 else 4200)

def arrival_frame(x0, y0, cw, ch, cards, times_ms, strength=1.0, urgencies=None, amps=None):
    """cards: list of (x, y, w, h) in screen px; times_ms: ms since each arrival began. Returns the composited float image (no text)."""
    urgencies = urgencies or [1] * len(cards); amps = amps or [1.0] * len(cards)
    img = over(scene(x0, y0, cw, ch), window_layer(x0, y0, cw, ch))
    # under the cards: one ring layer for the whole crop
    u = dict(seed=SEED, strength=strength, reach=RING_REACH, radius=4, resolution=(cw, ch))
    for i in range(3):
        if i < len(cards):
            x, y, w, h = cards[i]; ix, iy = ICON[0], ICON[1] + (h - 78) / 2
            p = min(max(times_ms[i] / dur_for(urgencies[i]), 0.0), 1.0); rc = reach_card(w, h, ix, iy)
            u[f"rect{i}"] = (x - x0, y - y0, w, h); u[f"src{i}"] = (x - x0 + ix, y - y0 + iy, rc, front_at(p, rc)); u[f"ev{i}"] = (p, urgencies[i], amps[i], 1.3 * i)
        else:
            u[f"rect{i}"] = (0, 0, 0, 0); u[f"src{i}"] = (0, 0, 0, 0); u[f"ev{i}"] = (0, 1, 0, 0)
    img = over(img, render(RING, cw * S, ch * S, **u))
    # the cards, each revealed by its front, with its flare above
    for i, (x, y, w, h) in enumerate(cards):
        ix, iy = ICON[0], ICON[1] + (h - 78) / 2
        p = min(max(times_ms[i] / dur_for(urgencies[i]), 0.0), 1.0); rc = reach_card(w, h, ix, iy); fr = front_at(p, rc)
        m = 40; ow, oh = w + 2 * m, h + 2 * m; ox, oy = x - m, y - m
        YY, XX = np.mgrid[0:oh * S, 0:ow * S].astype(np.float32)
        qx = np.abs(XX / S - (m + w / 2)) - (w / 2 - 4); qy = np.abs(YY / S - (m + h / 2)) - (h / 2 - 4)
        dd = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - 4
        cov = np.clip(0.5 - dd * S * 0.5, 0, 1)[..., None] * 0.93
        dist = np.hypot(XX / S - (m + ix), YY / S - (m + iy)); t = np.clip((dist - (fr - 16)) / 26, 0, 1)
        cov = cov * (1 - t * t * (3 - 2 * t))[..., None]                     # cardreveal.frag
        fade = 1 - min(max((fr / rc - 0.7) / 0.4, 0), 1); fade = fade * fade * (3 - 2 * fade)
        fl = render(FLARE, ow * S, oh * S, strength=strength, urgency=urgencies[i], radius=4, front=fr, fade=fade, size=(ow, oh), card=(m, m, w, h), icon=(m + ix, m + iy, ICON[2]))
        layer = np.concatenate([np.array([36, 32, 21], np.float32) / 255 * cov + fl[..., :3], cov], axis=2)
        sx, sy = (ox - x0) * S, (oy - y0) * S
        cx0, cy0 = max(sx, 0), max(sy, 0); cx1, cy1 = min(sx + ow * S, cw * S), min(sy + oh * S, ch * S)
        L = layer[cy0 - sy:cy1 - sy, cx0 - sx:cx1 - sx]
        img[cy0:cy1, cx0:cx1] = np.clip(L[..., :3] + img[cy0:cy1, cx0:cx1] * (1 - L[..., 3:4]), 0, 1)
    return img

def with_text(img, x0, y0, cards, texts, times_ms, rcs):
    # text only inside the front: draw it, then mask by the same front
    out = draw_text(img.copy(), x0, y0, cards, texts)
    H, W = img.shape[:2]; YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)
    for (x, y, w, h), tm, rc in zip(cards, times_ms, rcs):
        p = min(max(tm / 4200, 0), 1); fr = front_at(p, rc); ix, iy = x + ICON[0], y + ICON[1]
        dist = np.hypot(XX / S + x0 - ix, YY / S + y0 - iy); t = np.clip((dist - (fr - 16)) / 26, 0, 1); keep = (1 - t * t * (3 - 2 * t))[..., None]
        inbox = ((XX / S + x0 >= x) & (XX / S + x0 <= x + w) & (YY / S + y0 >= y) & (YY / S + y0 <= y + h))[..., None]
        out = np.where(inbox, img * (1 - keep) + out * keep, out)
    return out

# one toast, a strip of moments
AX0, AY0, ACW, ACH = 1100, 20, 780, 330
card = [(1490, 44, 380, 78)]
frames = []
for ms in (60, 160, 300, 480, 700, 1000, 1500, 2300, 3300):
    f = arrival_frame(AX0, AY0, ACW, ACH, card, [ms])
    f = with_text(f, AX0, AY0, card, CARDS[:1], [ms], [reach_card(380, 78, ICON[0], ICON[1])])
    frames.append(label(f, "%d ms" % ms))
while len(frames) % 3: frames.append(np.zeros_like(frames[0]))
save(np.concatenate([np.concatenate(frames[i:i + 3], axis=1) for i in range(0, len(frames), 3)], axis=0), "arrival-one")

# a critical one, a low one, and a burst of three
for name, u in (("critical", [2]), ("low", [0])):
    frames = []
    for ms in (200, 700, 1400, 2600):
        f = arrival_frame(AX0, AY0, ACW, ACH, card, [ms], urgencies=u)
        f = with_text(f, AX0, AY0, card, CARDS[1:2] if u[0] == 2 else CARDS[2:3], [ms], [reach_card(380, 78, ICON[0], ICON[1])])
        frames.append(label(f, "%s %d ms" % (name, ms)))
    save(np.concatenate([np.concatenate(frames[:2], axis=1), np.concatenate(frames[2:], axis=1)], axis=0), "arrival-" + name)
three = [(1490, 44, 380, 78), (1490, 130, 380, 78), (1490, 216, 380, 78)]
frames = []
for ms in ((900, 500, 150), (1800, 1400, 1050)):
    f = arrival_frame(AX0, AY0, ACW, ACH + 60, three, list(ms), amps=[1, 0.6, 0.6])
    f = with_text(f, AX0, AY0, three, CARDS, list(ms), [reach_card(380, 78, ICON[0], ICON[1])] * 3)
    frames.append(label(f, "burst %s ms" % (ms,)))
save(np.concatenate(frames, axis=1), "arrival-burst")
