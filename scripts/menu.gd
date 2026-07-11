extends CanvasLayer
## Pause menu (autoload "GameMenu"). Esc toggles it during a run — pauses
## the whole tree, offers Save and a safe exit to the title screen.
## Inactive on the title screen itself (GameState.in_game gates it).

var _save_btn: Button


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE and GameState.in_game:
		toggle()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_save_btn.text = "Save game"


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.03, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UITheme.make_theme()
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(toggle)
	box.add_child(resume)

	_save_btn = Button.new()
	_save_btn.text = "Save game"
	_save_btn.pressed.connect(_on_save)
	box.add_child(_save_btn)

	var quit := Button.new()
	quit.text = "Save & quit to title"
	quit.pressed.connect(_on_quit)
	box.add_child(quit)


func _on_save() -> void:
	GameState.save_game()
	_save_btn.text = "Saved ✓"
	await get_tree().create_timer(1.2).timeout
	if visible:
		_save_btn.text = "Save game"


func _on_quit() -> void:
	GameState.save_game()
	visible = false
	get_tree().paused = false
	GameState.in_game = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
