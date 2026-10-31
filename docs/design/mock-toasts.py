#!/usr/bin/env python3
# Design mock-ups of the notification card (run: FONTS=... python3 mock-toasts.py BACKDROP.png OUTDIR)
# Needs numpy and pillow (a throwaway venv is fine). Design mock-ups of the notification card, drawn over a backdrop (a dark window with the arrival ring
# behind). Not the implementation: the real thing is QML and shaders. This is for choosing a direction.
#   see docs/design/README.md for how the backdrop is made
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 2                                        # render at 2x
# The bundled Jost and Cinzel (SIL OFL) live in the theme repo; point FONTS at that directory.
FONTS = os.environ.get("FONTS", os.path.expanduser("~/dev/omarchy-annihilation-theme/extras/plugin/annihilation.shimmer/fonts/"))
backdrop = Image.open(sys.argv[1]).convert("RGB")
OUT = sys.argv[2]; os.makedirs(OUT, exist_ok=True)
BW, BH = backdrop.size
W, H = BW * S, BH * S
base = np.asarray(backdrop.resize((W, H), Image.BICUBIC)).astype(np.float32) / 255.0
blur = np.asarray(backdrop.resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(9 * S))).astype(np.float32) / 255.0
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)

def c(r, g, b): return np.array([r, g, b], dtype=np.float32) / 255.0
BG = c(36, 32, 21); TEXT = c(210, 195, 164); TEAL = c(97, 160, 168); MAG = c(145, 80, 108); AMBER = c(219, 147, 13); MOSS = c(122, 118, 83)
L_TEAL = np.array([0.20, 0.77, 0.82], np.float32); L_BLUE = np.array([0.37, 0.52, 1.0], np.float32)
L_VIOLET = np.array([0.60, 0.40, 0.95], np.float32); L_PINK = np.array([0.95, 0.48, 0.78], np.float32)
L_PEACH = np.array([0.96, 0.66, 0.47], np.float32); L_AMBER = np.array([0.96, 0.62, 0.18], np.float32)
SPEC_NORMAL = [L_TEAL, L_BLUE, L_VIOLET, L_PINK]
SPEC_CRIT = [L_AMBER, L_PEACH, L_PINK, L_VIOLET]

def spectrum(t, stops):
    t = np.clip(t, 0, 1) * (len(stops) - 1)
    i = np.minimum(t.astype(np.int32), len(stops) - 2); f = (t - i)[..., None]
    arr = np.stack(stops)
    return arr[i] * (1 - f) + arr[i + 1] * f

def sdf_rrect(x0, y0, x1, y1, r):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2; hx, hy = (x1 - x0) / 2, (y1 - y0) / 2
    qx = np.abs(XX - cx) - (hx - r); qy = np.abs(YY - cy) - (hy - r)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r

def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)

def font(name, px, wght):
    f = ImageFont.truetype(FONTS + name, int(round(px * S)))
    try: f.set_variation_by_axes([wght])
    except Exception: pass
    return f

def text_layer(items):
    """items: (x, y, text, font, tracking_px) -> an L mask of all the text, in canvas pixels."""
    im = Image.new("L", (W, H), 0); d = ImageDraw.Draw(im)
    for (x, y, s, f, tr) in items:
        cx = x * S
        for ch in s:
            d.text((cx, y * S), ch, font=f, fill=255)
            cx += f.getlength(ch) + tr * S
    return np.asarray(im).astype(np.float32) / 255.0

def text_width(s, f, tr): return sum(f.getlength(ch) + tr * S for ch in s) / S

def blur_mask(m, sigma):
    return np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(sigma * S))).astype(np.float32) / 255.0

def over(img, color, alpha):          # ordinary alpha compositing
    a = alpha[..., None] if alpha.ndim == 2 else alpha
    return img * (1 - a) + np.asarray(color, np.float32) * a

def add(img, rgb): return np.clip(img + rgb, 0, 1)

# ------------------------------------------------------------------ content
CARDS = [
    dict(app="SIGNAL", title="Lena", body="Found something in the water. Call me.", when="now", crit=False),
    dict(app="POWER", title="Battery critically low", body="4% remaining. Plug in now.", when="2 min", crit=True),
]
CX, CY, CW, CHH, GAP = 320, 10, 380, 78, 8
def card_rect(i): return (CX, CY + i * (CHH + GAP), CX + CW, CY + i * (CHH + GAP) + CHH)

# ------------------------------------------------------------------ 0. the current look (stock layout, theme tokens)
def draw_stock(img, i, card):
    x0, y0, x1, y1 = [v * S for v in card_rect(i)]
    d = sdf_rrect(x0, y0, x1, y1, 4 * S)
    a = np.clip(0.5 - d / 1.0, 0, 1)
    body = blur * 0.08 + BG * 0.92
    img = over(img, body, a * 0.92)
    # 2 px gradient border, teal -> magenta -> amber -> moss at 50deg
    t = np.clip(((XX - x0) * 0.64 + (YY - y0) * 0.77) / ((x1 - x0) * 0.64 + (y1 - y0) * 0.77), 0, 1)
    stops = [TEAL, MAG, AMBER, MOSS]
    col = np.zeros((H, W, 3), np.float32); tt = t * 3; k = np.minimum(tt.astype(np.int32), 2); f = (tt - k)[..., None]
    arr = np.stack(stops); col = arr[k] * (1 - f) + arr[k + 1] * f
    rim = np.clip(0.5 - np.abs(d + 1.0 * S) / (1.0 * S) + 0.5, 0, 1) * (d < 0.5)
    rim = np.clip(1 - np.abs(d + 1 * S) / (1 * S), 0, 1)
    img = over(img, col, rim * 0.93)
    f_title = ImageFont.truetype("/usr/share/fonts/liberation/LiberationSans-Bold.ttf", 15 * S) if os.path.exists("/usr/share/fonts/liberation/LiberationSans-Bold.ttf") else font("Jost.ttf", 15, 700)
    f_body = ImageFont.truetype("/usr/share/fonts/liberation/LiberationSans-Regular.ttf", 15 * S) if os.path.exists("/usr/share/fonts/liberation/LiberationSans-Regular.ttf") else font("Jost.ttf", 15, 400)
    tx = card_rect(i)[0] + 64
    m_title = text_layer([(tx, card_rect(i)[1] + 14, card["title"], f_title, 0)])
    m_body = text_layer([(tx, card_rect(i)[1] + 40, card["body"], f_body, 0)])
    img = over(img, TEXT, m_title); img = over(img, TEXT * 0.87, m_body)
    # a plain app-icon slot
    cxn, cyn = (card_rect(i)[0] + 32) * S, (card_rect(i)[1] + CHH / 2) * S
    disc = np.clip(1 - (np.hypot(XX - cxn, YY - cyn) - 15 * S), 0, 1)
    img = over(img, TEXT * 0.55, disc * 0.9)
    return img

# ------------------------------------------------------------------ A. Refraction
def draw_A(img, i, card):
    x0, y0, x1, y1 = [v * S for v in card_rect(i)]
    stops = SPEC_CRIT if card["crit"] else SPEC_NORMAL
    d = sdf_rrect(x0, y0, x1, y1, 5 * S)
    a = np.clip(0.5 - d / 1.0, 0, 1)
    body = blur * 0.16 + BG * 0.84
    # a very slight vertical lift: the top of the glass catches a little more light
    body = body * (1.0 + 0.10 * (1 - np.clip((YY - y0) / (y1 - y0), 0, 1)))[..., None]
    img = over(img, body, a * 0.90)
    t = 0.12 + 0.72 * np.clip((XX - x0) / (x1 - x0), 0, 1) + 0.06 * np.sin(YY / S * 0.09)
    col = spectrum(t, stops)
    light = 0.32 + 0.68 * np.exp(-np.hypot(XX - x1, YY - y0) / (0.6 * (x1 - x0)))     # the light comes from the top right
    rim = np.exp(-((d + 0.9 * S) / (0.85 * S)) ** 2) * (d < 1.5 * S)
    spill = np.exp(-np.maximum(-d, 0) / (9 * S)) * (d < 0) * 0.17
    halo = np.exp(-np.maximum(d, 0) / (4.5 * S)) * (d >= 0) * 0.20
    img = add(img, col * ((rim * 0.95 + spill + halo) * light)[..., None])
    # text
    f_cap = font("Jost.ttf", 10.5, 500); f_title = font("Jost.ttf", 16.5, 500); f_body = font("Jost.ttf", 13.5, 380)
    tx = card_rect(i)[0] + 64; ty = card_rect(i)[1]
    items_title = [(tx, ty + 24, card["title"], f_title, 0.1)]
    m_title = text_layer(items_title)
    m_cap = text_layer([(tx, ty + 9, card["app"], f_cap, 1.7)]); m_when = text_layer([(card_rect(i)[2] - 14 - text_width(card["when"], f_cap, 0.3), ty + 9, card["when"], f_cap, 0.3)])
    m_body = text_layer([(tx, ty + 47, card["body"], f_body, 0)])
    glow = blur_mask(m_title, 3.6) * 0.55
    gcol = spectrum(np.full((H, W), 0.1 if not card["crit"] else 0.05, np.float32), stops)
    img = add(img, gcol * glow[..., None] * 0.7)
    img = over(img, c(238, 228, 202), m_title)
    img = over(img, c(150, 142, 118), m_cap); img = over(img, c(118, 110, 90), m_when); img = over(img, c(176, 167, 140), m_body)
    # icon: a ring in the rim colour with a small spore at its centre
    icx, icy = (card_rect(i)[0] + 32) * S, (card_rect(i)[1] + CHH / 2) * S
    r = np.hypot(XX - icx, YY - icy)
    ring = np.exp(-((r - 15 * S) / (0.9 * S)) ** 2); core = np.exp(-(r / (2.6 * S)) ** 2); fill = np.clip(1 - (r - 15 * S), 0, 1) * 0.07
    tcol = spectrum(np.clip(0.1 + 0.8 * (XX - (icx - 15 * S)) / (30 * S), 0, 1), stops)
    img = add(img, tcol * (ring * 0.85 + core * 0.9 + fill + np.exp(-np.maximum(r - 15 * S, 0) / (5 * S)) * 0.10 * (r > 15 * S))[..., None])
    # countdown: the light draining along the bottom edge
    ly = y1 - 3.2 * S; lx0 = x0 + 14 * S; lx1 = lx0 + (0.62 if not card["crit"] else 0.35) * (x1 - x0 - 28 * S)
    seg = smooth(lx0 - 1 * S, lx0 + 6 * S, XX) * (1 - smooth(lx1 - 6 * S, lx1, XX))
    line = np.exp(-((YY - ly) / (0.8 * S)) ** 2) * seg
    lcol = spectrum(np.clip((XX - lx0) / max(lx1 - lx0, 1), 0, 1), stops)
    img = add(img, lcol * (line * 0.95 + np.exp(-((YY - ly) / (3.2 * S)) ** 2) * seg * 0.18)[..., None])
    spark = np.exp(-(np.hypot(XX - lx1, YY - ly) / (2.2 * S)) ** 2)
    img = add(img, (lcol[0, 0] * 0 + c(255, 245, 235)) * (spark * 0.8)[..., None] + lcol * (np.exp(-(np.hypot(XX - lx1, YY - ly) / (7 * S)) ** 2) * 0.25)[..., None])
    return img

# ------------------------------------------------------------------ B. Field note
def draw_B(img, i, card):
    x0, y0, x1, y1 = [v * S for v in card_rect(i)]
    rng = np.random.default_rng(5 + i)
    accent = AMBER if card["crit"] else TEAL
    d = sdf_rrect(x0, y0, x1, y1, 3 * S)
    a = np.clip(0.5 - d / 1.0, 0, 1)
    paper = c(44, 38, 25)
    body = blur * 0.05 + paper * 0.95
    body = body + rng.normal(0, 0.012, (H, W, 1)).astype(np.float32)             # paper grain
    edge = smooth(0, 26 * S, np.maximum(-d, 0))                                  # slightly darker toward the edges
    body = body * (0.90 + 0.10 * edge)[..., None]
    img = over(img, body, a * 0.96)
    # a double rule and four corner ticks
    outer = np.clip(1 - np.abs(d + 0.5 * S) / (0.6 * S), 0, 1)
    d2 = sdf_rrect(x0 + 5 * S, y0 + 5 * S, x1 - 5 * S, y1 - 5 * S, 1 * S)
    inner = np.clip(1 - np.abs(d2) / (0.6 * S), 0, 1)
    img = over(img, MOSS, outer * 0.55); img = over(img, accent, inner * 0.7)
    for (qx, qy, sx, sy) in [(x0 + 5 * S, y0 + 5 * S, 1, 1), (x1 - 5 * S, y0 + 5 * S, -1, 1), (x0 + 5 * S, y1 - 5 * S, 1, -1), (x1 - 5 * S, y1 - 5 * S, -1, -1)]:
        hz = (np.abs(YY - qy) < 0.8 * S) & ((XX - qx) * sx >= -1 * S) & ((XX - qx) * sx <= 7 * S)
        vt = (np.abs(XX - qx) < 0.8 * S) & ((YY - qy) * sy >= -1 * S) & ((YY - qy) * sy <= 7 * S)
        img = over(img, AMBER, (hz | vt).astype(np.float32) * 0.95)
    # header: app in small Cinzel capitals, the time at the right, a rule beneath
    f_cap = font("Cinzel.ttf", 10.5, 600); f_when = font("Jost.ttf", 10.5, 400); f_title = font("Jost.ttf", 16, 460); f_body = font("Jost.ttf", 13.2, 360)
    ty = card_rect(i)[1]; tx = card_rect(i)[0] + 20
    m_cap = text_layer([(tx + 10, ty + 11, card["app"], f_cap, 2.2)])
    m_when = text_layer([(card_rect(i)[2] - 20 - text_width(card["when"], f_when, 0.3), ty + 12, card["when"], f_when, 0.3)])
    m_title = text_layer([(tx, ty + 30, card["title"], f_title, 0)]); m_body = text_layer([(tx, ty + 51, card["body"], f_body, 0)])
    img = over(img, c(222, 150, 22), m_cap); img = over(img, c(128, 120, 98), m_when)
    img = over(img, c(228, 216, 186), m_title); img = over(img, c(166, 157, 130), m_body)
    rule = (np.abs(YY - (ty + 26) * S) < 0.5 * S) & (XX > tx * S) & (XX < (card_rect(i)[2] - 20) * S)
    img = over(img, MOSS, rule.astype(np.float32) * 0.45)
    # the unread spore, with a faint halo
    sx_, sy_ = (tx + 3) * S, (ty + 17) * S
    r = np.hypot(XX - sx_, YY - sy_)
    img = add(img, AMBER * (np.exp(-(r / (2.3 * S)) ** 2) * 0.95 + np.exp(-(r / (6 * S)) ** 2) * 0.22)[..., None])
    # countdown as a row of ticks, the spent ones fading to the rule colour
    n = 26; left = x0 + 20 * S; step = (x1 - x0 - 40 * S) / (n - 1); yb = y1 - 10 * S
    remaining = 17 if not card["crit"] else 9
    for k in range(n):
        xk = left + k * step; on = k < remaining
        m = (np.abs(XX - xk) < 0.6 * S) & (np.abs(YY - yb) < 2.2 * S)
        img = over(img, accent if on else MOSS, m.astype(np.float32) * (0.9 if on else 0.28))
    return img

# ------------------------------------------------------------------ C. Growth
def draw_C(img, i, card):
    x0, y0, x1, y1 = [v * S for v in card_rect(i)]
    rng = np.random.default_rng(31 + i); rnd = random.Random(31 + i)
    accent = c(226, 140, 40) if card["crit"] else TEAL
    d = sdf_rrect(x0, y0, x1, y1, 9 * S)
    nz = (0.9 * np.sin(XX * 0.045 / S * 2 + 1.3) * np.sin(YY * 0.061 / S * 2 + 0.4) + 0.6 * np.sin(XX * 0.11 / S * 2 + YY * 0.07 / S * 2 + 2.0)) * S
    d = d + nz * 0.55                                                              # the outline is not quite straight
    a = np.clip(0.5 - d / 1.0, 0, 1)
    patch = (0.5 + 0.5 * np.sin(XX / S * 0.07 + YY / S * 0.11 + i)) * (0.5 + 0.5 * np.sin(XX / S * 0.031 - YY / S * 0.05))
    moss_tint = c(31, 38, 22)
    body = blur * 0.10 + (BG * (1 - 0.30 * patch[..., None]) + moss_tint * (0.30 * patch[..., None]))
    body = body + rng.normal(0, 0.010, (H, W, 1)).astype(np.float32)
    img = over(img, body, a * 0.93)
    # the rim: moss, with teal where the growth is thicker
    rim = np.clip(1 - np.abs(d + 0.7 * S) / (0.9 * S), 0, 1)
    tealness = smooth(0.35, 0.8, 0.5 + 0.5 * np.sin(XX / S * 0.05 + YY / S * 0.08 + 3 * i))
    rimcol = MOSS * (1 - tealness[..., None]) + accent * tealness[..., None]
    img = over(img, rimcol, rim * 0.85)
    # a strip of lichen down the left edge, ragged where it meets the card
    xs = x0 + 4.5 * S + 1.6 * S * np.sin(YY / S * 0.33 + i) + 1.0 * S * np.sin(YY / S * 0.9)
    strip = (XX < xs) * (d < -0.5 * S) * (1 - smooth(xs - 2 * S, xs, XX) * 0.0)
    gradv = np.clip((YY - y0) / (y1 - y0), 0, 1)[..., None]
    scol = MOSS * (1 - gradv) + accent * gradv
    speck = (rng.random((H, W)) < 0.10).astype(np.float32)
    img = over(img, scol, strip.astype(np.float32) * (0.55 + 0.35 * speck))
    # veins reaching out from the corners and edges: random walks that branch and fade
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dr = ImageDraw.Draw(layer)
    def grow(px, py, ang, steps, width):
        if steps <= 0: return
        for s in range(steps):
            ang += rnd.uniform(-0.38, 0.38)
            nx, ny = px + math.cos(ang) * 2.4 * S, py + math.sin(ang) * 2.4 * S
            alpha = int(200 * (1 - s / (steps + 1)) ** 1.2)
            col = (int(accent[0] * 255), int(accent[1] * 255), int(accent[2] * 255)) if s > steps * 0.5 else (int(MOSS[0] * 255), int(MOSS[1] * 255), int(MOSS[2] * 255))
            dr.line([(px, py), (nx, ny)], fill=col + (alpha,), width=max(1, int(width * S)))
            px, py = nx, ny
            if s > 2 and rnd.random() < 0.13: grow(px, py, ang + rnd.choice([-1, 1]) * rnd.uniform(0.5, 0.9), steps - s - 2, width * 0.8)
    for (px, py, ang) in [(x0 + 14 * S, y0, -math.pi / 2 - 0.3), (x0 + 120 * S, y0, -math.pi / 2 + 0.2), (x1 - 40 * S, y0, -math.pi / 2 + 0.1), (x1, y0 + 20 * S, 0.1),
                         (x1, y1 - 12 * S, 0.5), (x0, y1 - 14 * S, math.pi - 0.4), (x0 + 200 * S, y1, math.pi / 2 - 0.2)]:
        grow(px, py, ang, rnd.randint(9, 16), 1.0)
    veins = np.asarray(layer.filter(ImageFilter.GaussianBlur(0.5 * S))).astype(np.float32) / 255.0
    outside = (d > 0.5 * S).astype(np.float32)[..., None]
    img = img * (1 - veins[..., 3:4] * outside * 0.8) + veins[..., :3] * veins[..., 3:4] * outside * 0.8
    # spores drifting off the top edge
    for _ in range(16):
        sx_ = rnd.uniform(x0 + 20 * S, x1 - 10 * S); sy_ = y0 - rnd.uniform(2, 20) * S
        rr = rnd.uniform(0.8, 1.9) * S; r = np.hypot(XX - sx_, YY - sy_)
        sc = AMBER if rnd.random() < 0.55 else accent
        al = rnd.uniform(0.35, 0.9) * (1 - (y0 - sy_) / (24 * S))
        img = add(img, sc * ((np.exp(-(r / rr) ** 2) * al + np.exp(-(r / (4 * rr)) ** 2) * 0.12 * al))[..., None])
    # text
    f_cap = font("Jost.ttf", 10.5, 500); f_title = font("Jost.ttf", 16.5, 500); f_body = font("Jost.ttf", 13.5, 380)
    ty = card_rect(i)[1]; tx = card_rect(i)[0] + 24
    m_cap = text_layer([(tx, ty + 9, card["app"].lower(), f_cap, 1.2)]); m_title = text_layer([(tx, ty + 24, card["title"], f_title, 0.1)]); m_body = text_layer([(tx, ty + 47, card["body"], f_body, 0)])
    img = over(img, c(140, 150, 112), m_cap); img = over(img, c(232, 222, 194), m_title); img = over(img, c(168, 160, 130), m_body)
    # countdown: a vein that retreats along the bottom edge
    ly = y1 - 4.5 * S; lx0 = x0 + 24 * S; lx1 = lx0 + (0.6 if not card["crit"] else 0.3) * (x1 - x0 - 48 * S)
    wob = ly + 1.1 * S * np.sin((XX - lx0) / S * 0.22)
    seg = smooth(lx0 - 1 * S, lx0 + 3 * S, XX) * (1 - smooth(lx1 - 10 * S, lx1, XX))
    line = np.exp(-((YY - wob) / (0.75 * S)) ** 2) * seg
    img = add(img, accent * (line * 0.9 + np.exp(-((YY - wob) / (3 * S)) ** 2) * seg * 0.14)[..., None])
    return img

for name, fn in [("0-current", draw_stock), ("A-refraction", draw_A), ("B-field-note", draw_B), ("C-growth", draw_C)]:
    img = base.copy()
    for i, card in enumerate(CARDS): img = fn(img, i, card)
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(f"{OUT}/{name}.png")
    print("wrote", name)
