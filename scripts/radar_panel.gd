extends Control
## Holographic resource radar — top-right of the HUD, two modes.
## "walk" (spacewalk): asteroid blips in their vein element's color
## (diamonds = rich), loose ore sparks, the ship square, tether ring.
## "flight" (at the helm): whole asteroid FIELDS, salvage wrecks in
## their metal's hue, the home station, and nebula bearings — soft
## tinted blobs in range, rim ticks pointing the way when beyond.
## Blips flare as the sweep passes; the whole thing flickers like
## cheap holo tech.

const PANEL := Vector2(178, 196)
const R := 72.0                # disc radius in px
const RANGE_PAD := 300.0       # walk range = tether reach + this
const FLIGHT_RANGE := 3600.0   # helm scanner reach in world px

var mode := "walk"             # "walk" | "flight"
var flight: Node2D = null      # the flight scene, set when mode == "flight"

var _t := 0.0
var _font: Font = ThemeDB.fallback_font


func _get_minimum_size() -> Vector2:
	return PANEL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _blip_alpha(rel_ang: float, sweep: float) -> float:
	## Blips burn bright right behind the sweep line and cool off after.
	var diff := wrapf(sweep - rel_ang, 0.0, TAU)
	return clampf(1.0 - diff / 4.6, 0.25, 1.0)


func _draw() -> void:
	var center_pos := Vector2.ZERO
	var world_range := 0.0
	var face_ang := -PI * 0.5   # which way you're actually pointed/moving
	if mode == "flight":
		if flight == null:
			return
		center_pos = flight.ship_pos
		world_range = FLIGHT_RANGE
		face_ang = flight.heading
	else:
		var player := get_tree().get_first_node_in_group("player")
		if player == null:
			return
		center_pos = player.global_position
		world_range = GameState.tether_length + GameState.tether_stretch() + RANGE_PAD
		# drifting = the arrow tracks your motion; still = it tracks your aim
		if (player.velocity as Vector2).length() > 14.0:
			face_ang = (player.velocity as Vector2).angle()
		else:
			face_ang = (player.aim_dir as Vector2).angle()

	var c := Vector2(PANEL.x * 0.5, PANEL.y * 0.5 + 10.0)
	var acc := UITheme.ACCENT
	# holo flicker: mostly steady, with a heartbeat shimmer and rare dropouts
	var flick := 0.82 + 0.12 * sin(_t * 19.0) + 0.06 * sin(_t * 3.1)
	if fmod(_t, 4.7) < 0.07:
		flick *= 0.45

	# projected disc
	draw_circle(c, R + 6.0, Color(acc.r, acc.g, acc.b, 0.05 * flick))
	draw_circle(c, R, Color(0.01, 0.06, 0.09, 0.75))
	for ring in [0.33, 0.66, 1.0]:
		draw_arc(c, R * ring, 0.0, TAU, 48,
			Color(acc.r, acc.g, acc.b, (0.3 if ring == 1.0 else 0.12) * flick), 1.0)
	draw_line(c - Vector2(R, 0), c + Vector2(R, 0),
		Color(acc.r, acc.g, acc.b, 0.08 * flick), 1.0)
	draw_line(c - Vector2(0, R), c + Vector2(0, R),
		Color(acc.r, acc.g, acc.b, 0.08 * flick), 1.0)
	# horizontal scanlines sell the hologram
	var sy := c.y - R + fmod(_t * 26.0, 8.0)
	while sy < c.y + R:
		var hw := sqrt(maxf(R * R - (sy - c.y) * (sy - c.y), 0.0))
		draw_line(Vector2(c.x - hw, sy), Vector2(c.x + hw, sy),
			Color(acc.r, acc.g, acc.b, 0.03 * flick), 1.0)
		sy += 8.0

	# sweep beam with a fading wake
	var sweep := fmod(_t * 1.5, TAU)
	for i in 14:
		var a := sweep - float(i) * 0.055
		draw_line(c, c + Vector2.from_angle(a) * R,
			Color(acc.r, acc.g, acc.b, (0.20 - 0.014 * float(i)) * flick), 2.0)

	var k := R / world_range

	if mode == "flight":
		_plot_flight(c, center_pos, k, sweep, flick)
	else:
		_plot_walk(c, center_pos, k, sweep, flick)

	# you, dead center — the arrow points where you're headed
	var nose := Vector2.from_angle(face_ang)
	var wing := nose.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		c + nose * 5.0, c - nose * 3.0 + wing * 3.5, c - nose * 3.0 - wing * 3.5]),
		Color(1, 1, 1, 0.95 * flick))
	# faint motion wake behind the arrow
	draw_line(c - nose * 3.0, c - nose * 8.0,
		Color(1, 1, 1, 0.3 * flick), 1.0)

	# frame + captions
	UITheme.draw_brackets(self, Rect2(c - Vector2(R + 8, R + 8),
		Vector2((R + 8) * 2.0, (R + 8) * 2.0)), acc, 10.0, 2.0)
	var where: String = str(GameState.region_at(
		center_pos if mode == "flight" else GameState.sector)["name"]).to_upper()
	draw_string(_font, Vector2(0, 12), "◈ SCAN · %s" % where,
		HORIZONTAL_ALIGNMENT_CENTER, PANEL.x, 11,
		Color(acc.r, acc.g, acc.b, 0.75 * flick))
	var rng_label := "RNG %dkm" % int(world_range / 100.0) if mode == "flight" \
		else "RNG %dm" % int(world_range)
	draw_string(_font, Vector2(0, PANEL.y - 2), rng_label,
		HORIZONTAL_ALIGNMENT_CENTER, PANEL.x, 10,
		Color(acc.r, acc.g, acc.b, 0.4 * flick))


# ------------------------------------------------------------------
# Spacewalk plot: individual rocks, ore chunks, the ship
# ------------------------------------------------------------------
func _plot_walk(c: Vector2, pp: Vector2, k: float, sweep: float, flick: float) -> void:
	var acc := UITheme.ACCENT
	# tether reach ring, in world scale
	draw_arc(c, GameState.tether_length * k, 0.0, TAU, 40,
		Color(1.0, 0.85, 0.3, 0.22 * flick), 1.0)

	# asteroid blips — the resources, in their element's color
	for a in get_tree().get_nodes_in_group("asteroids"):
		var rel: Vector2 = (a.global_position - pp) * k
		if rel.length() > R - 3.0:
			continue
		var col: Color = Elements.cpk_color(a.vein) if a.vein != "" else acc
		var al := _blip_alpha(rel.angle(), sweep) * flick
		var bp := c + rel
		if a.is_rich:
			# rich crystal: a diamond you can spot across the room
			var s := 3.4
			draw_colored_polygon(PackedVector2Array([
				bp + Vector2(0, -s), bp + Vector2(s, 0),
				bp + Vector2(0, s), bp + Vector2(-s, 0)]),
				Color(col.r, col.g, col.b, al))
			draw_circle(bp, 6.0, Color(col.r, col.g, col.b, 0.2 * al))
		else:
			draw_circle(bp, 2.3, Color(col.r, col.g, col.b, al))

	# loose ore chunks — faint sparks worth swinging back for
	for p in get_tree().get_nodes_in_group("pickups"):
		var rel: Vector2 = (p.global_position - pp) * k
		if rel.length() > R - 2.0:
			continue
		var col: Color = Elements.hue_of(p.element) if p.element != "" else acc
		draw_circle(c + rel, 1.3,
			Color(col.r, col.g, col.b, 0.8 * _blip_alpha(rel.angle(), sweep) * flick))

	# the ship — clamped to the rim when out of range, so it always points home
	var ship := get_tree().get_first_node_in_group("dock_ship")
	_plot_home(c, (ship.global_position if ship != null else Vector2.ZERO) - pp, k, flick)


# ------------------------------------------------------------------
# Helm plot: asteroid fields, wrecks, nebula bearings
# ------------------------------------------------------------------
func _plot_flight(c: Vector2, sp: Vector2, k: float, sweep: float, flick: float) -> void:
	var acc := UITheme.ACCENT
	var chunk: float = flight.FIELD_CHUNK
	var cc := Vector2i((sp / chunk).floor())
	var span := int(ceil(FLIGHT_RANGE / chunk)) + 1

	# nebulas first (under everything): in range = soft tinted cloud,
	# out of range = a colored tick on the rim pointing the way
	for i in GameState.NEBULAE.size():
		var ncol: Color = GameState.NEBULAE[i]["color"]
		var rel := (GameState.nebula_center(i) - sp) * k
		var nr: float = GameState.nebula_radius(i) * k
		if rel.length() - nr < R - 4.0:
			var pos := c + rel.limit_length(R - 6.0)
			# clamp the blob so it never spills past the disc edge
			var inside := R - c.distance_to(pos) - 2.0
			var br := clampf(minf(nr, R * 0.6), 2.5, maxf(inside, 2.5))
			draw_circle(pos, br, Color(ncol.r, ncol.g, ncol.b, 0.16 * flick))
			draw_circle(pos, br * 0.5, Color(ncol.r, ncol.g, ncol.b, 0.13 * flick))
		else:
			var dir := rel.normalized()
			draw_line(c + dir * (R - 6.0), c + dir * (R - 1.0),
				Color(ncol.r, ncol.g, ncol.b, 0.8 * flick), 2.5)

	# asteroid fields — one ring per field, gold→cyan by richness
	for cy in range(cc.y - span, cc.y + span + 1):
		for cx in range(cc.x - span, cc.x + span + 1):
			var f: Dictionary = flight._field_in_chunk(cx, cy)
			if f.is_empty():
				continue
			var rel: Vector2 = ((f["center"] as Vector2) - sp) * k
			if rel.length() > R - 4.0:
				continue
			var col := Color(1.0, 0.72, 0.25).lerp(Color(0.4, 0.95, 1.0),
				clampf(float(f["rich"]), 0.0, 1.0))
			var al := _blip_alpha(rel.angle(), sweep) * flick
			var bp := c + rel
			var fr: float = maxf((f["radius"] as float) * k, 2.5)
			draw_arc(bp, fr, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.7 * al), 1.2)
			draw_circle(bp, 1.8, Color(col.r, col.g, col.b, al))

	# salvage wrecks — sparks in their metal's color
	for cy in range(cc.y - span, cc.y + span + 1):
		for cx in range(cc.x - span, cc.x + span + 1):
			for piece in flight._trash_in_chunk(cx, cy):
				if piece["taken"]:
					continue
				var rel: Vector2 = ((piece["pos"] as Vector2) - sp) * k
				if rel.length() > R - 3.0:
					continue
				var col: Color = Elements.hue_of(piece["metal"])
				draw_circle(c + rel, 1.6,
					Color(col.r, col.g, col.b, 0.9 * _blip_alpha(rel.angle(), sweep) * flick))

	# the current distress beacon — the mission pointer, in gold
	if GameState.rescue_available():
		var brel := (GameState.rescue_beacon() - sp) * k
		var gold := Color(1.0, 0.85, 0.3)
		var bpulse := 0.6 + 0.4 * sin(_t * 5.0)
		if brel.length() < R - 6.0:
			var bpt := c + brel
			draw_circle(bpt, 3.0, Color(gold.r, gold.g, gold.b, bpulse * flick))
			draw_arc(bpt, 6.5, 0.0, TAU, 12,
				Color(gold.r, gold.g, gold.b, 0.5 * bpulse * flick), 1.2)
		else:
			var bdir := brel.normalized()
			draw_colored_polygon(PackedVector2Array([
				c + bdir * (R - 2.0),
				c + bdir * (R - 10.0) + bdir.orthogonal() * 4.0,
				c + bdir * (R - 10.0) - bdir.orthogonal() * 4.0]),
				Color(gold.r, gold.g, gold.b, 0.9 * bpulse * flick))


# Plots a square blip (your parked ship on the spacewalk radar), clamped to the
# rim when out of range so it always points the way back to the airlock.
func _plot_home(c: Vector2, rel_world: Vector2, k: float, flick: float) -> void:
	var acc := UITheme.ACCENT
	var srel := rel_world * k
	var clamped := srel.length() > R - 7.0
	if clamped:
		srel = srel.normalized() * (R - 7.0)
	var sp2 := c + srel
	var pulse := (0.7 + 0.3 * sin(_t * 5.0)) if clamped else 1.0
	draw_rect(Rect2(sp2 - Vector2(3.5, 3.5), Vector2(7, 7)),
		Color(acc.r, acc.g, acc.b, 0.95 * pulse * flick))
	draw_rect(Rect2(sp2 - Vector2(5.5, 5.5), Vector2(11, 11)),
		Color(acc.r, acc.g, acc.b, 0.4 * pulse * flick), false, 1.0)
