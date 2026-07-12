extends SceneTree
## One-shot: condition the captain's PLAYER dialog figure (back view, arm
## extended) — same treatment as the crew figures: border flood-fill green
## key, de-spill + feather, autocrop. Saved bottom-anchored as
## res://assets/sprites/crew/player_figure.png.
## Run: Godot --headless -s tools/prep_player.gd --path .

const SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/ChatGPT Image Jul 13, 2026, 12_55_47 AM.png"
const DST := "res://assets/sprites/crew/player_figure.png"
const TOL := 0.16


func _init() -> void:
	var img := Image.load_from_file(SRC)
	if img == null:
		push_error("cannot load " + SRC)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()

	# bg = average of corner patches
	var sum := Vector3.ZERO
	var n := 0
	for o in [Vector2i(4, 4), Vector2i(w - 12, 4), Vector2i(4, h - 12), Vector2i(w - 12, h - 12)]:
		for dy in 8:
			for dx in 8:
				var c := img.get_pixel(o.x + dx, o.y + dy)
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	var bg := Vector3(sum.x / n, sum.y / n, sum.z / n)

	# border flood fill over bg-colored pixels
	var keyed := PackedByteArray()
	keyed.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		for yy in [0, h - 1]:
			var y: int = yy
			var i: int = y * w + x
			if keyed[i] == 0 and _is_bg(img, x, y, bg):
				keyed[i] = 1
				stack.append(i)
	for y in h:
		for xx in [0, w - 1]:
			var x: int = xx
			var i2: int = y * w + x
			if keyed[i2] == 0 and _is_bg(img, x, y, bg):
				keyed[i2] = 1
				stack.append(i2)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % w
		var y := i / w
		for nb in [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]:
			var nx: int = nb[0]
			var ny: int = nb[1]
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var j: int = ny * w + nx
			if keyed[j] == 0 and _is_bg(img, nx, ny, bg):
				keyed[j] = 1
				stack.append(j)
	# enclosed pure-bg pockets (between arm and body)
	for i in w * h:
		if keyed[i] == 0:
			var c := img.get_pixel(i % w, i / w)
			if Vector3(c.r - bg.x, c.g - bg.y, c.b - bg.z).length() < TOL * 0.6:
				keyed[i] = 1

	# apply + edge despill/feather
	for i in w * h:
		var x := i % w
		var y := i / w
		if keyed[i] == 1:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	for i in w * h:
		var x := i % w
		var y := i / w
		var c := img.get_pixel(x, y)
		if c.a < 0.5:
			continue
		var edge := false
		for nb in [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]:
			var nx: int = nb[0]
			var ny: int = nb[1]
			if nx < 0 or ny < 0 or nx >= w or ny >= h \
					or img.get_pixel(nx, ny).a < 0.5:
				edge = true
				break
		if edge:
			if c.g > c.r and c.g > c.b:
				c.g = minf(c.g, maxf(c.r, c.b) * 1.12)
			c.a = 0.85
			img.set_pixel(x, y, c)

	var box := img.get_used_rect()
	var out := img.get_region(box)
	out.save_png(ProjectSettings.globalize_path(DST))
	print("player_figure  %dx%d (from %dx%d)" % [out.get_width(), out.get_height(), w, h])
	quit(0)


func _is_bg(img: Image, x: int, y: int, bg: Vector3) -> bool:
	var c := img.get_pixel(x, y)
	return Vector3(c.r - bg.x, c.g - bg.y, c.b - bg.z).length() < TOL
