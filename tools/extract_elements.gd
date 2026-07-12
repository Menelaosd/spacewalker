extends SceneTree
## Slice the green-screened element sprite sheets into per-element PNGs.
## Sheets are 4-column grids, atomic number == label number, in order:
##   sheet s, cell c  ->  atomic number = s*12 + c + 1   (last sheet: 97..103)
## For each column strip we find vertical "blobs" of non-green content and keep
## the TALL icon blob, dropping the short text label below it — so no text ends
## up in the output. Each icon is then green-keyed (with de-spill) and cropped
## tight. Saved as res://assets/sprites/elements/z<N>.png (N = atomic number).
## Run: godot --headless -s tools/extract_elements.gd

const SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/elements/"
const DST := "res://assets/sprites/elements/"
const COLS := 4
const SHEETS := [
	"ChatGPT Image Jul 12, 2026, 02_05_45 PM (1).png",   #  1..12
	"ChatGPT Image Jul 12, 2026, 02_05_45 PM (2).png",   # 13..24
	"ChatGPT Image Jul 12, 2026, 02_05_46 PM (3).png",   # 25..36
	"ChatGPT Image Jul 12, 2026, 02_05_46 PM (4).png",   # 37..48
	"ChatGPT Image Jul 12, 2026, 02_05_47 PM (5).png",   # 49..60
	"ChatGPT Image Jul 12, 2026, 02_05_48 PM (6).png",   # 61..72
	"ChatGPT Image Jul 12, 2026, 02_05_50 PM (7).png",   # 73..84
	"ChatGPT Image Jul 12, 2026, 02_05_50 PM (8).png",   # 85..96
	"ChatGPT Image Jul 12, 2026, 02_05_50 PM (9).png",   # 97..103
]


func _init() -> void:
	var abs_dst := ProjectSettings.globalize_path(DST)
	DirAccess.make_dir_recursive_absolute(abs_dst)
	var total := 0
	for s in SHEETS.size():
		total += _process_sheet(s, SHEETS[s])
	print("DONE — extracted %d element icons to %s" % [total, DST])
	quit(0)


func _is_green(c: Color) -> bool:
	return c.a > 0.3 and c.g > 0.45 and c.g > c.r * 1.25 and c.g > c.b * 1.25


func _process_sheet(sheet_idx: int, fname: String) -> int:
	var img := Image.load_from_file(SRC + fname)
	if img == null:
		push_error("could not load " + fname)
		return 0
	img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()
	print("sheet %d  %dx%d  %s" % [sheet_idx + 1, W, H, fname])
	var col_w := W / COLS
	var count := 0
	for col in COLS:
		var x0 := col * col_w
		var x1 := x0 + col_w
		# horizontal projection of non-green pixels across this column strip
		var rows := PackedInt32Array()
		rows.resize(H)
		for y in H:
			var n := 0
			for x in range(x0, x1):
				if not _is_green(img.get_pixel(x, y)):
					n += 1
			rows[y] = n
		# find contiguous blobs (runs of rows with content), gap tolerance 8px
		var blobs := _find_blobs(rows, 6, 10)
		# icons are tall & massy; text labels are short. keep icon blobs only.
		for b in blobs:
			var bh: int = b[1] - b[0]
			if bh < 55:
				continue   # text label or stray — skip
			# which element is this? blobs come out top-to-bottom = row order
			var row := int(b[2])   # row index assigned in _find_blobs pass
			var z := sheet_idx * 12 + row * COLS + col + 1
			if z > 103:
				continue
			var icon := _crop_icon(img, x0, x1, b[0], b[1])
			if icon == null:
				continue
			icon.save_png(ProjectSettings.globalize_path(DST + "z%d.png" % z))
			count += 1
	return count


func _find_blobs(rows: PackedInt32Array, thresh: int, gap: int) -> Array:
	## Returns [[y_start, y_end, row_index], ...] for icon-sized blobs, where
	## row_index counts icon blobs top-to-bottom (0,1,2) so we can map to the grid.
	var raw: Array = []
	var in_blob := false
	var start := 0
	var empty_run := 0
	for y in rows.size():
		if rows[y] > thresh:
			if not in_blob:
				in_blob = true
				start = y
			empty_run = 0
		else:
			if in_blob:
				empty_run += 1
				if empty_run >= gap:
					raw.append([start, y - empty_run + 1])
					in_blob = false
	if in_blob:
		raw.append([start, rows.size() - 1])
	# assign row index only to icon-sized blobs
	var out: Array = []
	var ri := 0
	for b in raw:
		if b[1] - b[0] >= 55:
			out.append([b[0], b[1], ri])
			ri += 1
		else:
			out.append([b[0], b[1], -1])
	return out


func _crop_icon(src: Image, x0: int, x1: int, y0: int, y1: int) -> Image:
	## Copy the cell sub-rect, green-key with de-spill, then crop to bbox.
	var w := x1 - x0
	var h := y1 - y0 + 1
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := src.get_pixel(x0 + x, y0 + y)
			if _is_green(c):
				out.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.g > c.r and c.g > c.b:
				# de-spill: pull the green channel back toward the other two
				out.set_pixel(x, y,
					Color(c.r, minf(c.g, maxf(c.r, c.b) * 1.12), c.b, c.a))
			else:
				out.set_pixel(x, y, c)
	var used := out.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	return out.get_region(used)
