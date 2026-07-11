extends CharacterBody2D
## The astronaut. Zero-g thruster movement, tethered to the ship,
## drains O2 on spacewalks, mines with a laser pistol.
## All visuals are placeholder _draw() shapes — swap for sprites later.

const THRUST := 320.0
const MAX_SPEED := 340.0
const DAMP := 0.5            # gentle drift damping so it stays controllable
const LASER_RANGE := 240.0
const OXYGEN_DRAIN := 1.5    # per second outside the ship
const REFILL_RATE := 45.0    # per second while docked

# The lifeline has some give past its rated length — a soft bungee zone,
# not a wall. Outward speed bleeds off and a pull-back force ramps up
# with stretch until you simply can't push any farther.
const TETHER_STRETCH := 90.0      # px of elastic give past max length
const TETHER_PULL := 460.0        # max pull-back accel at full stretch
const TETHER_BLEED := 10.0        # how fast outward velocity dies at full stretch

var tether_anchor := Vector2.ZERO
var in_dock := true
var laser_on := false
var laser_hit := Vector2.ZERO
var _hit_color := Color(1.0, 0.7, 0.4)
var aim_dir := Vector2.RIGHT   # body and pistol face the mouse
var thrust_input := Vector2.ZERO


func _ready() -> void:
	add_to_group("player")


const BRAKE := 4.5           # SPACE — stabilizer thrusters kill drift

var braking := false


func _physics_process(delta: float) -> void:
	# EVA controls, settled: WASD thrusts in screen directions (up is up),
	# the suit faces the mouse, and SPACE fires stabilizers to stop drift.
	_update_aim()
	thrust_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity += thrust_input * THRUST * delta
	braking = Input.is_physical_key_pressed(KEY_SPACE)
	if braking:
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-BRAKE * delta))
	velocity = velocity.limit_length(MAX_SPEED)
	velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-DAMP * delta))
	move_and_slide()
	_apply_tether(delta)
	_update_laser(delta)
	_update_oxygen(delta)
	queue_redraw()


func _apply_tether(delta: float) -> void:
	var offset := global_position - tether_anchor
	var dist := offset.length()
	var max_len: float = GameState.tether_length
	if dist <= max_len or dist == 0.0:
		return
	var n := offset / dist
	var over := dist - max_len
	# absolute end of the line — the elastic is fully stretched
	if over > TETHER_STRETCH:
		global_position = tether_anchor + n * (max_len + TETHER_STRETCH)
		over = TETHER_STRETCH
	var t := over / TETHER_STRETCH   # 0..1 how deep into the bungee zone
	# bleed outward speed progressively — no wall, just thickening resistance
	var radial := velocity.dot(n)
	if radial > 0.0:
		velocity -= n * radial * minf((2.0 + TETHER_BLEED * t) * delta, 1.0)
	# elastic pull-back ramps with stretch; at full stretch it beats the
	# thrusters, so pushing further is a losing fight, not a crash
	velocity -= n * TETHER_PULL * t * delta


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
		_hit_color = Color(1.0, 0.7, 0.4)
	else:
		laser_hit = hit["position"]
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(GameState.laser_dps * delta, laser_hit)
			# sparks glow in the vein's element color
			if "vein" in collider and collider.vein != "":
				_hit_color = Elements.hue_of(collider.vein)


func _update_oxygen(delta: float) -> void:
	if in_dock:
		GameState.refill_oxygen(REFILL_RATE * delta)
	else:
		if GameState.drain_oxygen(OXYGEN_DRAIN * delta):
			_black_out()


func _black_out() -> void:
	## You faint. The lifeline reels you home and you wake up in your bunk.
	GameState.last_lost = GameState.lose_carried()
	GameState.refill_oxygen(GameState.max_oxygen)
	GameState.wake_on_bunk = true
	get_tree().change_scene_to_file("res://scenes/ship_interior.tscn")


# ------------------------------------------------------------------
# Visuals — pixel sprite from tools/gen_sprites.gd + code-drawn extras
# ------------------------------------------------------------------
const SUIT_TEX := preload("res://assets/sprites/astronaut.png")


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
	# strain shows: gold when easy, hot red-orange and thin at full stretch
	var strain := clampf((dist - GameState.tether_length) / TETHER_STRETCH, 0.0, 1.0)
	var col := Color(1.0, 0.85, 0.3, 0.9).lerp(Color(1.0, 0.35, 0.2, 1.0), strain)
	draw_polyline(pts, col, 2.0 - strain * 0.8)


func _draw_suit() -> void:
	# thruster flame opposite to input, two-tone
	if thrust_input.length() > 0.1:
		var flame_dir := -thrust_input.normalized()
		var base := flame_dir * 14.0
		var tip := base + flame_dir * (11.0 + randf() * 6.0)
		var side := flame_dir.orthogonal() * 4.0
		draw_colored_polygon(
			PackedVector2Array([base + side, base - side, tip]),
			Color(1.0, 0.6, 0.15, 0.9))
		draw_colored_polygon(
			PackedVector2Array([base + side * 0.5, base - side * 0.5,
				base + flame_dir * 7.0]),
			Color(1.0, 0.9, 0.6, 0.9))
	# stabilizer puffs — little jets all around while braking
	if braking and velocity.length() > 12.0:
		for i in 4:
			var a := TAU * float(i) / 4.0 + PI / 4.0
			draw_circle(Vector2.from_angle(a) * 15.0, 1.8 + randf() * 1.4,
				Color(0.7, 0.9, 1.0, 0.55))
	# pixel astronaut, body faces the mouse (zero-g twist)
	draw_set_transform(Vector2.ZERO, aim_dir.angle(), Vector2(2.0, 2.0))
	draw_texture(SUIT_TEX, Vector2(-8.0, -8.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pistol() -> void:
	var grip := aim_dir * 15.0
	var tip := aim_dir * 24.0
	draw_line(grip, tip, Color(0.6, 0.65, 0.7), 5.0)
	if laser_on:
		var hit_local := to_local(laser_hit)
		draw_line(tip, hit_local, Color(1.0, 0.25, 0.2, 0.35), 6.0)
		draw_line(tip, hit_local, Color(1.0, 0.4, 0.3, 0.95), 2.0)
		draw_circle(hit_local, 4.0 + randf() * 2.0,
			Color(_hit_color.r, _hit_color.g, _hit_color.b, 0.85))
		draw_circle(hit_local, 8.0 + randf() * 3.0,
			Color(_hit_color.r, _hit_color.g, _hit_color.b, 0.25))
