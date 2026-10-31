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
    if (d > 40.0 && nearIcon > 40.0) { fragColor = vec4(0.0); return; }

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

    rgb *= (0.7 + 0.3 * ubuf.vividness) * ubuf.energy;
    rgb = 1.0 - exp(-rgb * 1.7);
    fragColor = vec4(rgb, 0.0) * ubuf.qt_Opacity;
}
