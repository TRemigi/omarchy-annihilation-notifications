#version 440

// The arrival's other half: the card itself (body, text and icon, as a layer) is shown only inside the front of light that
// is leaving its icon, with a soft edge, so it seems to condense out of the light that crosses it. See toastglow.frag, which
// draws the light. `front` is in px from `icon`; the card is `size` px.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float front;
    vec2 size;
    vec2 icon;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    float dist = length(qt_TexCoord0 * ubuf.size - ubuf.icon);
    float solid = 1.0 - smoothstep(ubuf.front - 16.0, ubuf.front + 10.0, dist);
    fragColor = texture(source, qt_TexCoord0) * solid * ubuf.qt_Opacity;
}
