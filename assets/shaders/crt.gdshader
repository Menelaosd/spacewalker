shader_type canvas_item;
// STATIC CRT/VHS finish — scanlines, RGB phosphor mask, VHS chroma bleed,
// edge color fringe and tape grain. NO time-based warp/wobble/jitter
// (motion-sickness safe: every term is a pure function of pixel position).
// Techniques are the classic public-domain CRT recipes (cf. the CC0 shaders
// on godotshaders.com); implementation is ours.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float scan_strength : hint_range(0.0, 0.4) = 0.18;
uniform float scan_period : hint_range(1.0, 4.0) = 2.0;    // px between lines
uniform float mask_strength : hint_range(0.0, 0.4) = 0.10; // RGB phosphor triads
uniform float bleed : hint_range(0.0, 1.0) = 0.5;          // VHS chroma smear
uniform float vignette : hint_range(0.0, 1.0) = 0.0;       // off per captain
uniform float aberration : hint_range(0.0, 2.0) = 0.9;     // color fringe at edges
uniform float grain : hint_range(0.0, 0.1) = 0.025;        // static tape noise

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = uv - vec2(0.5);
	float d2 = dot(center, center);

	// chromatic aberration — grows toward the edges, tiny at center
	vec2 off = center * aberration * d2 * SCREEN_PIXEL_SIZE * 2.0;
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;

	// VHS chroma bleed — color smears sideways while luma stays sharp
	if (bleed > 0.0) {
		vec2 px = vec2(SCREEN_PIXEL_SIZE.x, 0.0);
		vec3 left = texture(screen_tex, uv - px * 2.0).rgb;
		vec3 right = texture(screen_tex, uv + px * 2.0).rgb;
		vec3 smear = (left + right) * 0.5;
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 blended = mix(col, smear, bleed * 0.5);
		float bl = dot(blended, vec3(0.299, 0.587, 0.114));
		col = blended * (luma / max(bl, 0.001));   // restore original luma
	}

	// scanlines keyed to physical pixel rows (static)
	float sl = 1.0 - scan_strength * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159265 / (scan_period * 0.5)));
	col *= sl;

	// RGB phosphor mask — aperture-grille triads across x (static)
	int band = int(mod(FRAGCOORD.x, 3.0));
	vec3 mask = vec3(1.0 - mask_strength);
	if (band == 0) { mask.r = 1.0; }
	else if (band == 1) { mask.g = 1.0; }
	else { mask.b = 1.0; }
	col *= mask;

	// vignette
	col *= 1.0 - vignette * smoothstep(0.15, 0.75, d2);

	// faint static grain (hashed from pixel position, no time term)
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;

	COLOR = vec4(col, 1.0);
}
