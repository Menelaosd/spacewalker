extends Node2D
## Crew avatar for walking around the ship interior (top-down). Real painted
## walk cycles from the captain's frame sheet (assets/sprites/walk): 7 frames
## per direction + a dedicated idle still, extracted feet-anchored on one
## common canvas so the animation never jitters. No physics bodies indoors:
## we just integrate position and clamp to the hull bounds.

const SPEED := 160.0
const TARGET_H := 38.0   # world px for the full frame canvas
const FOOT_Y := 16.0     # feet line below the node origin (shadow sits here)
# The walk clock is driven by DISTANCE, not time: advancing the cycle per pixel
# traveled makes cadence independent of frame rate and holds a steady stride.
# CYCLE_PX is ground px per FULL cycle (two footfalls), so 4- and 8-frame
# directions walk at the same rate — more frames just subdivide the stride.
# It sets BOTH cadence (footfalls/min = 120*SPEED/CYCLE_PX) and foot slide: the
# chibi's drawn stride (~16 world px/cycle, tiny next to any playable SPEED)
# can't cover the ground, so some slide is unavoidable at every setting. Too
# small a value churns the legs frantically (72 = ~267/min, a scurry); 120 lands
# ~160/min — a brisk but natural walk — for the least slide that reads as a walk.
const CYCLE_PX := 120.0

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
		var idle_path := "res://assets/sprites/walk/%s_idle.png" % d
		var idle: Texture2D = load(idle_path) if ResourceLoader.exists(idle_path) else null
		# never leave the idle null (a dropped / mis-named file would crash the
		# draw) — fall back to the first walk frame when there is one
		if idle == null and not steps.is_empty():
			idle = steps[0]
		IDLE[d] = idle
		# 2 contact poses -> interleave the idle as the passing frame
		if steps.size() == 2:
			WALK[d] = [steps[0], idle, steps[1], idle]
		elif steps.is_empty():
			# no walk frames for this dir: degrade to a static idle, never []
			WALK[d] = [idle] if idle != null else []
		else:
			WALK[d] = steps


func _process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# debug: hold a direction for screenshots — debug builds only, so a shipped
	# game can never free-walk through the hull via an env var
	var sw := OS.get_environment("SW_WALK") if OS.is_debug_build() else ""
	match sw:
		"right": input = Vector2.RIGHT
		"left": input = Vector2.LEFT
		"up": input = Vector2.UP
		"down": input = Vector2.DOWN
	var motion := input * SPEED * delta
	var before := position
	if sw != "":
		# debug capture only: free-walk through the hull so the distance-locked
		# cycle keeps advancing (real collision freezes travel at a wall, which
		# would stall _step and show a single frozen frame in screenshots)
		position += motion
	elif walk_check.is_valid():
		# axis-separated so you slide along unbuilt hull instead of sticking
		var nx := position + Vector2(motion.x, 0)
		if walk_check.call(nx):
			position = nx
		var ny := position + Vector2(0, motion.y)
		if walk_check.call(ny):
			position = ny
		# runtime un-stick: if the spot under our feet just became un-walkable
		# (a room rebuilt or furniture placed onto the avatar), ease out to the
		# nearest open spot so we can never be permanently frozen
		if not walk_check.call(position):
			for r in [10.0, 20.0, 30.0, 44.0]:
				for a in range(0, 360, 45):
					var p: Vector2 = position + Vector2.from_angle(deg_to_rad(float(a))) * r
					if walk_check.call(p):
						position = p
						break
				if walk_check.call(position):
					break
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
		# advance the cycle by GROUND ACTUALLY COVERED (blocked by a wall =
		# no travel = no stepping), so the feet never slide
		var traveled := position.distance_to(before)
		var cycle := float(WALK[_dir].size())
		if cycle > 0.0:
			var beat_was := int(_step * 2.0 / cycle)
			_step += traveled * cycle / CYCLE_PX
			# two footfalls per cycle
			if int(_step * 2.0 / cycle) != beat_was:
				Sfx.play("step", -22.0, randf_range(0.85, 1.15))
	else:
		_step = 0.0   # restart the cycle cleanly on the next move
	queue_redraw()


# cycle EASING: contact poses hold longer than passing poses — even per-frame
# timing reads as a metronome robot; walks ease (contact is the weight-bearing
# beat). Boundaries are cumulative sums. HOLD8 follows the researched gait
# weights [1.30, 1.10, 0.85, 0.75]×2 (real walks spend ~60% of the cycle in
# stance; the up frame is shortest — the body FALLS fast into the next contact).
const HOLD4 := [0.0, 0.30, 0.50, 0.80, 1.0]
const HOLD8 := [0.0, 0.1625, 0.30, 0.40625, 0.50, 0.6625, 0.80, 0.90625, 1.0]


func _phase() -> float:
	## walk-cycle phase 0..1 (contacts at 0 and .5 — the beat grid)
	var cycle := float(WALK[_dir].size())
	if cycle <= 0.0:
		return 0.0
	return fmod(_step, cycle) / cycle


func _frame() -> Texture2D:
	if _moving:
		var frames: Array = WALK[_dir]
		if frames.is_empty():
			return IDLE[_dir]
		var holds: Array = HOLD4 if frames.size() == 4 else (
			HOLD8 if frames.size() == 8 else [])
		if not holds.is_empty():
			var p := _phase()
			for i in frames.size():
				if p < holds[i + 1]:
					return frames[i]
			return frames[frames.size() - 1]
		return frames[int(_step) % frames.size()]
	return IDLE[_dir]


func _bob() -> float:
	## stride bob: the body sits LOWEST on the contact holds and rises through
	## the passing frames — the missing ingredient that makes a flat glide
	## read as actual steps. ~1px = ~2.5% of body height (more reads as a
	## bouncing balloon on a helmet-heavy chibi). Phase-shifted so the dips
	## centre on the contact frames' display windows.
	if not _moving:
		return 0.0
	var dip := 0.08 if WALK[_dir].size() == 8 else 0.15
	return 1.0 * absf(sin((_phase() - dip) * TAU))


func _draw() -> void:
	# soft elliptical ground shadow, hugging the feet
	draw_set_transform(Vector2(0, FOOT_Y - 1.0), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.18))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tex := _frame()
	if tex == null:
		return   # this direction has no art at all — skip the sprite draw
	# every frame shares ONE canvas (feet bottom-aligned, centred), so one
	# scale for everything and zero jitter between frames
	var s := TARGET_H / tex.get_size().y
	var tw := tex.get_size().x
	var th := tex.get_size().y
	if _moving:
		# stride bob lifts the whole body between contacts (shadow stays put,
		# which grounds the feet)
		draw_set_transform(Vector2(0.0, -_bob()), 0.0, Vector2(s, s))
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
