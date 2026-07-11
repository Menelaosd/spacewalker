class_name UITheme
## The game's UI design language — "holographic cockpit".
## Cut-corner translucent panels with corner brackets, skewed buttons,
## custom meters with shine, teal info / warm-orange action accents.
## Every scene draws through these helpers; restyle here, nowhere else.

const ACCENT := Color(0.55, 0.9, 1.0)          # teal — info, borders
const ACCENT_WARM := Color(1.0, 0.62, 0.25)    # orange — action, highlights
const DANGER := Color(1.0, 0.32, 0.28)
const BG := Color(0.04, 0.07, 0.12, 0.86)
const BG_LIGHT := Color(0.10, 0.15, 0.22, 0.9)
const TEXT := Color(0.92, 0.95, 0.98)
const TEXT_DIM := Color(0.92, 0.95, 0.98, 0.55)
const CUT := 12.0                              # corner cut size


# ------------------------------------------------------------------
# Panels
# ------------------------------------------------------------------
static func cut_points(rect: Rect2, cut := CUT) -> PackedVector2Array:
	## Hexagonal panel silhouette: top-left and bottom-right corners cut.
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([
		Vector2(p.x + cut, p.y), Vector2(e.x, p.y), Vector2(e.x, e.y - cut),
		Vector2(e.x - cut, e.y), Vector2(p.x, e.y), Vector2(p.x, p.y + cut),
	])


static func draw_sci_panel(ci: CanvasItem, rect: Rect2,
		accent := ACCENT, bg := BG) -> void:
	var pts := cut_points(rect)
	ci.draw_colored_polygon(pts, bg)
	# inner top sheen
	ci.draw_rect(Rect2(rect.position + Vector2(CUT, 1), Vector2(rect.size.x - CUT * 2, 10)),
		Color(1, 1, 1, 0.035))
	# border
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(accent.r, accent.g, accent.b, 0.4), 1.2)
	# accent strip along the top edge
	ci.draw_line(rect.position + Vector2(CUT + 2, 0),
		rect.position + Vector2(CUT + 46, 0),
		Color(accent.r, accent.g, accent.b, 0.95), 2.5)
	draw_brackets(ci, rect, accent)


static func draw_brackets(ci: CanvasItem, rect: Rect2, accent := ACCENT,
		arm := 14.0, pad := 4.0) -> void:
	## The four corner brackets — the signature of the style.
	var col := Color(accent.r, accent.g, accent.b, 0.85)
	var p := rect.position - Vector2(pad, pad)
	var e := rect.end + Vector2(pad, pad)
	for corner in [
		[p, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(e.x, p.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(p.x, e.y), Vector2(1, 0), Vector2(0, -1)],
		[e, Vector2(-1, 0), Vector2(0, -1)],
	]:
		var o: Vector2 = corner[0]
		ci.draw_line(o, o + (corner[1] as Vector2) * arm, col, 2.0)
		ci.draw_line(o, o + (corner[2] as Vector2) * arm, col, 2.0)


static func draw_header(ci: CanvasItem, pos: Vector2, text: String,
		font: Font, size := 19, accent := ACCENT, width := 200.0) -> void:
	## Title text with a glowing underline.
	ci.draw_string(font, pos + Vector2(1, 1), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.5))
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, TEXT)
	var y := pos.y + 10.0
	ci.draw_line(Vector2(pos.x, y), Vector2(pos.x + width, y),
		Color(accent.r, accent.g, accent.b, 0.12), 5.0)
	ci.draw_line(Vector2(pos.x, y), Vector2(pos.x + width * 0.55, y),
		Color(accent.r, accent.g, accent.b, 0.8), 1.5)


# ------------------------------------------------------------------
# Meters — bars with ticks, shine and a glowing head
# ------------------------------------------------------------------
static func draw_meter(ci: CanvasItem, rect: Rect2, frac: float,
		color: Color, danger := false) -> void:
	frac = clampf(frac, 0.0, 1.0)
	var col := DANGER if danger else color
	# trough
	ci.draw_rect(rect, Color(0, 0, 0, 0.55))
	ci.draw_rect(rect, Color(1, 1, 1, 0.10), false, 1.0)
	# fill: base + top shine
	var w := rect.size.x * frac
	if w > 1.0:
		ci.draw_rect(Rect2(rect.position, Vector2(w, rect.size.y)), col.darkened(0.12))
		ci.draw_rect(Rect2(rect.position, Vector2(w, rect.size.y * 0.42)),
			col.lightened(0.28))
		# glowing head
		ci.draw_rect(Rect2(rect.position + Vector2(w - 2.0, 0), Vector2(2.0, rect.size.y)),
			Color(1, 1, 1, 0.85))
		ci.draw_rect(Rect2(rect.position + Vector2(w - 6.0, 0), Vector2(6.0, rect.size.y)),
			Color(col.r, col.g, col.b, 0.25))
	# quarter ticks
	for i in range(1, 4):
		var x := rect.position.x + rect.size.x * 0.25 * i
		ci.draw_line(Vector2(x, rect.position.y + 2), Vector2(x, rect.end.y - 2),
			Color(0, 0, 0, 0.35), 1.0)


static func draw_key_chip(ci: CanvasItem, center: Vector2, key: String,
		font: Font, accent := ACCENT) -> void:
	## A little keyboard-key badge, e.g. [E].
	var r := Rect2(center - Vector2(11, 11), Vector2(22, 22))
	ci.draw_rect(r, Color(accent.r, accent.g, accent.b, 0.14))
	ci.draw_rect(r, Color(accent.r, accent.g, accent.b, 0.9), false, 1.4)
	ci.draw_string(font, Vector2(r.position.x, center.y + 5.5), key,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, TEXT)


# ------------------------------------------------------------------
# Godot Theme for real Controls (buttons etc.)
# ------------------------------------------------------------------
static func _btn_box(border: Color, bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(3)
	sb.skew = Vector2(0.18, 0.0)
	sb.set_content_margin_all(11.0)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button",
		_btn_box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45), BG_LIGHT))
	t.set_stylebox("hover", "Button",
		_btn_box(ACCENT_WARM, Color(0.17, 0.21, 0.29, 0.96)))
	t.set_stylebox("pressed", "Button",
		_btn_box(ACCENT_WARM, Color(0.24, 0.17, 0.10, 0.96)))
	t.set_stylebox("focus", "Button",
		_btn_box(ACCENT_WARM, Color(0.17, 0.21, 0.29, 0.96)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.85, 0.6))
	t.set_color("font_pressed_color", "Button", ACCENT_WARM)

	var panel := StyleBoxFlat.new()
	panel.bg_color = BG
	panel.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(14.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", TEXT)
	return t
