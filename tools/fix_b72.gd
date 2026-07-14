extends SceneTree
## Re-crop trash_b72 correctly: sheet 9 cell r4c3. Same green-key + despill as the
## original tool, but take the MODULE (largest component in the cell) by its TRUE
## global connected-component bbox, dropping the detached debris cube / neighbour
## sliver. Trim tight + small pad. Overwrites assets/sprites/trash/trash_b72.png.
const SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/trash/ChatGPT Image Jul 14, 2026, 09_57_11 PM (9).png"
const DST := "res://assets/sprites/trash/trash_b72.png"
const ROWS := 5
const COLS := 4
const KEY_TOL := 0.34
const MIN_AREA := 1200
const PAD := 4

func _init() -> void:
	var img := Image.load_from_file(SRC)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var bg := _corner_bg(img)
	# green key
	for i in w * h:
		var x := i % w
		var y := i / w
		var c := img.get_pixel(x, y)
		var near := Vector3(c.r - bg.x, c.g - bg.y, c.b - bg.z).length() < KEY_TOL
		var greenish := c.g > 0.34 and c.g > c.r * 1.25 and c.g > c.b * 1.25
		if near or greenish:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	# despill + feather
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
	# components (global)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var comps: Array = []   # {rect, area}
	for y in h:
		for x in w:
			var idx := y * w + x
			if seen[idx] == 1 or img.get_pixel(x, y).a < 0.06:
				continue
			var minx := x; var maxx := x; var miny := y; var maxy := y; var area := 0
			var st: Array[int] = [idx]
			seen[idx] = 1
			while not st.is_empty():
				var p: int = st.pop_back()
				var px := p % w; var py := p / w
				area += 1
				minx = mini(minx, px); maxx = maxi(maxx, px)
				miny = mini(miny, py); maxy = maxi(maxy, py)
				for n in [p - 1, p + 1, p - w, p + w]:
					if n < 0 or n >= w * h: continue
					if absi((n % w) - px) > 1: continue
					if seen[n] == 0 and img.get_pixel(n % w, n / w).a >= 0.06:
						seen[n] = 1
						st.append(n)
			if area >= MIN_AREA:
				comps.append({"rect": Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1), "area": area})
	# pick largest component whose centre lands in cell r4c3
	var cw := float(w) / COLS
	var chf := float(h) / ROWS
	var best = null
	for c in comps:
		var ctr: Vector2 = c.rect.get_center()
		var col := clampi(int(ctr.x / cw), 0, COLS - 1)
		var row := clampi(int(ctr.y / chf), 0, ROWS - 1)
		if row == 4 and col == 3:
			if best == null or c.area > best.area:
				best = c
	if best == null:
		push_error("module component not found")
		quit(1)
		return
	var b: Rect2i = best.rect
	print("module bbox: x=%d..%d y=%d..%d  (%dx%d) area=%d" % [b.position.x, b.position.x + b.size.x - 1, b.position.y, b.position.y + b.size.y - 1, b.size.x, b.size.y, best.area])
	var padded := Rect2i(
		maxi(b.position.x - PAD, 0),
		maxi(b.position.y - PAD, 0), 0, 0)
	padded.size.x = mini(b.size.x + PAD * 2, w - padded.position.x)
	padded.size.y = mini(b.size.y + PAD * 2, h - padded.position.y)
	# mask out anything NOT belonging to the module component (kills debris cube /
	# neighbour sliver that fall inside the padded rect) by keeping only pixels
	# within the module bbox.
	var piece := img.get_region(padded)
	# zero out pixels of the region that are outside the module's tight bbox
	var offx := b.position.x - padded.position.x
	var offy := b.position.y - padded.position.y
	for py in piece.get_height():
		for px in piece.get_width():
			if px < offx or px >= offx + b.size.x or py < offy or py >= offy + b.size.y:
				piece.set_pixel(px, py, Color(0, 0, 0, 0))
	piece.save_png(ProjectSettings.globalize_path(DST))
	print("saved %s  (%dx%d)" % [DST, piece.get_width(), piece.get_height()])
	quit(0)

func _corner_bg(img: Image) -> Vector3:
	var w := img.get_width(); var h := img.get_height()
	var sum := Vector3.ZERO; var cnt := 0
	for o in [Vector2i(4, 4), Vector2i(w - 12, 4), Vector2i(4, h - 12), Vector2i(w - 12, h - 12)]:
		for dy in 8:
			for dx in 8:
				var c := img.get_pixel(o.x + dx, o.y + dy)
				sum += Vector3(c.r, c.g, c.b); cnt += 1
	return sum / cnt
