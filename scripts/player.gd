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
var attached := true   # false during the adrift opening — no line, no leash
var in_dock := true
var laser_on := false
var laser_hit := Vector2.ZERO
var _hit_color := Color(1.0, 0.7, 0.4)
var aim_dir := Vector2.RIGHT   # body and pistol face the mouse
var thrust_input := Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	texture_filter = TEXTURE_FILTER_LINEAR   # painted frames, not pixel art


const BRAKE := 4.5           # SPACE — stabilizer thrusters kill drift

var braking := false


func _physics_process(delta: float) -> void:
	# EVA controls, settled: WASD thrusts in screen directions (up is up),
	# the suit faces the mouse, and SPACE fires stabilizers to stop drift.
	_anim_t += delta
	_hit_t = maxf(_hit_t - delta, 0.0)
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
	if not attached:
		return
	var offset := global_position - tether_anchor
	var dist := offset.length()
	var max_len: float = GameState.tether_length
	if dist <= max_len or dist == 0.0:
		return
	var n := offset / dist
	var over := dist - max_len
	var stretch := GameState.tether_stretch()   # dampener craft extends it
	# absolute end of the line — the elastic is fully stretched
	if over > stretch:
		global_position = tether_anchor + n * (max_len + stretch)
		over = stretch
	var t := over / stretch   # 0..1 how deep into the bungee zone
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
	laser_on = Input.is_action_pressed("fire") \
		or OS.get_environment("SW_LASER") != ""   # debug: force the beam
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
		return
	# crafted emergency canister kicks in before you fade
	if GameState.canisters > 0 \
			and GameState.oxygen < GameState.max_oxygen * 0.15:
		GameState.canisters -= 1
		GameState.refill_oxygen(40.0)
		GameState.say("Emergency O2 canister discharged. (%d left)" % GameState.canisters)
	if GameState.drain_oxygen(OXYGEN_DRAIN * delta):
		_black_out()


func _black_out() -> void:
	## You faint — a limp beat of tumbling, then the bunk.
	if _dying:
		return
	_dying = true
	_anim_t = 0.0
	GameState.last_lost = GameState.lose_carried()
	GameState.wake_on_bunk = true
	GameState.pending_shift = true   # fainting costs the shift
	await get_tree().create_timer(1.1).timeout
	GameState.refill_oxygen(GameState.max_oxygen)
	get_tree().change_scene_to_file("res://scenes/ship_interior.tscn")


# ------------------------------------------------------------------
# Visuals — painted astronaut frames (game-assets, processed by
# tools/process_astronaut.gd) + code-drawn flames/tether/laser on top.
# The figure stays upright and flips toward the aim; thrust flames and
# the laser still point wherever they physically point.
# ------------------------------------------------------------------
const ASTRO: Array[Texture2D] = [
	preload("res://assets/sprites/astro/a1.png"),   # 0 idle drift A
	preload("res://assets/sprites/astro/a2.png"),   # 1 idle drift B
	preload("res://assets/sprites/astro/a3.png"),   # 2 thrust
	preload("res://assets/sprites/astro/a4.png"),   # 3 brake / star
	preload("res://assets/sprites/astro/a5.png"),   # 4 mining aim
	preload("res://assets/sprites/astro/a6.png"),   # 5 reach (tether)
	preload("res://assets/sprites/astro/a7.png"),   # 6 debris hit
	preload("res://assets/sprites/astro/a8.png"),   # 7 blackout
]
const ASTRO_SCALE := 0.5

var _anim_t := 0.0
var _hit_t := 0.0
var _dying := false


func hit_flash() -> void:
	_hit_t = 0.55


func _pick_frame() -> int:
	if _dying:
		return 7
	if _hit_t > 0.0:
		return 6
	if laser_on:
		return 4
	if not attached and global_position.distance_to(tether_anchor) < 340.0:
		return 5   # reaching for the line
	if thrust_input.length() > 0.1:
		return 2
	if braking and velocity.length() > 12.0:
		return 3
	return 0 if fmod(_anim_t, 1.3) < 0.65 else 1


func _suit_state() -> Dictionary:
	## The frame AND the exact transform that places it — shared by the
	## suit, the tether clip and the laser muzzle, so everything stays
	## glued to the same body no matter the pose.
	var f := _pick_frame()
	var rot := clampf(velocity.x * 0.0009, -0.3, 0.3)
	var sc := Vector2(ASTRO_SCALE, ASTRO_SCALE)
	if _dying:
		rot = _anim_t * 0.9   # limp slow tumble
	if f == 4:
		# the aim pose rotates with the shot; mirror vertically when
		# firing leftward so the head stays up
		rot = aim_dir.angle()
		if aim_dir.x < 0.0:
			sc.y = -ASTRO_SCALE
	else:
		var face := aim_dir.x
		if f == 2 and absf(thrust_input.x) > 0.05:
			face = thrust_input.x       # thrust pose leans where you burn
		elif f == 5:
			face = (tether_anchor - global_position).x   # reach for the line
		if face < 0.0:
			sc.x = -ASTRO_SCALE
	return {"frame": f, "xf": Transform2D(rot, sc, 0.0, Vector2.ZERO)}


func _draw() -> void:
	var st := _suit_state()
	_draw_tether(st)
	_draw_suit(st)
	_draw_pistol(st)


func _draw_tether(st: Dictionary) -> void:
	if not attached:
		return
	# the line clips to the belt, and the belt moves with the pose
	var hip: Vector2 = (st["xf"] as Transform2D) * Vector2(0, 14)
	var a := to_local(tether_anchor)
	var dist := a.length()
	var slack := clampf(1.0 - dist / GameState.tether_length, 0.0, 1.0)
	var sag := slack * 60.0
	var pts := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := a.lerp(hip, t)
		p.y += sin(t * PI) * sag
		pts.append(p)
	# strain shows: gold when easy, hot red-orange and thin at full stretch
	var strain := clampf((dist - GameState.tether_length) / GameState.tether_stretch(), 0.0, 1.0)
	var col := Color(1.0, 0.85, 0.3, 0.9).lerp(Color(1.0, 0.35, 0.2, 1.0), strain)
	draw_polyline(pts, col, 2.0 - strain * 0.8)


func _draw_suit(st: Dictionary) -> void:
	var frame: int = st["frame"]
	var xf: Transform2D = st["xf"]
	var tex: Texture2D = ASTRO[frame]
	# thruster flame fires FROM THE BACKPACK, opposite to the burn
	if thrust_input.length() > 0.1 and not _dying:
		var pack: Vector2 = xf * Vector2(-14, -14)   # backpack, pose-aware
		var flame_dir := -thrust_input.normalized()
		var base := pack + flame_dir * 5.0
		var tip := base + flame_dir * (9.0 + randf() * 5.0)
		var side := flame_dir.orthogonal() * 3.5
		draw_colored_polygon(
			PackedVector2Array([base + side, base - side, tip]),
			Color(1.0, 0.6, 0.15, 0.9))
		draw_colored_polygon(
			PackedVector2Array([base + side * 0.5, base - side * 0.5,
				base + flame_dir * 5.0]),
			Color(1.0, 0.9, 0.6, 0.9))
	# stabilizer puffs — little jets all around while braking
	if braking and velocity.length() > 12.0:
		for i in 4:
			var a := TAU * float(i) / 4.0 + PI / 4.0
			draw_circle(Vector2.from_angle(a) * 14.0, 1.6 + randf() * 1.2,
				Color(0.7, 0.9, 1.0, 0.55))
	draw_set_transform_matrix(xf)
	draw_texture(tex, -tex.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pistol(st: Dictionary) -> void:
	# the pistol lives in the aim frame's art — code draws only the beam,
	# and the beam leaves from the art's actual muzzle
	if not laser_on:
		return
	var muzzle: Vector2
	if int(st["frame"]) == 4:
		var tex: Texture2D = ASTRO[4]
		muzzle = (st["xf"] as Transform2D) \
			* Vector2(tex.get_size().x * 0.46, -tex.get_size().y * 0.20)
	else:
		muzzle = aim_dir * 14.0
	var hit_local := to_local(laser_hit)
	draw_line(muzzle, hit_local, Color(1.0, 0.25, 0.2, 0.35), 6.0)
	draw_line(muzzle, hit_local, Color(1.0, 0.4, 0.3, 0.95), 2.0)
	draw_circle(hit_local, 4.0 + randf() * 2.0,
		Color(_hit_color.r, _hit_color.g, _hit_color.b, 0.85))
	draw_circle(hit_local, 8.0 + randf() * 3.0,
		Color(_hit_color.r, _hit_color.g, _hit_color.b, 0.25))
