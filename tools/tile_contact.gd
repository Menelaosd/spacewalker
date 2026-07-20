extends Control
## Contact sheet for the 10 candidate grid tiles — draws them in a numbered 5x2 grid
## and screenshots itself. Run windowed: godot --path . res://tools/tile_contact.tscn
## with env SW_SHOT=<png>. Tiles read from the scratchpad dir given by SW_TILES.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().create_timer(0.4).timeout
	queue_redraw()
	await get_tree().create_timer(0.3).timeout
	if OS.get_environment("SW_SHOT") != "":
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SW_SHOT"))
	get_tree().quit()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.06, 0.07, 0.1))
	var font := ThemeDB.fallback_font
	var dir := OS.get_environment("SW_TILES")
	var cols := 5
	var rows := 2
	var cell := minf((vp.x - 80.0) / cols, (vp.y - 140.0) / rows)
	var tile := cell - 46.0
	var ox := (vp.x - cols * cell) * 0.5
	var oy := 70.0
	for i in 10:
		var c := i % cols
		var r := i / cols
		var x := ox + c * cell + (cell - tile) * 0.5
		var y := oy + r * cell + 30.0
		var p := ProjectSettings.globalize_path("%s/t%02d.png" % [dir, i + 1])
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			if img != null:
				var tex := ImageTexture.create_from_image(img)
				draw_texture_rect(tex, Rect2(x, y, tile, tile), false)
				draw_rect(Rect2(x, y, tile, tile), Color(0.3, 0.5, 0.65, 0.5), false, 2.0)
		draw_string(font, Vector2(x + 6, y - 8), "%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.5, 0.9, 1.0))
