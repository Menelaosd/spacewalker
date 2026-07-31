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
		# …and arm a distress beacon, so the course line is in the captured frame too
		GameState.quest_stage = maxi(GameState.quest_stage, 1)
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
		size: int, col: Color, vp: Vector2, avoid: Array[Rect2] = []) -> Rect2:
	## One contact label: NAME at `size`, then a dimmer range figure two points
	## smaller on the same baseline. A negative `off` hangs the tag on the left of
	## the marker; a positive one flips left anyway when the tag would run past the
	## right edge, so a long station name can never clip.
	##
	## Returns the box it occupied, and DRAWS NOTHING (returning an empty box) if that
	## box overlaps anything in `avoid`. That is how the ten scattered station names stay
	## off the nebula names: nebulae are placed first and are never suppressed, stations
	## yield. A label you cannot read is worse than a label that isn't there.
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
	var box := Rect2(x - 3.0, y - float(size) - 1.0, nw + sw + 6.0, float(size) + 5.0)
	for r in avoid:
		if box.intersects(r):
			return Rect2()
	draw_string(_font, Vector2(x + 1.0, y + 1.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.65))
	draw_string(_font, Vector2(x, y), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if sub != "":
		draw_string(_font, Vector2(x + nw, y), "  " + sub,
			HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size,
			Color(col.r, col.g, col.b, 0.5))
	return box


func _h(i: int, s: int) -> float:
	## Stable hash in 0..1. The starfield must be identical every frame or the chart
	## sparkles like static; deriving it from the index instead of randf() fixes that
	## without storing a single point.
	var x := float((i * 374761393 + s * 668265263) % 1000003)
	return fmod(sin(x) * 43758.5453, 1.0) * 0.5 + 0.5


func _starfield(center: Vector2, vp: Vector2, r_max: float) -> void:
	## Depth, cheaply: three passes of stars, the far ones dim and dense, the near ones
	## sparse and bright. Without this the chart is contacts floating on a flat wash and
	## the scale of the void never lands.
	for layer in 3:
		var count: int = [260, 120, 44][layer]
		var br: float = [0.16, 0.30, 0.55][layer]
		var sz: float = [0.7, 1.0, 1.5][layer]
		for i in count:
			var a: float = _h(i, layer * 7 + 1) * TAU
			# sqrt keeps the density even instead of clumping at the centre
			var rr: float = sqrt(_h(i, layer * 13 + 5)) * r_max * 1.06
			var p := center + Vector2.from_angle(a) * rr
			if p.x < -4.0 or p.x > vp.x + 4.0 or p.y < -4.0 or p.y > vp.y + 4.0:
				continue
			var tw: float = 0.75 + 0.25 * sin(_t * (0.6 + _h(i, layer) * 1.7) + float(i))
			var c: float = 0.72 + 0.28 * _h(i, layer * 3 + 2)
			draw_circle(p, sz, Color(c * 0.85, c * 0.92, c, br * tw))


func _polar_grid(center: Vector2, r_max: float, acc: Color) -> void:
	## Bearing spokes every 30°, fading outward. A navigation chart is polar — this is
	## what makes it read as an instrument rather than a poster of dots.
	# graduated rim: a tick every 5°, longer every 15°. This one detail is most of what
	# separates "a circle with dots in it" from an instrument face.
	for k in 72:
		var a: float = float(k) / 72.0 * TAU
		var d := Vector2.from_angle(a)
		var long: bool = k % 3 == 0
		draw_line(center + d * (r_max - (7.0 if long else 3.5)), center + d * r_max,
			Color(acc.r, acc.g, acc.b, 0.30 if long else 0.15), 1.0)
	for k in 12:
		var a: float = float(k) / 12.0 * TAU
		var d := Vector2.from_angle(a)
		var major: bool = k % 3 == 0
		for seg in 18:
			var t0: float = 0.10 + 0.90 * float(seg) / 18.0
			var t1: float = 0.10 + 0.90 * float(seg + 1) / 18.0
			var fade: float = (1.0 - t0) * (0.16 if major else 0.075)
			draw_line(center + d * (r_max * t0), center + d * (r_max * t1),
				Color(acc.r, acc.g, acc.b, fade), 1.0)
		if major:
			var lbl := "%03d" % int(round(rad_to_deg(a)))
			# INSIDE the rim: outside, 090 landed on top of the M-close hint
			var lp := center + d * (r_max * 0.945)
			draw_string(_font, lp - Vector2(14.0, -3.0), lbl,
				HORIZONTAL_ALIGNMENT_CENTER, 28.0, 7, Color(acc.r, acc.g, acc.b, 0.40))


func _cloud(p: Vector2, rad: float, col: Color, seed_i: int) -> void:
	## A nebula as a CLOUD, not a disc: a few offset lobes of decreasing alpha. Flat
	## circles made every region look like a bubble diagram.
	for j in 5:
		var a: float = _h(seed_i * 9 + j, 3) * TAU
		var off: float = _h(seed_i * 5 + j, 11) * rad * 0.45
		var rr: float = rad * (0.55 + 0.45 * _h(seed_i + j, 17))
		draw_circle(p + Vector2.from_angle(a) * off, rr,
			Color(col.r, col.g, col.b, 0.055))
	draw_circle(p, rad * 0.62, Color(col.r, col.g, col.b, 0.10))
	# filaments — partial arcs at odd radii. Lobes alone still read as a stack of discs;
	# the broken strokes are what make the eye call it gas.
	for j in 3:
		var a0: float = _h(seed_i * 31 + j, 23) * TAU
		var fr: float = rad * (0.66 + 0.34 * _h(seed_i * 7 + j, 29))
		draw_arc(p, fr, a0, a0 + 1.1 + _h(seed_i + j, 41) * 1.4, 20,
			Color(col.r, col.g, col.b, 0.16), 1.0)


## Radial warp. A linear chart is unreadable here: the universe radius is set by the
## farthest nebula (~60k) while HOME, the station cluster and THE REACH all live inside
## 6.6k — everything you actually care about collapsed into a pea at the centre with a
## vast empty ring around it. Raising the normalised distance to a power under 1 gives
## the near field most of the paper and still fits the far contacts on the same sheet.
const WARP := 0.62


func _proj(w: Vector2, r_max: float) -> Vector2:
	var d := w.length()
	if d < 1.0:
		return Vector2.ZERO
	return w / d * (pow(d / _max_r, WARP) * r_max)


func _pr(d: float, r_max: float) -> float:
	## Warped screen radius for a plain world distance (the region rings).
	return pow(clampf(d, 1.0, _max_r) / _max_r, WARP) * r_max


func _pw(d: float, wr: float, r_max: float) -> float:
	## A world-space SIZE (a nebula's radius) at distance `d`, through the warp — the
	## local derivative, clamped so a close-in region can't swell to fill the chart.
	var t := clampf(d, _max_r * 0.02, _max_r) / _max_r
	return clampf(wr * WARP * pow(t, WARP - 1.0) * r_max / _max_r, 4.0, 64.0)


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
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.008, 0.014, 0.026, 1.0))

	var center := Vector2(vp.x * 0.5, vp.y * 0.54)
	var acc := UITheme.ACCENT
	var ship := _ship_pos()
	var r_max := minf(vp.x, vp.y) * 0.5 * 0.82

	_starfield(center, vp, r_max)
	_polar_grid(center, r_max, acc)

	# the projection disc: a faint pool of light the chart is thrown onto, so the
	# contacts sit ON something instead of hanging in a black rectangle
	for i in 12:
		var t: float = float(i) / 12.0
		draw_circle(center, r_max * (1.0 - t * 0.06),
			Color(acc.r * 0.30, acc.g * 0.45, acc.b * 0.55, 0.012))
	# outer boundary of the known void — a real edge, with a soft inner falloff
	draw_arc(center, r_max, 0.0, TAU, 160, Color(acc.r, acc.g, acc.b, 0.34), 1.6)
	for i in 6:
		draw_arc(center, r_max - 1.0 - float(i) * 2.2, 0.0, TAU, 128,
			Color(acc.r, acc.g, acc.b, 0.05 * (1.0 - float(i) / 6.0)), 2.0)
	# a slow sweep, the same instrument language as the radar
	# The sweep, as a triangle fan with per-vertex alpha. Drawing it as N radial LINES
	# cannot work: at the rim the angular step outruns the line width, so it comes out
	# as a fan of separate spokes with a hard trailing edge — a pizza slice, not a beam.
	# Triangles tile the wedge with no gaps and fade smoothly both ways.
	var sweep := fmod(_t * 0.45, TAU)
	var span := 1.05
	for i in 48:
		var t0: float = float(i) / 48.0
		var t1: float = float(i + 1) / 48.0
		# ramp IN over the first couple of degrees as well, so the leading edge is a
		# bright rim rather than an alpha cliff
		var f0: float = pow(1.0 - t0, 2.0) * minf(1.0, t0 / 0.05)
		var f1: float = pow(1.0 - t1, 2.0) * minf(1.0, t1 / 0.05)
		var p0 := center + Vector2.from_angle(sweep - t0 * span) * r_max
		var p1 := center + Vector2.from_angle(sweep - t1 * span) * r_max
		draw_polygon(PackedVector2Array([center, p0, p1]),
			PackedColorArray([
				Color(acc.r, acc.g, acc.b, 0.085 * (f0 + f1) * 0.5),
				Color(acc.r, acc.g, acc.b, 0.030 * f0),
				Color(acc.r, acc.g, acc.b, 0.030 * f1)]))
	# the leading edge, tapered to nothing at the rim — a full-strength ray to the edge
	# reads as a drawn line rather than a beam
	var sd := Vector2.from_angle(sweep)
	for i in 20:
		var t0: float = float(i) / 20.0
		draw_line(center + sd * (r_max * t0), center + sd * (r_max * (t0 + 0.05)),
			Color(acc.r, acc.g, acc.b, 0.22 * (1.0 - t0 * 0.85)), 1.2)
	# Every plotted contact, in screen space, gathered BEFORE anything is labelled. The
	# ring names are placed by searching for the emptiest bearing against this list —
	# any fixed bearing (6 o'clock, the up-right diagonal) eventually lands on a nebula,
	# because where the contacts sit is data, not layout.
	# Each named contact contributes its marker AND two points along its tag, because a
	# name runs ~90px to the right of its dot — testing the dot alone let a ring name
	# land squarely on top of "Cerulean Shallows 23k".
	var cpts: Array[Vector2] = []
	for i in GameState.NEBULAE.size():
		var np := center + _proj(GameState.nebula_center(i), r_max)
		cpts.append(np)
		if GameState.seen_regions.has(i):
			cpts.append(np + Vector2(34.0, 0.0))
			cpts.append(np + Vector2(72.0, 0.0))
	for base in [Stations.centroid(), ship]:
		var bp2 := center + _proj(base, r_max)
		cpts.append(bp2)
		cpts.append(bp2 + Vector2(40.0, 0.0))
	if GameState.rescue_available():
		cpts.append(center + _proj(GameState.rescue_beacon(), r_max))

	# concentric region rings
	for band in [[6600.0, "THE REACH"], [13200.0, "THE DRIFT"], [19800.0, "THE BELT"]]:
		var rr: float = _pr(float(band[0]), r_max)
		draw_arc(center, rr, 0.0, TAU, 96, Color(acc.r, acc.g, acc.b, 0.13), 1.0)
		# put the name on the clearest arc of THIS ring: 24 candidate bearings, keep the
		# one whose label sits farthest from every contact
		var bl: String = str(band[1])
		var blw := _tw(bl, 7)
		var best := Vector2(0.7071, -0.7071)
		var best_d := -1.0
		for k in 24:
			var d := Vector2.from_angle(float(k) / 24.0 * TAU)
			var q := center + d * rr
			var worst := 1e9
			for cp2 in cpts:
				worst = minf(worst, q.distance_to(cp2))
			# a mild bias downward keeps the names off the header when nothing else decides
			worst += d.y * 6.0
			if worst > best_d:
				best_d = worst
				best = d
		var lp := center + best * rr
		draw_line(lp - best * 3.0, lp + best * 5.0, Color(acc.r, acc.g, acc.b, 0.30), 1.0)
		var tp := lp + best * 8.0 + Vector2(-blw * 0.5, 3.0)
		tp.x = clampf(tp.x, 8.0, vp.x - blw - 8.0)
		draw_rect(Rect2(tp.x - 3.0, tp.y - 8.0, blw + 6.0, 11.0),
			Color(0.008, 0.014, 0.026, 0.75))
		draw_string(_font, tp, bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
			Color(acc.r, acc.g, acc.b, 0.52))

	# nebulae — colour+name once seen, a faint unknown blip until then
	var seen := 0
	var taken: Array[Rect2] = []   # placed label boxes; stations yield to these
	for i in GameState.NEBULAE.size():
		var n: Dictionary = GameState.NEBULAE[i]
		var nc := GameState.nebula_center(i)
		var p := center + _proj(nc, r_max)
		if GameState.seen_regions.has(i):
			seen += 1
			var col: Color = n["color"]
			var rad: float = _pw(nc.length(), GameState.nebula_radius(i), r_max)
			_cloud(p, rad, col, i)
			draw_arc(p, rad, 0.0, TAU, 56, Color(col.r, col.g, col.b, 0.50), 1.2)
			draw_circle(p, 2.0, Color(col.r, col.g, col.b, 0.9))
			taken.append(_tag(p + Vector2(0.0, 3.0), rad + 5.0, str(n["name"]),
				_rng((GameState.nebula_center(i) - ship).length()), 9,
				Color(col.r, col.g, col.b, 0.95), vp))
		else:
			# an unsurveyed contact: a hollow ring reads as "something is there", where a
			# dot just read as more dust in the starfield. It PINGS as the beam crosses
			# it and decays behind — the one thing that makes the sweep mean something
			# instead of being a decoration laid over a static picture.
			var ping := 1.0 - clampf(fposmod(sweep - (p - center).angle(), TAU) / span,
				0.0, 1.0)
			ping = pow(ping, 3.0)
			if ping > 0.01:
				draw_circle(p, 3.0 + 5.0 * ping, Color(0.62, 0.80, 0.95, 0.16 * ping))
			draw_arc(p, 3.4, 0.0, TAU, 14,
				Color(0.58, 0.68, 0.80, 0.32 + 0.5 * ping), 1.0)
			draw_circle(p, 1.0, Color(0.58, 0.68, 0.80, 0.45 + 0.5 * ping))

	# current distress beacon (the live objective)
	if GameState.rescue_available():
		var bw := GameState.rescue_beacon()
		var bp := center + _proj(bw, r_max)
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		var dg := UITheme.DANGER
		# COURSE LINE from the ship to the objective — the one mark that makes the chart
		# a navigation tool instead of a picture. Dashed, and it crawls, so it reads as a
		# plotted heading rather than a static rule. Warped like everything else, so it
		# bends the same way the projection does.
		var a_sp := center + _proj(ship, r_max)
		var seg_n := int(a_sp.distance_to(bp) / 9.0)
		var crawl := fmod(_t * 0.9, 1.0)
		for i in seg_n:
			var t0: float = (float(i) + crawl) / float(maxi(seg_n, 1))
			if t0 > 1.0:
				continue
			var t1: float = minf(t0 + 0.45 / float(maxi(seg_n, 1)), 1.0)
			draw_line(a_sp.lerp(bp, t0), a_sp.lerp(bp, t1),
				Color(dg.r, dg.g, dg.b, 0.30), 1.0)
		# the live objective reads as the SELECTED contact: brackets + range
		UITheme.draw_brackets(self, Rect2(bp - Vector2(9.0, 9.0), Vector2(18.0, 18.0)),
			dg, 5.0, 0.0)
		draw_arc(bp, 7.0 + 4.0 * pulse, 0.0, TAU, 32, Color(dg.r, dg.g, dg.b, 0.9), 1.6)
		draw_circle(bp, 2.5, dg)
		taken.append(_tag(bp + Vector2(0.0, 3.0), 13.0, "DISTRESS",
			_rng((bw - ship).length()), 9, dg, vp))

	# --- the survivor STATIONS. Since they were scattered they are no longer one place
	# you visit at the end; they are ten destinations moored outside ten nebulae, and the
	# chart is how you find them. Every diamond always draws — the NAME is what yields
	# when there is no clean paper for it. Nearest first, so the ones you can actually
	# reach are the ones that keep their labels.
	var pulse := 0.5 + 0.5 * sin(_t * 2.5)
	var sc := Color(0.4, 0.95, 1.0)
	var order: Array[int] = []
	for i in Stations.count():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return Stations.world_pos(a).distance_to(ship) \
			< Stations.world_pos(b).distance_to(ship))
	for i in order:
		var swp := Stations.world_pos(i)
		var stp := center + _proj(swp, r_max)
		_station_pip(stp, 5.5, sc, pulse)
		var box := _tag(stp + Vector2(0.0, 3.0), 10.0, str(Stations.LIST[i]["name"]),
			_rng((swp - ship).length()), 9, Color(sc.r, sc.g, sc.b, 0.95), vp, taken)
		if box.size.x > 0.0:
			taken.append(box)

	# home — the origin the whole warp radiates from, so it gets a real glow
	for i in 9:
		draw_circle(center, 22.0 - float(i) * 2.2,
			Color(acc.r, acc.g, acc.b, 0.014))
	draw_circle(center, 4.0, acc)
	draw_arc(center, 7.0, 0.0, TAU, 24, Color(acc.r, acc.g, acc.b, 0.6), 1.0)
	draw_string(_font, center + Vector2(9.0, 12.0), "HOME",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UITheme.TEXT_DIM)

	# the ship — a bright chevron that POINTS where you're heading (bow direction)
	var sp := center + _proj(ship, r_max)
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

	# vignette: four bands of black creeping in from each edge, so the eye is pulled to
	# the disc and the chart feels like it is projected in a dark cockpit
	for i in 14:
		var t: float = float(i) / 14.0
		var a: float = 0.055 * (1.0 - t)
		var d: float = t * 120.0
		draw_rect(Rect2(0.0, d, vp.x, 9.0), Color(0, 0, 0, a))
		draw_rect(Rect2(0.0, vp.y - d - 9.0, vp.x, 9.0), Color(0, 0, 0, a))
		draw_rect(Rect2(d, 0.0, 9.0, vp.y), Color(0, 0, 0, a))
		draw_rect(Rect2(vp.x - d - 9.0, 0.0, 9.0, vp.y), Color(0, 0, 0, a))

	# HEADER, frameless. The plate and its hairline border were the only rectangle on a
	# chart made entirely of circles; the title now hangs on a fading rule instead.
	var title := "STAR CHART"
	var tw := _tw(title, 15)
	var tx := vp.x * 0.5 - tw * 0.5
	draw_string(_font, Vector2(tx + 1.0, 47.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.7))
	draw_string(_font, Vector2(tx, 46.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, acc)
	for side in [-1.0, 1.0]:
		for i in 26:
			var t: float = float(i) / 26.0
			var x0: float = vp.x * 0.5 + side * (tw * 0.5 + 14.0 + t * 190.0)
			var x1: float = vp.x * 0.5 + side * (tw * 0.5 + 14.0 + (t + 0.04) * 190.0)
			draw_line(Vector2(x0, 41.0), Vector2(x1, 41.0),
				Color(acc.r, acc.g, acc.b, 0.34 * (1.0 - t)), 1.0)
	# the two live figures, split to either side of the title
	draw_string(_font, Vector2(vp.x * 0.5 - 230.0, 66.0),
		"SURVEYED  %d / %d" % [seen, GameState.NEBULAE.size()],
		HORIZONTAL_ALIGNMENT_RIGHT, 220.0, 9, Color(acc.r, acc.g, acc.b, 0.62))
	draw_string(_font, Vector2(vp.x * 0.5 + 10.0, 66.0),
		"RANGE  %s" % _rng(ship.length()),
		HORIZONTAL_ALIGNMENT_LEFT, 220.0, 9, Color(acc.r, acc.g, acc.b, 0.62))
	UITheme.draw_hints_at(self, Vector2(vp.x * 0.5 - 50.0, vp.y - 38.0),
		[["M", "close"]], _font, 9)
