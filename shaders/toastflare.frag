#version 440

// The arrival, on the card: the edge of the card flares as the front of light crosses it and cools behind it, and the icon's spore
// is where the light is born. Drawn as an overlay a little larger than the card, above it, click-through, only while the front is
// crossing; added light only. The card itself is shown only inside the same front (cardreveal.frag), and the ring and halo outside
// are toastring.frag's. The settled rim is the look's own (toastrim.frag or toastgrowth.frag), which fades in as `fade` falls.
//
// `front` is the radius, in px from the icon, the front has reached; `fade` is 1 while the front is crossing and falls to 0 as it
// finishes, taking this overlay's light with it as the look's own rim takes over. `reverse` is 1 for the exit, the arrival played backwards: the
// front retreats towards the icon, and the afterglow is on the side it has left (further from the icon, where the card is already gone), a ghost
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
    float front;       // px from the icon
    float fade;        // 0 to 1
    float reverse;     // 0 for the arrival, 1 for the exit
    vec2 size;         // the overlay's size, px
    vec4 card;         // the card inside it: x, y, width, height, px
    vec3 icon;         // the icon ring: centre x, centre y, radius; radius <= 0 for none
} ubuf;

const vec3 N_IN = vec3(0.2000, 0.7686, 0.8157);
const vec3 N_OUT = vec3(0.4400, 0.4600, 0.9800);
const vec3 C_IN = vec3(0.9569, 0.6200, 0.1800);
const vec3 C_OUT = vec3(0.9490, 0.4784, 0.7000);
const vec3 L_IN = vec3(0.5300, 0.6900, 0.4200);
const vec3 L_OUT = vec3(0.2800, 0.6800, 0.7000);

float roundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - (halfSize - vec2(r));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    vec2 centre = ubuf.card.xy + 0.5 * ubuf.card.zw;
    float d = roundBox(px - centre, 0.5 * ubuf.card.zw, ubuf.radius);
    vec3 inner = N_IN, outer = N_OUT;
    if (ubuf.urgency > 1.5) { inner = C_IN; outer = C_OUT; }
    else if (ubuf.urgency < 0.5) { inner = L_IN; outer = L_OUT; }

    vec2 src = ubuf.icon.z > 0.0 ? ubuf.icon.xy : vec2(ubuf.card.x + 32.0, ubuf.card.y + 0.5 * ubuf.card.w);
    float dist = length(px - src);
    float across = clamp((px.x - ubuf.card.x) / ubuf.card.z, 0.0, 1.0);
    vec3 col = mix(inner, outer, smoothstep(0.0, 1.0, across));

    // The edge: a thin line with a short spill inside and a faint halo outside, lit by the front as it crosses, with an afterglow behind it.
    float inside = 1.0 - smoothstep(-0.5, 0.5, d);
    float rim = exp(-pow((d + 0.9) / 0.85, 2.0));
    float spill = exp(-max(-d, 0.0) / 9.0) * inside * 0.17;
    float halo = exp(-max(d, 0.0) / 4.5) * (1.0 - inside) * 0.20;
    float wavefront = exp(-pow((dist - ubuf.front) / 22.0, 2.0));
    float behind = ubuf.reverse > 0.5 ? max(dist - ubuf.front, 0.0) : max(ubuf.front - dist, 0.0);
    // the arrival's afterglow is a cooling trail behind the front; the exit's ghost is shorter (a ghost rectangle of the whole outline over empty space looked wrong)
    float trail = ubuf.reverse > 0.5 ? 60.0 : 140.0;
    float afterglow = behind > 0.0 ? exp(-behind / trail) * 0.45 : 0.0;
    vec3 rgb = col * (rim * 0.95 + spill + halo) * (wavefront * 1.6 + afterglow) * ubuf.fade;

    // The icon: the spore where the light is born, and its ring.
    if (ubuf.icon.z > 0.0) {
        float r = length(px - ubuf.icon.xy);
        float ring = exp(-pow((r - ubuf.icon.z) / 0.9, 2.0));
        float core = exp(-pow(r / 2.6, 2.0));
        float ringHalo = exp(-max(r - ubuf.icon.z, 0.0) / 5.0) * 0.10 * step(ubuf.icon.z, r);
        float born = smoothstep(0.0, 8.0, ubuf.front);
        rgb += inner * (ring * 0.85 + core * 1.1 + ringHalo) * born * ubuf.fade;
    }

    rgb *= ubuf.strength;
    rgb = 1.0 - exp(-rgb * 1.7);
    fragColor = vec4(rgb, 0.0) * ubuf.qt_Opacity;
}
