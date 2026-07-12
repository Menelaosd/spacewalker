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
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func set_enabled(on: bool) -> void:
	if _rect != null:
		_rect.visible = on
