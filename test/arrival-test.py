#!/usr/bin/env python3
# Numeric tests of the arrival's shaders (compiled form), run on Mesa's software GL through test/shader-harness.c:
#   toastring.frag   the ring and halo outside the card: shaped by the card's own outline, reached by the front, colours by urgency
#   toastflare.frag  the edge flare and the icon's spore on the card
#   cardreveal.frag  the mask that shows the card only inside the front
# and that the QML feeds exactly the uniforms the shaders declare, and that the committed .qsb files are the sources compiled.
#
#   python3 test/arrival-test.py        (needs gcc, EGL and GLES headers, llvmpipe, qsb; standard library only)
import math, os, re, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
QSB = "/usr/lib/qt6/bin/qsb"
SHADERS = os.environ.get("SHADERDIR", ROOT + "/shaders")      # a directory of mutated copies, to prove the checks can fail
tmp = tempfile.mkdtemp()
passed = failed = 0
def check(name, ok, detail=""):
    global passed, failed
    if ok: passed += 1
    else: failed += 1; print("FAIL", name, detail)

def extract(name):
    out = f"{tmp}/{name}.glsl"; subprocess.run([QSB, "-x", "glsl,100 es", "-o", out, f"{SHADERS}/{name}.frag.qsb"], check=True); return out
RING, FLARE, REVEAL = extract("toastring"), extract("toastflare"), extract("cardreveal")
subprocess.run(["gcc", "-O2", ROOT + "/test/shader-harness.c", "-o", tmp + "/harness", "-lEGL", "-lGLESv2"], check=True)

def render(glsl, w, h, **u):
    env = dict(os.environ, EGL_PLATFORM="surfaceless", LIBGL_ALWAYS_SOFTWARE="1")
    for k, v in u.items(): env["U_" + k] = ",".join(str(x) for x in v) if isinstance(v, (tuple, list)) else str(v)
    pam = f"{tmp}/o.pam"; subprocess.run([tmp + "/harness", glsl, str(w), str(h), pam], env=env, check=True, stderr=subprocess.DEVNULL)
    d = open(pam, "rb").read(); e = d.index(b"ENDHDR\n") + 7
    return w, h, d[e:]
def px(img, x, y): w, h, b = img; o = (int(y) * w + int(x)) * 4; return tuple(b[o:o + 4])
def lum(p): return (299 * p[0] + 587 * p[1] + 114 * p[2]) / 1000
def total(img): return sum(sum(img[2][i:i + 3]) for i in range(0, len(img[2]), 4))
def maxalpha(img): return max(img[2][3::4])

# ---------------------------------------------------------------------------- the ring (outside the card)
LW, LH = 900, 400
CARD = (300, 100, 380, 78); ICON = (334, 139)                  # the card in the layer; the icon 34 px in, centred on its height
RC = math.hypot(346, 39) + 30; REACH = 309.0
def ring(front=60.0, p=0.1, urgency=1, amp=1.0, strength=1.0, rect=CARD, radius=4, salt=0.0, **over):
    src = (rect[0] + 34, rect[1] + 39, RC, front)
    u = dict(seed=5, strength=strength, reach=REACH, radius=radius, resolution=(LW, LH), rect0=rect, rect1=(0, 0, 0, 0), rect2=(0, 0, 0, 0),
             src0=src, src1=(0, 0, 0, 0), src2=(0, 0, 0, 0), ev0=(p, urgency, amp, salt), ev1=(0, 1, 0, 0), ev2=(0, 1, 0, 0))
    u.update(over); return render(RING, LW, LH, **u)
def tfront(p): return (RC + REACH) * (1 - (1 - p) ** 3)
base = ring(front=tfront(0.12), p=0.12)
check("ring: the output is added light (alpha 0 everywhere)", maxalpha(base) == 0)
check("ring: nothing is drawn under the card (the card hides it)", lum(px(base, 480, 139)) == 0 and lum(px(base, 330, 139)) == 0)
check("ring: nothing when the arrival has not started (progress 0)", total(ring(p=0.0)) == 0)
check("ring: nothing when it is over (progress 1)", total(ring(p=1.0)) == 0)
check("ring: nothing with no card (width 0)", total(ring(rect=(0, 0, 0, 0))) == 0)
check("ring: strength 0 draws nothing", total(ring(front=tfront(0.12), p=0.12, strength=0)) == 0)
check("ring: strength 2 is brighter than 1", total(ring(front=tfront(0.12), p=0.12, strength=2)) > 1.3 * total(base))
check("ring: amplitude scales it (0.5 is dimmer)", total(ring(front=tfront(0.12), p=0.12, amp=0.5)) < 0.8 * total(base))

# shaped by the card, and reached by the front
early = ring(front=40.0, p=0.02)
check("ring: early, light leaves the edge nearest the icon (just above the card, over the icon)", lum(px(early, 334, 100 - 10)) > 3 * max(1, lum(px(early, 640, 100 - 10))), (px(early, 334, 90), px(early, 640, 90)))
check("ring: and the far end of the card has none yet (the front has not got there)", lum(px(early, 660, 100 - 10)) < 3 and lum(px(early, 690, 139)) < 3)
late = ring(front=tfront(0.12), p=0.12)
beyond = ring(front=tfront(0.3), p=0.3)
check("ring: later the wave has crossed the card and is out beyond its far end", lum(px(beyond, 700, 139)) > 4 or lum(px(beyond, 720, 139)) > 4, (px(beyond, 700, 139), px(beyond, 720, 139)))
# the halo hugs the outline: equally far above and below a vertically-centred icon
h_top, h_bot = lum(px(late, 480, 100 - 8)), lum(px(late, 480, 178 + 8))
check("ring: the glow hugs the card's outline, the same above and below (the icon is centred)", h_top > 3 and abs(h_top - h_bot) < 0.25 * max(h_top, h_bot), (h_top, h_bot))
# the ring front itself: at this front, the outline-distance contour near the icon vs far from it
mid = ring(front=100.0, p=0.05)
check("ring: the front is a thin band of light (bright where it is, dim a few widths away)", lum(px(mid, 334, 100 - (100 - 39))) > 2 * lum(px(mid, 334, 100 - (100 - 39) - 40)) or lum(px(mid, 334, 100 - (100 - 39))) > 8, (px(mid, 334, 61), px(mid, 334, 21)))

# it follows the card, and its corner radius
ca = (300, 160, 380, 78); cb = (400, 200, 380, 78)
moved0 = ring(front=90.0, p=0.04, rect=ca)
moved = ring(front=90.0, p=0.04, rect=cb)
def centroid(img):
    w, h, b = img; sx = sy = n = 0
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            l = lum(px(img, x, y)); sx += x * l; sy += y * l; n += l
    return (sx / n, sy / n)
c0, c1 = centroid(moved0), centroid(moved)
check("ring: it follows the card's rectangle (moving the card 100 right and 40 down moves the light with it)", abs((c1[0] - c0[0]) - 100) < 25 and abs((c1[1] - c0[1]) - 40) < 25, (c0, c1))
sharp, round_ = ring(front=tfront(0.12), p=0.12, radius=0), ring(front=tfront(0.12), p=0.12, radius=24)
check("ring: the card's corner radius shapes the light (a square corner and a round one differ)", sum(abs(a - b) for a, b in zip(sharp[2], round_[2])) > 20000)

# continuity across the outline: no seam
seam = max(abs(lum(px(late, x, 100 - 1 - k)) - lum(px(late, x, 100 - k))) for x in range(400, 600, 20) for k in range(0, 3))
check("ring: no seam at the card's outline (neighbouring pixels differ by little)", seam < 25, seam)

# the halo: a lamp-glow in the card's shape that is still there after the ring has gone on, and rises only behind the front
gone = ring(front=800.0, p=0.5)
check("ring: the halo is still there after the ring has gone on (the front is far out)", lum(px(gone, 480, 100 - 8)) > 8 and lum(px(gone, 480, 178 + 8)) > 8, (px(gone, 480, 92), px(gone, 480, 186)))
check("ring: the halo is not there before the front has reached that part of the card (far end, front still near the icon)", lum(px(ring(front=40.0, p=0.15), 650, 100 - 8)) < 3 and lum(px(gone, 650, 100 - 8)) > 5, (px(ring(front=40.0, p=0.15), 650, 92), px(gone, 650, 92)))
check("ring: the halo hugs the outline: strong beside it, gone about three widths (200 px) out", lum(px(gone, 480, 186)) > 8 and lum(px(gone, 480, 178 + 8 + 190)) < 4, (px(gone, 480, 186), px(gone, 480, 376)))
check("ring: an out-of-range progress draws nothing (not garbage)", total(ring(p=1.5)) == 0 and total(ring(p=-0.5)) == 0, (total(ring(p=1.5)), total(ring(p=-0.5))))

# colours
def rgb_at(img, x, y): p = px(img, x, y); return p[:3]
nrm, crit, low = [ring(front=tfront(0.12), p=0.12, urgency=u) for u in (1, 2, 0)]
sr, sc, sl = [tuple(sum(img[2][i + c] for i in range(0, len(img[2]), 4)) for c in range(3)) for img in (nrm, crit, low)]
check("ring: a normal arrival is teal to blue (blue over red)", sr[2] > sr[0] * 1.2, sr)
check("ring: a critical one is amber to pink (red over blue)", sc[0] > sc[2] * 1.2, sc)
check("ring: a low one is moss to teal (less blue and more red than a normal one)", sl[2] / sl[1] < 0.8 * sr[2] / sr[1] and sl[0] / sl[2] > 1.3 * sr[0] / sr[2], (sl, sr))

# several arrivals at once are independent
two = ring(front=tfront(0.12), p=0.12, rect1=(300, 220, 380, 78), src1=(334, 259, RC, tfront(0.12)), ev1=(0.12, 2, 1.0, 1.3))
below_only = lum(px(two, 480, 220 + 90)) 
check("ring: a second arrival draws its own light round its own card (and amber for critical)", below_only > lum(px(late, 480, 220 + 90)) and px(two, 480, 220 + 90)[0] > px(two, 480, 220 + 90)[2], (px(two, 480, 310), px(late, 480, 310)))

# ---------------------------------------------------------------------------- the flare (on the card)
OW, OH = 460, 158; FC = (40, 40, 380, 78); FI = (74, 79, 17)
def flare(front=100.0, fade=1.0, urgency=1, strength=1.0, icon=FI):
    return render(FLARE, OW, OH, strength=strength, urgency=urgency, radius=4, front=front, fade=fade, size=(OW, OH), card=FC, icon=icon)
fl = flare(front=120.0)
check("flare: the output is added light (alpha 0)", maxalpha(fl) == 0)
check("flare: nothing far from the card", lum(px(fl, 3, 3)) == 0 and lum(px(fl, 455, 150)) == 0)
check("flare: the middle of the card is dark", lum(px(fl, 300, 80)) < 4, px(fl, 300, 80))
check("flare: fade 0 draws nothing at all", total(flare(front=120.0, fade=0.0)) == 0)
check("flare: strength 0 draws nothing", total(flare(front=120.0, strength=0.0)) == 0)
check("flare: strength 2 is brighter", total(flare(front=120.0, strength=2.0)) > 1.2 * total(fl))
# the front's place on the top edge: at x where the distance from the icon is 120
fx = 74 + math.sqrt(120 ** 2 - 39 ** 2)
check("flare: the edge is brightest where the front crosses it", lum(px(fl, fx, 40 + 1)) > 2 * lum(px(fl, fx + 80, 40 + 1)) and lum(px(fl, fx, 41)) > lum(px(fl, fx - 70, 41)) * 0.9, (px(fl, fx, 41), px(fl, fx + 80, 41), px(fl, fx - 70, 41)))
check("flare: ahead of the front the edge is dark (the far end of the card)", lum(px(fl, 400, 41)) < 4, px(fl, 400, 41))
check("flare: behind the front there is an afterglow (the left edge is lit, fainter than at the front)", 3 < lum(px(fl, 60, 41)) < lum(px(fl, fx, 41)), (px(fl, 60, 41), px(fl, fx, 41)))
born = flare(front=0.0)
check("flare: before the front has left, the spore is not yet lit", lum(px(born, 74, 79)) < 4, px(born, 74, 79))
check("flare: once it has, the icon has a spore and a ring", lum(px(fl, 74, 79)) > 40 and lum(px(fl, 74 + 17, 79)) > 30, (px(fl, 74, 79), px(fl, 91, 79)))
check("flare: no icon, no spore", lum(px(flare(front=120.0, icon=(0, 0, 0)), 74, 79)) < 6)
crit_, norm_ = flare(front=120.0, urgency=2), flare(front=120.0, urgency=1)
def sums(img): return tuple(sum(img[2][i + c] for i in range(0, len(img[2]), 4)) for c in range(3))
check("flare: critical is amber (red over blue), normal teal (blue over red)", sums(crit_)[0] > sums(crit_)[2] * 1.2 and sums(norm_)[2] > sums(norm_)[0] * 1.1, (sums(crit_), sums(norm_)))
check("flare: a little halo outside the edge, none far out", lum(px(fl, fx, 40 - 2)) > 2 and lum(px(fl, fx, 40 - 20)) < 2, (px(fl, fx, 38), px(fl, fx, 20)))

# ---------------------------------------------------------------------------- the reveal mask (an unbound texture reads as opaque black: the alpha is the mask)
def mask(front, x, y): return px(render(REVEAL, 380, 78, front=front, size=(380, 78), icon=(34, 39)), x, y)[3]
check("reveal: the icon's own place is solid once the front has left it", mask(40, 34, 39) == 255)
check("reveal: far beyond the front is nothing yet", mask(40, 360, 39) == 0)
check("reveal: far behind the front is solid", mask(400, 360, 39) == 255)
check("reveal: the edge of the front is soft", 0 < mask(200, 234, 39) < 255, mask(200, 234, 39))
check("reveal: it is round, centred on the icon (60 px across and 60 px diagonally are the same)", abs(mask(60, 94, 39) - mask(60, 82, 75)) < 4, (mask(60, 94, 39), mask(60, 82, 75)))

# ---------------------------------------------------------------------------- the QML feeds what the shaders declare
def uniforms(path):
    src = open(path).read(); body = src[src.index("uniform buf {"):src.index("} ubuf;")]
    return {m for m in re.findall(r"^\s*\w+(?: \w+)?\s+(\w+);", body, re.M) if m not in ("qt_Matrix", "qt_Opacity")}
def props(path, marker):
    src = open(path).read(); blk = src[src.index(marker):]
    return set(re.findall(r"^\s*property (?:real|size|vector2d|vector3d|vector4d) (\w+):", blk, re.M))
for shader, qml, marker in (("toastring", "components/ArrivalLayer.qml", "  ShaderEffect {"), ("toastflare", "components/ArrivalFlare.qml", "  ShaderEffect {")):
    a, b = uniforms(f"{SHADERS}/{shader}.frag"), props(f"{ROOT}/{qml}", marker)
    check(f"{qml}'s ShaderEffect feeds exactly {shader}.frag's uniforms", a == b, a ^ b)
svc = open(ROOT + "/Service.qml").read(); blk = svc[svc.index("layer.effect: ShaderEffect {"):][:400]
check("the card's layer effect feeds exactly cardreveal.frag's uniforms", uniforms(f"{SHADERS}/cardreveal.frag") == set(re.findall(r"^\s*property (?:real|size|vector2d) (\w+):", blk, re.M)))
check("the committed .qsb files are the sources compiled", all(
    subprocess.run([QSB, "--glsl", "100 es,120,150", "--hlsl", "50", "--msl", "12", "-o", f"{tmp}/c.qsb", f"{SHADERS}/{n}.frag"], check=True) is not None and
    subprocess.run(["cmp", "-s", f"{tmp}/c.qsb", f"{SHADERS}/{n}.frag.qsb"]).returncode == 0 for n in ("toastring", "toastflare", "cardreveal")))

print(f"{passed} passed, {failed} failed"); sys.exit(1 if failed else 0)
