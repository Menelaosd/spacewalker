extends Control
## Cockpit vitals — O2 and lifeline meters with numbers, cargo counters,
## and a pulsing low-oxygen warning. Fully custom-drawn, sci-fi styled.

const W := 300.0
const H := 126.0

var _font: Font = ThemeDB.fallback_font
var _t := 0.0
var _plate_tex: GradientTexture2D = null   # hull-navy gradient behind the panel


func _get_minimum_size() -> Vector2:
	return Vector2(W, H)


func _ready() -> void:
	custom_minimum_size = _get_minimum_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# instrument plate: lit along the top edge, sinking to near-black at the base
	var pg := Gradient.new()
	pg.set_color(0, Color(0.055, 0.105, 0.145, 0.94))
	pg.set_color(1, Color(0.016, 0.035, 0.055, 0.90))
	pg.add_point(0.55, Color(0.028, 0.062, 0.092, 0.92))
	_plate_tex = GradientTexture2D.new()
	_plate_tex.gradient = pg
	_plate_tex.fill_from = Vector2(0.0, 0.0)
	_plate_tex.fill_to = Vector2(0.0, 1.0)
	_plate_tex.width = 4
	_plate_tex.height = 128


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw_ore_bag(c: Vector2, full: bool) -> void:
	## A tiny pouch glyph: cinched neck, rounded belly, an ore fleck.
	var col := UITheme.ACCENT_WARM if full else Color(0.85, 0.7, 0.45)
	var body := PackedVector2Array([
		c + Vector2(-5, -3), c + Vector2(5, -3), c + Vector2(7, 6),
		c + Vector2(0, 9), c + Vector2(-7, 6)])
	draw_colored_polygon(body, Color(col.r, col.g, col.b, 0.28))
	draw_polyline(body + PackedVector2Array([c + Vector2(-5, -3)]), col, 1.4, true)
	# cinched neck
	draw_line(c + Vector2(-4, -3), c + Vector2(-3, -6), col, 1.4)
	draw_line(c + Vector2(4, -3), c + Vector2(3, -6), col, 1.4)
	draw_line(c + Vector2(-3, -6), c + Vector2(3, -6), col, 1.4)
	draw_circle(c + Vector2(0, 3), 1.8, col)   # ore fleck


func _bar_col(frac: float, full: Color) -> Color:
	## Meter fills step healthy -> amber -> red as the value runs down. Short
	## crossfades at each threshold so the shift reads at a glance and the fill
	## never sits on a muddy halfway colour.
	if frac >= 0.42:
		return full
	if frac >= 0.34:
		return UITheme.ACCENT_WARM.lerp(full, (frac - 0.34) / 0.08)
	if frac >= 0.18:
		return UITheme.ACCENT_WARM
	if frac >= 0.12:
		return UITheme.DANGER.lerp(UITheme.ACCENT_WARM, (frac - 0.12) / 0.06)
	return UITheme.DANGER


func _line_frac() -> float:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return 1.0
	var dist: float = player.global_position.distance_to(player.tether_anchor)
	return clampf(1.0 - dist / GameState.tether_length, 0.0, 1.0)


func _draw() -> void:
	var o2_frac := GameState.oxygen / GameState.max_oxygen
	var o2_low := o2_frac < 0.25
	var accent := UITheme.ACCENT
	if o2_low and fmod(_t, 0.8) < 0.4:
		accent = UITheme.DANGER

	var pr := Rect2(0, 0, W, H)
	if _plate_tex != null:
		var pts := UITheme.panel_points(pr)
		var uvs := PackedVector2Array()
		for pt in pts:
			uvs.append((pt - pr.position) / pr.size)
		draw_colored_polygon(pts, Color(1, 1, 1, 1), uvs, _plate_tex)
		UITheme.draw_sci_panel(self, pr, accent, Color(0, 0, 0, 0))
	else:
		UITheme.draw_sci_panel(self, pr, accent)

	# O2 ring gauge on the right — the hero readout
	var ring_col := _bar_col(o2_frac, Color(0.35, 0.8, 1.0))
	UITheme.draw_ring_gauge(self, Vector2(256, 52), 24.0, o2_frac, ring_col, _font)
	draw_string(_font, Vector2(232, 88), "O2", HORIZONTAL_ALIGNMENT_CENTER,
		48, 9, UITheme.TEXT_DIM)

	# O2 row
	draw_string(_font, Vector2(16, 30), "O2", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		UITheme.DANGER if o2_low else UITheme.TEXT)
	UITheme.draw_meter(self, Rect2(52, 16, 130, 16), o2_frac,
		_bar_col(o2_frac, Color(0.35, 0.8, 1.0)), o2_frac < 0.12)
	draw_string(_font, Vector2(186, 29), "%d" % ceili(GameState.oxygen),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)

	# LINE row
	var lf := _line_frac()
	draw_string(_font, Vector2(16, 56), "LINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		UITheme.TEXT)
	UITheme.draw_meter(self, Rect2(52, 42, 130, 16), lf,
		_bar_col(lf, Color(1.0, 0.85, 0.3)), lf < 0.08)
	draw_string(_font, Vector2(186, 55), "%d%%" % int(lf * 100.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)

	# ORE BAG — the capped, return-home meter (the tension knob)
	var omax := GameState.ore_max()
	var ofrac := float(GameState.carried) / float(maxi(omax, 1))
	var full := GameState.carried >= omax
	_draw_ore_bag(Vector2(24, 82), full)
	draw_string(_font, Vector2(38, 78), "ORE BAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		UITheme.ACCENT_WARM if full else UITheme.TEXT_DIM)
	# the bag reads amber while there is room and bleeds red as it packs out
	UITheme.draw_meter(self, Rect2(38, 82, 118, 10), ofrac,
		UITheme.DANGER.lerp(Color(1.0, 0.72, 0.25),
			clampf((1.0 - ofrac) / 0.25, 0.0, 1.0)), full)
	draw_string(_font, Vector2(162, 90), "%d/%d" % [GameState.carried, omax],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		UITheme.ACCENT_WARM if full else UITheme.TEXT_DIM)

	# bottom line: element SAMPLES (no limit) · BANKED ore
	var samples := 0
	for s in GameState.carried_veins:
		samples += int(GameState.carried_veins[s])
	draw_circle(Vector2(20, 106), 4.0, Color(0.55, 0.9, 1.0))
	draw_string(_font, Vector2(30, 111), "SAMPLES %d" % samples,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT)
	draw_string(_font, Vector2(150, 111), "BANKED %d" % GameState.banked,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)

	if o2_low:
		draw_string(_font, Vector2(196, 16), "⚠ O2 LOW",
			HORIZONTAL_ALIGNMENT_CENTER, 100, 10,
			Color(UITheme.DANGER.r, UITheme.DANGER.g, UITheme.DANGER.b,
				0.5 + 0.5 * absf(sin(_t * 5.0))))
