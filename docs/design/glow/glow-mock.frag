#version 440

// MOCK-UP shader (not shipped): what a toast looks like when it is lit by the same light as a window.
//
// The colour field (lightSpectrum, fanField, glints) is copied unchanged from the theme's windowglow.frag, and the band's
// profile is the same arithmetic, so a toast and a window beside it are lit by one and the same light; the only difference is
// the shape it hugs. `mode` 0 is separate cards (each its own rounded rectangle); 1 is one body (the cards smoothly merged,
// the gaps between them becoming necks of light). `wave` is the arrival: a front travelling out from the icon, solid inside
// it and nothing yet beyond it, the edge flaring as the front crosses it; -1 for settled.
// Output is premultiplied: the body's colour at its coverage in alpha, the light added to rgb.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intensity;
    float seed;
    float rimWidth;
    float depth;
    float mode;       // 0 separate, 1 one body
    float radius;
    float wave;       // -1 settled, else 0..1
    float neck;       // smooth-union radius for mode 1, px
    vec2 resolution;  // the whole screen, logical px
    vec2 origin;      // this frame's top left, in screen px
    vec2 cropSize;
    vec4 c0;          // cards: x, y, w, h in screen px; w <= 0 for none
    vec4 c1;
    vec4 c2;
    vec4 urg;         // urgency of c0, c1, c2 (0 low, 1 normal, 2 critical)
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


float cardSd(vec4 r, vec2 px) {
    if (r.z <= 0.0) return 1.0e5;
    vec2 hs = r.zw * 0.5;
    vec2 q = abs(px - (r.xy + hs)) - hs + vec2(ubuf.radius);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - ubuf.radius;
}

float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

void main() {
    vec2 px = ubuf.origin + qt_TexCoord0 * ubuf.cropSize;
    float s0 = cardSd(ubuf.c0, px), s1 = cardSd(ubuf.c1, px), s2 = cardSd(ubuf.c2, px);
    float d = ubuf.mode > 0.5 ? smin(smin(s0, s1, ubuf.neck), s2, ubuf.neck) : min(min(s0, s1), s2);

    float w = ubuf.rimWidth * max(ubuf.depth, 0.02);
    if (ubuf.wave < 0.0 && d > 1.6 * w + 30.0) { fragColor = vec4(0.0); return; }
    // one body: the necks between cards lie inside the union, so keep the glow out of them and draw the seam as a hairline
    float own = min(min(s0, s1), s2);
    float neckMask = ubuf.mode > 0.5 && d < 0.0 ? mix(0.12, 1.0, smoothstep(-1.0, 3.0, own)) : 1.0;

    // The arrival: a front out of the icon of the first card.
    vec2 ic = ubuf.c0.xy + vec2(32.0, 0.5 * ubuf.c0.w);
    float dist = length(px - ic);
    float front = ubuf.wave * 560.0;
    float solid = 1.0;
    float flare = 0.0;
    float ring = 0.0;
    if (ubuf.wave >= 0.0) {
        // only the arriving (first) card is affected
        float passed = 1.0 - smoothstep(front - 16.0, front + 10.0, dist);
        solid = mix(1.0, passed, step(s0, 14.0) * step(s0, d + 1.0));
        flare = exp(-pow((dist - front) / 16.0, 2.0)) * (1.0 - smoothstep(0.5, 1.0, ubuf.wave));
        ring = exp(-pow((dist - front) / 30.0, 2.0)) * pow(1.0 - ubuf.wave, 1.6);
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
    // Urgency leans the colour: critical towards amber, low towards moss. The nearest card decides, blended.
    float wa = exp(-min(s0, 60.0) / 8.0), wb = exp(-min(s1, 60.0) / 8.0), wc = exp(-min(s2, 60.0) / 8.0);
    float urgency = (wa * ubuf.urg.x + wb * ubuf.urg.y + wc * ubuf.urg.z) / (wa + wb + wc + 1e-5);
    col = mix(col, vec3(0.96, 0.62, 0.18), 0.65 * clamp(urgency - 1.0, 0.0, 1.0));
    col = mix(col, vec3(0.53, 0.78, 0.55), 0.5 * clamp(1.0 - urgency, 0.0, 1.0));
    float edge = exp(-(u / 0.20) * (u / 0.20)) * 0.12;
    vec3 rgb = (col * prof * neckMask + AQUA * edge * neckMask) * strength * 1.7;
    if (ubuf.mode > 0.5 && d < -2.5) {
        float seam = max(exp(-pow(s0 / 0.9, 2.0)), max(exp(-pow(s1 / 0.9, 2.0)), exp(-pow(s2 / 0.9, 2.0))));
        rgb += col * seam * 0.30 * strength * smoothstep(-2.5, -6.0, d);
    }
    float nearEdge = exp(-abs(d) / (1.3 * w))
        * (inside ? 1.0 - smoothstep(1.4, 2.4, -d / w) : 1.0 - smoothstep(0.9, 1.6, d / w));
    rgb += glints(px, ubuf.rimWidth, ubuf.time, ubuf.seed) * nearEdge * 1.5;

    // The arrival: nothing until the front reaches an edge, a flare as it crosses.
    float lit = ubuf.wave >= 0.0 ? mix(1.0, 1.0 - smoothstep(front - 10.0, front + 26.0, dist), step(s0, d + 1.0)) : 1.0;
    rgb *= lit * (1.0 + 2.4 * flare);
    rgb += col * ring * 0.20;

    // The icon: a ring with a spore, as in toastrim.frag.
    float r = length(px - ic);
    vec3 icol = lightSpectrum(clamp(fan.x + 0.1, 0.0, 1.0));
    icol = mix(icol, vec3(0.96, 0.62, 0.18), 0.65 * clamp(urgency - 1.0, 0.0, 1.0));
    float nearI1 = length(px - (ubuf.c1.xy + vec2(32.0, 0.5 * ubuf.c1.w)));
    float nearI2 = length(px - (ubuf.c2.xy + vec2(32.0, 0.5 * ubuf.c2.w)));
    float rr = min(r, min(ubuf.c1.z > 0.0 ? nearI1 : 1e5, ubuf.c2.z > 0.0 ? nearI2 : 1e5));
    float ring2 = exp(-pow((rr - 15.0) / 0.9, 2.0));
    float core = exp(-pow(rr / 2.6, 2.0));
    rgb += icol * (ring2 * 0.85 + core * 0.9) * 0.9 * solid;

    float cov = (1.0 - smoothstep(-0.5, 0.5, d)) * 0.93 * solid;
    vec3 body = vec3(0.141, 0.125, 0.082);
    // The light falls inside the body as well: a little of the band's colour tints the dark fill.
    vec3 light = 1.0 - exp(-rgb * ubuf.intensity * 2.0);
    fragColor = vec4(body * cov + light, cov) * ubuf.qt_Opacity;
}
