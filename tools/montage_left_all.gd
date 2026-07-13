extends SceneTree
## All 7 raw LEFT-row figures straight from the source sheet, 2x, numbered —
## for picking the captain's exact 4 poses.

const SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/frames/ChatGPT Image Jul 13, 2026, 11_42_23 PM.png"


func _green(c: Color) -> bool:
	return c.g > 0.30 and c.g > c.r * 1.45 and c.g > c.b * 1.45


func _init() -> void:
	var img := Image.load_from_file(SRC)
	img.convert(Image.FORMAT_RGBA8)
	# LEFT row band: y ~ 280..470 in the 1254px sheet (row 2 of 5)
	var y0 := 270
	var y1 := 480
	# find figure columns by opaque-x histogram inside the band
	var w := img.get_width()
	var cols: Array = []
	var run_start := -1
	for x in w:
		var hit := false
		for y in range(y0, y1, 2):
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and not _green(c) and maxf(c.r, maxf(c.g, c.b)) > 0.16:
				hit = true
				break
		if hit and run_start < 0:
			run_start = x
		elif not hit and run_start >= 0:
			if x - run_start > 30:
				cols.append(Vector2i(run_start, x))
			run_start = -1
	print("left-row figures: %d" % cols.size())
	var cw := 110 * 2
	var ch := 220 * 2
	var out := Image.create(cw * cols.size(), ch, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.35, 0.35, 0.38))
	for i in cols.size():
		var r := Rect2i(cols[i].x - 4, y0, cols[i].y - cols[i].x + 8, y1 - y0)
		var crop := img.get_region(r)
		# key green
		for y in crop.get_height():
			for x in crop.get_width():
				if _green(crop.get_pixel(x, y)):
					crop.set_pixel(x, y, Color(0, 0, 0, 0))
		crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
		out.blend_rect(crop, Rect2i(0, 0, crop.get_width(), crop.get_height()),
			Vector2i(i * cw + 4, 4))
	out.save_png(ProjectSettings.globalize_path("res://montage_left_all.png"))
	print("saved montage_left_all.png")
	quit(0)
