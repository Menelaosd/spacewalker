extends Node
## Crops a region out of a PNG and blows it up with NEAREST, for judging small UI at
## pixel level.  SW_CROP_IN / SW_CROP_OUT / SW_CROP_RECT="x,y,w,h" / SW_CROP_ZOOM
func _ready() -> void:
	var src := OS.get_environment("SW_CROP_IN")
	var dst := OS.get_environment("SW_CROP_OUT")
	var rc := OS.get_environment("SW_CROP_RECT").split(",")
	var z := int(OS.get_environment("SW_CROP_ZOOM")) if OS.get_environment("SW_CROP_ZOOM") != "" else 3
	var im := Image.load_from_file(src)
	if im == null or rc.size() < 4:
		print("[CROP] bad input")
		get_tree().quit()
		return
	var r := Rect2i(int(rc[0]), int(rc[1]), int(rc[2]), int(rc[3]))
	var out := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(im, r, Vector2i.ZERO)
	out.resize(r.size.x * z, r.size.y * z, Image.INTERPOLATE_NEAREST)
	out.save_png(dst)
	print("[CROP] %s -> %s  (%dx%d @%dx)" % [src.get_file(), dst.get_file(), r.size.x, r.size.y, z])
	get_tree().quit()
