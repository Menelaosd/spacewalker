extends SceneTree
## 2x zoom of ONLY the side rows for leg-pose inspection.
const DIR := "res://assets/sprites/walk"
const ROWS := [
	["right_0", "right_1", "right_2", "right_3", "right_idle"],
	["left_0", "left_1", "left_2", "left_3", "left_idle"],
]
func _init() -> void:
	var cw := (88 + 6) * 2
	var ch := (126 + 6) * 2
	var out := Image.create(cw * 7, ch * ROWS.size(), false, Image.FORMAT_RGBA8)
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
	out.save_png(ProjectSettings.globalize_path("res://montage_side.png"))
	print("saved montage_side.png")
	quit(0)
