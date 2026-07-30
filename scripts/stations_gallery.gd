extends Node2D
## SCROLLABLE, NUMBERED station gallery for picking. Loads the generated stations
## (scratchpad/stations_v2/g2_*.png) + salvaged old ones (stations_old_clean/) via
## raw Image.load so no import step is needed. Scroll wheel / arrows / PgUp-Dn.
## Run: godot res://scenes/stations_gallery.tscn

var _font: Font = ThemeDB.fallback_font
var _scroll := 0.0
var _content_h := 0.0
var _items: Array = []   # {tex, name}

const MARGIN := 24.0
const CELL := 300.0
const IMG := 210.0


func _ready() -> void:
	_load_dir(ProjectSettings.globalize_path("res://scratchpad/stations_v2/"), "g2_")
	_load_dir(ProjectSettings.globalize_path("res://scratchpad/stations_old_clean/"), "")
	if OS.get_environment("SW_SHOT") != "":
		await get_tree().create_timer(0.6).timeout
		if is_inside_tree():
			get_viewport().get_texture().get_image().save_png(OS.get_environment("SW_SHOT"))
			get_tree().quit()


func _load_dir(abs: String, strip: String) -> void:
	var d := DirAccess.open(abs)
	if d == null:
		return
	var files := d.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".png"):
			continue
		var img := Image.load_from_file(abs + f)
		if img == null:
			continue
		var nm := f.substr(0, f.length() - 4)
		if strip != "" and nm.begins_with(strip):
			nm = nm.substr(strip.length())
		if strip == "":
			nm = "OLD " + nm
		_items.append({"tex": ImageTexture.create_from_image(img), "name": nm})


func _cols() -> int:
	return maxi(1, int((get_viewport_rect().size.x - MARGIN * 2.0) / CELL))


func _grad_rect(r: Rect2, top: Color, bottom: Color) -> void:
	## Vertical gradient fill — the gallery's tile and header material.
	draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _fit(s: String, w: float, base: int, floor_size := 7) -> int:
	## Largest size at or below `base` whose string still fits `w` — station names
	## run long, and a name must never spill past its tile.
	var sz := base
	while sz > floor_size and _font.get_string_size(
			s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > w:
		sz -= 1
	return sz


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var vp := get_viewport_rect().size
	var page := vp.y - 100.0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _scroll += 70.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: _scroll -= 70.0
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_DOWN: _scroll += 56.0
			KEY_UP: _scroll -= 56.0
			KEY_PAGEDOWN, KEY_SPACE: _scroll += page
			KEY_PAGEUP: _scroll -= page
			KEY_HOME: _scroll = 0.0
			KEY_END: _scroll = _content_h
			KEY_ESCAPE: get_tree().quit()
	_scroll = clampf(_scroll, 0.0, maxf(0.0, _content_h - (vp.y - 130.0)))


func _draw() -> void:
	var vp := get_viewport_rect().size
	_grad_rect(Rect2(Vector2.ZERO, vp), Color(0.047, 0.062, 0.094), Color(0.024, 0.033, 0.052))
	var cols := _cols()
	var ox := MARGIN + ((vp.x - MARGIN * 2.0) - cols * CELL) * 0.5
	var top := 64.0
	for i in _items.size():
		var col := i % cols
		var row := i / cols
		var cx := ox + col * CELL + CELL * 0.5
		var cy := top + row * CELL - _scroll
		if cy > vp.y or cy + CELL < 40.0:
			continue
		# panel — gradient backing + hairline border
		var cell_r := Rect2(cx - CELL * 0.5 + 5, cy + 5, CELL - 10, CELL - 12)
		_grad_rect(cell_r, Color(0.075, 0.095, 0.135), Color(0.035, 0.048, 0.072))
		draw_rect(cell_r, Color(0.35, 0.62, 0.78, 0.28), false, 1.0)
		var it: Dictionary = _items[i]
		var tex: Texture2D = it["tex"]
		var sz := tex.get_size()
		var sc := minf(IMG / sz.x, IMG / sz.y)
		var dw := sz.x * sc
		var dh := sz.y * sc
		draw_texture_rect(tex, Rect2(cx - dw * 0.5, cy + 18 + (IMG - dh) * 0.5, dw, dh), false)
		# number badge (top-left)
		var badge := Vector2(cx - CELL * 0.5 + 13, cy + 13)
		var bw := 32.0
		_grad_rect(Rect2(badge.x - 4, badge.y - 2, bw, 22),
			Color(0.05, 0.09, 0.13, 0.95), Color(0.02, 0.04, 0.06, 0.95))
		draw_rect(Rect2(badge.x - 4, badge.y - 2, bw, 22),
			Color(0.35, 0.62, 0.78, 0.35), false, 1.0)
		draw_string(_font, Vector2(badge.x - 4, badge.y + 14), str(i + 1),
			HORIZONTAL_ALIGNMENT_CENTER, bw, 16, Color(0.55, 0.9, 1.0))
		# name — shrink-to-fit so long ids never spill the tile
		var nm: String = str(it["name"])
		draw_string(_font, Vector2(cx - CELL * 0.5 + 10, cy + CELL - 20), nm,
			HORIZONTAL_ALIGNMENT_CENTER, CELL - 20, _fit(nm, CELL - 22, 10),
			Color(1, 1, 1, 0.88))
	_content_h = ceil(_items.size() / float(cols)) * CELL + 40.0
	# fixed header — gradient bar with a hairline rule under it
	_grad_rect(Rect2(0, 0, vp.x, 42), Color(0.05, 0.075, 0.115, 0.98),
		Color(0.018, 0.03, 0.048, 0.98))
	draw_line(Vector2(0, 42), Vector2(vp.x, 42), Color(0.35, 0.62, 0.78, 0.35), 1.0)
	draw_string(_font, Vector2(24, 20), "STATION GALLERY — %d options (pick by number)" % _items.size(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.9, 1.0))
	draw_string(_font, Vector2(24, 35), "wheel / arrows / PgUp-PgDn scroll  ·  Home/End  ·  Esc",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.7, 0.85, 0.9))
