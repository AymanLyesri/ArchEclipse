#version 300 es
precision mediump float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;

// --- USER TWEAK ZONE ---
const float GAMMA = 1.1;        // 1.0 = no change, 1.1–1.2 fixes washed panels
const float CONTRAST = 1.0;     // 1.0 = no change
const float VIBRANCE = 0.15;     // gentle, avoid >0.30
const vec3 WHITE_BALANCE = vec3(1.0, 1.0, 1.0);
// -----------------------

vec3 applyGamma(vec3 c) {
    return pow(c, vec3(GAMMA));
}

vec3 applyContrast(vec3 c) {
    return (c - 0.5) * CONTRAST + 0.5;
}

vec3 applyVibrance(vec3 c) {
    float maxC = max(c.r, max(c.g, c.b));
    float minC = min(c.r, min(c.g, c.b));
    float sat = maxC - minC;

    // Perceptual luma
    float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));

    // More boost to less saturated pixels
    float vib = 1.0 + VIBRANCE * (1.0 - sat);

    return mix(vec3(luma), c, vib);
}

void main() {
    vec4 pix = texture(tex, v_texcoord);
    vec3 col = pix.rgb;

    // 1. Correct panel tint
    col *= WHITE_BALANCE;

    // 2. Fix gamma first (most important!)
    col = applyGamma(col);

    // 3. Restore contrast
    col = applyContrast(col);

    // 4. Gentle vibrance instead of harsh saturation
    col = applyVibrance(col);

    fragColor = vec4(col, pix.a);
}
