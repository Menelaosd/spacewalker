extends SceneTree
## 6x zoom of right-row frames with a 10px grid overlay, for surgical
## coordinate planning (limb masks). Saves zoom_parts.png at project root.
const FILES := ["right_idle", "right_0", "right_1", "right_2", "right_3"]
func _init() -> void:
	var cell_w := 0
	var cell_h := 0
	var imgs: Array = []
	for f in FILES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(
			"res://assets/sprites/walk/%s.png" % f))
		img.convert(Image.FORMAT_RGBA8)
		imgs.append(img)
		cell_w = maxi(cell_w, img.get_width())
		cell_h = maxi(cell_h, img.get_height())
	var z := 6
	var out := Image.create((cell_w * z + 12) * imgs.size(), cell_h * z + 12,
		false, Image.FORMAT_RGBA8)
	out.fill(Color(0.35, 0.35, 0.38))
	for i in imgs.size():
		var img: Image = imgs[i]
		img.resize(img.get_width() * z, img.get_height() * z, Image.INTERPOLATE_NEAREST)
		var ox := i * (cell_w * z + 12) + 6
		out.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()),
			Vector2i(ox, 6))
		# 10px grid (in SOURCE pixels -> every 60 output px), light lines
		for gx in range(0, cell_w + 1, 10):
			for yy in range(0, cell_h * z):
				var px := ox + gx * z
				if px < out.get_width():
					var c := out.get_pixel(px, 6 + yy)
					out.set_pixel(px, 6 + yy, c.lerp(Color(1, 0.4, 0.4), 0.25))
		for gy in range(0, cell_h + 1, 10):
			for xx in range(0, cell_w * z):
				var py := 6 + gy * z
				if py < out.get_height():
					var c2 := out.get_pixel(ox + xx, py)
					out.set_pixel(ox + xx, py, c2.lerp(Color(0.4, 0.6, 1), 0.25))
	out.save_png(ProjectSettings.globalize_path("res://zoom_parts.png"))
	print("saved zoom_parts.png cell=%dx%d" % [cell_w, cell_h])
	quit(0)
