extends SceneTree
## Cut the captain's asteroid sheet into per-category rock sprites.
## Each ROW (top→bottom) is an element CATEGORY by core colour. Instead of a
## rigid grid (which sliced rocks that overflow their cell), we chroma-key the
## green, find CONNECTED COMPONENTS (merging nearby pebbles so a rock stays
## whole), then bucket each component into its row-band → category. Every
## sprite is cropped to its own true content, so nothing is halved.
##
## Keying: global border flood-fill on a GREEN-DOMINANCE test removes the
## background AND the bright green halos, while enclosed coloured cores
## (incl. the green nonmetal row) survive — gray rock walls them off.
## Run: godot --headless -s tools/extract_asteroids.gd --path .

const SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/asteroids/ChatGPT Image Jul 13, 2026, 08_33_22 PM.png"
const DST := "res://assets/asteroids"
const ROWS := 9
const ROW_CAT := ["gas", "alkali", "precious", "metal", "alkaline",
	"metalloid", "nonmetal", "rare", "actinide"]
const KEY_TOL := 0.34
const MERGE_PAD := 6      # small: only a rock's OWN touching pebbles merge,
                          # never its grid neighbours (rows sit ~30px apart)
const MIN_AREA := 1500    # keep rock bodies; drop loose specks entirely


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DST))
	var img := Image.load_from_file(SRC)
	if img == null:
		push_error("cannot load " + SRC)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var bg := _corner_bg(img)

	# border flood-fill: bg + halos (green-dominant) → transparent
	var keyed := PackedByteArray()
	keyed.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		_seed(stack, keyed, img, x, 0, bg)
		_seed(stack, keyed, img, x, h - 1, bg)
	for y in h:
		_seed(stack, keyed, img, 0, y, bg)
		_seed(stack, keyed, img, w - 1, y, bg)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % w
		var y := i / w
		if x > 0: _seed(stack, keyed, img, x - 1, y, bg)
		if x < w - 1: _seed(stack, keyed, img, x + 1, y, bg)
		if y > 0: _seed(stack, keyed, img, x, y - 1, bg)
		if y < h - 1: _seed(stack, keyed, img, x, y + 1, bg)
	for i in w * h:
		if keyed[i] == 1:
			img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))

	# green-despill + feather the fringe
	for i in w * h:
		var x := i % w
		var y := i / w
		if img.get_pixel(x, y).a < 0.5:
			continue
		var edge := false
		for o in [[x-1,y],[x+1,y],[x,y-1],[x,y+1]]:
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

	# connected components over opaque pixels (4-neighbour, iterative)
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
				boxes.append(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))

	# merge boxes whose padded bounds touch (a rock + its scattered pebbles)
	var changed := true
	while changed:
		changed = false
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				if boxes[i].grow(MERGE_PAD).intersects(boxes[j].grow(MERGE_PAD)):
					boxes[i] = boxes[i].merge(boxes[j])
					boxes.remove_at(j)
					changed = true
					break
			if changed:
				break

	# bucket each rock into its row-band → category, ordered by x within row
	var band := float(h) / ROWS
	var per := {}
	for c in ROW_CAT:
		per[c] = []
	for b in boxes:
		var row := clampi(int(b.get_center().y / band), 0, ROWS - 1)
		per[ROW_CAT[row]].append(b)
	var total := 0
	for cat in ROW_CAT:
		var arr: Array = per[cat]
		arr.sort_custom(func(a, b): return a.get_center().x < b.get_center().x)
		for n in arr.size():
			var piece := img.get_region(arr[n])
			piece.save_png(ProjectSettings.globalize_path("%s/%s_%d.png" % [DST, cat, n]))
			total += 1
		print("%s: %d rocks" % [cat, arr.size()])
	print("extracted %d asteroid rocks total" % total)
	quit(0)


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


func _seed(stack: Array, keyed: PackedByteArray, img: Image, x: int, y: int, bg: Vector3) -> void:
	var i := y * img.get_width() + x
	if keyed[i] == 1:
		return
	var c := img.get_pixel(x, y)
	var near := Vector3(c.r - bg.x, c.g - bg.y, c.b - bg.z).length() < KEY_TOL
	var greenish := c.g > 0.34 and c.g > c.r * 1.25 and c.g > c.b * 1.25
	if near or greenish:
		keyed[i] = 1
		stack.append(i)
