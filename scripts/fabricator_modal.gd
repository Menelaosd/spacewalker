extends Control
## The fabricator's catalogue modal — category tabs, a card grid of every
## printable object (locked ones ghosted with "no recipe yet"), a detail
## strip with real element costs, and a print button that hands off to
## room placement. Keyboard: 1-5 / Tab switch tabs, arrows or WASD move,
## E prints, Esc closes. Mouse works everywhere too.

signal closed()
signal craft_chosen(id: String)

const Craftables := preload("res://scripts/craftables.gd")

const PANEL_W := 680.0
const GRID_COLS := 6
const CARD_W := 99.0
const CARD_H := 74.0
const CARD_GAP := 7.0
const TAB_H := 26.0
const DETAIL_H := 88.0

var _font: Font = ThemeDB.fallback_font
var _tab := 0
var _sel := 0
var _hover := -1
var _hover_tab := -1
var _panel := Rect2()
var _btn := Rect2()
var _tab_rects: Array[Rect2] = []
var _card_rects: Array[Rect2] = []
var _flash := 0.0


func _ready() -> void:
	# anchors AND offsets — set_anchors_preset alone leaves this control 0x0
	# when the parent hasn't laid out yet, which makes it unclickable (the
	# _draw still paints full-screen, hiding the bug)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	visible = false
	GameState.inventory_changed.connect(func(): if visible: queue_redraw())
	GameState.recipes_changed.connect(func(): if visible: queue_redraw())


func open() -> void:
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


func _ids() -> Array:
	return Craftables.ids_in_category(Craftables.CATEGORIES[_tab])


func _sel_id() -> String:
	var ids := _ids()
	return ids[clampi(_sel, 0, ids.size() - 1)] if ids.size() > 0 else ""


func _confirm() -> void:
	var id := _sel_id()
	if id == "" or not GameState.recipes_unlocked.has(id):
		Sfx.play("deny", -12.0)
		return
	if not GameState.can_afford(Craftables.ITEMS[id]["cost"]):
		Sfx.play("deny", -12.0)
		return
	craft_chosen.emit(id)   # ship_interior closes us and starts placement


func _move_sel(dx: int, dy: int) -> void:
	var n := _ids().size()
	if n == 0:
		return
	var col := _sel % GRID_COLS
	var row := _sel / GRID_COLS
	col = clampi(col + dx, 0, GRID_COLS - 1)
	row = clampi(row + dy, 0, int(ceil(n / float(GRID_COLS))) - 1)
	_sel = clampi(row * GRID_COLS + col, 0, n - 1)
	queue_redraw()


func _set_tab(t: int) -> void:
	_tab = wrapi(t, 0, Craftables.CATEGORIES.size())
	_sel = 0
	_hover = -1        # stale hover from the previous tab's grid
	_hover_tab = -1
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				close()
			KEY_TAB:
				_set_tab(_tab + (-1 if event.shift_pressed else 1))
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				_set_tab(event.physical_keycode - KEY_1)
			KEY_LEFT, KEY_A:
				_move_sel(-1, 0)
			KEY_RIGHT, KEY_D:
				_move_sel(1, 0)
			KEY_UP, KEY_W:
				_move_sel(0, -1)
			KEY_DOWN, KEY_S:
				_move_sel(0, 1)
			KEY_E, KEY_ENTER, KEY_KP_ENTER:
				_confirm()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		# hover feedback so the mouse path is obvious
		var h := -1
		var ht := -1
		for i in _card_rects.size():
			if _card_rects[i].has_point(event.position):
				h = i
		for i in _tab_rects.size():
			if _tab_rects[i].has_point(event.position):
				ht = i
		if h != _hover or ht != _hover_tab:
			_hover = h
			_hover_tab = ht
			queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _tab_rects.size():
			if _tab_rects[i].has_point(event.position):
				_set_tab(i)
				accept_event()
				return
		for i in _card_rects.size():
			if _card_rects[i].has_point(event.position):
				if _sel == i and event.double_click:
					_confirm()   # double-click prints; single click only selects
				else:
					_sel = i
					queue_redraw()
				accept_event()
				return
		if _btn.has_point(event.position):
			_confirm()
		elif not _panel.has_point(event.position):
			close()
		accept_event()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0.02, 0.05, 0.72))

	var ids := _ids()
	var rows := int(ceil(ids.size() / float(GRID_COLS)))
	var grid_h := rows * (CARD_H + CARD_GAP)
	var body_h := 64.0 + TAB_H + 10.0 + grid_h + DETAIL_H + 30.0
	_panel = Rect2((vp.x - PANEL_W) * 0.5, (vp.y - body_h) * 0.5, PANEL_W, body_h)
	UITheme.draw_sci_panel(self, _panel, UITheme.ACCENT)
	if _flash > 0.0:
		draw_rect(_panel.grow(-3.0), Color(UITheme.ACCENT_WARM.r,
			UITheme.ACCENT_WARM.g, UITheme.ACCENT_WARM.b, 0.6 * _flash), false, 2.0)

	var px := _panel.position.x + 24.0
	var y := _panel.position.y + 32.0

	# header — printer icon + title + known-recipes tally
	var ft: Texture2D = Craftables.FABRICATOR_TEX
	var fs := 30.0 / maxf(ft.get_size().x, ft.get_size().y)
	draw_texture_rect(ft, Rect2(px, y - 18, ft.get_size().x * fs, ft.get_size().y * fs), false)
	draw_string(_font, Vector2(px + 38, y), "FABRICATOR",
		HORIZONTAL_ALIGNMENT_LEFT, 300, 15, UITheme.ACCENT)
	draw_string(_font, Vector2(px + 38, y + 14), "print objects for the rooms you built",
		HORIZONTAL_ALIGNMENT_LEFT, 300, 9, UITheme.TEXT_DIM)
	var known := GameState.recipes_unlocked.size()
	draw_string(_font, Vector2(px, y), "%d / %d  RECIPES" % [known, Craftables.ITEMS.size()],
		HORIZONTAL_ALIGNMENT_RIGHT, PANEL_W - 48, 11, UITheme.TEXT_DIM)
	y += 28.0

	# tabs
	_tab_rects.clear()
	var tab_w := (PANEL_W - 48.0) / Craftables.CATEGORIES.size()
	for t in Craftables.CATEGORIES.size():
		var r := Rect2(px + t * tab_w, y, tab_w - 4.0, TAB_H)
		_tab_rects.append(r)
		var on := t == _tab
		var hov := t == _hover_tab and not on
		var col: Color = UITheme.ACCENT if on else Color(1, 1, 1, 0.6 if hov else 0.35)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r, col.g, col.b, 0.16 if on else (0.09 if hov else 0.04))
		sb.border_color = Color(col.r, col.g, col.b, 0.8 if on else (0.5 if hov else 0.25))
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(5)
		sb.draw(get_canvas_item(), r)
		draw_string(_font, r.position + Vector2(0, 17), Craftables.CATEGORIES[t],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, col)
	y += TAB_H + 10.0

	# card grid
	_card_rects.clear()
	_sel = clampi(_sel, 0, maxi(ids.size() - 1, 0))
	for i in ids.size():
		var id: String = ids[i]
		var it: Dictionary = Craftables.ITEMS[id]
		var r := Rect2(px + (i % GRID_COLS) * (CARD_W + CARD_GAP),
			y + (i / GRID_COLS) * (CARD_H + CARD_GAP), CARD_W, CARD_H)
		_card_rects.append(r)
		var unlocked: bool = GameState.recipes_unlocked.has(id)
		var afford: bool = unlocked and GameState.can_afford(it["cost"])
		var selc := i == _sel
		var hov2 := i == _hover and not selc
		var edge := Color(1, 1, 1, 0.4 if hov2 else 0.14)
		if selc:
			edge = UITheme.ACCENT
		elif afford:
			edge = Color(0.5, 1.0, 0.6, 0.65 if hov2 else 0.4)
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0.09, 0.13, 0.19, 0.95) if hov2 or selc \
			else (Color(0.06, 0.09, 0.14, 0.9) if unlocked else Color(0.04, 0.05, 0.08, 0.9))
		sb2.border_color = edge
		sb2.set_border_width_all(2 if selc else 1)
		sb2.set_corner_radius_all(6)
		sb2.draw(get_canvas_item(), r)
		# art — ghosted when the recipe is still lost
		var tex: Texture2D = it["tex"]
		var box := 46.0
		var s := box / maxf(tex.get_size().x, tex.get_size().y)
		var dsz := tex.get_size() * s
		draw_texture_rect(tex, Rect2(r.position + Vector2((r.size.x - dsz.x) * 0.5, 6 + (box - dsz.y) * 0.5), dsz),
			false, Color(1, 1, 1, 1.0) if unlocked else Color(0.62, 0.72, 0.92, 0.32))
		if unlocked:
			draw_string(_font, r.position + Vector2(4, r.size.y - 8), it["name"],
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 9,
				UITheme.TEXT if selc else UITheme.TEXT_DIM)
		else:
			draw_string(_font, r.position + Vector2(4, r.size.y - 8), "no recipe yet",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 9, Color(1, 1, 1, 0.28))
	y += grid_h + 6.0

	# detail strip for the selection
	var dr := Rect2(px, y, PANEL_W - 48.0, DETAIL_H - 14.0)
	var id2 := _sel_id()
	if id2 != "":
		_draw_detail(dr, id2)
	UITheme.draw_hints(self, Vector2(_panel.position.x + PANEL_W * 0.5, _panel.end.y - 6),
		[["1-5", "tab"], ["←→↑↓", "browse"], ["E", "print"], ["Esc", "close"]], _font, 9)


func _draw_detail(r: Rect2, id: String) -> void:
	var it: Dictionary = Craftables.ITEMS[id]
	var unlocked: bool = GameState.recipes_unlocked.has(id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.13, 0.95)
	sb.border_color = Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.draw(get_canvas_item(), r)
	var x := r.position.x + 12.0
	if not unlocked:
		draw_string(_font, Vector2(x, r.position.y + 24), "?  RECIPE NOT RECOVERED",
			HORIZONTAL_ALIGNMENT_LEFT, 320, 13, Color(1, 1, 1, 0.4))
		draw_string(_font, Vector2(x, r.position.y + 42),
			"Lost blueprints drift inside old wrecks. Salvage derelict ships to recover them.",
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 10, UITheme.TEXT_DIM)
		_btn = Rect2()
		return
	draw_string(_font, Vector2(x, r.position.y + 22), it["name"],
		HORIZONTAL_ALIGNMENT_LEFT, 260, 13, UITheme.TEXT)
	draw_string(_font, Vector2(x, r.position.y + 38), it["desc"],
		HORIZONTAL_ALIGNMENT_LEFT, 300, 9, UITheme.TEXT_DIM)
	draw_string(_font, Vector2(x, r.position.y + 56), "SIZE  %d slot%s%s" % [
		int(it["size"]), "s" if int(it["size"]) > 1 else "",
		"  ·  floor mat" if it.get("flat", false) else ""],
		HORIZONTAL_ALIGNMENT_LEFT, 260, 9, UITheme.TEXT_DIM)
	# cost tallies, right-aligned block with have/need colors
	var cx := r.position.x + r.size.x * 0.52
	var cy := r.position.y + 16.0
	var all_ok := true
	for sym in it["cost"]:
		var need := int(it["cost"][sym])
		var have := int(GameState.elements.get(sym, 0))
		var ok := have >= need
		all_ok = all_ok and ok
		var tint := Color(0.5, 1.0, 0.6) if ok else Color(1.0, 0.5, 0.45)
		var icon := Elements.icon_for(sym)
		if icon != null:
			var s := 16.0 / maxf(icon.get_size().x, icon.get_size().y)
			draw_texture_rect(icon, Rect2(Vector2(cx, cy - 11),
				icon.get_size() * s), false)
		draw_string(_font, Vector2(cx + 20, cy), "%s  %d/%d" % [sym, have, need],
			HORIZONTAL_ALIGNMENT_LEFT, 110, 10, tint)
		cy += 16.0
		if cy > r.end.y - 8.0:
			cx += 118.0
			cy = r.position.y + 16.0
	# print button
	_btn = Rect2(r.end.x - 118.0, r.end.y - 34.0, 106.0, 24.0)
	var col := Color(0.5, 1.0, 0.6) if all_ok else Color(0.5, 0.55, 0.6)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(col.r, col.g, col.b, 0.18 if all_ok else 0.06)
	bsb.border_color = Color(col.r, col.g, col.b, 0.9 if all_ok else 0.35)
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(5)
	bsb.draw(get_canvas_item(), _btn)
	if all_ok:
		var kw := UITheme.key_width("E", _font, 11)
		var tw := _font.get_string_size("PRINT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var sx := _btn.position.x + (_btn.size.x - (kw + 7.0 + tw)) * 0.5
		UITheme.draw_key(self, Vector2(sx, _btn.position.y + 3.0), "E", _font, 11, col)
		draw_string(_font, Vector2(sx + kw + 7.0, _btn.position.y + 16.0), "PRINT",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
	else:
		draw_string(_font, _btn.position + Vector2(0, 16), "NEED MATERIALS",
			HORIZONTAL_ALIGNMENT_CENTER, _btn.size.x, 10, col)
