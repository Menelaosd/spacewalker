extends Node
## Counts the breach map's positional lights and shadow casters against the GL
## Compatibility caps (32 renderable, 8 per object). Run headless:
##   <godot> --headless --path . res://tools/count_lights.tscn

func _ready() -> void:
	var scn: Node = load("res://scenes/breach.tscn").instantiate()
	add_child(scn)
	await get_tree().process_frame
	await get_tree().process_frame
	var omni := 0
	var shad := 0
	var stack: Array = [scn]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is OmniLight3D:
			omni += 1
			if (n as OmniLight3D).shadow_enabled:
				shad += 1
		for c in n.get_children():
			stack.append(c)
	print("[LIGHTS] omni=%d shadow_casters=%d  (GL compat caps: 32 renderable, 8/object)"
		% [omni, shad])
	get_tree().quit()
