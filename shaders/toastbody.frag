#version 440

// The toast's body: a soft-edged oval under the text, in place of the card's rectangle and border (components/ToastBody.qml). Normal alpha blending of the
// card's own fill colour, and a little added light along the edge in the toast's colours, so the edge is lit and soft instead of drawn.
//
// The shape is a superellipse of exponent `shape.z` (3: an oval with fuller ends than an ellipse, so the text in the corners stays on it) concentric with the card, its
// semi-axes the card's half-size times `shape.xy`. The distance to it is the usual first-order one, (g - 1) / |grad g|, so the feather is as wide at the ends as on top.
// The fill is solid 22 px inside the outline and gone 22 px outside it (design px: times `ui`, the pixels per design px: a feather 44 px wide, widened from 26 after the first live look, where the
// edge still read as crisp), and takes on the glow's colour toward its outer edge, so the oval dissolves into the arrival's glow, which runs under it (toastring.frag no longer hides it behind the
// card). Chosen from mock-ups on 2026-11-02 (docs/design/blend/). Rebuild with tools/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float urgency;     // 0 low, 1 normal, 2 critical
    float vividness;   // 0 to 1: how strong the edge light is (the user's rim_vividness)
    float ui;          // pixels per design pixel
    vec2 size;         // the overlay's size, px
    vec4 card;         // the card inside it: x, y, width, height, px
    vec4 shape;        // the oval: semi-axes as multiples of the card's half-size (x, y), the exponent (z), unused (w)
    vec4 fill;         // the body's colour and opacity (not premultiplied)
} ubuf;

vec3 edgeColour(float across, float urgency) {
    vec3 a, b;
    if (urgency > 1.5) { a = vec3(0.96, 0.62, 0.18); b = vec3(0.95, 0.48, 0.78); }
    else if (urgency < 0.5) { a = vec3(0.53, 0.70, 0.45); b = vec3(0.30, 0.60, 0.80); }
    else { a = vec3(0.20, 0.77, 0.82); b = vec3(0.44, 0.46, 0.98); }
    return mix(a, b, smoothstep(0.0, 1.0, across));
}

float ovalSd(vec2 p, vec2 ab, float n) {
    vec2 u = max(abs(p) / ab, vec2(1e-4));
    float g = pow(pow(u.x, n) + pow(u.y, n), 1.0 / n);
    vec2 gr = pow(g, 1.0 - n) * pow(u, vec2(n - 1.0)) / ab;
    return (g - 1.0) / max(length(gr), 1e-5);
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    vec2 centre = ubuf.card.xy + 0.5 * ubuf.card.zw;
    float sd = ovalSd(px - centre, 0.5 * ubuf.card.zw * ubuf.shape.xy, ubuf.shape.z);
    float u = ubuf.ui;
    if (sd > 24.0 * u) { fragColor = vec4(0.0); return; }

    float alpha = ubuf.fill.a * (1.0 - smoothstep(-22.0 * u, 22.0 * u, sd));
    float across = clamp((px.x - ubuf.card.x) / ubuf.card.z, 0.0, 1.0);
    vec3 glow = edgeColour(across, ubuf.urgency);
    // toward the outer edge the body is tinted with the glow (a dark fill fading out over a bright glow reads as a dark smudge with an outline; this makes it a soft edge)
    vec3 fillRgb = mix(ubuf.fill.rgb, glow * 0.30, 0.55 * smoothstep(-8.0 * u, 20.0 * u, sd));
    float edge = exp(-pow((sd + 2.0 * u) / (16.0 * u), 2.0));
    vec3 light = glow * edge * 0.12 * (0.7 + 0.3 * ubuf.vividness);
    fragColor = vec4(fillRgb * alpha + light, alpha) * ubuf.qt_Opacity;
}
