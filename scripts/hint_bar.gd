extends Control
## Bottom-left control-hint strip, rendered as keyboard keycaps.
## Set `items` (from Keymap.hint(ctx)) before or after adding to the tree.

var items: Array = []:
	set(v):
		items = v
		queue_redraw()

var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var vp := get_viewport_rect().size
	UITheme.draw_hints_at(self, Vector2(16.0, vp.y - 26.0), items,
		_font, 11, Color(1, 1, 1, 0.5))
