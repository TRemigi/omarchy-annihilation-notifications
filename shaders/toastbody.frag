#version 440

// The toast's body: a soft-edged oval under the text, in place of the card's rectangle and border (components/ToastBody.qml). Normal alpha blending of the
// card's own fill colour and nothing else: no light and no tint on the edge (both drew a faint line where the body ends, which read as a hard edge on a flat background).
//
// The shape is a superellipse of exponent `shape.z` (3: an oval with fuller ends than an ellipse, so the text in the corners stays on it) concentric with the card, its
// semi-axes the card's half-size times `shape.xy`. The distance to it is the usual first-order one, (g - 1) / |grad g|, so the feather is as wide at the ends as on top.
// The fill is solid 22 px inside the outline and gone 58 px outside it (design px: times `ui`, the pixels per design px: a feather 80 px wide, widened from 26 and then 44 after live looks, where the
// edge still read as crisp), so the oval dissolves into what is behind it (and the arrival's glow, which runs under it: toastring.frag no longer hides it behind the card). Chosen from mock-ups on 2026-11-02 (docs/design/blend/). Rebuild with tools/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float urgency;     // unused now (the edge light is gone); kept so ToastBody feeds the same properties
    float vividness;   // unused now, as above
    float ui;          // pixels per design pixel
    vec2 size;         // the overlay's size, px
    vec4 card;         // the card inside it: x, y, width, height, px
    vec4 shape;        // the oval: semi-axes as multiples of the card's half-size (x, y), the exponent (z), unused (w)
    vec4 fill;         // the body's colour and opacity (not premultiplied)
} ubuf;

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
    if (sd > 60.0 * u) { fragColor = vec4(0.0); return; }

    float alpha = ubuf.fill.a * (1.0 - smoothstep(-22.0 * u, 58.0 * u, sd));
    fragColor = vec4(ubuf.fill.rgb * alpha, alpha) * ubuf.qt_Opacity;
}
