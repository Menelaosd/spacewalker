class_name UITheme
## The game's UI design language v5 — RETROFUTURISM (user reference):
## cyan-on-black tactical HUD. Angular notched panels with accent wedges
## and tick marks, triangle-segment loaders, hazard warning banners,
## chevrons, bracket-cornered chips. All vector — crisp at any size.
## Every scene draws through these helpers; restyle here, nowhere else.

const ACCENT := Color8(74, 222, 255)           # cyan — everything
const ACCENT_DIM := Color(0.29, 0.55, 0.65)
const ACCENT_WARM := Color8(255, 205, 64)      # hazard amber
const DANGER := Color8(255, 82, 70)
const BG := Color(0.016, 0.075, 0.105, 0.92)   # panel interior
const BG_LIGHT := Color(0.035, 0.125, 0.17, 0.94)
const TEXT := Color(0.88, 0.99, 1.0)
const TEXT_DIM := Color(0.88, 0.99, 1.0, 0.6)
const CUT := 18.0                              # big corner slant
const UI_SCALE := 0.70                          # global HUD shrink factor


static func shrink(c: Control, right: bool, bottom: bool, s := UI_SCALE) -> void:
	## Scale a corner-anchored HUD panel down about the corner nearest the
	## screen edge, so it shrinks in place and stays flush to that corner.
	var ms := c.get_combined_minimum_size()
	c.pivot_offset = Vector2(ms.x if right else 0.0, ms.y if bottom else 0.0)
	c.scale = Vector2(s, s)


# ------------------------------------------------------------------
# Panels — angular, notched, decorated
# ------------------------------------------------------------------
static func panel_points(rect: Rect2, cut := CUT, notch := 7.0) -> PackedVector2Array:
	## Big 45° slant top-left, notched everywhere else.
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([
		Vector2(p.x + cut, p.y), Vector2(e.x - notch, p.y), Vector2(e.x, p.y + notch),
		Vector2(e.x, e.y - notch), Vector2(e.x - notch, e.y), Vector2(p.x, e.y),
		Vector2(p.x, p.y + cut),
	])


static func draw_sci_panel(ci: CanvasItem, rect: Rect2,
		accent := ACCENT, bg := BG) -> void:
	var pts := panel_points(rect)
	ci.draw_colored_polygon(pts, bg)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(accent.r, accent.g, accent.b, 0.9), 1.5)
	var p := rect.position
	var e := rect.end
	# solid accent wedge hugging the slant
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(p.x + 2, p.y + CUT), Vector2(p.x + CUT, p.y + 2),
		Vector2(p.x + CUT, p.y + CUT)]), Color(accent.r, accent.g, accent.b, 0.85))
	# doubled top edge segment
	ci.draw_line(Vector2(p.x + CUT + 5, p.y + 4),
		Vector2(p.x + rect.size.x * 0.55, p.y + 4),
		Color(accent.r, accent.g, accent.b, 0.3), 1.0)
	# tick marks, bottom-right
	for i in 3:
		ci.draw_line(Vector2(e.x - 12.0 - i * 8.0, e.y - 5),
			Vector2(e.x - 7.0 - i * 8.0, e.y - 5),
			Color(accent.r, accent.g, accent.b, 0.7), 2.0)
	# bottom-left accent underline
	ci.draw_line(Vector2(p.x + 4, e.y - 5), Vector2(p.x + 34, e.y - 5),
		Color(accent.r, accent.g, accent.b, 0.45), 2.0)


static func draw_sub_panel(ci: CanvasItem, rect: Rect2, accent := ACCENT) -> void:
	## Slim notched sub-panel for rows, tiles, nested boxes.
	var p := rect.position
	var e := rect.end
	var c := 8.0
	var pts := PackedVector2Array([
		Vector2(p.x + c, p.y), Vector2(e.x, p.y), Vector2(e.x, e.y - c),
		Vector2(e.x - c, e.y), Vector2(p.x, e.y), Vector2(p.x, p.y + c),
	])
	ci.draw_colored_polygon(pts, BG_LIGHT)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(accent.r, accent.g, accent.b, 0.45), 1.0)
	ci.draw_line(Vector2(p.x + 2, p.y + c), Vector2(p.x + c, p.y + 2),
		Color(accent.r, accent.g, accent.b, 0.9), 2.0)


static func draw_brackets(ci: CanvasItem, rect: Rect2, accent := ACCENT,
		arm := 9.0, pad := 3.0) -> void:
	## Bracket ticks on the four corners — the reference thumbnail frames.
	var col := Color(accent.r, accent.g, accent.b, 0.9)
	var p := rect.position - Vector2(pad, pad)
	var e := rect.end + Vector2(pad, pad)
	for corner in [
		[p, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(e.x, p.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(p.x, e.y), Vector2(1, 0), Vector2(0, -1)],
		[e, Vector2(-1, 0), Vector2(0, -1)],
	]:
		var o: Vector2 = corner[0]
		ci.draw_line(o, o + (corner[1] as Vector2) * arm, col, 1.6)
		ci.draw_line(o, o + (corner[2] as Vector2) * arm, col, 1.6)


static func draw_header(ci: CanvasItem, pos: Vector2, text: String,
		font: Font, size := 19, accent := ACCENT, width := 200.0) -> void:
	ci.draw_string(font, pos + Vector2(1, 1), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6))
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, TEXT)
	var y := pos.y + 9.0
	ci.draw_line(Vector2(pos.x, y), Vector2(pos.x + width, y),
		Color(accent.r, accent.g, accent.b, 0.25), 1.0)
	ci.draw_line(Vector2(pos.x, y), Vector2(pos.x + width * 0.45, y),
		Color(accent.r, accent.g, accent.b, 1.0), 2.0)
	# end chevron + block tick
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x + width * 0.45 + 2, y - 3), Vector2(pos.x + width * 0.45 + 8, y),
		Vector2(pos.x + width * 0.45 + 2, y + 3)]),
		Color(accent.r, accent.g, accent.b, 1.0))
	ci.draw_rect(Rect2(pos.x + width - 10, y - 2, 10, 4),
		Color(accent.r, accent.g, accent.b, 0.5))


static func draw_headline(ci: CanvasItem, rect: Rect2, text: String,
		font: Font, size := 15) -> void:
	## Slanted tech banner with striped end caps.
	var cy := rect.get_center().y
	var sk := 10.0
	var plate := PackedVector2Array([
		Vector2(rect.position.x + sk, rect.position.y), Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x - sk, rect.end.y), Vector2(rect.position.x, rect.end.y)])
	ci.draw_colored_polygon(plate, Color(0.02, 0.09, 0.13, 0.95))
	var outline := plate.duplicate()
	outline.append(plate[0])
	ci.draw_polyline(outline, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.9), 1.4)
	# striped caps
	for i in 3:
		var x0 := rect.position.x + sk + 6.0 + i * 6.0
		ci.draw_line(Vector2(x0, rect.position.y + 4), Vector2(x0 - 5, rect.end.y - 4),
			Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.8), 2.0)
		var x1 := rect.end.x - sk - 6.0 - i * 6.0
		ci.draw_line(Vector2(x1, rect.position.y + 4), Vector2(x1 + 5, rect.end.y - 4),
			Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.8), 2.0)
	ci.draw_string(font, Vector2(rect.position.x, cy + size * 0.36), text,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, TEXT)


static func draw_warning_banner(ci: CanvasItem, rect: Rect2, text: String,
		font: Font, col := ACCENT_WARM, size := 13) -> void:
	## Center label with hazard-stripe wings, like the reference WARNING bar.
	var cy := rect.get_center().y
	var label_w := maxf(rect.size.x * 0.4,
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 24.0)
	var lx := rect.get_center().x - label_w * 0.5
	# stripe wings
	for side in [[rect.position.x, lx - 8.0], [lx + label_w + 8.0, rect.end.x]]:
		var x: float = side[0]
		while x < float(side[1]):
			ci.draw_line(Vector2(x, rect.end.y - 2), Vector2(x + 6, rect.position.y + 2),
				Color(col.r, col.g, col.b, 0.75), 2.5)
			x += 11.0
	# label plate
	ci.draw_rect(Rect2(lx, rect.position.y, label_w, rect.size.y), Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(lx, rect.position.y, label_w, rect.size.y),
		Color(col.r, col.g, col.b, 0.95), false, 1.4)
	ci.draw_string(font, Vector2(lx, cy + size * 0.36), text,
		HORIZONTAL_ALIGNMENT_CENTER, label_w, size, col)


static func draw_chevrons(ci: CanvasItem, pos: Vector2, count: int,
		size: float, color: Color, t := 0.0) -> void:
	## Animated ">>>" flow arrows.
	for i in count:
		var a := 0.25 + 0.75 * maxf(sin(t * 3.0 - float(i) * 0.7), 0.0)
		var x := pos.x + float(i) * size * 0.8
		ci.draw_polyline(PackedVector2Array([
			Vector2(x, pos.y - size * 0.5), Vector2(x + size * 0.55, pos.y),
			Vector2(x, pos.y + size * 0.5)]),
			Color(color.r, color.g, color.b, a), 2.5)


# ------------------------------------------------------------------
# Meters & gauges
# ------------------------------------------------------------------
static func draw_meter(ci: CanvasItem, rect: Rect2, frac: float,
		color: Color, danger := false) -> void:
	## Zigzag triangle-segment loader, like the reference 91% bar.
	frac = clampf(frac, 0.0, 1.0)
	var col := DANGER if danger else color
	ci.draw_rect(rect, Color(0.0, 0.03, 0.05, 0.75))
	ci.draw_rect(rect, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35), false, 1.0)
	var inner := rect.grow(-3.0)
	var tw := 8.0
	var n := int(inner.size.x / tw)
	var lit := int(roundf(float(n) * frac))
	for i in n:
		var x := inner.position.x + float(i) * tw
		var up := i % 2 == 0
		var tri: PackedVector2Array
		if up:
			tri = PackedVector2Array([
				Vector2(x, inner.end.y), Vector2(x + tw - 1, inner.end.y),
				Vector2(x + tw * 0.5, inner.position.y)])
		else:
			tri = PackedVector2Array([
				Vector2(x, inner.position.y), Vector2(x + tw - 1, inner.position.y),
				Vector2(x + tw * 0.5, inner.end.y)])
		if i < lit:
			ci.draw_colored_polygon(tri,
				col.lightened(0.3) if i == lit - 1 else col)
		else:
			ci.draw_colored_polygon(tri, Color(1, 1, 1, 0.06))


static func draw_ring_gauge(ci: CanvasItem, center: Vector2, radius: float,
		frac: float, color: Color, font: Font, show_pct := true) -> void:
	frac = clampf(frac, 0.0, 1.0)
	ci.draw_arc(center, radius, 0, TAU, 64, Color(0, 0, 0, 0.5), 6.0)
	ci.draw_arc(center, radius + 3.0, 0, TAU, 64,
		Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.15), 1.0)
	# tick ring
	for i in 12:
		var a := TAU * float(i) / 12.0
		ci.draw_line(center + Vector2.from_angle(a) * (radius - 4.0),
			center + Vector2.from_angle(a) * (radius - 7.0),
			Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3), 1.0)
	if frac > 0.005:
		var a0 := -PI / 2.0
		var a1 := a0 + TAU * frac
		ci.draw_arc(center, radius, a0, a1, 64,
			Color(color.r, color.g, color.b, 0.3), 10.0)
		ci.draw_arc(center, radius, a0, a1, 64, color, 4.0)
		ci.draw_arc(center, radius, a0, a1, 64, Color(1, 1, 1, 0.9), 1.5)
		var head := center + Vector2.from_angle(a1) * radius
		ci.draw_circle(head, 3.0, Color(1, 1, 1, 0.95))
	if show_pct:
		ci.draw_string(font, center + Vector2(-radius, 5.0),
			"%d%%" % int(frac * 100.0), HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0, 13, color.lightened(0.3))


static func draw_key_chip(ci: CanvasItem, center: Vector2, key: String,
		font: Font, accent := ACCENT) -> void:
	var r := Rect2(center - Vector2(10, 10), Vector2(20, 20))
	ci.draw_rect(r, Color(accent.r, accent.g, accent.b, 0.12))
	draw_brackets(ci, r, accent, 6.0, 1.0)
	ci.draw_string(font, Vector2(r.position.x, center.y + 5.0), key,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, TEXT)


# ------------------------------------------------------------------
# Keycaps — every on-screen key prompt renders as a little keyboard cap.
# One source of truth so controller glyphs can slot in here later.
# ------------------------------------------------------------------
static func key_width(label: String, font: Font, size := 11) -> float:
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return maxf(tw + 12.0, size + 9.0)


static func draw_key(ci: CanvasItem, pos: Vector2, label: String,
		font: Font, size := 11, accent := ACCENT) -> float:
	## Draw a keycap with its top-left at `pos`; returns the cap's width.
	var h := size + 9.0
	var w := key_width(label, font, size)
	var r := Rect2(pos, Vector2(w, h))
	ci.draw_rect(r, Color(0.06, 0.14, 0.19, 0.96))
	ci.draw_rect(r, Color(accent.r, accent.g, accent.b, 0.85), false, 1.0)
	# top bevel highlight
	ci.draw_line(r.position + Vector2(2, 2), Vector2(r.end.x - 2, r.position.y + 2),
		Color(accent.r, accent.g, accent.b, 0.4), 1.0)
	ci.draw_string(font, Vector2(pos.x, pos.y + h * 0.5 + size * 0.36), label,
		HORIZONTAL_ALIGNMENT_CENTER, w, size, TEXT)
	return w


static func hints_width(items: Array, font: Font, size := 11, gap := 15.0) -> float:
	var total := 0.0
	for it in items:
		total += key_width(it[0], font, size) + 5.0 \
			+ font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + gap
	return maxf(total - gap, 0.0)


static func draw_hints_at(ci: CanvasItem, pos: Vector2, items: Array,
		font: Font, size := 11, dim := TEXT_DIM) -> float:
	## Left-aligned row of "[cap] label" pairs starting at pos (row top-left);
	## returns the total width. items = [[key, label], ...].
	var gap := 15.0
	var kh := size + 9.0
	var x := pos.x
	for it in items:
		var kw := draw_key(ci, Vector2(x, pos.y), it[0], font, size)
		x += kw + 5.0
		ci.draw_string(font, Vector2(x, pos.y + kh * 0.5 + size * 0.36), it[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, dim)
		x += font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + gap
	return maxf(x - gap - pos.x, 0.0)


static func draw_hints(ci: CanvasItem, center: Vector2, items: Array,
		font: Font, size := 11, dim := TEXT_DIM) -> void:
	## Centered row of "[cap] label" pairs.
	var kh := size + 9.0
	var x := center.x - hints_width(items, font, size) * 0.5
	draw_hints_at(ci, Vector2(x, center.y - kh * 0.5), items, font, size, dim)


static func draw_icon(ci: CanvasItem, tex: Texture2D, center: Vector2,
		size := 22.0, color := ACCENT) -> void:
	## SVG icon, tinted. Icons are white-stroke so modulate = color.
	ci.draw_texture_rect(tex, Rect2(center - Vector2(size, size) * 0.5,
		Vector2(size, size)), false, color)


# ------------------------------------------------------------------
# Godot Theme for real Controls
# ------------------------------------------------------------------
static func _btn_box(border: Color, bg: Color, glow := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.skew = Vector2(0.25, 0.0)
	sb.set_content_margin_all(10.0)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	if glow > 0.0:
		sb.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, glow)
		sb.shadow_size = 6
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button",
		_btn_box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6), Color(0.03, 0.13, 0.18, 0.92)))
	t.set_stylebox("hover", "Button",
		_btn_box(ACCENT, Color(0.05, 0.22, 0.30, 0.95), 0.3))
	t.set_stylebox("pressed", "Button",
		_btn_box(ACCENT, Color(0.02, 0.08, 0.11, 0.95)))
	t.set_stylebox("focus", "Button",
		_btn_box(ACCENT, Color(0.05, 0.22, 0.30, 0.95), 0.3))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)

	var panel := StyleBoxFlat.new()
	panel.bg_color = BG
	panel.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)
	panel.set_border_width_all(1)
	panel.skew = Vector2(0.12, 0.0)
	panel.set_content_margin_all(12.0)
	panel.content_margin_left = 18.0
	panel.content_margin_right = 18.0
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", TEXT)
	return t
