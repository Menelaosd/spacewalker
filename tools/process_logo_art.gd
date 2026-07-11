extends SceneTree
## One-shot: strip the painted logo's dark gradient backdrop.
## Flood-fills from the image borders through desaturated dark pixels —
## only backdrop connected to the edge dies, so the logo's own grays
## survive. Glow fringes stop the fill and keep their soft edge.
## Run: godot --headless -s tools/process_logo_art.gd

const SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/logo.png"
const DST := "res://assets/sprites/logo.png"


func _is_backdrop(c: Color) -> bool:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	var sat := (mx - mn) / mx if mx > 0.0 else 0.0
	return sat < 0.30 and mx < 0.62


func _init() -> void:
	var img := Image.load_from_file(SRC)
	if img == null:
		push_error("Could not load " + SRC)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()

	# BFS from every border pixel through backdrop-colored pixels
	var bg := PackedByteArray()
	bg.resize(w * h)
	var queue: Array[int] = []
	for x in w:
		queue.append(x)
		queue.append((h - 1) * w + x)
	for y in h:
		queue.append(y * w)
		queue.append(y * w + w - 1)
	while not queue.is_empty():
		var i: int = queue.pop_back()
		if bg[i] == 1:
			continue
		var px := i % w
		var py := i / w
		if not _is_backdrop(img.get_pixel(px, py)):
			continue
		bg[i] = 1
		if px > 0:
			queue.append(i - 1)
		if px < w - 1:
			queue.append(i + 1)
		if py > 0:
			queue.append(i - w)
		if py < h - 1:
			queue.append(i + w)

	# clear backdrop; feather the one-pixel boundary for a soft edge
	for y in h:
		for x in w:
			var i := y * w + x
			var c := img.get_pixel(x, y)
			if bg[i] == 1:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
			else:
				var near_bg := false
				for off in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
					var nx: int = x + off[0]
					var ny: int = y + off[1]
					if nx >= 0 and nx < w and ny >= 0 and ny < h \
							and bg[ny * w + nx] == 1:
						near_bg = true
						break
				if near_bg:
					img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.45))

	var used := img.get_used_rect()
	img = img.get_region(used)
	# halve it — 1536px source is far more than the title needs
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(DST))
	print("logo processed: ", img.get_width(), "x", img.get_height(), " -> ", DST)
	quit(0)
