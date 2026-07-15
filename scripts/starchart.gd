extends Control
## Full-screen STAR CHART overlay (toggle with M). Draws the whole known universe
## to scale: home at the centre, the concentric region rings (Reach/Drift/Belt/
## Expanse), and every deterministic nebula from GameState.NEBULAE — named + in
## colour once the ship has been near it (GameState.seen_regions), a faint unknown
## blip until then, so the sheer spread of undiscovered contacts reads as VAST.
## The live ship position and the current distress beacon are plotted on top.
##
## Data-only view: reads GameState + an optional `flight` ref for the live ship
## position (falls back to GameState.sector when opened from the interior).

const UITheme := preload("res://scripts/ui_theme.gd")

var flight: Node = null                       # optional, for live ship_pos
var can_open: Callable = func() -> bool: return true

var _font: Font = ThemeDB.fallback_font
var _max_r := 1000.0                          # universe radius in world units
var _t := 0.0                                 # clock for the beacon pulse


func _ready() -> void:
	# process while the tree is paused, so the chart still animates + takes input
	# when it pauses the sim (below) — the ship must not fly under the open map
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = OS.get_environment("SW_CHART") != ""   # screenshot aid (like SW_SHOW_INV)
	if visible:
		# reveal a spread of nebulae so the captured chart isn't empty
		for i in [0, 1, 2, 5, 9, 13, 18, 22]:
			if i < GameState.NEBULAE.size():
				GameState.seen_regions[i] = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# universe extent = the farthest nebula's far edge, plus a small margin
	for i in GameState.NEBULAE.size():
		_max_r = maxf(_max_r,
			float(GameState.NEBULAE[i]["dist"]) + GameState.nebula_radius(i))
	_max_r *= 1.06


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_M:
		if not visible and not can_open.call():
			return
		visible = not visible
		get_tree().paused = visible   # freeze the sim under the open map
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE and visible:
		visible = false
		get_tree().paused = false
		queue_redraw()
		get_viewport().set_input_as_handled()


func _ship_pos() -> Vector2:
	if flight != null and is_instance_valid(flight):
		return flight.ship_pos
	return GameState.sector


func _draw() -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.03, 0.05, 0.92))

	var center := Vector2(vp.x * 0.5, vp.y * 0.54)
	var scale := minf(vp.x, vp.y) * 0.5 * 0.82 / _max_r
	var acc := UITheme.ACCENT

	# outer boundary of the known void
	draw_arc(center, _max_r * scale, 0.0, TAU, 128, Color(acc.r, acc.g, acc.b, 0.10), 1.0)
	# concentric region rings
	for band in [[6600.0, "THE REACH"], [13200.0, "THE DRIFT"], [19800.0, "THE BELT"]]:
		var rr: float = float(band[0]) * scale
		draw_arc(center, rr, 0.0, TAU, 96, Color(acc.r, acc.g, acc.b, 0.13), 1.0)
		# label centred at the BOTTOM of each ring (the emptiest arc), never over centre
		draw_string(_font, center + Vector2(-60.0, rr - 5.0), str(band[1]),
			HORIZONTAL_ALIGNMENT_CENTER, 120.0, 8, Color(acc.r, acc.g, acc.b, 0.4))

	# nebulae — colour+name once seen, a faint unknown blip until then
	var seen := 0
	for i in GameState.NEBULAE.size():
		var n: Dictionary = GameState.NEBULAE[i]
		var p := center + GameState.nebula_center(i) * scale
		if GameState.seen_regions.has(i):
			seen += 1
			var col: Color = n["color"]
			var rad: float = maxf(GameState.nebula_radius(i) * scale, 3.5)
			draw_circle(p, rad, Color(col.r, col.g, col.b, 0.20))
			draw_arc(p, rad, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.75), 1.5)
			draw_string(_font, p + Vector2(rad + 4.0, 4.0), str(n["name"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(col.r, col.g, col.b, 0.95))
		else:
			draw_circle(p, 2.0, Color(0.55, 0.65, 0.75, 0.35))
			draw_string(_font, p + Vector2(4.0, 4.0), "?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.65, 0.75, 0.4))

	# current distress beacon (the live objective)
	if GameState.rescue_available():
		var bp := center + GameState.rescue_beacon() * scale
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		var dg := UITheme.DANGER
		draw_arc(bp, 7.0 + 4.0 * pulse, 0.0, TAU, 32, Color(dg.r, dg.g, dg.b, 0.9), 2.0)
		draw_circle(bp, 3.0, dg)
		draw_string(_font, bp + Vector2(9.0, 4.0), "DISTRESS",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, dg)

	# home
	draw_circle(center, 4.0, acc)
	draw_arc(center, 7.0, 0.0, TAU, 24, Color(acc.r, acc.g, acc.b, 0.6), 1.0)
	draw_string(_font, center + Vector2(9.0, 4.0), "HOME",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UITheme.TEXT_DIM)

	# the ship — a bright chevron so "you are here" pops
	var sp := center + _ship_pos() * scale
	var warm := UITheme.ACCENT_WARM
	draw_colored_polygon(PackedVector2Array([
		sp + Vector2(0, -6), sp + Vector2(5, 6), sp + Vector2(0, 3),
		sp + Vector2(-5, 6)]), warm)
	draw_string(_font, sp + Vector2(8.0, -2.0), "YOU",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, warm)

	# header + legend
	UITheme.draw_header(self, Vector2(vp.x * 0.5 - 130.0, 42.0), "STAR CHART",
		_font, 16, acc, 260.0)
	draw_string(_font, Vector2(vp.x * 0.5 - 130.0, 74.0),
		"DISCOVERED  %d / %d  NEBULAE" % [seen, GameState.NEBULAE.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)
	UITheme.draw_hints_at(self, Vector2(vp.x * 0.5 - 60.0, vp.y - 40.0),
		[["M", "close"]], _font, 10)
