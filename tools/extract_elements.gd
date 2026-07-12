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


func _process_sheet(sheet_idx: int, fname: String) -> int:
	var img := Image.load_from_file(SRC + fname)
	if img == null:
		push_error("could not load " + fname)
		return 0
	img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()
	var data := img.get_data()
	var bg := _sample_sheet_bg(data, W, H)
	print("sheet %d  %dx%d  %s" % [sheet_idx + 1, W, H, fname])
	var col_w := W / COLS
	var count := 0
	for col in COLS:
		var x0 := col * col_w
		var x1 := x0 + col_w
		# horizontal projection of CONTENT (anything not the flat screen green,
		# so green-coloured elements count as content, not background)
		var rows := PackedInt32Array()
		rows.resize(H)
		for y in H:
			var n := 0
			for x in range(x0, x1):
				if _content(data, y * W + x, bg):
					n += 1
			rows[y] = n
		# find contiguous blobs (runs of rows with content), gap tolerance 10px
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
			var icon := _extract_icon(img, data, W, H, bg, x0, x1, b[0], b[1])
			if icon == null:
				continue
			icon.save_png(ProjectSettings.globalize_path(DST + "z%d.png" % z))
			count += 1
	return count


func _content(data: PackedByteArray, idx: int, bg: Vector3) -> bool:
	## true unless the pixel is the flat background green
	return not _is_bg(data, idx, bg)


func _col_content(data: PackedByteArray, W: int, x: int, y0: int, y1: int, bg: Vector3) -> int:
	## count content pixels in column x over rows [y0, y1]
	var n := 0
	for y in range(y0, y1 + 1):
		if _content(data, y * W + x, bg):
			n += 1
	return n


func _extract_icon(src: Image, data: PackedByteArray, W: int, H: int, bg: Vector3,
		x0: int, x1: int, y0: int, y1: int) -> Image:
	## The icon may spill past its column (some sheets place icons off-grid) or a
	## neighbour may spill in. So don't trust the rigid column strip: find the
	## densest content column INSIDE the strip (the icon's core) and grow left and
	## right across the FULL sheet width, stopping at the green gap that separates
	## this icon from its neighbours. Captures the whole icon, no bleed, no crop.
	var pad := 12
	var yy0: int = maxi(0, y0 - pad)
	var yy1: int = mini(H - 1, y1 + pad)

	# seed at the peak content column within the strip (the icon's core)
	var seed := x0
	var best := -1
	for x in range(x0, x1):
		var n := _col_content(data, W, x, yy0, yy1, bg)
		if n > best:
			best = n
			seed = x
	if best <= 0:
		return null

	var gap := 24
	# grow left
	var xl := seed
	var empty := 0
	var xx := seed
	while xx > 0:
		xx -= 1
		if _col_content(data, W, xx, yy0, yy1, bg) > 0:
			xl = xx
			empty = 0
		else:
			empty += 1
			if empty >= gap:
				break
	# grow right
	var xr := seed
	empty = 0
	xx = seed
	while xx < W - 1:
		xx += 1
		if _col_content(data, W, xx, yy0, yy1, bg) > 0:
			xr = xx
			empty = 0
		else:
			empty += 1
			if empty >= gap:
				break

	# a few px of green margin so the keyer has a clean border to sample
	xl = maxi(0, xl - 6)
	xr = mini(W - 1, xr + 6)
	var cell := src.get_region(Rect2i(xl, yy0, xr - xl + 1, yy1 - yy0 + 1))
	cell.convert(Image.FORMAT_RGBA8)
	_key_cell(cell)
	var used := cell.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	return cell.get_region(used)


func _sample_sheet_bg(data: PackedByteArray, w: int, h: int) -> Vector3:
	## flat screen green, sampled from the four sheet corners
	var acc := Vector3.ZERO
	var n := 0
	var corners: Array[Vector2i] = [Vector2i(3, 3), Vector2i(w - 12, 3), Vector2i(3, h - 12), Vector2i(w - 12, h - 12)]
	for corner in corners:
		for dy in 8:
			for dx in 8:
				var base: int = ((corner.y + dy) * w + (corner.x + dx)) * 4
				acc += Vector3(data[base], data[base + 1], data[base + 2])
				n += 1
	return acc / (n * 255.0)


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


# ---------------------------------------------------------------------------
#  Border flood-fill chroma key (same approach as tools/prep_crew.gd). Only the
#  flat screen-green connected to the cell edge is removed; the element's own
#  green art is a different hue/brightness and survives. A tight "pure bg-green"
#  pass then clears enclosed pockets (gaps between crystals), and the fringe is
#  de-spilled + alpha-feathered.
# ---------------------------------------------------------------------------
func _key_cell(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var bg := _sample_bg(data, w, h)

	var keyed := PackedByteArray()
	keyed.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		_seed(stack, keyed, data, w, x, 0, bg)
		_seed(stack, keyed, data, w, x, h - 1, bg)
	for y in h:
		_seed(stack, keyed, data, w, 0, y, bg)
		_seed(stack, keyed, data, w, w - 1, y, bg)

	while stack.size() > 0:
		var idx := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var x := idx % w
		var y := idx / w
		if x > 0:      _grow(stack, keyed, data, idx - 1, bg)
		if x < w - 1:  _grow(stack, keyed, data, idx + 1, bg)
		if y > 0:      _grow(stack, keyed, data, idx - w, bg)
		if y < h - 1:  _grow(stack, keyed, data, idx + w, bg)

	for i in w * h:
		if keyed[i] == 0 and _is_pure_bg(data, i, bg):
			keyed[i] = 1

	for i in w * h:
		var base := i * 4
		if keyed[i] == 1:
			data[base + 3] = 0
			continue
		var x := i % w
		var y := i / w
		var edge := (x > 0 and keyed[i - 1] == 1) or (x < w - 1 and keyed[i + 1] == 1) \
			or (y > 0 and keyed[i - w] == 1) or (y < h - 1 and keyed[i + w] == 1)
		if not edge:
			continue
		var r := data[base] / 255.0
		var g := data[base + 1] / 255.0
		var b := data[base + 2] / 255.0
		var rb := maxf(r, b)
		if g > rb:
			var excess := g - rb
			data[base + 1] = int(rb * 255.0)
			var a := clampf(1.0 - excess * 2.2, 0.3, 1.0)
			data[base + 3] = int(data[base + 3] * a)

	var out := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	img.copy_from(out)


func _seed(stack: PackedInt32Array, keyed: PackedByteArray, data: PackedByteArray,
		w: int, x: int, y: int, bg: Vector3) -> void:
	var idx := y * w + x
	if keyed[idx] == 0 and _is_bg(data, idx, bg):
		keyed[idx] = 1
		stack.push_back(idx)


func _grow(stack: PackedInt32Array, keyed: PackedByteArray, data: PackedByteArray,
		nidx: int, bg: Vector3) -> void:
	if keyed[nidx] == 0 and _is_bg(data, nidx, bg):
		keyed[nidx] = 1
		stack.push_back(nidx)


func _is_bg(data: PackedByteArray, idx: int, bg: Vector3) -> bool:
	var base := idx * 4
	var r := data[base] / 255.0
	var g := data[base + 1] / 255.0
	var b := data[base + 2] / 255.0
	if not (g > r * 1.12 and g > b * 1.12):
		return false
	var dr := r - bg.x
	var dg := g - bg.y
	var db := b - bg.z
	return dr * dr + dg * dg + db * db < 0.10


func _is_pure_bg(data: PackedByteArray, idx: int, bg: Vector3) -> bool:
	var base := idx * 4
	var r := data[base] / 255.0
	var g := data[base + 1] / 255.0
	var b := data[base + 2] / 255.0
	if not (g > r * 1.5 and g > b * 1.5):
		return false
	var dr := r - bg.x
	var dg := g - bg.y
	var db := b - bg.z
	return dr * dr + dg * dg + db * db < 0.04


func _sample_bg(data: PackedByteArray, w: int, h: int) -> Vector3:
	var acc := Vector3.ZERO
	var n := 0
	var corners: Array[Vector2i] = [Vector2i(2, 2), Vector2i(w - 8, 2), Vector2i(2, h - 8), Vector2i(w - 8, h - 8)]
	for corner in corners:
		for dy in 6:
			for dx in 6:
				var base: int = ((corner.y + dy) * w + (corner.x + dx)) * 4
				acc += Vector3(data[base], data[base + 1], data[base + 2])
				n += 1
	return acc / (n * 255.0)
