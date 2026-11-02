#version 440

// The arrival, on the card: the edge of the card flares as the front of light crosses it and cools behind it, the card's centre is where the light is born (a spark), and the icon's spore
// is where the light is born. Drawn as an overlay a little larger than the card, above it, click-through, only while the front is
// crossing; added light only. The card itself is shown only inside the same front (cardreveal.frag), and the ring and halo outside
// are toastring.frag's. The settled rim is the look's own (toastrim.frag or toastgrowth.frag), which fades in as `fade` falls.
//
// `front` is the radius, in px from `origin` (the card's centre), the front has reached; `fade` is 1 while the front is crossing and falls to 0 as it
// finishes, taking this overlay's light with it as the look's own rim takes over. `reverse` is 1 for the exit, the arrival played backwards: the
// front retreats towards the centre, and the afterglow is on the side it has left (further from the centre, where the card is already gone), a ghost
// of the edge that fades.
// Colours are the theme's, as in toastring.frag. Rebuild with tools/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float strength;    // the user's `arrival` setting, 0 to 2
    float urgency;     // 0 low, 1 normal, 2 critical
    float radius;      // the card's corner radius, px
    float front;       // px from the origin
    float fade;        // 0 to 1
    float reverse;     // 0 for the arrival, 1 for the exit
    vec2 size;         // the overlay's size, px
    vec4 card;         // the card inside it: x, y, width, height, px
    vec3 icon;         // the icon ring: centre x, centre y, radius; radius <= 0 for none
    vec2 origin;       // where the wave starts: the card's centre, in the overlay's px
    vec4 shape;        // the toast's oval body, when it has one: semi-axes as multiples of the card's half-size (x, y), the exponent (z), 1 if it has one (w)
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

float roundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - (halfSize - vec2(r));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    vec2 centre = ubuf.card.xy + 0.5 * ubuf.card.zw;
    // the edge that flares is the oval body's when the toast has one, else the card's
    float d = ubuf.shape.w > 0.5 ? ovalSd(px - centre, 0.5 * ubuf.card.zw * ubuf.shape.xy, ubuf.shape.z) : roundBox(px - centre, 0.5 * ubuf.card.zw, ubuf.radius);
    vec3 inner = N_IN, outer = N_OUT;
    if (ubuf.urgency > 1.5) { inner = C_IN; outer = C_OUT; }
    else if (ubuf.urgency < 0.5) { inner = L_IN; outer = L_OUT; }

    float dist = length(px - ubuf.origin);
    float across = clamp((px.x - ubuf.card.x) / ubuf.card.z, 0.0, 1.0);
    vec3 col = mix(inner, outer, smoothstep(0.0, 1.0, across));

    // The edge: a thin line with a short spill inside and a faint halo outside, lit by the front as it crosses, with an afterglow behind it.
    float inside = 1.0 - smoothstep(-0.5, 0.5, d);
    float rim = exp(-pow((d + 0.9) / 0.85, 2.0));
    float spill = exp(-max(-d, 0.0) / 9.0) * inside * 0.17;
    float halo = exp(-max(d, 0.0) / 4.5) * (1.0 - inside) * 0.20;
    float wavefront = exp(-pow((dist - ubuf.front) / 22.0, 2.0));
    float behind = ubuf.reverse > 0.5 ? max(dist - ubuf.front, 0.0) : max(ubuf.front - dist, 0.0);
    // the arrival's afterglow is a cooling trail behind the front; the exit's is a short smear right behind the front (a longer ghost left a faint outline of the whole rectangle lingering after the card had collapsed from it: seen live)
    float trail = ubuf.reverse > 0.5 ? 18.0 : 140.0;
    float afterglow = behind > 0.0 ? exp(-behind / trail) * 0.45 : 0.0;
    vec3 rgb = col * (rim * 0.95 + spill + halo) * (wavefront * 1.6 + afterglow) * ubuf.fade;

    // The icon: a spore and its ring, lit as the front reaches it.
    if (ubuf.icon.z > 0.0) {
        float r = length(px - ubuf.icon.xy);
        float ring = exp(-pow((r - ubuf.icon.z) / 0.9, 2.0));
        float core = exp(-pow(r / 2.6, 2.0));
        float ringHalo = exp(-max(r - ubuf.icon.z, 0.0) / 5.0) * 0.10 * step(ubuf.icon.z, r);
        // lit once the front has reached the icon (and out again as the exit's front retreats past it)
        float born = 1.0 - smoothstep(ubuf.front - 16.0, ubuf.front + 10.0, length(ubuf.icon.xy - ubuf.origin));
        rgb += inner * (ring * 0.85 + core * 1.1 + ringHalo) * born * ubuf.fade;
    }

    // a spark at the card's centre where the wave starts, spreading into the front
    float spark = exp(-pow(length(px - ubuf.origin) / (5.0 + 0.25 * ubuf.front), 2.0)) * smoothstep(0.0, 3.0, ubuf.front) * (1.0 - smoothstep(0.0, 90.0, ubuf.front));
    rgb += mix(inner, vec3(1.0, 0.96, 0.92), 0.4) * spark * 1.1 * ubuf.fade;

    rgb *= ubuf.strength;
    rgb = 1.0 - exp(-rgb * 1.7);
    fragColor = vec4(rgb, 0.0) * ubuf.qt_Opacity;
}
