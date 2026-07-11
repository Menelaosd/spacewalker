extends ColorRect
## Whole-screen VHS filter (shaders/vhs.gdshader) — chromatic aberration,
## scanlines, grain, tape wobble. Sits under the HUD, over the world, so
## the world gets the tape look while the instruments stay crisp.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/vhs.gdshader")
	material = mat
