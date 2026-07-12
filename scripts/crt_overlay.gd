extends CanvasLayer
## Autoload: a single full-screen CRT post-process laid over every scene.
## Subtle by default; toggle with the SW_NO_CRT env (screenshots/perf tests).

const CRT_SHADER := preload("res://assets/shaders/crt.gdshader")

var _rect: ColorRect


func _ready() -> void:
	layer = 128                                  # above all HUD
	if OS.get_environment("SW_NO_CRT") != "":
		return
	var mat := ShaderMaterial.new()
	mat.shader = CRT_SHADER
	_rect = ColorRect.new()
	_rect.material = mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	# preset AFTER entering the tree, then pin the size explicitly and track
	# viewport resizes — a preset alone can leave a CanvasLayer-child Control
	# 0x0 (same family as the unclickable-modal bug)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	if _rect != null:
		_rect.position = Vector2.ZERO
		_rect.size = get_viewport().get_visible_rect().size


func set_enabled(on: bool) -> void:
	if _rect != null:
		_rect.visible = on
