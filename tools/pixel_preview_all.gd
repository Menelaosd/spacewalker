extends Node
## Contact sheet of ALL SIX ships as they now ship: the player's hull plus the five crew
## wrecks, pixelated. Reads the LIVE files, so this shows exactly what the game loads.
## Also verifies each master is safe in the vault before reporting success.
const OUT := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/cf45e486-8764-4be3-bb51-d6dafa43276d/scratchpad/pixel/ALL_SHIPS.png"
const VAULT := "res://assets/_originals/"
const SHIPS := [
	["ship_hd", "res://assets/sprites/ship_hd.png"],
	["juno_wreck", "res://assets/sprites/crew/juno_wreck.png"],
	["hale_wreck", "res://assets/sprites/crew/hale_wreck.png"],
	["mira_wreck", "res://assets/sprites/crew/mira_wreck.png"],
	["sola_wreck", "res://assets/sprites/crew/sola_wreck.png"],
	["vega_wreck", "res://assets/sprites/crew/vega_wreck.png"],
]
const CELL := 620


func _ready() -> void:
	var cols := 3
	var rows := 2
	var sheet := Image.create(CELL * cols, CELL * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.035, 0.045, 0.065, 1.0))
	for i in SHIPS.size():
		var nm: String = SHIPS[i][0]
		var abs := ProjectSettings.globalize_path(str(SHIPS[i][1]))
		var im := Image.load_from_file(abs)
		if im == null:
			print("[ALL] unreadable ", nm)
			continue
		im.convert(Image.FORMAT_RGBA8)
		# fit into the cell without resampling away the very blocks we are showing:
		# integer-ish scale down, NEAREST so the pixel grid survives the contact sheet
		var pad := 40
		var maxw := CELL - pad * 2
		var sc: float = minf(float(maxw) / float(im.get_width()),
			float(maxw) / float(im.get_height()))
		im.resize(maxi(1, int(im.get_width() * sc)), maxi(1, int(im.get_height() * sc)),
			Image.INTERPOLATE_NEAREST)
		var ox := (i % cols) * CELL + (CELL - im.get_width()) / 2
		var oy := (i / cols) * CELL + (CELL - im.get_height()) / 2
		sheet.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(ox, oy))
		var vault_ok := FileAccess.file_exists(VAULT + nm + ".png")
		print("[ALL] %-12s live %s   master in vault: %s"
			% [nm, str(Image.load_from_file(abs).get_size()), "YES" if vault_ok else "*** NO ***"])
	sheet.save_png(OUT)
	print("[ALL] wrote ", OUT)
	get_tree().quit()
