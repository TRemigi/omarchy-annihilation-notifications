#version 440

// The arrival, outside the card: a ring of light, an oval round the card, that grows out of the card's centre, eases into a resting size and lingers there for
// the toast's life, undulating, and a halo that hugs the card's outline. When the toast leaves, the ring shrinks back onto the card.
//
// Drawn in one layer under the toast column (so each card hides the middle of its own light), for up to three arrivals at once. This replaces the theme's
// old arrival ring (theme repo, shaders/arrival.frag), whose source was a fixed box near the corner because the theme could not know where the card was.
//
// The ring is an ellipse centred on the card (an earlier version hugged the card's outline, which read as a rounded rectangle, and stopped at its resting distance
// with a hard clamp, which read as a wall). Its size `src.z` runs 0 to 1 (the layer eases it, with no stop: ArrivalLogic.ringScale) and scales the semi-axes from nothing to
// half the card plus 0.55 (across) and 0.8 (up and down) of `reach`: wider than tall, as the card is, but an oval, not a copy of its shape. A pixel's distance from the ring is the ellipse's own
// (the usual first-order distance), so the ring is as wide at the ends as on top. The halo is a function of the card's outline distance d (a lamp-glow in the card's shape,
// which is what a card's glow is) and rises behind the front, `src.w`, the radius the wave has reached (the same wave that reveals the card: cardreveal.frag, toastflare.frag).
//
// Progress 1 means "arrived", the held state; the layer keeps it until the toast leaves. Held, the ring undulates: its distance from the ellipse ripples slowly
// (two plane waves, travelling in `time`), it breathes, and the halo with it. On the way out the layer retreats the front and the size together.
//
// Colours are the theme's: normal teal to blue, critical amber to pink, low moss to teal; the arrival's own colour inside the ring
// and what it drifts to outside. Output is added light (colour above alpha), rolled off with 1 - exp(-x).
// Rebuild with tools/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float seed;
    float strength;   // the user's `arrival` setting, 0 to 2
    float reach;      // the arrival's largest extent beyond the card, px: the ring rests at 0.6 of it, and the halo falls away within it
    float radius;     // the cards' corner radius, px
    float time;       // seconds, for the held ring's undulation
    vec2 resolution;  // this layer, px
    vec4 rect0;       // each arrival's card in the layer: x, y, width, height; width <= 0 for none
    vec4 rect1;
    vec4 rect2;
    vec4 src0;        // the wave's origin x, y (the card's centre), the ring's size 0..1, the front's radius now
    vec4 src1;
    vec4 src2;
    vec4 ev0;         // progress 0..1 (1 is arrived: the held state; outside 0..1, off), urgency (0 low, 1 normal, 2 critical), amplitude, salt
    vec4 ev1;
    vec4 ev2;
    vec4 shape;       // the toast's oval body, when it has one: semi-axes as multiples of the card's half-size (x, y), the exponent (z), 1 if it has one (w)
} ubuf;

const vec3 N_IN = vec3(0.2000, 0.7686, 0.8157);
const vec3 N_OUT = vec3(0.4400, 0.4600, 0.9800);
const vec3 C_IN = vec3(0.9569, 0.6200, 0.1800);
const vec3 C_OUT = vec3(0.9490, 0.4784, 0.7000);
const vec3 L_IN = vec3(0.5300, 0.6900, 0.4200);
const vec3 L_OUT = vec3(0.2800, 0.6800, 0.7000);

// The distance to a superellipse centred on the origin (first order: (g - 1) / |grad g|), negative inside: the toast's oval body (toastbody.frag).
float ovalSd(vec2 p, vec2 ab, float n) {
    vec2 u = max(abs(p) / ab, vec2(1e-4));
    float g = pow(pow(u.x, n) + pow(u.y, n), 1.0 / n);
    vec2 gr = pow(g, 1.0 - n) * pow(u, vec2(n - 1.0)) / ab;
    return (g - 1.0) / max(length(gr), 1e-5);
}

vec3 arrival(vec2 px, vec4 rect, vec4 src, vec4 ev) {
    float p = ev.x;
    if (rect.z <= 0.0 || p <= 0.0 || p > 1.0) return vec3(0.0);

    vec3 inner = N_IN, outer = N_OUT;
    if (ev.y > 1.5) { inner = C_IN; outer = C_OUT; }
    else if (ev.y < 0.5) { inner = L_IN; outer = L_OUT; }

    // The card's rounded rectangle: the signed distance to it, and the nearest point of its outline.
    vec2 half_ = 0.5 * rect.zw;
    vec2 centre = rect.xy + half_;
    vec2 pp = px - centre;
    vec2 hi = max(half_ - vec2(ubuf.radius), vec2(0.0));
    vec2 c = clamp(pp, -hi, hi);
    vec2 v = pp - c;
    float vl = length(v);
    float sd = vl - ubuf.radius;                       // > 0 outside
    // The card hides what is under it, so fade out a little inside the outline, not outside it: no gap of dark right at the edge, no seam.
    // With an oval body (ubuf.shape.w) nothing is hidden here: the body is soft and covers the glow itself, which shows through its feathered edge, and the halo
    // hugs the oval, not the card's rectangle.
    bool oval = ubuf.shape.w > 0.5;
    float outside = oval ? 1.0 : smoothstep(-2.5, -0.5, sd);
    if (outside <= 0.0) return vec3(0.0);
    float sdOval = oval ? ovalSd(pp, 0.5 * rect.zw * ubuf.shape.xy, ubuf.shape.z) : sd;
    float d = max(sdOval, 0.0);
    vec2 q = centre + c + (vl > 1e-4 ? v / vl * ubuf.radius : vec2(0.0));
    // the front is an oval of the toast's proportions when it has an oval body (as in cardreveal.frag)
    float tEdge = length((q - src.xy) * (oval ? vec2(1.0, (ubuf.shape.x * rect.z) / (ubuf.shape.y * rect.w)) : vec2(1.0)));

    // How settled it is: the undulation grows in as the ring comes to rest.
    float held = smoothstep(0.5, 1.0, p);
    float t = ubuf.time;
    // plane waves in the layer's position, so the ripple is even all round the oval
    float ripple = 0.10 * sin(0.045 * px.x + 0.030 * px.y - 0.9 * t + ev.w) + 0.06 * sin(0.070 * px.x - 0.050 * px.y + 0.55 * t + 2.0 * ev.w) + 0.04 * sin(0.7 * t + ev.w);

    // A few per cent of bend (half as much round an oval body, so the ring keeps the toast's shape), smooth in position, so the ring is not a perfect ellipse.
    vec2 b = (px - centre) / (4.0 * ubuf.reach);
    float bend = 1.0 + (oval ? 0.025 : 0.05) * sin(b.x * 2.3 + ubuf.seed * 3.1 + ev.w) * sin(b.y * 2.9 + ubuf.seed * 1.7 + 2.0 * ev.w);
    // The ellipse and the pixel's distance from it (first order: k0 * (k0 - 1) / k1), plus the ripple.
    // With an oval body the ring is the set of points a fixed distance (0.6 of `reach`, times the growth) outside the body's own outline (offsetting the axes by equal amounts instead left a gap
    // of 55 px at the top and 35 at the corners), so it is exactly the toast's shape, and far enough out
    // to be a halo round the toast and not its border: nearer, the bright ring against the soft dark body read as a hard edge, most of all on a flat background. Without one it is an ellipse
    // (half the card plus 0.55 across and 0.8 up and down of `reach`).
    vec2 abBody = 0.5 * rect.zw * ubuf.shape.xy;
    float grow = clamp(src.z, 0.0, 1.0) * bend;
    vec2 ab = max((oval ? abBody : vec2(0.5 * rect.z + 0.55 * ubuf.reach, 0.5 * rect.w + 0.8 * ubuf.reach)) * grow, vec2(1.0));
    vec2 e = px - centre;
    float k0 = length(e / ab), k1 = length(e / (ab * ab));
    float dEll = oval ? ovalSd(e, ab, ubuf.shape.z) - 0.6 * ubuf.reach * grow : (k1 > 1e-6 ? k0 * (k0 - 1.0) / k1 : -min(ab.x, ab.y));
    dEll += 0.6 * ubuf.reach * ripple * held;

    float travel = 1.0 - pow(1.0 - p, 3.0);
    float w = ubuf.reach * (oval ? 0.08 + 0.24 * travel : 0.06 + 0.09 * travel);       // much wider and softer round an oval body: a band hugging a soft dark body read as its outline
    float s = dEll / w;
    float ring = exp(-0.5 * s * s) * (1.0 - smoothstep(3.2, 4.2, abs(s)));
    float ringLife = smoothstep(0.0, 0.07, p) * mix(oval ? 0.45 : 0.55, 1.0, (1.0 - p) * (1.0 - p)) * (1.0 + 0.18 * held * sin(0.030 * px.x + 0.050 * px.y + 0.8 * t + 1.7 * ev.w));
    vec3 ringCol = mix(inner, outer, smoothstep(-1.2, 1.6, s));

    // The halo: a lamp-glow round the outline, slower to rise, which stays (a little dimmer) while the ring rests, and only behind the front.
    float sigma = ubuf.reach * 0.3;
    float h = d / sigma;
    float halo = exp(-0.5 * h * h) * (1.0 - smoothstep(2.4, 3.4, h));
    // with an oval body the glow fades out inward as well, behind the body's feathered edge, instead of sitting at full strength right up to it (a bright outline round a dark oval)
    if (oval) halo *= smoothstep(-0.45 * ubuf.reach, 0.0, sdOval);
    float haloLife = smoothstep(0.0, 0.14, p) * mix(0.6, 1.0, pow(1.0 - p, 1.5)) * (1.0 + 0.15 * held * sin(0.9 * t + ev.w + 0.020 * px.x));
    float behind = 1.0 - smoothstep(src.w - 30.0, src.w + 40.0, tEdge);
    vec3 haloCol = mix(inner, vec3(1.0, 0.95, 0.88), 0.10);

    return (ringCol * ring * ringLife * 0.30 + haloCol * halo * haloLife * behind * (oval ? 0.03 : 0.15)) * ev.z * outside;
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.resolution;
    vec3 rgb = arrival(px, ubuf.rect0, ubuf.src0, ubuf.ev0) + arrival(px, ubuf.rect1, ubuf.src1, ubuf.ev1) + arrival(px, ubuf.rect2, ubuf.src2, ubuf.ev2);
    rgb = 1.0 - exp(-rgb * ubuf.strength * 2.0);
    fragColor = vec4(clamp(rgb, 0.0, 1.0), 0.0) * ubuf.qt_Opacity;
}
