#version 440

// The arrival's other half: the card itself (body, text and icon, as a layer) is shown only inside the front of light that
// is leaving its centre, with a soft edge, so it seems to condense out of the light that crosses it. See toastglow.frag, which
// draws the light. `front` is in px from `origin` (the card's centre); the card is `size` px. With an oval body the front is an oval of the toast's own proportions, not a circle:
// `aspect` stretches the distance vertically (1 for a circle; the body's half-width over its half-height for the oval toast). The edge is `soft` px wide in real pixels, within a factor of 3 (the stretched
// distance is divided by the size of its gradient: without that a 26 px edge was 26 / aspect, about 6 px, thick along the top and bottom of an oval, a hard edge as the toast expanded).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float front;
    float aspect;
    float soft;      // the edge's width, px (26 for a card)
    vec2 size;
    vec2 origin;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * ubuf.size - ubuf.origin;
    float dist = length(p * vec2(1.0, ubuf.aspect));
    // the gradient of that distance has length >= 1 (exactly 1 where the stretch does not matter); dividing by it makes the edge about as wide in px in every direction, up to a cap of 3
    // (uncapped, the front would have to travel more than twice as far to finish revealing the faint top and bottom of the body)
    float g = clamp(length(vec2(p.x, p.y * ubuf.aspect * ubuf.aspect)) / max(dist, 1e-3), 1.0, 3.0);
    float e = (dist - ubuf.front) / g;
    float solid = 1.0 - smoothstep(-0.6154 * ubuf.soft, 0.3846 * ubuf.soft, e);
    fragColor = texture(source, qt_TexCoord0) * solid * ubuf.qt_Opacity;
}
