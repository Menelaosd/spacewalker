extends SceneTree
## One-shot: process the latest "new" asset drop (game-assets/spacewalker/new):
##  - ship2.png   -> assets/sprites/ship_hd.png (green-keyed, bow rotated to +X)
##  - intro2.png  -> assets/sprites/title_bg.png (resized backdrop, no keying)
## Run: godot --headless -s tools/process_new_art.gd

const DIR := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/new/"
const SHIP_SRC := DIR + "ship2.png"
const BG_SRC := DIR + "intro2.png"
const SHIP_DST := "res://assets/sprites/ship_hd.png"
const BG_DST := "res://assets/sprites/title_bg.png"
const SHIP_TARGET_W := 340
const BG_TARGET_W := 1440


func _init() -> void:
	_ship()
	_bg()
	quit(0)


func _ship() -> void:
	var img := Image.load_from_file(SHIP_SRC)
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.g > 0.35 and c.g > c.r * 1.5 and c.g > c.b * 1.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.g > c.r and c.g > c.b:
				img.set_pixel(x, y,
					Color(c.r, minf(c.g, maxf(c.r, c.b) * 1.15), c.b, c.a))
	var used := img.get_used_rect()
	img = img.get_region(used)
	print("ship2 used rect: ", used)
	# art bow points LEFT — rotate 180 so the bow faces +X
	img.rotate_180()
	var h := int(round(float(img.get_height()) * SHIP_TARGET_W / img.get_width()))
	img.resize(SHIP_TARGET_W, h, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(SHIP_DST))
	print("ship2 processed: %dx%d -> %s" % [SHIP_TARGET_W, h, SHIP_DST])


func _bg() -> void:
	## The painted title/intro backdrop — no keying, just resize to a
	## sensible width and keep aspect.
	var img := Image.load_from_file(BG_SRC)
	img.convert(Image.FORMAT_RGBA8)
	var h := int(round(float(img.get_height()) * BG_TARGET_W / img.get_width()))
	img.resize(BG_TARGET_W, h, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(BG_DST))
	print("intro2 backdrop: %dx%d -> %s" % [BG_TARGET_W, h, BG_DST])
