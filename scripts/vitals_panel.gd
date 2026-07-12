extends Control
## Cockpit vitals — O2 and lifeline meters with numbers, cargo counters,
## and a pulsing low-oxygen warning. Fully custom-drawn, sci-fi styled.

const W := 300.0
const H := 126.0

var _font: Font = ThemeDB.fallback_font
var _t := 0.0


func _get_minimum_size() -> Vector2:
	return Vector2(W, H)


func _ready() -> void:
	custom_minimum_size = _get_minimum_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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

	UITheme.draw_sci_panel(self, Rect2(0, 0, W, H), accent)

	# O2 ring gauge on the right — the hero readout
	var ring_col := UITheme.DANGER if o2_low else Color(0.35, 0.8, 1.0)
	UITheme.draw_ring_gauge(self, Vector2(256, 52), 24.0, o2_frac, ring_col, _font)
	draw_string(_font, Vector2(232, 88), "O2", HORIZONTAL_ALIGNMENT_CENTER,
		48, 11, UITheme.TEXT_DIM)

	# O2 row
	draw_string(_font, Vector2(16, 30), "O2", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		UITheme.DANGER if o2_low else UITheme.TEXT)
	UITheme.draw_meter(self, Rect2(52, 16, 130, 16), o2_frac,
		Color(0.35, 0.8, 1.0), o2_low)
	draw_string(_font, Vector2(186, 29), "%d" % ceili(GameState.oxygen),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT_DIM)

	# LINE row
	var lf := _line_frac()
	draw_string(_font, Vector2(16, 56), "LINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		UITheme.TEXT)
	UITheme.draw_meter(self, Rect2(52, 42, 130, 16), lf,
		Color(1.0, 0.85, 0.3), lf < 0.12)
	draw_string(_font, Vector2(186, 55), "%d%%" % int(lf * 100.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT_DIM)

	# ORE BAG — the capped, return-home meter (the tension knob)
	var omax := GameState.ore_max()
	var ofrac := float(GameState.carried) / float(maxi(omax, 1))
	var full := GameState.carried >= omax
	_draw_ore_bag(Vector2(24, 82), full)
	draw_string(_font, Vector2(38, 78), "ORE BAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		UITheme.ACCENT_WARM if full else UITheme.TEXT_DIM)
	UITheme.draw_meter(self, Rect2(38, 82, 118, 10), ofrac,
		Color(1.0, 0.72, 0.25), full)
	draw_string(_font, Vector2(162, 90), "%d/%d" % [GameState.carried, omax],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		UITheme.ACCENT_WARM if full else UITheme.TEXT_DIM)

	# bottom line: element SAMPLES (no limit) · BANKED ore
	var samples := 0
	for s in GameState.carried_veins:
		samples += int(GameState.carried_veins[s])
	draw_circle(Vector2(20, 106), 4.0, Color(0.55, 0.9, 1.0))
	draw_string(_font, Vector2(30, 111), "SAMPLES %d" % samples,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT)
	draw_string(_font, Vector2(150, 111), "BANKED %d" % GameState.banked,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT_DIM)

	if o2_low:
		draw_string(_font, Vector2(210, 87), "⚠ O2 LOW",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(UITheme.DANGER.r, UITheme.DANGER.g, UITheme.DANGER.b,
				0.5 + 0.5 * absf(sin(_t * 5.0))))
