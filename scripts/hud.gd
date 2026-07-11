extends CanvasLayer
## HUD built in code — O2 bar, remaining line bar, cargo counters,
## fading message label and controls hint.

const GEAR_PANEL := preload("res://scripts/gear_panel.gd")

var _oxygen_bar: ProgressBar
var _line_bar: ProgressBar
var _cargo_label: Label
var _msg_label: Label
var _msg_tween: Tween
var _dock_prompt: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	root.add_child(box)

	_oxygen_bar = _make_bar("O2", box, Color(0.35, 0.8, 1.0))
	_line_bar = _make_bar("LINE", box, Color(1.0, 0.85, 0.3))

	_cargo_label = Label.new()
	_cargo_label.text = "Ore: 0   Banked: 0"
	box.add_child(_cargo_label)

	# gear rack (top-right)
	var gear := GEAR_PANEL.new()
	root.add_child(gear)
	gear.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)

	# "enter ship" prompt — only visible while docked
	_dock_prompt = Label.new()
	_dock_prompt.text = "E  Enter ship"
	_dock_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_prompt.modulate = Color(0.6, 0.9, 1.0, 0.0)
	root.add_child(_dock_prompt)
	_dock_prompt.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 120)

	var hint := Label.new()
	hint.text = "WASD thrust · Hold LMB to mine · Dock to bank & refill O2 · R restart"
	hint.modulate = Color(1, 1, 1, 0.55)
	root.add_child(hint)
	hint.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)

	_msg_label = Label.new()
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.modulate.a = 0.0
	root.add_child(_msg_label)
	_msg_label.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 80)

	GameState.oxygen_changed.connect(_on_oxygen)
	GameState.cargo_changed.connect(_on_cargo)
	GameState.notify.connect(_on_notify)


func _make_bar(title: String, parent: Control, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lab := Label.new()
	lab.text = title
	lab.custom_minimum_size = Vector2(44, 0)
	row.add_child(lab)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(180, 16)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	bar.add_theme_stylebox_override("fill", sb)
	row.add_child(bar)
	return bar


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var dist: float = player.global_position.distance_to(player.tether_anchor)
		_line_bar.value = clampf((1.0 - dist / GameState.tether_length) * 100.0, 0.0, 100.0)
		_dock_prompt.modulate.a = 0.9 if player.in_dock else 0.0


func _on_oxygen(current: float, maximum: float) -> void:
	_oxygen_bar.max_value = maximum
	_oxygen_bar.value = current


func _on_cargo(carried: int, banked: int) -> void:
	_cargo_label.text = "Ore: %d   Banked: %d" % [carried, banked]


func _on_notify(text: String) -> void:
	_msg_label.text = text
	if _msg_tween:
		_msg_tween.kill()
	_msg_label.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(2.2)
	_msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.8)
