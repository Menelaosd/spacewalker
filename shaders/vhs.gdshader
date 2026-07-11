shader_type canvas_item;
// Subtle VHS: chromatic aberration, scanlines, static grain, line wobble,
// a slow rolling brightness band. Applied to the world, under the HUD.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float aberration : hint_range(0.0, 4.0) = 1.1;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.028;
uniform float scanline_strength : hint_range(0.0, 0.3) = 0.07;
uniform float wobble : hint_range(0.0, 0.002) = 0.00035;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	// per-line horizontal wobble
	uv.x += sin(uv.y * 480.0 + t * 7.0) * wobble;
	// occasional stronger tape jitter on a narrow moving band
	float band = smoothstep(0.0, 0.004, 0.004 - abs(fract(uv.y + t * 0.11) - 0.5) * 0.008);
	uv.x += band * 0.0015 * sin(t * 60.0);
	// chromatic aberration
	vec2 off = vec2(aberration / 1280.0, 0.0);
	float r = texture(screen_tex, uv + off).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - off).b;
	vec3 col = vec3(r, g, b);
	// scanlines
	col *= 1.0 - scanline_strength * (0.5 + 0.5 * sin(uv.y * 2262.0));
	// static grain
	float n = fract(sin(dot(uv * (fract(t) + 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * noise_strength;
	// slow rolling luminance band
	col *= 1.0 + 0.025 * sin(uv.y * 6.0 - t * 0.6);
	COLOR = vec4(col, 1.0);
}
