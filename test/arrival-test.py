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
CARD = (300, 100, 380, 78); ORIGIN = (490, 139)                # the card in the layer; the wave starts at its centre
RC = math.hypot(190, 39) + 30; WAVE = 309.0; REACH = 75.0     # the front runs WAVE beyond the card (the timing); the ring rests at 0.6 of REACH and the light stays within it
def ringsize(front): return 1 - math.exp(-max(0.0, front) / 110)       # the ring's size (ArrivalLogic.ringScale)
def ring(front=60.0, p=0.1, urgency=1, amp=1.0, strength=1.0, rect=CARD, radius=4, salt=0.0, scale=None, **over):
    src = (rect[0] + 190, rect[1] + 39, ringsize(front) if scale is None else scale, front)
    u = dict(seed=5, strength=strength, reach=REACH, radius=radius, resolution=(LW, LH), rect0=rect, rect1=(0, 0, 0, 0), rect2=(0, 0, 0, 0),
             src0=src, src1=(0, 0, 0, 0), src2=(0, 0, 0, 0), ev0=(p, urgency, amp, salt), ev1=(0, 1, 0, 0), ev2=(0, 1, 0, 0))
    u.update(over); return render(RING, LW, LH, **u)
def tfront(p): return (RC + WAVE) * (1 - (1 - p) ** 3)
base = ring(front=tfront(0.12), p=0.12)
check("ring: the output is added light (alpha 0 everywhere)", maxalpha(base) == 0)
check("ring: nothing is drawn under the card (the card hides it)", lum(px(base, 480, 139)) == 0 and lum(px(base, 330, 139)) == 0)
check("ring: nothing when the arrival has not started (progress 0)", total(ring(p=0.0)) == 0)
check("ring: progress 1 is not over, it is the held state: the ring rests and still draws", total(ring(front=RC + WAVE, p=1.0)) > 0.3 * total(base))
check("ring: nothing with no card (width 0)", total(ring(rect=(0, 0, 0, 0))) == 0)
check("ring: strength 0 draws nothing", total(ring(front=tfront(0.12), p=0.12, strength=0)) == 0)
check("ring: strength 2 is brighter than 1", total(ring(front=tfront(0.12), p=0.12, strength=2)) > 1.3 * total(base))
check("ring: amplitude scales it (0.5 is dimmer)", total(ring(front=tfront(0.12), p=0.12, amp=0.5)) < 0.8 * total(base))

# shaped by the card, and reached by the front
early = ring(front=70.0, p=0.03)       # the ring (an oval round the card) has just come out above and below the card, not yet at its ends
check("ring: early, the ring has come out above the card, over its middle (the oval's top, 7 px up), and is not yet out at the ends", lum(px(early, 490, 92)) > 3 * max(1, lum(px(early, 640, 92))) and lum(px(early, 490, 92)) > 3 * max(1, lum(px(early, 340, 92))), (px(early, 490, 92), px(early, 640, 92), px(early, 340, 92)))
check("ring: and both ends of the card have none yet (the front has not got there; it starts from the middle, so it is the same on both sides)", lum(px(early, 660, 100 - 10)) < 3 and lum(px(early, 690, 139)) < 3 and lum(px(early, 320, 100 - 10)) < 3 and lum(px(early, 290, 139)) < 3)
late = ring(front=tfront(0.12), p=0.12)
beyond = ring(front=tfront(0.3), p=0.3)
check("ring: later the wave has crossed the card and is out beyond both its ends", (lum(px(beyond, 700, 139)) > 4 or lum(px(beyond, 720, 139)) > 4) and (lum(px(beyond, 280, 139)) > 4 or lum(px(beyond, 260, 139)) > 4), (px(beyond, 700, 139), px(beyond, 720, 139), px(beyond, 280, 139), px(beyond, 260, 139)))
# the halo hugs the outline: equally far above and below a vertically-centred icon
h_top, h_bot = lum(px(late, 480, 100 - 8)), lum(px(late, 480, 178 + 8))
check("ring: the glow hugs the card's outline, the same above and below (the centre is centred)", h_top > 3 and abs(h_top - h_bot) < 0.25 * max(h_top, h_bot), (h_top, h_bot))
# the ring front itself: at front 70 the wave has gone 31 px past the top edge above the centre
mid = ring(front=70.0, p=0.05)
check("ring: the ring is a band of light, the oval's top above the middle of the card (at 92) and not a fill: dark 30 px further up", lum(px(mid, 490, 92)) > 8 and lum(px(mid, 490, 92)) > 2 * lum(px(mid, 490, 62)), (px(mid, 490, 92), px(mid, 490, 62)))

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
check("ring: the halo hugs the outline: strong beside it, gone within the hold reach (75 px) and a little more", lum(px(gone, 480, 186)) > 8 and lum(px(gone, 480, 178 + 8 + 100)) < 2, (px(gone, 480, 186), px(gone, 480, 286)))
check("ring: an out-of-range progress draws nothing (not garbage)", total(ring(p=1.5)) == 0 and total(ring(p=-0.5)) == 0, (total(ring(p=1.5)), total(ring(p=-0.5))))

# ---- lingering: the ring comes to rest at 0.6 * reach from the outline, all round, and stays within the hold reach
def peak(img, x, y0, direction, span=90):
    best = max(range(1, span), key=lambda k: lum(px(img, x, y0 + direction * k))); return best
def held(t=0.0, front=RC + WAVE, **kw): return ring(front=front, p=1.0, time=t, **kw)
h0 = held()
up, down = peak(h0, 480, 100, -1), peak(h0, 480, 178, 1)
check("held: the ring is an oval 0.8 * reach (60 px) above the card's top and below its bottom, over the middle", 45 <= up <= 75 and 45 <= down <= 75, (up, down))
lt, rt = peak(h0, 300, 139, -1), peak(h0, 680, 139, 1)   # (horizontal scans: use rows)
def peak_h(img, y, x0, direction, span=90): return max(range(1, span), key=lambda k: lum(px(img, x0 + direction * k, y)))
left, right = peak_h(h0, 139, 300, -1), peak_h(h0, 139, 680, 1)
check("held: and about 0.55 * reach (41 px) beyond the card's ends: an oval, wider than tall, not the card's outline offset (which would be 60 all round)", 25 <= left <= 58 and 25 <= right <= 58 and up - left >= 5, (left, right, up))
check("held: nothing beyond the reach (75 px) plus the width of the ring, above or below the card, at any of eight moments",
      all(max(lum(px(held(t), 480, y)) for y in (100 - 75 - 22, 178 + 75 + 22)) < 3 for t in (0, 1.3, 2.9, 4.4, 6.1, 7.7, 9.2, 11.5)),
      [(t, px(held(t), 480, 3), px(held(t), 480, 375)) for t in (0, 5)])
def edge_above(img, x):
    # where the ring's outer edge is above the card at column x: the first pixel, going in from the top of the layer, that is half as bright as the ring's peak (a position that
    # a change of brightness alone cannot move, unlike the brightest pixel)
    col = [lum(px(img, x, y)) for y in range(0, 100)]
    top = max(col[:92]); return next(100 - y for y, v in enumerate(col) if v >= 0.5 * top)
def ringpos(t):
    img = held(t); return [edge_above(img, x) for x in (340, 420, 490, 560, 640)]
pos = [ringpos(t) for t in (0, 1.5, 3.0, 4.5)]
check("held: it undulates: at some place the ring's distance changes with time, by several px", max(max(a) - min(a) for a in zip(*pos)) >= 4, pos)
check("held: and along the card at one moment (a ripple, not a uniform breath)", max(pos[0]) - min(pos[0]) >= 3, pos[0])
check("held: but only a ripple: at each place it stays within 35% of its own mean at all moments", all(0.65 * (sum(a) / len(a)) <= v <= 1.35 * (sum(a) / len(a)) for a in zip(*pos) for v in a), pos)
def above_sum(img): return sum(lum(px(img, x, y)) for x in range(300, 680, 4) for y in range(20, 70, 2))
above = [above_sum(held(t)) for t in (0, 1.5, 3.0, 4.5, 6.0)]
check("held: the halo stays beside the outline after the arrival is over (it used to fall to nothing with the ring)", lum(px(h0, 480, 100 - 8)) > 8 and lum(px(h0, 480, 178 + 8)) > 8, (px(h0, 480, 92), px(h0, 480, 186)))
check("held: it breathes in brightness: the light above the card (the ring, far from the halo) varies by 5 to 60% over time", 0.05 < (max(above) - min(above)) / min(above) < 0.6, above)
arr_a, arr_b = ring(front=tfront(0.12), p=0.12, time=0.0), ring(front=tfront(0.12), p=0.12, time=3.0)
check("held: while the arrival is still under way (progress 0.12) it does not undulate: the picture is the same at two times", total(arr_a) > 0 and abs(total(arr_a) - total(arr_b)) < 0.002 * total(arr_a), (total(arr_a), total(arr_b)))
def peak_lum(img): return max(lum(px(img, 490, 100 - k)) for k in range(1, 90))
check("held: the ring is dimmer than the arrival's passing one (so a ring that stays is not in the way)", peak_lum(h0) < 0.8 * peak_lum(arr_a), (peak_lum(h0), peak_lum(arr_a)))
peak_arr = ring(front=tfront(0.12), p=0.12)
fronts = [60, 80, 110, 160, 230, 330, 450, RC + WAVE]
sizes = [peak(ring(front=f, p=0.3, time=0.0), 490, 100, -1) if f >= 70 else 0 for f in fronts]
steps = [(b - a) / (f2 - f1) for a, b, f1, f2 in zip(sizes[1:], sizes[2:], fronts[1:], fronts[2:])]      # growth per px of front
check("held: arriving, the ring grows with the wave and eases into its size with no wall: it never shrinks, the growth per px of front only ever falls, and by the end is under 0.02 px per px, and never drops to under 30% of the step before (a wall: a clamp stops the ring dead)", all(b >= a - 1 for a, b in zip(sizes, sizes[1:])) and all(b <= a + 0.02 for a, b in zip(steps, steps[1:])) and steps[-1] <= 0.02 and steps[0] >= 0.25 and all(b >= 0.3 * a - 0.01 for a, b in zip(steps, steps[1:])), (sizes, steps))

# ---- the exit: from rest the front falls in and the ring is pulled onto the card
def xscale(f): return min(1.0, ringsize(RC + WAVE) * ringsize(f) / ringsize(RC + 75.0))      # the size on the way out (ArrivalLogic.ringScaleExit), from the resting size at the start
rest_start = ring(front=RC + 75.0, p=1.0, time=2.0, scale=xscale(RC + 75.0))
rest_far = ring(front=RC + WAVE, p=1.0, time=2.0)
check("exit: at q=0 (the front 75 px beyond the card's reach) the picture is exactly the resting one (no jump when the exit begins)", sum(abs(a - b) for a, b in zip(rest_start[2], rest_far[2])) < 0.001 * sum(rest_far[2]), (total(rest_start), total(rest_far)))
near_end = ring(front=RC - 40.0, p=1.0, time=2.0, scale=xscale(RC - 40.0))
check("exit: the ring shrinks all round as the front falls: above the middle and at the ends it is nearer the card than at rest", peak_h(near_end, 139, 680, 1) < peak_h(rest_far, 139, 680, 1) - 3 and peak(near_end, 490, 100, -1) < peak(rest_far, 490, 100, -1) - 4, (peak_h(near_end, 139, 680, 1), peak_h(rest_far, 139, 680, 1), peak(near_end, 490, 100, -1), peak(rest_far, 490, 100, -1)))
late_exit = ring(front=60.0, p=1.0, time=2.0, scale=xscale(60.0))
check("exit: later it has been pulled right in: what is left sits within 40 px of the top of the card and the light is under half of what it was", peak(late_exit, 490, 100, -1) <= 40 and total(late_exit) < 0.5 * total(rest_far), (peak(late_exit, 490, 100, -1), total(late_exit), total(rest_far)))
check("exit: with the front at -30 (the end) nothing is drawn", total(ring(front=-30.0, p=1.0, time=2.0)) < 0.01 * total(rest_far), total(ring(front=-30.0, p=1.0)))
check("exit: the ring brightens as it is pulled in (the amplitude the layer passes rises; the shader multiplies it)", total(ring(front=RC - 20, p=1.0, amp=1.7, time=2.0)) > 1.4 * total(ring(front=RC - 20, p=1.0, amp=1.0, time=2.0)))

# colours
def rgb_at(img, x, y): p = px(img, x, y); return p[:3]
nrm, crit, low = [ring(front=tfront(0.12), p=0.12, urgency=u) for u in (1, 2, 0)]
sr, sc, sl = [tuple(sum(img[2][i + c] for i in range(0, len(img[2]), 4)) for c in range(3)) for img in (nrm, crit, low)]
check("ring: a normal arrival is teal to blue (blue over red)", sr[2] > sr[0] * 1.2, sr)
check("ring: a critical one is amber to pink (red over blue)", sc[0] > sc[2] * 1.2, sc)
check("ring: a low one is moss to teal (less blue and more red than a normal one)", sl[2] / sl[1] < 0.8 * sr[2] / sr[1] and sl[0] / sl[2] > 1.3 * sr[0] / sr[2], (sl, sr))

# several arrivals at once are independent
two = ring(front=tfront(0.12), p=0.12, rect1=(300, 220, 380, 78), src1=(490, 259, RC, tfront(0.12)), ev1=(0.12, 2, 1.0, 1.3))
pt = (480, 310)
d_ = tuple(a - b for a, b in zip(px(two, *pt)[:3], px(late, *pt)[:3]))
check("ring: a second arrival draws its own light round its own card, and amber for critical (what it adds there is red, not blue)", d_[0] > 15 and d_[0] > 2 * d_[2], d_)

# ---- the oval body: nothing is hidden behind the card, and the halo hugs the oval, not the rectangle
SHAPE = (1.12, 1.20, 3.0, 1.0)         # BodyLogic: semi-axes 1.12 and 1.2 of the card's half-size, exponent 3; the last is "on"
on_, off_ = ring(front=RC + WAVE, p=1.0, shape=SHAPE), ring(front=RC + WAVE, p=1.0)
check("ring (oval body): nothing is hidden behind the card any more: the (faint) glow is drawn inside the card's rectangle near the oval's edge too; with no oval body it is not", lum(px(on_, 490, 108)) > lum(px(off_, 490, 108)), (px(on_, 490, 108), px(off_, 490, 108)))
halo_on, halo_off = ring(front=RC + WAVE, p=1.0, scale=0.0, shape=SHAPE), ring(front=RC + WAVE, p=1.0, scale=0.0)       # the ring shrunk to nothing: the halo alone
check("ring (oval body): the lamp-glow hugging the toast is nearly gone (it made a bright band against the soft body, which read as a hard edge): 22 px above the oval's top (y = 70, where the ring's own tail is negligible) it is under half of what it is at 30 px above a card's top edge", lum(px(halo_on, 490, 70)) < 0.5 * max(lum(px(halo_off, 490, 70)), 3), (px(halo_on, 490, 70), px(halo_off, 490, 70)))
check("ring (oval body): but it is there, faintly, past the oval's end (the tip is 23 px beyond the card's edge)", lum(px(halo_on, 720, 139)) > 0, px(halo_on, 720, 139))
# the ring is the toast's shape, a fixed gap outside it: the distance from the body's outline to the ring's peak is the same all round
def body_sd(x, y):
    a, b, n = 190 * 1.12, 39 * 1.20, 3.0
    ux, uy = max(abs(x - 490) / a, 1e-4), max(abs(y - 139) / b, 1e-4); g = (ux ** n + uy ** n) ** (1 / n)
    return (g - 1) / math.hypot(g ** (1 - n) * ux ** (n - 1) / a, g ** (1 - n) * uy ** (n - 1) / b)
ringfull = ring(front=RC + WAVE, p=0.45, time=0.0, shape=SHAPE, strength=1.0)       # before the ripple begins (it grows in from p = 0.5), so only the shape is measured
def ring_gap(dx, dy):
    n_ = math.hypot(dx, dy); dx, dy = dx / n_, dy / n_
    # along the ray from the centre (dx, dy), the signed distance to the body of the brightest pixel beyond the outline
    best = max(((lum(px(ringfull, 490 + dx * t, 139 + dy * t)), t) for t in [i * 0.5 for i in range(40, 800)] if 0 <= 490 + dx * t < LW and 0 <= 139 + dy * t < LH and body_sd(490 + dx * t, 139 + dy * t) > 8), default=(0, 0))
    return body_sd(490 + dx * best[1], 139 + dy * best[1])
# the directions: top, bottom, both ends, and through the body's corners (where an ellipse and the squarer body differ most: 79% along both axes)
CORNER = (212.8 * 0.794, -46.8 * 0.794)
gaps = [ring_gap(*d) for d in ((0, -1), (0, 1), (1, 0), (-1, 0), CORNER, (-CORNER[0], -CORNER[1]), (CORNER[0], -CORNER[1]), (-CORNER[0], CORNER[1]))]
check("ring (oval body): the ring is the toast's shape a fixed gap outside it: its distance from the body's outline (top, bottom, both ends, two diagonals) is the same all round (the ring is the body's outline offset by 0.6 * reach = 45 px, so within the ring's 2.5% bend and the sampling; offsetting the axes instead left 35 at the corners against 55 at the top)", max(gaps) - min(gaps) < 14 and 36 < sum(gaps) / len(gaps) < 58, gaps)
check("ring (oval body): the light is still only added light (alpha 0)", maxalpha(on_) == 0)
# the halo is revealed by the oval front: 8 px above the top edge, over the middle, an oval front of aspect 4.55 (212.8 / 46.8) has not got there at front 100 (it is 177 away), a circular one has (39 away)
h_oval, h_circ = ring(front=100.0, p=0.05, scale=0.0, shape=SHAPE), ring(front=100.0, p=0.05, scale=0.0)
check("ring (oval body): the halo comes in behind the oval front, not a circular one: above the middle of the card at front 100 it is not there yet with an oval body, and is there without", lum(px(h_oval, 490, 92)) < 0.25 * max(lum(px(h_circ, 490, 92)), 1) and lum(px(h_circ, 490, 92)) > 4, (px(h_oval, 490, 92), px(h_circ, 490, 92)))

# ---------------------------------------------------------------------------- the flare (on the card)
OW, OH = 460, 158; FC = (40, 40, 380, 78); FI = (74, 79, 17); FO = (230, 79)   # the card, the icon ring, the wave's origin (the card's centre)
def flare(front=100.0, fade=1.0, urgency=1, strength=1.0, icon=FI, reverse=0, origin=FO, aspect=1.0):
    return render(FLARE, OW, OH, strength=strength, urgency=urgency, radius=4, front=front, fade=fade, reverse=reverse, aspect=aspect, size=(OW, OH), card=FC, icon=icon, origin=origin)
fl = flare(front=120.0)
check("flare: the output is added light (alpha 0)", maxalpha(fl) == 0)
check("flare: nothing far from the card", lum(px(fl, 3, 3)) == 0 and lum(px(fl, 455, 150)) == 0)
check("flare: the middle of the card is dark", lum(px(fl, 300, 80)) < 4, px(fl, 300, 80))
check("flare: fade 0 draws nothing at all", total(flare(front=120.0, fade=0.0)) == 0)
check("flare: strength 0 draws nothing", total(flare(front=120.0, strength=0.0)) == 0)
check("flare: strength 2 is brighter", total(flare(front=120.0, strength=2.0)) > 1.2 * total(fl))
# the front's place on the top edge: at x where the distance from the icon is 120
fx = 230 + math.sqrt(120 ** 2 - 39 ** 2)       # right of the centre, along the top edge
check("flare: the edge is brightest where the front crosses it", lum(px(fl, fx, 40 + 1)) > 2 * lum(px(fl, fx + 60, 40 + 1)) and lum(px(fl, fx, 41)) > lum(px(fl, fx - 70, 41)) * 0.9, (px(fl, fx, 41), px(fl, fx + 60, 41), px(fl, fx - 70, 41)))
check("flare: ahead of the front the edge is dark (both ends of the card: it starts from the middle)", lum(px(fl, 400, 41)) < 4 and lum(px(fl, 60, 41)) < 4, (px(fl, 400, 41), px(fl, 60, 41)))
check("flare: behind the front there is an afterglow (the edge above the middle is lit, fainter than at the front)", 3 < lum(px(fl, 230, 41)) < lum(px(fl, fx, 41)), (px(fl, 230, 41), px(fl, fx, 41)))
born = flare(front=0.0)
check("flare: before the front has reached the icon (156 px from the centre) it is not lit", lum(px(born, 74, 79)) < 4 and lum(px(fl, 74, 79)) < 4, (px(born, 74, 79), px(fl, 74, 79)))
fi = flare(front=200.0)
check("flare: once it has, the icon has a spore and a ring", lum(px(fi, 74, 79)) > 40 and lum(px(fi, 74 + 17, 79)) > 30, (px(fi, 74, 79), px(fi, 91, 79)))
check("flare: no icon, no spore", lum(px(flare(front=200.0, icon=(0, 0, 0)), 74, 79)) < 6)
sp = flare(front=12.0)
check("flare: a spark at the card's centre where the wave starts, which has gone out by the time the front is 90 px out", lum(px(sp, 230, 79)) > 40 and lum(px(flare(front=100.0), 230, 79)) < 6, (px(sp, 230, 79), px(flare(front=100.0), 230, 79)))
crit_, norm_ = flare(front=120.0, urgency=2), flare(front=120.0, urgency=1)
def sums(img): return tuple(sum(img[2][i + c] for i in range(0, len(img[2]), 4)) for c in range(3))
check("flare: critical is amber (red over blue), normal teal (blue over red)", sums(crit_)[0] > sums(crit_)[2] * 1.2 and sums(norm_)[2] > sums(norm_)[0] * 1.1, (sums(crit_), sums(norm_)))
check("flare: a little halo outside the edge, none far out", lum(px(fl, fx, 40 - 2)) > 2 and lum(px(fl, fx, 40 - 20)) < 2, (px(fl, fx, 38), px(fl, fx, 20)))

# the exit: the arrival played backwards. The afterglow is a ghost of the edge on the side the front has left (further from the icon)
rv = flare(front=120.0, reverse=1)
gx = 230 + math.sqrt(135 ** 2 - 39 ** 2)   # 135 px from the centre along the top edge: 15 px beyond the front at 120
gi = 230 + math.sqrt(105 ** 2 - 39 ** 2)   # 105 px from the centre: 15 px inside the front
check("flare (exit): a smear of the edge lies just beyond the front, where the card is already gone (the edge 15 px beyond is brighter than 15 px inside, where the wavefront alone is the same)", lum(px(rv, gx, 41)) > 1.15 * lum(px(rv, gi, 41)), (px(rv, gx, 41), px(rv, gi, 41)))
tr = flare(front=40.0, reverse=1)
tx_near = 230 + math.sqrt(52 ** 2 - 39 ** 2)    # 12 px beyond the front along the top edge
check("flare (exit): and it is a short smear, not the whole outline: 12 px beyond the front it is lit, 60 px beyond it is nearly gone, and the far end of the card has none (the outline must not linger once the card has collapsed from it)",
      lum(px(tr, tx_near, 41)) > 8 and lum(px(tr, 230 + math.sqrt(100 ** 2 - 39 ** 2), 41)) < 0.25 * lum(px(tr, tx_near, 41)) and lum(px(tr, 400, 41)) < 3,
      (px(tr, tx_near, 41), px(tr, 230 + math.sqrt(100 ** 2 - 39 ** 2), 41), px(tr, 400, 41)))
check("flare (exit): and none on the side nearer the centre (the edge above the middle, which in the arrival glows behind the front)", lum(px(rv, 230, 41)) < 0.5 * lum(px(fl, 230, 41)), (px(rv, 230, 41), px(fl, 230, 41)))
check("flare (exit): the front still flares where it crosses the edge", lum(px(rv, fx, 41)) > 2 * lum(px(rv, fx - 70, 41)) and lum(px(rv, fx, 41)) > 20, (px(rv, fx, 41), px(rv, fx - 70, 41)))
check("flare (exit): the icon is still lit while the front is beyond it, and out when the front has retreated past it", lum(px(flare(front=200.0, reverse=1), 74, 79)) > 40 and lum(px(rv, 74, 79)) < 4)
check("flare (exit): the arrival's picture is unchanged by the flag being 0 (explicit 0 and absent are the same)", flare(front=120.0, reverse=0)[2] == fl[2])

# the oval body: the edge that flares is the oval's, not the card's rectangle
def flare_shape(front, shape, aspect=1.0): return render(FLARE, OW, OH, strength=1.0, urgency=1, radius=4, front=front, fade=1.0, reverse=0, aspect=aspect, size=(OW, OH), card=FC, icon=(0, 0, 0), origin=FO, shape=shape)
def edge_row(img, x, y0, y1): return max(range(y0, y1), key=lambda y: lum(px(img, x, y)))
fr, fo = flare_shape(400.0, (0, 0, 0, 0)), flare_shape(400.0, (1.12, 1.20, 3.0, 1.0))
check("flare (oval body): with none the edge that flares above the middle is the card's top (y = 40); with an oval body it is the oval's top, about 8 px higher (y = 32)", abs(edge_row(fr, 230, 20, 60) - 40) <= 2 and abs(edge_row(fo, 230, 20, 60) - 32) <= 3, (edge_row(fr, 230, 20, 60), edge_row(fo, 230, 20, 60)))
check("flare (oval body): and at the right end it is the oval's tip, 23 px beyond the card's edge (x = 443), not the card's (x = 420)", abs(max(range(380, 460), key=lambda x: lum(px(fo, x, 79))) - 443) <= 4 and abs(max(range(380, 460), key=lambda x: lum(px(fr, x, 79))) - 420) <= 3, (max(range(380, 460), key=lambda x: lum(px(fo, x, 79))), max(range(380, 460), key=lambda x: lum(px(fr, x, 79)))))
check("flare (oval body): added light still (alpha 0), and with shape off the picture is the old one", maxalpha(fo) == 0 and fr[2] == flare(front=400.0, icon=(0, 0, 0))[2])

# ---------------------------------------------------------------------------- the reveal mask (an unbound texture reads as opaque black: the alpha is the mask)
def mask(front, x, y, aspect=1.0): return px(render(REVEAL, 380, 78, front=front, aspect=aspect, size=(380, 78), origin=(190, 39)), x, y)[3]
check("reveal: the middle of the card is solid once the front has left it", mask(40, 190, 39) == 255)
check("reveal: far beyond the front is nothing yet, on both sides", mask(40, 360, 39) == 0 and mask(40, 20, 39) == 0)
check("reveal: far behind the front is solid", mask(400, 360, 39) == 255)
check("reveal: the edge of the front is soft", 0 < mask(100, 290, 39) < 255, mask(100, 290, 39))
check("reveal: it is round, centred on the card's middle (60 px across and 60 px diagonally are the same; and the same each side)", abs(mask(60, 250, 39) - mask(60, 236, 77)) < 20 and abs(mask(60, 250, 39) - mask(60, 130, 39)) < 20, (mask(60, 250, 39), mask(60, 236, 77), mask(60, 130, 39)))

# the oval front: with an aspect the front is an oval (the distance is stretched vertically), not a circle
check("reveal (oval front): with aspect 4, 30 px above the centre is as far as 120 px to the side: both are shown at front 160 and neither at 100", mask(100, 190, 39 - 30, 4.0) == 0 and mask(100, 190 + 120, 39, 4.0) == 0 and mask(160, 190, 39 - 30, 4.0) == 255 and mask(160, 190 + 120, 39, 4.0) == 255, [mask(100, 190, 9, 4.0), mask(100, 310, 39, 4.0), mask(160, 190, 9, 4.0), mask(160, 310, 39, 4.0)])
check("reveal (oval front): and with aspect 1 it is the circle it was (30 px above is shown at front 100)", mask(100, 190, 9, 1.0) == 255)
a4, a1 = flare(front=156.0, aspect=4.0), flare(front=156.0, aspect=1.0)
check("flare (oval front): with aspect 4 the wavefront is on the top edge above the middle at front 156 (39 px up, stretched 4 times), much brighter there than with a circular front, for which that edge is long since passed", lum(px(a4, 230, 41)) > 3 * lum(px(a1, 230, 41)), (px(a4, 230, 41), px(a1, 230, 41)))

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
svc = open(ROOT + "/Service.qml").read()
effects = [svc[m.start():][:400] for m in re.finditer(r"layer\.effect: ShaderEffect \{", svc)]
check("there are three reveal masks (the card, the rim on the way out, and the oval body)", len(effects) == 3, len(effects))
for n, blk in enumerate(effects):
    check(f"reveal mask {n + 1}'s layer effect feeds exactly cardreveal.frag's uniforms", uniforms(f"{SHADERS}/cardreveal.frag") == set(re.findall(r"^\s*property (?:real|size|vector2d) (\w+):", blk, re.M)))
check("the committed .qsb files are the sources compiled", all(
    subprocess.run([QSB, "--glsl", "100 es,120,150", "--hlsl", "50", "--msl", "12", "-o", f"{tmp}/c.qsb", f"{SHADERS}/{n}.frag"], check=True) is not None and
    subprocess.run(["cmp", "-s", f"{tmp}/c.qsb", f"{SHADERS}/{n}.frag.qsb"]).returncode == 0 for n in ("toastring", "toastflare", "cardreveal")))

print(f"{passed} passed, {failed} failed"); sys.exit(1 if failed else 0)
