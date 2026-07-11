extends SceneTree
## One-shot: montage the extracted props into one contact image per sheet
## (reading order = extraction index), for visual verification/mapping.
## Run: godot --headless -s tools/make_contact.gd

const PROPS := "res://assets/props"
const OUT := "user://contact"
const CELL := 150
const COLS := 6


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for id in range(1, 11):
		var files: Array[String] = []
		var n := 0
		while FileAccess.file_exists(ProjectSettings.globalize_path(
				"%s/s%d_%02d.png" % [PROPS, id, n])):
			files.append("%s/s%d_%02d.png" % [PROPS, id, n])
			n += 1
		if files.is_empty():
			continue
		var rows := int(ceil(float(files.size()) / COLS))
		var img := Image.create(COLS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.1, 0.12, 0.16))
		for i in files.size():
			var piece := Image.load_from_file(ProjectSettings.globalize_path(files[i]))
			piece.convert(Image.FORMAT_RGBA8)
			# fit into the cell
			var s := minf(float(CELL - 14) / piece.get_width(),
				float(CELL - 14) / piece.get_height())
			if s < 1.0:
				piece.resize(int(piece.get_width() * s), int(piece.get_height() * s),
					Image.INTERPOLATE_LANCZOS)
			var cx := (i % COLS) * CELL + (CELL - piece.get_width()) / 2
			var cy := (i / COLS) * CELL + (CELL - piece.get_height()) / 2
			img.blend_rect(piece, Rect2i(0, 0, piece.get_width(), piece.get_height()),
				Vector2i(cx, cy))
			# index tick marks along the cell top (i+1 dots)
			for d in i + 1:
				img.fill_rect(Rect2i((i % COLS) * CELL + 4 + d * 6,
					(i / COLS) * CELL + 3, 4, 4), Color(0.3, 1.0, 1.0))
		img.save_png(ProjectSettings.globalize_path("%s/contact_%d.png" % [OUT, id]))
		print("contact_%d.png (%d props)" % [id, files.size()])
	quit(0)
