//modified version of [this shader](https://github.com/wessles/GLSL-CRT/blob/master/shader.frag)

precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

const vec3 VIB_RGB_BALANCE = vec3(1.0, 1.0, 1.0);
const float VIB_VIBRANCE = 0.40;


const vec3 VIB_coeffVibrance = VIB_RGB_BALANCE * -VIB_VIBRANCE;

void main() {
	vec2 tc = vec2(v_texcoord.x, v_texcoord.y);

	// Distance from the center
	float dx = abs(0.5-tc.x);
	float dy = abs(0.5-tc.y);

	// Square it to smooth the edges
	dx *= dx;
	dy *= dy;

	tc.x -= 0.5;
	tc.x *= 1.0 + (dy * 0.05);
	tc.x += 0.5;

	tc.y -= 0.5;
	tc.y *= 1.0 + (dx * 0.18);
	tc.y += 0.5;

	// Get texel, and add in scanline if need be
	vec4 cta = texture2D(tex, vec2(tc.x, tc.y));

	cta.rgb += sin(tc.y * 1250.0) * 0.02;

	// Cutoff
	if(tc.y > 1.0 || tc.x < 0.0 || tc.x > 1.0 || tc.y < 0.0)
		cta = vec4(0.0);


    // RGB
    vec3 color = vec3(cta[0], cta[1], cta[2]);


    // vec3 VIB_coefLuma = vec3(0.333333, 0.333334, 0.333333); // was for `if VIB_LUMA == 1`
    vec3 VIB_coefLuma = vec3(0.212656, 0.715158, 0.072186); // try both and see which one looks nicer.

    float luma = dot(VIB_coefLuma, color);

    float max_color = max(color[0], max(color[1], color[2]));
    float min_color = min(color[0], min(color[1], color[2]));

    float color_saturation = max_color - min_color;

    vec3 p_col = vec3(vec3(vec3(vec3(sign(VIB_coeffVibrance) * color_saturation) - 1.0) * VIB_coeffVibrance) + 1.0);

    cta[0] = mix(luma, color[0], p_col[0]);
    cta[1] = mix(luma, color[1], p_col[1]);
    cta[2] = mix(luma, color[2], p_col[2]);

	// Apply
	gl_FragColor = cta;
}