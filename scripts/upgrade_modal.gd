extends Control
## Beautiful upgrade modal — opens at a gear station. Shows the NEXT level's
## requirements as element icons with have/need tallies, the ore cost, and the
## stat it buys. Confirm with E / click; Esc closes. Reads GameState live.

signal closed()
signal upgraded(kind: String)

const PANEL_W := 372.0
const ROW_H := 28.0

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
	# anchors AND offsets — anchors alone leave the control 0x0 (unclickable)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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


func _stat_line_note() -> String:
	## the part the headline stat does not say — checked against try_upgrade()
	match kind:
		"o2": return "installing also tops the tank up by %d" % \
			int(GameState.UPGRADES["o2"]["step"])
	return ""


func _grad(r: Rect2, top: Color, bot: Color) -> void:
	## vertical gradient wash — draw_polygon interpolates per-vertex colours
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
		r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bot, bot]))


func _grad_panel(rect: Rect2, top: Color, bot: Color) -> void:
	## the same wash, but following the sci-panel's notched silhouette so it
	## never paints over the slanted corner
	var pts := UITheme.panel_points(rect)
	var mid := rect.get_center().y
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top if p.y < mid else bot)
	draw_polygon(pts, cols)


func _hairline(rect: Rect2, col: Color) -> void:
	## inner hairline that follows the same silhouette
	var pts := UITheme.panel_points(rect)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, col, 1.0)


func _fit(text: String, w: float, size: int, floor_size := 8) -> int:
	## biggest size <= `size` that still fits `w` px — labels shrink, never clip
	var s := size
	while s > floor_size and _font.get_string_size(text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > w:
		s -= 1
	return s


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0.02, 0.05, 0.72))

	var maxed := GameState.gear_maxed(kind)
	var req: Dictionary = GameState.upgrade_req(kind)
	var rows: int = (req.get("req", {}) as Dictionary).size() + 1   # + ore row
	# header/stat block (124) + material rows + footer (50)
	var body_h := 150.0 if maxed else 124.0 + rows * (ROW_H + 4.0) + 50.0
	_panel = Rect2((vp.x - PANEL_W) * 0.5, (vp.y - body_h) * 0.5, PANEL_W, body_h)
	UITheme.draw_sci_panel(self, _panel, UITheme.ACCENT)
	# gradient backing + inner hairline
	_grad_panel(_panel.grow(-2.0), Color(0.07, 0.16, 0.22, 0.45),
		Color(0.01, 0.03, 0.06, 0.15))
	_hairline(_panel.grow(-5.0), Color(UITheme.ACCENT.r, UITheme.ACCENT.g,
		UITheme.ACCENT.b, 0.10))
	if _flash > 0.0:
		draw_rect(_panel.grow(-3.0), Color(UITheme.ACCENT_WARM.r,
			UITheme.ACCENT_WARM.g, UITheme.ACCENT_WARM.b, 0.6 * _flash), false, 2.0)

	var lvl := GameState._level_of(kind)
	var px := _panel.position.x + 24.0
	var y := _panel.position.y + 30.0

	# header: gear icon + name + level pips
	if GEAR_ICON.has(kind):
		UITheme.draw_icon(self, GEAR_ICON[kind], Vector2(px + 11, y + 2), 22.0)
	var title := "UPGRADE — %s" % str(GameState.UPGRADES[kind]["label"]).to_upper()
	draw_string(_font, Vector2(px + 32, y), title, HORIZONTAL_ALIGNMENT_LEFT,
		PANEL_W - 150, _fit(title, PANEL_W - 150, 13), UITheme.ACCENT)
	# 5 level pips
	for p in GameState.MAX_GEAR_LEVEL:
		var pip := Rect2(_panel.end.x - 24 - (GameState.MAX_GEAR_LEVEL - p) * 13.0, y - 6, 9, 5)
		var on := p < lvl
		var nextp := p == lvl and not maxed
		draw_rect(pip, UITheme.ACCENT if on else (
			Color(UITheme.ACCENT_WARM.r, UITheme.ACCENT_WARM.g, UITheme.ACCENT_WARM.b, 0.6)
			if nextp else Color(1, 1, 1, 0.12)))
	y += 20.0
	draw_string(_font, Vector2(px + 32, y),
		"LEVEL %d  ›  %d" % [lvl, mini(lvl + 1, GameState.MAX_GEAR_LEVEL)],
		HORIZONTAL_ALIGNMENT_LEFT, 300, 9, UITheme.TEXT_DIM)
	y += 18.0
	draw_line(Vector2(px, y), Vector2(_panel.end.x - 24, y),
		Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.25), 1.0)
	y += 15.0

	if maxed:
		draw_string(_font, Vector2(px, y + 12), "◆  FULLY UPGRADED",
			HORIZONTAL_ALIGNMENT_CENTER, PANEL_W - 48, 13, Color(0.5, 1.0, 0.6))
		draw_string(_font, Vector2(px, y + 34),
			"at maximum spec. nothing left to install.",
			HORIZONTAL_ALIGNMENT_CENTER, PANEL_W - 48, 9, UITheme.TEXT_DIM)
		_btn = Rect2()
		_draw_footer(maxed, false)
		return

	var sl := _stat_line()
	draw_string(_font, Vector2(px, y), sl, HORIZONTAL_ALIGNMENT_LEFT,
		PANEL_W - 48, _fit(sl, PANEL_W - 48, 11), Color(0.7, 0.95, 1.0))
	y += 12.0
	var note := _stat_line_note()
	if note != "":
		draw_string(_font, Vector2(px, y), note,
			HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 48, 8, UITheme.TEXT_DIM)
	y += 13.0
	draw_string(_font, Vector2(px, y), "COST TO INSTALL",
		HORIZONTAL_ALIGNMENT_LEFT, 200, 8, UITheme.TEXT_DIM)
	y += 11.0

	# element requirement rows — icon + name + have/need
	var all_ok := GameState.banked >= int(req["ore"])
	for sym in req["req"]:
		var need := int(req["req"][sym])
		var have := int(GameState.elements.get(sym, 0))
		var ok := have >= need
		all_ok = all_ok and ok
		_draw_req_row(Rect2(px, y, PANEL_W - 48, ROW_H), sym, have, need, ok)
		y += ROW_H + 4.0
	# ore row
	var ore_need := int(req["ore"])
	var ore_ok := GameState.banked >= ore_need
	_draw_ore_row(Rect2(px, y, PANEL_W - 48, ROW_H), GameState.banked, ore_need, ore_ok)
	y += ROW_H + 4.0

	_draw_footer(false, all_ok)


func _draw_req_row(r: Rect2, sym: String, have: int, need: int, ok: bool) -> void:
	_draw_cost_row(r, sym, Elements.name_of(sym), have, need, ok)
	var icon := Elements.icon_for(sym)
	if icon != null:
		var box := 22.0
		var isz := icon.get_size()
		var s := box / maxf(isz.x, isz.y)
		var dsz := isz * s
		draw_texture_rect(icon, Rect2(r.position + Vector2(8 + (box - dsz.x) * 0.5,
			(r.size.y - dsz.y) * 0.5), dsz), false)


func _draw_ore_row(r: Rect2, have: int, need: int, ok: bool) -> void:
	_draw_cost_row(r, "ORE", "banked currency", have, need, ok)
	var oc := Color(1.0, 0.72, 0.25)
	draw_circle(r.position + Vector2(19, r.size.y * 0.5), 6.0, Color(oc.r, oc.g, oc.b, 0.85))
	draw_circle(r.position + Vector2(16.5, r.size.y * 0.5 - 2.5), 2.0, Color(1, 1, 1, 0.5))


func _draw_cost_row(r: Rect2, label: String, sub: String, have: int, need: int,
		ok: bool) -> void:
	## One cost line, shared by the element rows and the ore row. The have/need
	## number is the loudest thing in the row; the fill bar, the tick and the
	## left spine mean affordability reads without relying on hue alone.
	var tint := Color(0.5, 1.0, 0.6) if ok else Color(1.0, 0.5, 0.45)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r, tint.g, tint.b, 0.06)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.40)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.draw(get_canvas_item(), r)
	_grad(r.grow(-2.0), Color(tint.r, tint.g, tint.b, 0.16),
		Color(tint.r, tint.g, tint.b, 0.01))
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(3.0, r.size.y - 2.0)),
		Color(tint.r, tint.g, tint.b, 0.85))
	draw_string(_font, r.position + Vector2(36, 13), label,
		HORIZONTAL_ALIGNMENT_LEFT, 150, 9, UITheme.TEXT)
	draw_string(_font, r.position + Vector2(36, 24), sub,
		HORIZONTAL_ALIGNMENT_LEFT, 150, 8, UITheme.TEXT_DIM)
	draw_string(_font, r.position + Vector2(0, 15), "%d / %d" % [have, need],
		HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 24, 11, tint)
	draw_string(_font, r.position + Vector2(0, 15), "✔" if ok else "✘",
		HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 11, tint)
	# stock bar — how close you are, at a glance
	var bar := Rect2(r.position + Vector2(r.size.x - 104.0, 20.0), Vector2(80.0, 3.0))
	draw_rect(bar, Color(1, 1, 1, 0.10))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(have)
		/ maxf(float(need), 1.0), 0.0, 1.0), bar.size.y)),
		Color(tint.r, tint.g, tint.b, 0.9))


func _draw_footer(maxed: bool, ready: bool) -> void:
	var by := _panel.end.y - 46.0
	# confirm button
	if not maxed:
		_btn = Rect2(_panel.position.x + PANEL_W * 0.5 - 72, by, 144, 22)
		var col := Color(0.5, 1.0, 0.6) if ready else Color(0.55, 0.6, 0.66)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r, col.g, col.b, 0.16 if ready else 0.05)
		sb.border_color = Color(col.r, col.g, col.b, 0.9 if ready else 0.35)
		sb.set_border_width_all(2 if ready else 1)
		sb.set_corner_radius_all(5)
		sb.draw(get_canvas_item(), _btn)
		if ready:
			_grad(_btn.grow(-2.0), Color(col.r, col.g, col.b, 0.28),
				Color(col.r, col.g, col.b, 0.04))
			var kw := UITheme.key_width("E", _font, 11)
			var lbl := "INSTALL UPGRADE"
			var tw := _font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var sx := _btn.position.x + (_btn.size.x - (kw + 6.0 + tw)) * 0.5
			UITheme.draw_key(self, Vector2(sx, _btn.position.y + 3.0), "E", _font, 11, col)
			draw_string(_font, Vector2(sx + kw + 6.0, _btn.position.y + 15.0),
				lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		else:
			# hazard hatch — cannot-afford reads as texture, not just a tint
			var hx := _btn.position.x + 4.0
			while hx < _btn.end.x - 4.0:
				draw_line(Vector2(hx, _btn.end.y - 3.0),
					Vector2(hx + 7.0, _btn.position.y + 3.0),
					Color(col.r, col.g, col.b, 0.13), 1.5)
				hx += 8.0
			draw_string(_font, _btn.position + Vector2(0, 14), "NEED MATERIALS",
				HORIZONTAL_ALIGNMENT_CENTER, _btn.size.x, 11, col)
	UITheme.draw_hints(self, Vector2(_panel.position.x + PANEL_W * 0.5, _panel.end.y - 12),
		[["Esc", "close"]], _font, 8)
