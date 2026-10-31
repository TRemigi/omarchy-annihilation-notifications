#!/usr/bin/env python3
# Previews shaders/toastspores.frag: a toast folding away over docs/design/backdrop.png while its spores lift off and
# drift left, at six moments, as a contact sheet. The shader's real output, run through test/shader-harness.c on Mesa's
# software GL and added over the backdrop; the card is a stand-in (a body fading as it folds). Developer tool; needs
# numpy and pillow and the compiled shaders/toastspores.frag.qsb.
#
#   python3 test/spores-preview.py OUT.png [urgency] [seed]
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
OUT = sys.argv[1]; URGENCY = sys.argv[2] if len(sys.argv) > 2 else "1"; SEED = sys.argv[3] if len(sys.argv) > 3 else "7"
S = 2
tmp = tempfile.mkdtemp()
frag = tmp + "/s.frag"; harness = tmp + "/harness"
subprocess.run(["/usr/lib/qt6/bin/qsb", "-x", "glsl,100 es", "-o", frag, ROOT + "/shaders/toastspores.frag.qsb"], check=True)
subprocess.run(["gcc", "-O2", HERE + "/shader-harness.c", "-o", harness, "-lEGL", "-lGLESv2"], check=True)

backdrop = Image.open(ROOT + "/docs/design/backdrop.png").convert("RGB")
BW, BH = backdrop.size; W, H = BW * S, BH * S
base = np.asarray(backdrop.resize((W, H), Image.BICUBIC)).astype(np.float32) / 255.0
BG = np.array([36, 32, 21], np.float32) / 255.0
CARD = (320, 10, 380, 78)                                           # x, y, w, h in logical px

def card_body(alpha, fold):
    """a stand-in for the card as it folds: the body fading, and its height closing up from the bottom"""
    x, y, w, h = [v * S for v in CARD]; h = h * fold
    img = Image.new("L", (W, H), 0); ImageDraw.Draw(img).rounded_rectangle([x, y, x + w, y + h], radius=5 * S, fill=int(255 * alpha))
    return np.asarray(img).astype(np.float32) / 255.0

frames = []
ages = [0.0, 0.12, 0.30, 0.60, 0.95, 1.40]
for age in ages:
    img = base.copy()
    fold = max(0.0, 1.0 - age / 0.30) if age < 0.30 else 0.0       # the 300 ms fold
    a = card_body(max(0.0, 1.0 - age / 0.30) * 0.92, fold) if fold > 0 else np.zeros((H, W), np.float32)
    img = img * (1 - a[..., None]) + BG * a[..., None]
    env = dict(os.environ, EGL_PLATFORM="surfaceless", LIBGL_ALWAYS_SOFTWARE="1", U_amount="1", U_size=f"{BW},{BH}",
               U_rect0=f"{CARD[0]},{CARD[1]},{CARD[2]},{CARD[3]}", U_state0=f"{age},{SEED},{URGENCY},0",
               U_rect1="0,0,0,0", U_state1="-1,0,1,0", U_rect2="0,0,0,0", U_state2="-1,0,1,0", U_rect3="0,0,0,0", U_state3="-1,0,1,0")
    pam = tmp + "/o.pam"
    subprocess.run([harness, frag, str(W), str(H), pam], env=env, check=True, stderr=subprocess.DEVNULL)
    raw = open(pam, "rb").read(); e = raw.index(b"ENDHDR\n") + 7
    o = np.frombuffer(raw[e:], np.uint8).reshape(H, W, 4).astype(np.float32) / 255.0
    img = np.clip(o[..., :3] + img * (1 - o[..., 3:4]), 0, 1)
    crop = Image.fromarray((img * 255).astype(np.uint8)).crop((200 * S, 0, 700 * S, 120 * S))
    d = ImageDraw.Draw(crop); d.text((10, 8), f"{int(age * 1000)} ms", fill=(235, 225, 200))
    frames.append(crop)

cw, ch = frames[0].size
sheet = Image.new("RGB", (cw * 2, ch * 3))
for i, f in enumerate(frames): sheet.paste(f, ((i % 2) * cw, (i // 2) * ch))
sheet.save(OUT); print(OUT, sheet.size)
