extends Node
## CONTACT / ASSET SHEET BUILDER. Tiles a folder of PNGs into one labelled sheet.
##
##   SW_SHEET_SRC   source dir (globalized or res://), or several separated by ";"
##   SW_SHEET_OUT   output png path
##   SW_SHEET_COLS  columns (default 6)
##   SW_SHEET_CELL  cell size in px (default 200) — art is fitted, never stretched
##   SW_SHEET_TITLE heading printed at the top
##   SW_SHEET_PAD   cell padding (default 10)
##   SW_SHEET_BG    "dark" (default) or "grid" — grid draws a checker under the art so
##                  transparent sprites read as transparent instead of as black
##   SW_SHEET_MAX   cap the number of images (0 = all)
##   SW_SHEET_LABEL "1" (default) draws each file's name under it, "0" hides it
##
## Runs headless. Images are composited with Image.blit/blend directly — no viewport, so
## the sheet can be any size without touching the window resolution.

const LABEL_H := 18


func _ready() -> void:
	var src := OS.get_environment("SW_SHEET_SRC")
	var out := OS.get_environment("SW_SHEET_OUT")
	if src == "" or out == "":
		push_error("[SHEET] need SW_SHEET_SRC and SW_SHEET_OUT")
		get_tree().quit(1)
		return
	var cols := _envi("SW_SHEET_COLS", 6)
	var cell := _envi("SW_SHEET_CELL", 200)
	var pad := _envi("SW_SHEET_PAD", 10)
	var cap := _envi("SW_SHEET_MAX", 0)
	var title := OS.get_environment("SW_SHEET_TITLE")
	var checker := OS.get_environment("SW_SHEET_BG") == "grid"
	var want_label := OS.get_environment("SW_SHEET_LABEL") != "0"

	# SW_SHEET_FILTER: comma-separated filename PREFIXES to keep
	var filt: PackedStringArray = OS.get_environment("SW_SHEET_FILTER").split(",", false)
	var files: Array[String] = []
	for d in src.split(";", false):
		var dir := ProjectSettings.globalize_path(d)
		var da := DirAccess.open(dir)
		if da == null:
			push_warning("[SHEET] cannot open %s" % dir)
			continue
		var names := da.get_files()
		names.sort()
		for f in names:
			if not f.to_lower().ends_with(".png") or f.ends_with(".import"):
				continue
			if filt.size() > 0:
				var keep := false
				for pre in filt:
					if f.begins_with(pre):
						keep = true
						break
				if not keep:
					continue
			files.append(dir.path_join(f))
	if cap > 0 and files.size() > cap:
		files = files.slice(0, cap)
	if files.is_empty():
		push_error("[SHEET] no PNGs under %s" % src)
		get_tree().quit(1)
		return

	var lab_h := LABEL_H if want_label else 0
	var rows := int(ceil(files.size() / float(cols)))
	var head := 46 if title != "" else 8
	var w := cols * (cell + pad) + pad
	var h := head + rows * (cell + lab_h + pad) + pad
	var sheet := Image.create(w, h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.035, 0.045, 0.062))

	var font: Font = ThemeDB.fallback_font
	for i in files.size():
		var cx := pad + (i % cols) * (cell + pad)
		var cy := head + (i / cols) * (cell + lab_h + pad)
		if checker:
			_checker(sheet, cx, cy, cell)
		else:
			_box(sheet, Rect2i(cx, cy, cell, cell), Color(0.07, 0.085, 0.11))
		var im := Image.load_from_file(files[i])
		if im == null:
			continue
		if im.get_format() != Image.FORMAT_RGBA8:
			im.convert(Image.FORMAT_RGBA8)
		# FIT, never stretch: an asset sheet whose job is showing what the art looks like
		# must not change any sprite's proportions
		var sc: float = minf(float(cell) / float(im.get_width()),
			float(cell) / float(im.get_height()))
		var nw := maxi(1, int(im.get_width() * sc))
		var nh := maxi(1, int(im.get_height() * sc))
		im.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
		sheet.blend_rect(im, Rect2i(0, 0, nw, nh),
			Vector2i(cx + (cell - nw) / 2, cy + (cell - nh) / 2))

	# labels + heading are drawn in a viewport-free way: rasterise the string through the
	# font's own contours would need a canvas, so they go on via a tiny Label render below
	# the count goes in the heading automatically — a hand-written "(all 194)" in the
	# caller was wrong the moment SW_SHEET_MAX or the folder changed
	if title != "":
		title = "%s   ·   %d" % [title, files.size()]
	var canvas: Image = await _text_layer(w, h, files, cols, cell, pad, head, lab_h,
		title, font, want_label)
	if canvas != null:
		sheet.blend_rect(canvas, Rect2i(0, 0, w, h), Vector2i.ZERO)

	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("[SHEET] %d images -> %s (%dx%d)" % [files.size(), out, w, h])
	get_tree().quit()


func _text_layer(w: int, h: int, files: Array[String], cols: int, cell: int, pad: int,
		head: int, lab_h: int, title: String, font: Font, want_label: bool) -> Image:
	## Text needs a canvas. A SubViewport with a transparent background gives one without
	## disturbing the window, and its texture blends straight over the tiled art.
	var svp := SubViewport.new()
	svp.size = Vector2i(w, h)
	svp.transparent_bg = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var ctl := _TextCanvas.new()
	ctl.font = font
	ctl.files = files
	ctl.cols = cols
	ctl.cell = cell
	ctl.pad = pad
	ctl.head = head
	ctl.lab_h = lab_h
	ctl.title = title
	ctl.want_label = want_label
	ctl.size = Vector2(w, h)
	svp.add_child(ctl)
	add_child(svp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return svp.get_texture().get_image()


func _checker(img: Image, x: int, y: int, cell: int) -> void:
	for j in cell:
		for i in cell:
			var on: bool = ((i / 10) + (j / 10)) % 2 == 0
			img.set_pixel(x + i, y + j,
				Color(0.13, 0.145, 0.17) if on else Color(0.10, 0.115, 0.14))


func _box(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(r, c)


func _envi(k: String, d: int) -> int:
	var v := OS.get_environment(k)
	return int(v) if v != "" else d


class _TextCanvas extends Control:
	var font: Font
	var files: Array[String] = []
	var cols := 6
	var cell := 200
	var pad := 10
	var head := 46
	var lab_h := 18
	var title := ""
	var want_label := true

	func _pretty(nm: String) -> String:
		## The element icons are filed by atomic number (z26.png). On a sheet that is meant
		## to SHOW the art to someone, "z26" says nothing and "Fe Iron" says everything.
		if nm.length() > 1 and nm[0] == "z" and nm.substr(1).is_valid_int():
			var z := int(nm.substr(1))
			for e in Elements.TABLE:
				if int(e[2]) == z:
					return "%s  %s" % [str(e[0]), str(e[1])]
		return nm


	func _draw() -> void:
		if title != "":
			draw_string(font, Vector2(pad + 2, 30), title,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.62, 0.86, 0.95))
		if not want_label:
			return
		for i in files.size():
			var cx := pad + (i % cols) * (cell + pad)
			var cy := head + (i / cols) * (cell + lab_h + pad)
			var nm := _pretty(files[i].get_file().get_basename())
			# the width argument HARD-CLIPS, so shrink until it fits rather than lose the end
			var sz := 11
			while sz > 7 and font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1,
					sz).x > float(cell):
				sz -= 1
			draw_string(font, Vector2(cx, cy + cell + 13), nm,
				HORIZONTAL_ALIGNMENT_CENTER, float(cell), sz, Color(0.72, 0.78, 0.85))
