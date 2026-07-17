shader_type canvas_item;
render_mode blend_mix, unshaded;

// A single full-screen ambient / atmosphere pass. Everything is computed
// analytically — no gradient textures — so the falloff never banded-steps
// into the ugly "opacity circles" a PointLight2D pool makes. Ordered pieces:
//   * a smoothstep vignette that darkens the deck toward the screen edges
//   * a slow drifting FBM haze that reads as thin cabin atmosphere / dust
//   * a hash dither that erases 8-bit banding on the smooth gradient
// It also carries a faint cool tint, which doubles as a unifying grade over
// the mixed-source art.

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.52;
uniform float vignette_radius   : hint_range(0.2, 1.5) = 0.98;
uniform float haze_amount       : hint_range(0.0, 0.4) = 0.09;
uniform float dither_amount     : hint_range(0.0, 0.1) = 0.02;
uniform vec3  edge_color        = vec3(0.02, 0.04, 0.08);
uniform vec3  haze_color        = vec3(0.16, 0.34, 0.52);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.02;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 d = UV - vec2(0.5);
	d.x *= 1.15;                          // widen the pool to a ~16:9 ellipse
	float r = length(d) * 1.35;
	float vig = 1.0 - smoothstep(vignette_radius * 0.35, vignette_radius, r);

	float darken = (1.0 - vig) * vignette_strength;

	float h = fbm(UV * 2.4 + vec2(TIME * 0.012, TIME * 0.008));
	float haze = haze_amount * h * (0.35 + 0.65 * vig);

	vec3 col = mix(edge_color, haze_color, clamp(haze * 3.0, 0.0, 1.0));
	float alpha = clamp(darken + haze, 0.0, 1.0);

	alpha += (hash(FRAGCOORD.xy) - 0.5) * dither_amount;   // kill banding
	alpha = clamp(alpha, 0.0, 1.0);

	COLOR = vec4(col, alpha);
}
