// Proton stream cursor shader for Ghostty (>= 1.2).
//
// Original shader. When the cursor jumps, a particle-thrower stream fires
// from where it was to where it landed: a white-hot core in a red-orange
// glow, blue and violet tendrils twisting around it, crackling arcs, and a
// flare where it hits. The stream whips and wobbles, then dissipates.
//
// Small moves (typing, single-cell motions) are ignored; see MIN_JUMP.

// --- CONFIGURATION ---
// Timing, in seconds at PACE = 1. PACE stretches the whole sequence (lay-out,
// whip, crack, fade) without slowing the flicker and twist; 2 = half speed.
const float PACE = 2.0;
const float DURATION = 0.70;    // whole effect
const float FIRE_TIME = 0.24;   // how long the stream takes to reach the target
const float CRACK_TIME = 0.30;  // when the loop reaches the tip and cracks
const float FADE_START = 0.45;  // when it starts to dissipate

// Where the stream comes from:
//   0 = the previous cursor position
//   1 = bottom centre of the window (like firing from the hip)
const int EMITTER = 0;

// Sizes are in cursor heights, so they scale with font size.
const float MIN_JUMP = 2.0;          // minimum move that fires the stream
const float CORE_WIDTH = 0.05;       // white-hot centre line
const float GLOW_WIDTH = 0.16;       // red-orange glow around the core
const float WOBBLE = 0.80;           // how far the whole stream snakes about
const float WHIP_LOOP = 1.6;         // height of the loop that rolls down the stream
const float WHIP_SAG = 0.10;         // how far the not-yet-cracked stream trails (fraction of the jump)
const float RECOIL = 0.6;            // ripple that runs back down the stream after the crack
const float TENDRIL_AMPLITUDE = 0.50; // radius of the twisting tendrils
const float TENDRIL_WIDTH = 0.055;
const float TWIST_LENGTH = 2.6;      // cursor heights per full twist
const float TWIST_SPEED = 38.0;      // radians per second
const float CRACKLE = 1.10;          // how far the arcs jump off the stream
const float INTENSITY = 1.0;         // overall brightness

// Colours (sRGB; converted to linear below).
const vec3 CORE_COLOR = vec3(1.00, 0.96, 0.88);
const vec3 GLOW_COLOR = vec3(1.00, 0.28, 0.06);
const vec3 TENDRIL_A_COLOR = vec3(0.20, 0.40, 1.00);
const vec3 TENDRIL_B_COLOR = vec3(0.60, 0.25, 1.00);
const vec3 ARC_COLOR = vec3(0.80, 0.88, 1.00);

// --- IMPLEMENTATION ---
const float PI = 3.14159265359;

vec3 sRGBToLinear(vec3 c) {
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

// Smooth 1D value noise in [-1, 1].
float noise1(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f);
    return mix(hash11(i), hash11(i + 1.0), u) * 2.0 - 1.0;
}

// Gaussian falloff: 1 on the line, ~0 a few widths away.
float band(float d, float w) {
    float x = d / w;
    return exp(-x * x);
}

// Sideways offset of the stream's centre line at position t (0..1 of the jump).
// Moves like a whip: the stream lays out, then an S-shaped loop rolls from
// the emitter to the tip, speeding up and tightening as it goes. Ahead of the
// loop the stream still trails to one side; behind it the stream is taut.
// When the loop reaches the tip it cracks and a smaller ripple recoils.
float whipOffset(float t, float side, float len, float H, float elapsed) {
    float w = clamp(elapsed / CRACK_TIME, 0.0, 1.0);
    float pos = w * w * (1.4 - 0.4 * w);           // accelerating, lands at 1
    float width = mix(0.16, 0.05, w);              // loop tightens as it speeds up
    float x = (t - pos) / width;
    float loop = WHIP_LOOP * H * (0.6 + 0.8 * w) * x * exp(-x * x) * 1.65;

    float ahead = smoothstep(pos - 0.05, pos + 0.15, t) * (1.0 - smoothstep(0.85, 1.0, w));
    float sag = WHIP_SAG * len * sin(PI * t) * ahead;

    float since = max(elapsed - CRACK_TIME, 0.0);
    float recoil = RECOIL * H * step(CRACK_TIME, elapsed) * exp(-since * 10.0)
                 * sin(2.0 * PI * (t * 2.5 + since * 7.0)) * sin(PI * t);

    return side * (loop * (1.0 - smoothstep(0.95, 1.05, w + since * 4.0)) + sag) + recoil;
}

vec2 cursorCenter(vec4 c) {
    // xy is the top-left corner (y grows upwards), zw is width/height.
    return c.xy + vec2(c.z, -c.w) * 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = base;

    float elapsed = iTime - iTimeCursorChange; // real seconds: flicker, twist
    float beat = elapsed / PACE;                // paced seconds: the motion
    if (beat < 0.0 || beat > DURATION) return;

    // Unit size: cursor height, guarding against bar/underline cursors.
    float H = max(max(iCurrentCursor.w, iCurrentCursor.z * 2.0), 4.0);

    vec2 target = cursorCenter(iCurrentCursor);
    vec2 previous = cursorCenter(iPreviousCursor);
    if (distance(previous, target) < MIN_JUMP * H) return;

    vec2 origin = EMITTER == 1 ? vec2(iResolution.x * 0.5, 0.0) : previous;
    vec2 seg = target - origin;
    float len = length(seg);
    if (len < 1.0) return;

    vec2 dir = seg / len;
    vec2 nrm = vec2(-dir.y, dir.x);
    vec2 rel = fragCoord - origin;
    float along = dot(rel, dir);
    float across = dot(rel, nrm);

    // Cheap reject for pixels far from the stream.
    float reachPx = 3.0 * H;
    if (abs(across) > reachPx * 2.0 + WHIP_SAG * len + (WHIP_LOOP + RECOIL) * H * 1.5 || along < -reachPx || along > len + reachPx) return;

    // Stream head lays out (ease-out), a loop whips down it and cracks at
    // the tip, and the whole thing fades.
    float fire = clamp(beat / FIRE_TIME, 0.0, 1.0);
    float head = 1.0 - (1.0 - fire) * (1.0 - fire);
    float side = hash11(floor(iTimeCursorChange * 10.0)) > 0.5 ? 1.0 : -1.0;
    float life = 1.0 - smoothstep(FADE_START, DURATION, beat);
    float flicker = 0.85 + 0.15 * noise1(elapsed * 45.0);

    // Position along the drawn part of the stream, capped at both ends.
    float t = clamp(along / len, 0.0, head);
    float s = t * len / H;                 // distance along, in cursor heights
    float env = max(sin(PI * t), 0.0);     // 0 at the ends, 1 in the middle
    float capDx = along - t * len;         // non-zero only past the ends

    // The stream snakes: the whip, a large slow bend, and tighter kinks.
    float whip = whipOffset(t, side, len, H, beat);
    float wob = whip + WOBBLE * H * env * (noise1(s * 0.35 - elapsed * 9.0) + 0.5 * noise1(s * 1.1 + elapsed * 16.0));

    // Where the loop is steep, sideways distance overstates true distance;
    // scale it so the stream keeps an even thickness around the bend.
    float dt = 0.01;
    float slope = (whipOffset(min(t + dt, 1.0), side, len, H, beat) - whip) / (dt * len);
    float k = inversesqrt(1.0 + slope * slope);
    across = across * k;
    wob = wob * k;

    // Core and glow.
    float dCore = length(vec2(capDx, across - wob));
    float core = band(dCore, CORE_WIDTH * H * (0.8 + 0.4 * flicker));
    float glow = band(dCore, GLOW_WIDTH * H);
    float halo = band(dCore, GLOW_WIDTH * H * 1.8) * 0.25;

    // Two tendrils on a helix around the core; brighter on the near side.
    float phase = s * (2.0 * PI / TWIST_LENGTH) - elapsed * TWIST_SPEED;
    float amp = TENDRIL_AMPLITUDE * H * sqrt(env);
    float dA = length(vec2(capDx, across - (wob + amp * sin(phase))));
    float dB = length(vec2(capDx, across - (wob + amp * sin(phase + PI))));
    float nearA = 0.35 + 0.65 * (0.5 + 0.5 * cos(phase));
    float nearB = 0.35 + 0.65 * (0.5 - 0.5 * cos(phase));
    float tendrilA = band(dA, TENDRIL_WIDTH * H) * nearA;
    float tendrilB = band(dB, TENDRIL_WIDTH * H) * nearB;

    // Crackling arcs: two jagged bolts, re-rolled ~30 times a second,
    // each flickering on and off independently.
    float tick = floor(elapsed * 30.0);
    float jag1 = noise1(s * 2.7 + tick * 17.3) + 0.5 * noise1(s * 7.1 - tick * 5.9);
    float jag2 = noise1(s * 3.3 - tick * 11.1) + 0.5 * noise1(s * 8.3 + tick * 7.7);
    float dArc1 = length(vec2(capDx, across - (wob + CRACKLE * H * env * jag1)));
    float dArc2 = length(vec2(capDx, across - (wob + CRACKLE * H * env * jag2)));
    float arc = band(dArc1, TENDRIL_WIDTH * H * 0.7) * step(0.2, hash11(tick + 3.7))
              + band(dArc2, TENDRIL_WIDTH * H * 0.6) * step(0.4, hash11(tick + 9.1));

    // Flare where the stream hits, plus a bright snap when the whip cracks.
    float hit = smoothstep(0.8, 1.0, head);
    float dHit = length(fragCoord - target) / H;
    float crack = band(beat - CRACK_TIME, 0.035);
    float flare = (hit * (0.75 + 0.25 * noise1(elapsed * 60.0)) + 1.5 * crack)
                * (exp(-dHit * 2.2) + 0.5 * band(dHit, 0.25 + 0.6 * crack));

    vec3 col = vec3(0.0);
    col += sRGBToLinear(GLOW_COLOR) * (glow * 0.9 + halo);
    col += sRGBToLinear(TENDRIL_A_COLOR) * tendrilA * 2.2;
    col += sRGBToLinear(TENDRIL_B_COLOR) * tendrilB * 2.2;
    col += sRGBToLinear(ARC_COLOR) * arc * 1.8;
    col += sRGBToLinear(CORE_COLOR) * core * 1.6;
    col += sRGBToLinear(mix(CORE_COLOR, GLOW_COLOR, 0.4)) * flare;

    col *= life * flicker * INTENSITY;
    fragColor = vec4(min(base.rgb + col, vec3(1.0)), base.a);
}
