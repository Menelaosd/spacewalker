extends SceneTree
## Copy the curated candidate crops to their final trash_a## names and build the
## verification montage (3x, neutral gray). Run after crop_trash_a.gd.
## Run: godot --headless -s tools/finalize_trash_a.gd --path .

const CAND := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/cand"
const DST := "res://assets/sprites/trash"
const MONTAGE := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/trash_a_montage.png"

# curated 14 — distinct silhouettes across all 5 sheets
const PICKS := [
	"a00",  # round reactor, orange core        (sheet1)
	"a22",  # broken cockpit, teal glass         (sheet2)
	"a31",  # door / hatch frame (holed)         (sheet2)
	"a32",  # truss beam, thin lattice           (sheet2)
	"a33",  # bent pipe segment                  (sheet2)
	"a41",  # engine, teal rings                 (sheet3)
	"a44",  # triple thruster cluster            (sheet3)
	"a60",  # satellite w/ solar wings           (sheet4)
	"a68",  # large dish antenna                 (sheet4)
	"a72",  # geodesic sensor sphere w/ arms     (sheet4)
	"a80",  # solar array panel                  (sheet5)
	"a84",  # ribbed radiator                    (sheet5)
	"a92",  # robotic arm w/ claw                (sheet5)
	"a94",  # container module box               (sheet5)
]


func _init() -> void:
	var out_dir := ProjectSettings.globalize_path(DST)
	DirAccess.make_dir_recursive_absolute(out_dir)
	# wipe any stale trash_a* only (never touch trash_b*)
	for f in DirAccess.get_files_at(out_dir):
		if f.begins_with("trash_a") and f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + "/" + f)

	var imgs: Array = []
	for i in PICKS.size():
		var src := Image.load_from_file("%s/%s.png" % [CAND, PICKS[i]])
		if src == null:
			push_error("missing candidate " + PICKS[i])
			continue
		src.convert(Image.FORMAT_RGBA8)
		var name := "trash_a%02d" % (i + 1)
		src.save_png("%s/%s.png" % [out_dir, name])
		imgs.append(src)
		print("%s  <- %s  (%dx%d)" % [name, PICKS[i], src.get_width(), src.get_height()])

	_montage(imgs)
	print("wrote %d sprites; montage -> %s" % [imgs.size(), MONTAGE])
	quit(0)


func _montage(imgs: Array) -> void:
	var cols := 5
	var z := 2
	var pad := 10
	var cw := 0
	var ch := 0
	for im: Image in imgs:
		cw = maxi(cw, im.get_width())
		ch = maxi(ch, im.get_height())
	cw *= z
	ch *= z
	var rows := int(ceil(float(imgs.size()) / cols))
	var out := Image.create(cols * (cw + pad) + pad, rows * (ch + pad) + pad, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.5, 0.5, 0.53))
	for i in imgs.size():
		var t: Image = imgs[i].duplicate()
		t.resize(t.get_width() * z, t.get_height() * z, Image.INTERPOLATE_NEAREST)
		var col := i % cols
		var row := i / cols
		var ox := pad + col * (cw + pad) + (cw - t.get_width()) / 2
		var oy := pad + row * (ch + pad) + (ch - t.get_height()) / 2
		out.blend_rect(t, Rect2i(0, 0, t.get_width(), t.get_height()), Vector2i(ox, oy))
	out.save_png(MONTAGE)
