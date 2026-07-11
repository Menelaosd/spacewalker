class_name NebulaFog
## Procedural smoke/fog textures for nebulas — fractal simplex noise
## shaped by a radial falloff, hue-varied by a second noise channel.
## Generated lazily (first sight of each nebula) and cached per session.

const SIZE := 320

static var _cache := {}


static func texture_for(i: int) -> ImageTexture:
	if _cache.has(i):
		return _cache[i]
	var col: Color = GameState.NEBULAE[i]["color"]

	var density := FastNoiseLite.new()
	density.seed = 900 + i
	density.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	density.fractal_type = FastNoiseLite.FRACTAL_FBM
	density.fractal_octaves = 6
	density.frequency = 0.019

	var hue_drift := FastNoiseLite.new()
	hue_drift.seed = 1700 + i
	hue_drift.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hue_drift.fractal_octaves = 3
	hue_drift.frequency = 0.006

	# cool-tone channel: regions of the cloud shift green/teal/blue
	var cool_mix := FastNoiseLite.new()
	cool_mix.seed = 2600 + i
	cool_mix.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cool_mix.fractal_octaves = 3
	cool_mix.frequency = 0.009
	var cool_a := Color.from_hsv(fmod(col.h + 0.38, 1.0), col.s * 0.9, col.v)  # teal/green side
	var cool_b := Color.from_hsv(fmod(col.h + 0.55, 1.0), col.s * 0.85, col.v) # blue side

	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c := SIZE * 0.5
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x - c, y - c).length() / c
			if d >= 1.0:
				continue
			var falloff := pow(clampf(1.0 - d, 0.0, 1.0), 1.1)
			var v := (density.get_noise_2d(x, y) + 1.0) * 0.5
			# wide hue swing — purple through pink across the cloud
			var pc := col
			pc.h = fmod(col.h + hue_drift.get_noise_2d(x, y) * 0.16 + 1.0, 1.0)
			pc.s = clampf(pc.s * 1.2, 0.0, 1.0)
			# cool regions: whole patches drift green/teal or blue
			var cm := (cool_mix.get_noise_2d(x, y) + 1.0) * 0.5
			if cm > 0.60:
				pc = pc.lerp(cool_a, clampf((cm - 0.60) * 2.4, 0.0, 0.8))
			elif cm < 0.30:
				pc = pc.lerp(cool_b, clampf((0.30 - cm) * 2.0, 0.0, 0.6))
			var out: Color
			if v < 0.38:
				# dark dust lanes — deep tinted near-black, denser where v drops
				var dk := pow((0.38 - v) / 0.38, 1.3)
				out = Color(pc.r * 0.16, pc.g * 0.10, pc.b * 0.26,
					dk * 0.6 * falloff)
			else:
				# bright fog — climbs to near-white hot cores
				var lv := (v - 0.38) / 0.62
				pc.v = clampf(col.v * (0.5 + 1.1 * lv), 0.0, 1.0)
				if lv > 0.45:
					pc = pc.lerp(Color(1.0, 0.95, 1.0), (lv - 0.45) * 0.95)
				out = Color(pc.r, pc.g, pc.b,
					minf(pow(lv, 1.05) * falloff * 1.15, 0.82))
			if out.a < 0.012:
				continue
			img.set_pixel(x, y, out)
	var tex := ImageTexture.create_from_image(img)
	_cache[i] = tex
	return tex
