extends SceneTree
## Composite all extracted element icons into one contact sheet for visual QA.
## Run: godot --headless -s tools/contact_elements.gd

const DIR := "res://assets/sprites/elements/"
const CELL := 96
const COLS := 12
const OUT := "res://tools/_contact_elements.png"


func _init() -> void:
	var rows := int(ceil(103.0 / COLS))
	var sheet := Image.create(COLS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.13, 1))
	var found := 0
	for z in range(1, 104):
		var path := DIR + "z%d.png" % z
		if not FileAccess.file_exists(path):
			continue
		var im := Image.load_from_file(ProjectSettings.globalize_path(path))
		im.convert(Image.FORMAT_RGBA8)
		# scale to fit CELL keeping aspect
		var scale: float = float(CELL - 8) / float(maxi(im.get_width(), im.get_height()))
		var nw := maxi(int(im.get_width() * scale), 1)
		var nh := maxi(int(im.get_height() * scale), 1)
		im.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
		var idx := z - 1
		var cx := (idx % COLS) * CELL + (CELL - nw) / 2
		var cy := (idx / COLS) * CELL + (CELL - nh) / 2
		sheet.blit_rect(im, Rect2i(0, 0, nw, nh), Vector2i(cx, cy))
		found += 1
	sheet.save_png(ProjectSettings.globalize_path(OUT))
	print("contact sheet: %d icons -> %s" % [found, OUT])
	quit(0)
