class_name UITheme
## The game's UI design language — "Nemesis kit": metallic beveled frames
## with riveted corner plates (baked textures from tools/gen_ui_kit.gd),
## glossy buttons, segmented meters, glowing ring gauges.
## Every scene draws through these helpers; restyle here, nowhere else.

const ACCENT := Color(0.55, 0.9, 1.0)          # cyan — info, borders
const ACCENT_WARM := Color(1.0, 0.62, 0.25)    # orange — action, highlights
const DANGER := Color(1.0, 0.32, 0.28)
const BG := Color(0.04, 0.07, 0.12, 0.86)
const BG_LIGHT := Color(0.10, 0.15, 0.22, 0.9)
const TEXT := Color(0.92, 0.95, 0.98)
const TEXT_DIM := Color(0.92, 0.95, 0.98, 0.55)
const CUT := 12.0

const TEX_FRAME := preload("res://assets/ui/panel_frame.png")
const TEX_SMALL := preload("res://assets/ui/panel_small.png")
const TEX_BTN_N := preload("res://assets/ui/btn_normal.png")
const TEX_BTN_H := preload("res://assets/ui/btn_hover.png")
const TEX_BTN_P := preload("res://assets/ui/btn_pressed.png")
const TEX_METER := preload("res://assets/ui/meter_bg.png")

static var _frame_sb: StyleBoxTexture
static var _small_sb: StyleBoxTexture
static var _meter_sb: StyleBoxTexture


static func _tex_sb(tex: Texture2D, margin: float, content := 0.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(margin)
	if content > 0.0:
		sb.set_content_margin_all(content)
	return sb


static func frame_sb() -> StyleBoxTexture:
	if _frame_sb == null:
		_frame_sb = _tex_sb(TEX_FRAME, 26.0, 24.0)
	return _frame_sb


static func small_sb() -> StyleBoxTexture:
	if _small_sb == null:
		_small_sb = _tex_sb(TEX_SMALL, 12.0, 12.0)
	return _small_sb


static func meter_sb() -> StyleBoxTexture:
	if _meter_sb == null:
		_meter_sb = _tex_sb(TEX_METER, 6.0)
	return _meter_sb


# ------------------------------------------------------------------
# Panels
# ------------------------------------------------------------------
static func cut_points(rect: Rect2, cut := CUT) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([
		Vector2(p.x + cut, p.y), Vector2(e.x, p.y), Vector2(e.x, e.y - cut),
		Vector2(e.x - cut, e.y), Vector2(p.x, e.y), Vector2(p.x, p.y + cut),
	])


static func draw_sci_panel(ci: CanvasItem, rect: Rect2,
		_accent := ACCENT, _bg := BG) -> void:
	## Main panel: the ornate riveted metal frame.
	frame_sb().draw(ci.get_canvas_item(), rect)


static func draw_sub_panel(ci: CanvasItem, rect: Rect2) -> void:
	## Thin steel sub-panel for tiles, rows, nested boxes.
	small_sb().draw(ci.get_canvas_item(), rect)


static func draw_header(ci: CanvasItem, pos: Vector2, text: String,
		font: Font, size := 19, accent := ACCENT, width := 200.0) -> void:
	ci.draw_string(font, pos + Vector2(1, 1), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.5))
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, TEXT)
	var y := pos.y + 10.0
	ci.draw_line(Vector2(pos.x, y), Vector2(pos.x + width, y),
		Color(accent.r, accent.g, accent.b, 0.12), 5.0)
	ci.draw_line(Vector2(pos.x, y), Vector2(pos.x + width * 0.55, y),
		Color(accent.r, accent.g, accent.b, 0.8), 1.5)


static func draw_headline(ci: CanvasItem, rect: Rect2, text: String,
		font: Font, size := 16) -> void:
	## Metal nameplate with side wings, like the reference "HEADLINE" bar.
	var cy := rect.get_center().y
	var steel := Color8(84, 93, 109)
	var steel_dark := Color8(46, 52, 64)
	for side in [-1.0, 1.0]:
		var x0 := rect.position.x if side < 0.0 else rect.end.x
		var wing := PackedVector2Array([
			Vector2(x0, cy - 5), Vector2(x0 + 30.0 * side, cy - 12),
			Vector2(x0 + 30.0 * side, cy + 12), Vector2(x0, cy + 5)])
		ci.draw_colored_polygon(wing, steel_dark)
		ci.draw_polyline(PackedVector2Array([wing[0], wing[1], wing[2], wing[3], wing[0]]),
			Color8(6, 8, 12), 1.5)
	var plate := Rect2(rect.position.x + 26, rect.position.y,
		rect.size.x - 52, rect.size.y)
	ci.draw_rect(plate, Color8(10, 17, 31))
	ci.draw_rect(Rect2(plate.position, Vector2(plate.size.x, 4)), steel)
	ci.draw_rect(Rect2(plate.position + Vector2(0, plate.size.y - 4),
		Vector2(plate.size.x, 4)), steel_dark)
	ci.draw_rect(plate, Color8(6, 8, 12), false, 1.5)
	ci.draw_string(font, Vector2(plate.position.x, cy + size * 0.36), text,
		HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, size, TEXT)
	ci.draw_line(plate.position + Vector2(8, plate.size.y - 6),
		plate.position + Vector2(plate.size.x - 8, plate.size.y - 6),
		Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5), 1.0)


# ------------------------------------------------------------------
# Meters & gauges
# ------------------------------------------------------------------
static func draw_meter(ci: CanvasItem, rect: Rect2, frac: float,
		color: Color, danger := false) -> void:
	## Segmented cell meter in an inset steel trough.
	frac = clampf(frac, 0.0, 1.0)
	var col := DANGER if danger else color
	meter_sb().draw(ci.get_canvas_item(), rect)
	var inner := rect.grow(-4.0)
	var cw := 7.0
	var gap := 2.0
	var n := int((inner.size.x + gap) / (cw + gap))
	var lit := int(roundf(float(n) * frac))
	for i in n:
		var cell := Rect2(inner.position + Vector2(float(i) * (cw + gap), 0),
			Vector2(cw, inner.size.y))
		if i < lit:
			ci.draw_rect(cell, col.darkened(0.15))
			ci.draw_rect(Rect2(cell.position, Vector2(cw, inner.size.y * 0.45)),
				col.lightened(0.3))
			if i == lit - 1:
				ci.draw_rect(cell.grow(1.0), Color(col.r, col.g, col.b, 0.3), false, 1.5)
		else:
			ci.draw_rect(cell, Color(1, 1, 1, 0.04))


static func draw_ring_gauge(ci: CanvasItem, center: Vector2, radius: float,
		frac: float, color: Color, font: Font, show_pct := true) -> void:
	## Glowing circular gauge, like the reference 97% rings.
	frac = clampf(frac, 0.0, 1.0)
	ci.draw_arc(center, radius, 0, TAU, 64, Color(0, 0, 0, 0.55), 9.0)
	ci.draw_arc(center, radius + 4.0, 0, TAU, 64, Color(1, 1, 1, 0.08), 1.0)
	ci.draw_arc(center, radius - 4.0, 0, TAU, 64, Color(1, 1, 1, 0.08), 1.0)
	if frac > 0.005:
		var a0 := -PI / 2.0
		var a1 := a0 + TAU * frac
		ci.draw_arc(center, radius, a0, a1, 64,
			Color(color.r, color.g, color.b, 0.22), 15.0)   # outer glow
		ci.draw_arc(center, radius, a0, a1, 64, color, 6.0)
		ci.draw_arc(center, radius, a0, a1, 64, color.lightened(0.45), 2.0)
		var head := center + Vector2.from_angle(a1) * radius
		ci.draw_circle(head, 3.5, Color(1, 1, 1, 0.95))
		ci.draw_circle(head, 6.5, Color(color.r, color.g, color.b, 0.35))
	if show_pct:
		ci.draw_string(font, center + Vector2(-radius, 5.0),
			"%d%%" % int(frac * 100.0), HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0, 13, color.lightened(0.3))


static func draw_key_chip(ci: CanvasItem, center: Vector2, key: String,
		font: Font, accent := ACCENT) -> void:
	var r := Rect2(center - Vector2(11, 11), Vector2(22, 22))
	ci.draw_rect(r, Color(accent.r, accent.g, accent.b, 0.14))
	ci.draw_rect(r, Color(accent.r, accent.g, accent.b, 0.9), false, 1.4)
	ci.draw_string(font, Vector2(r.position.x, center.y + 5.5), key,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, TEXT)


# ------------------------------------------------------------------
# Godot Theme for real Controls
# ------------------------------------------------------------------
static func make_theme() -> Theme:
	var t := Theme.new()
	var bn := _tex_sb(TEX_BTN_N, 14.0)
	var bh := _tex_sb(TEX_BTN_H, 14.0)
	var bp := _tex_sb(TEX_BTN_P, 14.0)
	for sb: StyleBoxTexture in [bn, bh, bp]:
		sb.content_margin_left = 20.0
		sb.content_margin_right = 20.0
		sb.content_margin_top = 10.0
		sb.content_margin_bottom = 12.0
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("focus", "Button", bh)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(0.8, 0.95, 1.0))
	t.set_color("font_pressed_color", "Button", ACCENT)

	t.set_stylebox("panel", "PanelContainer", _tex_sb(TEX_SMALL, 12.0, 14.0))
	t.set_color("font_color", "Label", TEXT)
	return t
