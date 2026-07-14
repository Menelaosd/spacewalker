extends SceneTree
## Promote the verified clean candidates (scratchpad/cand_a/aNNN.png) to the
## final trash_a## names, overwriting the half-cropped originals. Only touches
## trash_a*.png (never trash_b*). Run AFTER reextract_trash_a.gd.
## Run: godot --headless -s tools/promote_trash_a.gd --path .

const CAND := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/cand_a"
const DST := "res://assets/sprites/trash"


func _init() -> void:
	var out_dir := ProjectSettings.globalize_path(DST)
	# wipe existing trash_a*.png ONLY (leave trash_b*, leave .import sidecars)
	for f in DirAccess.get_files_at(out_dir):
		if f.begins_with("trash_a") and f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + "/" + f)

	var cand_files := DirAccess.get_files_at(CAND)
	var names := []
	for f in cand_files:
		if f.ends_with(".png"):
			names.append(f)
	names.sort()
	var i := 1
	for f in names:
		var img := Image.load_from_file(CAND + "/" + f)
		if img == null:
			push_error("cannot load candidate " + f)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var dst := "%s/trash_a%02d.png" % [out_dir, i]
		img.save_png(dst)
		i += 1
	print("promoted %d clean sprites -> trash_a01..trash_a%02d" % [names.size(), names.size()])
	quit(0)
