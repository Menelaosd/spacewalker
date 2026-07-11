extends CharacterBody2D
## The astronaut. Zero-g thruster movement, tethered to the ship,
## drains O2 on spacewalks, mines with a laser pistol.
## All visuals are placeholder _draw() shapes — swap for sprites later.

const THRUST := 300.0
const MAX_SPEED := 340.0
const DAMP := 0.5            # gentle drift damping so it stays controllable
const LASER_RANGE := 240.0
const OXYGEN_DRAIN := 4.0    # per second outside the ship
const REFILL_RATE := 45.0    # per second while docked

var tether_anchor := Vector2.ZERO
var in_dock := true
var laser_on := false
var laser_hit := Vector2.ZERO
var aim_dir := Vector2.RIGHT
var thrust_input := Vector2.ZERO


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	thrust_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity += thrust_input * THRUST * delta
	velocity = velocity.limit_length(MAX_SPEED)
	velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-DAMP * delta))
	move_and_slide()
	_apply_tether()
	_update_aim()
	_update_laser(delta)
	_update_oxygen(delta)
	queue_redraw()


func _apply_tether() -> void:
	var offset := global_position - tether_anchor
	var dist := offset.length()
	var max_len: float = GameState.tether_length
	if dist > max_len and dist > 0.0:
		var n := offset / dist
		global_position = tether_anchor + n * max_len
		var radial := velocity.dot(n)
		if radial > 0.0:
			# kill outward velocity + a small elastic tug back
			velocity -= n * radial * 1.7


func _update_aim() -> void:
	var dir := get_global_mouse_position() - global_position
	if dir.length() > 0.001:
		aim_dir = dir.normalized()


func _update_laser(delta: float) -> void:
	laser_on = Input.is_action_pressed("fire")
	if not laser_on:
		return
	var from := global_position + aim_dir * 16.0
	var to := global_position + aim_dir * LASER_RANGE
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		laser_hit = to
	else:
		laser_hit = hit["position"]
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(GameState.laser_dps * delta, laser_hit)


func _update_oxygen(delta: float) -> void:
	if in_dock:
		GameState.refill_oxygen(REFILL_RATE * delta)
	else:
		if GameState.drain_oxygen(OXYGEN_DRAIN * delta):
			_black_out()


func _black_out() -> void:
	var lost := GameState.lose_carried()
	global_position = tether_anchor
	velocity = Vector2.ZERO
	GameState.refill_oxygen(GameState.max_oxygen)
	if lost > 0:
		GameState.say("Blacked out — the lifeline reeled you in. Lost %d ore." % lost)
	else:
		GameState.say("Blacked out — the lifeline reeled you in.")


# ------------------------------------------------------------------
# Placeholder visuals
# ------------------------------------------------------------------
func _draw() -> void:
	_draw_tether()
	_draw_suit()
	_draw_pistol()


func _draw_tether() -> void:
	var a := to_local(tether_anchor)
	var dist := a.length()
	var slack := clampf(1.0 - dist / GameState.tether_length, 0.0, 1.0)
	var sag := slack * 60.0
	var pts := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := a.lerp(Vector2.ZERO, t)
		p.y += sin(t * PI) * sag
		pts.append(p)
	draw_polyline(pts, Color(1.0, 0.85, 0.3, 0.9), 2.0)


func _draw_suit() -> void:
	# thruster flame opposite to input
	if thrust_input.length() > 0.1:
		var flame_dir := -thrust_input.normalized()
		var base := flame_dir * 14.0
		var tip := base + flame_dir * (10.0 + randf() * 6.0)
		var side := flame_dir.orthogonal() * 4.0
		draw_colored_polygon(
			PackedVector2Array([base + side, base - side, tip]),
			Color(1.0, 0.6, 0.15, 0.9)
		)
	# backpack (O2 tank)
	draw_circle(-aim_dir * 10.0, 9.0, Color(0.45, 0.48, 0.55))
	# suit body
	draw_circle(Vector2.ZERO, 14.0, Color(0.92, 0.94, 0.97))
	# visor looks toward the mouse
	draw_circle(aim_dir * 5.0, 7.5, Color(0.1, 0.2, 0.35))
	draw_circle(aim_dir * 5.0 + Vector2(-2, -2), 2.0, Color(0.7, 0.9, 1.0, 0.8))


func _draw_pistol() -> void:
	var grip := aim_dir * 15.0
	var tip := aim_dir * 24.0
	draw_line(grip, tip, Color(0.6, 0.65, 0.7), 5.0)
	if laser_on:
		var hit_local := to_local(laser_hit)
		draw_line(tip, hit_local, Color(1.0, 0.25, 0.2, 0.35), 6.0)
		draw_line(tip, hit_local, Color(1.0, 0.4, 0.3, 0.95), 2.0)
		draw_circle(hit_local, 4.0 + randf() * 2.0, Color(1.0, 0.7, 0.4, 0.8))
