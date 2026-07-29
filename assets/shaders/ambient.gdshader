shader_type canvas_item;
render_mode blend_mix, unshaded;

// A single full-screen ambient / atmosphere pass for the ship interior.
// Everything is computed analytically — no gradient textures — so the falloff
// never banded-steps into the ugly "opacity circles" a PointLight2D pool makes.
//
// EVERYTHING HERE IS ANCHORED TO THE WORLD, NEVER TO THE SCREEN.
// The old version darkened by distance from the SCREEN CENTRE (`UV - 0.5`),
// which meant the dark/light gradient slid across the deck as the camera
// moved: rooms far from the player brightened just because the view swung
// toward them (measured: a distant medbay went +37% brighter from a camera
// nudge alone, with the player standing still). Now the lit pool is a
// rounded box around the ROOM THE PLAYER IS STANDING IN, handed over in
// viewport pixels by ship_interior.gd::_update_ambient(). Pan the view all
// day: not one pixel of the grade changes. Ordered pieces:
//   * a rounded-box falloff that darkens every deck outside the player's room
//   * a slow drifting FBM haze, world-locked, that reads as cabin dust
//   * a hash dither that erases 8-bit banding on the smooth gradient
// It also carries a faint cool tint (accent-shifted per room), which doubles
// as a unifying grade over the mixed-source art.

uniform float gloom_strength    : hint_range(0.0, 1.0) = 0.52;
uniform float haze_amount       : hint_range(0.0, 0.4) = 0.09;
uniform float dither_amount     : hint_range(0.0, 0.1) = 0.02;
uniform vec3  edge_color        = vec3(0.02, 0.04, 0.08);
uniform vec3  haze_color        = vec3(0.16, 0.34, 0.52);

// --- world-anchored pool (all in VIEWPORT PIXELS; pushed every frame) ---
uniform vec2  view_px    = vec2(1280.0, 720.0);  // viewport size
uniform vec2  pool_c     = vec2(640.0, 360.0);   // player's room centre, on screen
uniform vec2  pool_half  = vec2(135.0, 120.0);   // its half-extent (corner already inset)
uniform float pool_corner = 60.0;                // rounded-corner radius
uniform float pool_fade   = 360.0;               // px of falloff outside the room
// world <- screen mapping for the haze, so the dust hangs in the CABIN and
// does not smear across the glass as the camera pans
uniform vec2  world_org  = vec2(0.0, 0.0);
uniform float world_zoom = 1.0;

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
	vec2 px = UV * view_px;

	// signed distance to the player's room, rounded-box (0 inside its walls)
	vec2 q = abs(px - pool_c) - pool_half;
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - pool_corner;

	float vig = 1.0 - smoothstep(0.0, pool_fade, sd);   // 1 in your room, 0 far off
	float darken = (1.0 - vig) * gloom_strength;

	// cabin haze, in WORLD units so it drifts with the ship, not with the view
	vec2 wp = (px - world_org) / max(world_zoom, 0.001);
	float h = fbm(wp * 0.0024 + vec2(TIME * 0.012, TIME * 0.008));
	float haze = haze_amount * h * (0.35 + 0.65 * vig);

	vec3 col = mix(edge_color, haze_color, clamp(haze * 3.0, 0.0, 1.0));
	float alpha = clamp(darken + haze, 0.0, 1.0);

	alpha += (hash(FRAGCOORD.xy) - 0.5) * dither_amount;   // kill banding
	alpha = clamp(alpha, 0.0, 1.0);

	COLOR = vec4(col, alpha);
}
