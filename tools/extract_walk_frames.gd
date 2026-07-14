extends SceneTree
## Extract the interior-astronaut walk frames from the captain's green-screen
## sheet (labelled rows: RIGHT / LEFT / DOWN / UP walks ×7 + 4 stills).
## NOTE the sheet's UP/DOWN labels are camera-inverted for a top-down game:
## the "DOWN" row shows the BACK (backpack) and "UP" shows the FRONT (visor).
## We name by what the pixels show: front_* = visor rows, back_* = backpack —
## the player script maps front→moving down-screen, back→moving up-screen.
## Every frame is saved on ONE common canvas, feet bottom-aligned and centred,
## so animation never jitters from per-frame crop differences.
## Run: godot --headless -s tools/extract_walk_frames.gd --path .

const SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/frames5/ChatGPT Image Jul 14, 2026, 02_30_48 AM (10).png"
const OUT := "res://assets/sprites/walk"
const MERGE_PAD := 8       # px gap that still counts as the same figure
const MIN_AREA := 900      # ignore stray specks
const MIN_FIG_H := 80      # anything shorter is a row LABEL (white text), not a figure
const HELMET_W := 68.0     # normalise every frame so the helmet is this wide —
                           # pose-independent, so the astronaut stays ONE size
                           # across frames, directions and idle/walk switches
const ROW_H := 120.0       # second pass: each direction's MEDIAN body height →
                           # this, so turning never snaps the figure bigger or
                           # smaller; within-row stride bob is preserved
# frames5 sheet layout (same as frames4): 4 rows (RIGHT / LEFT / FRONT /
# BACK), 4 walk figures + 1 STILL at the row's end. KEEP order IS playback
# order — derived with tools/analyze_walk.gd (pairwise-diff BEST LOOP) plus
# a gait read tracking BOTH legs across frames (contact → push-off → trail
# lift → swing → plant). right/front/back share the sheet's convention;
# left's sheet order already IS the cycle (optimizer agrees, cost 0.493).
const IDLE_INDEX := 4
# hand-picked from sheet (10) of frames5 — the only sheet drawn per-direction
# ("SIDE VIEW RIGHT/LEFT", "FRONT VIEW", "BACK VIEW"), judged across all ten
# at 2x zoom. Sides play in sheet order; front/back use the optimizer's loop.
const KEEP := {
	"right": [0, 1, 2, 3],
	"left": [0, 1, 2, 3],
	"front": [0, 3, 1, 2],
	"back": [0, 3, 1, 2],
}
# per-frame scale corrections where the helmet detector mis-measured (hand
# verified against siblings): left walk frame 0 came out ~8% oversized
const REFIT := {"left": {0: 0.944}}

var _img: Image
var _w := 0
var _h := 0
var _seen := {}


func _green(c: Color) -> bool:
	# green screen — green clearly dominates both other channels. Threshold is
	# LOW so the dark-green feet shadows painted on the screen key out too
	# (the game draws its own foot shadow; baked ones would double up)
	return c.g > 0.16 and c.g > c.r * 1.35 and c.g > c.b * 1.35


func _init() -> void:
	_img = Image.load_from_file(SRC)
	_img.convert(Image.FORMAT_RGBA8)
	_w = _img.get_width()
	_h = _img.get_height()

	# key out the green, keep everything else
	for y in _h:
		for x in _w:
			var c := _img.get_pixel(x, y)
			if _green(c):
				_img.set_pixel(x, y, Color(0, 0, 0, 0))

	# connected components (grid-coarsened for speed), merged with a pad
	var comps: Array = _components()
	# drop the row LABELS: black boxes (older sheets) or short white text runs
	var frames: Array = []
	for r: Rect2i in comps:
		if r.size.y < MIN_FIG_H:
			continue
		if _black_frac(r) > 0.35:
			continue
		frames.append(r)
	print("figures found: %d (of %d comps)" % [frames.size(), comps.size()])

	# group into rows by vertical overlap, sort rows by y, frames by x
	frames.sort_custom(func(a, b): return a.position.y < b.position.y)
	var rows: Array = []
	for r in frames:
		var placed := false
		for row in rows:
			var ry: Vector2 = row[0]   # y-range of the row
			if r.position.y < ry.y and r.end.y > ry.x:
				row[1].append(r)
				row[0] = Vector2(minf(ry.x, r.position.y), maxf(ry.y, r.end.y))
				placed = true
				break
		if not placed:
			rows.append([Vector2(r.position.y, r.end.y), [r]])
	rows.sort_custom(func(a, b): return a[0].x < b[0].x)

	# crop every figure, then rescale it so its HELMET is exactly HELMET_W wide
	# — bbox height varies with the stride (legs apart = shorter), but the
	# helmet is the same size in every pose, so it's the true scale anchor
	var scaled: Array = []          # [row][frame] -> Image
	for i in rows.size():
		var lst: Array = rows[i][1]
		lst.sort_custom(func(a, b): return a.position.x < b.position.x)
		var out_row: Array = []
		for r: Rect2i in lst:
			var crop := _img.get_region(r)
			var hw := _helmet_w(crop)
			var k := HELMET_W / float(hw)
			crop.resize(int(round(crop.get_width() * k)),
				int(round(crop.get_height() * k)), Image.INTERPOLATE_LANCZOS)
			out_row.append(crop)
		scaled.append(out_row)

	# per-direction height equalisation: one factor per row, from the median of
	# its WALK frames; the matching still (row 4) gets its row's factor too
	var factor: Array = []
	for i in 4:
		var hs: Array = []
		for img: Image in scaled[i]:
			hs.append(img.get_height())
		hs.sort()
		var med: float = 0.5 * (hs[hs.size() / 2] + hs[(hs.size() - 1) / 2])
		factor.append(ROW_H / med)
	for i in scaled.size():
		var out_row: Array = scaled[i]
		for j in out_row.size():
			var k2: float = factor[i] if i < 4 else factor[mini(j, 3)]
			var img: Image = out_row[j]
			img.resize(int(round(img.get_width() * k2)),
				int(round(img.get_height() * k2)), Image.INTERPOLATE_LANCZOS)

	# hand scale corrections (REFIT) — applied on top of the two auto passes
	var rnames := ["right", "left", "front", "back"]
	for i in mini(rows.size(), 4):
		var fixes: Dictionary = REFIT.get(rnames[i], {})
		for j in fixes:
			if j < scaled[i].size():
				var fimg: Image = scaled[i][j]
				var fk: float = fixes[j]
				fimg.resize(int(round(fimg.get_width() * fk)),
					int(round(fimg.get_height() * fk)), Image.INTERPOLATE_LANCZOS)

	# ONE canvas for every frame: global max w/h of the NORMALISED figures
	var cw := 0
	var ch := 0
	for out_row in scaled:
		for img: Image in out_row:
			cw = maxi(cw, img.get_width())
			ch = maxi(ch, img.get_height())
	print("common canvas: %dx%d" % [cw, ch])

	# rows in sheet order — frames3 labels are correct: RIGHT, LEFT, FRONT, BACK
	var names := ["right", "left", "front", "back"]
	var out_dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):   # wipe stale frames first
		if f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + "/" + f)
	for i in rows.size():
		var out_row: Array = scaled[i]
		if i < 4:
			# frame IDLE_INDEX is the standing still; KEEP lists the cycle
			var keep: Array = KEEP[names[i]]
			for j in keep.size():
				_save(out_row[keep[j]], cw, ch, "%s_%d" % [names[i], j])
			_save(out_row[IDLE_INDEX], cw, ch, "%s_idle" % names[i])
			print("row %s: kept %d walk + idle (of %d)" % [
				names[i], keep.size(), out_row.size()])
	quit(0)


func _black_frac(r: Rect2i) -> float:
	var dark := 0
	var tot := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := _img.get_pixel(x, y)
			if c.a < 0.1:
				continue
			tot += 1
			if maxf(c.r, maxf(c.g, c.b)) < 0.16:
				dark += 1
	return 0.0 if tot == 0 else float(dark) / float(tot)


func _helmet_w(img: Image) -> int:
	## widest opaque run in the top quarter of the figure — the helmet, the one
	## body part whose drawn size doesn't change with the pose
	var best := 1
	for y in maxi(img.get_height() / 4, 1):
		var minx := -1
		var maxx := -1
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.1:
				if minx < 0:
					minx = x
				maxx = x
		if minx >= 0:
			best = maxi(best, maxx - minx + 1)
	return best


func _save(img: Image, cw: int, ch: int, name: String) -> void:
	var out := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	# centre horizontally, FEET on the canvas bottom
	var ox := (cw - img.get_width()) / 2
	var oy := ch - img.get_height()
	out.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()),
		Vector2i(ox, oy))
	out.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))


func _components() -> Array:
	## flood-fill components over opaque pixels, then merge overlapping
	## (padded) boxes — same approach as extract_asteroids.gd
	var boxes: Array = []
	var visited := {}
	for y in range(0, _h, 2):
		for x in range(0, _w, 2):
			var k := y * _w + x
			if visited.has(k):
				continue
			if _img.get_pixel(x, y).a < 0.1:
				continue
			# BFS
			var minx := x
			var maxx := x
			var miny := y
			var maxy := y
			var area := 0
			var stack: Array = [Vector2i(x, y)]
			visited[k] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				area += 1
				minx = mini(minx, p.x)
				maxx = maxi(maxx, p.x)
				miny = mini(miny, p.y)
				maxy = maxi(maxy, p.y)
				for d: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
					var q: Vector2i = p + d
					if q.x < 0 or q.y < 0 or q.x >= _w or q.y >= _h:
						continue
					var qk: int = q.y * _w + q.x
					if visited.has(qk):
						continue
					if _img.get_pixel(q.x, q.y).a < 0.1:
						continue
					visited[qk] = true
					stack.append(q)
			if area * 4 >= MIN_AREA:
				boxes.append(Rect2i(minx, miny, maxx - minx + 2, maxy - miny + 2))
	# merge boxes closer than MERGE_PAD
	var changed := true
	while changed:
		changed = false
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				var a: Rect2i = boxes[i].grow(MERGE_PAD)
				if a.intersects(boxes[j]):
					boxes[i] = boxes[i].merge(boxes[j])
					boxes.remove_at(j)
					changed = true
					break
			if changed:
				break
	return boxes
