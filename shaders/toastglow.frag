#version 440

// The light on a toast when it is lit by the same light as the windows (look=glow).
//
// The colour field (lightSpectrum, fanField, glints) is copied unchanged from the theme's windowglow.frag, and the band's
// profile below is the same arithmetic, so a toast and the window beside it are lit by one light: it needs the glow's own
// clock and seed (the theme publishes them, see components/GlowClock.qml), and the toast's place on the screen, because the
// fans are fields over the whole screen. The only difference from a window is the shape the light hugs, and that the band
// is a little shallower (`depth`; a 78 px card with a window's band reads as a bevelled frame).
//
// Drawn as an overlay a little larger than the card, above it, click-through; added light only (alpha 0), rolled off with
// 1 - exp(-x) as the window glow is. The card's own body, text and border-less outline are QML.
//
// The arrival: `front` is the radius, in px from the icon, that a front of light has reached, or negative once settled. Nothing
// is lit beyond it; the edge flares as it crosses. The card itself is revealed by the same front (cardreveal.frag).
// Rebuild with tools/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;        // the glow's clock, seconds
    float intensity;   // the glow's intensity (the theme's layerIntensity)
    float seed;        // the glow's seed
    float rimWidth;    // the windows' rim width: 0.026 of the screen height, 16 to 44 px
    float depth;       // the toast's band depth, as a multiple of rimWidth
    float urgency;     // 0 low, 1 normal, 2 critical
    float radius;      // the card's corner radius, px
    float front;       // px, or negative when settled
    vec2 resolution;   // the screen, px
    vec2 origin;       // this overlay's top left, in screen px
    vec2 size;         // the overlay's size, px
    vec4 card;         // the card inside it: x, y, width, height, px
    vec3 icon;         // the icon ring: centre x, centre y, radius; radius <= 0 for none
} ubuf;

const vec3 L_GREEN = vec3(0.5255, 0.8392, 0.6039);
const vec3 L_TEAL = vec3(0.2000, 0.7686, 0.8157);
const vec3 L_BLUE = vec3(0.3725, 0.5176, 1.0000);
const vec3 L_VIOLET = vec3(0.6039, 0.4000, 0.9490);
const vec3 L_PINK = vec3(0.9490, 0.4784, 0.7843);
const vec3 L_PEACH = vec3(0.9569, 0.6588, 0.4706);
const vec3 AQUA = vec3(0.8314, 0.9176, 0.9255);

// How fast the fans move, as a multiple of the shader clock.
const float FAN_SPEED = 3.0;
const float PI = 3.14159265;

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float hash12(vec2 p) {
    return hash13(vec3(p, 1.7));
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float noise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float x00 = mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x);
    float x10 = mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x);
    float x01 = mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x);
    float x11 = mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x);
    return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

float fbm3(vec3 p, int octaves) {
    float a = 0.5;
    float s = 0.0;
    float norm = 0.0;
    for (int i = 0; i < 3; i++) {
        if (i >= octaves) break;
        s += a * noise3(p);
        norm += a;
        p = vec3(p.xy * 2.03 + vec2(17.1, 9.2), p.z * 1.7 + 3.3);
        a *= 0.5;
    }
    return s / norm;
}

vec3 seg(vec3 a, vec3 b, float pa, float pb, float x) {
    return mix(a, b, smoothstep(0.0, 1.0, (x - pa) / (pb - pa)));
}

// green, teal, blue, violet, pink, peach.
vec3 lightSpectrum(float x) {
    x = clamp(x, 0.0, 0.9999);
    if (x < 0.14) return seg(L_GREEN, L_TEAL, 0.00, 0.14, x);
    if (x < 0.30) return seg(L_TEAL, L_BLUE, 0.14, 0.30, x);
    if (x < 0.46) return seg(L_BLUE, L_VIOLET, 0.30, 0.46, x);
    if (x < 0.66) return seg(L_VIOLET, L_PINK, 0.46, 0.66, x);
    return seg(L_PINK, L_PEACH, 0.66, 1.00, x);
}

float wrapAngle(float a) {
    return mod(a + PI, 2.0 * PI) - PI;
}

// The two fans, at p (screen height = 1). Returns their combined strength and the
// strength-weighted mean of their hues. They are blended, never chosen between:
// picking the stronger one makes colour and strength jump in a hard line wherever
// the two cross, and that line drifts as the fans wander.
//
// The mean has a small prior of its own pulling it toward a base hue. Without it the
// hue is undefined where no fan reaches, and a mean taken over only a trace of
// strength still takes that fan's full hue, so the glow changed colour in a straight
// line along the edge of every fan, however faint the fan was there.
vec2 fanField(vec2 p, float aspect, float t, float s) {
    float ft = t * FAN_SPEED;
    float sumE = 0.0;
    float sumH = 0.0;
    for (int k = 0; k < 2; k++) {
        float kk = float(k);
        float alpha = s * (2.3 + 1.7 * kk)
            + 0.55 * sin(ft * (0.021 + 0.011 * kk) + s * (1.9 + kk))
            + ft * (0.0035 + 0.003 * kk);
        // A circle around the middle, big enough to clear the corners. (It used to be an
        // ellipse 1.38 times the half-extents, which at the diagonals passes just inside
        // the screen's corner: the source then showed as the sharp tip of a thin wedge
        // lit inside a window, the spotlight look. Now it stays at least 0.12 screen
        // heights away, always.)
        float rk = 1.28 + 0.10 * sin(ft * (0.013 + 0.005 * kk) + s * 4.1);
        vec2 src = vec2(aspect * 0.5, 0.5) + 0.5 * length(vec2(aspect, 1.0)) * rk * vec2(cos(alpha), sin(alpha));
        float phi0 = atan(0.5 - src.y, aspect * 0.5 - src.x)
            + 0.22 * sin(ft * (0.027 + 0.006 * kk) + s * (3.3 + kk));
        vec2 dv = p - src;
        float dist = length(dv);
        float ang = atan(dv.y, dv.x);
        // Sampled by position, not by angle: atan jumps by a full turn along one ray from
        // the source, and noise of it would jump there too.
        float bend = 0.05 * (fbm3(vec3(dv * 1.7 + vec2(5.0 * kk, 3.0 * kk),
                                       ft * 0.12 + s * 3.0), 2) - 0.5) * 2.0;
        float delta = wrapAngle(ang - phi0 + bend);
        float hw = 0.40 + 0.12 * sin(ft * (0.017 + 0.004 * kk) + s * (2.7 + kk));
        float u = delta / hw;
        float env = 1.0 - smoothstep(0.25, 1.0, abs(u));
        float reach = exp(-(dist / 1.5) * (dist / 1.5));
        float life = 0.22 + 0.78 * smoothstep(0.15, 0.85,
            0.5 + 0.5 * sin(ft * (0.017 + 0.007 * kk) + s * (5.7 + kk)));
        float n1 = fbm3(vec3(u * 7.0 + 13.0 * kk, 0.5 + kk, ft * 0.09 + s * 7.0), 2);
        float ray = 0.35 + 0.65 * smoothstep(0.25, 0.85, n1);
        // A narrower slice of the spectrum than on the wallpaper: along a window edge,
        // colours should blend into one another, not read as separate strips.
        float hx = clamp(0.5 + 0.20 * u + 0.16 * sin(ft * 0.02 + s * (1.3 + kk)) + 0.12 * kk, 0.0, 1.0);
        // Only a trace of the rays: they are what made the glow read as a beam.
        float e = env * reach * life * (0.85 + 0.15 * ray);
        sumE += e;
        sumH += e * hx;
    }
    // The base hue drifts smoothly across the screen and over time, so the glow's
    // colour keeps shifting where no fan reaches, and never changes in a line.
    float prior = 0.08;
    float baseHue = 0.55 + 2.6 * (fbm3(vec3(p * 0.9 + vec2(4.7, 2.3), ft * 0.03 + s * 5.1), 2) - 0.5);
    return vec2((sumH + prior * baseHue) / (sumE + prior), min(sumE, 1.0));
}

// Bright spots: a few soft round glints that drift and twinkle. Each is a plain
// Gaussian blob, the same in every direction, so nothing is projected from it; the
// caller only lets them show close to a window edge. About one cell in seven of a
// coarse grid hosts one, so at any moment there are only a few.
vec3 glints(vec2 px, float w, float t, float s) {
    float cs = 4.6 * w;
    vec2 id = floor(px / cs);
    vec3 acc = vec3(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 c = id + vec2(float(i), float(j));
            float h = hash12(c + s * 3.1);
            if (h < 0.86) continue;
            vec2 o = hash22(c + s * 1.7);
            vec2 pos = (c + 0.15 + 0.7 * o) * cs
                + 0.28 * cs * vec2(sin(t * (0.13 + 0.10 * h) + h * 31.0), cos(t * (0.10 + 0.09 * h) + h * 17.0));
            vec2 dv = px - pos;
            float r = w * (0.85 + 0.9 * fract(h * 9.0));
            float g = exp(-dot(dv, dv) / (r * r));
            float tw = 0.30 + 0.70 * smoothstep(0.15, 0.95, 0.5 + 0.5 * sin(t * (0.22 + 0.35 * h) + h * 47.0));
            vec3 col = mix(lightSpectrum(0.28 + 0.52 * fract(h * 13.0)), AQUA, 0.35);
            acc += col * g * tw;
        }
    }
    return acc;
}


float roundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - (halfSize - vec2(r));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 opx = qt_TexCoord0 * ubuf.size;
    vec2 px = ubuf.origin + opx;
    vec2 centre = ubuf.card.xy + 0.5 * ubuf.card.zw;
    float d = roundBox(opx - centre, 0.5 * ubuf.card.zw, ubuf.radius);

    float w = ubuf.rimWidth * max(ubuf.depth, 0.02);
    bool arriving = ubuf.front >= 0.0;
    float nearIcon = ubuf.icon.z > 0.0 ? length(opx - ubuf.icon.xy) - ubuf.icon.z : 1e3;
    if (!arriving && d > 1.6 * w + 4.0 && nearIcon > 4.0) { fragColor = vec4(0.0); return; }

    // The arrival: distance from the icon's centre (or from the card's left-middle when there is no icon).
    vec2 src = ubuf.icon.z > 0.0 ? ubuf.icon.xy : vec2(ubuf.card.x + 32.0, ubuf.card.y + 0.5 * ubuf.card.w);
    float dist = length(opx - src);
    float lit = 1.0;
    float flare = 0.0;
    float ring = 0.0;
    float solid = 1.0;
    if (arriving) {
        lit = 1.0 - smoothstep(ubuf.front - 10.0, ubuf.front + 26.0, dist);
        solid = 1.0 - smoothstep(ubuf.front - 16.0, ubuf.front + 10.0, dist);
        // how far the front has to go to have crossed the whole card: it dims as it gets there
        vec2 far = max(src - ubuf.card.xy, ubuf.card.xy + ubuf.card.zw - src);
        float done = clamp(ubuf.front / (length(far) + 30.0), 0.0, 1.0);
        flare = exp(-pow((dist - ubuf.front) / 16.0, 2.0)) * (1.0 - smoothstep(0.5, 1.0, done));
        ring = exp(-pow((dist - ubuf.front) / 30.0, 2.0)) * pow(1.0 - done, 1.6);
    }

    // The same light as the windows.
    float aspect = ubuf.resolution.x / max(ubuf.resolution.y, 1.0);
    vec2 uv = px / ubuf.resolution;
    vec2 p = vec2(uv.x * aspect, uv.y);
    vec2 fan = fanField(p, aspect, ubuf.time, ubuf.seed);
    bool inside = d < 0.0;
    float u = -d / w;
    float prof = inside ? (0.45 * exp(-u * 1.3) + 0.55 * exp(-u * u / 1.9)) * (1.0 - smoothstep(2.0, 3.4, u))
                        : 0.65 * exp(-(-u) * 4.0);
    float strength = 0.30 + 0.70 * (1.0 - exp(-4.0 * fan.y));
    vec3 col = lightSpectrum(clamp(fan.x + 0.06 * clamp(u, -1.0, 1.5), 0.0, 1.0));
    // Urgency leans the colour: critical towards amber, low towards moss; the field still shows through.
    col = mix(col, vec3(0.96, 0.62, 0.18), 0.65 * clamp(ubuf.urgency - 1.0, 0.0, 1.0));
    col = mix(col, vec3(0.53, 0.78, 0.55), 0.5 * clamp(1.0 - ubuf.urgency, 0.0, 1.0));
    float edge = exp(-(u / 0.20) * (u / 0.20)) * 0.12;
    vec3 rgb = (col * prof + AQUA * edge) * strength * 1.7;
    float nearEdge = exp(-abs(d) / (1.3 * w))
        * (inside ? 1.0 - smoothstep(1.4, 2.4, -d / w) : 1.0 - smoothstep(0.9, 1.6, d / w));
    rgb += glints(px, ubuf.rimWidth, ubuf.time, ubuf.seed) * nearEdge * 1.5;

    // Nothing until the front reaches an edge, a flare as it crosses, and a soft ring that fades before the overlay's border.
    float margin = min(min(opx.x, opx.y), min(ubuf.size.x - opx.x, ubuf.size.y - opx.y));
    rgb *= lit * (1.0 + 2.4 * flare);
    rgb += col * ring * 0.20 * smoothstep(0.0, 24.0, margin) * exp(-max(d, 0.0) / 12.0);   // it hugs the card, so the overlay's edge never shows

    // The icon: a ring with a spore, in the colour of the field there.
    if (ubuf.icon.z > 0.0) {
        float r = length(opx - ubuf.icon.xy);
        float ringI = exp(-pow((r - ubuf.icon.z) / 0.9, 2.0));
        float core = exp(-pow(r / 2.6, 2.0));
        vec3 icol = lightSpectrum(clamp(fan.x + 0.1, 0.0, 1.0));
        icol = mix(icol, vec3(0.96, 0.62, 0.18), 0.65 * clamp(ubuf.urgency - 1.0, 0.0, 1.0));
        rgb += icol * (ringI * 0.85 + core * 0.9) * 0.9 * solid;
    }

    vec3 light = 1.0 - exp(-rgb * ubuf.intensity * 2.0);
    fragColor = vec4(light, 0.0) * ubuf.qt_Opacity;
}
