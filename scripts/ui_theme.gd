class_name UITheme
## Shared UI look — translucent rounded panels, thin bright borders,
## warm accent on interactables. One place to tune the whole game's UI.

const ACCENT := Color(0.55, 0.9, 1.0)          # teal — info, borders
const ACCENT_WARM := Color(1.0, 0.62, 0.25)    # orange — action, highlights
const BG := Color(0.045, 0.075, 0.125, 0.88)
const BG_LIGHT := Color(0.10, 0.15, 0.22, 0.9)
const TEXT := Color(0.92, 0.95, 0.98)
const TEXT_DIM := Color(0.92, 0.95, 0.98, 0.55)


static func panel(border := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35),
		bg := BG, radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12.0)
	return sb


static func bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb


static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()

	var btn := panel(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3), BG_LIGHT, 6)
	btn.set_content_margin_all(10.0)
	var btn_hover := panel(ACCENT_WARM, Color(0.16, 0.20, 0.28, 0.95), 6)
	btn_hover.set_content_margin_all(10.0)
	var btn_pressed := panel(ACCENT_WARM, Color(0.22, 0.16, 0.10, 0.95), 6)
	btn_pressed.set_content_margin_all(10.0)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("focus", "Button", btn_hover)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.85, 0.6))
	t.set_color("font_pressed_color", "Button", ACCENT_WARM)

	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_color("font_color", "Label", TEXT)
	return t
