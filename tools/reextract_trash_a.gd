extends SceneTree
## RE-EXTRACT trash_a from green-screen sheets 1-5 with UNCLAMPED connected
## components (no grid cell) AND masked copy, so no item is ever half-cropped and
## no NEIGHBOUR/debris bleeds into the padding. Green-key + edge despill from
## crop_trash_a.gd. Each opaque pixel is labelled by component; components below
## MIN_AREA are dropped (loose specks). Components whose padded bounds touch merge
## into one item (body + its own detached chunks). The final crop copies ONLY the
## pixels carrying that item's labels onto a transparent canvas sized to the true
## bbox + PAD -> guaranteed transparent margin on all four sides (no clip, no
## bleed). Writes candidates to a scratch dir + labelled montage for visual QA.
## Run: godot --headless -s tools/reextract_trash_a.gd --path .

const DIR := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/trash/"
const FILES := [
	"ChatGPT Image Jul 14, 2026, 09_57_09 PM (1).png",
	"ChatGPT Image Jul 14, 2026, 09_57_09 PM (2).png",
	"ChatGPT Image Jul 14, 2026, 09_57_10 PM (3).png",
	"ChatGPT Image Jul 14, 2026, 09_57_10 PM (4).png",
	"ChatGPT Image Jul 14, 2026, 09_57_10 PM (5).png",
]
const CAND := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/cand_a"
const MONTAGE := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/cand_a_montage.png"
const MIN_AREA := 2600     # keep whole items, drop loose debris specks
const MERGE_PAD := 9       # item's own touching debris merges; neighbours never
const PAD := 4             # transparent padding around each crop


func _green(c: Color) -> bool:
	return c.g > 0.35 and c.g > c.r * 1.3 and c.g > c.b * 1.3


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(CAND)
	for f in DirAccess.get_files_at(CAND):
		DirAccess.remove_absolute(CAND + "/" + f)

	var thumbs: Array = []
	var labels_txt: Array = []
	var idx := 1
	for si in FILES.size():
		var img := Image.load_from_file(DIR + FILES[si])
		if img == null:
			push_error("cannot load " + FILES[si])
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()

		# 1) chroma-key
		for y in h:
			for x in w:
				if _green(img.get_pixel(x, y)):
					img.set_pixel(x, y, Color(0, 0, 0, 0))

		# 2) edge despill
		for y in h:
			for x in w:
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
						c.g = minf(c.g, maxf(c.r, c.b) * 1.08)
					img.set_pixel(x, y, c)

		# 3) connected components (BFS) with per-pixel labels. Kept components
		#    (area >= MIN_AREA) get a label >= 1; specks stay label 0 (excluded).
		var labels := PackedInt32Array()
		labels.resize(w * h)          # 0 = background/speck
		var seen := PackedByteArray()
		seen.resize(w * h)
		var comps := []               # {rect: Rect2i, labels: Array[int]}
		var next_label := 1
		for y0 in h:
			for x0 in w:
				var start := y0 * w + x0
				if seen[start] == 1 or img.get_pixel(x0, y0).a < 0.06:
					continue
				var minx := x0
				var maxx := x0
				var miny := y0
				var maxy := y0
				var pix: Array[int] = []
				var st: Array[int] = [start]
				seen[start] = 1
				while not st.is_empty():
					var p: int = st.pop_back()
					var px := p % w
					var py := p / w
					pix.append(p)
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
				if pix.size() >= MIN_AREA:
					var lab := next_label
					next_label += 1
					for p in pix:
						labels[p] = lab
					comps.append({"rect": Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1), "labels": [lab]})

		# 4) merge components whose padded bounds touch (item + own detached chunks)
		var changed := true
		while changed:
			changed = false
			for i in comps.size():
				for j in range(i + 1, comps.size()):
					if (comps[i].rect as Rect2i).grow(MERGE_PAD).intersects((comps[j].rect as Rect2i).grow(MERGE_PAD)):
						comps[i].rect = (comps[i].rect as Rect2i).merge(comps[j].rect)
						comps[i].labels.append_array(comps[j].labels)
						comps.remove_at(j)
						changed = true
						break
				if changed:
					break

		# 5) reading order
		comps.sort_custom(func(a, b):
			var ra := int((a.rect as Rect2i).get_center().y / 200.0)
			var rb := int((b.rect as Rect2i).get_center().y / 200.0)
			if ra != rb:
				return ra < rb
			return (a.rect as Rect2i).get_center().x < (b.rect as Rect2i).get_center().x)

		print("sheet %d: %d items" % [si + 1, comps.size()])
		for comp in comps:
			var rect: Rect2i = comp.rect
			var lset := {}
			for l in comp.labels:
				lset[l] = true
			# masked copy onto transparent canvas sized bbox + PAD (clamped to sheet)
			var r := rect.grow(PAD).intersection(Rect2i(0, 0, w, h))
			var crop := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
			crop.fill(Color(0, 0, 0, 0))
			for yy in range(r.position.y, r.position.y + r.size.y):
				for xx in range(r.position.x, r.position.x + r.size.x):
					if lset.has(labels[yy * w + xx]):
						crop.set_pixel(xx - r.position.x, yy - r.position.y, img.get_pixel(xx, yy))
			# tight-trim to real content then re-pad exactly PAD (belt & braces)
			crop = _trim_pad(crop, PAD)
			var name := "a%03d" % idx
			crop.save_png("%s/%s.png" % [CAND, name])
			thumbs.append(crop)
			labels_txt.append("%s s%d" % [name, si + 1])
			idx += 1

	print("TOTAL candidates: %d" % thumbs.size())
	_montage(thumbs, labels_txt)
	quit(0)


func _trim_pad(img: Image, pad: int) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.02:
				minx = mini(minx, x); maxx = maxi(maxx, x)
				miny = mini(miny, y); maxy = maxi(maxy, y)
	if maxx < 0:
		return img
	var cw := maxx - minx + 1
	var ch := maxy - miny + 1
	var out := Image.create(cw + pad * 2, ch + pad * 2, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(img, Rect2i(minx, miny, cw, ch), Vector2i(pad, pad))
	return out


func _montage(thumbs: Array, labels_txt: Array) -> void:
	var cols := 10
	var cell := 150
	var rows := int(ceil(float(thumbs.size()) / cols))
	var out := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.30, 0.30, 0.33))
	for i in thumbs.size():
		var t: Image = thumbs[i].duplicate()
		var s: float = float(cell - 20) / float(maxi(t.get_width(), t.get_height()))
		s = minf(s, 2.2)
		t.resize(maxi(int(t.get_width() * s), 1), maxi(int(t.get_height() * s), 1), Image.INTERPOLATE_NEAREST)
		var cx := (i % cols) * cell
		var cy := (i / cols) * cell
		var ox := cx + (cell - t.get_width()) / 2
		var oy := cy + (cell - t.get_height()) / 2
		# thin red frame exactly around the sprite crop bounds so any content
		# flush to a frame edge (i.e. a clip) is visible.
		for xx in range(ox - 1, ox + t.get_width() + 1):
			if xx >= 0 and xx < out.get_width():
				if oy - 1 >= 0: out.set_pixel(xx, oy - 1, Color(1, 0.2, 0.2))
				if oy + t.get_height() < out.get_height(): out.set_pixel(xx, oy + t.get_height(), Color(1, 0.2, 0.2))
		for yy in range(oy - 1, oy + t.get_height() + 1):
			if yy >= 0 and yy < out.get_height():
				if ox - 1 >= 0: out.set_pixel(ox - 1, yy, Color(1, 0.2, 0.2))
				if ox + t.get_width() < out.get_width(): out.set_pixel(ox + t.get_width(), yy, Color(1, 0.2, 0.2))
		out.blend_rect(t, Rect2i(0, 0, t.get_width(), t.get_height()), Vector2i(ox, oy))
	out.save_png(MONTAGE)
	print("montage -> ", MONTAGE)
	print("grid %d cols; red frame = exact crop bounds; content should NOT touch frame" % cols)
