extends SceneTree
## One-shot: key ship3.png off its green screen, rotate so the bow faces
## +X (game convention), trim and resize. REPLACES assets/sprites/ship_hd.png
## (the old hull lives on in git). Run: godot --headless -s tools/process_ship3.gd

const SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/ship3.png"
const DST := "res://assets/sprites/ship_hd.png"
const TARGET_W := 340


func _init() -> void:
	var img := Image.load_from_file(SRC)
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.g > 0.35 and c.g > c.r * 1.5 and c.g > c.b * 1.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.g > c.r and c.g > c.b:
				img.set_pixel(x, y,
					Color(c.r, minf(c.g, maxf(c.r, c.b) * 1.15), c.b, c.a))
	img = img.get_region(img.get_used_rect())
	# art bow points LEFT — rotate 180 so the bow faces +X
	img.rotate_180()
	var h := int(round(float(img.get_height()) * TARGET_W / img.get_width()))
	img.resize(TARGET_W, h, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(DST))
	print("ship3 processed: %dx%d -> %s" % [TARGET_W, h, DST])
	quit(0)
