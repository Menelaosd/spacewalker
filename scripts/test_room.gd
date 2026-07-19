extends Node2D
## TEST ROOM — inspection showroom for EVERY craftable object. Renders each item
## at its true in-game display size (dims_of), zoomed for the eye, and loops the
## animated ones on the EXACT in-game timing (DEV_ANIM_FPS + per-device hash
## rate/phase) so what you see here is what the ship draws. Grouped by category,
## scroll with the wheel / arrows / PageUp-Down.
## Run: godot res://scenes/test_room.tscn   (delete scenes/test_room.* to remove)

const Craftables := preload("res://scripts/craftables.gd")
const DEV_ANIM_DIR := "res://assets/sprites/device_anim"
const DEV_ANIM_FPS := 2.0   # must match ship_interior.gd

var _font: Font = ThemeDB.fallback_font
var _t := 0.0
var _scroll := 0.0
var _content_h := 0.0
var _anim := {}       # id -> Array[Texture2D]
var _rate := {}       # id -> speed mult (in-game formula)
var _phase := {}      # id -> start phase
var _cells: Array = []   # {id, name, cat, animated} in draw order, with category headers inlined

const MARGIN := 26.0
const CELL_W := 168.0
const CELL_H := 176.0
const HEADER_H := 40.0
const SPRITE_AREA := 118.0   # px of vertical room for the sprite in a cell


func _ready() -> void:
	_load_anims()
	# build the ordered cell list: category header rows + item cells
	for cat in Craftables.CATEGORIES:
		_cells.append({"header": cat})
		for id in Craftables.ids_in_category(cat):
			var it: Dictionary = Craftables.ITEMS[id]
			_cells.append({"id": id, "name": str(it.get("name", id)),
				"animated": _anim.has(id), "flat": bool(it.get("flat", false))})
	if OS.get_environment("SW_SHOT") != "":
		await get_tree().create_timer(0.7).timeout
		if is_inside_tree():
			get_viewport().get_texture().get_image().save_png(OS.get_environment("SW_SHOT"))
			get_tree().quit()


func _load_anims() -> void:
	var groups := {}
	var d := DirAccess.open(DEV_ANIM_DIR)
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".png"):
			continue
		var base := f.substr(0, f.length() - 4)
		var us := base.rfind("_")
		if us < 0 or not base.substr(us + 1).is_valid_int():
			continue
		var id := base.substr(0, us)
		if not groups.has(id):
			groups[id] = []
		(groups[id] as Array).append([int(base.substr(us + 1)), f])
	# only keep anims that belong to an actual craftable
	for id in groups:
		if not Craftables.ITEMS.has(id):
			continue
		var list: Array = groups[id]
		list.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
		var frames: Array = []
		for e in list:
			var path := "%s/%s" % [DEV_ANIM_DIR, e[1]]
			if ResourceLoader.exists(path):
				var tex: Texture2D = load(path)
				if tex != null:
					frames.append(tex)
		if frames.size() > 1:
			_anim[id] = frames
			var hp := absi(hash(id))
			_phase[id] = float(hp % 997) / 997.0
			_rate[id] = 0.8 + float((hp / 997) % 401) / 1000.0


func _dev_frame(id: String) -> Texture2D:
	var frames: Array = _anim[id]
	var n := frames.size()
	var t: float = _t * DEV_ANIM_FPS * float(_rate.get(id, 1.0)) + float(_phase.get(id, 0.0)) * float(n)
	return frames[int(floor(t)) % n]


func _cols() -> int:
	var vp := get_viewport_rect().size
	return maxi(1, int((vp.x - MARGIN * 2.0) / CELL_W))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var vp := get_viewport_rect().size
	var page := vp.y - 90.0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll += 60.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll -= 60.0
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_DOWN: _scroll += 48.0
			KEY_UP: _scroll -= 48.0
			KEY_PAGEDOWN, KEY_SPACE: _scroll += page
			KEY_PAGEUP: _scroll -= page
			KEY_HOME: _scroll = 0.0
			KEY_END: _scroll = _content_h
			KEY_ESCAPE: get_tree().quit()
	_scroll = clampf(_scroll, 0.0, maxf(0.0, _content_h - (vp.y - 120.0)))


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.08, 0.11))
	var cols := _cols()
	var ox := MARGIN
	var top := 64.0
	var y := top - _scroll
	var col := 0
	var row_h := CELL_H

	# lay out header rows + item grid, measuring content height as we go
	var i := 0
	while i < _cells.size():
		var c: Dictionary = _cells[i]
		if c.has("header"):
			if col != 0:
				y += row_h
				col = 0
			_draw_header(c["header"], ox, y, vp.x - MARGIN * 2.0)
			y += HEADER_H
			i += 1
			continue
		var cx := ox + col * CELL_W
		if y > -row_h and y < vp.y:      # cull off-screen cells
			_draw_cell(c, cx, y)
		col += 1
		if col >= cols:
			col = 0
			y += row_h
		i += 1
	if col != 0:
		y += row_h
	_content_h = (y + _scroll) - top

	# fixed chrome on top
	draw_rect(Rect2(0, 0, vp.x, 52), Color(0.04, 0.05, 0.08, 0.96))
	draw_string(_font, Vector2(24, 24), "TEST ROOM — %d craftables (%d animated)" % [_count_items(), _anim.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.65, 0.88, 1.0))
	draw_string(_font, Vector2(24, 42), "wheel / ↑↓ / PgUp-PgDn scroll   ·   Home/End   ·   Esc quit",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.85, 0.9))
	# scrollbar
	var track_h := vp.y - 60.0
	if _content_h > track_h:
		var frac := track_h / _content_h
		var bar_h := maxf(24.0, track_h * frac)
		var bar_y := 56.0 + (track_h - bar_h) * (_scroll / maxf(1.0, _content_h - track_h))
		draw_rect(Rect2(vp.x - 8, bar_y, 4, bar_h), Color(0.4, 0.6, 0.8, 0.5))


func _draw_header(cat: String, x: float, y: float, w: float) -> void:
	if y < 44.0 or y > get_viewport_rect().size.y:
		return
	draw_rect(Rect2(x, y + 6, w, 26), Color(0.11, 0.14, 0.2))
	draw_rect(Rect2(x, y + 6, 4, 26), Color(0.45, 0.75, 1.0))
	draw_string(_font, Vector2(x + 14, y + 25), cat, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.92, 1.0))


func _draw_cell(c: Dictionary, x: float, y: float) -> void:
	var id: String = c["id"]
	# cell panel
	draw_rect(Rect2(x + 4, y + 4, CELL_W - 10, CELL_H - 12), Color(0.10, 0.12, 0.17))
	# floor line the sprite stands on
	var base_y := y + 6 + SPRITE_AREA
	draw_line(Vector2(x + 12, base_y), Vector2(x + CELL_W - 14, base_y), Color(0.25, 0.3, 0.4, 0.7), 1.0)

	var tex: Texture2D = Craftables.ITEMS[id]["tex"]
	if c["animated"]:
		tex = _dev_frame(id)
	var disp: Vector2 = Craftables.dims_of(id)      # TRUE in-game size
	# inspection zoom: bring small items up to ~92px tall, cap 3x
	var zoom := clampf(92.0 / maxf(disp.y, 1.0), 1.0, 3.0)
	var dw := disp.x * zoom
	var dh := disp.y * zoom
	if c["flat"]:
		dh *= 0.55
	var cx := x + CELL_W * 0.5
	# anchored bottom-centre on the floor line, exactly like _draw_furniture
	draw_texture_rect(tex, Rect2(cx - dw * 0.5, base_y - dh, dw, dh), false)

	# label block
	var ly := base_y + 14
	draw_string(_font, Vector2(x + 8, ly), c["name"], HORIZONTAL_ALIGNMENT_CENTER, CELL_W - 12, 12, Color(1, 1, 1, 0.92))
	draw_string(_font, Vector2(x + 8, ly + 15), id, HORIZONTAL_ALIGNMENT_CENTER, CELL_W - 12, 10, Color(0.6, 0.7, 0.85, 0.8))
	var tag := "%d×%d px" % [int(disp.x), int(disp.y)]
	if c["animated"]:
		tag = "▶ ANIM  " + tag
		draw_string(_font, Vector2(x + 8, ly + 30), tag, HORIZONTAL_ALIGNMENT_CENTER, CELL_W - 12, 10, Color(0.5, 0.95, 0.7, 0.9))
	else:
		draw_string(_font, Vector2(x + 8, ly + 30), tag, HORIZONTAL_ALIGNMENT_CENTER, CELL_W - 12, 10, Color(0.55, 0.6, 0.72, 0.7))


func _count_items() -> int:
	var n := 0
	for c in _cells:
		if not c.has("header"):
			n += 1
	return n
