extends SceneTree
## Zoom the edge-clip-flagged walk frames big so we can see if a limb/foot is
## actually cut at the canvas edge (true clip) or merely touches it. READ-ONLY.
const DIR := "res://assets/sprites/walk"
const OUT := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/zoom_walk_flags.png"
const FILES := [
	"front_0", "front_1", "front_2",
	"front_4", "front_5", "front_6",
	"left_4", "left_5", "left_6", "left_7",
	"right_5", "right_6", "right_7",
]

func _init() -> void:
	var scale := 5
	var cols := 3
	var imgs := []
	var cw := 0
	var ch := 0
	for n in FILES:
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [DIR, n]))
		img.convert(Image.FORMAT_RGBA8)
		imgs.append(img)
		cw = max(cw, img.get_width())
		ch = max(ch, img.get_height())
	var pad := 4
	var cellw := cw * scale + pad * 2
	var cellh := ch * scale + pad * 2
	var rows := int(ceil(float(imgs.size()) / float(cols)))
	var out := Image.create(cellw * cols, cellh * rows, false, Image.FORMAT_RGBA8)
	# bright magenta bg + a 1px red frame at each cell's canvas border so any
	# opaque pixel reaching the border is obvious
	for y in out.get_height():
		for x in out.get_width():
			out.set_pixel(x, y, Color(0.15, 0.75, 0.15))
	for i in imgs.size():
		var im := imgs[i].duplicate() as Image
		im.resize(im.get_width() * scale, im.get_height() * scale, Image.INTERPOLATE_NEAREST)
		var col := i % cols
		var row := i / cols
		var ox := col * cellw + pad
		var oy := row * cellh + pad
		# red canvas-border rectangle
		for xx in range(im.get_width()):
			out.set_pixel(ox + xx, oy, Color(1, 0, 0))
			out.set_pixel(ox + xx, oy + im.get_height() - 1, Color(1, 0, 0))
		for yy in range(im.get_height()):
			out.set_pixel(ox, oy + yy, Color(1, 0, 0))
			out.set_pixel(ox + im.get_width() - 1, oy + yy, Color(1, 0, 0))
		out.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(ox, oy))
	out.save_png(OUT)
	print("zoom -> ", OUT, "  order: ", FILES)
	quit(0)
