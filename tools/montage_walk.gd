extends SceneTree
## Contact sheet of the extracted walk frames (on gray, for eyeballing), 2x.
const DIR := "res://assets/sprites/walk"
const ROWS := [
	["right_0", "right_1", "right_2", "right_3", "right_idle"],
	["left_0", "left_1", "left_2", "left_3", "left_idle"],
	["front_0", "front_1", "front_2", "front_3", "front_idle"],
	["back_0", "back_1", "back_2", "back_3", "back_idle"],
]
func _init() -> void:
	var cw := (82 + 6) * 2
	var ch := (123 + 6) * 2
	var out := Image.create(cw * 5, ch * ROWS.size(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.35, 0.35, 0.38))
	for r in ROWS.size():
		for c in ROWS[r].size():
			var img := Image.load_from_file(ProjectSettings.globalize_path(
				"%s/%s.png" % [DIR, ROWS[r][c]]))
			if img == null:
				continue
			img.convert(Image.FORMAT_RGBA8)
			img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
			out.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()),
				Vector2i(c * cw + 6, r * ch + 6))
	out.save_png(ProjectSettings.globalize_path("res://montage_walk.png"))
	print("saved montage_walk.png")
	quit(0)
