extends Control
## Whole-screen cockpit glass: faint scanlines + corner vignette.
## Static drawing (no per-frame cost); sits under the HUD, over the world.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var vp := get_viewport_rect().size
	# scanlines
	var y := 0.0
	while y < vp.y:
		draw_line(Vector2(0, y), Vector2(vp.x, y), Color(0, 0, 0, 0.035), 1.0)
		y += 4.0
	# corner vignette — nested translucent triangles fake a soft gradient
	# (a single hard triangle shows a straight edge over bright nebulas)
	for c in [
		[Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(vp.x, 0), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(0, vp.y), Vector2(1, 0), Vector2(0, -1)],
		[vp, Vector2(-1, 0), Vector2(0, -1)],
	]:
		var o: Vector2 = c[0]
		for step in [[300.0, 210.0, 0.07], [220.0, 155.0, 0.08], [140.0, 100.0, 0.09]]:
			draw_colored_polygon(PackedVector2Array([
				o, o + (c[1] as Vector2) * float(step[0]),
				o + (c[2] as Vector2) * float(step[1])]),
				Color(0, 0.01, 0.03, step[2]))
