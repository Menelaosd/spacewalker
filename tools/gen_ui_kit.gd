extends SceneTree
## UI kit texture generator v3 — lighter, ROUNDED, shiny.
## Rounded rects are rendered from a signed-distance function with soft
## anti-aliased edges, so panels and buttons have genuinely smooth corners.
##   godot --headless --path . -s res://tools/gen_ui_kit.gd

const OUT := "res://assets/ui"

# palette v4 — white-silver rims, bright holo-glass interiors, vivid blues
const NAVY_TOP := Color(0.22, 0.30, 0.44, 0.93)
const NAVY_BOT := Color(0.10, 0.15, 0.24, 0.95)
const STEEL_HI := Color8(248, 252, 255)
const STEEL_TOP := Color8(208, 219, 235)
const STEEL_BOT := Color8(132, 146, 168)
const CYAN := Color8(150, 232, 255)
const BLUE_TOP := Color8(150, 200, 250)
const BLUE_MID := Color8(80, 140, 215)
const BLUE_BOT := Color8(40, 84, 155)


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


func _rr_sdf(p: Vector2, rect: Rect2, r: float) -> float:
	## Signed distance to a rounded rectangle (negative = inside).
	var q := (p - rect.get_center()).abs() - rect.size * 0.5 + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() \
		+ minf(maxf(q.x, q.y), 0.0) - r


func _vmix(top: Color, bottom: Color, rect: Rect2, y: float) -> Color:
	var t := clampf((y - rect.position.y) / maxf(rect.size.y - 1.0, 1.0), 0.0, 1.0)
	return top.lerp(bottom, t)


## Paints a rounded panel: steel rim -> hairline glow -> interior gradient
## with a gloss band. Everything soft-edged via the SDF.
func _rounded_panel(size: Vector2i, outer_r: float, rim: float,
		hairline: Color, navy_top: Color, navy_bot: Color,
		gloss := 0.06, rim_top := STEEL_TOP, rim_bot := STEEL_BOT) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var outer := Rect2(Vector2(1, 1), Vector2(size) - Vector2(2, 2))
	var inner := outer.grow(-rim)
	var inner_r := maxf(outer_r - rim, 2.0)
	for y in size.y:
		for x in size.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var d_out := _rr_sdf(p, outer, outer_r)
			if d_out > 0.75:
				continue
			var edge_a := clampf(0.75 - d_out, 0.0, 1.0)
			var d_in := _rr_sdf(p, inner, inner_r)
			var col: Color
			if d_in < 0.0:
				col = _vmix(navy_top, navy_bot, inner, p.y)
				# gloss band across the upper quarter
				var gt := (p.y - inner.position.y) / inner.size.y
				if gt < 0.28:
					col = col.lerp(Color(1, 1, 1, col.a), gloss * (1.0 - gt / 0.28))
				# cyan hairline hugging the rim
				if d_in > -1.6:
					col = col.lerp(hairline, clampf((d_in + 1.6) / 1.6, 0.0, 1.0) * hairline.a)
			else:
				col = _vmix(rim_top, rim_bot, outer, p.y)
				# rim top highlight / bottom shade
				if d_out > -1.5:
					var t := clampf((d_out + 1.5) / 1.5, 0.0, 1.0)
					col = col.lerp(STEEL_HI if p.y < size.y * 0.5 else Color8(40, 46, 58), t * 0.8)
			col.a *= edge_a
			img.set_pixel(x, y, col)
	return img


func _panel_frame() -> Image:
	return _rounded_panel(Vector2i(64, 64), 12.0, 3.0,
		Color(CYAN.r, CYAN.g, CYAN.b, 0.7), NAVY_TOP, NAVY_BOT, 0.12)


func _panel_small() -> Image:
	return _rounded_panel(Vector2i(32, 32), 8.0, 1.6,
		Color(CYAN.r, CYAN.g, CYAN.b, 0.4), NAVY_TOP, NAVY_BOT, 0.09)


func _button(state: int) -> Image:
	match state:
		1:   # hover — brighter body, cyan rim
			return _rounded_panel(Vector2i(48, 36), 9.0, 2.0,
				Color(CYAN.r, CYAN.g, CYAN.b, 0.65),
				Color(BLUE_TOP.lightened(0.15).r, BLUE_TOP.lightened(0.15).g,
					BLUE_TOP.lightened(0.15).b, 1.0),
				Color(BLUE_BOT.lightened(0.08).r, BLUE_BOT.lightened(0.08).g,
					BLUE_BOT.lightened(0.08).b, 1.0),
				0.3, STEEL_HI, Color8(70, 150, 200))
		2:   # pressed — darker, no gloss
			return _rounded_panel(Vector2i(48, 36), 9.0, 2.0,
				Color(CYAN.r, CYAN.g, CYAN.b, 0.3),
				Color(BLUE_BOT.r, BLUE_BOT.g, BLUE_BOT.b, 1.0),
				Color(BLUE_MID.darkened(0.25).r, BLUE_MID.darkened(0.25).g,
					BLUE_MID.darkened(0.25).b, 1.0),
				0.0)
		_:   # normal — glossy blue
			return _rounded_panel(Vector2i(48, 36), 9.0, 2.0,
				Color(CYAN.r, CYAN.g, CYAN.b, 0.35),
				Color(BLUE_TOP.r, BLUE_TOP.g, BLUE_TOP.b, 1.0),
				Color(BLUE_BOT.r, BLUE_BOT.g, BLUE_BOT.b, 1.0),
				0.26)


func _meter_bg() -> Image:
	return _rounded_panel(Vector2i(24, 14), 5.0, 1.2,
		Color(1, 1, 1, 0.10),
		Color(0.02, 0.04, 0.08, 0.88), Color(0.07, 0.11, 0.18, 0.88), 0.0)
