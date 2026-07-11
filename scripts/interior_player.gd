extends Node2D
## Crew avatar for walking around the ship interior (top-down, in the
## captain's mini-astronaut sprites from sheet 10). No physics bodies
## indoors: we just integrate position and clamp to the hull bounds.

const SPEED := 205.0
const TARGET_H := 36.0   # world px

const F_FRONT := preload("res://assets/props/s10_00.png")
const F_FRONT_WALK := [   # synthesized by tools/gen_walk_frames.gd
	preload("res://assets/props/s10_front_a.png"),
	preload("res://assets/props/s10_front_b.png"),
]
const F_SIDE := [
	preload("res://assets/props/s10_01.png"),   # standing
	preload("res://assets/props/s10_02.png"),   # stride A
	preload("res://assets/props/s10_03.png"),   # stride B
]
const F_BACK := [
	preload("res://assets/props/s10_04.png"),
	preload("res://assets/props/s10_05.png"),
]

var bounds := Rect2()
var walk_check: Callable   # set by the interior — cell-based walkability
var facing := Vector2.DOWN
var _step := 0.0
var _moving := false


func _ready() -> void:
	# mipmapped filtering — plain linear shimmers when art this detailed
	# is drawn at a third of its native size
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
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
	if _moving:
		facing = input.normalized()
		_step += delta * 9.0
	queue_redraw()


func _pick() -> Dictionary:
	## frame + horizontal flip for the current facing/motion.
	## Walk cycle is a 4-beat: stride A, stand, stride B, stand.
	var beat := int(_step) % 4
	if absf(facing.x) > 0.35:
		var tex: Texture2D = F_SIDE[0]
		if _moving:
			match beat:
				0: tex = F_SIDE[1]
				1: tex = F_SIDE[0]
				2: tex = F_SIDE[2]
				3: tex = F_SIDE[0]
		# side frames face RIGHT in the art — mirror when walking left
		return {"tex": tex, "flip": facing.x < 0.0}
	if facing.y < -0.35:
		# two back frames alternate, with a mirror on the off-beats
		return {"tex": F_BACK[beat % 2] if _moving else F_BACK[0],
			"flip": _moving and beat >= 2}
	# front walk: synthesized stride frames, idle between steps
	if _moving:
		match beat:
			0: return {"tex": F_FRONT_WALK[0], "flip": false}
			2: return {"tex": F_FRONT_WALK[1], "flip": false}
	return {"tex": F_FRONT, "flip": false}


func _draw() -> void:
	# soft elliptical ground shadow, hugging the feet
	draw_set_transform(Vector2(0, 15), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.18))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var f := _pick()
	var tex: Texture2D = f["tex"]
	# ONE scale for everything, from the idle frame — otherwise the taller
	# synthesized stride frames make the whole body shrink mid-step
	var s := TARGET_H / F_FRONT.get_size().y
	var bob := (absf(sin(_step * PI)) * -1.8) if _moving else 0.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(-s if f["flip"] else s, s))
	# anchor the HEAD, not the center: taller frames extend downward only
	draw_texture(tex, Vector2(-tex.get_size().x * 0.5, -F_FRONT.get_size().y * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
