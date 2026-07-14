extends SceneTree
## Condition the green-screen dialog expression art into game-ready figures.
## Run: <godot> --headless -s tools/prep_dialog_figures.gd --path .
##
## Per character SET:
##   1. chroma-key the green screen + despill the green edge halo
##   2. normalize scale so every pose's HEAD width matches the set's neutral
##   3. place on ONE common canvas per set — bottom-aligned, feet-centred —
##      so the body never moves or resizes when expressions swap in-game
##   4. save as res://assets/sprites/crew/dialog/<name>_<expr>.png
## Also writes conditioned contact sheets to the scratchpad for eyeballing.

const SRC := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker"
const SHEETS := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad"
const OUT_DIR := "res://assets/sprites/crew/dialog"
const TARGET_H := 1400.0        # neutral pose content height, all sets

# expr slug -> source file, per set. Cataloged by eye from contact sheets;
# player dupes (9 of 18) skipped on purpose.
const SETS := {
	"player": {
		"talk": "main_character_dialogs/ChatGPT Image Jul 14, 2026, 01_43_09 AM (1).png",
		"neutral": "main_character_dialogs/ChatGPT Image Jul 14, 2026, 01_43_22 AM (1).png",
		"ask": "main_character_dialogs/ChatGPT Image Jul 14, 2026, 01_43_22 AM (2).png",
		"shrug": "main_character_dialogs/ChatGPT Image Jul 14, 2026, 01_43_10 AM (2).png",
		"point": "main_character_dialogs/ChatGPT Image Jul 14, 2026, 01_43_10 AM (3).png",
		"wave": "main_character_dialogs/ChatGPT Image Jul 14, 2026, 01_43_22 AM (3).png",
		"offer": "main_character_dialogs/ChatGPT Image Jul 14, 2026, 01_43_22 AM (4).png",
		"think": "main_character_dialogs/ChatGPT Image Jul 14, 2026, 01_43_23 AM (5).png",
		"wait": "main_character_dialogs/ChatGPT Image Jul 14, 2026, 01_43_23 AM (6).png",
	},
	"juno": {
		"neutral": "characters/JUNO/dialog/ChatGPT Image Jul 14, 2026, 02_09_20 AM (1).png",
		"offer": "characters/JUNO/dialog/ChatGPT Image Jul 14, 2026, 02_09_20 AM (2).png",
		"talk": "characters/JUNO/dialog/ChatGPT Image Jul 14, 2026, 02_09_21 AM (3).png",
		"earnest": "characters/JUNO/dialog/ChatGPT Image Jul 14, 2026, 02_09_21 AM (4).png",
		"warn": "characters/JUNO/dialog/ChatGPT Image Jul 14, 2026, 02_09_21 AM (5).png",
		"think": "characters/JUNO/dialog/ChatGPT Image Jul 14, 2026, 02_09_22 AM (6).png",
		"point": "characters/JUNO/dialog/ChatGPT Image Jul 14, 2026, 02_09_22 AM (7).png",
		"serious": "characters/JUNO/dialog/ChatGPT Image Jul 14, 2026, 02_09_22 AM (8).png",
		"grin": "characters/JUNO/dialog/ChatGPT Image Jul 14, 2026, 02_09_23 AM (9).png",
		"tada": "characters/JUNO/dialog/ChatGPT Image Jul 14, 2026, 02_09_23 AM (10).png",
	},
	"mira": {
		"neutral": "characters/MIRA/dialog/ChatGPT Image Jul 14, 2026, 02_13_03 AM (1).png",
		"offer": "characters/MIRA/dialog/ChatGPT Image Jul 14, 2026, 02_13_04 AM (2).png",
		"point": "characters/MIRA/dialog/ChatGPT Image Jul 14, 2026, 02_13_06 AM (3).png",
		"think": "characters/MIRA/dialog/ChatGPT Image Jul 14, 2026, 02_13_06 AM (4).png",
		"earnest": "characters/MIRA/dialog/ChatGPT Image Jul 14, 2026, 02_13_06 AM (5).png",
		"talk": "characters/MIRA/dialog/ChatGPT Image Jul 14, 2026, 02_13_07 AM (6).png",
		"wave": "characters/MIRA/dialog/ChatGPT Image Jul 14, 2026, 02_13_07 AM (7).png",
		"show": "characters/MIRA/dialog/ChatGPT Image Jul 14, 2026, 02_13_08 AM (8).png",
		"worried": "characters/MIRA/dialog/ChatGPT Image Jul 14, 2026, 02_13_08 AM (9).png",
		"tablet": "characters/MIRA/dialog/ChatGPT Image Jul 14, 2026, 02_13_09 AM (10).png",
	},
	"hale": {
		"talk": "characters/HALE/dialog/ChatGPT Image Jul 14, 2026, 01_56_48 AM (1).png",
		"offer": "characters/HALE/dialog/ChatGPT Image Jul 14, 2026, 01_56_49 AM (2).png",
		"shrug": "characters/HALE/dialog/ChatGPT Image Jul 14, 2026, 01_56_50 AM (3).png",
		"neutral": "characters/HALE/dialog/ChatGPT Image Jul 14, 2026, 01_56_50 AM (4).png",
		"point": "characters/HALE/dialog/ChatGPT Image Jul 14, 2026, 01_56_51 AM (5).png",
		"annoyed": "characters/HALE/dialog/ChatGPT Image Jul 14, 2026, 01_56_53 AM (6).png",
		"wave": "characters/HALE/dialog/ChatGPT Image Jul 14, 2026, 01_56_54 AM (7).png",
		"rant": "characters/HALE/dialog/ChatGPT Image Jul 14, 2026, 01_56_55 AM (8).png",
		"think": "characters/HALE/dialog/ChatGPT Image Jul 14, 2026, 01_56_56 AM (9).png",
		"stop": "characters/HALE/dialog/ChatGPT Image Jul 14, 2026, 01_56_57 AM (10).png",
	},
	"sola": {
		"neutral": "characters/SOLA/dialog/ChatGPT Image Jul 14, 2026, 02_18_31 AM (1).png",
		"offer": "characters/SOLA/dialog/ChatGPT Image Jul 14, 2026, 02_18_31 AM (2).png",
		"point": "characters/SOLA/dialog/ChatGPT Image Jul 14, 2026, 02_18_31 AM (3).png",
		"think": "characters/SOLA/dialog/ChatGPT Image Jul 14, 2026, 02_18_32 AM (4).png",
		"earnest": "characters/SOLA/dialog/ChatGPT Image Jul 14, 2026, 02_18_32 AM (5).png",
		"talk": "characters/SOLA/dialog/ChatGPT Image Jul 14, 2026, 02_18_32 AM (6).png",
		"wave": "characters/SOLA/dialog/ChatGPT Image Jul 14, 2026, 02_18_33 AM (7).png",
		"thumbs": "characters/SOLA/dialog/ChatGPT Image Jul 14, 2026, 02_18_33 AM (8).png",
		"show": "characters/SOLA/dialog/ChatGPT Image Jul 14, 2026, 02_18_33 AM (9).png",
		"shrug": "characters/SOLA/dialog/ChatGPT Image Jul 14, 2026, 02_18_34 AM (10).png",
	},
	"vega": {
		"neutral": "characters/VEGA/dialog/ChatGPT Image Jul 14, 2026, 02_22_47 AM (1).png",
		"present": "characters/VEGA/dialog/ChatGPT Image Jul 14, 2026, 02_22_48 AM (2).png",
		"point": "characters/VEGA/dialog/ChatGPT Image Jul 14, 2026, 02_22_48 AM (3).png",
		"think": "characters/VEGA/dialog/ChatGPT Image Jul 14, 2026, 02_22_49 AM (4).png",
		"earnest": "characters/VEGA/dialog/ChatGPT Image Jul 14, 2026, 02_22_49 AM (5).png",
		"explain": "characters/VEGA/dialog/ChatGPT Image Jul 14, 2026, 02_22_49 AM (6).png",
		"stop": "characters/VEGA/dialog/ChatGPT Image Jul 14, 2026, 02_22_50 AM (7).png",
		"thumbs": "characters/VEGA/dialog/ChatGPT Image Jul 14, 2026, 02_22_50 AM (8).png",
		"shrug": "characters/VEGA/dialog/ChatGPT Image Jul 14, 2026, 02_22_50 AM (9).png",
		"show": "characters/VEGA/dialog/ChatGPT Image Jul 14, 2026, 02_22_51 AM (10).png",
	},
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for set_name in SETS:
		_process_set(set_name, SETS[set_name])
	print("DONE")
	quit()


func _process_set(set_name: String, files: Dictionary) -> void:
	print("=== %s ===" % set_name)
	var imgs := {}      # expr -> keyed Image
	var boxes := {}     # expr -> Rect2i content bbox
	var bodies := {}    # expr -> crown-to-feet height (px, source scale)
	var feet := {}      # expr -> feet centre x (px, source scale)
	for expr in files:
		var img := Image.load_from_file(SRC + "/" + files[expr])
		if img == null:
			push_error("load failed: " + str(files[expr]))
			continue
		img.convert(Image.FORMAT_RGBA8)
		_key_and_despill(img)
		var bb := _bbox(img)
		imgs[expr] = img
		boxes[expr] = bb
		feet[expr] = _feet_cx(img, bb)
		# body height = feet line to head CROWN on the body axis. Head width
		# (widest run in the bbox top quarter) proved unreliable — a hand at
		# the chin or a raised palm merges with the face run and shrank whole
		# figures by up to 20%. Crown height ignores arms entirely.
		var crown := _crown_y(img, bb, feet[expr])
		bodies[expr] = bb.end.y - crown
		print("  %s: bbox=%s body_h=%d feet_cx=%d" % [expr, bb, bodies[expr], feet[expr]])
	if not imgs.has("neutral"):
		push_error(set_name + ": no neutral base, skipping set")
		return

	# scale so every crown-to-feet height matches neutral's, and neutral
	# content = TARGET_H — heads/bodies then render identical across the set
	var base_bb: Rect2i = boxes["neutral"]
	var s_base := TARGET_H / float(base_bb.size.y)
	var scales := {}
	var max_l := 0.0
	var max_r := 0.0
	var max_h := 0.0
	for expr in imgs:
		var s: float = s_base * float(bodies["neutral"]) / maxf(float(bodies[expr]), 1.0)
		scales[expr] = s
		var bb: Rect2i = boxes[expr]
		max_l = maxf(max_l, (float(feet[expr]) - bb.position.x) * s)
		max_r = maxf(max_r, (float(bb.end.x) - float(feet[expr])) * s)
		max_h = maxf(max_h, bb.size.y * s)

	var pad := 6
	var canvas_w := int(ceil(max_l + max_r)) + pad * 2
	var canvas_h := int(ceil(max_h)) + pad
	var anchor_x := pad + max_l
	print("  canvas %dx%d anchor_x=%.0f" % [canvas_w, canvas_h, anchor_x])

	# contact sheet of the conditioned set on a dark bg (fringe check)
	var cols := 5
	var cell_s := 0.22
	var cw := int(canvas_w * cell_s) + 8
	var ch := int(canvas_h * cell_s) + 8
	var rows := int(ceil(float(imgs.size()) / cols))
	var sheet := Image.create(cols * cw, rows * ch, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.07, 0.08, 0.1))

	var order := imgs.keys()
	order.sort()
	var i := 0
	for expr in order:
		var s: float = scales[expr]
		var bb: Rect2i = boxes[expr]
		var content: Image = (imgs[expr] as Image).get_region(bb)
		var sw := maxi(int(round(bb.size.x * s)), 1)
		var sh := maxi(int(round(bb.size.y * s)), 1)
		content.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
		var canvas := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
		var dx := int(round(anchor_x - (float(feet[expr]) - bb.position.x) * s))
		var dy := canvas_h - pad / 2 - sh
		canvas.blit_rect(content, Rect2i(Vector2i.ZERO, content.get_size()), Vector2i(dx, dy))
		canvas.save_png(OUT_DIR + "/" + set_name + "_" + expr + ".png")

		var thumb := canvas.duplicate() as Image
		thumb.resize(int(canvas_w * cell_s), int(canvas_h * cell_s), Image.INTERPOLATE_BILINEAR)
		sheet.blend_rect(thumb, Rect2i(Vector2i.ZERO, thumb.get_size()),
			Vector2i((i % cols) * cw + 4, (i / cols) * ch + 4))
		i += 1
	sheet.save_png(SHEETS + "/cond_" + set_name + ".png")
	print("  sheet order: " + ", ".join(order))


func _key_and_despill(img: Image) -> void:
	## Pass 1 — chroma key: green-dominant pixels go transparent. The delta
	## term (g minus the next channel) separates the vivid screen green
	## (delta 0.85-0.95, measured) from MIRA's sage-green suit (delta <= 0.20)
	## which the plain ratio rule was eating.
	## Pass 2 — despill: opaque pixels that still lean green AND sit within
	## 2 px of keyed background (the anti-aliased halo), plus any strongly
	## green remnant anywhere, get their green pulled down to max(r, b) so
	## no green fringe survives against the dark scene.
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.g > 0.16 and c.g > c.r * 1.35 and c.g > c.b * 1.35 \
					and c.g - maxf(c.r, c.b) > 0.30:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var leans := c.g > c.r * 1.08 and c.g > c.b * 1.08
			if not leans:
				continue
			var strong := c.g > c.r * 1.35 and c.g > c.b * 1.35 \
				and c.g - maxf(c.r, c.b) > 0.22
			if strong or _near_alpha(img, x, y, w, h):
				c.g = maxf(c.r, c.b)
				img.set_pixel(x, y, c)


func _near_alpha(img: Image, x: int, y: int, w: int, h: int) -> bool:
	for dy in range(-2, 3):
		var yy := y + dy
		if yy < 0 or yy >= h:
			return true      # canvas edge counts — halo hugs the border too
		for dx in range(-2, 3):
			var xx := x + dx
			if xx < 0 or xx >= w:
				return true
			if img.get_pixel(xx, yy).a <= 0.0:
				return true
	return false


func _bbox(img: Image) -> Rect2i:
	var minx := img.get_width()
	var maxx := 0
	var miny := img.get_height()
	var maxy := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.05:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	return Rect2i(minx, miny, maxi(maxx - minx + 1, 1), maxi(maxy - miny + 1, 1))


func _crown_y(img: Image, bb: Rect2i, feet_cx: int) -> int:
	## topmost opaque pixel within +/-100 px of the body axis — the head
	## crown. Raised hands/pointing arms sit off-axis so they don't register.
	var x0 := maxi(bb.position.x, feet_cx - 100)
	var x1 := mini(bb.end.x, feet_cx + 101)
	for y in range(bb.position.y, bb.end.y):
		for x in range(x0, x1):
			if img.get_pixel(x, y).a > 0.1:
				return y
	return bb.position.y


func _feet_cx(img: Image, bb: Rect2i) -> int:
	## centroid x of the bottom 6% of the content — a stable body anchor that
	## ignores arm poses, so the figure never slides when expressions swap
	var y0 := bb.end.y - maxi(int(bb.size.y * 0.06), 4)
	var sum := 0.0
	var n := 0
	for y in range(y0, bb.end.y):
		for x in range(bb.position.x, bb.end.x):
			if img.get_pixel(x, y).a > 0.1:
				sum += x
				n += 1
	return int(sum / maxf(n, 1.0))
