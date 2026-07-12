extends Control
## Quest log — a compact objectives panel that sits under the radar in the
## spacewalk and flight HUDs. Reads live from GameState: the jump-drive
## rebuild and the search for the scattered survivors, with progress.

const PANEL := Vector2(238.0, 138.0)

var _font: Font = ThemeDB.fallback_font


func _get_minimum_size() -> Vector2:
	return PANEL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var acc := UITheme.ACCENT
	var rect := Rect2(Vector2.ZERO, PANEL)
	UITheme.draw_sci_panel(self, rect)
	UITheme.draw_brackets(self, rect, acc, 8.0, 2.0)

	var x := 16.0
	var y := 21.0
	draw_string(_font, Vector2(x, y), "◈ OBJECTIVES",
		HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 12, Color(acc.r, acc.g, acc.b, 0.85))
	y += 7.0
	draw_line(Vector2(x, y), Vector2(PANEL.x - 12, y), Color(acc.r, acc.g, acc.b, 0.25), 1.0)
	y += 18.0

	# --- objective 1: the jump drive ---
	var done := Color(0.5, 1.0, 0.6)
	if GameState.quest_stage >= GameState.QUEST_PARTS.size():
		draw_string(_font, Vector2(x, y), "✔ Jump drive complete",
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 11, done)
		y += 20.0
	else:
		var part: Dictionary = GameState.quest_part()
		draw_string(_font, Vector2(x, y), "▸ Rebuild the jump drive",
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 11, UITheme.TEXT)
		y += 14.0
		draw_string(_font, Vector2(x + 12, y), str(part.get("name", "")),
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 30, 10, UITheme.ACCENT_WARM)
		y += 13.0
		draw_string(_font, Vector2(x + 12, y), GameState.quest_progress_text(),
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 9, UITheme.TEXT_DIM)
		y += 16.0

	# --- objective 2: the scattered survivors ---
	var rc := GameState.rescued_count()
	var total: int = GameState.RESCUES.size()
	if rc >= total:
		draw_string(_font, Vector2(x, y), "✔ All six aboard — set course",
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 11, done)
	else:
		draw_string(_font, Vector2(x, y), "▸ Find the scattered   %d/%d" % [rc, total],
			HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 24, 11, UITheme.TEXT)
		y += 14.0
		if GameState.rescue_available():
			var t: Dictionary = GameState.rescue_target()
			draw_string(_font, Vector2(x + 12, y),
				"✦ %s the %s" % [t.get("name", ""), t.get("role", "")],
				HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 30, 10, Color(1.0, 0.85, 0.3))
			y += 12.0
			draw_string(_font, Vector2(x + 12, y), str(t.get("region", "")),
				HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 30, 9, UITheme.TEXT_DIM)
		else:
			draw_string(_font, Vector2(x + 12, y),
				"signal needs drive part %d" % (rc + 1),
				HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 30, 9, UITheme.TEXT_DIM)
