extends SceneTree
## CROPPER B (round 2) — extract the FULL set of individual space-trash sprites
## from green-screen sheets 6..10 (the files ending (6)(7)(8)(9)(10)). Each sheet
## is a regular 5-row x 4-col grid of 20 machine/debris items on bright green.
##
## Method (unchanged green key, curation REMOVED — now saves the whole set):
##  1. GLOBAL GREEN key on a green-dominance test -> removes the background AND
##     any bright-green halo/pocket seen through an item's holes. Teal/cyan glow
##     survives (g not >1.25x b).
##  2. Green-despill + feather the 1px fringe so no green halo remains.
##  3. Connected components over opaque pixels (drop specks below MIN_AREA).
##  4. GRID-AWARE pick: assign each component to its 5x4 cell by centre; the
##     LARGEST component in a cell is the main item. One whole item per cell ->
##     never half-cut, never merged with a neighbour.
##  5. Trim to the item's opaque bbox (+PAD transparent padding), save RGBA.
##
## The original 14 curated sprites trash_b01..b14.png are KEPT untouched. Every
## other cleanly-croppable cell across all 5 sheets is added continuing at
## trash_b15.png, EXCEPT: exact/near-identical duplicates of an already-kept
## sprite (dropped), and the one pure-GREEN medical-cross module on sheet 10
## (cell r0c3) whose cross the key would punch (SKIPped).
##
## Re-runnable: on each run it deletes trash_b<NN>.png for NN>KEEP and rebuilds.
## Run: godot --headless -s tools/crop_trash_b.gd --path .

const SRC_DIR := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/trash/"
const SHEETS := {
	6: "ChatGPT Image Jul 14, 2026, 09_57_11 PM (6).png",
	7: "ChatGPT Image Jul 14, 2026, 09_57_11 PM (7).png",
	8: "ChatGPT Image Jul 14, 2026, 09_57_11 PM (8).png",
	9: "ChatGPT Image Jul 14, 2026, 09_57_11 PM (9).png",
	10: "ChatGPT Image Jul 14, 2026, 09_57_12 PM (10).png",
}
const DST := "res://assets/sprites/trash"
const MONTAGE := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/trash_b_montage.png"
const ROWS := 5
const COLS := 4
const KEY_TOL := 0.34     # distance from corner bg colour that still keys out
const MIN_AREA := 1200    # drop loose debris specks / tiny fragments
const PAD := 3            # transparent padding around each trimmed item
const KEEP := 14          # trash_b01..b14 are the kept curated originals
const DEDUP_TOL := 0.045  # mean per-channel byte diff (0..1) below = duplicate
# cells to skip entirely: sheet -> [ [row,col], ... ]
const SKIP := {10: [[0, 3]]}   # sheet 10 r0c3 = pure-green medical-cross module


func _init() -> void:
	var out_dir := ProjectSettings.globalize_path(DST)
	DirAccess.make_dir_recursive_absolute(out_dir)

	# --- keep b01..bKEEP, wipe any previously-generated b>KEEP so re-runs are clean ---
	for f in DirAccess.get_files_at(out_dir):
		if f.begins_with("trash_b") and f.ends_with(".png"):
			var n := int(f.trim_prefix("trash_b").trim_suffix(".png"))
			if n > KEEP:
				DirAccess.remove_absolute(out_dir + "/" + f)

	# --- load the kept originals: for the montage (in order) and for dedup sigs ---
	var kept_imgs: Array = []
	var sigs: Array = []            # PackedByteArray 32x32 signatures to dedup against
	for i in range(1, KEEP + 1):
		var p := "%s/trash_b%02d.png" % [out_dir, i]
		if not FileAccess.file_exists(p):
			continue
		var im := Image.load_from_file(p)
		im.convert(Image.FORMAT_RGBA8)
		kept_imgs.append(im)
		sigs.append(_sig(im))

	var new_imgs: Array = []
	var idx := KEEP
	var dropped_dup := 0
	var skipped := 0

	for sheet in SHEETS:
		var res := _extract(sheet, SRC_DIR + SHEETS[sheet])
		var comps: Array = res   # Array of {img:Image, row:int, col:int}
		var kept_this := 0
		for item in comps:
			var row: int = item.row
			var col: int = item.col
			if _is_skipped(sheet, row, col):
				skipped += 1
				continue
			var piece: Image = item.img
			var sig := _sig(piece)
			var dup := false
			for s in sigs:
				if _sig_diff(sig, s) < DEDUP_TOL:
					dup = true
					break
			if dup:
				dropped_dup += 1
				continue
			idx += 1
			sigs.append(sig)
			new_imgs.append(piece)
			piece.save_png("%s/trash_b%02d.png" % [out_dir, idx])
			kept_this += 1
		print("sheet %d: kept %d new item(s)" % [sheet, kept_this])

	print("----")
	print("originals kept: %d  |  new added: %d  |  dup dropped: %d  |  skipped: %d"
		% [kept_imgs.size(), new_imgs.size(), dropped_dup, skipped])
	print("TOTAL trash_b*.png: %d" % (kept_imgs.size() + new_imgs.size()))

	# --- green-fringe diagnostic over every final sprite ---
	var all_imgs: Array = kept_imgs + new_imgs
	var fringe_flags := 0
	for i in all_imgs.size():
		var fr := _fringe_count(all_imgs[i])
		if fr > 6:
			fringe_flags += 1
			print("  [FRINGE] trash_b%02d.png has %d green edge px" % [i + 1, fr])
	print("sprites with notable green fringe: %d" % fringe_flags)

	_montage(all_imgs)
	print("montage -> %s" % MONTAGE)
	quit(0)


func _is_skipped(sheet: int, row: int, col: int) -> bool:
	if not SKIP.has(sheet):
		return false
	for rc in SKIP[sheet]:
		if rc[0] == row and rc[1] == col:
			return true
	return false


func _extract(sheet: int, path: String) -> Array:
	var img := Image.load_from_file(path)
	if img == null:
		push_error("cannot load " + path)
		return []
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var bg := _corner_bg(img)

	# --- 1. GLOBAL green key ---
	for i in w * h:
		var x := i % w
		var y := i / w
		var c := img.get_pixel(x, y)
		var near := Vector3(c.r - bg.x, c.g - bg.y, c.b - bg.z).length() < KEY_TOL
		var greenish := c.g > 0.34 and c.g > c.r * 1.25 and c.g > c.b * 1.25
		if near or greenish:
			img.set_pixel(x, y, Color(0, 0, 0, 0))

	# --- 2. green-despill + feather the fringe ---
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

	# --- 3. connected components over opaque pixels (4-neighbour) ---
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

	# --- 4. grid-aware: largest component per 5x4 cell = the main item ---
	var cw := float(w) / COLS
	var ch := float(h) / ROWS
	var best := {}
	var best_area := {}
	for b in comps:
		var ctr := b.get_center()
		var col := clampi(int(ctr.x / cw), 0, COLS - 1)
		var row := clampi(int(ctr.y / ch), 0, ROWS - 1)
		var cell := row * COLS + col
		var a := b.size.x * b.size.y
		if not best.has(cell) or a > best_area[cell]:
			best[cell] = b
			best_area[cell] = a

	# --- 5. trim (+pad) and return per-cell items ---
	var out: Array = []
	for cell in best:
		var b: Rect2i = best[cell]
		var padded := Rect2i(
			maxi(b.position.x - PAD, 0),
			maxi(b.position.y - PAD, 0),
			mini(b.size.x + PAD * 2, w - maxi(b.position.x - PAD, 0)),
			mini(b.size.y + PAD * 2, h - maxi(b.position.y - PAD, 0)))
		var piece := img.get_region(padded)
		var row: int = cell / COLS
		var col: int = cell % COLS
		out.append({"img": piece, "row": row, "col": col})
	print("sheet %d: %d comps -> %d cells" % [sheet, comps.size(), out.size()])
	return out


## 32x32 RGBA8 signature bytes for near-duplicate detection.
func _sig(im: Image) -> PackedByteArray:
	var t := im.duplicate()
	t.resize(32, 32, Image.INTERPOLATE_NEAREST)
	return t.get_data()


func _sig_diff(a: PackedByteArray, b: PackedByteArray) -> float:
	var n := mini(a.size(), b.size())
	if n == 0:
		return 1.0
	var s := 0
	for i in n:
		s += absi(a[i] - b[i])
	return float(s) / float(n) / 255.0


## count opaque edge pixels that are still green-dominant (leftover fringe)
func _fringe_count(im: Image) -> int:
	var w := im.get_width()
	var h := im.get_height()
	var cnt := 0
	for y in h:
		for x in w:
			var c := im.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var edge := false
			for o in [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]:
				var ox: int = o[0]
				var oy: int = o[1]
				if ox < 0 or oy < 0 or ox >= w or oy >= h or im.get_pixel(ox, oy).a < 0.5:
					edge = true
					break
			if edge and c.g > 0.35 and c.g > c.r * 1.15 and c.g > c.b * 1.15:
				cnt += 1
	return cnt


func _montage(imgs: Array) -> void:
	var cols := 8
	var box := 240        # each item fitted into this square (native ~250-310px)
	var pad := 8
	var rows := int(ceil(float(imgs.size()) / cols))
	var out := Image.create(cols * (box + pad) + pad, rows * (box + pad) + pad, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.5, 0.5, 0.53))
	for i in imgs.size():
		var t: Image = imgs[i].duplicate()
		var iw := t.get_width()
		var ih := t.get_height()
		var scale := minf(float(box) / iw, float(box) / ih)
		var nw := maxi(1, int(iw * scale))
		var nh := maxi(1, int(ih * scale))
		t.resize(nw, nh, Image.INTERPOLATE_NEAREST)
		var col := i % cols
		var row := i / cols
		var ox := pad + col * (box + pad) + (box - nw) / 2
		var oy := pad + row * (box + pad) + (box - nh) / 2
		out.blend_rect(t, Rect2i(0, 0, nw, nh), Vector2i(ox, oy))
	out.save_png(MONTAGE)


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
