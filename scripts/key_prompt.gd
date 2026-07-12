extends Control
## Centered "press KEY to X" world prompt with the key drawn as a keycap.
## Drop-in replacement for the old prompt Labels: set text with set_prompt(),
## fade it via `modulate.a` exactly as before.
## Format: segments separated by "·"; in each segment a leading short token
## followed by 2+ spaces becomes a keycap ("E   Talk to HALE  ·  I   check ID"
## renders two keycaps). A segment with no key token is plain text.

var y_from_bottom := 110.0
var from_top := -1.0    # >= 0: anchor the prompt this far from the TOP instead
var _parts: Array = []  # [{key, text}]
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_prompt(s: String) -> void:
	_parts = []
	for seg in s.split("·"):
		var part := str(seg).strip_edges()
		if part == "":
			continue
		# leading key token: 1-5 chars, then a run of 2+ spaces
		var key := ""
		var text := part
		var idx := part.find("  ")
		if idx > 0 and idx <= 5:
			key = part.substr(0, idx).strip_edges()
			text = part.substr(idx).strip_edges()
		_parts.append({"key": key, "text": text})
	queue_redraw()


func _draw() -> void:
	if _parts.is_empty():
		return
	var vp := get_viewport_rect().size
	var size := 13
	var cy := from_top if from_top >= 0.0 else vp.y - y_from_bottom
	const SEG_GAP := 22.0
	# measure the full strip so it stays centered
	var total := 0.0
	for p in _parts:
		if p["key"] != "":
			total += UITheme.key_width(p["key"], _font, size) + 9.0
		total += _font.get_string_size(p["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	total += SEG_GAP * (_parts.size() - 1)
	var x := vp.x * 0.5 - total * 0.5
	for i in _parts.size():
		var p: Dictionary = _parts[i]
		if p["key"] != "":
			UITheme.draw_key(self, Vector2(x, cy - (size + 9.0) * 0.5), p["key"], _font, size)
			x += UITheme.key_width(p["key"], _font, size) + 9.0
		draw_string(_font, Vector2(x, cy + size * 0.36), p["text"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.72, 0.92, 1.0))
		x += _font.get_string_size(p["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if i < _parts.size() - 1:
			draw_circle(Vector2(x + SEG_GAP * 0.5, cy), 1.6, Color(0.72, 0.92, 1.0, 0.45))
			x += SEG_GAP
