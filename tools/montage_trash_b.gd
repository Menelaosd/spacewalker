extends SceneTree
## trash_b-only montage with numeric labels drawn as pixel digits so the
## reader can identify each sprite by its bXX number. Read-only.
const DIR := "res://assets/sprites/trash"
const OUT := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/trash_b_fixed_montage.png"

# 3x5 pixel font for digits 0-9
const FONT := {
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"],
	"3": ["111", "001", "111", "001", "111"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"],
	"9": ["111", "101", "111", "001", "111"],
}

func _init() -> void:
	var files := _list()
	var cols := 10
	var box := 150
	var pad := 6
	var label_h := 16
	var rows := int(ceil(float(files.size()) / cols))
	var cw := box + pad
	var ch := box + pad + label_h
	var out := Image.create(cols * cw + pad, rows * ch + pad, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.30, 0.30, 0.34))
	for i in files.size():
		var f: String = files[i]
		var im := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [DIR, f]))
		if im == null:
			continue
		im.convert(Image.FORMAT_RGBA8)
		var iw := im.get_width()
		var ih := im.get_height()
		var scale := minf(float(box) / iw, float(box) / ih)
		var nw := maxi(1, int(iw * scale))
		var nh := maxi(1, int(ih * scale))
		im.resize(nw, nh, Image.INTERPOLATE_NEAREST)
		var col := i % cols
		var row := i / cols
		var cellx := pad + col * cw
		var celly := pad + row * ch
		# checker background inside cell so transparency + green halos show
		for yy in box:
			for xx in box:
				var ck := ((xx / 10) + (yy / 10)) % 2 == 0
				out.set_pixel(cellx + xx, celly + label_h + yy,
					Color(0.55, 0.55, 0.58) if ck else Color(0.42, 0.42, 0.45))
		var ox := cellx + (box - nw) / 2
		var oy := celly + label_h + (box - nh) / 2
		out.blend_rect(im, Rect2i(0, 0, nw, nh), Vector2i(ox, oy))
		# label = the number in trash_bNN
		var num := f.trim_prefix("trash_b").trim_suffix(".png")
		_draw_text(out, num, cellx + 2, celly + 3, Color(1, 1, 0.2))
	out.save_png(OUT)
	print("montage saved (%d sprites) -> %s" % [files.size(), OUT])
	quit(0)

func _draw_text(img: Image, s: String, x: int, y: int, col: Color) -> void:
	var sc := 2
	var cx := x
	for ch in s:
		if not FONT.has(ch):
			continue
		var glyph: Array = FONT[ch]
		for gy in 5:
			var rowstr: String = glyph[gy]
			for gx in 3:
				if rowstr[gx] == "1":
					for sy in sc:
						for sx in sc:
							var px := cx + gx * sc + sx
							var py := y + gy * sc + sy
							if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
								img.set_pixel(px, py, col)
		cx += 4 * sc

func _list() -> Array:
	var out := []
	var d := DirAccess.open(ProjectSettings.globalize_path(DIR))
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.begins_with("trash_b") and fn.ends_with(".png"):
			out.append(fn)
		fn = d.get_next()
	d.list_dir_end()
	out.sort()
	return out
