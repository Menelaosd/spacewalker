extends Control
## Quest log — an analytical objectives panel under the radar. Live from
## GameState: the jump-drive rebuild (part X/5 with a progress bar and a
## per-material breakdown) and the search for the five scattered survivors
## (pips + next beacon). Sci-fi styled to match the HUD.

const PANEL := Vector2(252.0, 236.0)

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
	var rect := Rect2(Vector2.ZERO, PANEL)
	UITheme.draw_sci_panel(self, rect)
	UITheme.draw_brackets(self, rect, acc, 8.0, 2.0)

	var x := 15.0
	var y := 20.0
	draw_string(_font, Vector2(x, y), "◈ OBJECTIVES", HORIZONTAL_ALIGNMENT_LEFT,
		PANEL.x - 24, 12, Color(acc.r, acc.g, acc.b, 0.9))
	# overall campaign progress, right-aligned in the header
	var overall := (GameState.quest_stage + GameState.rescued_count()) \
		/ float(GameState.QUEST_PARTS.size() + GameState.RESCUES.size())
	draw_string(_font, Vector2(0, y), "%d%%" % int(overall * 100.0),
		HORIZONTAL_ALIGNMENT_RIGHT, PANEL.x - 14, 11, Color(acc.r, acc.g, acc.b, 0.7))
	y += 6.0
	draw_line(Vector2(x, y), Vector2(PANEL.x - 12, y), Color(acc.r, acc.g, acc.b, 0.25), 1.0)
	y += 16.0

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
		# a line of flavour — what this part is, why it matters
		var flav := str(part.get("flavor", ""))
		if flav != "":
			draw_multiline_string(_font, Vector2(x + 8, y), flav,
				HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 26, 9, 2,
				Color(dim.r, dim.g, dim.b, 0.75))
			y += 24.0
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
	draw_line(Vector2(x, y), Vector2(PANEL.x - 12, y), Color(acc.r, acc.g, acc.b, 0.12), 1.0)
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
		draw_circle(Vector2(px, y), 3.6, done if i < rc else Color(1, 1, 1, 0.14))
		if i < rc:
			draw_arc(Vector2(px, y), 5.0, 0, TAU, 12, Color(done.r, done.g, done.b, 0.35), 1.0)
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


func _mat_row(x: float, y: float, col: Color, label: String, have: int, need: int) -> float:
	## One material line: colour dot · symbol · mini progress bar · have/need.
	var ok := have >= need
	draw_circle(Vector2(x + 4, y + 4), 3.4, col)
	draw_string(_font, Vector2(x + 12, y + 8), label,
		HORIZONTAL_ALIGNMENT_LEFT, 40, 10, UITheme.TEXT if ok else UITheme.TEXT_DIM)
	_bar(Rect2(x + 52, y + 2, PANEL.x - 118, 7), float(have) / float(maxi(need, 1)), col)
	draw_string(_font, Vector2(0, y + 8), "%d/%d" % [have, need],
		HORIZONTAL_ALIGNMENT_RIGHT, PANEL.x - 14, 9,
		Color(0.5, 1.0, 0.6) if ok else UITheme.TEXT_DIM)
	return y + 15.0


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r, Color(1, 1, 1, 0.06))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)),
		Color(col.r, col.g, col.b, 0.85))
	draw_rect(r, Color(col.r, col.g, col.b, 0.25), false, 1.0)