extends CanvasLayer
## Global screen fade for scene changes. Autoload `Transition`. Every scene swap
## (enter/exit ship, take helm, park, respawn, title/chargen/intro) goes through
## `to_scene()`, which fades to black, changes the scene, then fades back in — so
## transitions never hard-cut. Also fades in once on boot.
## Alpha-only (no motion) — respects the captain's no-lurch rule.

const FADE := 0.45

var _rect: ColorRect
var _busy := false   # a swap is in flight — swallow repeat calls and stray keys
var _alpha_tw: Tween   # the one live fade tween, so a new fade cancels the old


func _ready() -> void:
	layer = 1000            # above every HUD/overlay
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 1)   # start black; fade in as the first scene loads
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_tween_alpha(0.0, FADE)   # boot fade-in


func to_scene(path: String, dur := FADE) -> void:
	## Fade to black, swap the scene, fade back in. Safe to fire-and-forget — the
	## tween runs on this autoload, which outlives the scene being replaced.
	if _busy:
		return                                       # a swap is already running — ignore repeat presses
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP   # eat input mid-transition
	await _tween_alpha(1.0, dur)
	get_tree().change_scene_to_file(path)            # the actual swap (under black)
	await get_tree().process_frame                   # let the new scene build
	await get_tree().process_frame
	await _tween_alpha(0.0, dur)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func is_busy() -> bool:
	return _busy


func _input(event: InputEvent) -> void:
	# While a swap is in flight the screen is black — swallow every key/click so
	# the outgoing scene can't fire a second transition (or re-save/re-load).
	if _busy and (event is InputEventKey or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()


func _tween_alpha(to: float, dur: float) -> Signal:
	# kill any in-flight fade first, so the boot fade-in can't fight a scene
	# swap that starts inside the 0.45s boot window (both animating color:a)
	if _alpha_tw != null and _alpha_tw.is_valid():
		_alpha_tw.kill()
	_alpha_tw = create_tween()
	_alpha_tw.tween_property(_rect, "color:a", to, dur).set_trans(Tween.TRANS_SINE)
	return _alpha_tw.finished
