extends SceneTree
## One-shot: cut the captain's green-screen sprite sheets into individual
## prop textures. Chroma-keys the green, de-spills edges, finds sprites as
## connected components (merging nearby parts so dashed frames and crate
## stacks stay whole), and saves each as res://assets/props/sN_RR.png
## named by sheet + reading order (row band, then x).
## Run: godot --headless -s tools/extract_props.gd

const SRC_DIR := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker"
const SHEETS := {
	1: "ChatGPT Image Jul 11, 2026, 08_10_20 PM (1).png",
	2: "ChatGPT Image Jul 11, 2026, 08_10_20 PM (2).png",
	3: "ChatGPT Image Jul 11, 2026, 08_10_22 PM (3).png",
	4: "ChatGPT Image Jul 11, 2026, 08_10_22 PM (4).png",
	5: "ChatGPT Image Jul 11, 2026, 08_10_22 PM (5).png",
	6: "ChatGPT Image Jul 11, 2026, 08_10_23 PM (6).png",
	7: "ChatGPT Image Jul 11, 2026, 08_10_24 PM (7).png",
	8: "ChatGPT Image Jul 11, 2026, 08_10_24 PM (8).png",
	9: "ChatGPT Image Jul 11, 2026, 08_10_25 PM (9).png",
	10: "ChatGPT Image Jul 11, 2026, 08_10_25 PM (10).png",
}
const DST_DIR := "res://assets/props"
const MERGE_PAD := 22       # bbox gap that still counts as one sprite
# sheet 3's small wall connectors sit close together — tighter merge
# there so T/cross/stub/corners come out as separate pieces
const PAD_OVERRIDE := {3: 6}
const MIN_AREA := 120       # ignore stray dust specks


func _is_green(c: Color) -> bool:
	return c.g > 0.35 and c.g > c.r * 1.5 and c.g > c.b * 1.5


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DST_DIR))
	var total := 0
	for id in SHEETS:
		total += _process_sheet(id, SRC_DIR + "/" + SHEETS[id])
	print("extracted %d props" % total)
	quit(0)


func _process_sheet(id: int, path: String) -> int:
	var img := Image.load_from_file(path)
	if img == null:
		push_error("cannot load " + path)
		return 0
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()

	# chroma key + despill
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if _is_green(c):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.g > c.r and c.g > c.b:
				# green fringe on edges — pull green down to the others
				img.set_pixel(x, y, Color(c.r, minf(c.g, maxf(c.r, c.b) * 1.15), c.b, c.a))

	# connected components over opaque pixels (4-neighbor, iterative)
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
						continue   # row wrap
					if seen[n] == 0 and img.get_pixel(n % w, n / w).a >= 0.06:
						seen[n] = 1
						stack.append(n)
			if area >= MIN_AREA:
				boxes.append(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))

	# merge boxes whose padded bounds touch (dashed frames, stacks)
	var pad: int = PAD_OVERRIDE.get(id, MERGE_PAD)
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

	# reading order: row bands (by center y, 140px bands), then x
	boxes.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		var ba := int(a.get_center().y / 140.0)
		var bb := int(b.get_center().y / 140.0)
		if ba != bb:
			return ba < bb
		return a.get_center().x < b.get_center().x)

	var n := 0
	for box in boxes:
		var piece := img.get_region(box)
		piece.save_png(ProjectSettings.globalize_path(
			"%s/s%d_%02d.png" % [DST_DIR, id, n]))
		n += 1
	print("sheet %d: %d props" % [id, n])
	return n
