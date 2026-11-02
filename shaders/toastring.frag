#version 440

// The arrival, outside the card: a ring of light that leaves the toast's own outline, travels out to a resting distance and lingers there for the
// toast's life, undulating, and a halo that hugs the outline. When the toast leaves, the ring collapses back onto the card.
//
// Drawn in one layer under the toast column (so each card hides the middle of its own light), top right, for up to three arrivals
// at once. This replaces the theme's old arrival ring (theme repo, shaders/arrival.frag), whose source was a fixed box near
// the corner because the theme could not know where the card was. The fork does: every arrival carries its card's real rectangle,
// so the ring and the halo have the card's own shape and corner radius.
//
// One wave leaves the card's centre (`src`: its x, y, the radius at which the front has crossed the whole card, the front's radius now).
// Inside the card it is the front that reveals the card (cardreveal.frag) and flares its edge (toastflare.frag); here it carries
// on outside. A pixel outside the card is reached by the front at `F = d + |src - q|`, where d is its distance from the outline
// and q the nearest point of the outline: the wave crosses the outline at q, then travels d further. Near the card that makes the
// ring hug the outline, bulging where the centre is closest and lagging at the far end; far away F tends to the plain distance from the
// icon, so it rounds off into a circle. The halo is a function of d alone (a lamp-glow in the card's shape) and rises behind the front.
//
// The ring does not travel on for ever: it comes to rest at `0.6 * reach` from the outline (the arrival's largest extent on screen is about `reach`), the same
// all round, and stays (progress 1 means "arrived", the held state; the layer keeps it until the toast leaves). Held, it undulates: its distance from the outline
// ripples slowly round the card (two plane waves along the outline, travelling in `time`), it breathes, and the halo with it. On the way out the layer retreats the
// front (src.w) from where the ring rests to nothing, so the ring is pulled in onto the outline and the card with it.
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
    vec4 src0;        // the wave's origin x, y (the card's centre), the front's radius when it has crossed the card, the front's radius now
    vec4 src1;
    vec4 src2;
    vec4 ev0;         // progress 0..1 (1 is arrived: the held state; outside 0..1, off), urgency (0 low, 1 normal, 2 critical), amplitude, salt
    vec4 ev1;
    vec4 ev2;
} ubuf;

const vec3 N_IN = vec3(0.2000, 0.7686, 0.8157);
const vec3 N_OUT = vec3(0.4400, 0.4600, 0.9800);
const vec3 C_IN = vec3(0.9569, 0.6200, 0.1800);
const vec3 C_OUT = vec3(0.9490, 0.4784, 0.7000);
const vec3 L_IN = vec3(0.5300, 0.6900, 0.4200);
const vec3 L_OUT = vec3(0.2800, 0.6800, 0.7000);

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
    float outside = smoothstep(-2.5, -0.5, sd);
    if (outside <= 0.0) return vec3(0.0);
    float d = max(sd, 0.0);
    vec2 q = centre + c + (vl > 1e-4 ? v / vl * ubuf.radius : vec2(0.0));
    float tEdge = length(q - src.xy);

    // How settled it is: the undulation grows in as the ring comes to rest.
    float held = smoothstep(0.5, 1.0, p);
    float t = ubuf.time;
    // plane waves in the outline's position (not in its angle round the card, which is squeezed to a kink across the middle of a wide card's top and bottom)
    float ripple = 0.10 * sin(0.045 * q.x + 0.030 * q.y - 0.9 * t + ev.w) + 0.06 * sin(0.070 * q.x - 0.050 * q.y + 0.55 * t + 2.0 * ev.w) + 0.04 * sin(0.7 * t + ev.w);
    float rest = 0.6 * ubuf.reach * (1.0 + ripple * held);

    // A few per cent of bend, smooth in position, so the ring is not a perfect contour.
    vec2 b = (px - centre) / (4.0 * ubuf.reach);
    float bend = 1.0 + 0.06 * sin(b.x * 2.3 + ubuf.seed * 3.1 + ev.w) * sin(b.y * 2.9 + ubuf.seed * 1.7 + 2.0 * ev.w);
    // The front reaches the outline at q when it has gone tEdge, then travels on out; the ring stops at its resting distance.
    float dRing = min(src.w / bend - tEdge, rest);

    float travel = 1.0 - pow(1.0 - p, 3.0);
    float w = ubuf.reach * (0.06 + 0.09 * travel);
    float s = (d - dRing) / w;
    float ring = exp(-0.5 * s * s) * (1.0 - smoothstep(3.2, 4.2, abs(s)));
    float ringLife = smoothstep(0.0, 0.07, p) * mix(0.55, 1.0, (1.0 - p) * (1.0 - p)) * (1.0 + 0.18 * held * sin(0.030 * q.x + 0.050 * q.y + 0.8 * t + 1.7 * ev.w));
    vec3 ringCol = mix(inner, outer, smoothstep(-1.2, 1.6, s));

    // The halo: a lamp-glow round the outline, slower to rise, which stays (a little dimmer) while the ring rests, and only behind the front.
    float sigma = ubuf.reach * 0.3;
    float h = d / sigma;
    float halo = exp(-0.5 * h * h) * (1.0 - smoothstep(2.4, 3.4, h));
    float haloLife = smoothstep(0.0, 0.14, p) * mix(0.6, 1.0, pow(1.0 - p, 1.5)) * (1.0 + 0.15 * held * sin(0.9 * t + ev.w + 0.020 * q.x));
    float behind = 1.0 - smoothstep(src.w - 30.0, src.w + 40.0, tEdge);
    vec3 haloCol = mix(inner, vec3(1.0, 0.95, 0.88), 0.10);

    return (ringCol * ring * ringLife * 0.30 + haloCol * halo * haloLife * behind * 0.15) * ev.z * outside;
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.resolution;
    vec3 rgb = arrival(px, ubuf.rect0, ubuf.src0, ubuf.ev0) + arrival(px, ubuf.rect1, ubuf.src1, ubuf.ev1) + arrival(px, ubuf.rect2, ubuf.src2, ubuf.ev2);
    rgb = 1.0 - exp(-rgb * ubuf.strength * 2.0);
    fragColor = vec4(clamp(rgb, 0.0, 1.0), 0.0) * ubuf.qt_Opacity;
}
