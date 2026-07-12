shader_type canvas_item;
// Subtle, STATIC CRT finish — scanlines + vignette + a whisper of chromatic
// aberration at the edges. No time-based warp or wobble (motion-sickness safe).
// One full-screen pass on the GPU, so it costs almost nothing.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float scan_strength : hint_range(0.0, 0.3) = 0.07;
uniform float scan_period : hint_range(1.0, 4.0) = 2.0;   // px between lines
uniform float vignette : hint_range(0.0, 1.0) = 0.0;      // off — scanlines only
uniform float aberration : hint_range(0.0, 2.0) = 0.0;    // off
uniform float grain : hint_range(0.0, 0.1) = 0.0;         // off

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

	// scanlines keyed to physical pixel rows (static)
	float sl = 1.0 - scan_strength * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159265 / (scan_period * 0.5)));
	col *= sl;

	// vignette
	col *= 1.0 - vignette * smoothstep(0.15, 0.75, d2);

	// faint static grain (hashed from pixel position, no time term)
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;

	COLOR = vec4(col, 1.0);
}
