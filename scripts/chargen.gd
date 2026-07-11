extends Control
## Crew registry — the emergency record you file before the intro plays.
## Name, gender and age get stored on GameState.pilot (and in the save),
## then the story addresses you by name. ENTER confirms, ESC accepts
## defaults and moves on.

const GENDERS := ["FEMALE", "MALE", "OTHER"]
const AGE_MIN := 16
const AGE_MAX := 99

var _name_edit: LineEdit
var _gender_btns: Array[Button] = []
var _age_label: Label
var _gender := 2
var _age := 27
var _t := 0.0
var _stars: Array = []
var _panel: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.make_theme()
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in 120:
		_stars.append([Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)),
			rng.randf_range(0.4, 1.9), rng.randf_range(0.15, 0.7),
			rng.randf_range(0.0, TAU)])

	# panel chrome is painted; the interactive widgets sit on top of it
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	box.position = Vector2(640 - 190, 258)
	box.custom_minimum_size = Vector2(380, 0)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "CALLSIGN"
	_name_edit.max_length = 12
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(380, 44)
	_name_edit.text_submitted.connect(func(_s: String): _confirm())
	box.add_child(_name_edit)

	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 8)
	box.add_child(grow)
	for i in GENDERS.size():
		var b := Button.new()
		b.text = GENDERS[i]
		b.custom_minimum_size = Vector2(121, 40)
		b.pressed.connect(_set_gender.bind(i))
		grow.add_child(b)
		_gender_btns.append(b)

	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(arow)
	var minus := Button.new()
	minus.text = "◀"
	minus.custom_minimum_size = Vector2(56, 40)
	minus.pressed.connect(_bump_age.bind(-1))
	arow.add_child(minus)
	_age_label = Label.new()
	_age_label.custom_minimum_size = Vector2(180, 40)
	_age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_age_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_age_label.add_theme_font_size_override("font_size", 20)
	arow.add_child(_age_label)
	var plus := Button.new()
	plus.text = "▶"
	plus.custom_minimum_size = Vector2(56, 40)
	plus.pressed.connect(_bump_age.bind(1))
	arow.add_child(plus)

	var go := Button.new()
	go.text = "FILE RECORD  —  BEGIN"
	go.custom_minimum_size = Vector2(380, 48)
	go.pressed.connect(_confirm)
	box.add_child(go)

	_set_gender(_gender)
	_refresh_age()
	_name_edit.grab_focus()

	var fx := preload("res://scripts/screen_fx.gd").new()
	add_child(fx)


func _set_gender(i: int) -> void:
	_gender = i
	for j in _gender_btns.size():
		_gender_btns[j].modulate = Color(1, 1, 1) if j == _gender \
			else Color(1, 1, 1, 0.45)


func _bump_age(dir: int) -> void:
	_age = clampi(_age + dir, AGE_MIN, AGE_MAX)
	_refresh_age()


func _refresh_age() -> void:
	_age_label.text = "AGE   %d" % _age


func _confirm() -> void:
	var n := _name_edit.text.strip_edges().to_upper()
	GameState.pilot = {
		"name": n if n != "" else "WALKER",
		"gender": GENDERS[_gender],
		"age": _age,
	}
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/intro.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_confirm()   # defaults are a valid record; the flare won't wait
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ENTER:
			_confirm()


func _process(delta: float) -> void:
	_t += delta
	_panel.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.012, 0.025, 0.05), true)
	for s in _stars:
		draw_circle(s[0], s[1], Color(1, 1, 1, s[2] * (0.6 + 0.4 * sin(_t * 1.1 + s[3]))))


func _draw_panel() -> void:
	var vp: Vector2 = _panel.get_viewport_rect().size
	var font: Font = ThemeDB.fallback_font
	var rect := Rect2(vp.x * 0.5 - 240, 150, 480, 400)
	UITheme.draw_sci_panel(_panel, rect)
	UITheme.draw_headline(_panel, Rect2(rect.position + Vector2(24, 18),
		Vector2(rect.size.x - 48, 34)), "EMERGENCY CREW RECORD", font, 17)
	_panel.draw_string(font, rect.position + Vector2(0, 78),
		"COLONIAL AUTHORITY · FORM 2211-C · LAST OF STATION",
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11,
		Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.45))
	# field captions, left-aligned to the widget column
	var lx := vp.x * 0.5 - 190.0
	_panel.draw_string(font, Vector2(lx, 252), "NAME / CALLSIGN",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.TEXT_DIM)
	_panel.draw_string(font, Vector2(lx, 314), "GENDER",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.TEXT_DIM)
	_panel.draw_string(font, Vector2(lx, 372), "AGE (STANDARD YEARS)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.TEXT_DIM)
	UITheme.draw_chevrons(_panel, Vector2(rect.position.x - 40, rect.get_center().y),
		3, 14.0, UITheme.ACCENT, _t)
	UITheme.draw_chevrons(_panel, Vector2(rect.end.x + 12, rect.get_center().y),
		3, 14.0, UITheme.ACCENT, _t + 0.4)
	_panel.draw_string(font, Vector2(0, vp.y - 22),
		"ENTER — file record        ESC — file with defaults",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 12, UITheme.TEXT_DIM)
