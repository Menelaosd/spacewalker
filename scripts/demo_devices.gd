extends Node2D
## DELETABLE DEMO — animation gallery for the fabricated devices. Plays every
## device_anim loop side by side so you can eyeball the motion in-engine.
## Run: godot res://scenes/demo_devices.tscn   (delete scenes/demo_devices.* to remove)

const DIR := "res://assets/sprites/device_anim"

var _anims := {}     # id -> Array[Texture2D]
var _ids: Array = []
var _t := 0.0
var _font: Font = ThemeDB.fallback_font
var _scroll := 0.0
var _content_h := 0.0


func _ready() -> void:
	var byid := {}
	var d := DirAccess.open(DIR)
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".png"):
				continue
			var base := f.get_basename()          # "<id>_<n>"
			var us := base.rfind("_")
			if us < 0:
				continue
			var id := base.substr(0, us)
			var n := int(base.substr(us + 1))
			if not byid.has(id):
				byid[id] = {}
			byid[id][n] = load("%s/%s" % [DIR, f])
	for id in byid:
		var keys: Array = byid[id].keys()
		keys.sort()
		var frames: Array = []
		for k in keys:
			frames.append(byid[id][k])
		if frames.size() > 1:
			_anims[id] = frames
	_ids = _anims.keys()
	_ids.sort()

	if OS.get_environment("SW_SHOT") != "":
		await get_tree().create_timer(0.6).timeout
		if is_inside_tree():
			get_viewport().get_texture().get_image().save_png(OS.get_environment("SW_SHOT"))
			get_tree().quit()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var vp := get_viewport_rect().size
	var page := vp.y - 120.0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _scroll += 64.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: _scroll -= 64.0
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_DOWN: _scroll += 48.0
			KEY_UP: _scroll -= 48.0
			KEY_PAGEDOWN, KEY_SPACE: _scroll += page
			KEY_PAGEUP: _scroll -= page
			KEY_HOME: _scroll = 0.0
			KEY_END: _scroll = _content_h
			KEY_ESCAPE: get_tree().quit()
	_scroll = clampf(_scroll, 0.0, maxf(0.0, _content_h - (vp.y - 140.0)))


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.06, 0.09))
	draw_string(_font, Vector2(24, 30),
		"DEVICE ANIMATION DEMO — %d animated fabricator devices (they loop)" % _ids.size(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.85, 1.0))
	var cols := 6
	var cellw := (vp.x - 48.0) / cols
	var cellh := 176.0
	var ox := 24.0
	var oy := 84.0 - _scroll
	for i in _ids.size():
		var id: String = _ids[i]
		var frames: Array = _anims[id]
		var fi := int(_t * 6.0) % frames.size()
		var tex: Texture2D = frames[fi]
		var col := i % cols
		var row := i / cols
		var cx := ox + col * cellw + cellw * 0.5
		var cell_top := oy + row * cellh
		if cell_top > vp.y or cell_top + cellh < 40.0:
			continue                       # cull off-screen rows
		var base_y := cell_top + 130.0     # a common floor line for every cell
		var sz := tex.get_size()
		var sc := minf(2.2, 118.0 / maxf(sz.x, sz.y))
		var dw := sz.x * sc
		var dh := sz.y * sc
		draw_rect(Rect2(cx - cellw * 0.5 + 5, cell_top + 6, cellw - 10, 158), Color(0.09, 0.11, 0.16))
		# alignment guides: a vertical centre line + the floor line. If the object
		# WOBBLES between frames you see it drift off these guides.
		draw_line(Vector2(cx, cell_top + 12), Vector2(cx, base_y), Color(0.9, 0.3, 0.3, 0.25), 1.0)
		draw_line(Vector2(cx - cellw * 0.5 + 12, base_y), Vector2(cx + cellw * 0.5 - 12, base_y), Color(0.9, 0.3, 0.3, 0.25), 1.0)
		# anchored bottom-centre on the floor line, exactly like the ship draws furniture
		draw_texture_rect(tex, Rect2(cx - dw * 0.5, base_y - dh, dw, dh), false)
		draw_string(_font, Vector2(cx - cellw * 0.5 + 8, base_y + 20), id,
			HORIZONTAL_ALIGNMENT_CENTER, cellw - 16, 12, Color(1, 1, 1, 0.9))
	_content_h = 84.0 + ceil(_ids.size() / float(cols)) * cellh + 40.0
	# fixed header bar over the scrolled content
	draw_rect(Rect2(0, 0, vp.x, 52), Color(0.04, 0.05, 0.08, 0.96))
	draw_string(_font, Vector2(24, 24),
		"ANIMATED OBJECTS — %d devices (loop) · anchored on the red floor line" % _ids.size(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.85, 1.0))
	draw_string(_font, Vector2(24, 42), "wheel / ↑↓ / PgUp-PgDn scroll · Home/End · Esc quit",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.7, 0.85, 0.9))
