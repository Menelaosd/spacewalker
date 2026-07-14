extends SceneTree
## Quick colour probe: corner bg + a few teal/orange samples across sheets.
const DIR := "C:/Users/menel/OneDrive/Έγγραφα/Games/game-assets/spacewalker/trash/"
const FILES := [
	"ChatGPT Image Jul 14, 2026, 09_57_09 PM (1).png",
	"ChatGPT Image Jul 14, 2026, 09_57_09 PM (2).png",
	"ChatGPT Image Jul 14, 2026, 09_57_10 PM (3).png",
	"ChatGPT Image Jul 14, 2026, 09_57_10 PM (4).png",
	"ChatGPT Image Jul 14, 2026, 09_57_10 PM (5).png",
]

func _init() -> void:
	for f in FILES:
		var img := Image.load_from_file(DIR + f)
		if img == null:
			print("FAIL ", f)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var c0 := img.get_pixel(4, 4)
		var cc := img.get_pixel(w / 2, 4)
		print("%s  %dx%d  TLcorner=(%.2f,%.2f,%.2f)  topmid=(%.2f,%.2f,%.2f)" % [
			f.substr(f.length() - 8), w, h, c0.r, c0.g, c0.b, cc.r, cc.g, cc.b])
	quit(0)
