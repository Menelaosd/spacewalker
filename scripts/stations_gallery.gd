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
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.06, 0.07, 0.10))
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
		# panel
		draw_rect(Rect2(cx - CELL * 0.5 + 5, cy + 5, CELL - 10, CELL - 12), Color(0.10, 0.12, 0.16))
		var it: Dictionary = _items[i]
		var tex: Texture2D = it["tex"]
		var sz := tex.get_size()
		var sc := minf(IMG / sz.x, IMG / sz.y)
		var dw := sz.x * sc
		var dh := sz.y * sc
		draw_texture_rect(tex, Rect2(cx - dw * 0.5, cy + 18 + (IMG - dh) * 0.5, dw, dh), false)
		# big number badge (top-left)
		var badge := Vector2(cx - CELL * 0.5 + 14, cy + 14)
		draw_rect(Rect2(badge.x - 4, badge.y - 2, 46, 30), Color(0.03, 0.05, 0.08, 0.9))
		draw_string(_font, badge + Vector2(0, 24), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.55, 0.9, 1.0))
		# name
		draw_string(_font, Vector2(cx - CELL * 0.5 + 10, cy + CELL - 18), it["name"],
			HORIZONTAL_ALIGNMENT_CENTER, CELL - 20, 13, Color(1, 1, 1, 0.9))
	_content_h = ceil(_items.size() / float(cols)) * CELL + 40.0
	# fixed header
	draw_rect(Rect2(0, 0, vp.x, 52), Color(0.03, 0.05, 0.08, 0.96))
	draw_string(_font, Vector2(24, 24), "STATION GALLERY — %d options (pick by number)" % _items.size(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.9, 1.0))
	draw_string(_font, Vector2(24, 42), "wheel / arrows / PgUp-PgDn scroll  ·  Home/End  ·  Esc",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.7, 0.85, 0.9))
