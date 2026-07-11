extends SceneTree
## Sprite generator — run headless to (re)build the game's pixel art:
##   godot --headless --path . -s res://tools/gen_sprites.gd
## Sprites are authored here as ASCII art / shape code so the whole art
## style can be tweaked in one place and regenerated deterministically.

const OUT := "res://assets/sprites"

const PAL := {
	"K": Color8(26, 32, 48),      # outline
	"W": Color8(236, 240, 247),   # suit white
	"w": Color8(198, 206, 220),   # suit shade
	"V": Color8(22, 40, 60),      # visor
	"v": Color8(127, 212, 255),   # visor glint
	"G": Color8(118, 126, 142),   # metal
	"g": Color8(74, 81, 96),      # metal dark
	"O": Color8(232, 117, 42),    # accent orange
	"B": Color8(138, 147, 166),   # hull
	"b": Color8(92, 100, 118),    # hull shadow
	"h": Color8(185, 194, 212),   # hull light
	"C": Color8(102, 242, 255),   # crystal
	"c": Color8(47, 184, 216),    # crystal dark
	"I": Color8(217, 142, 58),    # iron ore
	"i": Color8(165, 100, 42),    # iron dark
	"Y": Color8(242, 193, 78),    # lifeline yellow
}

const ASTRONAUT := [
	"................",
	"....KKKKKK......",
	"...KWWWWWWK.....",
	"..KWWWWWWWWK....",
	".KGKWWKVVVVWK...",
	".KGKWWVVVVvVK...",
	".KGKWWVVVVVVK...",
	".KGKWWWKVVVWK...",
	".KGKWWWWKKWWK...",
	".KGKWwWWWWWwK...",
	"..KKWwwWWWwwK...",
	"...KWWWWWWWWK...",
	"...KWWWKKWWWK...",
	"....KWWK.KWWK...",
	".....KK...KK....",
	"................",
]

const IRON := [
	"..KKK...",
	".KIIiK..",
	"KIIIIiK.",
	"KIiIIIK.",
	"KIIiIiK.",
	".KiIiK..",
	"..KKK...",
	"........",
]

const CRYSTAL := [
	"...KK...",
	"..KCcK..",
	".KCCCcK.",
	"KCCvCcK.",
	".KcCCcK.",
	"..KccK..",
	"...KK...",
	"........",
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_save(_from_ascii(ASTRONAUT), "astronaut")
	_save(_from_ascii(IRON), "iron")
	_save(_from_ascii(CRYSTAL), "crystal")
	_save(_gen_ship(), "ship")
	print("SPRITES OK")
	quit()


func _save(img: Image, name: String) -> void:
	img.save_png("%s/%s.png" % [OUT, name])
	print("wrote ", name, ".png ", img.get_width(), "x", img.get_height())


func _from_ascii(rows: Array) -> Image:
	var h := rows.size()
	var w: int = rows[0].length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var ch: String = rows[y][x]
			if PAL.has(ch):
				img.set_pixel(x, y, PAL[ch])
	return img


# ------------------------------------------------------------------
# Ship (64x32, faces right) — built from shape code, not ASCII
# ------------------------------------------------------------------
func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _gen_ship() -> Image:
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var A := Vector2(20, 16)
	var B := Vector2(50, 16)
	var R := 11.0

	# engine block (behind hull, sticks out left)
	for y in range(11, 22):
		for x in range(4, 14):
			img.set_pixel(x, y, PAL["g"])
	# hull capsule with three shading bands
	for y in 32:
		for x in 64:
			if _seg_dist(Vector2(x, y), A, B) <= R:
				var col: Color = PAL["B"]
				if y <= 12:
					col = PAL["h"]
				elif y >= 21:
					col = PAL["b"]
				img.set_pixel(x, y, col)
	# stripe across the hull — stay inside the outline
	for y in range(15, 18):
		for x in range(10, 60):
			if img.get_pixel(x, y).a > 0.0 and _seg_dist(Vector2(x, y), A, B) <= R - 1.5:
				img.set_pixel(x, y, PAL["O"])
	# airlock bump under the hull, where the lifeline anchors
	for y in range(26, 31):
		for x in range(28, 37):
			img.set_pixel(x, y, PAL["g"])
	img.set_pixel(32, 30, PAL["Y"])
	# outline everything drawn so far
	var base := img.duplicate()
	for y in 32:
		for x in 64:
			if base.get_pixel(x, y).a == 0.0:
				continue
			for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + n
				if q.x < 0 or q.y < 0 or q.x >= 64 or q.y >= 32 \
						or base.get_pixel(q.x, q.y).a == 0.0:
					img.set_pixel(x, y, PAL["K"])
					break
	# cockpit window — only ever painted on existing hull pixels
	for y in 32:
		for x in 64:
			if img.get_pixel(x, y).a == 0.0:
				continue
			var d := Vector2(x, y).distance_to(Vector2(44, 14))
			if d <= 4.0:
				img.set_pixel(x, y, PAL["V"])
			elif d <= 5.0:
				img.set_pixel(x, y, PAL["K"])
	img.set_pixel(43, 12, PAL["v"])
	img.set_pixel(42, 13, PAL["v"])
	return img
