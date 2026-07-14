extends SceneTree
## Remove small DISCONNECTED debris specks from trash_b69 (keeps every component
## >= KEEP_AREA, i.e. the claw body + gripper) and re-trim tight + pad.
## Overwrites the file. Operates on the already-correct sprite, so it cannot
## split the item.
const TARGET := "res://assets/sprites/trash/trash_b69.png"
const KEEP_AREA := 800
const PAD := 4

func _init() -> void:
	var p := ProjectSettings.globalize_path(TARGET)
	var img := Image.load_from_file(p)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var comps: Array = []   # {pixels:PackedInt32Array, area:int}
	for y in h:
		for x in w:
			var idx := y * w + x
			if seen[idx] == 1 or img.get_pixel(x, y).a < 0.06:
				continue
			var px_list := PackedInt32Array()
			var st: Array[int] = [idx]
			seen[idx] = 1
			while not st.is_empty():
				var pp: int = st.pop_back()
				px_list.append(pp)
				var px := pp % w; var py := pp / w
				for n in [pp - 1, pp + 1, pp - w, pp + w]:
					if n < 0 or n >= w * h: continue
					if absi((n % w) - px) > 1: continue
					if seen[n] == 0 and img.get_pixel(n % w, n / w).a >= 0.06:
						seen[n] = 1
						st.append(n)
			comps.append({"pixels": px_list, "area": px_list.size()})
	# blank out specks below KEEP_AREA
	var removed := 0
	for c in comps:
		if c.area < KEEP_AREA:
			removed += 1
			for pp in c.pixels:
				img.set_pixel(pp % w, pp / w, Color(0, 0, 0, 0))
	print("components: %d  removed specks: %d" % [comps.size(), removed])
	# tight bbox of remaining
	var minx := w; var miny := h; var maxx := -1; var maxy := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a >= 0.06:
				minx = mini(minx, x); maxx = maxi(maxx, x)
				miny = mini(miny, y); maxy = maxi(maxy, y)
	var rx := maxi(minx - PAD, 0)
	var ry := maxi(miny - PAD, 0)
	var rw := mini(maxx - minx + 1 + PAD * 2, w - rx)
	var rh := mini(maxy - miny + 1 + PAD * 2, h - ry)
	var piece := img.get_region(Rect2i(rx, ry, rw, rh))
	piece.save_png(p)
	print("saved %s  (%dx%d)" % [TARGET, piece.get_width(), piece.get_height()])
	quit(0)
