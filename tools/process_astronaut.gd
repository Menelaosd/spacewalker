extends SceneTree
## One-shot: trim and downscale the painted astronaut frames (a1-a8)
## from game-assets into res://assets/sprites/astro/.
## ONE uniform scale factor (derived from a1's content height) applies
## to every frame — so the body stays the same size across poses; only
## the canvas differs. Run: godot --headless -s tools/process_astronaut.gd

const SRC_DIR := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker"
const DST_DIR := "res://assets/sprites/astro"
const A1_TARGET_H := 76.0   # a1 content height in px; drawn at 0.5 -> ~38 world px


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DST_DIR))
	# the reference frame decides the scale for the whole set
	var ref := Image.load_from_file(SRC_DIR + "/a1.png")
	ref.convert(Image.FORMAT_RGBA8)
	var factor := A1_TARGET_H / float(ref.get_used_rect().size.y)
	for i in range(1, 9):
		var img := Image.load_from_file("%s/a%d.png" % [SRC_DIR, i])
		if img == null:
			push_error("Could not load a%d" % i)
			continue
		img.convert(Image.FORMAT_RGBA8)
		img = img.get_region(img.get_used_rect())
		var w := maxi(int(round(img.get_width() * factor)), 1)
		var h := maxi(int(round(img.get_height() * factor)), 1)
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path("%s/a%d.png" % [DST_DIR, i]))
		print("a%d: %dx%d" % [i, w, h])
	quit(0)
