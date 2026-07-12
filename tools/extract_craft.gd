extends SceneTree
## One-shot: cut the captain's green-screen CRAFT and SALVAGE sheets into
## individual sprites for the crafting feature. Writes raw pieces + labeled
## contact sheets to the scratchpad for curation — nothing lands in assets/
## until the keep-list is decided (we only ship the curated ones).
##
## Keying is STRICT-DISTANCE to the sampled bg green (not "any greenish"),
## so plant foliage / hydroponics survive; despill only touches edge pixels.
## Run: godot --headless -s tools/extract_craft.gd --path .

const CRAFT_SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/craft"
const SALVAGE_SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/salvage"
const OUT := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad"

const CRAFT_SHEETS := {
	1: "ChatGPT Image Jul 12, 2026, 09_35_01 PM (1).png",
	2: "ChatGPT Image Jul 12, 2026, 09_35_02 PM (2).png",
	3: "ChatGPT Image Jul 12, 2026, 09_35_02 PM (3).png",
	4: "ChatGPT Image Jul 12, 2026, 09_35_02 PM (4).png",
	5: "ChatGPT Image Jul 12, 2026, 09_35_02 PM (5).png",
	6: "ChatGPT Image Jul 12, 2026, 09_35_12 PM (1).png",
	7: "ChatGPT Image Jul 12, 2026, 09_35_13 PM (2).png",
	8: "ChatGPT Image Jul 12, 2026, 09_35_13 PM (3).png",
	9: "ChatGPT Image Jul 12, 2026, 09_35_13 PM (4).png",
	10: "ChatGPT Image Jul 12, 2026, 09_35_13 PM (5).png",
}
const SALVAGE_SHEETS := {
	1: "ChatGPT Image Jul 12, 2026, 10_00_53 PM (1).png",
	2: "ChatGPT Image Jul 12, 2026, 10_00_53 PM (2).png",
	3: "ChatGPT Image Jul 12, 2026, 10_00_53 PM (3).png",
	4: "ChatGPT Image Jul 12, 2026, 10_00_54 PM (4).png",
	5: "ChatGPT Image Jul 12, 2026, 10_00_54 PM (5).png",
}

const MIN_AREA := 140
const KEY_DIST := 0.16      # colour distance to bg that counts as chroma


func _init() -> void:
	for d in ["craft_raw", "wreck_raw", "contact"]:
		DirAccess.make_dir_recursive_absolute(OUT + "/" + d)
	var total := 0
	for id in CRAFT_SHEETS:
		total += _cut_sheet(CRAFT_SRC + "/" + CRAFT_SHEETS[id],
			OUT + "/craft_raw", "c%d" % id, 8)
	for id in SALVAGE_SHEETS:
		total += _cut_grid(SALVAGE_SRC + "/" + SALVAGE_SHEETS[id],
			OUT + "/wreck_raw", "w%d" % id, 4, 5)
	print("extracted %d sprites total" % total)
	quit(0)


func _bg_color(img: Image) -> Color:
	# average the four corner patches — the chroma green
	var w := img.get_width()
	var h := img.get_height()
	var sum := Vector3.ZERO
	var n := 0
	for o in [Vector2i(4, 4), Vector2i(w - 12, 4), Vector2i(4, h - 12), Vector2i(w - 12, h - 12)]:
		for dy in 8:
			for dx in 8:
				var c := img.get_pixel(o.x + dx, o.y + dy)
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	return Color(sum.x / n, sum.y / n, sum.z / n)


func _key_image(path: String, aggressive := false) -> Image:
	## load a sheet and chroma-key its green to transparent (in place).
	## aggressive: also kill green-DOMINANT pixels anywhere — for the wreck
	## sheets, whose fine struts/mesh let bg bleed through everywhere.
	## NEVER aggressive on craft sheets (it would eat plant foliage).
	var img := Image.load_from_file(path)
	if img == null:
		push_error("cannot load " + path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var bg := _bg_color(img)

	# strict-distance chroma key — foliage greens are darker/desaturated
	# than the pure chroma green, so they survive
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var d := Vector3(c.r - bg.r, c.g - bg.g, c.b - bg.b).length()
			if d < KEY_DIST:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif aggressive:
				if c.g > 0.4 and c.g > c.r * 1.5 and c.g > c.b * 1.5:
					img.set_pixel(x, y, Color(0, 0, 0, 0))   # pure bleed
				elif c.g > 0.3 and c.g > c.r * 1.2 and c.g > c.b * 1.2:
					# green-tinged mix pixel — pull the green down
					c.g = maxf(c.r, c.b) * 1.1
					img.set_pixel(x, y, c)

	# edge-only despill + feather: opaque pixels touching transparency
	var edits: Array[Vector3i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < 0.5:
				continue
			var on_edge := false
			for o in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if o.x < 0 or o.y < 0 or o.x >= w or o.y >= h or img.get_pixel(o.x, o.y).a < 0.5:
					on_edge = true
					break
			if on_edge:
				edits.append(Vector3i(x, y, 0))
	for e in edits:
		var c := img.get_pixel(e.x, e.y)
		if c.g > c.r and c.g > c.b:
			c.g = minf(c.g, maxf(c.r, c.b) * 1.12)
		c.a = 0.85
		img.set_pixel(e.x, e.y, c)
	return img


func _cut_sheet(path: String, dst: String, tag: String, pad: int) -> int:
	## irregular grids (craft sheets): connected components + small merge pad
	var img := _key_image(path)
	if img == null:
		return 0
	var w := img.get_width()
	var h := img.get_height()

	# connected components (4-neighbor, iterative)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var boxes: Array[Rect2i] = []
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
			var stack: Array[int] = [idx]
			seen[idx] = 1
			while not stack.is_empty():
				var i: int = stack.pop_back()
				var px := i % w
				var py := i / w
				area += 1
				minx = mini(minx, px)
				maxx = maxi(maxx, px)
				miny = mini(miny, py)
				maxy = maxi(maxy, py)
				for n in [i - 1, i + 1, i - w, i + w]:
					if n < 0 or n >= w * h:
						continue
					if absi((n % w) - px) > 1:
						continue
					if seen[n] == 0 and img.get_pixel(n % w, n / w).a >= 0.06:
						seen[n] = 1
						stack.append(n)
			if area >= MIN_AREA:
				boxes.append(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))

	# merge padded bounds — wreck debris joins its hull with the big pad
	var changed := true
	while changed:
		changed = false
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				if boxes[i].grow(pad).intersects(boxes[j].grow(pad)):
					boxes[i] = boxes[i].merge(boxes[j])
					boxes.remove_at(j)
					changed = true
					break
			if changed:
				break

	# reading order: row bands by center y, then x
	boxes.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		var ba := int(a.get_center().y / 150.0)
		var bb := int(b.get_center().y / 150.0)
		if ba != bb:
			return ba < bb
		return a.get_center().x < b.get_center().x)

	var n := 0
	var pieces: Array[Image] = []
	for box in boxes:
		var piece := img.get_region(box)
		piece.save_png("%s/%s_%02d.png" % [dst, tag, n])
		pieces.append(piece)
		n += 1

	_contact_sheet(pieces, OUT + "/contact/%s.png" % tag)
	print("%s: %d sprites" % [tag, n])
	return n


func _cut_grid(path: String, dst: String, tag: String, cols: int, rows: int) -> int:
	## regular grids (salvage sheets, 4x5): slice fixed cells so every wreck
	## keeps its scattered debris, then crop each cell to its content bbox
	var img := _key_image(path, true)
	if img == null:
		return 0
	var w := img.get_width()
	var h := img.get_height()
	var cw := w / cols
	var ch := h / rows
	var n := 0
	var pieces: Array[Image] = []
	for ry in rows:
		for rx in cols:
			var cell := img.get_region(Rect2i(rx * cw, ry * ch, cw, ch))
			var box := cell.get_used_rect()
			if box.size.x * box.size.y < MIN_AREA:
				continue
			var piece := cell.get_region(box)
			piece.save_png("%s/%s_%02d.png" % [dst, tag, n])
			pieces.append(piece)
			n += 1
	_contact_sheet(pieces, OUT + "/contact/%s.png" % tag)
	print("%s: %d sprites" % [tag, n])
	return n


func _contact_sheet(pieces: Array[Image], out_path: String) -> void:
	## curation aid: every piece in a fixed grid, reading order = index.
	## 8 columns, 128px cells, gray checker border so extents are visible.
	const COLS := 8
	const CELL := 128
	var rows := int(ceil(pieces.size() / float(COLS)))
	var sheet := Image.create(COLS * CELL, maxi(rows, 1) * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.13, 0.13, 0.16))
	for i in pieces.size():
		var cx := (i % COLS) * CELL
		var cy := (i / COLS) * CELL
		# cell border
		for x in CELL:
			sheet.set_pixel(cx + x, cy, Color(0.3, 0.3, 0.36))
			sheet.set_pixel(cx + x, cy + CELL - 1, Color(0.3, 0.3, 0.36))
		for y in CELL:
			sheet.set_pixel(cx, cy + y, Color(0.3, 0.3, 0.36))
			sheet.set_pixel(cx + CELL - 1, cy + y, Color(0.3, 0.3, 0.36))
		var p := pieces[i].duplicate() as Image
		var s := minf((CELL - 10) / float(p.get_width()), (CELL - 10) / float(p.get_height()))
		if s < 1.0:
			p.resize(maxi(int(p.get_width() * s), 1), maxi(int(p.get_height() * s), 1),
				Image.INTERPOLATE_LANCZOS)
		var ox := cx + (CELL - p.get_width()) / 2
		var oy := cy + (CELL - p.get_height()) / 2
		sheet.blend_rect(p, Rect2i(0, 0, p.get_width(), p.get_height()), Vector2i(ox, oy))
	sheet.save_png(out_path)
