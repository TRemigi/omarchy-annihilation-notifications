#version 440

// The light on a toast: an iridescent rim with a soft prism spill just inside it and a faint halo outside
// (the same language as the theme's window glow), and a ring round the app icon. Drawn as an overlay a little
// larger than the card, above it, click-through; nothing else is drawn, so most pixels cost a few operations.
//
// The rim's colour is a narrow slice of the spectrum that runs across the card and drifts very slowly, and
// it is brightest on the side the light comes from (the top right, where the arrival ring started), so the toast
// reads as the wave condensing into an object. `energy` is 1 once settled and higher while the rim ignites at
// arrival, cooling back over about a second. Output is added light (colour above alpha, as in windowglow.frag),
// rolled off with 1 - exp(-x) so a bright ignition never clips flat.
//
// The countdown is a line of light along the bottom edge that drains as the toast runs out, ending in a bright spark.
// Full, it runs from the card's left border to its right border, meeting both (a first version stopped at the corners
// and left a small dark gap at each end), so a fresh toast has a line the card's whole width; its colours are fixed along
// that full length, so it seems to retreat and reveal them rather than to recolour.
// `remaining` is the fraction of the toast's life left; negative means no countdown (critical toasts never expire).
//
// A few faint spores leave the card's left edge now and then and drift away from the screen's edge into the free space to
// the left (the same direction as the spores a toast leaves when it goes, see toastspores.frag), over a few seconds each.
// `spores` scales them (0 for none).
//
// Rebuild with tools/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;        // seconds, for the slow drift of the colour
    float energy;      // 1 settled, above 1 while igniting
    float vividness;   // 0 to 1: how saturated and strong the light is
    float urgency;     // 0 low, 1 normal, 2 critical
    float radius;      // the card's corner radius, px
    vec2 size;         // the overlay's size, px
    vec4 card;         // the card inside it: x, y, width, height, px
    vec3 icon;         // the icon ring: centre x, centre y, radius; radius <= 0 for none
    float remaining;   // 0 to 1: the toast's life left; negative for none
    float spores;      // 0 to 1: the faint spores off the left edge (the user's spore_amount); 0 for none
    float seed;        // unused here: toastgrowth.frag's, kept so ToastRim feeds both shaders the same properties
    float growth;      // unused here, as above
} ubuf;

// Light colours, as in the theme's shaders. Normal runs teal to blue to violet to pink, critical amber to peach to
// pink to violet, low moss to teal to blue.
vec3 spectrum(float t, float urgency) {
    vec3 a, b, c, d;
    if (urgency > 1.5) {
        a = vec3(0.96, 0.62, 0.18); b = vec3(0.96, 0.66, 0.47); c = vec3(0.95, 0.48, 0.78); d = vec3(0.60, 0.40, 0.95);
    } else if (urgency < 0.5) {
        a = vec3(0.53, 0.70, 0.45); b = vec3(0.30, 0.70, 0.66); c = vec3(0.30, 0.60, 0.80); d = vec3(0.45, 0.55, 0.90);
    } else {
        a = vec3(0.20, 0.77, 0.82); b = vec3(0.37, 0.52, 1.00); c = vec3(0.60, 0.40, 0.95); d = vec3(0.95, 0.48, 0.78);
    }
    t = clamp(t, 0.0, 1.0) * 3.0;
    if (t < 1.0) return mix(a, b, t);
    if (t < 2.0) return mix(b, c, t - 1.0);
    return mix(c, d, t - 2.0);
}

float hash(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }

// Six spores, each with its own period of 5 to 8.5 s: it leaves the left edge, drifts about 46 px away, swaying a little,
// and fades in and out over that time. Drawn only to the left of the card, so they seem to come from its edge.
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
        vec3 col = h4 < 0.5 ? vec3(0.96, 0.62, 0.18) : spectrum(0.1, ubuf.urgency);
        acc += col * (exp(-pow(r / s, 2.0)) * 0.9 + exp(-pow(r / (3.4 * s), 2.0)) * 0.15) * env;
    }
    return acc * smoothstep(left + 1.0, left - 3.0, px.x);
}

float roundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - (halfSize - vec2(r));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    vec2 centre = ubuf.card.xy + 0.5 * ubuf.card.zw;
    float d = roundBox(px - centre, 0.5 * ubuf.card.zw, ubuf.radius);

    // Everything is within a few dozen pixels of the card's edge or its icon.
    float nearIcon = ubuf.icon.z > 0.0 ? length(px - ubuf.icon.xy) - ubuf.icon.z : 1e3;
    if (d > 60.0 && nearIcon > 40.0) { fragColor = vec4(0.0); return; }

    // How far across the card (0 left, 1 right), with a slow drift and a little waviness down the height.
    float across = clamp((px.x - ubuf.card.x) / ubuf.card.z, 0.0, 1.0);
    float t = 0.12 + 0.72 * across + 0.06 * sin(px.y * 0.09) + 0.045 * sin(ubuf.time * 0.45 + px.x * 0.011);
    vec3 col = spectrum(t, ubuf.urgency);
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, 0.55 + 0.45 * ubuf.vividness);

    // The light comes from the top right.
    vec2 corner = vec2(ubuf.card.x + ubuf.card.z, ubuf.card.y);
    float light = 0.32 + 0.68 * exp(-length(px - corner) / (0.6 * ubuf.card.z));

    float inside = 1.0 - smoothstep(-0.5, 0.5, d);
    float rim = exp(-pow((d + 0.9) / 0.85, 2.0));
    float spill = exp(-max(-d, 0.0) / 9.0) * inside * 0.17;
    float halo = exp(-max(d, 0.0) / 4.5) * (1.0 - inside) * 0.20;
    vec3 rgb = col * (rim * 0.95 + spill + halo) * light;

    // The icon: a ring with a spore at its centre, in the colour of the rim at that place.
    if (ubuf.icon.z > 0.0) {
        float r = length(px - ubuf.icon.xy);
        float ring = exp(-pow((r - ubuf.icon.z) / 0.9, 2.0));
        float core = exp(-pow(r / 2.6, 2.0));
        float fill = (1.0 - smoothstep(0.0, 1.0, r - ubuf.icon.z)) * 0.07;
        float ringHalo = exp(-max(r - ubuf.icon.z, 0.0) / 5.0) * 0.10 * step(ubuf.icon.z, r);
        float ti = clamp(0.1 + 0.8 * (px.x - (ubuf.icon.x - ubuf.icon.z)) / (2.0 * ubuf.icon.z), 0.0, 1.0);
        vec3 icol = spectrum(ti, ubuf.urgency);
        icol = mix(vec3(dot(icol, vec3(0.299, 0.587, 0.114))), icol, 0.55 + 0.45 * ubuf.vividness);
        rgb += icol * (ring * 0.85 + core * 0.9 + fill + ringHalo);
    }

    // The countdown: a line just inside the bottom edge, border to border, shrinking from the right. It sits 3.2 px above
    // the edge, where a rounded corner has pulled the border in by `ex`; the rim is centred 0.9 px inside the edge. Starting
    // there makes the line meet the border instead of leaving a gap.
    if (ubuf.remaining >= 0.0) {
        float lineHeight = 3.2;
        float lineY = ubuf.card.y + ubuf.card.w - lineHeight;
        float ex = lineHeight < ubuf.radius ? ubuf.radius - sqrt(max(ubuf.radius * ubuf.radius - (ubuf.radius - lineHeight) * (ubuf.radius - lineHeight), 0.0)) : 0.0;
        float x0 = ubuf.card.x + 0.9 + ex;
        float full = max(ubuf.card.z - 2.0 * (0.9 + ex), 1.0);
        float x1 = x0 + clamp(ubuf.remaining, 0.0, 1.0) * full;
        float seg = smoothstep(x0 - 0.5, x0 + 2.0, px.x) * (1.0 - smoothstep(x1 - 6.0, x1, px.x));
        float life = smoothstep(0.0, 0.08, ubuf.remaining);          // it fades out at the very end
        float dy = px.y - lineY;
        float line = exp(-pow(dy / 0.8, 2.0)) * seg;
        float glow = exp(-pow(dy / 3.2, 2.0)) * seg * 0.18;
        vec3 lcol = spectrum((px.x - x0) / full, ubuf.urgency);
        lcol = mix(vec3(dot(lcol, vec3(0.299, 0.587, 0.114))), lcol, 0.55 + 0.45 * ubuf.vividness);
        float sd = length(px - vec2(x1, lineY));
        float spark = exp(-pow(sd / 2.2, 2.0)) * 0.8;
        float sparkHalo = exp(-pow(sd / 7.0, 2.0)) * 0.25;
        rgb += (lcol * (line * 0.95 + glow + sparkHalo) + vec3(1.0, 0.96, 0.92) * spark) * life;
    }

    rgb *= (0.7 + 0.3 * ubuf.vividness) * ubuf.energy;
    rgb += ambientSpores(px) * 0.55 * ubuf.spores;
    rgb = 1.0 - exp(-rgb * 1.7);
    fragColor = vec4(rgb, 0.0) * ubuf.qt_Opacity;
}
