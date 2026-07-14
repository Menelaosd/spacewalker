extends SceneTree
## Stack ONE direction's row from ALL 10 frames5 sheets into a single tall
## strip (numbered), so the captain's pilot (me) can hand-pick the best row
## and frames by eye. Run per direction:
##   godot --headless -s tools/compare_sheets.gd --path . -- right|left|front|back

const DIR_ROWS := {"right": 0, "left": 1, "front": 2, "back": 3}
const SRC_DIR := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/frames5"
const OUT := "res://sheet_compare_%s.png"


func _green(c: Color) -> bool:
	return c.g > 0.16 and c.g > c.r * 1.35 and c.g > c.b * 1.35


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dname: String = args[0] if args.size() > 0 else "right"
	var row_idx: int = DIR_ROWS[dname]

	var files: Array = []
	for f in DirAccess.get_files_at(SRC_DIR):
		if f.ends_with(".png"):
			files.append(f)
	files.sort_custom(func(a, b):
		# sort by the "(N)" suffix so strips are numbered 1..10
		return _num(a) < _num(b))

	var strips: Array = []
	var max_w := 0
	var max_h := 0
	for f in files:
		var img := Image.load_from_file(SRC_DIR + "/" + f)
		img.convert(Image.FORMAT_RGBA8)
		# key green quickly at half res for row detection
		var h := img.get_height()
		var w := img.get_width()
		# find figure rows: y-histogram of non-green, non-label pixels
		var band_hits: Array = []
		for y in range(0, h, 4):
			var hit := 0
			for x in range(0, w, 6):
				var c := img.get_pixel(x, y)
				if not _green(c) and c.a > 0.5 and maxf(c.r, maxf(c.g, c.b)) > 0.16:
					hit += 1
			band_hits.append(hit)
		# group consecutive hit bands into rows
		var rows: Array = []
		var start := -1
		for i in band_hits.size():
			if band_hits[i] > 3 and start < 0:
				start = i * 4
			elif band_hits[i] <= 3 and start >= 0:
				if i * 4 - start > 60:   # tall enough to be a figure row
					rows.append(Vector2i(start, i * 4))
				start = -1
		if start >= 0:
			rows.append(Vector2i(start, h))
		if rows.size() <= row_idx:
			continue
		var band: Vector2i = rows[row_idx]
		var strip := img.get_region(Rect2i(0, maxi(band.x - 6, 0), w,
			mini(band.y - band.x + 12, h - band.x)))
		# key the strip's green for clean viewing
		for y2 in strip.get_height():
			for x2 in strip.get_width():
				if _green(strip.get_pixel(x2, y2)):
					strip.set_pixel(x2, y2, Color(0.32, 0.32, 0.35, 1))
		strips.append(strip)
		max_w = maxi(max_w, strip.get_width())
		max_h = maxi(max_h, strip.get_height())

	var pad := 8
	var out := Image.create(max_w, (max_h + pad) * strips.size(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.13, 0.13, 0.16))
	for i in strips.size():
		var s: Image = strips[i]
		out.blit_rect(s, Rect2i(0, 0, s.get_width(), s.get_height()),
			Vector2i(0, i * (max_h + pad)))
		# number tag: a small white square count marker column at the left edge
		for m in i + 1:
			out.fill_rect(Rect2i(2 + m * 8, i * (max_h + pad) + 2, 6, 6), Color.WHITE)
	out.save_png(ProjectSettings.globalize_path(OUT % dname))
	print("saved sheet_compare_%s.png (%d strips)" % [dname, strips.size()])
	quit(0)


func _num(f: String) -> int:
	var m := f.rfind("(")
	if m < 0:
		return 0
	return int(f.substr(m + 1))
