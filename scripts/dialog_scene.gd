extends Control
## First-meeting conversation overlay — full-screen, modal. The rescued
## crew member stands waist-up on the right while a sci-panel dialog box
## plays the exchange typewriter-style. After the last line the whole
## overlay fades to solid black and emits finished(); the host scene
## swaps scenes under the cover. No motion — alpha fades only (the
## captain gets motion-sick).

signal finished()

const CrewDialogs := preload("res://scripts/crew_dialogs.gd")

const TYPE_SPEED := 45.0        # chars / sec
const FIGURE_FADE := 0.4
const FADE_OUT := 0.9
const FADE_HOLD := 0.3
const MARGIN_X := 90.0
const TEXT_SIZE := 13
const LINE_H := 18.0

# characters whose figure art faces AWAY from the player's side —
# mirror them so the two are actually talking to each other
const FLIP := {"HALE": true, "MIRA": true}

var _font: Font = ThemeDB.fallback_font
var _who := ""
var _lines: Array = []
var _idx := 0
var _chars := 0.0
var _t := 0.0                   # time since start() — figure fade-in
var _figure: Texture2D = null
var _player: Texture2D = null   # the captain, back view, left side
var _fading_out := false
var _fade_t := 0.0
var _done := false              # finished() already emitted


func _ready() -> void:
	# anchors AND offsets — anchors alone leave the control 0x0 (unclickable)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 300
	visible = false


func start(char_name: String) -> void:
	_who = char_name
	_lines = []
	var dialogs: Dictionary = CrewDialogs.DIALOGS
	if dialogs.has(char_name):
		_lines = dialogs[char_name]
	_figure = load("res://assets/sprites/crew/" + char_name.to_lower() + "_figure.png")
	if _player == null:
		_player = load("res://assets/sprites/crew/player_figure.png")
	_idx = 0
	_chars = 0.0
	_t = 0.0
	_fading_out = false
	_fade_t = 0.0
	_done = false
	visible = true
	if _lines.is_empty():
		_begin_fade_out()   # nothing to say — fade straight through
	queue_redraw()


func _begin_fade_out() -> void:
	if _fading_out:
		return
	_fading_out = true
	_fade_t = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _fading_out:
		_fade_t += delta
		if not _done and _fade_t >= FADE_OUT + FADE_HOLD:
			_done = true
			finished.emit()   # still solid black — host swaps scene under cover
	else:
		_chars += delta * TYPE_SPEED
	queue_redraw()


func _advance() -> void:
	if _fading_out or _lines.is_empty():
		return
	var text := str((_lines[_idx] as Dictionary).get("text", ""))
	if int(_chars) < text.length():
		_chars = float(text.length())   # finish the reveal
	elif _idx < _lines.size() - 1:
		_idx += 1
		_chars = 0.0
	else:
		_begin_fade_out()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				_begin_fade_out()   # skip the whole conversation
			elif event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
				_advance()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_advance()
		accept_event()


func _wrap(text: String, width: float) -> PackedStringArray:
	# draw_string doesn't wrap — split into lines that fit `width`
	var out := PackedStringArray()
	var cur := ""
	for word in text.split(" "):
		var trial := word if cur == "" else cur + " " + word
		if cur != "" and _font.get_string_size(trial,
				HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x > width:
			out.append(cur)
			cur = word
		else:
			cur = trial
	if cur != "":
		out.append(cur)
	return out


func _draw() -> void:
	var vp := get_viewport_rect().size
	var ac := UITheme.ACCENT

	# near-black dim — the scene behind vanishes
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.01, 0.03, 0.82))

	# who's speaking? the active side draws bright, the listener dims a touch
	var speaking_you := false
	if not _lines.is_empty() and _idx < _lines.size():
		speaking_you = str((_lines[_idx] as Dictionary).get("who", "")) == "YOU"
	var fade := clampf(_t / FIGURE_FADE, 0.0, 1.0)

	# the captain — back view, LEFT side, a little larger (nearer the camera)
	if _player != null:
		var pts := _player.get_size()
		if pts.y > 0.0:
			var ps := vp.y * 0.96 / pts.y
			var pdsz := pts * ps
			var ppos := Vector2(56.0, vp.y - pdsz.y)
			var pcol := Color(1, 1, 1, fade) if speaking_you \
				else Color(0.62, 0.66, 0.74, fade)
			draw_texture_rect(_player, Rect2(ppos, pdsz), false, pcol)

	# character figure, right side, bottom-anchored, ~92% of screen height;
	# the dialog box intentionally covers the lower half (waist-up framing).
	# FLIP mirrors art that faces away from the conversation.
	if _figure != null:
		var ts := _figure.get_size()
		if ts.y > 0.0:
			var s := vp.y * 0.92 / ts.y
			var dsz := ts * s
			var pos := Vector2(vp.x - 120.0 - dsz.x, vp.y - dsz.y)
			var ccol := Color(0.62, 0.66, 0.74, fade) if speaking_you \
				else Color(1, 1, 1, fade)
			if FLIP.get(_who, false):
				# mirror around the figure's own span (negative-size rects
				# don't reposition — use a transform)
				draw_set_transform(Vector2(pos.x + dsz.x, pos.y), 0.0, Vector2(-1, 1))
				draw_texture_rect(_figure, Rect2(Vector2.ZERO, dsz), false, ccol)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture_rect(_figure, Rect2(pos, dsz), false, ccol)

	# dialog box — sci panel over the lower third
	var box_h := vp.y * 0.34
	var box := Rect2(MARGIN_X, vp.y - box_h - 20.0, vp.x - MARGIN_X * 2.0, box_h)
	UITheme.draw_sci_panel(self, box, ac)

	if not _lines.is_empty() and _idx < _lines.size():
		var line: Dictionary = _lines[_idx]
		var speaker := str(line.get("who", ""))
		var text := str(line.get("text", ""))
		var px := box.position.x + 26.0
		var text_w := box.size.x - 52.0

		# speaker name plate + divider
		draw_string(_font, Vector2(px, box.position.y + 30.0), speaker,
			HORIZONTAL_ALIGNMENT_LEFT, 260, 12, ac)
		draw_line(Vector2(px, box.position.y + 38.0),
			Vector2(px + 150.0, box.position.y + 38.0),
			Color(ac.r, ac.g, ac.b, 0.35), 1.0)

		# typewriter body — wrap the FULL text so lines never reflow mid-reveal
		var wrapped := _wrap(text, text_w)
		var remain := int(_chars)
		var y := box.position.y + 62.0
		for wl in wrapped:
			if remain <= 0:
				break
			draw_string(_font, Vector2(px, y),
				wl.substr(0, mini(remain, wl.length())),
				HORIZONTAL_ALIGNMENT_LEFT, text_w, TEXT_SIZE, UITheme.TEXT)
			remain -= wl.length() + 1   # +1 for the space the wrap consumed
			y += LINE_H

		# "more" pulse once the line is fully revealed (alpha sine — no motion)
		if int(_chars) >= text.length():
			var pa := 0.35 + 0.45 * (0.5 + 0.5 * sin(_t * 4.0))
			draw_string(_font, Vector2(box.end.x - 34.0, box.end.y - 22.0), "▼",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(ac.r, ac.g, ac.b, pa))

	UITheme.draw_hints(self, Vector2(box.position.x + box.size.x * 0.5, box.end.y - 6.0),
		[["Space", "next"], ["Esc", "skip"]], _font, 9)

	# fade to solid black over everything; held there while the host swaps scene
	if _fading_out:
		var a := clampf(_fade_t / FADE_OUT, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, a))
