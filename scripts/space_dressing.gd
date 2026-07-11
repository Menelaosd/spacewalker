class_name SpaceDressing
## Painted light for a _draw()-based space. One shared sun direction so
## every scene (dive, flight, title) is lit from the same side, plus
## procedural distant planets, a glowing sun and comets. All static —
## scenes call these from their _draw().

# Where the light comes from (normalized). Upper-right, like the flare art.
const SUN_DIR := Vector2(0.6606, -0.7507)


static func sun_local(ci: CanvasItem) -> Vector2:
	## The sun direction expressed in a canvas item's local space, so
	## rotated nodes (asteroids) still shade toward the real sun.
	return SUN_DIR.rotated(-ci.get_global_transform().get_rotation())


# ------------------------------------------------------------------
# Distant planets — shaded discs with a lit side, terminator shadow,
# atmosphere rim and (sometimes) a ring. Deterministic per seed.
# ------------------------------------------------------------------
static func draw_planet(ci: CanvasItem, pos: Vector2, r: float, planet_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed
	var hue := rng.randf()
	var kind := rng.randi_range(0, 2)   # 0 rocky · 1 gas bands · 2 ice
	var sat: float = [0.35, 0.5, 0.25][kind]
	var base := Color.from_hsv(hue, sat, 0.42)
	var lit := SUN_DIR

	# body
	ci.draw_circle(pos, r, base)
	if kind == 1:
		# gas giant: latitude bands, clipped by redrawing inside the disc
		for i in 5:
			var by := (float(i) - 2.0) * r * 0.32
			var bw := sqrt(maxf(r * r - by * by, 0.0))
			var bc := base.lightened(0.12 + 0.1 * float(i % 2)) \
				if i % 2 == 0 else base.darkened(0.15)
			ci.draw_rect(Rect2(pos + Vector2(-bw, by - r * 0.11), Vector2(bw * 2.0, r * 0.22)), bc)
	elif kind == 0:
		# rocky: a few mare blotches
		for i in 4:
			var off := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.1, 0.6)
			ci.draw_circle(pos + off, r * rng.randf_range(0.12, 0.3), base.darkened(0.2))
	else:
		# ice: bright polar caps
		ci.draw_circle(pos + Vector2(0, -r * 0.72), r * 0.34, base.lightened(0.35))
		ci.draw_circle(pos + Vector2(0, r * 0.72), r * 0.3, base.lightened(0.3))

	# painted light: lit-side sheen, then the night side swallowed by shadow
	ci.draw_circle(pos + lit * r * 0.35, r * 0.72, Color(1.0, 0.98, 0.9, 0.10))
	ci.draw_circle(pos + lit * r * 0.5, r * 0.4, Color(1.0, 0.98, 0.9, 0.08))
	ci.draw_circle(pos - lit * r * 0.55, r * 0.85, Color(0.0, 0.01, 0.03, 0.5))
	# crisp rim on the day side, faint atmosphere glow past the edge
	var ang := lit.angle()
	ci.draw_arc(pos, r - 1.0, ang - 1.25, ang + 1.25, 24,
		Color(1.0, 1.0, 0.95, 0.35), 2.0)
	ci.draw_arc(pos, r + 3.0, ang - 1.5, ang + 1.5, 24,
		Color(base.lightened(0.5).r, base.lightened(0.5).g, base.lightened(0.5).b, 0.2), 4.0)

	# some worlds keep a ring
	if rng.randf() < 0.3:
		var rc := base.lightened(0.3)
		for i in 3:
			var rr := r * (1.5 + 0.16 * float(i))
			_draw_ellipse(ci, pos, rr, rr * 0.28, 0.35,
				Color(rc.r, rc.g, rc.b, 0.28 - 0.07 * float(i)), 2.0)


static func _draw_ellipse(ci: CanvasItem, pos: Vector2, rx: float, ry: float,
		tilt: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * float(i) / 40.0
		pts.append(pos + Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
	ci.draw_polyline(pts, col, width)


# ------------------------------------------------------------------
# The sun — a layered glow you can almost squint at
# ------------------------------------------------------------------
static func draw_sun(ci: CanvasItem, pos: Vector2, r: float, t: float) -> void:
	var pulse := 1.0 + 0.03 * sin(t * 0.7)
	# many thin layers — coarse steps band visibly on the dark backdrop
	for layer in [[8.0, 0.012], [6.6, 0.016], [5.4, 0.02], [4.3, 0.025],
			[3.3, 0.032], [2.5, 0.045], [1.9, 0.065], [1.45, 0.1]]:
		ci.draw_circle(pos, r * float(layer[0]) * pulse,
			Color(1.0, 0.85, 0.55, float(layer[1])))
	ci.draw_circle(pos, r * pulse, Color(1.0, 0.95, 0.8, 0.9))
	ci.draw_circle(pos, r * 0.6, Color(1.0, 1.0, 0.95))
	# cross flare spikes
	for a in [0.0, PI * 0.5]:
		var d := Vector2.from_angle(a + 0.12)
		ci.draw_line(pos - d * r * 5.0, pos + d * r * 5.0,
			Color(1.0, 0.9, 0.7, 0.10), 1.5)
		ci.draw_line(pos - d * r * 2.6, pos + d * r * 2.6,
			Color(1.0, 0.95, 0.85, 0.18), 2.5)


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
