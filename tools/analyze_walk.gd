extends SceneTree
## Measure the extracted walk frames: opaque bbox per frame (figure size),
## helmet width (top-quarter width — pose-independent size reference), and
## pairwise similarity within each row (duplicate detection).
## Run: godot --headless -s tools/analyze_walk.gd --path .

const DIR := "res://assets/sprites/walk"
const SETS := {
	"right": 4, "left": 4, "front": 4, "back": 4,
}


func _init() -> void:
	for dir_name in SETS:
		var names: Array = []
		for i in SETS[dir_name]:
			names.append("%s_%d" % [dir_name, i])
		names.append("%s_idle" % dir_name)
		var imgs: Array = []
		print("== %s ==" % dir_name)
		for nm in names:
			var img := Image.load_from_file(ProjectSettings.globalize_path(
				"%s/%s.png" % [DIR, nm]))
			img.convert(Image.FORMAT_RGBA8)
			imgs.append(img)
			var bb := _bbox(img)
			var hw := _helmet_w(img, bb)
			print("  %-12s bbox %3dx%3d  helmet_w %3d" % [nm, bb.size.x, bb.size.y, hw])
		# full pairwise diff of the walk frames (not idle)
		var n: int = SETS[dir_name]
		var D := []
		for a in n:
			D.append([])
			for b in n:
				D[a].append(0.0)
		for a in n:
			var line := "  d%d:" % a
			for b in range(a + 1, n):
				var d := _diff(imgs[a], imgs[b])
				D[a][b] = d
				D[b][a] = d
				line += " %d=%.3f" % [b, d]
			print(line)
		# SMOOTHEST LOOP: the cyclic order minimising total adjacent diff —
		# a real walk cycle is exactly that. Brute force all orders (fix 0
		# first; both directions equivalent).
		var idxs: Array = range(1, n)
		var best_order: Array = []
		var best_cost := INF
		for perm in _perms(idxs):
			var order: Array = [0]
			order.append_array(perm)
			var cost := 0.0
			for i in n:
				cost += D[order[i]][order[(i + 1) % n]]
			if cost < best_cost:
				best_cost = cost
				best_order = order
		var worst := 0.0
		for i in n:
			worst = maxf(worst, D[best_order[i]][best_order[(i + 1) % n]])
		print("  BEST LOOP: %s  total=%.3f  worst-step=%.3f" % [
			str(best_order), best_cost, worst])
	quit(0)


func _perms(arr: Array) -> Array:
	if arr.size() <= 1:
		return [arr]
	var out: Array = []
	for i in arr.size():
		var rest := arr.duplicate()
		rest.remove_at(i)
		for p in _perms(rest):
			var q: Array = [arr[i]]
			q.append_array(p)
			out.append(q)
	return out


func _bbox(img: Image) -> Rect2i:
	var minx := img.get_width()
	var maxx := 0
	var miny := img.get_height()
	var maxy := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.1:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)


func _helmet_w(img: Image, bb: Rect2i) -> int:
	## widest opaque run inside the top quarter of the figure — the helmet.
	var best := 0
	for y in range(bb.position.y, bb.position.y + maxi(bb.size.y / 4, 1)):
		var minx := -1
		var maxx := -1
		for x in range(bb.position.x, bb.end.x):
			if img.get_pixel(x, y).a > 0.1:
				if minx < 0:
					minx = x
				maxx = x
		if minx >= 0:
			best = maxi(best, maxx - minx + 1)
	return best


func _diff(a: Image, b: Image) -> float:
	## mean per-pixel difference (alpha-weighted) on the shared canvas
	var tot := 0.0
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if ca.a < 0.1 and cb.a < 0.1:
				continue
			n += 1
			tot += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) \
				+ absf(ca.a - cb.a)
	return 1.0 if n == 0 else tot / (n * 4.0)
