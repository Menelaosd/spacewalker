extends SceneTree
## One-shot: synthesize front-walk frames for the mini astronaut from the
## kit's single front frame (s10_00) — paper-doll style: below the hip
## line, one leg shifts down (planted, extended) and the other shifts up
## (lifted). Two frames, opposite legs. Saves s10_front_a/b.png.
## Run: godot --headless -s tools/gen_walk_frames.gd

const SRC := "res://assets/props/s10_00.png"
const SHIFT := 13   # planted-leg extension — must survive the ~1/3 draw scale
const LIFT := 7     # lifted-leg rise


func _frame(img: Image, left_down: bool) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var legs_y := int(h * 0.66)   # hip line
	var mid := int(w * 0.5)
	var out := Image.create(w, h + SHIFT, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(0, 0))
	out.fill_rect(Rect2i(0, legs_y, w, h - legs_y + SHIFT), Color(0, 0, 0, 0))
	var lrect := Rect2i(0, legs_y, mid, h - legs_y)
	var rrect := Rect2i(mid, legs_y, w - mid, h - legs_y)
	var planted := img.get_region(lrect if left_down else rrect)
	var lifted := img.get_region(rrect if left_down else lrect)
	var px := 0 if left_down else mid
	var lx := mid if left_down else 0
	# planted leg: drawn at rest AND shifted down — the overlap bridges
	# the hip so the leg reads extended, no seam
	out.blit_rect(planted, Rect2i(0, 0, planted.get_width(), planted.get_height()),
		Vector2i(px, legs_y))
	out.blit_rect(planted, Rect2i(0, 0, planted.get_width(), planted.get_height()),
		Vector2i(px, legs_y + SHIFT))
	# lifted leg: raised, blended so its transparent margins don't erase
	# the torso rows it now overlaps
	out.blend_rect(lifted, Rect2i(0, 0, lifted.get_width(), lifted.get_height()),
		Vector2i(lx, legs_y - LIFT))
	return out


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	img.convert(Image.FORMAT_RGBA8)
	_frame(img, true).save_png(
		ProjectSettings.globalize_path("res://assets/props/s10_front_a.png"))
	_frame(img, false).save_png(
		ProjectSettings.globalize_path("res://assets/props/s10_front_b.png"))
	print("front walk frames generated")
	quit(0)
