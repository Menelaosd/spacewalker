extends Control
## Full-screen inventory overlay (I or Tab) — No Man's Sky flavoured.
## Left: EXOSUIT — the character with every gear piece and its stats.
## Right: ELEMENTS — all 83 real elements in a grid, live amounts.
## Everything is code-drawn; slots light up in their category colour
## once you own any amount of that element.

const SUIT_TEX := preload("res://assets/sprites/astronaut.png")

const PANEL_H := 560.0
const LEFT_W := 350.0
const RIGHT_W := 652.0
const GAP := 20.0
const COLS := 12
const SLOT := 47.0
const SLOT_GAP := 4.0

var _font: Font = ThemeDB.fallback_font
var _sorted: Array = []


func _ready() -> void:
	visible = OS.get_environment("SW_SHOW_INV") != ""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100   # above prompts/messages from the scene HUD
	# size arrives after the first layout pass — redraw when it does
	resized.connect(queue_redraw)
	GameState.inventory_changed.connect(queue_redraw)
	GameState.cargo_changed.connect(func(_c, _b): queue_redraw())
	GameState.gear_changed.connect(queue_redraw)
	_sorted = Elements.TABLE.duplicate()
	_sorted.sort_custom(func(a, b): return a[2] < b[2])   # atomic number order


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo \
			and event.physical_keycode in [KEY_I, KEY_TAB]:
		visible = not visible


func _draw() -> void:
	# anchor everything to the viewport — independent of layout timing
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.02, 0.05, 0.72), true)
	var total_w := LEFT_W + GAP + RIGHT_W
	var x0 := (vp.x - total_w) * 0.5
	var y0 := (vp.y - PANEL_H) * 0.5
	_draw_suit_panel(Rect2(x0, y0, LEFT_W, PANEL_H))
	_draw_elements_panel(Rect2(x0 + LEFT_W + GAP, y0, RIGHT_W, PANEL_H))


func _header(rect: Rect2, text: String, sub: String) -> void:
	draw_string(_font, rect.position + Vector2(18, 32), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UITheme.TEXT)
	draw_string(_font, rect.position + Vector2(18, 50), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.TEXT_DIM)
	draw_line(rect.position + Vector2(16, 60), Vector2(rect.end.x - 16, rect.position.y + 60),
		Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.3), 1.0)


# ------------------------------------------------------------------
# EXOSUIT — character + gear
# ------------------------------------------------------------------
func _draw_suit_panel(rect: Rect2) -> void:
	UITheme.panel().draw(get_canvas_item(), rect)
	_header(rect, "EXOSUIT", "SPACEWALKER · CREW OF 1")

	# the character, big and pixel-crisp
	var cx := rect.position.x + rect.size.x * 0.5
	var cy := rect.position.y + 150.0
	draw_texture_rect(SUIT_TEX, Rect2(cx - 64, cy - 64, 128, 128), false)

	# gear list
	var rows := [
		["SUIT", "Mk I pressure suit", "—", _icon_suit],
		["LIFELINE", "%dm rated reach" % int(GameState.tether_length),
			"LV %d" % (GameState.tether_level + 1), _icon_tether],
		["O2 TANK", "%d capacity" % int(GameState.max_oxygen),
			"LV %d" % (GameState.o2_level + 1), _icon_tank],
		["LASER", "%d output" % int(GameState.laser_dps),
			"LV %d" % (GameState.laser_level + 1), _icon_pistol],
	]
	var y := rect.position.y + 250.0
	for row in rows:
		var slot_rect := Rect2(rect.position.x + 18, y, rect.size.x - 36, 62)
		UITheme.panel(Color(1, 1, 1, 0.12), UITheme.BG_LIGHT, 8).draw(
			get_canvas_item(), slot_rect)
		(row[3] as Callable).call(slot_rect.position + Vector2(30, 31))
		draw_string(_font, slot_rect.position + Vector2(62, 26), row[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT)
		draw_string(_font, slot_rect.position + Vector2(62, 46), row[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.TEXT_DIM)
		draw_string(_font, slot_rect.position + Vector2(0, 38), row[2],
			HORIZONTAL_ALIGNMENT_RIGHT, slot_rect.size.x - 16, 13, UITheme.ACCENT_WARM)
		y += 70.0


# ------------------------------------------------------------------
# ELEMENTS — the whole periodic table, real amounts
# ------------------------------------------------------------------
func _draw_elements_panel(rect: Rect2) -> void:
	UITheme.panel().draw(get_canvas_item(), rect)
	var owned := 0
	for e in _sorted:
		if GameState.elements.get(e[0], 0.0) > 0.0:
			owned += 1
	_header(rect, "ELEMENTS",
		"%d / %d COLLECTED · REAL SOLAR ABUNDANCE · CHUNKS HELD %d" % [
			owned, _sorted.size(), GameState.carried])

	var gx := rect.position.x + 18.0
	var gy := rect.position.y + 74.0
	for i in _sorted.size():
		var e: Array = _sorted[i]
		var col := i % COLS
		var row := i / COLS
		var p := Vector2(gx + col * (SLOT + SLOT_GAP), gy + row * (SLOT + SLOT_GAP))
		var amount: float = GameState.elements.get(e[0], 0.0)
		var have := amount > 0.0
		var ecol: Color = Elements.color_of(e[0])
		# slot
		var bg := Color(0.0, 0.0, 0.0, 0.35)
		var border := Color(1, 1, 1, 0.08)
		if have:
			bg = Color(ecol.r, ecol.g, ecol.b, 0.13)
			border = Color(ecol.r, ecol.g, ecol.b, 0.65)
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(5)
		sb.draw(get_canvas_item(), Rect2(p, Vector2(SLOT, SLOT)))
		# symbol + amount
		var sym_col := ecol if have else Color(1, 1, 1, 0.22)
		draw_string(_font, p + Vector2(0, 24), e[0],
			HORIZONTAL_ALIGNMENT_CENTER, SLOT, 15, sym_col)
		draw_string(_font, p + Vector2(0, 40), Elements.fmt(amount),
			HORIZONTAL_ALIGNMENT_CENTER, SLOT, 9,
			UITheme.TEXT_DIM if have else Color(1, 1, 1, 0.12))

	# category legend along the bottom
	var ly := rect.end.y - 22.0
	var lx := rect.position.x + 18.0
	for cat in Elements.CATEGORY_COLORS:
		var c: Color = Elements.CATEGORY_COLORS[cat]
		draw_circle(Vector2(lx, ly), 4.0, c)
		draw_string(_font, Vector2(lx + 9, ly + 4), cat.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UITheme.TEXT_DIM)
		lx += 12.0 + cat.length() * 7.0 + 14.0


# ------------------------------------------------------------------
# Gear icons — same visual language as the gear rack
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
