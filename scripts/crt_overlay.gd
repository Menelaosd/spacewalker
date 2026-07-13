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
	# full-rect anchors resolve against the viewport for a CanvasLayer child
	# and auto-track resizes — must be set AFTER add_child (anchors applied
	# before entering the tree leave it 0x0). No manual .size: setting size on
	# a non-equal-anchor control is overridden anyway and just warns.
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_enabled(on: bool) -> void:
	if _rect != null:
		_rect.visible = on
