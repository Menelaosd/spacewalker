extends SceneTree
## One-shot processor for the hand-painted ship art:
##   godot --headless --path . -s res://tools/process_ship_art.gd
## Reads tools/ship_source.png and produces assets/sprites/ship_hd.png:
##   1. kills the white background (flood fill from the borders only,
##      so white HULL panels are safe)
##   2. trims all empty margins
##   3. rotates bow-up -> bow-right (game convention: heading = +X)
##   4. downscales to a game-friendly size (Lanczos)

const SRC := "res://tools/ship_source.png"
const OUT := "res://assets/sprites/ship_hd.png"
const TARGET_LONG_AXIS := 300      # px after resize (drawn at 0.5 scale)
const WHITE_CUTOFF := 0.88         # how bright a border-connected pixel
const SAT_CUTOFF := 0.16           # must be (and how grey) to be background


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if img == null:
		push_error("ship_source.png not found at " + SRC)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	print("loaded ", w, "x", h)

	# --- 1. flood fill background from every border pixel ---
	var visited := PackedByteArray()
	visited.resize(w * h)
	var queue: Array[Vector2i] = []
	for x in w:
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, h - 1))
	for y in h:
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(w - 1, y))
	var cleared := 0
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var idx := p.y * w + p.x
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		var c := img.get_pixelv(p)
		# background = bright, desaturated, or already transparent
		var is_bg := c.a < 0.05 or (c.v > WHITE_CUTOFF and c.s < SAT_CUTOFF)
		if not is_bg:
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		cleared += 1
		queue.append(p + Vector2i(1, 0))
		queue.append(p + Vector2i(-1, 0))
		queue.append(p + Vector2i(0, 1))
		queue.append(p + Vector2i(0, -1))
	print("background cleared: ", cleared, " px")

	# soften leftover white fringe on the silhouette edge
	# (one erosion pass on pixels adjacent to transparency)
	var fringe := 0
	var base: Image = img.duplicate()
	for y in h:
		for x in w:
			var c := base.get_pixel(x, y)
			if c.a < 0.05:
				continue
			if c.v > WHITE_CUTOFF and c.s < SAT_CUTOFF:
				for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := Vector2i(x, y) + n
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h \
							and base.get_pixel(q.x, q.y).a < 0.05:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
						fringe += 1
						break
	print("fringe cleaned: ", fringe, " px")

	# --- 2. trim margins ---
	var used := img.get_used_rect()
	img = img.get_region(used)
	print("trimmed to ", img.get_width(), "x", img.get_height())

	# --- 3. the tapered spine is the BOW; it points down in the art,
	# so rotate counter-clockwise to put it on the right. The broad
	# twin-tower end is the stern — that's where the turbines live. ---
	img.rotate_90(COUNTERCLOCKWISE)

	# --- 4. downscale, longest axis to TARGET_LONG_AXIS ---
	var scale := float(TARGET_LONG_AXIS) / float(maxi(img.get_width(), img.get_height()))
	img.resize(int(img.get_width() * scale), int(img.get_height() * scale),
		Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("SHIP ART OK -> ", OUT, " ", img.get_width(), "x", img.get_height())
	quit()
