extends SceneTree
## Diagnostic re-extractor: same green-key/despill as crop_trash_b, but per 5x4
## cell it UNIONS the bboxes of ALL sizeable components (reuniting an item that
## the green key split into pieces) instead of keeping only the largest. This
## fixes bottom half-crops caused by a green interior gap splitting the item.
## Saves every cell to a temp dir named sheetN_rRcC.png + a labelled montage.
## READ-ONLY w.r.t. the game assets. Run:
##   godot --headless -s tools/recrop_union.gd --path .

const SRC_DIR := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/trash/"
const SHEETS := {
	6: "ChatGPT Image Jul 14, 2026, 09_57_11 PM (6).png",
	7: "ChatGPT Image Jul 14, 2026, 09_57_11 PM (7).png",
	8: "ChatGPT Image Jul 14, 2026, 09_57_11 PM (8).png",
	9: "ChatGPT Image Jul 14, 2026, 09_57_11 PM (9).png",
	10: "ChatGPT Image Jul 14, 2026, 09_57_12 PM (10).png",
}
const TMP := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/recrop/"
const MONTAGE := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/recrop_montage.png"
const ROWS := 5
const COLS := 4
const KEY_TOL := 0.34
const MIN_AREA := 180     # smaller: keep split halves, still drop specks
const MERGE_GAP := 10     # components whose bboxes are within this many px are one item
const PAD := 4

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	for f in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP + f)
	var saved: Array = []   # {name, img}
	for sheet in SHEETS:
		var cells := _extract(sheet, SRC_DIR + SHEETS[sheet])
		for item in cells:
			var nm := "sheet%d_r%dc%d.png" % [sheet, item.row, item.col]
			item.img.save_png(TMP + nm)
			saved.append({"name": nm, "img": item.img, "eb": item.eb})
	print("saved %d cell crops -> %s" % [saved.size(), TMP])
	# report any with opaque bottom edge (still half-cropped after union)
	print("--- residual bottom-edge-opaque (>10%%) after union ---")
	for s in saved:
		if s.eb > 0.10:
			print("  %-16s edgeB=%.0f%%" % [s.name, s.eb * 100.0])
	_montage(saved)
	print("montage -> %s" % MONTAGE)
	quit(0)

func _extract(sheet: int, path: String) -> Array:
	var img := Image.load_from_file(path)
	if img == null:
		push_error("cannot load " + path)
		return []
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var bg := _corner_bg(img)
	for i in w * h:
		var x := i % w
		var y := i / w
		var c := img.get_pixel(x, y)
		var near := Vector3(c.r - bg.x, c.g - bg.y, c.b - bg.z).length() < KEY_TOL
		var greenish := c.g > 0.34 and c.g > c.r * 1.25 and c.g > c.b * 1.25
		if near or greenish:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	for i in w * h:
		var x := i % w
		var y := i / w
		if img.get_pixel(x, y).a < 0.5:
			continue
		var edge := false
		for o in [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]:
			var ox: int = o[0]
			var oy: int = o[1]
			if ox < 0 or oy < 0 or ox >= w or oy >= h or img.get_pixel(ox, oy).a < 0.5:
				edge = true
				break
		if edge:
			var c := img.get_pixel(x, y)
			if c.g > c.r and c.g > c.b:
				c.g = minf(c.g, maxf(c.r, c.b) * 1.1)
			c.a = 0.85
			img.set_pixel(x, y, c)
	# connected components
	var seen := PackedByteArray()
	seen.resize(w * h)
	var comps: Array[Rect2i] = []
	for y in h:
		for x in w:
			var idx := y * w + x
			if seen[idx] == 1 or img.get_pixel(x, y).a < 0.06:
				continue
			var minx := x
			var maxx := x
			var miny := y
			var maxy := y
			var area := 0
			var st: Array[int] = [idx]
			seen[idx] = 1
			while not st.is_empty():
				var p: int = st.pop_back()
				var px := p % w
				var py := p / w
				area += 1
				minx = mini(minx, px); maxx = maxi(maxx, px)
				miny = mini(miny, py); maxy = maxi(maxy, py)
				for n in [p - 1, p + 1, p - w, p + w]:
					if n < 0 or n >= w * h:
						continue
					if absi((n % w) - px) > 1:
						continue
					if seen[n] == 0 and img.get_pixel(n % w, n / w).a >= 0.06:
						seen[n] = 1
						st.append(n)
			if area >= MIN_AREA:
				comps.append(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))
	# assign comps to cells by center, UNION all comps in a cell that are close
	var cw := float(w) / COLS
	var chf := float(h) / ROWS
	var cell_boxes := {}     # cell -> Array[Rect2i]
	for b in comps:
		var ctr := b.get_center()
		var col := clampi(int(ctr.x / cw), 0, COLS - 1)
		var row := clampi(int(ctr.y / chf), 0, ROWS - 1)
		var cell := row * COLS + col
		if not cell_boxes.has(cell):
			cell_boxes[cell] = []
		cell_boxes[cell].append(b)
	var out: Array = []
	for cell in cell_boxes:
		var boxes: Array = cell_boxes[cell]
		# main = largest; union in any other box within MERGE_GAP of the running union
		boxes.sort_custom(func(a, b): return a.size.x * a.size.y > b.size.x * b.size.y)
		var u: Rect2i = boxes[0]
		var changed := true
		while changed:
			changed = false
			for b in boxes:
				if _near(u, b) and not u.encloses(b):
					u = u.merge(b)
					changed = true
		var padded := Rect2i(
			maxi(u.position.x - PAD, 0),
			maxi(u.position.y - PAD, 0),
			0, 0)
		padded.size.x = mini(u.size.x + PAD * 2, w - padded.position.x)
		padded.size.y = mini(u.size.y + PAD * 2, h - padded.position.y)
		var piece := img.get_region(padded)
		out.append({
			"img": piece,
			"row": cell / COLS,
			"col": cell % COLS,
			"eb": _edge_bottom(piece)})
	return out

func _near(a: Rect2i, b: Rect2i) -> bool:
	var ax2 := a.position.x + a.size.x
	var ay2 := a.position.y + a.size.y
	var bx2 := b.position.x + b.size.x
	var by2 := b.position.y + b.size.y
	var dx := maxi(0, maxi(a.position.x - bx2, b.position.x - ax2))
	var dy := maxi(0, maxi(a.position.y - by2, b.position.y - ay2))
	return dx <= MERGE_GAP and dy <= MERGE_GAP

func _edge_bottom(im: Image) -> float:
	var w := im.get_width()
	var h := im.get_height()
	var c := 0
	for x in w:
		if im.get_pixel(x, h - 1).a > 0.5:
			c += 1
	return float(c) / float(w)

func _corner_bg(img: Image) -> Vector3:
	var w := img.get_width()
	var h := img.get_height()
	var sum := Vector3.ZERO
	var cnt := 0
	for o in [Vector2i(4, 4), Vector2i(w - 12, 4), Vector2i(4, h - 12), Vector2i(w - 12, h - 12)]:
		for dy in 8:
			for dx in 8:
				var c := img.get_pixel(o.x + dx, o.y + dy)
				sum += Vector3(c.r, c.g, c.b)
				cnt += 1
	return sum / cnt

func _montage(items: Array) -> void:
	items.sort_custom(func(a, b): return a.name < b.name)
	var cols := 10
	var box := 150
	var pad := 6
	var label_h := 30
	var rows := int(ceil(float(items.size()) / cols))
	var cwid := box + pad
	var chgt := box + pad + label_h
	var out := Image.create(cols * cwid + pad, rows * chgt + pad, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.30, 0.30, 0.34))
	for i in items.size():
		var im: Image = items[i].img.duplicate()
		var iw := im.get_width()
		var ih := im.get_height()
		var scale := minf(float(box) / iw, float(box) / ih)
		var nw := maxi(1, int(iw * scale))
		var nh := maxi(1, int(ih * scale))
		im.resize(nw, nh, Image.INTERPOLATE_NEAREST)
		var col := i % cols
		var row := i / cols
		var cellx := pad + col * cwid
		var celly := pad + row * chgt
		for yy in box:
			for xx in box:
				var ck := ((xx / 10) + (yy / 10)) % 2 == 0
				out.set_pixel(cellx + xx, celly + label_h + yy,
					Color(0.55, 0.55, 0.58) if ck else Color(0.42, 0.42, 0.45))
		var ox := cellx + (box - nw) / 2
		var oy := celly + label_h + (box - nh) / 2
		out.blend_rect(im, Rect2i(0, 0, nw, nh), Vector2i(ox, oy))
	out.save_png(MONTAGE)
