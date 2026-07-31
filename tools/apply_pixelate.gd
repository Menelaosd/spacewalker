extends Node
## Applies the chosen pixelation to the ship art IN PLACE. Originals are copied to
## <scratch>/ship_originals/ first — this is destructive to the working tree, and the only
## way back is that folder or git.
##
## Factors were picked from the comparison sheets: x3 for the player's 340x240 hull, x7 for
## the 1236x1002 crew wrecks (bigger source needs a bigger block for the same apparent
## chunkiness). Colours are NOT quantised — palette reduction shifted the hull toward pink
## and the block size is what actually reads as pixel art.

const BACKUP := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/cf45e486-8764-4be3-bb51-d6dafa43276d/scratchpad/ship_originals"
const JOBS := {
	"res://assets/sprites/ship_hd.png": 3,
	"res://assets/sprites/crew/juno_wreck.png": 7,
	"res://assets/sprites/crew/hale_wreck.png": 7,
	"res://assets/sprites/crew/mira_wreck.png": 7,
	"res://assets/sprites/crew/sola_wreck.png": 7,
	"res://assets/sprites/crew/vega_wreck.png": 7,
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(BACKUP)
	for res in JOBS:
		var abs := ProjectSettings.globalize_path(str(res))
		if not FileAccess.file_exists(abs):
			print("[APPLY] missing ", res)
			continue
		var img := Image.load_from_file(abs)
		if img == null:
			print("[APPLY] unreadable ", res)
			continue
		img.convert(Image.FORMAT_RGBA8)
		# back the original up before anything is written over it
		img.save_png("%s/%s" % [BACKUP, str(res).get_file()])
		var w := img.get_width()
		var h := img.get_height()
		var f: int = int(JOBS[res])
		var small := img.duplicate() as Image
		small.resize(maxi(1, w / f), maxi(1, h / f), Image.INTERPOLATE_BILINEAR)
		# hard alpha so the edges stay crisp blocks instead of feathering
		for y in small.get_height():
			for x in small.get_width():
				var c := small.get_pixel(x, y)
				small.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0) if c.a < 0.35 \
					else Color(c.r, c.g, c.b, 1.0))
		small.resize(w, h, Image.INTERPOLATE_NEAREST)
		small.save_png(abs)
		print("[APPLY] %s  x%d  (%dx%d)" % [str(res).get_file(), f, w, h])
	print("[APPLY] done — originals in ", BACKUP)
	get_tree().quit()
