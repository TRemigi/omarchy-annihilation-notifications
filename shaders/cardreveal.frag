#version 440

// The arrival's other half: the card itself (body, text and icon, as a layer) is shown only inside the front of light that
// is leaving its centre, with a soft edge, so it seems to condense out of the light that crosses it. See toastglow.frag, which
// draws the light. `front` is in px from `origin` (the card's centre); the card is `size` px. With an oval body the front is an oval of the toast's own proportions, not a circle:
// `aspect` stretches the distance vertically (1 for a circle; the body's half-width over its half-height for the oval toast).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float front;
    float aspect;
    vec2 size;
    vec2 origin;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    float dist = length((qt_TexCoord0 * ubuf.size - ubuf.origin) * vec2(1.0, ubuf.aspect));
    float solid = 1.0 - smoothstep(ubuf.front - 16.0, ubuf.front + 10.0, dist);
    fragColor = texture(source, qt_TexCoord0) * solid * ubuf.qt_Opacity;
}
