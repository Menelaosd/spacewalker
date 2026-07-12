extends Control
## Beautiful upgrade modal — opens at a gear station. Shows the NEXT level's
## requirements as element icons with have/need tallies, the ore cost, and the
## stat it buys. Confirm with E / click; Esc closes. Reads GameState live.

signal closed()
signal upgraded(kind: String)

const PANEL_W := 470.0
const ROW_H := 40.0

var _font: Font = ThemeDB.fallback_font
var kind := ""
var _flash := 0.0
var _panel := Rect2()
var _btn := Rect2()

const GEAR_ICON := {
	"o2": preload("res://assets/icons/tank.svg"),
	"tether": preload("res://assets/icons/line.svg"),
	"laser": preload("res://assets/icons/laser.svg"),
	"suit": preload("res://assets/icons/helmet.svg"),
}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	visible = false
	GameState.gear_changed.connect(func(): if visible: queue_redraw())
	GameState.inventory_changed.connect(func(): if visible: queue_redraw())


func open(k: String) -> void:
	kind = k
	visible = true
	_flash = 0.0
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 2.0, 0.0)
		queue_redraw()


func _confirm() -> void:
	if GameState.can_upgrade(kind):
		if GameState.try_upgrade(kind):
			_flash = 1.0
			upgraded.emit(kind)
			queue_redraw()
	else:
		Sfx.play("deny", -12.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			close()
		elif event.physical_keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_confirm()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _btn.has_point(event.position):
			_confirm()
		elif not _panel.has_point(event.position):
			close()      # click the dim backdrop to dismiss
		accept_event()


func _stat_line() -> String:
	var step: float = GameState.UPGRADES[kind]["step"]
	match kind:
		"o2": return "O2 capacity   %d → %d" % [int(GameState.max_oxygen),
			int(GameState.max_oxygen + step)]
		"tether": return "Lifeline reach   %dm → %dm" % [int(GameState.tether_length),
			int(GameState.tether_length + step)]
		"laser": return "Laser power   %d → %d" % [int(GameState.laser_dps),
			int(GameState.laser_dps + step)]
		"suit": return "Ore bag   %d → %d" % [GameState.ore_max(),
			GameState.ore_max() + int(step)]
	return ""


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0.02, 0.05, 0.72))

	var maxed := GameState.gear_maxed(kind)
	var req: Dictionary = GameState.upgrade_req(kind)
	var rows: int = (req.get("req", {}) as Dictionary).size() + 1   # + ore row
	# header/stat block (118) + material rows + footer (52)
	var body_h := 196.0 if maxed else 118.0 + rows * (ROW_H + 4.0) + 52.0
	_panel = Rect2((vp.x - PANEL_W) * 0.5, (vp.y - body_h) * 0.5, PANEL_W, body_h)
	UITheme.draw_sci_panel(self, _panel, UITheme.ACCENT)
	if _flash > 0.0:
		draw_rect(_panel.grow(-3.0), Color(UITheme.ACCENT_WARM.r,
			UITheme.ACCENT_WARM.g, UITheme.ACCENT_WARM.b, 0.6 * _flash), false, 2.0)

	var lvl := GameState._level_of(kind)
	var px := _panel.position.x + 26.0
	var y := _panel.position.y + 34.0

	# header: gear icon + name + level pips
	UITheme.draw_icon(self, GEAR_ICON[kind], Vector2(px + 14, y + 6), 30.0)
	draw_string(_font, Vector2(px + 42, y), "UPGRADE — %s" % \
		str(GameState.UPGRADES[kind]["label"]).to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 90, 18, UITheme.ACCENT)
	# 5 level pips
	for p in GameState.MAX_GEAR_LEVEL:
		var pip := Rect2(_panel.end.x - 26 - (GameState.MAX_GEAR_LEVEL - p) * 15.0, y - 6, 11, 6)
		var on := p < lvl
		var nextp := p == lvl and not maxed
		draw_rect(pip, UITheme.ACCENT if on else (
			Color(UITheme.ACCENT_WARM.r, UITheme.ACCENT_WARM.g, UITheme.ACCENT_WARM.b, 0.6)
			if nextp else Color(1, 1, 1, 0.12)))
	y += 22.0
	draw_string(_font, Vector2(px + 42, y),
		"LEVEL %d  ›  %d" % [lvl, mini(lvl + 1, GameState.MAX_GEAR_LEVEL)],
		HORIZONTAL_ALIGNMENT_LEFT, 300, 11, UITheme.TEXT_DIM)
	y += 22.0
	draw_line(Vector2(px, y), Vector2(_panel.end.x - 26, y),
		Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.25), 1.0)
	y += 18.0

	if maxed:
		draw_string(_font, Vector2(px, y + 14), "◆  FULLY UPGRADED",
			HORIZONTAL_ALIGNMENT_CENTER, PANEL_W - 52, 16, Color(0.5, 1.0, 0.6))
		draw_string(_font, Vector2(px, y + 44),
			"This gear is at its maximum. Nothing more to install.",
			HORIZONTAL_ALIGNMENT_CENTER, PANEL_W - 52, 11, UITheme.TEXT_DIM)
		_btn = Rect2()
		_draw_footer(maxed, false)
		return

	draw_string(_font, Vector2(px, y), _stat_line(),
		HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 52, 13, Color(0.7, 0.95, 1.0))
	y += 16.0
	draw_string(_font, Vector2(px, y), "REQUIRES",
		HORIZONTAL_ALIGNMENT_LEFT, 200, 10, UITheme.TEXT_DIM)
	y += 12.0

	# element requirement rows — icon + name + have/need
	var all_ok := GameState.banked >= int(req["ore"])
	for sym in req["req"]:
		var need := int(req["req"][sym])
		var have := int(GameState.elements.get(sym, 0))
		var ok := have >= need
		all_ok = all_ok and ok
		_draw_req_row(Rect2(px, y, PANEL_W - 52, ROW_H), sym, have, need, ok)
		y += ROW_H + 4.0
	# ore row
	var ore_need := int(req["ore"])
	var ore_ok := GameState.banked >= ore_need
	_draw_ore_row(Rect2(px, y, PANEL_W - 52, ROW_H), GameState.banked, ore_need, ore_ok)
	y += ROW_H + 4.0

	_draw_footer(false, all_ok)


func _draw_req_row(r: Rect2, sym: String, have: int, need: int, ok: bool) -> void:
	var tint := Color(0.5, 1.0, 0.6) if ok else Color(1.0, 0.5, 0.45)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r, tint.g, tint.b, 0.08)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.draw(get_canvas_item(), r)
	# icon
	var icon := Elements.icon_for(sym)
	if icon != null:
		var box := 34.0
		var isz := icon.get_size()
		var s := box / maxf(isz.x, isz.y)
		var dsz := isz * s
		draw_texture_rect(icon, Rect2(r.position + Vector2(6 + (box - dsz.x) * 0.5,
			(r.size.y - dsz.y) * 0.5), dsz), false)
	draw_string(_font, r.position + Vector2(48, 20), sym,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.TEXT)
	draw_string(_font, r.position + Vector2(48, 36), Elements.name_of(sym),
		HORIZONTAL_ALIGNMENT_LEFT, 200, 10, UITheme.TEXT_DIM)
	draw_string(_font, r.position + Vector2(0, 27),
		"%d / %d" % [have, need], HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 34, 15, tint)
	draw_string(_font, r.position + Vector2(0, 27), "✔" if ok else "✘",
		HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8, 14, tint)


func _draw_ore_row(r: Rect2, have: int, need: int, ok: bool) -> void:
	var tint := Color(0.5, 1.0, 0.6) if ok else Color(1.0, 0.5, 0.45)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r, tint.g, tint.b, 0.08)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.draw(get_canvas_item(), r)
	var oc := Color(1.0, 0.72, 0.25)
	draw_circle(r.position + Vector2(23, r.size.y * 0.5), 8.0, Color(oc.r, oc.g, oc.b, 0.85))
	draw_circle(r.position + Vector2(20, r.size.y * 0.5 - 3), 3.0, Color(1, 1, 1, 0.5))
	draw_string(_font, r.position + Vector2(48, 20), "ORE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.TEXT)
	draw_string(_font, r.position + Vector2(48, 36), "banked currency",
		HORIZONTAL_ALIGNMENT_LEFT, 200, 10, UITheme.TEXT_DIM)
	draw_string(_font, r.position + Vector2(0, 27),
		"%d / %d" % [have, need], HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 34, 15, tint)
	draw_string(_font, r.position + Vector2(0, 27), "✔" if ok else "✘",
		HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8, 14, tint)


func _draw_footer(maxed: bool, ready: bool) -> void:
	var by := _panel.end.y - 44.0
	# confirm button
	if not maxed:
		_btn = Rect2(_panel.position.x + PANEL_W * 0.5 - 90, by, 180, 30)
		var col := Color(0.5, 1.0, 0.6) if ready else Color(0.5, 0.55, 0.6)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r, col.g, col.b, 0.18 if ready else 0.08)
		sb.border_color = Color(col.r, col.g, col.b, 0.9 if ready else 0.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.draw(get_canvas_item(), _btn)
		draw_string(_font, _btn.position + Vector2(0, 20),
			"E   INSTALL UPGRADE" if ready else "NEED MATERIALS",
			HORIZONTAL_ALIGNMENT_CENTER, _btn.size.x, 13, col)
	draw_string(_font, Vector2(_panel.position.x, _panel.end.y - 12),
		"Esc — close", HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 10, UITheme.TEXT_DIM)
