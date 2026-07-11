extends Control
## Title screen — pick a save slot to resume, or start a new game on an
## empty one. Placeholder _draw() starfield behind code-built buttons.

const SLOTS := 3

var _stars: Array = []
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.make_theme()
	GameState.in_game = false
	get_tree().paused = false

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 160:
		_stars.append([
			Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)),
			rng.randf_range(0.5, 2.2),
			rng.randf_range(0.2, 0.9),
		])

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(640 - 170, 320)
	box.custom_minimum_size = Vector2(340, 0)

	for i in SLOTS:
		var b := Button.new()
		b.text = _slot_text(i)
		b.custom_minimum_size = Vector2(340, 44)
		b.pressed.connect(_on_slot.bind(i))
		box.add_child(b)

	var hint := Label.new()
	hint.text = "Spacewalks drain O2 · bank ore at the ship · upgrade · fly farther"
	hint.modulate = Color(1, 1, 1, 0.45)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	hint.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)


func _slot_text(i: int) -> String:
	var data := GameState.slot_data(i)
	if data.is_empty():
		return "SLOT %d   —   New game" % (i + 1)
	var date: String = data.get("saved_at", "")
	var parts := date.split("-")
	if parts.size() == 3:
		date = "%s/%s/%s" % [parts[2], parts[1], parts[0]]
	return "SLOT %d   —   %d ore · %s" % [i + 1, int(data.get("banked", 0)), date]


func _on_slot(i: int) -> void:
	if GameState.load_game(i):
		# resume inside the ship — safe ground after any absence
		get_tree().change_scene_to_file("res://scenes/ship_interior.tscn")
	else:
		GameState.new_game(i)
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.035, 0.05, 0.09), true)
	for s in _stars:
		draw_circle(s[0], s[1], Color(1, 1, 1, s[2]))
	# title
	draw_string(_font, Vector2(0, 200), "SPACEWALKER",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 56, Color(0.92, 0.94, 0.97))
	draw_string(_font, Vector2(0, 236), "mine the void · mind the line",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(0.35, 0.8, 1.0, 0.7))
	# little astronaut doodle by the title
	var c := Vector2(size.x * 0.5 + 250, 180)
	draw_circle(c + Vector2(-8, 2), 7.0, Color(0.45, 0.48, 0.55))
	draw_circle(c, 11.0, Color(0.92, 0.94, 0.97))
	draw_circle(c + Vector2(4, -2), 6.0, Color(0.1, 0.2, 0.35))
	draw_line(c + Vector2(-16, 6), c + Vector2(-38, 18), Color(1.0, 0.85, 0.3, 0.8), 2.0)
