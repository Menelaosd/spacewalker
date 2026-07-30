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
	# keep the giant endgame stations inside the chart boundary
	for i in Stations.count():
		_max_r = maxf(_max_r, Stations.world_pos(i).length() + 500.0)
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
		# freeze the sim under the open map — via the ref-counted coordinator so
		# it never fights the pause menu for ownership of get_tree().paused
		if visible:
			GameState.push_pause("starchart")
		else:
			GameState.pop_pause("starchart")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE and visible:
		visible = false
		GameState.pop_pause("starchart")
		queue_redraw()
		get_viewport().set_input_as_handled()


func _ship_pos() -> Vector2:
	if flight != null and is_instance_valid(flight):
		return flight.ship_pos
	return GameState.sector


# ------------------------------------------------------------------
# Instrument chrome — gradient plates, hairline borders, fitted labels
# ------------------------------------------------------------------
func _grad_rect(r: Rect2, top: Color, bottom: Color) -> void:
	## Vertical gradient fill. The chart's only panel material — kept near-black
	## so the void behind it never lifts.
	draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _plate(r: Rect2, accent: Color, a := 0.22) -> void:
	## Gradient backing + hairline border.
	_grad_rect(r, Color(0.047, 0.067, 0.102, 0.85), Color(0.024, 0.035, 0.059, 0.55))
	draw_rect(r, Color(accent.r, accent.g, accent.b, a), false, 1.0)


func _tw(s: String, size: int) -> float:
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _rng(d: float) -> String:
	## Range figure, never wider than six characters.
	if d >= 10000.0:
		return "%.0fk" % (d / 1000.0)
	if d >= 1000.0:
		return "%.1fk" % (d / 1000.0)
	return "%d" % int(d)


func _tag(anchor: Vector2, off: float, title: String, sub: String,
		size: int, col: Color, vp: Vector2) -> void:
	## One contact label: NAME at `size`, then a dimmer range figure two points
	## smaller on the same baseline. A negative `off` hangs the tag on the left of
	## the marker; a positive one flips left anyway when the tag would run past the
	## right edge, so a long station name can never clip.
	var sub_size := maxi(size - 2, 6)
	var nw := _tw(title, size)
	var sw := 0.0
	if sub != "":
		sw = _tw("  " + sub, sub_size)
	var x := anchor.x + off
	if off < 0.0:
		x = anchor.x + off - nw - sw
	elif x + nw + sw > vp.x - 10.0:
		x = anchor.x - off - nw - sw
	x = clampf(x, 6.0, maxf(vp.x - nw - sw - 6.0, 6.0))
	var y := clampf(anchor.y, 14.0, vp.y - 8.0)
	draw_string(_font, Vector2(x + 1.0, y + 1.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.65))
	draw_string(_font, Vector2(x, y), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if sub != "":
		draw_string(_font, Vector2(x + nw, y), "  " + sub,
			HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size,
			Color(col.r, col.g, col.b, 0.5))


func _station_pip(p: Vector2, dd: float, sc: Color, pulse: float) -> void:
	## A station landmark: haloed diamond with a hollow core.
	draw_circle(p, dd + 4.0 + pulse * 1.5, Color(sc.r, sc.g, sc.b, 0.12))
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -dd), p + Vector2(dd, 0),
		p + Vector2(0, dd), p + Vector2(-dd, 0)]), sc)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -dd * 0.45), p + Vector2(dd * 0.45, 0),
		p + Vector2(0, dd * 0.45), p + Vector2(-dd * 0.45, 0)]), Color(0.03, 0.06, 0.1))
	draw_arc(p, dd + 2.5, 0.0, TAU, 20, Color(sc.r, sc.g, sc.b, 0.7), 1.2)


func _draw() -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.012, 0.02, 0.035, 0.96))
	# hull-navy wash under the title block only — space itself stays black
	_grad_rect(Rect2(0.0, 0.0, vp.x, 170.0),
		Color(0.047, 0.067, 0.102, 0.5), Color(0.047, 0.067, 0.102, 0.0))

	var center := Vector2(vp.x * 0.5, vp.y * 0.54)
	var scale := minf(vp.x, vp.y) * 0.5 * 0.82 / _max_r
	var acc := UITheme.ACCENT
	var ship := _ship_pos()

	# outer boundary of the known void
	draw_arc(center, _max_r * scale, 0.0, TAU, 128, Color(acc.r, acc.g, acc.b, 0.10), 1.0)
	# concentric region rings
	for band in [[6600.0, "THE REACH"], [13200.0, "THE DRIFT"], [19800.0, "THE BELT"]]:
		var rr: float = float(band[0]) * scale
		draw_arc(center, rr, 0.0, TAU, 96, Color(acc.r, acc.g, acc.b, 0.13), 1.0)
		# label centred at the BOTTOM of each ring (the emptiest arc), never over centre
		# — a fade plate keeps the arc from striking through the type
		var bl: String = str(band[1])
		var blw := _tw(bl, 7) + 12.0
		_grad_rect(Rect2(center.x - blw * 0.5, center.y + rr - 15.0, blw, 14.0),
			Color(0.012, 0.02, 0.035, 0.0), Color(0.012, 0.02, 0.035, 0.85))
		draw_string(_font, center + Vector2(-60.0, rr - 4.0), bl,
			HORIZONTAL_ALIGNMENT_CENTER, 120.0, 7, Color(acc.r, acc.g, acc.b, 0.45))

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
			_tag(p + Vector2(0.0, 3.0), rad + 5.0, str(n["name"]),
				_rng((GameState.nebula_center(i) - ship).length()), 9,
				Color(col.r, col.g, col.b, 0.95), vp)
		else:
			draw_circle(p, 1.8, Color(0.55, 0.65, 0.75, 0.35))
			draw_string(_font, p + Vector2(3.5, 3.0), "?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.65, 0.75, 0.4))

	# current distress beacon (the live objective)
	if GameState.rescue_available():
		var bw := GameState.rescue_beacon()
		var bp := center + bw * scale
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		var dg := UITheme.DANGER
		# the live objective reads as the SELECTED contact: brackets + range
		UITheme.draw_brackets(self, Rect2(bp - Vector2(9.0, 9.0), Vector2(18.0, 18.0)),
			dg, 5.0, 0.0)
		draw_arc(bp, 7.0 + 4.0 * pulse, 0.0, TAU, 32, Color(dg.r, dg.g, dg.b, 0.9), 1.6)
		draw_circle(bp, 2.5, dg)
		_tag(bp + Vector2(0.0, 3.0), 13.0, "DISTRESS", _rng((bw - ship).length()),
			9, dg, vp)

	# --- endgame STATIONS: giant rescue-station landmarks (art in stations_v2/;
	# gameplay wiring is TODO — for now they mark the map so they aren't unused) ---
	var pulse := 0.5 + 0.5 * sin(_t * 2.5)
	var sc := Color(0.4, 0.95, 1.0)
	var st_spread := Stations.GAP * scale >= 54.0   # room for one name per diamond?
	if st_spread:
		for i in Stations.count():
			var stp := center + Stations.world_pos(i) * scale
			_station_pip(stp, 6.0, sc, pulse)
			_tag(stp + Vector2(0.0, 3.0), 11.0, str(Stations.LIST[i]["name"]),
				_rng((Stations.world_pos(i) - ship).length()), 9,
				Color(sc.r, sc.g, sc.b, 0.95), vp)
	else:
		# the grid is tighter than its own labels at this scale — ten diamonds and
		# ten names landed on top of each other. Collapse it to ONE counted contact.
		var cp := center + Stations.CLUSTER * scale
		_station_pip(cp, 7.0, sc, pulse)
		draw_arc(cp, 12.0 + pulse * 2.0, 0.0, TAU, 28, Color(sc.r, sc.g, sc.b, 0.30), 1.0)
		_tag(cp + Vector2(0.0, 3.0), 16.0, "STATIONS",
			"%d contacts  %s" % [Stations.count(),
				_rng((Stations.CLUSTER - ship).length())],
			9, Color(sc.r, sc.g, sc.b, 0.95), vp)

	# home
	draw_circle(center, 4.0, acc)
	draw_arc(center, 7.0, 0.0, TAU, 24, Color(acc.r, acc.g, acc.b, 0.6), 1.0)
	draw_string(_font, center + Vector2(8.0, 3.0), "HOME",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UITheme.TEXT_DIM)

	# the ship — a bright chevron that POINTS where you're heading (bow direction)
	var sp := center + ship * scale
	var warm := UITheme.ACCENT_WARM
	var head := 0.0
	if flight != null and is_instance_valid(flight):
		head = flight.heading   # ship bow angle (0 = +x); the arrow tip aligns to it
	draw_set_transform(sp, head + PI * 0.5, Vector2.ONE)   # chevron models "up" = bow
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -9), Vector2(6, 6), Vector2(0, 2.5), Vector2(-6, 6)]), warm)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# hung on the LEFT of the chevron — HOME and the station cluster both sit right
	_tag(sp + Vector2(0.0, -8.0), -9.0, "YOU", "", 8, warm, vp)

	# header — gradient plate, hairline border, width-fitted so nothing clips
	var hdr_w := 200.0
	var sub := "DISCOVERED  %d / %d  NEBULAE   ·   RANGE  %s" % [seen,
		GameState.NEBULAE.size(), _rng(ship.length())]
	var plate_w := maxf(hdr_w, _tw(sub, 8)) + 26.0
	var hx := vp.x * 0.5 - plate_w * 0.5 + 13.0
	_plate(Rect2(hx - 13.0, 26.0, plate_w, 54.0), acc, 0.20)
	UITheme.draw_header(self, Vector2(hx, 46.0), "STAR CHART", _font, 13, acc, hdr_w)
	draw_string(_font, Vector2(hx, 70.0), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UITheme.TEXT_DIM)
	UITheme.draw_hints_at(self, Vector2(vp.x * 0.5 - 50.0, vp.y - 38.0),
		[["M", "close"]], _font, 9)
