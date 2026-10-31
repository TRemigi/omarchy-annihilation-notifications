#!/usr/bin/env python3
# Previews tools' toastrim shader as it will look: the card body, the shader's real output (run through
# test/shader-harness.c on Mesa's software GL) added on top, over docs/design/backdrop.png, and the text from the
# design mock-up for scale. Developer tool; needs numpy and pillow and the compiled shaders/toastrim.frag.qsb.
#
#   python3 test/rim-preview.py OUTDIR [vividness] [energy] [remaining] [spores] [time]
# SHADER=toastgrowth renders the Growth look instead (GROWTH=0..1 is how far its veins have reached, SEED=n).
# The first card is a normal toast with `remaining` of its life left (default 0.62); the second is critical, which never expires, so has no countdown.
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
OUT = sys.argv[1]; VIV = sys.argv[2] if len(sys.argv) > 2 else "0.75"; ENERGY = sys.argv[3] if len(sys.argv) > 3 else "1"; REMAINING = sys.argv[4] if len(sys.argv) > 4 else "0.62"
SPORES = sys.argv[5] if len(sys.argv) > 5 else "0"; TIME = sys.argv[6] if len(sys.argv) > 6 else "3"
SHADER = os.environ.get("SHADER", "toastrim"); GROWTH = os.environ.get("GROWTH", "1"); SEED = os.environ.get("SEED", "7")
os.makedirs(OUT, exist_ok=True)
S = 2
tmp = tempfile.mkdtemp()
frag = tmp + "/s.frag"; harness = tmp + "/harness"
subprocess.run(["/usr/lib/qt6/bin/qsb", "-x", "glsl,100 es", "-o", frag, ROOT + "/shaders/" + SHADER + ".frag.qsb"], check=True)
subprocess.run(["gcc", "-O2", HERE + "/shader-harness.c", "-o", harness, "-lEGL", "-lGLESv2"], check=True)

backdrop = Image.open(ROOT + "/docs/design/backdrop.png").convert("RGB")
BW, BH = backdrop.size; W, H = BW * S, BH * S
base = np.asarray(backdrop.resize((W, H), Image.BICUBIC)).astype(np.float32) / 255.0
blur = np.asarray(backdrop.resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(9 * S))).astype(np.float32) / 255.0
BG = np.array([36, 32, 21], np.float32) / 255.0

# the same geometry as the mock-ups, in logical px: cards at x 320..700, 78 tall, 8 apart
cards = [dict(y=10, urgency=1, remaining=REMAINING), dict(y=96, urgency=2, remaining="-1")]
img = base.copy()
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)
def sdf(x0, y0, x1, y1, r):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2; hx, hy = (x1 - x0) / 2, (y1 - y0) / 2
    qx = np.abs(XX - cx) - (hx - r); qy = np.abs(YY - cy) - (hy - r)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r
for c in cards:                                                     # the card bodies
    d = sdf(320 * S, c["y"] * S, 700 * S, (c["y"] + 78) * S, 5 * S)
    a = np.clip(0.5 - d, 0, 1) * 0.90
    body = blur * 0.16 + BG * 0.84
    img = img * (1 - a[..., None]) + body * a[..., None]

for c in cards:                                                     # the shader's output for each, over a margin
    mx = 110 if (float(SPORES) > 0 or SHADER == 'toastgrowth') else 20   # the faint spores drift up to ~50 px out of the left edge, the roots further
    ox, oy = 320 - mx, max(c["y"] - mx, 0)
    ow, oh = 380 + 2 * mx, (c["y"] - oy) + 78 + mx
    env = dict(os.environ, EGL_PLATFORM="surfaceless", LIBGL_ALWAYS_SOFTWARE="1",
               # the shader works in logical px (as the QML will pass them) while the bitmap is drawn at 2x
               U_time=TIME, U_spores=SPORES, U_seed=SEED if c["urgency"] == 1 else "19", U_growth=GROWTH, U_energy=ENERGY, U_vividness=VIV, U_urgency=str(c["urgency"]), U_radius="5",
               U_size=f"{ow},{oh}", U_card=f"{mx},{c['y'] - oy},380,78",
               U_icon=f"{mx + 32},{c['y'] - oy + 39},15", U_remaining=c["remaining"])
    pam = tmp + "/o.pam"
    subprocess.run([harness, frag, str(ow * S), str(oh * S), pam], env=env, check=True, stderr=subprocess.DEVNULL)
    raw = open(pam, "rb").read(); e = raw.index(b"ENDHDR\n") + 7
    o = np.frombuffer(raw[e:], np.uint8).reshape(oh * S, ow * S, 4).astype(np.float32) / 255.0
    ys, xs = oy * S, ox * S
    region = img[ys:ys + o.shape[0], xs:xs + o.shape[1]]
    o = o[:region.shape[0], :region.shape[1]]                       # the margin may run past the backdrop's edge
    img[ys:ys + o.shape[0], xs:xs + o.shape[1]] = np.clip(o[..., :3] + region * (1 - o[..., 3:4]), 0, 1)

name = f"{OUT}/{SHADER[5:] if SHADER != 'toastrim' else 'rim'}-v{VIV}-e{ENERGY}-r{REMAINING}-s{SPORES}-t{TIME}.png"
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(name)
print(name)
