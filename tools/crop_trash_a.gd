extends SceneTree
## CROPPER A — extract individual space-trash sprites from green-screen sheets 1-5.
## Per-pixel green chroma-key (keeps interior holes transparent, e.g. trusses &
## door frames), edge despill to kill the fringe, then CONNECTED COMPONENTS over
## opaque pixels merged with a small pad so an item keeps its own scattered
## debris/cables but never merges its grid neighbours. Components below MIN_AREA
## are dropped (loose specks). Every piece is cropped to its true content bbox
## with a few px transparent padding, so nothing is halved.
##
## FULL-SET pass: extract EVERY cleanly-croppable item from all 5 sheets (~100),
## KEEP the hand-curated trash_a01..a14 already in assets/, dedup each new
## candidate against those 14 (they were picked from this same extraction, so
## their crops are pixel-identical) and against each other, then save the rest
## continuing the numbering trash_a15.png, a16.png, ...
## Run: godot --headless -s tools/crop_trash_a.gd --path .

const DIR := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/trash/"
const FILES := [
	"ChatGPT Image Jul 14, 2026, 09_57_09 PM (1).png",
	"ChatGPT Image Jul 14, 2026, 09_57_09 PM (2).png",
	"ChatGPT Image Jul 14, 2026, 09_57_10 PM (3).png",
	"ChatGPT Image Jul 14, 2026, 09_57_10 PM (4).png",
	"ChatGPT Image Jul 14, 2026, 09_57_10 PM (5).png",
]
const ASSETS := "assets/sprites/trash"   # res:// path; final home + existing a01..a14
const KEEP := 14                          # existing curated sprites to preserve
const MONTAGE := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/trash_a_montage.png"
const MIN_AREA := 2600     # keep whole items, drop loose debris specks
const MERGE_PAD := 9       # an item's own touching debris merges; neighbours (~70px apart) never
const PAD := 4             # transparent padding around each crop
const DUP_EXISTING := 0.045   # sig distance below this == same item as a curated one -> skip
const DUP_INTERNAL := 0.030   # stricter: only drop near-identical repeats between candidates


func _green(c: Color) -> bool:
	# bg is ~(0.03,0.90,0.10): green dominates hard. 1.3x also grabs the
	# anti-aliased fringe. Teal glow (high b) & orange glow (high r) survive.
	return c.g > 0.35 and c.g > c.r * 1.3 and c.g > c.b * 1.3


func _init() -> void:
	var cands: Array = []        # Image, cropped, reading order across all 5 sheets
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

		# 2) edge despill: neutralise green cast on opaque pixels bordering alpha
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

		# 3) connected components over opaque pixels (PackedByteArray BFS)
		var seen := PackedByteArray()
		seen.resize(w * h)
		var boxes: Array[Rect2i] = []
		for y0 in h:
			for x0 in w:
				var start := y0 * w + x0
				if seen[start] == 1 or img.get_pixel(x0, y0).a < 0.06:
					continue
				var minx := x0
				var maxx := x0
				var miny := y0
				var maxy := y0
				var area := 0
				var st: Array[int] = [start]
				seen[start] = 1
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

		# 4) merge boxes whose padded bounds touch (item + its own debris)
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

		# 5) order in reading order (row-band, then x) & crop with padding
		boxes.sort_custom(func(a, b):
			var ra := int(a.get_center().y / 200.0)
			var rb := int(b.get_center().y / 200.0)
			if ra != rb:
				return ra < rb
			return a.get_center().x < b.get_center().x)
		for b in boxes:
			var r := b.grow(PAD).intersection(Rect2i(0, 0, w, h))
			cands.append(img.get_region(r))
	print("TOTAL raw candidates across 5 sheets: %d" % cands.size())

	# ---- load existing curated a01..a14 & build their signatures ----
	var base := ProjectSettings.globalize_path("res://" + ASSETS)
	var existing: Array = []          # Image, for the final montage
	var keep_sigs: Array = []         # signatures of the curated 14
	for i in range(1, KEEP + 1):
		var p := "%s/trash_a%02d.png" % [base, i]
		var im := Image.load_from_file(p)
		if im == null:
			push_error("missing curated sprite " + p)
			continue
		im.convert(Image.FORMAT_RGBA8)
		existing.append(im)
		keep_sigs.append(_sig(im))

	# ---- dedup candidates vs curated 14 and vs each other, then save as a15+ ----
	var kept_sigs: Array = keep_sigs.duplicate()
	var next := KEEP + 1
	var added: Array = []             # Image, the newly saved sprites
	for c in cands:
		var s := _sig(c)
		var dup_ex := false
		for k in keep_sigs:
			if _dist(s, k) < DUP_EXISTING:
				dup_ex = true
				break
		if dup_ex:
			continue
		var dup_in := false
		for k in kept_sigs:
			if _dist(s, k) < DUP_INTERNAL:
				dup_in = true
				break
		if dup_in:
			continue
		var out_path := "%s/trash_a%02d.png" % [base, next]
		c.save_png(out_path)
		added.append(c)
		kept_sigs.append(s)
		print("saved trash_a%02d  %dx%d" % [next, c.get_width(), c.get_height()])
		next += 1

	print("kept existing: %d   added new: %d   TOTAL: %d" % [existing.size(), added.size(), existing.size() + added.size()])
	_montage(existing + added)
	quit(0)


func _sig(im: Image) -> PackedFloat32Array:
	# 32x32 downscale; alpha (silhouette) + premultiplied luma per cell.
	var s := im.duplicate()
	s.resize(32, 32, Image.INTERPOLATE_BILINEAR)
	var out := PackedFloat32Array()
	for y in 32:
		for x in 32:
			var col: Color = s.get_pixel(x, y)
			out.append(col.a)
			out.append((col.r + col.g + col.b) / 3.0 * col.a)
	return out


func _dist(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var acc := 0.0
	for i in a.size():
		acc += absf(a[i] - b[i])
	return acc / float(a.size())


func _montage(thumbs: Array) -> void:
	var cols := 8
	var cell := 180
	var z := 1.0
	var rows := int(ceil(float(thumbs.size()) / cols))
	var out := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.32, 0.32, 0.35))
	for i in thumbs.size():
		var t: Image = thumbs[i].duplicate()
		var s: float = float(cell - 12) / float(maxi(t.get_width(), t.get_height()))
		s = minf(s, 2.5)
		t.resize(maxi(int(t.get_width() * s), 1), maxi(int(t.get_height() * s), 1), Image.INTERPOLATE_NEAREST)
		var cx := (i % cols) * cell
		var cy := (i / cols) * cell
		var ox := cx + (cell - t.get_width()) / 2
		var oy := cy + (cell - t.get_height()) / 2
		out.blend_rect(t, Rect2i(0, 0, t.get_width(), t.get_height()), Vector2i(ox, oy))
		# index marker: small white bar whose length encodes tens+ones is overkill;
		# rely on the printed reading-order list instead.
	out.save_png(MONTAGE)
	print("montage -> ", MONTAGE)
