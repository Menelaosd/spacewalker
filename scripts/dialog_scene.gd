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
# (verified per head: JUNO + VEGA gaze screen-right, SOLA is frontal)
const FLIP := {"HALE": true, "MIRA": true, "JUNO": true, "VEGA": true}

var _font: Font = ThemeDB.fallback_font
var _boxes := {}                # texture -> Rect2 opaque-content bbox cache
var _who := ""
var _lines: Array = []
var _idx := 0
var _chars := 0.0
var _t := 0.0                   # time since start() — figure fade-in
var _figure: Texture2D = null
var _bg: Texture2D = null       # the crew member's ship interior, full-screen
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
	# their ship's interior fills the scene — you BOARDED their wreck; no
	# space, no radar, no HUD peeking through
	_bg = load("res://assets/sprites/crew/" + char_name.to_lower() + "_inside.png")
	if _player == null:
		_player = load("res://assets/sprites/crew/player_figure.png")
	_idx = 0
	_chars = 0.0
	_t = 0.0
	_fading_out = false
	_fade_t = 0.0
	_done = false
	visible = true
	# the conversation owns the whole screen — hide every other HUD element
	# (radar, quest log, labels, banners) so nothing animates/flickers on top
	for sib in get_parent().get_children():
		if sib != self and sib is CanvasItem:
			sib.visible = false
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


func _content_box(tex: Texture2D) -> Rect2:
	## The opaque bbox of the art INSIDE its canvas. Each figure PNG pads its
	## canvas differently, so scaling by canvas height rendered every character
	## a different size — scale by what's actually drawn instead.
	if _boxes.has(tex):
		return _boxes[tex]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var minx := img.get_width()
	var maxx := 0
	var miny := img.get_height()
	var maxy := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).a > 0.05:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	var box := Rect2(minx, miny, maxi(maxx - minx, 1), maxi(maxy - miny, 1))
	_boxes[tex] = box
	return box


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

	# their ship interior fills the frame — OPAQUE (no space/radar bleed),
	# cover-fit (fill + centre-crop) and pulled darker so the figures and the
	# dialog box stay the read
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 1))
	if _bg != null:
		var bsz := _bg.get_size()
		var cover := maxf(vp.x / bsz.x, vp.y / bsz.y)
		var dsz2 := bsz * cover
		var org := (Vector2(vp.x, vp.y) - dsz2) * 0.5
		draw_texture_rect(_bg, Rect2(org, dsz2), false, Color(0.5, 0.5, 0.55))
	# soft extra dusk so the bright panels in the art never fight the text
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.01, 0.03, 0.25))

	# who's speaking? the active side draws bright, the listener dims a touch
	var speaking_you := false
	if not _lines.is_empty() and _idx < _lines.size():
		speaking_you = str((_lines[_idx] as Dictionary).get("who", "")) == "YOU"
	var fade := clampf(_t / FIGURE_FADE, 0.0, 1.0)

	# BOTH figures scale by their opaque CONTENT box (not the canvas — canvas
	# padding differs per art, which used to render every character a
	# different size) and bottom-anchor on the content's real feet.

	# the captain — back view, LEFT side, sunk below the screen bottom so he
	# reads planted (nearer the camera), never hovering
	if _player != null:
		var pbb := _content_box(_player)
		var ps := vp.y * 0.92 / pbb.size.y
		var pdsz := _player.get_size() * ps
		# sunk so his HEAD lines up with the crew's across the box (he's the
		# bigger figure — without the extra sink he towers a head above them)
		var ppos := Vector2(56.0 - pbb.position.x * ps,
			vp.y + vp.y * 0.20 - pbb.end.y * ps)
		var pcol := Color(1, 1, 1, fade) if speaking_you \
			else Color(0.62, 0.66, 0.74, fade)
		draw_texture_rect(_player, Rect2(ppos, pdsz), false, pcol)

	# character figure, right side — smaller than the captain (they stand a
	# step further back) and sunk below the bottom edge so their feet never
	# hover over the floor. FLIP mirrors art that faces away.
	if _figure != null:
		var bb := _content_box(_figure)
		var s := vp.y * 0.84 / bb.size.y
		var dsz := _figure.get_size() * s
		var ccol := Color(0.62, 0.66, 0.74, fade) if speaking_you \
			else Color(1, 1, 1, fade)
		var top := vp.y + vp.y * 0.13 - bb.end.y * s   # feet sunk off-screen
		if FLIP.get(_who, false):
			# mirror around the CONTENT span so the visible art (not the
			# padded canvas) lands right-edge at the same anchor
			var anchor := vp.x - 120.0 + bb.position.x * s
			draw_set_transform(Vector2(anchor, top), 0.0, Vector2(-1, 1))
			draw_texture_rect(_figure, Rect2(Vector2.ZERO, dsz), false, ccol)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var pos := Vector2(vp.x - 120.0 - bb.end.x * s, top)
			draw_texture_rect(_figure, Rect2(pos, dsz), false, ccol)

	# dialog box — a compact sci panel along the bottom (lines are short;
	# a third of the screen was way too much box)
	var box_h := vp.y * 0.21
	var box := Rect2(MARGIN_X * 1.4, vp.y - box_h - 24.0,
		vp.x - MARGIN_X * 2.8, box_h)
	UITheme.draw_sci_panel(self, box, ac)

	# speaker tail — a small triangle on the box's top edge pointing up at
	# whoever is talking (captain left, crew right). Static, jumps per line.
	if not _lines.is_empty() and _idx < _lines.size():
		var tx := box.position.x + 150.0 if speaking_you else box.end.x - 150.0
		var ty := box.position.y + 1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx - 13.0, ty), Vector2(tx + 13.0, ty),
			Vector2(tx, ty - 15.0)]), Color(0.04, 0.13, 0.18, 0.96))
		draw_line(Vector2(tx - 13.0, ty), Vector2(tx, ty - 15.0),
			Color(ac.r, ac.g, ac.b, 0.8), 1.4)
		draw_line(Vector2(tx + 13.0, ty), Vector2(tx, ty - 15.0),
			Color(ac.r, ac.g, ac.b, 0.8), 1.4)

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
