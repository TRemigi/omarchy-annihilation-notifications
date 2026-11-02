#!/usr/bin/env python3
# Numeric tests of shaders/toastbody.frag (compiled form), run on Mesa's software GL through test/shader-harness.c: the oval body of a toast.
# The shape is checked against an independent mirror of BodyLogic.js's distance and feather, pixel by pixel, so the shader and the logic cannot drift apart.
#   python3 test/body-test.py        (needs gcc, EGL and GLES headers, llvmpipe, qsb; standard library only)
import math, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
QSB = "/usr/lib/qt6/bin/qsb"
SHADERS = os.environ.get("SHADERDIR", ROOT + "/shaders")      # a directory of mutated copies, to prove the checks can fail
tmp = tempfile.mkdtemp()
passed = failed = 0
def check(name, ok, detail=""):
    global passed, failed
    if ok: passed += 1
    else: failed += 1; print("FAIL", name, detail)
subprocess.run([QSB, "-x", "glsl,100 es", "-o", f"{tmp}/b.glsl", f"{SHADERS}/toastbody.frag.qsb"], check=True)
subprocess.run(["gcc", "-O2", ROOT + "/test/shader-harness.c", "-o", tmp + "/harness", "-lEGL", "-lGLESv2"], check=True)
W, H = 640, 260; CARD = (110, 70, 404, 92)       # a themed card (design px 404 x 92) in an overlay with room for the oval
def render(**over):
    env = dict(os.environ, EGL_PLATFORM="surfaceless", LIBGL_ALWAYS_SOFTWARE="1")
    u = dict(urgency=1, vividness=0.75, ui=1.0, size=(W, H), card=CARD, shape=(1.12, 1.20, 3.0, 0.0), fill=(0.1, 0.08, 0.06, 0.95)); u.update(over)
    for k, v in u.items(): env["U_" + k] = ",".join(str(x) for x in v) if isinstance(v, (tuple, list)) else str(v)
    pam = f"{tmp}/o.pam"; subprocess.run([tmp + "/harness", f"{tmp}/b.glsl", str(W), str(H), pam], env=env, check=True, stderr=subprocess.DEVNULL)
    d = open(pam, "rb").read(); e = d.index(b"ENDHDR\n") + 7
    return d[e:]
def px(img, x, y): o = (int(y) * W + int(x)) * 4; return tuple(img[o:o + 4])
def alpha(img, x, y): return px(img, x, y)[3] / 255.0
CX, CY = CARD[0] + CARD[2] / 2, CARD[1] + CARD[3] / 2

# the mirror of BodyLogic.js
def oval_sd(x, y, a, b, n=3.0):
    ux, uy = max(abs(x) / a, 1e-4), max(abs(y) / b, 1e-4); g = (ux ** n + uy ** n) ** (1 / n)
    gx = g ** (1 - n) * ux ** (n - 1) / a; gy = g ** (1 - n) * uy ** (n - 1) / b
    return (g - 1) / math.hypot(gx, gy)
def feather(sd, ui=1.0):
    t = max(0.0, min(1.0, (sd + 22 * ui) / (44 * ui))); return 1 - t * t * (3 - 2 * t)
A, B = CARD[2] / 2 * 1.12, CARD[3] / 2 * 1.20
img = render()

# alpha: the fill's opacity, where it is solid; nothing far away; the right profile through the feather
check("body: solid at the middle (alpha is the fill's, 0.95)", abs(alpha(img, CX, CY) - 0.95) < 0.01, alpha(img, CX, CY))
check("body: solid in the text's corners (a card's content corner, 26 design px in from each side)", abs(alpha(img, CARD[0] + 26, CARD[1] + 18) - 0.95) < 0.03, alpha(img, CARD[0] + 26, CARD[1] + 18))
check("body: nothing 40 px beyond the oval's end, above it, or in the overlay's corner", alpha(img, CX + A + 40, CY) == 0 and alpha(img, CX, CY - B - 40) == 0 and alpha(img, 2, 2) == 0, (alpha(img, CX + A + 40, CY), alpha(img, CX, CY - B - 40)))
worst = 0
for y in range(4, H - 4, 3):
    for x in range(4, W - 4, 3):
        want = 0.95 * feather(oval_sd(x + 0.5 - CX, y + 0.5 - CY, A, B))
        worst = max(worst, abs(alpha(img, x, y) - want))
check("body: the alpha is the superellipse and the feather exactly (every 3rd pixel against the mirror of BodyLogic.js, within 0.02)", worst < 0.02, worst)
# soft edge: no step
steps = max(abs(alpha(img, x + 1, CY) - alpha(img, x, CY)) for x in range(int(CX), W - 2))
stepv = max(abs(alpha(img, CX, y + 1) - alpha(img, CX, y)) for y in range(int(CY), H - 2))
check("body: the edge is soft, not drawn: no pixel steps by more than 0.04 along the middle row or column (the steepest a 44 px smoothstep gets is 0.032)", steps < 0.04 and stepv < 0.04, (steps, stepv))
# the shape
check("body: wider than tall: about 23 px beyond the card's ends and 8 beyond its top at the outline (alpha about a half there: the feather is symmetric)", 0.35 < alpha(img, CX + A, CY) < 0.6 and 0.35 < alpha(img, CX, CY - B) < 0.6, (alpha(img, CX + A, CY), alpha(img, CX, CY - B)))
check("body: symmetric above and below, and left and right (to a pixel: the steepest the feather gets is 0.032 a pixel)", abs(alpha(img, CX, CY - 40) - alpha(img, CX, CY + 40)) < 0.045 and abs(alpha(img, CX - 150, CY - 20) - alpha(img, CX + 150, CY + 20)) < 0.045)
corner = alpha(img, CARD[0] + 2, CARD[1] + 2)
check("body: the card's own corners are cut: the outline passes inside them (a rectangle would be solid there)", corner < 0.6, corner)
check("body: exponent 3 is fuller than an ellipse: a point 80% along both axes is inside the outline for n=3 and outside it for n=2", oval_sd(0.8 * A * 0.84, 0.8 * B * 0.84, A, B, 3) < oval_sd(0.8 * A * 0.84, 0.8 * B * 0.84, A, B, 2))
bigger = render(shape=(1.30, 1.40, 3.0, 0.0))
check("body: the shape uniform sets the size (1.3 x 1.4 reaches 20 px further than 1.12 x 1.2 at the end)", alpha(bigger, CX + A + 16, CY) > alpha(img, CX + A + 16, CY) + 0.3, (alpha(bigger, CX + A + 16, CY), alpha(img, CX + A + 16, CY)))
# ui scales the feather
big = render(ui=2.0)
check("body: ui 2 doubles the feather: 26 px outside the outline it is still faintly there (at ui 1 it is gone from 22), and 24 px inside it is not yet solid (the mirror says so)", alpha(big, CX + A + 26, CY) > 0.01 and alpha(img, CX + A + 26, CY) == 0 and abs(alpha(big, CX + A - 24, CY) - 0.95 * feather(-24, 2.0)) < 0.02 and 0.95 * feather(-24, 2.0) < 0.9, (alpha(big, CX + A + 26, CY), alpha(img, CX + A + 26, CY), alpha(big, CX + A - 24, CY), 0.95 * feather(-24, 2.0)))
# colour: the fill is the card's colour, unpremultiplied
p = px(img, CX, CY)
check("body: the middle is the fill's colour times its alpha (premultiplied: 0.1, 0.08, 0.06 times 0.95)", all(abs(p[i] / 255.0 - (0.1, 0.08, 0.06)[i] * 0.95) < 0.012 for i in range(3)), p)
check("body: the fill's own opacity scales it (0.5 gives half)", abs(alpha(render(fill=(0.1, 0.08, 0.06, 0.5)), CX, CY) - 0.5) < 0.01)
check("body: qt_Opacity scales everything (0.5)", abs(alpha(render(qt_Opacity=0.5), CX, CY) - 0.475) < 0.01)
# the light on the edge
def light_at(img, x, y):                        # the added light: premultiplied colour above the alpha
    p = px(img, x, y); return tuple(max(0, p[i] - p[3] * (0.1, 0.08, 0.06)[i]) for i in range(3))
ex, ey = CX + A - 4, CY
n_, c_, l_ = [render(urgency=u) for u in (1, 2, 0)]
ln, lc, ll = [light_at(i, ex - 40, CY - B + 4) for i in (n_, c_, l_)]
check("body: the edge carries light: some at the outline, none at the middle", sum(light_at(img, CX + A - 6, CY)) > 8 and sum(light_at(img, CX, CY)) < 2, (light_at(img, CX + A - 6, CY), light_at(img, CX, CY)))
check("body: a normal toast's edge light is teal to blue, a critical one's amber to pink, a low one's moss (blue over red; red over blue; less blue than normal)",
      ln[2] > ln[0] and lc[0] > lc[2] and ll[2] < ln[2], (ln, lc, ll))
check("body: rim vividness 0 leaves less light on the edge than 1, but some", 0 < sum(light_at(render(vividness=0.0), CX + A - 6, CY)) < sum(light_at(render(vividness=1.0), CX + A - 6, CY)))
check("body: the edge light is faint: no brighter than a fifth of full anywhere", max(max(light_at(img, x, y)) for x in range(0, W, 5) for y in range(0, H, 5)) < 60)

print(f"{passed} passed, {failed} failed"); sys.exit(1 if failed else 0)
