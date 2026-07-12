extends SceneTree
## One-shot asset conditioner for the five rescuable crew.
##
## Each character ships six source images (green-screen or painted): a profile
## bust, a repaired top-down ship, a wrecked ship (how you find them), a small
## in-ship token, a CREW ID card, and a large dialog figure. This tool:
##   * green-keys the four transparent-background types via BORDER FLOOD FILL
##     (so it never eats MIRA's greenhouse windows or green suit — only the
##     background that touches the frame edge is removed),
##   * de-spills the 1px key fringe and feathers its alpha,
##   * autocrops to content, then pads each TYPE to one shared canvas across
##     all five crew so they drop into the engine at identical proportions,
##   * copies the profiles and the dark-background IDs through untouched.
## Run: Godot --headless -s tools/prep_crew.gd --path .

const SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/characters"
const OUT := "res://assets/sprites/crew"

# type -> how to place it on the shared canvas ("center" | "bottom")
const ANCHOR := {
	"ship": "center", "wreck": "center", "token": "bottom", "figure": "bottom",
	"id": "center",
}

# character -> {type: source filename}
const MAP := {
	"hale": {
		"profile": "ChatGPT Image Jul 12, 2026, 02_58_27 PM (3).png",
		"ship":    "ChatGPT Image Jul 12, 2026, 02_58_28 PM (8).png",
		"wreck":   "ChatGPT Image Jul 12, 2026, 03_49_41 PM (1).png",
		"token":   "ChatGPT Image Jul 12, 2026, 04_45_05 PM (3).png",
		"id":      "ChatGPT Image Jul 12, 2026, 05_00_23 PM (3).png",
		"figure":  "ChatGPT Image Jul 12, 2026, 06_28_01 PM (3).png",
	},
	"juno": {
		"profile": "ChatGPT Image Jul 12, 2026, 02_58_27 PM (1).png",
		"ship":    "ChatGPT Image Jul 12, 2026, 02_58_28 PM (6).png",
		"wreck":   "ChatGPT Image Jul 12, 2026, 03_14_03 PM (5).png",
		"token":   "ChatGPT Image Jul 12, 2026, 04_45_05 PM (4).png",
		"id":      "ChatGPT Image Jul 12, 2026, 05_00_22 PM (1).png",
		"figure":  "ChatGPT Image Jul 12, 2026, 06_28_00 PM (1).png",
	},
	"mira": {
		"profile": "ChatGPT Image Jul 12, 2026, 02_58_27 PM (2).png",
		"ship":    "ChatGPT Image Jul 12, 2026, 02_58_28 PM (7).png",
		"wreck":   "ChatGPT Image Jul 12, 2026, 03_49_41 PM (2).png",
		"token":   "ChatGPT Image Jul 12, 2026, 04_45_05 PM (1).png",
		"id":      "ChatGPT Image Jul 12, 2026, 05_00_22 PM (2).png",
		"figure":  "ChatGPT Image Jul 12, 2026, 06_28_01 PM (2).png",
	},
	"sola": {
		"profile": "ChatGPT Image Jul 12, 2026, 02_58_27 PM (4).png",
		"ship":    "ChatGPT Image Jul 12, 2026, 02_58_29 PM (9).png",
		"wreck":   "ChatGPT Image Jul 12, 2026, 03_14_02 PM (2).png",
		"token":   "ChatGPT Image Jul 12, 2026, 04_45_05 PM (2).png",
		"id":      "ChatGPT Image Jul 12, 2026, 05_00_23 PM (4).png",
		"figure":  "ChatGPT Image Jul 12, 2026, 06_28_01 PM (4).png",
	},
	"vega": {
		"profile": "ChatGPT Image Jul 12, 2026, 02_58_28 PM (5).png",
		"ship":    "ChatGPT Image Jul 12, 2026, 03_04_58 PM.png",
		"wreck":   "ChatGPT Image Jul 12, 2026, 03_14_03 PM (4).png",
		"token":   "ChatGPT Image Jul 12, 2026, 04_45_05 PM (5).png",
		"id":      "ChatGPT Image Jul 12, 2026, 05_00_23 PM (5).png",
		"figure":  "ChatGPT Image Jul 12, 2026, 06_28_01 PM (5).png",
	},
}

const DIRS := {"hale": "HALE", "juno": "JUNO", "mira": "MIRA", "sola": "SOLA", "vega": "VEGA"}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	# --- copy the painted profiles straight through (scene bg is intentional) ---
	for c in MAP:
		var img := _load(c, "profile")
		if img == null:
			continue
		img.save_png("%s/%s_profile.png" % [OUT, c])
		print("copied  %s_profile  %dx%d" % [c, img.get_width(), img.get_height()])

	# --- key + autocrop the transparent types, hold them for padding ---
	# ships/token/figure are green-screen; the ID is a card on near-black.
	var keyed := {}          # type -> {char -> Image}
	var canvas := {}         # type -> Vector2i (max content bbox)
	for t in ["ship", "wreck", "token", "figure", "id"]:
		keyed[t] = {}
		var mx := Vector2i.ZERO
		for c in MAP:
			var img := _load(c, t)
			if img == null:
				continue
			if t == "id":
				_key_black(img)
			else:
				_key_green(img)
			img = _autocrop(img)
			keyed[t][c] = img
			mx.x = maxi(mx.x, img.get_width())
			mx.y = maxi(mx.y, img.get_height())
			print("keyed   %s_%s  -> %dx%d" % [c, t, img.get_width(), img.get_height()])
		# pad the shared canvas a touch so nothing kisses the edge
		canvas[t] = mx + Vector2i(8, 8)

	# --- pad every image of a type onto that type's shared canvas ---
	for t in keyed:
		var cv: Vector2i = canvas[t]
		var anchor: String = ANCHOR[t]
		for c in keyed[t]:
			var src: Image = keyed[t][c]
			var out := Image.create(cv.x, cv.y, false, Image.FORMAT_RGBA8)
			out.fill(Color(0, 0, 0, 0))
			var px := int((cv.x - src.get_width()) / 2.0)
			var py: int
			if anchor == "bottom":
				py = cv.y - src.get_height() - 4
			else:
				py = int((cv.y - src.get_height()) / 2.0)
			out.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(px, py))
			out.save_png("%s/%s_%s.png" % [OUT, c, t])
			print("padded  %s_%s  -> %dx%d" % [c, t, cv.x, cv.y])

	print("done.")
	quit()


func _load(c: String, t: String) -> Image:
	var path := "%s/%s/%s" % [SRC, DIRS[c], MAP[c][t]]
	var img := Image.load_from_file(path)
	if img == null:
		push_warning("missing: " + path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


# ---------------------------------------------------------------------------
#  Border flood-fill chroma key. Only background green connected to the frame
#  edge is removed; enclosed greens (plants, suits) survive.
# ---------------------------------------------------------------------------
func _key_green(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()          # PackedByteArray, RGBA8
	var bg := _sample_bg(data, w, h)

	var keyed := PackedByteArray()
	keyed.resize(w * h)                  # 0 = keep, 1 = background
	var stack := PackedInt32Array()

	for x in w:
		_seed(stack, keyed, data, w, x, 0, bg)
		_seed(stack, keyed, data, w, x, h - 1, bg)
	for y in h:
		_seed(stack, keyed, data, w, 0, y, bg)
		_seed(stack, keyed, data, w, w - 1, y, bg)

	while stack.size() > 0:
		var idx := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var x := idx % w
		var y := idx / w
		if x > 0:      _grow(stack, keyed, data, w, idx - 1, x - 1, y, bg)
		if x < w - 1:  _grow(stack, keyed, data, w, idx + 1, x + 1, y, bg)
		if y > 0:      _grow(stack, keyed, data, w, idx - w, x, y - 1, bg)
		if y < h - 1:  _grow(stack, keyed, data, w, idx + w, x, y + 1, bg)

	# second pass: kill leftover PURE background-green trapped in enclosed
	# pockets (between limbs, under an arm) that the border flood can't reach.
	# A tight chroma match — the muted suit/plant greens are nowhere near it.
	for i in w * h:
		if keyed[i] == 0 and _is_pure_bg(data, i, bg):
			keyed[i] = 1

	# apply: clear keyed pixels; de-spill + feather the boundary ring
	for i in w * h:
		var base := i * 4
		if keyed[i] == 1:
			data[base + 3] = 0
			continue
		var x := i % w
		var y := i / w
		var edge := (x > 0 and keyed[i - 1] == 1) or (x < w - 1 and keyed[i + 1] == 1) \
			or (y > 0 and keyed[i - w] == 1) or (y < h - 1 and keyed[i + w] == 1)
		if not edge:
			continue
		var r := data[base] / 255.0
		var g := data[base + 1] / 255.0
		var b := data[base + 2] / 255.0
		var rb := maxf(r, b)
		if g > rb:                        # green fringe -> pull green down
			var excess := g - rb
			data[base + 1] = int(rb * 255.0)
			var a := clampf(1.0 - excess * 2.2, 0.3, 1.0)
			data[base + 3] = int(data[base + 3] * a)

	var out := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	img.copy_from(out)


# ---------------------------------------------------------------------------
#  Border flood-fill knock-out of the near-black ID background. Flood spreads
#  only through dark pixels reachable from the frame edge, so the bright silver
#  card halts it — enclosed darks (photo backdrop, text) survive. The soft drop
#  shadow is ramped out by luminance so there's no dark halo left floating.
# ---------------------------------------------------------------------------
const _DARK_HI := 0.34   # flood spreads through anything darker than this
const _RAMP_LO := 0.10   # <= this luminance -> fully transparent
const _RAMP_HI := 0.30   # >= this -> keep (card edge / bevel)

func _key_black(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var keyed := PackedByteArray()
	keyed.resize(w * h)
	var stack := PackedInt32Array()

	for x in w:
		_seed_dark(stack, keyed, data, x, 0, w)
		_seed_dark(stack, keyed, data, x, h - 1, w)
	for y in h:
		_seed_dark(stack, keyed, data, 0, y, w)
		_seed_dark(stack, keyed, data, w - 1, y, w)

	while stack.size() > 0:
		var idx := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var x := idx % w
		var y := idx / w
		if x > 0:      _grow_dark(stack, keyed, data, idx - 1)
		if x < w - 1:  _grow_dark(stack, keyed, data, idx + 1)
		if y > 0:      _grow_dark(stack, keyed, data, idx - w)
		if y < h - 1:  _grow_dark(stack, keyed, data, idx + w)

	for i in w * h:
		if keyed[i] == 0:
			continue
		var base := i * 4
		var lum := _lum(data, base)
		var a := clampf((lum - _RAMP_LO) / (_RAMP_HI - _RAMP_LO), 0.0, 1.0)
		data[base + 3] = int(data[base + 3] * a)

	var out := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	img.copy_from(out)


func _seed_dark(stack: PackedInt32Array, keyed: PackedByteArray,
		data: PackedByteArray, x: int, y: int, w: int) -> void:
	var idx := y * w + x
	if keyed[idx] == 0 and _lum(data, idx * 4) < _DARK_HI:
		keyed[idx] = 1
		stack.push_back(idx)


func _grow_dark(stack: PackedInt32Array, keyed: PackedByteArray,
		data: PackedByteArray, nidx: int) -> void:
	if keyed[nidx] == 0 and _lum(data, nidx * 4) < _DARK_HI:
		keyed[nidx] = 1
		stack.push_back(nidx)


func _lum(data: PackedByteArray, base: int) -> float:
	return (0.299 * data[base] + 0.587 * data[base + 1] + 0.114 * data[base + 2]) / 255.0


func _seed(stack: PackedInt32Array, keyed: PackedByteArray, data: PackedByteArray,
		w: int, x: int, y: int, bg: Vector3) -> void:
	var idx := y * w + x
	if keyed[idx] == 0 and _is_bg(data, idx, bg):
		keyed[idx] = 1
		stack.push_back(idx)


func _grow(stack: PackedInt32Array, keyed: PackedByteArray, data: PackedByteArray,
		_w: int, nidx: int, _x: int, _y: int, bg: Vector3) -> void:
	if keyed[nidx] == 0 and _is_bg(data, nidx, bg):
		keyed[nidx] = 1
		stack.push_back(nidx)


func _is_bg(data: PackedByteArray, idx: int, bg: Vector3) -> bool:
	var base := idx * 4
	var r := data[base] / 255.0
	var g := data[base + 1] / 255.0
	var b := data[base + 2] / 255.0
	if not (g > r * 1.12 and g > b * 1.12):   # must be green-dominant
		return false
	var dr := r - bg.x
	var dg := g - bg.y
	var db := b - bg.z
	return dr * dr + dg * dg + db * db < 0.12  # near the sampled background


func _is_pure_bg(data: PackedByteArray, idx: int, bg: Vector3) -> bool:
	# unmistakable bright chroma green, very close to the sampled background
	var base := idx * 4
	var r := data[base] / 255.0
	var g := data[base + 1] / 255.0
	var b := data[base + 2] / 255.0
	if not (g > r * 1.5 and g > b * 1.5):
		return false
	var dr := r - bg.x
	var dg := g - bg.y
	var db := b - bg.z
	return dr * dr + dg * dg + db * db < 0.05


func _sample_bg(data: PackedByteArray, w: int, h: int) -> Vector3:
	# average the four corner patches — the background is a flat green
	var acc := Vector3.ZERO
	var n := 0
	var corners: Array[Vector2i] = [Vector2i(6, 6), Vector2i(w - 16, 6), Vector2i(6, h - 16), Vector2i(w - 16, h - 16)]
	for corner in corners:
		for dy in 10:
			for dx in 10:
				var base: int = ((corner.y + dy) * w + (corner.x + dx)) * 4
				acc += Vector3(data[base], data[base + 1], data[base + 2])
				n += 1
	return acc / (n * 255.0)


func _autocrop(img: Image) -> Image:
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return img
	return img.get_region(used)
