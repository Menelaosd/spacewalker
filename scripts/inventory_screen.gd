extends Control
## Full-screen inventory (I / Tab, Esc closes) — one big framed screen:
## EXOSUIT column (character, gear, discovery gauge) and a scrollable
## grid of LARGE element cards — symbol, full name, count, capacity bar,
## category strip, on-suit badge. Mouse wheel scrolls, hover for details.

const SUIT_TEX := preload("res://assets/sprites/astronaut.png")

const PANEL_W := 1180.0
const PANEL_H := 664.0
const LEFT_W := 280.0
const COLS := 6
const CARD_W := 134.0
const CARD_H := 54.0
const CARD_GAP := 5.0
const VISIBLE_ROWS := 8

var _font: Font = ThemeDB.fallback_font
var _sorted: Array = []
var _grid_origin := Vector2.ZERO
var _scroll := 0
var _hover := -1


func _ready() -> void:
	visible = OS.get_environment("SW_SHOW_INV") != ""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	resized.connect(queue_redraw)
	GameState.inventory_changed.connect(queue_redraw)
	GameState.cargo_changed.connect(func(_c, _b): queue_redraw())
	GameState.gear_changed.connect(queue_redraw)
	_sorted = Elements.TABLE.duplicate()
	_sorted.sort_custom(func(a, b): return a[2] < b[2])   # atomic number order


func _max_scroll() -> int:
	return maxi(int(ceilf(float(_sorted.size()) / COLS)) - VISIBLE_ROWS, 0)


func _process(_delta: float) -> void:
	if not visible:
		return
	var rel := get_global_mouse_position() - _grid_origin
	var idx := -1
	if rel.x >= 0.0 and rel.y >= 0.0:
		var col := int(rel.x / (CARD_W + CARD_GAP))
		var row := int(rel.y / (CARD_H + CARD_GAP)) + _scroll
		if col < COLS and row - _scroll < VISIBLE_ROWS \
				and fmod(rel.x, CARD_W + CARD_GAP) <= CARD_W \
				and fmod(rel.y, CARD_H + CARD_GAP) <= CARD_H:
			var i := row * COLS + col
			if i < _sorted.size():
				idx = i
	if idx != _hover:
		_hover = idx
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_I, KEY_TAB]:
			visible = not visible
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and visible:
			visible = false
			get_viewport().set_input_as_handled()
	elif visible and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = mini(_scroll + 1, _max_scroll())
			get_viewport().set_input_as_handled()
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = maxi(_scroll - 1, 0)
			get_viewport().set_input_as_handled()
			queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.02, 0.05, 0.75), true)
	var panel := Rect2((vp.x - PANEL_W) * 0.5, (vp.y - PANEL_H) * 0.5, PANEL_W, PANEL_H)
	UITheme.draw_sci_panel(self, panel)
	UITheme.draw_headline(self, Rect2(panel.position.x + PANEL_W * 0.5 - 130,
		panel.position.y - 14, 260, 30), "INVENTORY", _font, 15)
	_draw_suit_column(Rect2(panel.position + Vector2(20, 28), Vector2(LEFT_W, PANEL_H - 48)))
	_draw_elements_area(Rect2(panel.position + Vector2(LEFT_W + 40, 28),
		Vector2(PANEL_W - LEFT_W - 60, PANEL_H - 48)))


# ------------------------------------------------------------------
# EXOSUIT column
# ------------------------------------------------------------------
func _draw_suit_column(rect: Rect2) -> void:
	UITheme.draw_header(self, rect.position + Vector2(0, 18), "EXOSUIT", _font,
		17, UITheme.ACCENT, rect.size.x)
	var cx := rect.position.x + rect.size.x * 0.5
	draw_texture_rect(SUIT_TEX, Rect2(cx - 52, rect.position.y + 44, 104, 104), false)

	var rows := [
		["SUIT", "Mk I pressure suit", "—", _icon_suit],
		["LIFELINE", "%dm rated reach" % int(GameState.tether_length),
			"LV %d" % (GameState.tether_level + 1), _icon_tether],
		["O2 TANK", "%d capacity" % int(GameState.max_oxygen),
			"LV %d" % (GameState.o2_level + 1), _icon_tank],
		["LASER", "%d output" % int(GameState.laser_dps),
			"LV %d" % (GameState.laser_level + 1), _icon_pistol],
	]
	var y := rect.position.y + 168.0
	for row in rows:
		var slot_rect := Rect2(rect.position.x, y, rect.size.x, 54)
		UITheme.draw_sub_panel(self, slot_rect)
		(row[3] as Callable).call(slot_rect.position + Vector2(26, 27))
		draw_string(_font, slot_rect.position + Vector2(52, 23), row[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT)
		draw_string(_font, slot_rect.position + Vector2(52, 40), row[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)
		draw_string(_font, slot_rect.position + Vector2(0, 33), row[2],
			HORIZONTAL_ALIGNMENT_RIGHT, slot_rect.size.x - 12, 12, UITheme.ACCENT_WARM)
		y += 60.0

	# discovery gauge
	var owned := GameState.discovered.size()
	UITheme.draw_ring_gauge(self, Vector2(cx - 54, y + 54), 30.0,
		float(owned) / float(_sorted.size()), UITheme.ACCENT, _font)
	draw_string(_font, Vector2(cx - 14, y + 46), "%d / %d" % [owned, _sorted.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.TEXT)
	draw_string(_font, Vector2(cx - 14, y + 62), "ELEMENTS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)
	draw_string(_font, Vector2(cx - 14, y + 74), "DISCOVERED",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)


# ------------------------------------------------------------------
# ELEMENTS — large cards, scrollable
# ------------------------------------------------------------------
func _draw_elements_area(rect: Rect2) -> void:
	var held_note := ""
	if GameState.carried > 0:
		held_note = "   ·   +n ON SUIT — DOCK TO REFINE"
	UITheme.draw_header(self, rect.position + Vector2(0, 18), "ELEMENTS", _font,
		17, UITheme.ACCENT, rect.size.x)
	draw_string(_font, rect.position + Vector2(0, 42),
		"REAL SOLAR ABUNDANCE · CHUNKS HELD %d%s" % [GameState.carried, held_note],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)

	_grid_origin = rect.position + Vector2(0, 54)
	var first := _scroll * COLS
	for i in range(first, mini(first + VISIBLE_ROWS * COLS, _sorted.size())):
		var e: Array = _sorted[i]
		var col := i % COLS
		var row := int(float(i) / COLS) - _scroll
		var p := _grid_origin + Vector2(col * (CARD_W + CARD_GAP), row * (CARD_H + CARD_GAP))
		_draw_card(e, Rect2(p, Vector2(CARD_W, CARD_H)), i == _hover)

	# scrollbar
	var track := Rect2(rect.end.x - 5.0, _grid_origin.y,
		4.0, VISIBLE_ROWS * (CARD_H + CARD_GAP) - CARD_GAP)
	draw_rect(track, Color(1, 1, 1, 0.06))
	var total_rows := ceilf(float(_sorted.size()) / COLS)
	var thumb_h := track.size.y * VISIBLE_ROWS / total_rows
	var thumb_y := track.position.y + (track.size.y - thumb_h) * \
		(float(_scroll) / maxf(float(_max_scroll()), 1.0))
	draw_rect(Rect2(track.position.x, thumb_y, 4.0, thumb_h),
		Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.5))

	# detail footer
	var fy := rect.end.y - 30.0
	if _hover >= 0:
		var he: Array = _sorted[_hover]
		var hcol: Color = Elements.hue_of(he[0])
		draw_circle(Vector2(rect.position.x + 8, fy + 6), 5.0, hcol)
		var status := "DISCOVERED" if GameState.discovered.has(he[0]) else "NOT YET FOUND"
		draw_string(_font, Vector2(rect.position.x + 20, fy + 11),
			"%s — %s   ·   Z %d   ·   %s   ·   stored %d / %d   ·   abundance %s%%   ·   %s" % [
				he[0], he[1], he[2], Elements.category(he[0]).to_upper(),
				int(GameState.elements.get(he[0], 0)), GameState.ELEMENT_CAP,
				String.num_scientific(he[3]), status],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.TEXT)
	else:
		draw_string(_font, Vector2(rect.position.x + 8, fy + 11),
			"hover a card for details · mouse wheel to scroll · Esc to close",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.3))


func _draw_card(e: Array, r: Rect2, hovered: bool) -> void:
	var sym: String = e[0]
	var amount: int = int(GameState.elements.get(sym, 0))
	var have: bool = GameState.discovered.has(sym)
	var ecol: Color = Elements.hue_of(sym)

	var bg := Color(0.0, 0.0, 0.0, 0.35)
	var border := Color(1, 1, 1, 0.08)
	if have:
		bg = Color(ecol.r, ecol.g, ecol.b, 0.10)
		border = Color(ecol.r, ecol.g, ecol.b, 0.5)
	if hovered:
		bg = Color(ecol.r, ecol.g, ecol.b, 0.20)
		border = Color(1, 1, 1, 0.9)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.draw(get_canvas_item(), r)

	# category strip down the left edge
	draw_rect(Rect2(r.position + Vector2(1, 6), Vector2(3, r.size.y - 12)),
		Color(Elements.color_of(sym).r, Elements.color_of(sym).g,
			Elements.color_of(sym).b, 0.9 if have else 0.25))

	# symbol, count, name
	var sym_col := ecol if have else Color(1, 1, 1, 0.25)
	draw_string(_font, r.position + Vector2(12, 24), sym,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, sym_col)
	draw_string(_font, r.position + Vector2(0, 22),
		("×%d" % amount) if amount > 0 else "—",
		HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10, 13,
		UITheme.TEXT if amount > 0 else Color(1, 1, 1, 0.18))
	draw_string(_font, r.position + Vector2(12, 42), str(e[1]),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 9,
		UITheme.TEXT_DIM if have else Color(1, 1, 1, 0.15))

	# capacity bar
	if amount > 0:
		var frac := float(amount) / float(GameState.ELEMENT_CAP)
		draw_rect(Rect2(r.position + Vector2(12, r.size.y - 6), Vector2(r.size.x - 24, 2)),
			Color(1, 1, 1, 0.07))
		draw_rect(Rect2(r.position + Vector2(12, r.size.y - 6),
			Vector2((r.size.x - 24) * clampf(frac, 0.01, 1.0), 2)),
			Color(ecol.r, ecol.g, ecol.b, 0.85))

	# on-suit badge
	var held: int = GameState.carried_veins.get(sym, 0)
	if held > 0:
		draw_string(_font, r.position + Vector2(0, 38), "+%d" % held,
			HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10, 10, UITheme.ACCENT_WARM)
		draw_rect(r, Color(UITheme.ACCENT_WARM.r, UITheme.ACCENT_WARM.g,
			UITheme.ACCENT_WARM.b, 0.5), false, 1.0)


# ------------------------------------------------------------------
# Gear icons
# ------------------------------------------------------------------
func _icon_suit(c: Vector2) -> void:
	draw_circle(c + Vector2(-7, 0), 6.0, Color(0.45, 0.48, 0.55))
	draw_circle(c, 10.0, Color(0.92, 0.94, 0.97))
	draw_circle(c + Vector2(3, -1), 5.5, Color(0.1, 0.2, 0.35))
	draw_circle(c + Vector2(1, -3), 1.6, Color(0.7, 0.9, 1.0, 0.85))


func _icon_tether(c: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 23:
		var t := float(i) / 22.0
		pts.append(c + Vector2(lerpf(-11.0, 11.0, t), sin(t * TAU * 1.5) * 6.0))
	draw_polyline(pts, Color(1.0, 0.85, 0.3, 0.95), 2.0)


func _icon_tank(c: Vector2) -> void:
	draw_rect(Rect2(c.x - 6, c.y - 9, 12, 18), Color(0.35, 0.8, 1.0), true)
	draw_rect(Rect2(c.x - 2, c.y - 12, 4, 3), Color(0.55, 0.58, 0.66))
	draw_rect(Rect2(c.x - 5, c.y + 2, 10, 3), Color(1, 1, 1, 0.35))


func _icon_pistol(c: Vector2) -> void:
	draw_rect(Rect2(c.x - 10, c.y - 4, 16, 6), Color(0.6, 0.65, 0.7))
	draw_rect(Rect2(c.x - 6, c.y + 2, 5, 7), Color(0.45, 0.48, 0.55))
	draw_circle(c + Vector2(8, -1), 2.2, Color(1.0, 0.4, 0.3, 0.95))