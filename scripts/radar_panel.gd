extends Control
## Holographic resource radar — top-right of the HUD, two modes.
## "walk" (spacewalk): asteroid blips in their vein element's color
## (diamonds = rich), loose ore sparks, the ship square, tether ring.
## "flight" (at the helm): whole asteroid FIELDS, salvage wrecks in
## their metal's hue, the home station, and nebula bearings — soft
## tinted blobs in range, rim ticks pointing the way when beyond.
## Blips flare as the sweep passes; the whole thing flickers like
## cheap holo tech.

const PANEL := Vector2(188, 214)
const R := 78.0                # disc radius in px
const RANGE_PAD := 300.0       # walk range = tether reach + this
const FLIGHT_RANGE := 3600.0   # helm scanner reach in world px

var mode := "walk"             # "walk" | "flight"
var flight: Node2D = null      # the flight scene, set when mode == "flight"

var _t := 0.0
var _font: Font = ThemeDB.fallback_font
var _derelict_tex: Texture2D = null    # small faint ship marker for derelicts
var _face_cache := {}                  # crew name -> small roster face texture


func _get_minimum_size() -> Vector2:
	return PANEL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/ui/derelict.svg"):
		_derelict_tex = load("res://assets/ui/derelict.svg")


func _draw_bezel(c: Vector2) -> void:
	## A turned-metal ring around the dial. The whole trick is that metal only reads as metal
	## when it is lit from ONE direction: each segment's brightness follows cos(angle - light),
	## so the ring catches a highlight upper-left and falls into shadow lower-right. A flat
	## grey annulus, however thick, reads as a drawn circle instead.
	const LIGHT := -2.36                      # upper-left, in radians
	const SEG := 96
	var steel := Color(0.60, 0.63, 0.68)
	# outer casing, widest and darkest, gives the ring something to sit proud of
	draw_arc(c, R + 11.0, 0.0, TAU, SEG, Color(0.055, 0.065, 0.080, 0.92), 9.0)
	for i in SEG:
		var a0: float = float(i) / float(SEG) * TAU
		var a1: float = float(i + 1) / float(SEG) * TAU
		var lit: float = 0.5 + 0.5 * cos(a0 - LIGHT)
		# two concentric bands, lit in opposition — the outer catches the light where the
		# inner is dark, which is what makes a ring look ROUND rather than painted on
		var o: float = 0.20 + 0.80 * pow(lit, 1.6)
		draw_arc(c, R + 7.5, a0, a1, 2,
			Color(steel.r * o, steel.g * o, steel.b * o * 1.03, 0.96), 5.0)
		var inv: float = 0.16 + 0.62 * pow(1.0 - lit, 1.4)
		draw_arc(c, R + 3.2, a0, a1, 2,
			Color(steel.r * inv, steel.g * inv, steel.b * inv, 0.95), 3.6)
	# machined edges: a bright wire on the outside, a dark one biting into the glass
	draw_arc(c, R + 10.0, 0.0, TAU, SEG, Color(0.80, 0.84, 0.90, 0.30), 1.0)
	draw_arc(c, R + 1.2, 0.0, TAU, SEG, Color(0.02, 0.03, 0.04, 0.85), 2.0)
	# six rivets, lit from the same source so they belong to the ring
	for i in 6:
		var a: float = LIGHT + float(i) / 6.0 * TAU
		var p := c + Vector2.from_angle(a) * (R + 7.5)
		var lit2: float = 0.5 + 0.5 * cos(a - LIGHT)
		draw_circle(p, 2.1, Color(0.10, 0.12, 0.14, 0.9))
		draw_circle(p - Vector2.from_angle(LIGHT) * 0.6, 1.3,
			Color(0.55 + 0.35 * lit2, 0.58 + 0.35 * lit2, 0.62 + 0.35 * lit2, 0.95))


func _crew_face(nm: String) -> Texture2D:
	## The rescued-crew roster portrait, cached, for the distress-beacon blip.
	if nm == "":
		return null
	if not _face_cache.has(nm):
		var path := "res://assets/sprites/crew/roster/%s_face.png" % nm.to_lower()
		_face_cache[nm] = load(path) if ResourceLoader.exists(path) else null
	return _face_cache[nm]


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

	var c := Vector2(PANEL.x * 0.5, PANEL.y * 0.5 + 8.0)
	var acc := UITheme.ACCENT
	# holo flicker: steady baseline with a faint heartbeat + a soft dropout
	var flick := 0.88 + 0.09 * sin(_t * 19.0) + 0.03 * sin(_t * 3.1)
	if fmod(_t, 4.7) < 0.07:
		flick *= 0.72

	# NO instrument plate and NO corner brackets. The scope is just the circle now — the
	# notched navy panel and the bracket frame were housing that added nothing the disc
	# does not already say.

	_draw_bezel(c)
	# THE FACE IS DRAWN WITH CIRCLES, NOT TEXTURES.
	# A GradientTexture2D radial has to be blitted with draw_texture_rect, and its corners
	# clamp to the gradient's last colour — which put a visible dark SQUARE around the dial.
	# Concentric circles are round by construction and cannot do that.
	draw_circle(c, R, Color(0.028, 0.030, 0.032, 0.97))
	# Restrained on purpose: this is a warm cast on the glass, not a lamp. The first pass
	# was twice this strong and read as a yellow disc rather than an aged instrument.
	var warm_a: float = 0.13 * (0.65 + 0.35 * flick)
	for i in 22:
		var f: float = 1.0 - float(i) / 22.0          # 1 at the centre, 0 at the rim
		var rr: float = R * (1.0 - float(i) / 22.0)
		# hold strength across the middle, then fall away fast near the glass edge
		var a: float = warm_a * pow(smoothstep(0.0, 0.55, f), 0.85) / 9.0
		draw_circle(c, rr, Color(0.98, 0.84 - 0.06 * (1.0 - f), 0.52, a))
	# inner shadow: a few tight rings hugging the rim so the face sits DOWN in the bezel
	for i in 7:
		var t: float = float(i) / 6.0
		draw_arc(c, R - 1.0 - t * 7.0, 0.0, TAU, 72,
			Color(0.0, 0.01, 0.02, 0.30 * (1.0 - t)), 2.6)
	for ring in [0.4, 0.7, 1.0]:
		draw_arc(c, R * ring, 0.0, TAU, 48,
			Color(acc.r, acc.g, acc.b, (0.22 if ring == 1.0 else 0.08) * flick), 1.0)
	# the bezel is the frame now; this is only the reflection where the dome meets metal
	draw_arc(c, R - 1.5, 0.0, TAU, 72, Color(acc.r, acc.g, acc.b, 0.30 * flick), 1.2)
	# glass seated INSIDE the ring — drawn last of the face layers so it darkens the
	# outer few percent and the dial stops looking flush with the bezel
	# short cardinal bearing ticks instead of a full crosshair (clears the middle)
	for ca in [0.0, PI * 0.5, PI, PI * 1.5]:
		draw_line(c + Vector2.from_angle(ca) * (R - 5.0), c + Vector2.from_angle(ca) * R,
			Color(acc.r, acc.g, acc.b, 0.18 * flick), 1.0)
	# faint scanlines — sparser + dimmer than before
	var sy := c.y - R + fmod(_t * 22.0, 11.0)
	while sy < c.y + R:
		var hw := sqrt(maxf(R * R - (sy - c.y) * (sy - c.y), 0.0))
		draw_line(Vector2(c.x - hw, sy), Vector2(c.x + hw, sy),
			Color(acc.r, acc.g, acc.b, 0.016 * flick), 1.0)
		sy += 11.0

	# sweep: one crisp leading edge + a short fading wake
	var sweep := fmod(_t * 1.5, TAU)
	draw_line(c, c + Vector2.from_angle(sweep) * R,
		Color(acc.r, acc.g, acc.b, 0.34 * flick), 1.2)
	for i in 9:
		var a := sweep - float(i) * 0.05
		draw_line(c, c + Vector2.from_angle(a) * R,
			Color(acc.r, acc.g, acc.b, (0.14 - 0.013 * float(i)) * flick), 1.2)

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

	# captions
	var where: String = str(GameState.region_at(
		center_pos if mode == "flight" else GameState.sector)["name"]).to_upper()
	if where.length() > 15:
		where = where.substr(0, 14) + "…"
	draw_string(_font, Vector2(0, 11), "◈ SCAN · %s" % where,
		HORIZONTAL_ALIGNMENT_CENTER, PANEL.x, 8,
		Color(acc.r, acc.g, acc.b, 0.8 * flick))
	var rng_label := "RNG %dkm" % int(world_range / 100.0) if mode == "flight" \
		else "RNG %dm" % int(world_range)
	draw_string(_font, Vector2(0, PANEL.y - 5), rng_label,
		HORIZONTAL_ALIGNMENT_CENTER, PANEL.x, 7,
		Color(acc.r, acc.g, acc.b, 0.52 * flick))


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
		if rel.length() > R - 3.5:   # keep the blip's own radius inside the dome
			continue
		var col: Color = Elements.hue_of(p.element) if p.element != "" else acc
		draw_circle(c + rel, 1.3,
			Color(col.r, col.g, col.b, 0.8 * _blip_alpha(rel.angle(), sweep) * flick))

	# the ship — clamped to the rim when out of range, so it always points home.
	# Skip entirely when there's no dock ship, or the blip would point at the
	# universe origin instead of home.
	var ship := get_tree().get_first_node_in_group("dock_ship")
	if ship != null:
		_plot_home(c, ship.global_position - pp, k, flick)


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
	var bearings := []
	for i in GameState.NEBULAE.size():
		var ncol: Color = GameState.NEBULAE[i]["color"]
		var rel := (GameState.nebula_center(i) - sp) * k
		var nr: float = GameState.nebula_radius(i) * k
		if rel.length() - nr < R - 4.0:
			var pos := c + rel.limit_length(R - 6.0)
			# clamp the blob so it never spills past the disc edge
			var inside := R - c.distance_to(pos) - 2.0
			var br := clampf(minf(nr, R * 0.55), 2.5, maxf(inside, 2.5))
			draw_circle(pos, br, Color(ncol.r, ncol.g, ncol.b, 0.16 * flick))
			draw_circle(pos, br * 0.5, Color(ncol.r, ncol.g, ncol.b, 0.13 * flick))
		else:
			bearings.append({"d": rel.length(), "dir": rel.normalized(), "col": ncol})
	# only the NEAREST few out-of-range nebulae, muted toward the scope cyan —
	# so the rim reads as a couple of bearings, not a rainbow of confetti
	bearings.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	for j in mini(5, bearings.size()):
		var bg: Dictionary = bearings[j]
		var tc: Color = (bg["col"] as Color).lerp(acc, 0.4)
		var bd: Vector2 = bg["dir"]
		draw_line(c + bd * (R - 3.5), c + bd * (R - 1.0),
			Color(tc.r, tc.g, tc.b, 0.5 * flick), 1.4)

	# STATIONS — the giant endgame landmarks. In range: a bright cyan diamond blip;
	# far: a cyan diamond bearing on the rim so you can steer toward them.
	for i in Stations.count():
		var srel: Vector2 = (Stations.world_pos(i) - sp) * k
		var far: bool = srel.length() >= R - 6.0
		var spos: Vector2 = c + (srel.normalized() * (R - 5.0) if far else srel)
		var dd: float = 2.6 if far else 4.2
		var sa: float = (0.75 if far else 0.95) * flick
		draw_colored_polygon(PackedVector2Array([
			spos + Vector2(0, -dd), spos + Vector2(dd, 0),
			spos + Vector2(0, dd), spos + Vector2(-dd, 0)]),
			Color(0.4, 0.95, 1.0, sa))
		if not far:
			draw_arc(spos, dd + 2.5, 0.0, TAU, 14, Color(0.4, 0.95, 1.0, 0.6 * flick), 1.0)

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

	# derelict SHIPS — a small, faint, ship-shaped marker (rarer than junk)
	if _derelict_tex != null:
		for cy in range(cc.y - span, cc.y + span + 1):
			for cx in range(cc.x - span, cc.x + span + 1):
				var w: Dictionary = flight._wreck_in_chunk(cx, cy)
				if w.is_empty() or w.get("taken", false):
					continue
				var wrel: Vector2 = ((w["pos"] as Vector2) - sp) * k
				if wrel.length() > R - 5.0:
					continue
				var mp := c + wrel
				var msz := 8.0 if w.get("rare", false) else 7.0
				var mcol := Color(0.72, 0.86, 0.96,
					0.5 * _blip_alpha(wrel.angle(), sweep) * flick)
				draw_set_transform(mp, float(w.get("rot", 0.0)) + PI * 0.5, Vector2.ONE)
				draw_texture_rect(_derelict_tex,
					Rect2(-msz * 0.5, -msz * 0.5, msz, msz), false, mcol)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# the current distress beacon — the mission pointer, in gold
	if GameState.rescue_available():
		var brel := (GameState.rescue_beacon() - sp) * k
		var gold := Color(1.0, 0.85, 0.3)
		var bpulse := 0.6 + 0.4 * sin(_t * 5.0)
		if brel.length() < R - 6.0:
			var bpt := c + brel
			var face := _crew_face(str(GameState.rescue_target().get("name", "")))
			if face != null:
				# the crew member's portrait, pinned on the scope as the objective
				var fs := 14.0
				draw_circle(bpt, fs * 0.62,
					Color(gold.r, gold.g, gold.b, 0.9 * bpulse * flick))
				draw_texture_rect(face,
					Rect2(bpt - Vector2(fs, fs) * 0.5, Vector2(fs, fs)),
					false, Color(1, 1, 1, flick))
				draw_arc(bpt, fs * 0.62, 0.0, TAU, 28,
					Color(gold.r, gold.g, gold.b, bpulse * flick), 1.5)
			else:
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
