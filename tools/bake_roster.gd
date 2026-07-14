extends SceneTree
## Headless icon baker for the CREW ROSTER HUD.
##
## Run:  godot --headless --script tools/bake_roster.gd
##
## Reads each crew's CREW ID card (assets/sprites/crew/<name>_id.png, a fixed
## 1566x960 template with a clean head+shoulders bust in the blue panel on the
## left), crops the face/bust to a square, resizes with anti-aliasing, masks to
## a clean circle (transparent outside), and writes two baked icons per crew:
##   assets/sprites/crew/roster/<name>_face.png     — full COLOUR  (collected)
##   assets/sprites/crew/roster/<name>_face_bw.png  — grey+dimmed  (uncollected)
## Baking both is simpler and more reliable than desaturating in a shader.

const OUT_DIR := "res://assets/sprites/crew/roster"
const SRC_FMT := "res://assets/sprites/crew/%s_id.png"
const OUT_SIZE := 128            # final icon side (px)
const WORK := 512                # supersample size for a smooth circle edge
const BW_BRIGHT := 0.55          # uncollected dimming (~55% brightness)

# Crop square in SOURCE id-card pixels (all cards share the 1566x960 template).
# Per-crew centre/size lets us re-frame a face that sits a little high or low.
# cx, cy = centre of the square; s = side length (px).
const CROP := {
	"juno": {"cx": 338, "cy": 452, "s": 520},
	"mira": {"cx": 352, "cy": 448, "s": 540},
	"hale": {"cx": 340, "cy": 452, "s": 540},
	"sola": {"cx": 340, "cy": 450, "s": 520},
	"vega": {"cx": 336, "cy": 440, "s": 520},
}

const NAMES := ["juno", "mira", "hale", "sola", "vega"]


func _initialize() -> void:
	var da := DirAccess.open("res://")
	if da != null and not da.dir_exists(OUT_DIR):
		da.make_dir_recursive(OUT_DIR)

	for name in NAMES:
		var src_path := SRC_FMT % name
		var img := Image.new()
		var err := img.load(src_path)
		if err != OK:
			# fall back to an absolute path in case res:// import isn't ready
			err = img.load(ProjectSettings.globalize_path(src_path))
		if err != OK:
			push_error("FAILED to load %s (err %d)" % [src_path, err])
			continue

		var crop: Dictionary = CROP[name]
		var side: int = int(crop["s"])
		var x0: int = int(crop["cx"]) - side / 2
		var y0: int = int(crop["cy"]) - side / 2
		x0 = clampi(x0, 0, img.get_width() - side)
		y0 = clampi(y0, 0, img.get_height() - side)

		var face := img.get_region(Rect2i(x0, y0, side, side))
		# upsample to a common working size, mask, then downsample with AA so the
		# circle edge is smooth (no jaggies, no square corners)
		face.resize(WORK, WORK, Image.INTERPOLATE_LANCZOS)
		face.convert(Image.FORMAT_RGBA8)

		var color_img := _circle_mask(face)
		color_img.resize(OUT_SIZE, OUT_SIZE, Image.INTERPOLATE_LANCZOS)
		var col_out := "%s/%s_face.png" % [OUT_DIR, name]
		color_img.save_png(col_out)

		var bw_img := _desaturate(_circle_mask(face))
		bw_img.resize(OUT_SIZE, OUT_SIZE, Image.INTERPOLATE_LANCZOS)
		var bw_out := "%s/%s_face_bw.png" % [OUT_DIR, name]
		bw_img.save_png(bw_out)

		print("baked %s -> %s , %s  (crop %d,%d %dpx)"
			% [name, col_out, bw_out, x0, y0, side])

	print("DONE")
	quit()


func _circle_mask(src: Image) -> Image:
	## Return a copy of `src` with a circular alpha mask (transparent outside,
	## 1px anti-aliased edge). Works at the source resolution.
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w * 0.5
	var cy := h * 0.5
	var r := minf(w, h) * 0.5 - 1.0
	for y in h:
		for x in w:
			var px := src.get_pixel(x, y)
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			var edge := clampf(r - d, 0.0, 1.0)   # 1px feather
			px.a *= edge
			out.set_pixel(x, y, px)
	return out


func _desaturate(src: Image) -> Image:
	## Grayscale (luminance) + darken to ~BW_BRIGHT, preserving alpha.
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var px := src.get_pixel(x, y)
			var l := (0.299 * px.r + 0.587 * px.g + 0.114 * px.b) * BW_BRIGHT
			out.set_pixel(x, y, Color(l, l, l, px.a))
	return out
