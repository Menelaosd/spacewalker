extends Control
## Centered "press KEY to X" world prompt with the key drawn as a keycap.
## Drop-in replacement for the old prompt Labels: set text with set_prompt(),
## fade it via `modulate.a` exactly as before. A leading "KEY   rest" token
## (2+ spaces) becomes the keycap; otherwise the whole string is plain text.

var y_from_bottom := 110.0
var _key := ""
var _text := ""
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_prompt(s: String) -> void:
	var idx := s.find("   ")            # 3+ spaces separate the key from the label
	if idx > 0 and idx <= 4:
		_key = s.substr(0, idx).strip_edges()
		_text = s.substr(idx).strip_edges()
	else:
		_key = ""
		_text = s
	queue_redraw()


func _draw() -> void:
	if _text == "" and _key == "":
		return
	var vp := get_viewport_rect().size
	var size := 13
	var cy := vp.y - y_from_bottom
	var kw := 0.0
	if _key != "":
		kw = UITheme.key_width(_key, _font, size) + 9.0
	var tw := _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := vp.x * 0.5 - (kw + tw) * 0.5
	if _key != "":
		UITheme.draw_key(self, Vector2(x, cy - (size + 9.0) * 0.5), _key, _font, size)
		x += kw
	draw_string(_font, Vector2(x, cy + size * 0.36), _text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.72, 0.92, 1.0))
