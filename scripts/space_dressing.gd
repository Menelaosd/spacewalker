class_name SpaceDressing
## Painted light for a _draw()-based space. One shared (off-screen) sun
## direction so everything shades from the same side, plus comets and
## shooting stars. All static — scenes call these from their _draw().

# Where the light comes from (normalized). Upper-right, like the flare art.
const SUN_DIR := Vector2(0.6606, -0.7507)


static func sun_local(ci: CanvasItem) -> Vector2:
	## The sun direction expressed in a canvas item's local space, so
	## rotated nodes (asteroids) still shade toward the real sun.
	return SUN_DIR.rotated(-ci.get_global_transform().get_rotation())


# ------------------------------------------------------------------
# Comets & shooting stars — {pos, vel, size, life} dictionaries owned
# by the scene; these just paint them.
# ------------------------------------------------------------------
static func draw_comet(ci: CanvasItem, c: Dictionary, t: float) -> void:
	var pos: Vector2 = c["pos"]
	var dirv: Vector2 = (c["vel"] as Vector2).normalized()
	var size: float = c["size"]
	var fade: float = clampf(float(c["life"]) / 2.0, 0.0, 1.0)
	# tail: three tapering streaks, ice-blue fading to nothing
	for i in 3:
		var jig := dirv.orthogonal() * (float(i) - 1.0) * size * 0.8
		var back := pos - dirv * size * (14.0 + 4.0 * float(i)) + jig
		ci.draw_line(back, pos, Color(0.6, 0.85, 1.0, 0.16 * fade), size * (1.6 - 0.4 * float(i)))
	ci.draw_line(pos - dirv * size * 8.0, pos, Color(0.85, 0.95, 1.0, 0.4 * fade), size * 0.9)
	# head with a hot core and flicker
	ci.draw_circle(pos, size * 1.7, Color(0.7, 0.9, 1.0, 0.25 * fade))
	ci.draw_circle(pos, size * (0.9 + 0.15 * sin(t * 11.0)), Color(1, 1, 1, 0.9 * fade))
