#version 440

// The "Growth" look for a toast (an alternative to toastrim.frag, chosen with `look=growth`): the card as something alive.
// The same overlay, the same uniforms and the same added-light output as toastrim.frag, so ToastRim swaps one for the other.
//
// What the first mock-up of this direction got wrong was geometry that read as a glitch: a wavy outline and a ragged strip.
// So nothing here is a distorted shape. The outline stays straight and is *alive* instead: its thickness and colour vary
// slowly along its length in colonies (moss, teal), its edge moves less than a pixel, and a slow pulse of sap travels
// round it. Lichen is a scatter of tiny dots clustered in patches on the left edge inside the card (not a strip), thinning
// as it goes in. Veins are fine curves with side branches that reach from the four corners: out into the free space on the
// left, in across the card on the right; they grow out when the toast arrives (`growth`, 0 to 1) and then stay faint.
// The countdown is the bottom border itself, lit as a vein whose thickness undulates, retreating to a bud.
//
// `energy`, `vividness`, `urgency`, `remaining` and `spores` mean what they mean in toastrim.frag. `seed` makes every toast
// grow differently; `growth` is how far through its life the toast is: the roots grow over all of it, each starting and finishing at its own moment, the last just before the countdown ends.
//
// Rebuild with tools/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;        // seconds, for the slow drift of the colour and the sap
    float energy;      // 1 settled, above 1 while igniting
    float vividness;   // 0 to 1: how saturated and strong the light is
    float urgency;     // 0 low, 1 normal, 2 critical
    float radius;      // the card's corner radius, px
    vec2 size;         // the overlay's size, px
    vec4 card;         // the card inside it: x, y, width, height, px
    vec3 icon;         // the icon ring: centre x, centre y, radius; radius <= 0 for none
    float remaining;   // 0 to 1: the toast's life left; negative for none
    float spores;      // 0 to 1: the faint spores off the left edge (the user's spore_amount); 0 for none
    float seed;        // per toast, so no two grow alike
    float growth;      // 0 to 1: how far through its life the toast is (never goes back); the roots grow over it
} ubuf;

// Living colours: moss and teal for a normal toast, a darker moss for a low one, embers for a critical one.
vec3 palette(float t, float urgency) {
    vec3 a, b, c;
    if (urgency > 1.5) {
        a = vec3(0.96, 0.62, 0.18); b = vec3(0.92, 0.45, 0.16); c = vec3(0.90, 0.40, 0.50);
    } else if (urgency < 0.5) {
        a = vec3(0.42, 0.62, 0.36); b = vec3(0.30, 0.62, 0.52); c = vec3(0.42, 0.60, 0.40);
    } else {
        a = vec3(0.50, 0.74, 0.38); b = vec3(0.20, 0.76, 0.70); c = vec3(0.30, 0.66, 0.86);
    }
    t = clamp(t, 0.0, 1.0) * 2.0;
    return t < 1.0 ? mix(a, b, t) : mix(b, c, t - 1.0);
}

float hash(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec3 desaturate(vec3 c) { // 0 vividness is a muted version of the same colour
    return mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, 0.55 + 0.45 * ubuf.vividness);
}

// The same few faint spores as toastrim.frag: they leave the left edge and drift away into the free space.
vec3 ambientSpores(vec2 px) {
    float left = ubuf.card.x;
    if (px.x > left + 1.0 || px.x < left - 56.0) return vec3(0.0);
    if (px.y < ubuf.card.y - 10.0 || px.y > ubuf.card.y + ubuf.card.w + 10.0) return vec3(0.0);
    vec3 acc = vec3(0.0);
    for (int i = 0; i < 6; i++) {
        float k = float(i) * 3.17 + 1.3;
        float h1 = hash(k), h2 = hash(k + 1.0), h3 = hash(k + 2.0), h4 = hash(k + 3.0);
        float phase = fract(ubuf.time / (5.0 + 3.5 * h2) + h3);
        float y0 = ubuf.card.y + (0.12 + 0.76 * h1) * ubuf.card.w;
        float travel = 46.0 * (1.0 - (1.0 - phase) * (1.0 - phase));
        vec2 p = vec2(left + 1.0 - travel, y0 + (3.0 + 3.0 * h4) * sin(6.2832 * (phase * 1.5 + h1)) + 4.0 * phase);
        float r = length(px - p);
        float s = 0.8 + 0.6 * h4;
        float env = pow(sin(3.14159 * phase), 1.5);
        vec3 col = h4 < 0.5 ? vec3(0.96, 0.62, 0.18) : palette(0.4, ubuf.urgency);
        acc += col * (exp(-pow(r / s, 2.0)) * 0.9 + exp(-pow(r / (3.4 * s), 2.0)) * 0.15) * env;
    }
    return acc * smoothstep(left + 1.0, left - 3.0, px.x);
}

float roundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - (halfSize - vec2(r));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// A vein: a curve of up to 12 short steps whose heading turns smoothly (two slow sine waves, different per vein), thinning
// and dimming toward its tip. `reach` (0 to 1) is how much of it has grown; the step being grown is drawn part way.
// Returns its brightness at px.
float curve(vec2 px, vec2 org, float ang, float stepLen, int n, float seed, float reach, float width) {
    vec2 p = org;
    float a = ang, best = 0.0;
    for (int i = 0; i < 12; i++) {
        if (i >= n) break;
        float fi = float(i);
        a += 0.30 * sin(seed * 3.1 + fi * 0.9) + 0.12 * sin(seed * 1.7 + fi * 2.3);
        float grown = clamp(reach * float(n) - fi, 0.0, 1.0);
        vec2 e = vec2(cos(a), sin(a)) * stepLen;
        if (grown > 0.0) {
            vec2 se = e * grown, pa = px - p;
            float h = clamp(dot(pa, se) / max(dot(se, se), 1e-4), 0.0, 1.0);
            float dist = length(pa - se * h);
            float along = fi / float(n);
            float w = width * (1.0 - 0.55 * along);
            best = max(best, exp(-pow(dist / w, 2.0)) * (1.0 - 0.8 * along));
        }
        p += e;
    }
    return best;
}

// Where the same walk is after k steps, and which way it is heading, for the branches to start from.
vec3 walkTo(vec2 org, float ang, float stepLen, int k, float seed) {
    vec2 p = org;
    float a = ang;
    for (int i = 0; i < 12; i++) {
        if (i >= k) break;
        float fi = float(i);
        a += 0.30 * sin(seed * 3.1 + fi * 0.9) + 0.12 * sin(seed * 1.7 + fi * 2.3);
        p += vec2(cos(a), sin(a)) * stepLen;
    }
    return vec3(p, a);
}

// How far a root has grown, from `g`, how far through the toast's life it is. Each root has its own moment to start (in the first
// fifth of the life) and its own to finish (between 80% and 94% of it, so the last is done shortly before the countdown ends),
// and grows fast at first and slows toward the end.
float rootReach(float g, float h1, float h3) {
    float start = 0.22 * h1;
    float end = 0.80 + 0.14 * h3;
    float t = clamp((g - start) / (end - start), 0.0, 1.0);
    return 1.0 - (1.0 - t) * (1.0 - t);
}

// A vein (a root) with two side branches. `scale` (about 0.7 to 1.2) makes it shorter or longer. Nothing is drawn far from it.
float vein(vec2 px, vec2 org, float ang, float seed, float reach, float scale) {
    if (length(px - org) > 84.0) return 0.0;
    float stepLen = 3.6 * scale;
    float v = curve(px, org, ang, stepLen, 12, seed, reach, 0.62);
    vec3 b1 = walkTo(org, ang, stepLen, 4, seed);
    vec3 b2 = walkTo(org, ang, stepLen, 8, seed);
    float side = hash(seed + 5.0) < 0.5 ? 1.0 : -1.0;
    v = max(v, 0.8 * curve(px, b1.xy, b1.z + side * 0.9, 3.0 * scale, 6, seed + 1.3, clamp((reach - 4.0 / 12.0) * 2.2, 0.0, 1.0), 0.5));
    v = max(v, 0.7 * curve(px, b2.xy, b2.z - side * 0.8, 2.8 * scale, 5, seed + 2.6, clamp((reach - 8.0 / 12.0) * 2.6, 0.0, 1.0), 0.45));
    return v;
}

// Lichen: tiny dots in patches along the left edge inside the card, dense at the edge and thinning in, kept clear of the icon.
float lichen(vec2 px, float d, float nearIcon) {
    float x = px.x - ubuf.card.x, y = px.y - ubuf.card.y;
    if (x < 1.2 || x > 16.0 || d > 0.0) return 0.0;
    vec2 g = vec2(x, y) / 3.0;
    vec2 cell = floor(g);
    float colony = smoothstep(0.18, 0.5, vnoise(vec2(y * 0.045, ubuf.seed * 0.37)));
    float acc = 0.0;
    // each cell holds one dot at a random place in it, so the scatter does not look like a grid; check the cell and its neighbours
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec2 c = cell + vec2(float(i), float(j));
            float h = hash2(c + ubuf.seed), h2 = hash2(c * 1.7 + ubuf.seed + 4.0), h3 = hash2(c * 2.3 + ubuf.seed + 9.0);
            vec2 centre = (c + vec2(0.2 + 0.6 * h2, 0.2 + 0.6 * h3)) * 3.0;
            float dens = exp(-(centre.x - 1.2) / 5.0) * colony;
            float on = step(1.0 - dens * 0.9, h);
            acc = max(acc, on * exp(-pow(length(vec2(x, y) - centre) / (0.55 + 0.5 * h2), 2.0)));
        }
    }
    return acc * smoothstep(2.0, 14.0, nearIcon);
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    vec2 centre = ubuf.card.xy + 0.5 * ubuf.card.zw;
    float d = roundBox(px - centre, 0.5 * ubuf.card.zw, ubuf.radius);

    float nearIcon = ubuf.icon.z > 0.0 ? length(px - ubuf.icon.xy) - ubuf.icon.z : 1e3;
    if (d > 90.0 && nearIcon > 40.0) { fragColor = vec4(0.0); return; }

    float seed = ubuf.seed;
    float inside = 1.0 - smoothstep(-0.5, 0.5, d);

    // The colonies: where the outline is thicker, it is also more teal.
    float colony = vnoise(px * 0.035 + seed);
    vec3 col = desaturate(palette(0.12 + 0.78 * colony + 0.08 * sin(ubuf.time * 0.4 + px.x * 0.02), ubuf.urgency));

    // The outline, alive: its thickness varies along its length, and its position by under a pixel.
    float thick = 0.55 + 0.75 * vnoise(px * 0.06 + seed * 3.0);
    float sway = (vnoise(px * 0.11 + seed * 5.0) - 0.5) * 0.9;
    float rim = exp(-pow((d + 0.9 + sway) / thick, 2.0)) * (0.55 + 0.6 * colony);
    // The sap: a slow pulse that travels round the card (along the top and bottom, by x).
    float across = (px.x - ubuf.card.x) / ubuf.card.z;
    float sap = exp(-pow((fract(across - ubuf.time * 0.07) - 0.5) / 0.09, 2.0)) * 0.55;
    // Less spill and halo than the blend: the life is in the line and the veins.
    float spill = exp(-max(-d, 0.0) / 7.0) * inside * 0.10;
    float halo = exp(-max(d, 0.0) / 4.0) * (1.0 - inside) * 0.13;
    vec3 rgb = col * (rim * (0.95 + sap) + spill + halo);

    // Lichen, in a moss colour.
    rgb += desaturate(palette(0.0, ubuf.urgency)) * lichen(px, d, nearIcon) * 0.7;

    // Veins and roots: out into the free space on the left, in across the card on the right.
    float g = ubuf.growth;
    vec2 tr = ubuf.card.xy + vec2(ubuf.card.z, 1.0), br = ubuf.card.xy + vec2(ubuf.card.z, ubuf.card.w - 1.0);
    // Roots: many, along the left edge (about one per 18 px of the card's height), reaching out into the free space. Each
    // has its own place, direction, length and moment of starting to grow. Those near the top lean down and those near the
    // bottom lean up, so they stay in the card's own band (above and below is the screen's edge and the next toast).
    float outer = 0.0;
    float roots = clamp(floor(ubuf.card.w / 18.0), 3.0, 8.0);
    for (int i = 0; i < 14; i++) {
        float fi = float(i);
        if (fi >= roots) break;
        float h1 = hash(seed + fi * 5.3 + 40.0), h2 = hash(seed + fi * 3.1 + 41.0), h3 = hash(seed + fi * 7.7 + 42.0);
        float u = (fi + 0.5 + (h1 - 0.5) * 0.6) / roots;
        vec2 org = vec2(ubuf.card.x, ubuf.card.y + 1.0 + u * (ubuf.card.w - 2.0));
        if (px.x > org.x + 1.0 || org.x - px.x > 84.0 || abs(px.y - org.y) > 70.0) continue;
        float ang = 3.14159 + (h2 - 0.5) * 0.9 - (0.5 - u) * 0.9;
        float reach = rootReach(g, h1, h3);
        outer = max(outer, vein(px, org, ang, seed + fi * 13.0, reach, 1.0 + 0.5 * h3) * (1.0 + 0.5 * (1.0 - reach)));
    }
    // The same along the bottom edge (about one per 20 px of its width): down and leaning left, shorter, since the gap to the
    // toast below is small (they pass behind it) and, under the last toast, the screen is free.
    float bottomRoots = clamp(floor(ubuf.card.z / 20.0), 6.0, 24.0);
    float belowEdge = ubuf.card.y + ubuf.card.w;
    float under = 0.0;
    if (px.y > belowEdge - 1.0 && px.y < belowEdge + 80.0) {
        for (int i = 0; i < 24; i++) {
            float fi = float(i);
            if (fi >= bottomRoots) break;
            float h1 = hash(seed + fi * 4.1 + 70.0), h2 = hash(seed + fi * 2.9 + 71.0), h3 = hash(seed + fi * 6.3 + 72.0);
            float u = (fi + 0.5 + (h1 - 0.5) * 0.6) / bottomRoots;
            vec2 org = vec2(ubuf.card.x + u * ubuf.card.z, belowEdge - 1.0);
            if (abs(px.x - org.x) > 84.0) continue;
            float ang = 1.5708 + 0.35 + (h2 - 0.5) * 0.9;
            float reach = rootReach(g, h1, h3);
            under = max(under, vein(px, org, ang, seed + fi * 17.0 + 100.0, reach, 0.8 + 0.5 * h3) * (1.0 + 0.5 * (1.0 - reach)));
        }
    }
    outer = max(outer, 0.85 * under);
    // And, fainter, across the card from its right corners.
    float inner = vein(px, tr, 3.14159 - 0.55, seed + 23.0, rootReach(g, 0.3, 0.9), 1.0) + vein(px, br, 4.71239 - 0.55, seed + 37.0, rootReach(g, 0.7, 0.5), 1.0);
    vec3 vcol = desaturate(palette(0.55, ubuf.urgency));
    rgb += vcol * (outer * 0.7 + inner * 0.36 * (0.5 + 0.5 * inside));

    // The icon: a ring that is very slightly irregular, with a spore at its centre.
    if (ubuf.icon.z > 0.0) {
        vec2 q = px - ubuf.icon.xy;
        float r = length(q), ang = atan(q.y, q.x);
        float rr = ubuf.icon.z + 0.3 * sin(ang * 3.0 + seed) + 0.18 * sin(ang * 5.0 + seed * 2.0);
        float ring = exp(-pow((r - rr) / 0.9, 2.0));
        float core = exp(-pow(r / 2.6, 2.0));
        float fill = (1.0 - smoothstep(0.0, 1.0, r - rr)) * 0.06;
        float ringHalo = exp(-max(r - rr, 0.0) / 4.0) * 0.08 * step(rr, r);
        vec3 icol = desaturate(palette(0.35 + 0.3 * vnoise(px * 0.1 + seed), ubuf.urgency));
        rgb += icol * (ring * 0.8 + core * 0.9 + fill + ringHalo);
    }

    // The countdown: the card's own bottom border, lit. It is drawn from the same distance field and the same sway as the
    // outline above, so it lies exactly on the border and the two read as one line (an earlier version ran 3 px above the
    // border, as a second line). Where the toast has time left, the border is thicker and brighter, its thickness undulating
    // along it like a vein; the part that has run out is the plain border. It retreats from the right and ends in a bud.
    // It covers the bottom edge and a little way up each corner, not the top or the sides.
    if (ubuf.remaining >= 0.0) {
        float bottom = ubuf.card.y + ubuf.card.w;
        float x0 = ubuf.card.x;
        float x1 = x0 + clamp(ubuf.remaining, 0.0, 1.0) * ubuf.card.z;
        float onBottom = smoothstep(bottom - 7.0, bottom - 3.0, px.y);
        float seg = smoothstep(x0 - 0.5, x0 + 2.0, px.x) * (1.0 - smoothstep(x1 - 4.0, x1, px.x)) * onBottom;
        float life = smoothstep(0.0, 0.08, ubuf.remaining);
        float wave = 0.5 + 0.5 * sin((px.x - x0) * 0.11 - ubuf.time * 1.6 + seed);
        float off = d + 0.9 + sway;                                         // distance from the outline's own centre line
        float line = exp(-pow(off / (0.7 + 0.5 * wave), 2.0)) * seg * (0.55 + 0.45 * wave);
        float glow = exp(-pow(off / 2.6, 2.0)) * seg * 0.14;
        vec3 lcol = desaturate(palette((px.x - x0) / ubuf.card.z, ubuf.urgency));
        vec2 bud = vec2(x1, bottom - 0.9 - (vnoise(vec2(x1, bottom - 0.9) * 0.11 + seed * 5.0) - 0.5) * 0.9);
        float sd = length(px - bud);
        float spark = exp(-pow(sd / 1.9, 2.0)) * 0.8;
        float sparkHalo = exp(-pow(sd / 6.0, 2.0)) * 0.22;
        rgb += (lcol * (line * 0.85 + glow + sparkHalo) + vec3(0.95, 1.0, 0.85) * spark) * life;
    }

    rgb *= (0.7 + 0.3 * ubuf.vividness) * ubuf.energy;
    rgb += ambientSpores(px) * 0.55 * ubuf.spores;
    rgb = 1.0 - exp(-rgb * 1.7);
    fragColor = vec4(rgb, 0.0) * ubuf.qt_Opacity;
}
