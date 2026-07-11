extends Control
## Title screen — pick a save slot to resume, or start a new game on an
## empty one. Animated: twinkling stars, drifting nebula haze, and the
## captain's ship gliding through the backdrop.

const SLOTS := 3
const SHIP_TEX := preload("res://assets/sprites/ship_hd.png")

var _stars: Array = []
var _font: Font = ThemeDB.fallback_font
var _t := 0.0
var _slot_btns: Array[Button] = []
var _del_btns: Array[Button] = []
var _arm_delete := -1   # slot whose ✕ was pressed once (confirm state)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.make_theme()
	GameState.in_game = false
	get_tree().paused = false
	# VHS filter over the title backdrop too (added below the buttons)
	var fx := preload("res://scripts/screen_fx.gd").new()
	add_child(fx)
	move_child(fx, 0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 170:
		_stars.append([
			Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)),
			rng.randf_range(0.5, 2.2),
			rng.randf_range(0.2, 0.9),
			rng.randf_range(0.0, TAU),      # twinkle phase
			rng.randf_range(0.6, 2.4),      # twinkle speed
		])

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.position = Vector2(640 - 200, 330)
	box.custom_minimum_size = Vector2(400, 0)

	for i in SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var b := Button.new()
		b.text = _slot_text(i)
		b.custom_minimum_size = Vector2(360, 46)
		b.pressed.connect(_on_slot.bind(i))
		row.add_child(b)
		_slot_btns.append(b)
		var d := Button.new()
		d.text = "✕"
		d.custom_minimum_size = Vector2(46, 46)
		d.tooltip_text = "Delete this save"
		d.visible = not GameState.slot_data(i).is_empty()
		d.pressed.connect(_on_delete.bind(i))
		row.add_child(d)
		_del_btns.append(d)

	var hint := Label.new()
	hint.text = "mine the void · bank at the ship · upgrade · fly farther"
	hint.modulate = Color(1, 1, 1, 0.4)
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	hint.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 36)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _slot_text(i: int) -> String:
	var data := GameState.slot_data(i)
	if data.is_empty():
		return "SLOT %d   —   NEW GAME" % (i + 1)
	var date: String = data.get("saved_at", "")
	var parts := date.split("-")
	if parts.size() == 3:
		date = "%s/%s/%s" % [parts[2], parts[1], parts[0]]
	return "SLOT %d   —   %d ORE · %s" % [i + 1, int(data.get("banked", 0)), date]


func _on_delete(i: int) -> void:
	if _arm_delete != i:
		# first press arms it — press ✕ again to confirm
		_arm_delete = i
		_refresh_slots()
		return
	GameState.delete_save(i)
	_arm_delete = -1
	_refresh_slots()


func _refresh_slots() -> void:
	for i in SLOTS:
		var empty := GameState.slot_data(i).is_empty()
		_slot_btns[i].text = _slot_text(i)
		_del_btns[i].visible = not empty
		if _arm_delete == i:
			_del_btns[i].text = "SURE?"
			_del_btns[i].custom_minimum_size = Vector2(74, 46)
			_del_btns[i].modulate = UITheme.DANGER
		else:
			_del_btns[i].text = "✕"
			_del_btns[i].custom_minimum_size = Vector2(46, 46)
			_del_btns[i].modulate = Color.WHITE


func _on_slot(i: int) -> void:
	if _arm_delete != -1:
		_arm_delete = -1
		_refresh_slots()
	if GameState.load_game(i):
		# resume inside the ship — safe ground after any absence
		get_tree().change_scene_to_file("res://scenes/ship_interior.tscn")
	else:
		GameState.new_game(i)
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.045, 0.085), true)

	# drifting nebula haze
	var haze1 := Vector2(vp.x * 0.72 + sin(_t * 0.11) * 40.0, 170.0 + cos(_t * 0.09) * 25.0)
	var haze2 := Vector2(vp.x * 0.18 + cos(_t * 0.07) * 50.0, vp.y * 0.8)
	draw_circle(haze1, 300.0, Color(0.85, 0.35, 0.6, 0.045))
	draw_circle(haze1 + Vector2(-120, 60), 210.0, Color(0.85, 0.35, 0.6, 0.035))
	draw_circle(haze2, 260.0, Color(0.3, 0.65, 0.95, 0.04))

	# twinkling stars
	for s in _stars:
		var a: float = s[2] * (0.65 + 0.35 * sin(_t * s[4] + s[3]))
		draw_circle(s[0], s[1], Color(1, 1, 1, a))

	# the ship, drifting through the upper right
	var ship_pos := Vector2(vp.x * 0.76 + sin(_t * 0.14) * 26.0,
		186.0 + sin(_t * 0.2) * 10.0)
	draw_set_transform(ship_pos, -0.16 + sin(_t * 0.1) * 0.02, Vector2(0.62, 0.62))
	draw_texture(SHIP_TEX, -SHIP_TEX.get_size() * 0.5,
		Color(0.75, 0.8, 0.9, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# title with layered glow
	var ty := 208.0
	for glow in [[6, 0.09], [3, 0.16], [1, 0.3]]:
		draw_string(_font, Vector2(float(glow[0]), ty + float(glow[0])),
			"SPACEWALKER", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 58,
			Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b,
				float(glow[1])))
	draw_string(_font, Vector2(0, ty), "SPACEWALKER",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 58, Color(0.94, 0.97, 1.0))
	# accent rules around the subtitle
	var mid := vp.x * 0.5
	var sub_a := 0.6 + 0.15 * sin(_t * 1.6)
	draw_line(Vector2(mid - 240, 236), Vector2(mid - 118, 236),
		Color(1, 1, 1, 0.75), 1.2)
	draw_line(Vector2(mid + 118, 236), Vector2(mid + 240, 236),
		Color(1, 1, 1, 0.75), 1.2)
	draw_string(_font, Vector2(0, 241), "MINE THE VOID · MIND THE LINE",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 14,
		Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, sub_a))

	# footer
	draw_string(_font, Vector2(0, vp.y - 14), "v0.5 · prototype",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 11, Color(1, 1, 1, 0.25))