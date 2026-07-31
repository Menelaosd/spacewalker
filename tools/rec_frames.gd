extends Node
## Frame grabber for short clips. Godot's own --write-movie produces a large MJPEG AVI and
## there is no ffmpeg on this machine to transcode it, so this writes a numbered PNG
## sequence instead — readable directly, and trivially turned into a GIF or sheet later.
##
##   SW_REC_SCENE  scene to record (default: flight)
##   SW_REC_FRAMES how many frames        SW_REC_EVERY  capture 1 in N ticks
##   SW_REC_OUT    output directory
const DEF_OUT := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/cf45e486-8764-4be3-bb51-d6dafa43276d/scratchpad/video/frames"

var _n := 0
var _tick := 0
var _want := 48
var _every := 3
var _out := DEF_OUT


func _ready() -> void:
	if OS.get_environment("SW_REC_OUT") != "":
		_out = OS.get_environment("SW_REC_OUT")
	if OS.get_environment("SW_REC_FRAMES") != "":
		_want = int(OS.get_environment("SW_REC_FRAMES"))
	if OS.get_environment("SW_REC_EVERY") != "":
		_every = maxi(1, int(OS.get_environment("SW_REC_EVERY")))
	DirAccess.make_dir_recursive_absolute(_out)
	var path := OS.get_environment("SW_REC_SCENE")
	if path == "":
		path = "res://scenes/flight.tscn"
	add_child(load(path).instantiate())
	print("[REC] %s -> %d frames every %d ticks" % [path, _want, _every])


func _process(_dt: float) -> void:
	_tick += 1
	if _tick % _every != 0:
		return
	if _n >= _want:
		print("[REC] done, %d frames in %s" % [_n, _out])
		get_tree().quit()
		return
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	im.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	im.save_png("%s/f%03d.png" % [_out, _n])
	_n += 1
