extends Control
## Quest log — an analytical objectives panel under the radar. Live from
## GameState: the jump-drive rebuild (part X/5 with a progress bar and a
## per-material breakdown) and the search for the five scattered survivors
## (pips + next beacon). Sci-fi styled to match the HUD.

const PANEL := Vector2(224.0, 234.0)   # tall enough for 3-element drive parts
                                       # + a live rescue beacon (was 206, spilled)

var _font: Font = ThemeDB.fallback_font


func _get_minimum_size() -> Vector2:
	return PANEL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var acc := UITheme.ACCENT
	var warm := UITheme.ACCENT_WARM
	var done := Color(0.5, 1.0, 0.6)
	var dim := UITheme.TEXT_DIM
	# NO PANEL, NO BRACKETS. Instead of a box, the log is grounded by a soft wash that is
	# darkest along a lit spine on the left and dissolves to nothing at the right and
	# bottom edges — so it sits ON the starfield rather than being cut out of it.
	_wash()

	var x := 14.0
	var y := 20.0
	var overall := (GameState.quest_stage + GameState.rescued_count()) \
		/ float(GameState.QUEST_PARTS.size() + GameState.RESCUES.size())
	# the campaign total is a RING, not a number buried in the header — it is the one
	# figure worth seeing at a glance, and an arc reads as progress without being read
	_ring(Vector2(PANEL.x - 22.0, y - 3.0), 9.5, overall, acc)
	draw_string(_font, Vector2(x, y), "OBJECTIVES", HORIZONTAL_ALIGNMENT_LEFT,
		PANEL.x - 46, 11, Color(acc.r, acc.g, acc.b, 0.92))
	y += 7.0
	# a rule that fades out toward the right instead of stopping dead
	for i in 24:
		var t: float = float(i) / 24.0
		var x0: float = x + t * (PANEL.x - 46.0 - x)
		var x1: float = x + (t + 1.0 / 24.0) * (PANEL.x - 46.0 - x)
		draw_line(Vector2(x0, y), Vector2(x1, y),
			Color(acc.r, acc.g, acc.b, 0.34 * (1.0 - t)), 1.0)
	y += 17.0

	# ============ objective 1: the jump drive ============
	var total_parts: int = GameState.QUEST_PARTS.size()
	if GameState.quest_stage >= total_parts:
		draw_string(_font, Vector2(x, y), "✔ JUMP DRIVE COMPLETE",
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 11, done)
		y += 20.0
	else:
		var part: Dictionary = GameState.quest_part()
		draw_string(_font, Vector2(x, y), "▸ REBUILD THE JUMP DRIVE",
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 10, UITheme.TEXT)
		draw_string(_font, Vector2(0, y), "PART %d/%d" % [GameState.quest_stage + 1, total_parts],
			HORIZONTAL_ALIGNMENT_RIGHT, PANEL.x - 14, 9, dim)
		y += 14.0
		draw_string(_font, Vector2(x + 8, y), str(part.get("name", "")),
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 11, warm)
		y += 14.0
		# One line of flavour, not two. It is read once and then it is scenery, so it should
		# not cost 24px of a panel whose job is live numbers. Shrunk to fit rather than
		# wrapped — draw_string's width argument HARD-CLIPS, so a fixed size would amputate
		# the longest part descriptions instead of wrapping them.
		var flav := str(part.get("flavor", ""))
		if flav != "":
			var fw := PANEL.x - 26.0
			var fsz := 9
			while fsz > 6 and _font.get_string_size(flav, HORIZONTAL_ALIGNMENT_LEFT, -1,
					fsz).x > fw:
				fsz -= 1
			draw_string(_font, Vector2(x + 8, y + 7), flav,
				HORIZONTAL_ALIGNMENT_LEFT, fw, fsz, Color(dim.r, dim.g, dim.b, 0.62))
			y += 14.0
		# per-material bars: element rows, then the ore row
		var got := 0
		var need_tot := 0
		for sym in part["req"]:
			var need := int(part["req"][sym])
			var have := mini(int(GameState.elements.get(sym, 0)), need)
			got += have
			need_tot += need
			y = _mat_row(x, y, Elements.cpk_color(sym), sym, have, need)
		var oh := mini(GameState.banked, int(part["ore"]))
		got += oh
		need_tot += int(part["ore"])
		y = _mat_row(x, y, Color(1.0, 0.72, 0.25), "ORE", oh, int(part["ore"]))
		# part completion bar
		var frac := float(got) / float(maxi(need_tot, 1))
		_bar(Rect2(x, y, PANEL.x - 30, 5), frac,
			done if GameState.quest_can_install() else acc)
		y += 14.0

	# ============ objective 2: the scattered survivors ============
	y += 2.0
	for i in 20:
		var t: float = float(i) / 20.0
		draw_line(Vector2(x + t * (PANEL.x - 26.0 - x), y),
			Vector2(x + (t + 0.05) * (PANEL.x - 26.0 - x), y),
			Color(acc.r, acc.g, acc.b, 0.20 * (1.0 - t)), 1.0)
	y += 15.0
	var rc := GameState.rescued_count()
	var tot: int = GameState.RESCUES.size()
	draw_string(_font, Vector2(x, y), "▸ FIND THE SCATTERED",
		HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 10, UITheme.TEXT if rc < tot else done)
	draw_string(_font, Vector2(0, y), "%d/%d" % [rc, tot],
		HORIZONTAL_ALIGNMENT_RIGHT, PANEL.x - 14, 10, done if rc >= tot else dim)
	y += 8.0
	# survivor pips
	for i in tot:
		var px := x + 4.0 + i * 15.0
		# a recovered survivor glows; an empty slot is a hollow ring, so the row reads as
		# "four still out there" instead of five near-identical dots
		if i < rc:
			draw_circle(Vector2(px, y), 7.5, Color(done.r, done.g, done.b, 0.13))
			draw_circle(Vector2(px, y), 4.0, done)
			draw_arc(Vector2(px, y), 6.2, 0, TAU, 16, Color(done.r, done.g, done.b, 0.45), 1.0)
		else:
			draw_arc(Vector2(px, y), 4.0, 0, TAU, 16, Color(1, 1, 1, 0.16), 1.0)
	y += 16.0
	if rc >= tot:
		draw_string(_font, Vector2(x + 8, y), "all aboard — set course for Haven",
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 9, dim)
	elif GameState.rescue_available():
		var t: Dictionary = GameState.rescue_target()
		draw_string(_font, Vector2(x + 8, y), "✦ %s · %s" % [t.get("name", ""), t.get("role", "")],
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 10, Color(1.0, 0.85, 0.3))
		y += 12.0
		draw_string(_font, Vector2(x + 8, y), "beacon: %s" % t.get("region", ""),
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 9, dim)
	else:
		draw_string(_font, Vector2(x + 8, y), "next signal needs drive part %d" % (rc + 1),
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 9, dim)


func _wash() -> void:
	## The backing, without a frame. A short horizontal ramp per row: near-opaque hull at
	## the left spine, gone by the right edge. Drawn as rows so it can also fade vertically
	## at the bottom, which is what keeps it from reading as a rectangle.
	var rows := 26
	var h := PANEL.y / float(rows)
	for i in rows:
		var vy: float = float(i) / float(rows)
		var vfade: float = 1.0 - smoothstep(0.72, 1.0, vy)      # dissolve near the bottom
		for k in 14:
			var t: float = float(k) / 14.0
			var a: float = 0.62 * vfade * pow(1.0 - t, 1.7)
			draw_rect(Rect2(t * PANEL.x, float(i) * h, PANEL.x / 14.0 + 1.0, h + 1.0),
				Color(0.031, 0.041, 0.058, a))
	# lit spine: the one hard edge, and the thing the eye aligns every row to
	var acc := UITheme.ACCENT
	for i in rows:
		var vy: float = float(i) / float(rows)
		var a: float = (1.0 - smoothstep(0.55, 1.0, vy)) * 0.55
		draw_rect(Rect2(0.0, float(i) * h, 1.5, h + 1.0), Color(acc.r, acc.g, acc.b, a))


func _ring(c: Vector2, r: float, frac: float, col: Color) -> void:
	## Campaign completion as an arc, read like a clock face from 12 o'clock.
	## At 0% the first version was a faint track around a faint "0" and vanished into the
	## starfield — the one number worth seeing was the one you could not see. So the empty
	## track carries real contrast on its own, a tick marks the start, and the figure sits
	## on a dark disc so it reads at any value.
	var f := clampf(frac, 0.0, 1.0)
	draw_circle(c, r + 1.2, Color(0.012, 0.02, 0.03, 0.72))
	draw_arc(c, r, 0.0, TAU, 44, Color(col.r, col.g, col.b, 0.22), 2.6)
	var a0 := -PI * 0.5
	# start tick at 12 o'clock, so an empty ring still looks like an instrument
	draw_line(c + Vector2(0, -r - 3.0), c + Vector2(0, -r + 2.0),
		Color(col.r, col.g, col.b, 0.55), 1.0)
	if f > 0.001:
		draw_arc(c, r, a0, a0 + f * TAU, 44, Color(col.r, col.g, col.b, 0.95), 2.8)
	draw_string(_font, Vector2(c.x - r, c.y + 3.5), "%d%%" % int(f * 100.0),
		HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 9,
		Color(col.r, col.g, col.b, 0.95) if f > 0.001 else Color(0.72, 0.80, 0.88, 0.8))


func _mat_row(x: float, y: float, col: Color, label: String, have: int, need: int) -> float:
	## One material line: colour dot · symbol · mini progress bar · have/need.
	var ok := have >= need
	# the dot gets a soft halo in its own element colour — cheap, and it makes the row
	# scannable by colour before you read a single glyph
	draw_circle(Vector2(x + 4, y + 4), 6.0, Color(col.r, col.g, col.b, 0.13))
	draw_circle(Vector2(x + 4, y + 4), 3.4, col)
	draw_string(_font, Vector2(x + 14, y + 8), label,
		HORIZONTAL_ALIGNMENT_LEFT, 40, 10, UITheme.TEXT if ok else UITheme.TEXT_DIM)
	_bar(Rect2(x + 52, y + 2, PANEL.x - 118, 7), float(have) / float(maxi(need, 1)), col)
	draw_string(_font, Vector2(0, y + 8), "%d/%d" % [have, need],
		HORIZONTAL_ALIGNMENT_RIGHT, PANEL.x - 14, 9,
		Color(0.5, 1.0, 0.6) if ok else UITheme.TEXT_DIM)
	return y + 16.0


func _bar(r: Rect2, frac: float, col: Color) -> void:
	## Sunken track, graded fill, lit leading edge. The old version was two flat rects and
	## read as a loading bar; the depth is what makes it look built rather than drawn.
	draw_rect(r, Color(0.0, 0.01, 0.02, 0.55))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), Color(0, 0, 0, 0.35))
	var f := clampf(frac, 0.0, 1.0)
	if f <= 0.001:
		return
	var w: float = r.size.x * f
	# vertical grade inside the fill: brighter along the top, so it has a light source
	var bands := 4
	for i in bands:
		var t: float = float(i) / float(bands)
		var a: float = 0.95 - 0.42 * t
		draw_rect(Rect2(r.position.x, r.position.y + t * r.size.y,
			w, r.size.y / float(bands) + 0.5), Color(col.r, col.g, col.b, a))
	# the head of the bar catches the light
	if w > 2.0:
		draw_rect(Rect2(r.position.x + w - 2.0, r.position.y, 2.0, r.size.y),
			Color(1, 1, 1, 0.5))
	draw_rect(r, Color(col.r, col.g, col.b, 0.25), false, 1.0)