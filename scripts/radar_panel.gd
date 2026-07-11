extends Control
## Holographic resource radar — top-right of the spacewalk HUD.
## A cyan sweep disc: asteroid blips glow in their vein element's color
## (diamonds = rich crystal rock), loose ore chunks are sparks, and the
## ship is the square you never want to lose. Blips flare as the sweep
## line passes over them; the whole thing flickers like cheap holo tech.

const PANEL := Vector2(178, 196)
const R := 72.0                # disc radius in px
const RANGE_PAD := 300.0       # world range = tether reach + this

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
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
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

	var world_range: float = GameState.tether_length + GameState.tether_stretch() + RANGE_PAD
	var k := R / world_range
	var pp: Vector2 = player.global_position

	# tether reach ring, in world scale
	draw_arc(c, GameState.tether_length * k, 0.0, TAU, 40,
		Color(1.0, 0.85, 0.3, 0.22 * flick), 1.0)

	# asteroid blips — the resources, in their element's color
	for a in get_tree().get_nodes_in_group("asteroids"):
		var rel: Vector2 = (a.global_position - pp) * k
		if rel.length() > R - 3.0:
			continue
		var col: Color = Elements.hue_of(a.vein) if a.vein != "" else acc
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
	var ship_pos: Vector2 = ship.global_position if ship != null else Vector2.ZERO
	var srel := (ship_pos - pp) * k
	var clamped := srel.length() > R - 7.0
	if clamped:
		srel = srel.normalized() * (R - 7.0)
	var sp := c + srel
	var pulse := (0.7 + 0.3 * sin(_t * 5.0)) if clamped else 1.0
	draw_rect(Rect2(sp - Vector2(3.5, 3.5), Vector2(7, 7)),
		Color(acc.r, acc.g, acc.b, 0.95 * pulse * flick))
	draw_rect(Rect2(sp - Vector2(5.5, 5.5), Vector2(11, 11)),
		Color(acc.r, acc.g, acc.b, 0.4 * pulse * flick), false, 1.0)

	# you, dead center
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -4), c + Vector2(3, 3), c + Vector2(-3, 3)]),
		Color(1, 1, 1, 0.95 * flick))

	# frame + caption
	UITheme.draw_brackets(self, Rect2(c - Vector2(R + 8, R + 8),
		Vector2((R + 8) * 2.0, (R + 8) * 2.0)), acc, 10.0, 2.0)
	draw_string(_font, Vector2(0, 12), "◈ SCAN · %s" % \
		str(GameState.region_at(GameState.sector)["name"]).to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, PANEL.x, 11,
		Color(acc.r, acc.g, acc.b, 0.75 * flick))
	draw_string(_font, Vector2(0, PANEL.y - 2), "RNG %dm" % int(world_range),
		HORIZONTAL_ALIGNMENT_CENTER, PANEL.x, 10,
		Color(acc.r, acc.g, acc.b, 0.4 * flick))
