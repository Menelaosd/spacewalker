extends SceneTree
## UI kit texture generator — "Nemesis" style: metallic beveled frames with
## riveted corner plates, glossy blue buttons, inset meter troughs.
##   godot --headless --path . -s res://tools/gen_ui_kit.gd
## Produces 9-slice PNGs in assets/ui/. All gradients/bevels are baked here;
## glowing/animated parts are drawn at runtime by ui_theme.gd.

const OUT := "res://assets/ui"

# palette
const NAVY_TOP := Color8(18, 30, 54)
const NAVY_BOT := Color8(7, 12, 24)
const STEEL_HI := Color8(168, 182, 200)
const STEEL_TOP := Color8(116, 128, 146)
const STEEL_MID := Color8(74, 82, 97)
const STEEL_BOT := Color8(42, 48, 60)
const OUTLINE := Color8(6, 8, 12)
const CYAN := Color8(60, 200, 255)
const BLUE_TOP := Color8(88, 148, 216)
const BLUE_MID := Color8(44, 90, 160)
const BLUE_BOT := Color8(18, 44, 94)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_save(_panel_frame(), "panel_frame")
	_save(_panel_small(), "panel_small")
	_save(_button(0), "btn_normal")
	_save(_button(1), "btn_hover")
	_save(_button(2), "btn_pressed")
	_save(_meter_bg(), "meter_bg")
	print("UI KIT OK")
	quit()


func _save(img: Image, name: String) -> void:
	img.save_png("%s/%s.png" % [OUT, name])
	print("wrote ", name, ".png ", img.get_width(), "x", img.get_height())


# ------------------------------------------------------------------
# drawing primitives
# ------------------------------------------------------------------
func _fill(img: Image, r: Rect2i, col: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			img.set_pixel(x, y, col)


func _vgrad(img: Image, r: Rect2i, top: Color, bottom: Color) -> void:
	for y in range(r.position.y, r.end.y):
		var t := float(y - r.position.y) / maxf(float(r.size.y - 1), 1.0)
		var col := top.lerp(bottom, t)
		for x in range(r.position.x, r.end.x):
			img.set_pixel(x, y, col)


func _outline(img: Image, r: Rect2i, col: Color) -> void:
	for x in range(r.position.x, r.end.x):
		img.set_pixel(x, r.position.y, col)
		img.set_pixel(x, r.end.y - 1, col)
	for y in range(r.position.y, r.end.y):
		img.set_pixel(r.position.x, y, col)
		img.set_pixel(r.end.x - 1, y, col)


func _steel(img: Image, r: Rect2i) -> void:
	## brushed-steel band: gradient + top highlight + bottom shadow
	_vgrad(img, r, STEEL_TOP, STEEL_BOT)
	for x in range(r.position.x, r.end.x):
		img.set_pixel(x, r.position.y, STEEL_HI)
		img.set_pixel(x, r.end.y - 1, Color8(28, 32, 42))


func _rivet(img: Image, cx: int, cy: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if dx * dx + dy * dy <= 4:
				img.set_pixel(cx + dx, cy + dy, Color8(30, 34, 44))
	img.set_pixel(cx, cy, Color8(52, 58, 72))
	img.set_pixel(cx - 1, cy - 1, STEEL_HI)


# ------------------------------------------------------------------
# components
# ------------------------------------------------------------------
func _panel_frame() -> Image:
	## Ornate frame, 96x96, 9-slice margins 30. Metallic band, cyan inner
	## glow line, navy interior, riveted corner plates.
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	_outline(img, Rect2i(0, 0, 96, 96), OUTLINE)
	_outline(img, Rect2i(1, 1, 94, 94), OUTLINE)
	_steel(img, Rect2i(2, 2, 92, 92))
	# interior
	_vgrad(img, Rect2i(12, 12, 72, 72), NAVY_TOP, NAVY_BOT)
	_outline(img, Rect2i(12, 12, 72, 72), OUTLINE)
	_outline(img, Rect2i(13, 13, 70, 70), Color(CYAN.r, CYAN.g, CYAN.b, 0.45))
	# faint interior top sheen
	_fill(img, Rect2i(14, 14, 68, 6), Color(1, 1, 1, 0.03))
	# corner plates with rivets
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var px := 0 if c.x == 0 else 96 - 24
		var py := 0 if c.y == 0 else 96 - 24
		var plate := Rect2i(px, py, 24, 24)
		_steel(img, plate)
		_outline(img, plate, OUTLINE)
		_rivet(img, px + (7 if c.x == 0 else 17), py + (7 if c.y == 0 else 17))
	return img


func _panel_small() -> Image:
	## Thin steel frame, 48x48, margins 12 — for tiles, rows, sub-panels.
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	_outline(img, Rect2i(0, 0, 48, 48), OUTLINE)
	_steel(img, Rect2i(1, 1, 46, 46))
	_vgrad(img, Rect2i(6, 6, 36, 36), NAVY_TOP, NAVY_BOT)
	_outline(img, Rect2i(6, 6, 36, 36), OUTLINE)
	_outline(img, Rect2i(7, 7, 34, 34), Color(CYAN.r, CYAN.g, CYAN.b, 0.3))
	return img


func _button(state: int) -> Image:
	## Glossy blue button, 64x44, margins 14/14/14/16.
	## state: 0 normal, 1 hover (cyan glow), 2 pressed (dark, gloss gone)
	var img := Image.create(64, 44, false, Image.FORMAT_RGBA8)
	if state == 1:
		# outer cyan glow
		_outline(img, Rect2i(0, 0, 64, 44), Color(CYAN.r, CYAN.g, CYAN.b, 0.35))
		_outline(img, Rect2i(1, 1, 62, 42), Color(CYAN.r, CYAN.g, CYAN.b, 0.7))
	else:
		_outline(img, Rect2i(0, 0, 64, 44), OUTLINE)
		_outline(img, Rect2i(1, 1, 62, 42), OUTLINE)
	_steel(img, Rect2i(2, 2, 60, 40))
	var body := Rect2i(5, 5, 54, 34)
	match state:
		0:
			_vgrad(img, body, BLUE_MID, BLUE_BOT)
			_vgrad(img, Rect2i(5, 5, 54, 15), BLUE_TOP, BLUE_MID)  # gloss
			_fill(img, Rect2i(5, 19, 54, 1), Color(0.85, 0.95, 1.0, 0.25))
		1:
			_vgrad(img, body, BLUE_MID.lightened(0.15), BLUE_BOT.lightened(0.1))
			_vgrad(img, Rect2i(5, 5, 54, 15), BLUE_TOP.lightened(0.2), BLUE_MID.lightened(0.15))
			_fill(img, Rect2i(5, 19, 54, 1), Color(0.9, 0.98, 1.0, 0.4))
		2:
			_vgrad(img, body, BLUE_BOT, BLUE_MID.darkened(0.2))
			_fill(img, Rect2i(5, 5, 54, 2), Color(0, 0, 0, 0.4))  # inner shadow
	_outline(img, body, OUTLINE)
	return img


func _meter_bg() -> Image:
	## Inset trough, 32x20, margins 6.
	var img := Image.create(32, 20, false, Image.FORMAT_RGBA8)
	_outline(img, Rect2i(0, 0, 32, 20), OUTLINE)
	_steel(img, Rect2i(1, 1, 30, 18))
	_vgrad(img, Rect2i(3, 3, 26, 14), Color8(4, 7, 13), Color8(12, 20, 34))
	_fill(img, Rect2i(3, 3, 26, 2), Color(0, 0, 0, 0.5))  # inset shadow
	_outline(img, Rect2i(3, 3, 26, 14), OUTLINE)
	return img
