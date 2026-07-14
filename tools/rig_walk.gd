extends SceneTree
## RIG-COMPOSITED side walk: one FIXED upper body (helmet/torso from the
## idle — kills the AI sheets' frame-to-frame helmet jitter) over 8 leg
## positions: the 5 donors' authentic leg blocks + horizontal MIRRORS of the
## stride blocks for the opposite leg (profile suit legs are symmetric).
## Height proportions untouched: legs stay feet-on-bottom, hip line fixed,
## upper body identical in every frame.
## Run: godot --headless -s tools/rig_walk.gd --path . -- right|left

const SRC := "res://assets/sprites/walk"
const HIP_Y := 93          # upper body owns y < HIP_Y+OVERLAP; legs y >= HIP_Y
const OVERLAP := 4         # torso bottom draws OVER the leg tops — no seams

# the 8-frame cycle as (donor, mirrored) leg blocks, in playback order:
# contact A (wide) -> down -> passing -> up -> contact B (mirror) -> down
# (mirror) -> passing -> up (mirror). Donor indices: 0..3 = walk frames of
# the CURRENT build's row (sheet-10), 4 = idle (feet together = passing).
const CYCLE := [
	[2, false],   # contact A — widest authentic stride
	[1, false],   # down — mid stride
	[4, false],   # passing — feet together (idle legs)
	[3, false],   # up — leg swinging through, forward
	[2, true],    # contact B — mirrored wide stride (opposite leg)
	[1, true],    # down (mirrored)
	[4, false],   # passing again
	[3, true],    # up (mirrored)
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dname: String = args[0] if args.size() > 0 else "right"

	# donors 0..3 = current walk frames, 4 = idle
	var donors: Array = []
	for i in 4:
		donors.append(_load("%s/%s_%d.png" % [SRC, dname, i]))
	donors.append(_load("%s/%s_idle.png" % [SRC, dname]))

	var cw: int = donors[4].get_width()
	var ch: int = donors[4].get_height()

	# the FIXED upper body: idle's pixels above the hip+overlap line
	var upper := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	upper.blit_rect(donors[4], Rect2i(0, 0, cw, HIP_Y + OVERLAP), Vector2i.ZERO)

	# figure x-centre of the idle (for aligning mirrored leg blocks)
	var idle_cx := _content_cx(donors[4])

	for f in CYCLE.size():
		var donor_i: int = CYCLE[f][0]
		var mirrored: bool = CYCLE[f][1]
		var src: Image = donors[donor_i]

		# the donor's LEG BLOCK: everything from HIP_Y down
		var legs := Image.create(cw, ch - HIP_Y, false, Image.FORMAT_RGBA8)
		legs.blit_rect(src, Rect2i(0, HIP_Y, cw, ch - HIP_Y), Vector2i.ZERO)
		var shift := 0
		if mirrored:
			# mirror, then re-centre on the idle's figure axis so the hips
			# stay under the fixed torso
			var lc_before := _block_cx(legs)
			legs.flip_x()
			var lc_after := _block_cx(legs)
			shift = int(round(lc_before - lc_after))
			# also re-align to the donor's own pre-mirror centre drift vs idle
		# compose: legs first, fixed upper body OVER them (covers the seam)
		var out := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
		_blend_at(out, legs, Vector2i(shift, HIP_Y))
		_blend_at(out, upper, Vector2i.ZERO)
		out.save_png(ProjectSettings.globalize_path(
			"%s/%s_%d.png" % [SRC, dname, f]))
	print("rigged 8-frame %s cycle (fixed upper body, idle_cx=%.1f)" % [dname, idle_cx])
	quit(0)


func _load(p: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(p))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _content_cx(img: Image) -> float:
	var minx := img.get_width()
	var maxx := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.1:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
	return (minx + maxx) * 0.5


func _block_cx(img: Image) -> float:
	return _content_cx(img)


func _blend_at(dst: Image, src: Image, at: Vector2i) -> void:
	## alpha-blend src onto dst at offset (blit would erase with src's 0-alpha)
	for y in src.get_height():
		var dy := at.y + y
		if dy < 0 or dy >= dst.get_height():
			continue
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a < 0.02:
				continue
			var dx := at.x + x
			if dx < 0 or dx >= dst.get_width():
				continue
			var b := dst.get_pixel(dx, dy)
			dst.set_pixel(dx, dy, b.blend(c) if c.a < 0.98 else c)
	# (per-pixel is fine at 81x124 tool scale)
