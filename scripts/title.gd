extends Control
## Main menu — a painted backdrop (intro2), the SPACEWALKER banner, and a
## DATA-DRIVEN command menu framed in sci-fi brackets. To add an entry
## later, just append one dict to the array a `_menu_*()` builder returns:
##   {"label": "...", "icon": "play|continue|settings|quit|plus|back|slot",
##    "action": Callable, "enabled": bool, "danger": bool}
## Menus nest via a stack, so NEW GAME / CONTINUE open a slot sub-menu and
## Esc walks back. Keyboard (↑/↓ + Enter/Esc) and mouse both drive it.

const VERSION := "1.8.0"
const SLOTS := 3
const BG_TEX := preload("res://assets/sprites/title_bg.png")
const LOGO_TEX := preload("res://assets/sprites/logo.png")

const MENU_X := 70.0
const MENU_TOP := 342.0
const ITEM_W := 280.0
const ITEM_H := 38.0
const ITEM_GAP := 9.0

var _font: Font = ThemeDB.fallback_font
var _t := 0.0

var _menu: Array = []          # current menu's items
var _menu_title := ""
var _rebuild: Callable         # builds the current menu (for live refresh)
var _stack: Array = []         # [[title, builder], ...] for Back
var _sel := 0
var _hover := -1
var _armed := -1               # slot index armed for overwrite confirm


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_LINEAR
	theme = UITheme.make_theme()
	GameState.in_game = false
	get_tree().paused = false
	_open(_main_menu, "COMMAND")
	match OS.get_environment("SW_MENU"):   # debug: jump to a sub-menu for shots
		"new": _push(_slot_menu.bind(true), "SELECT SAVE SLOT")
		"continue": _push(_slot_menu.bind(false), "LOAD SAVE")


func _process(delta: float) -> void:
	_t += delta
	var m := get_local_mouse_position()
	var h := -1
	for i in _menu.size():
		if _item_rect(i).has_point(m):
			h = i
			break
	if h != _hover:
		_hover = h
	queue_redraw()


# ------------------------------------------------------------------
# Menu model
# ------------------------------------------------------------------
func _any_save() -> bool:
	for i in SLOTS:
		if not GameState.slot_data(i).is_empty():
			return true
	return false


func _main_menu() -> Array:
	# ── add new top-level commands here ──────────────────────────
	return [
		{"label": "NEW GAME", "icon": "play",
			"action": func(): _push(_slot_menu.bind(true), "SELECT SAVE SLOT")},
		{"label": "CONTINUE", "icon": "continue", "enabled": _any_save(),
			"action": func(): _push(_slot_menu.bind(false), "LOAD SAVE")},
		{"label": "SETTINGS", "icon": "settings",
			"action": func(): _push(_settings_menu, "SETTINGS")},
		{"label": "QUIT", "icon": "quit", "danger": true,
			"action": func(): get_tree().quit()},
	]


func _slot_menu(new_mode: bool) -> Array:
	var items: Array = []
	if new_mode:
		# NEW GAME lists only free slots. If every slot is full, it falls back
		# to overwrite entries so you're never stranded.
		var has_empty := false
		for i in SLOTS:
			if GameState.slot_data(i).is_empty():
				has_empty = true
				break
		for i in SLOTS:
			var empty := GameState.slot_data(i).is_empty()
			if has_empty:
				if empty:
					items.append({"label": "SLOT %d — NEW GAME" % (i + 1),
						"icon": "plus", "action": _on_new_slot.bind(i)})
			else:
				var lbl := ("SLOT %d — OVERWRITE?" % (i + 1)) if _armed == i \
					else ("SLOT %d — OVERWRITE" % (i + 1))
				items.append({"label": lbl, "icon": "slot",
					"action": _on_new_slot.bind(i)})
	else:
		# CONTINUE lists only real saves, each with its own summary
		for i in SLOTS:
			if not GameState.slot_data(i).is_empty():
				items.append({"label": _slot_text(i), "icon": "slot",
					"action": _on_load_slot.bind(i)})
		if items.is_empty():
			items.append({"label": "NO SAVES YET", "icon": "slot", "enabled": false,
				"action": func(): pass})
	items.append({"label": "BACK", "icon": "back", "action": func(): _back()})
	return items


func _settings_menu() -> Array:
	# placeholder rooms to grow into — wire real screens here later
	return [
		{"label": "AUDIO — soon", "icon": "settings", "enabled": false, "action": func(): pass},
		{"label": "CONTROLS — soon", "icon": "settings", "enabled": false, "action": func(): pass},
		{"label": "BACK", "icon": "back", "action": func(): _back()},
	]


func _open(builder: Callable, title: String) -> void:
	# store the BUILDER, not a snapshot — so labels (overwrite-confirm,
	# CONTINUE availability) can refresh in place via _refresh()
	_rebuild = builder
	_menu = builder.call()
	_menu_title = title
	_armed = -1
	_sel = 0
	for i in _menu.size():
		if _menu[i].get("enabled", true):
			_sel = i
			break


func _push(builder: Callable, title: String) -> void:
	_stack.append([_menu_title, _rebuild])
	_open(builder, title)


func _back() -> void:
	if _stack.is_empty():
		return
	var prev: Array = _stack.pop_back()
	_open(prev[1], prev[0])


func _refresh() -> void:
	# rebuild the current menu's items in place, keeping the selection
	_menu = _rebuild.call()
	_sel = clampi(_sel, 0, _menu.size() - 1)


func _on_new_slot(i: int) -> void:
	if GameState.slot_data(i).is_empty():
		GameState.new_game(i)
		get_tree().change_scene_to_file("res://scenes/chargen.tscn")
		return
	# occupied — arm once (relabel to OVERWRITE?), confirm on the second press
	if _armed != i:
		_armed = i
		_refresh()
		return
	GameState.new_game(i)
	get_tree().change_scene_to_file("res://scenes/chargen.tscn")


func _on_load_slot(i: int) -> void:
	if GameState.load_game(i):
		get_tree().change_scene_to_file("res://scenes/ship_interior.tscn")


func _activate(i: int) -> void:
	if i < 0 or i >= _menu.size():
		return
	var it: Dictionary = _menu[i]
	if not it.get("enabled", true):
		return
	(it["action"] as Callable).call()


func _slot_text(i: int) -> String:
	# CONTINUE labels — the save's own summary
	var data := GameState.slot_data(i)
	if data.is_empty():
		return "SLOT %d — EMPTY" % (i + 1)
	var who := str((data.get("pilot", {}) as Dictionary).get("name", ""))
	if who == "":
		who = "WALKER"
	if data.get("game_complete", false) and (data.get("rescued", []) as Array).size() >= 5:
		return "SLOT %d — %s · ✦ HAVEN" % [i + 1, who]
	return "SLOT %d — %s · DRIVE %d/5" % [i + 1, who, int(data.get("quest_stage", 0))]


# ------------------------------------------------------------------
# Input
# ------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover >= 0:
			_sel = _hover
			# mark handled BEFORE activating — _activate may change the scene,
			# after which get_viewport() is null and would crash
			get_viewport().set_input_as_handled()
			_activate(_hover)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_step_sel(-1)
		KEY_DOWN, KEY_S:
			_step_sel(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_activate(_sel)
		KEY_ESCAPE:
			if not _stack.is_empty():
				_back()
	queue_redraw()


func _step_sel(dir: int) -> void:
	if _menu.is_empty():
		return
	if _armed != -1:
		_armed = -1
		_refresh()   # drop the OVERWRITE? relabel when you navigate away
	var n := _menu.size()
	for _k in n:
		_sel = (_sel + dir + n) % n
		if _menu[_sel].get("enabled", true):
			return


# ------------------------------------------------------------------
# Layout
# ------------------------------------------------------------------
func _item_rect(i: int) -> Rect2:
	return Rect2(MENU_X, MENU_TOP + i * (ITEM_H + ITEM_GAP), ITEM_W, ITEM_H)


# ------------------------------------------------------------------
# Draw
# ------------------------------------------------------------------
func _draw() -> void:
	var vp := get_viewport_rect().size
	# painted backdrop, cover-fit (title_bg shares the 16:9 aspect)
	draw_texture_rect(BG_TEX, Rect2(Vector2.ZERO, vp), false)
	# darken the left third so the menu reads over the nebula — ONE smooth
	# vertex-colour gradient (a banded rect stack left visible seam lines)
	var gw := vp.x * 0.52
	var dark := Color(0.01, 0.02, 0.04, 0.6)
	var clear := Color(0.01, 0.02, 0.04, 0.0)
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(gw, 0), Vector2(gw, vp.y), Vector2(0, vp.y)]),
		PackedColorArray([dark, clear, clear, dark]))
	# top & bottom vignette bands
	draw_rect(Rect2(0, 0, vp.x, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(0, vp.y - 4, vp.x, 4), Color(0, 0, 0, 0.6))

	_draw_frame(vp)
	_draw_logo(vp)
	_draw_menu()
	_draw_footer(vp)


func _draw_frame(vp: Vector2) -> void:
	## Sci-fi border: an inset cyan rule with bracketed corners and a few
	## hazard ticks — the "corners above the image" from the concept.
	var acc := UITheme.ACCENT
	var pad := 16.0
	var r := Rect2(pad, pad, vp.x - pad * 2.0, vp.y - pad * 2.0)
	var flick := 0.75 + 0.15 * sin(_t * 2.3) + 0.1 * sin(_t * 0.9)
	draw_rect(r, Color(acc.r, acc.g, acc.b, 0.10 * flick), false, 1.0)
	# long bracket arms at each corner
	var arm := 52.0
	for corner in [
			[r.position, Vector2(1, 0), Vector2(0, 1)],
			[Vector2(r.end.x, r.position.y), Vector2(-1, 0), Vector2(0, 1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, 0), Vector2(0, -1)],
			[r.end, Vector2(-1, 0), Vector2(0, -1)]]:
		var o: Vector2 = corner[0]
		var hx: Vector2 = corner[1]
		var vy: Vector2 = corner[2]
		draw_line(o, o + hx * arm, Color(acc.r, acc.g, acc.b, 0.85 * flick), 2.0)
		draw_line(o, o + vy * arm, Color(acc.r, acc.g, acc.b, 0.85 * flick), 2.0)
		# inner corner accent tick
		draw_line(o + hx * 10.0 + vy * 10.0, o + hx * 26.0 + vy * 10.0,
			Color(acc.r, acc.g, acc.b, 0.5 * flick), 1.0)
	# hazard tick clusters top-centre and bottom-centre
	for cx in [vp.x * 0.5]:
		for s in [pad + 2.0, r.end.y - 6.0]:
			for k in 5:
				draw_rect(Rect2(cx - 26.0 + k * 11.0, s, 7, 3),
					UITheme.ACCENT_WARM if k % 2 == 0 else Color(acc.r, acc.g, acc.b, 0.5))


func _draw_logo(vp: Vector2) -> void:
	var sc := 0.62
	var c := Vector2(vp.x * 0.5, 118.0 + sin(_t * 0.8) * 3.0)
	draw_set_transform(c, 0.0, Vector2(sc, sc))
	# cyan under-glow + rare signal glitch
	draw_texture(LOGO_TEX, -LOGO_TEX.get_size() * 0.5 + Vector2(0, 8),
		Color(0.2, 0.85, 1.0, 0.10))
	if fmod(_t, 3.4) < 0.12:
		var j := sin(_t * 90.0) * 5.0
		draw_texture(LOGO_TEX, -LOGO_TEX.get_size() * 0.5 + Vector2(j, 0),
			Color(0.3, 1.0, 1.0, 0.45))
		draw_texture(LOGO_TEX, -LOGO_TEX.get_size() * 0.5 - Vector2(j, 0),
			Color(1.0, 0.4, 0.4, 0.35))
	draw_texture(LOGO_TEX, -LOGO_TEX.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_menu() -> void:
	# panel behind the command list
	var top := _item_rect(0)
	var bot := _item_rect(_menu.size() - 1)
	var panel := Rect2(top.position.x - 18, top.position.y - 30,
		ITEM_W + 36, (bot.end.y - top.position.y) + 44)
	UITheme.draw_sci_panel(self, panel)
	UITheme.draw_brackets(self, panel, UITheme.ACCENT, 12.0, 3.0)
	draw_string(_font, panel.position + Vector2(16, 21), "◈ " + _menu_title,
		HORIZONTAL_ALIGNMENT_LEFT, ITEM_W, 11,
		Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.8))
	# hazard ticks top-right of the panel
	for k in 5:
		draw_rect(Rect2(panel.end.x - 58.0 + k * 10.0, panel.position.y + 16, 6, 3),
			UITheme.ACCENT_WARM if k % 2 == 0 else Color(UITheme.ACCENT.r,
				UITheme.ACCENT.g, UITheme.ACCENT.b, 0.5))
	for i in _menu.size():
		_draw_item(i)


func _draw_item(i: int) -> void:
	var r := _item_rect(i)
	var it: Dictionary = _menu[i]
	var enabled: bool = it.get("enabled", true)
	var on := (i == _sel or i == _hover) and enabled
	var acc := UITheme.ACCENT
	if it.get("danger", false):
		acc = UITheme.DANGER
	if not enabled:
		acc = UITheme.ACCENT_DIM
	# notched button plate
	var cut := 8.0
	var p := r.position
	var e := r.end
	var pts := PackedVector2Array([
		Vector2(p.x + cut, p.y), Vector2(e.x, p.y), Vector2(e.x, e.y - cut),
		Vector2(e.x - cut, e.y), Vector2(p.x, e.y), Vector2(p.x, p.y + cut)])
	var fill := 0.72 if on else (0.42 if enabled else 0.28)
	draw_colored_polygon(pts, Color(0.03, 0.13, 0.18, fill))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(acc.r, acc.g, acc.b, 0.95 if on else 0.5), 1.4)
	# left accent bar, brighter and thicker when selected
	draw_rect(Rect2(p.x, p.y + 6, 4.0 if on else 3.0, r.size.y - 12),
		Color(acc.r, acc.g, acc.b, 0.95 if on else 0.45))
	# selection glow
	if on:
		draw_colored_polygon(pts, Color(acc.r, acc.g, acc.b, 0.06))
	# icon
	_draw_menu_icon(str(it["icon"]), Vector2(p.x + 28, r.get_center().y), 13.0,
		Color(acc.r, acc.g, acc.b, 1.0 if enabled else 0.5))
	# label
	var tcol := UITheme.TEXT if enabled else Color(1, 1, 1, 0.35)
	if on:
		tcol = Color.WHITE
	draw_string(_font, Vector2(p.x + 50, r.get_center().y + 5), str(it["label"]),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 76, 12, tcol)
	# animated chevron on the active row
	if on:
		UITheme.draw_chevrons(self, Vector2(e.x - 26, r.get_center().y), 2, 10.0,
			acc, _t)


func _draw_menu_icon(kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"play":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.5, -s * 0.6), c + Vector2(s * 0.6, 0),
				c + Vector2(-s * 0.5, s * 0.6)]), col)
		"continue":
			draw_arc(c, s * 0.55, -2.2, PI * 1.15, 20, col, 2.0)
			var tip := c + Vector2.from_angle(-2.2) * s * 0.55
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-3, -1), tip + Vector2(4, -2), tip + Vector2(1, 4)]), col)
		"settings":
			for k in 8:
				var a := TAU * float(k) / 8.0
				draw_line(c + Vector2.from_angle(a) * s * 0.4,
					c + Vector2.from_angle(a) * s * 0.62, col, 2.4)
			draw_arc(c, s * 0.4, 0, TAU, 20, col, 2.0)
			draw_circle(c, s * 0.16, col)
		"quit":
			draw_arc(c, s * 0.5, -PI * 0.35, PI * 1.35, 20, col, 2.0)
			draw_line(c + Vector2(0, -s * 0.6), c + Vector2(0, -s * 0.05), col, 2.0)
		"plus":
			draw_line(c + Vector2(-s * 0.45, 0), c + Vector2(s * 0.45, 0), col, 2.2)
			draw_line(c + Vector2(0, -s * 0.45), c + Vector2(0, s * 0.45), col, 2.2)
		"back":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(s * 0.5, -s * 0.6), c + Vector2(-s * 0.6, 0),
				c + Vector2(s * 0.5, s * 0.6)]), col)
		_:  # "slot" — a little save chip
			draw_rect(Rect2(c - Vector2(s * 0.5, s * 0.5), Vector2(s, s)), col, false, 1.6)
			draw_rect(Rect2(c - Vector2(s * 0.2, s * 0.5), Vector2(s * 0.4, s * 0.3)), col)


func _draw_footer(vp: Vector2) -> void:
	var acc := UITheme.ACCENT
	# version, tucked a little further into the frame with hazard ticks
	var vleft := 64.0
	var vy := vp.y - 58.0
	draw_string(_font, Vector2(vleft, vy + 4), "VERSION %s" % VERSION,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(acc.r, acc.g, acc.b, 0.75))
	var vx := vleft + _font.get_string_size("VERSION %s" % VERSION,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
	for k in 5:
		draw_rect(Rect2(vx + k * 9.0, vy - 4, 6, 3),
			UITheme.ACCENT_WARM if k % 2 == 0 else Color(acc.r, acc.g, acc.b, 0.5))
	# control hint, bottom-right
	draw_string(_font, Vector2(0, vp.y - 30),
		"↑ ↓  select     ENTER  confirm     ESC  back  ",
		HORIZONTAL_ALIGNMENT_RIGHT, vp.x - 34, 11,
		Color(1, 1, 1, 0.4))
