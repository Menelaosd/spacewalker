extends SceneTree
## 3x montage of a 4-frame walk cycle + idle. Arg: direction (default right).
## Run: godot --headless -s tools/montage_rig6.gd --path . -- right
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var d: String = args[0] if args.size() > 0 else "right"
	var names: Array = []
	for i in 4:
		names.append("%s_%d" % [d, i])
	names.append("%s_idle" % d)
	var z := 3
	var cw := 0
	var ch := 0
	var imgs: Array = []
	for n in names:
		var img := Image.load_from_file(ProjectSettings.globalize_path(
			"res://assets/sprites/walk/%s.png" % n))
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		imgs.append(img)
		cw = maxi(cw, img.get_width())
		ch = maxi(ch, img.get_height())
	var out := Image.create((cw * z + 8) * imgs.size(), ch * z + 8, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.35, 0.35, 0.38))
	# baseline guide line so a common feet baseline is easy to eyeball
	out.fill_rect(Rect2i(0, ch * z + 4 - 1, out.get_width(), 1), Color(1, 0.3, 0.3, 0.6))
	for i in imgs.size():
		var img: Image = imgs[i]
		img.resize(img.get_width() * z, img.get_height() * z, Image.INTERPOLATE_NEAREST)
		out.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()),
			Vector2i(i * (cw * z + 8) + 4, 4))
	out.save_png(ProjectSettings.globalize_path("res://montage_rig.png"))
	print("saved montage_rig.png (%s)" % d)
	quit(0)
