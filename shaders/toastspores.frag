#version 440

// The exit of a toast: as it folds away it dissolves into spores. Up to four toasts can be dissolving at once; each is
// a burst of a couple of dozen spores that lift off the card's body over a quarter of a second, drift to the left (away
// from the screen's edge and the arrival ring's source, into free space, never across the toast below) and fade over a
// second and a half. Spores are soft dots in amber and in the toast's own colour, drawn as added light.
//
// This lives in a layer over the whole stack that outlasts the cards: a card is gone after its 300 ms fold, but its
// spores are not. There are no particle objects: where each spore is at a given age is computed here from a hash of
// the burst's seed and the spore's number, so a burst is deterministic and costs nothing but this loop, and a pixel far
// from every burst returns early.
//
// Output is added light (colour above alpha, as in the other shaders), rolled off with 1 - exp(-x).
// Rebuild with tools/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float amount;      // 0 to 1: how many spores, and how bright (the user's spore_amount)
    vec2 size;         // the layer's size, px
    vec4 rect0;        // the card that dissolved: x, y, width, height, in the layer's px
    vec4 rect1;
    vec4 rect2;
    vec4 rect3;
    vec4 state0;       // its burst: age in seconds (negative: no burst), seed, urgency (0 low, 1 normal, 2 critical), unused
    vec4 state1;
    vec4 state2;
    vec4 state3;
} ubuf;

const int SPORES = 22;
const float REACH = 110.0;       // the farthest a spore travels, px, so the area a burst can touch is known

float hash(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }

vec3 accent(float urgency) {
    if (urgency > 1.5) return vec3(0.95, 0.48, 0.78);
    if (urgency < 0.5) return vec3(0.53, 0.70, 0.45);
    return vec3(0.20, 0.77, 0.82);
}

vec3 burst(vec2 px, vec4 rect, vec4 state) {
    float age = state.x;
    if (age < 0.0 || age > 2.2) return vec3(0.0);
    // Everything a burst can touch lies within the card's rect, REACH to its left and a little around it.
    if (px.x < rect.x - REACH - 12.0 || px.x > rect.x + rect.z + 14.0 || px.y < rect.y - 22.0 || px.y > rect.y + rect.w + 22.0) return vec3(0.0);

    vec3 rgb = vec3(0.0);
    vec3 amber = vec3(0.96, 0.62, 0.18);
    vec3 tint = accent(state.z);
    for (int i = 0; i < SPORES; i++) {
        float k = state.y * 17.13 + float(i) * 1.618;
        float h1 = hash(k), h2 = hash(k + 1.0), h3 = hash(k + 2.0), h4 = hash(k + 3.0), h5 = hash(k + 4.0), h6 = hash(k + 5.0);

        float delay = h3 * 0.28;                      // they lift off one after another, not all at once
        float life = 0.9 + 0.8 * h4;
        float t = age - delay;
        if (t < 0.0 || t > life) continue;
        float f = t / life;

        vec2 start = rect.xy + vec2(mix(0.06, 0.94, h1) * rect.z, mix(0.15, 0.85, h2) * rect.w);
        vec2 dir = normalize(vec2(-1.0, 0.3 * (h6 - 0.5) + 0.10));
        vec2 perp = vec2(-dir.y, dir.x);
        float travel = (28.0 + 74.0 * h5) * (1.0 - (1.0 - f) * (1.0 - f));          // quick away, then drifting
        float sway = (4.0 + 6.0 * h6) * sin(6.2832 * (f * 1.3 + h1));
        vec2 p = start + dir * travel + perp * sway;

        float r = length(px - p);
        float s = 0.9 + 1.0 * h2;                                                    // core radius, px
        float env = smoothstep(0.0, 0.12, f) * (1.0 - smoothstep(0.55, 1.0, f));
        vec3 col = h5 < 0.5 ? amber : tint;
        rgb += col * (exp(-pow(r / s, 2.0)) * 0.95 + exp(-pow(r / (3.6 * s), 2.0)) * 0.18) * env;
    }
    return rgb;
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    vec3 rgb = burst(px, ubuf.rect0, ubuf.state0) + burst(px, ubuf.rect1, ubuf.state1)
             + burst(px, ubuf.rect2, ubuf.state2) + burst(px, ubuf.rect3, ubuf.state3);
    rgb = 1.0 - exp(-rgb * ubuf.amount * 1.6);
    fragColor = vec4(rgb, 0.0) * ubuf.qt_Opacity;
}
