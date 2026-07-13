extends SceneTree
## Split the source asteroid rocks into TWO layers per shape so the outside
## zone rock can be a neutral GRAY body with only its CORE tinted per element:
##   neutral_<n>.png — the whole rock desaturated (gray body)
##   core_<n>.png    — a white mask of just the coloured gem/core (tinted later)
## Core detection: pixels whose colour is far from gray (max-min channel gap),
## which is exactly the gem in the middle; the rocky body is near-gray.
## Run: godot --headless -s tools/gen_rock_layers.gd --path .

const SRC := "res://assets/asteroids"
const SHAPES := ["metal", "nonmetal"]   # 8 variants each -> 16 shapes
const CORE_GAP := 0.11                  # channel spread that counts as "coloured core"


func _init() -> void:
	var n := 0
	for row in SHAPES:
		for v in 8:
			var img := Image.load_from_file(ProjectSettings.globalize_path(
				"%s/%s_%d.png" % [SRC, row, v]))
			if img == null:
				continue
			img.convert(Image.FORMAT_RGBA8)
			var w := img.get_width()
			var h := img.get_height()
			var body := Image.create(w, h, false, Image.FORMAT_RGBA8)
			var core := Image.create(w, h, false, Image.FORMAT_RGBA8)
			for y in h:
				for x in w:
					var c := img.get_pixel(x, y)
					if c.a < 0.02:
						continue
					var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
					var g := clampf(lum * 1.15 + 0.12, 0.0, 1.0)   # lifted gray
					body.set_pixel(x, y, Color(g, g, g, c.a))
					var gap: float = maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
					if gap > CORE_GAP:
						# white core mask; alpha ramps with how coloured it is so
						# the tint fades softly into the rock, no hard edge
						var m := clampf((gap - CORE_GAP) / 0.25, 0.0, 1.0) * c.a
						core.set_pixel(x, y, Color(1, 1, 1, m))
			body.save_png(ProjectSettings.globalize_path("%s/neutral_%d.png" % [SRC, n]))
			core.save_png(ProjectSettings.globalize_path("%s/core_%d.png" % [SRC, n]))
			n += 1
	print("generated %d rock body+core layer pairs" % n)
	quit(0)
