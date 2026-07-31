extends Node
## Pixel-art conversion preview for the SHIPS: the player's hull and the five crew wrecks.
## Writes ONLY to the scratchpad — the repo art is never modified. Produces, per ship, a
## comparison strip of the original beside several pixel factors so the captain can pick.
##
## Method: average-downscale to 1/N (LANCZOS keeps shape while merging detail), then
## nearest-neighbour back to full size so every source pixel becomes a hard NxN block.
## Optional palette quantisation snaps colours to a coarser ramp, which is what actually
## sells "pixel art" — chunky blocks with 200 shades still read as a filtered photo.

const OUT := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/cf45e486-8764-4be3-bb51-d6dafa43276d/scratchpad/pixel"
const SHIPS := {
	"ship_hd": "res://assets/sprites/ship_hd.png",
	"juno_wreck": "res://assets/sprites/crew/juno_wreck.png",
	"hale_wreck": "res://assets/sprites/crew/hale_wreck.png",
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for name in SHIPS:
		var src := load(str(SHIPS[name])) as Texture2D
		if src == null:
			print("[PIX] missing ", SHIPS[name])
			continue
		var img := src.get_image()
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		# factors chosen so the resulting block is 3-10 source px on the art's own scale
		var factors: Array = [2, 3, 4] if w < 600 else [5, 7, 9]
		var strip := Image.create(w * (factors.size() + 1), h, false, Image.FORMAT_RGBA8)
		strip.fill(Color(0, 0, 0, 0))
		strip.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(0, 0))
		for i in factors.size():
			var f: int = factors[i]
			var small := img.duplicate() as Image
			small.resize(maxi(1, w / f), maxi(1, h / f), Image.INTERPOLATE_BILINEAR)
			_quantise(small, 0)   # 0 = colours untouched, alpha cutoff only
			small.resize(w, h, Image.INTERPOLATE_NEAREST)
			strip.blit_rect(small, Rect2i(0, 0, w, h), Vector2i(w * (i + 1), 0))
			small.save_png("%s/%s_x%d.png" % [OUT, name, f])
		strip.save_png("%s/CMP_%s.png" % [OUT, name])
		print("[PIX] %s %dx%d -> factors %s" % [name, w, h, str(factors)])
	print("[PIX] done")
	get_tree().quit()


func _quantise(img: Image, levels: int) -> void:
	## Snap each channel to a fixed number of steps. Chunky blocks alone still read as a downscaled
	## photo; cutting the palette is what makes it read as drawn pixel art. Kept at 10 levels
	## and paired with BILINEAR downscaling: at 6 levels the LANCZOS ringing quantised into
	## magenta speckle that was never in the source art.
	var keep_colour := levels <= 0
	var step := 1.0 / float(maxi(levels, 2) - 1)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.35:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# NEUTRALS STAY NEUTRAL. Rounding each channel independently lets a grey land on
			# different steps per channel, which tinted the hull pink. If a pixel is already
			# near-grey, quantise its luminance once and write it to all three.
			if keep_colour:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
				continue
			var mx: float = maxf(c.r, maxf(c.g, c.b))
			var mn: float = minf(c.r, minf(c.g, c.b))
			if mx - mn < 0.06:
				var l: float = round(((c.r + c.g + c.b) / 3.0) / step) * step
				img.set_pixel(x, y, Color(l, l, l, 1.0))
				continue
			img.set_pixel(x, y, Color(
				round(c.r / step) * step,
				round(c.g / step) * step,
				round(c.b / step) * step, 1.0))
