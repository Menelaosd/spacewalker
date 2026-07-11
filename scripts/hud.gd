extends CanvasLayer
## HUD built in code — O2 bar, remaining line bar, cargo counters,
## fading message label and controls hint.

const GEAR_PANEL := preload("res://scripts/gear_panel.gd")
const INVENTORY_SCREEN := preload("res://scripts/inventory_screen.gd")

var _oxygen_bar: ProgressBar
var _oxygen_num: Label
var _line_bar: ProgressBar
var _cargo_label: Label
var _msg_label: Label
var _msg_tween: Tween
var _dock_prompt: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.make_theme()
	add_child(root)

	# vitals cluster in a rounded panel, NMS-style
	var vitals := PanelContainer.new()
	vitals.position = Vector2(14, 14)
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vitals)
	var box := VBoxContainer.new()
	vitals.add_child(box)

	_oxygen_bar = _make_bar("O2", box, Color(0.35, 0.8, 1.0))
	_oxygen_num = Label.new()
	_oxygen_num.modulate = Color(0.7, 0.9, 1.0)
	_oxygen_bar.get_parent().add_child(_oxygen_num)
	_line_bar = _make_bar("LINE", box, Color(1.0, 0.85, 0.3))

	_cargo_label = Label.new()
	_cargo_label.text = "Ore: 0   Banked: 0"
	box.add_child(_cargo_label)

	# gear rack (bottom-right)
	var gear := GEAR_PANEL.new()
	root.add_child(gear)
	gear.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)

	# full inventory overlay (I / Tab)
	root.add_child(INVENTORY_SCREEN.new())

	# "enter ship" prompt — only visible while docked
	_dock_prompt = Label.new()
	_dock_prompt.text = "E  Enter ship"
	_dock_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_prompt.modulate = Color(0.6, 0.9, 1.0, 0.0)
	root.add_child(_dock_prompt)
	_dock_prompt.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 120)

	var hint := Label.new()
	hint.text = "WASD thrust · Hold LMB to mine · Dock to bank & refill O2 · I inventory · Esc menu"
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
	# reflect loaded/current state immediately, not just on next change
	_on_oxygen(GameState.oxygen, GameState.max_oxygen)
	_on_cargo(GameState.carried, GameState.banked)


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
	bar.add_theme_stylebox_override("background", UITheme.bar_bg())
	bar.add_theme_stylebox_override("fill", UITheme.bar_fill(color))
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
	_oxygen_num.text = "%d / %d" % [ceili(current), int(maximum)]


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
