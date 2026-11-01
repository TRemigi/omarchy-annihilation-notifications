#!/usr/bin/env python3
# Numeric tests of shaders/toastglow.frag and shaders/cardreveal.frag (compiled form), run on Mesa's software GL through
# test/shader-harness.c: where the light is, that it is added light, that it is the SAME light as the theme's window glow at the
# same place on the screen (when the theme repo is next door), that urgency leans it, the arrival's front and flare, the icon
# ring, the intensity and depth controls, the reveal mask, and that the shader's uniforms are the ones GlowRim.qml feeds.
#
#   python3 test/glow-test.py        (needs gcc, EGL and GLES headers, llvmpipe, qsb; standard library only)
import os, re, subprocess, sys, tempfile, math
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
QSB = "/usr/lib/qt6/bin/qsb"
THEME = os.environ.get("THEME_SHADERS", os.path.expanduser("~/dev/omarchy-annihilation-theme/extras/plugin/annihilation.shimmer/shaders"))
tmp = tempfile.mkdtemp()
passed = failed = skipped = 0
def check(name, ok, detail=""):
    global passed, failed
    if ok: passed += 1
    else: failed += 1; print("FAIL", name, detail)

def extract(qsb, name):
    out = f"{tmp}/{name}.glsl"; subprocess.run([QSB, "-x", "glsl,100 es", "-o", out, qsb], check=True); return out
SHADERS = os.environ.get("SHADERDIR", ROOT + "/shaders")      # a directory of mutated copies, to prove the checks can fail
GLOW = extract(SHADERS + "/toastglow.frag.qsb", "glow")
REVEAL = extract(SHADERS + "/cardreveal.frag.qsb", "reveal")
subprocess.run(["gcc", "-O2", ROOT + "/test/shader-harness.c", "-o", tmp + "/harness", "-lEGL", "-lGLESv2"], check=True)

def render(glsl, w, h, **u):
    env = dict(os.environ, EGL_PLATFORM="surfaceless", LIBGL_ALWAYS_SOFTWARE="1")
    for k, v in u.items(): env["U_" + k] = ",".join(str(x) for x in v) if isinstance(v, (tuple, list)) else str(v)
    pam = f"{tmp}/o.pam"; subprocess.run([tmp + "/harness", glsl, str(w), str(h), pam], env=env, check=True, stderr=subprocess.DEVNULL)
    d = open(pam, "rb").read(); e = d.index(b"ENDHDR\n") + 7; b = d[e:]
    return w, h, b
def px(img, x, y): w, h, b = img; o = (y * w + x) * 4; return tuple(b[o:o + 4])
def lum(p): return (299 * p[0] + 587 * p[1] + 114 * p[2]) / 1000

# the screen is 1880x1190 (the author's); the overlay is 540x200 at (1400,40) on it, the card 380x78 at (48,48) in it
SCREEN = (1880, 1190); OW, OH = 540, 200; M = 48; CW_, CH_ = 380, 78
base = dict(time=300.0, intensity=0.44, seed=53, rimWidth=30.94, depth=0.13, urgency=1, radius=4, front=-1, resolution=SCREEN,
            origin=(1400, 40), size=(OW, OH), card=(M, M, CW_, CH_), icon=(M + 34, M + 39, 17))
def glow(**over): return render(GLOW, OW, OH, **{**base, **over})
settled = glow()
def total(img): return sum(sum(img[2][i:i + 3]) for i in range(0, len(img[2]), 4))
def colour_dir(p): m = max(p[:3]) or 1; return tuple(c / m for c in p[:3])
def dist(a, b): return math.dist(a, b)

check("nothing is drawn far from the card (a corner of the overlay)", px(settled, 2, 2) == (0, 0, 0, 0), px(settled, 2, 2))
check("the output is added light: alpha is 0 everywhere", max(settled[2][3::4]) == 0)
check("the middle of the card, away from the edge and the icon, is dark", lum(px(settled, M + 250, M + 39)) < 10, px(settled, M + 250, M + 39))
edge = max(range(OH), key=lambda y: lum(px(settled, M + 190, y)) if y < M + 30 else -1)
check("the top edge is lit, and the brightest row is within 3 px of it", abs(edge - M) <= 3 and lum(px(settled, M + 190, edge)) > 40, (edge, px(settled, M + 190, edge)))
check("there is a halo outside the edge (where no glint sits), fainter than the edge itself", 4 < lum(px(settled, M + 60, M - 2)) < lum(px(settled, M + 60, M + 1)), (px(settled, M + 60, M - 2), px(settled, M + 60, M + 1)))
check("the light is gone 20 px outside the edge", lum(px(settled, M + 190, M - 20)) < 3)
check("and fades inside: 10 px in is much dimmer than the edge", lum(px(settled, M + 190, M + 10)) < 0.45 * lum(px(settled, M + 190, edge)))

# the same light as the theme's window glow
wg = THEME + "/windowglow.frag.qsb"
if os.path.exists(wg):
    src = subprocess.run([QSB, "-x", "glsl,100 es", "-o", tmp + "/wg0.glsl", wg], check=True)
    # the theme's shader draws a window's edge from the screen's top left; ask for just the strip we need by giving it the card as the
    # window: the same screen place, the same clock and seed
    def window(**over):
        u = dict(time=300.0, intensity=0.44, seed=53, additive=1, rimWidth=30.94, rounding=4, resolution=SCREEN, usable=(0, 0, SCREEN[0], SCREEN[1]),
                 cursor=(0, 0, 0, 0), cursorSpan=1.98, depth=0.21, centerGain=0.98, nearest=(0, 0, 1, 0), nearestPrev=(0, 0, 1, 0), pools=(0, 0, 0, 0),
                 win0=(1400 + M, 40 + M, CW_, CH_), win1=(0, 0, 0, 0), win2=(0, 0, 0, 0), win3=(0, 0, 0, 0), win4=(0, 0, 0, 0), win5=(0, 0, 0, 0))
        u.update(over); return u
    # render the whole screen at 1/1 only along one row's worth: the shader maps the whole viewport to the screen, so render it all
    W, H = SCREEN; full = render(tmp + "/wg0.glsl", W, H, **window())
    ok = []
    for xs in (60, 190, 330):
        sx, sy = 1400 + M + xs, 40 + M + 1                      # a point just inside the top edge
        a = colour_dir(px(full, sx, sy)); b = colour_dir(px(settled, M + xs, M + 1))
        ok.append(dist(a, b))
    check("the toast's edge has the same colour as a window's edge at the same place on the screen (three points)", max(ok) < 0.12, ok)
    other = render(tmp + "/wg0.glsl", W, H, **window(seed=11))
    check("(and the test could tell: another seed gives a different window colour there)", dist(colour_dir(px(other, 1400 + M + 190, 40 + M + 1)), colour_dir(px(full, 1400 + M + 190, 40 + M + 1))) > 0.12)
else:
    skipped += 1; print("skipped: the theme's windowglow.frag.qsb is not at", wg)

def hue_at(img, x, y): return colour_dir(px(img, x, y))
pts = [(M + 60, M + 1), (M + 190, M + 1), (M + 330, M + 1), (M + 190, M + CH_ - 2)]
def differs(a, b, tol=0.08): return max(dist(hue_at(a, *p), hue_at(b, *p)) for p in pts) > tol
check("another seed gives another colour", differs(settled, glow(seed=11)))
check("another time on the glow's clock gives another colour", differs(settled, glow(time=900.0)))
check("another place on the screen gives another colour", differs(settled, glow(origin=(900, 500))))
check("the screen's size matters (the fans are a field over the whole screen)", differs(settled, glow(resolution=(1280, 800))))

# controls
check("intensity 0 draws nothing at all", total(glow(intensity=0)) == 0)
check("a stronger glow is brighter", total(glow(intensity=0.9)) > 1.3 * total(settled))
check("a deeper band reaches further in (the same card, depth 0.5: more light 10 px inside)", lum(px(glow(depth=0.5), M + 190, M + 10)) > 2 * lum(px(settled, M + 190, M + 10)))
crit, low = glow(urgency=2), glow(urgency=0)
def rb(img): p = px(img, M + 190, M + 1); return p[0] - p[2]
check("a critical toast leans amber (red over blue more than a normal one)", rb(crit) > rb(settled) + 25, (rb(crit), rb(settled)))
check("a low toast leans green (less red over blue than a normal one)", rb(low) < rb(settled) or px(low, M + 190, M + 1)[1] > px(settled, M + 190, M + 1)[1], (px(low, M + 190, M + 1), px(settled, M + 190, M + 1)))

# the icon ring
ring = px(settled, M + 34 + 17, M + 39)
check("the icon has a ring, much brighter than the card beside it", lum(ring) > 40 and lum(px(settled, M + 34 + 17 + 6, M + 39)) < 0.4 * lum(ring), (ring, px(settled, M + 34 + 23, M + 39)))
check("and a spore at its centre", lum(px(settled, M + 34, M + 39)) > 30)
noicon = glow(icon=(0, 0, 0))
check("no icon, no ring", lum(px(noicon, M + 34 + 17, M + 39)) < 8)

# the arrival
far_x = M + 340
early = glow(front=30); late = glow(front=2000)
check("early in the arrival the far end of the card is dark (the front is still near the icon)", lum(px(early, far_x, M + 1)) < 3, px(early, far_x, M + 1))
check("while the icon's own ring is already there", lum(px(early, M + 34 + 17, M + 39)) > 30)
diff = max(abs(a - b) for a, b in zip(late[2], settled[2]))
check("once the front has crossed everything the picture is the settled one (within 2 levels)", diff <= 2, diff)
tx = far_x; front_here = math.hypot(tx - (M + 34), (M + 1) - (M + 39))
flare = glow(front=front_here)
check("as the front crosses an edge point it flares: clearly brighter than settled (the roll-off keeps it from doubling)", lum(px(flare, tx, M + 1)) > 1.15 * lum(px(settled, tx, M + 1)), (px(flare, tx, M + 1), px(settled, tx, M + 1)))
check("and behind the front it has settled to about the usual", lum(px(glow(front=front_here + 200), tx, M + 1)) < 1.3 * lum(px(settled, tx, M + 1)) + 6)
check("the front only ever adds to what is lit: the arriving picture never exceeds the flared one by much elsewhere", max(a - b for a, b in zip(early[2], settled[2])) < 120)
check("no icon: the front still leaves from the card's left and the far end waits", lum(px(glow(front=30, icon=(0, 0, 0)), far_x, M + 1)) < 3)

# the reveal mask: an unbound texture reads as opaque black, so its alpha is the mask
def mask(front, x, y): return px(render(REVEAL, 380, 78, front=front, size=(380, 78), icon=(34, 39)), x, y)[3]
check("reveal: the icon's own place is solid once the front has left it", mask(40, 34, 39) == 255)
check("reveal: far beyond the front is nothing yet", mask(40, 360, 39) == 0)
check("reveal: far behind the front is solid", mask(400, 360, 39) == 255)
check("reveal: the edge of the front is soft (some middle value close to it)", 0 < mask(200, 34 + 200, 39) < 255, mask(200, 234, 39))
check("reveal: it is round, centred on the icon (60 px across and 60 px diagonally are the same)", abs(mask(60, 94, 39) - mask(60, 82, 75)) < 4, (mask(60, 94, 39), mask(60, 82, 75)))

# the QML feeds exactly the uniforms the shaders declare
def uniforms(path):
    src = open(path).read(); body = src[src.index("uniform buf {"):src.index("} ubuf;")]
    return {m for m in re.findall(r"^\s*\w+(?: \w+)?\s+(\w+);", body, re.M) if m not in ("qt_Matrix", "qt_Opacity")}
def props(path, marker):
    src = open(path).read(); i = src.index(marker); blk = src[i:]
    return set(re.findall(r"^\s*property (?:real|size|vector2d|vector3d|vector4d) (\w+):", blk, re.M))
check("GlowRim's ShaderEffect feeds exactly toastglow.frag's uniforms", uniforms(SHADERS + "/toastglow.frag") == props(ROOT + "/components/GlowRim.qml", "  ShaderEffect {"),
      (uniforms(SHADERS + "/toastglow.frag") ^ props(ROOT + "/components/GlowRim.qml", "  ShaderEffect {")))
svc = open(ROOT + "/Service.qml").read(); blk = svc[svc.index("layer.effect: ShaderEffect {"):]
check("the card's layer effect feeds exactly cardreveal.frag's uniforms", uniforms(SHADERS + "/cardreveal.frag") == set(re.findall(r"^\s*property (?:real|size|vector2d) (\w+):", blk[:400], re.M)))
check("the committed .qsb files are built from the current sources (compile and compare)", all(
    subprocess.run([QSB, "--glsl", "100 es,120,150", "--hlsl", "50", "--msl", "12", "-o", f"{tmp}/c.qsb", f"{SHADERS}/{n}.frag"], check=True) is not None and
    subprocess.run(["cmp", "-s", f"{tmp}/c.qsb", f"{SHADERS}/{n}.frag.qsb"]).returncode == 0 for n in ("toastglow", "cardreveal")))

print(f"{passed} passed, {failed} failed" + (f", {skipped} skipped" if skipped else "")); sys.exit(1 if failed else 0)
