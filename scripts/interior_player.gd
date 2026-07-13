extends Node2D
## Crew avatar for walking around the ship interior (top-down). Real painted
## walk cycles from the captain's frame sheet (assets/sprites/walk): 7 frames
## per direction + a dedicated idle still, extracted feet-anchored on one
## common canvas so the animation never jitters. No physics bodies indoors:
## we just integrate position and clamp to the hull bounds.

const SPEED := 205.0
const TARGET_H := 38.0   # world px for the full frame canvas
const FOOT_Y := 16.0     # feet line below the node origin (shadow sits here)
const WALK_FPS := 6.0   # 4-frame cycle → ~1.5 cycles/s; 10 was frantic

# frame sets built in _ready. Each direction keeps TWO opposite-leg contact
# poses; the walk cycle interleaves the idle as the passing frame —
# step A, stand, step B, stand — the classic 4-beat top-down walk.
var WALK := {}   # dir -> [stepA, idle, stepB, idle]
var IDLE := {}

var bounds := Rect2()
var walk_check: Callable   # set by the interior — cell-based walkability
var facing := Vector2.DOWN
var _dir := "front"        # which frame set we're on
var _step := 0.0           # walk-cycle clock (frames)
var _moving := false
var _breath := 0.0


func _ready() -> void:
	# mipmapped filtering — plain linear shimmers when art this detailed
	# is drawn at a third of its native size
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for d in ["right", "left", "front", "back"]:
		var steps: Array = []
		var i := 0
		while ResourceLoader.exists("res://assets/sprites/walk/%s_%d.png" % [d, i]):
			steps.append(load("res://assets/sprites/walk/%s_%d.png" % [d, i]))
			i += 1
		var idle: Texture2D = load("res://assets/sprites/walk/%s_idle.png" % d)
		IDLE[d] = idle
		# 2 contact poses -> interleave the idle as the passing frame
		WALK[d] = [steps[0], idle, steps[1], idle] if steps.size() == 2 else steps


func _process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	match OS.get_environment("SW_WALK"):   # debug: hold a direction for screenshots
		"right": input = Vector2.RIGHT
		"left": input = Vector2.LEFT
		"up": input = Vector2.UP
		"down": input = Vector2.DOWN
	var motion := input * SPEED * delta
	if walk_check.is_valid():
		# axis-separated so you slide along unbuilt hull instead of sticking
		var nx := position + Vector2(motion.x, 0)
		if walk_check.call(nx):
			position = nx
		var ny := position + Vector2(0, motion.y)
		if walk_check.call(ny):
			position = ny
	else:
		position += motion
		if bounds.size != Vector2.ZERO:
			position.x = clampf(position.x, bounds.position.x, bounds.end.x)
			position.y = clampf(position.y, bounds.position.y, bounds.end.y)
	_moving = input.length() > 0.1
	_breath += delta
	if _moving:
		facing = input.normalized()
		if absf(facing.x) > 0.35:
			_dir = "right" if facing.x > 0.0 else "left"
		else:
			_dir = "back" if facing.y < 0.0 else "front"
		var cycle := float(WALK[_dir].size())
		var beat_was := int(_step * 2.0 / cycle)
		_step += delta * WALK_FPS
		# two footfalls per cycle
		if int(_step * 2.0 / cycle) != beat_was:
			Sfx.play("step", -22.0, randf_range(0.85, 1.15))
	else:
		_step = 0.0   # restart the cycle cleanly on the next move
	queue_redraw()


func _frame() -> Texture2D:
	if _moving:
		var frames: Array = WALK[_dir]
		return frames[int(_step) % frames.size()]
	return IDLE[_dir]


func _draw() -> void:
	# soft elliptical ground shadow, hugging the feet
	draw_set_transform(Vector2(0, FOOT_Y - 1.0), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.18))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tex := _frame()
	# every frame shares ONE canvas (feet bottom-aligned, centred), so one
	# scale for everything and zero jitter between frames
	var s := TARGET_H / tex.get_size().y
	var tw := tex.get_size().x
	var th := tex.get_size().y
	if _moving:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		draw_texture(tex, Vector2(-tw * 0.5, FOOT_Y / s - th))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# idle: ONLY the chest breathes — the middle slice puffs a hair wider;
		# head and legs hold perfectly still
		var br := maxf(sin(_breath * 1.6), 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		var top := FOOT_Y / s - th
		_slice(tex, top, tw, th, 0.0, 0.38, 1.0)               # head — still
		_slice(tex, top, tw, th, 0.38, 0.62, 1.0 + 0.08 * br)  # chest — breathes
		_slice(tex, top, tw, th, 0.62, 1.0, 1.0)               # legs — still
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _slice(tex: Texture2D, top: float, tw: float, th: float,
		a: float, b: float, w: float) -> void:
	## Draw a horizontal band of the sprite, its width scaled by w.
	var src := Rect2(0, th * a, tw, th * (b - a))
	var dw := tw * w
	draw_texture_rect_region(tex, Rect2(-dw * 0.5, top + th * a, dw, th * (b - a)), src)
