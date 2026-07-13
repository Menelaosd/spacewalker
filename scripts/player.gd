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
const TETHER_STRETCH := 46.0      # px of elastic give past max length — a SLIGHT
                                  # bungee, not a big rubber-band bounce
const TETHER_PULL := 520.0        # max pull-back accel at full stretch
const TETHER_BLEED := 12.0        # how fast outward velocity dies at full stretch

var tether_anchor := Vector2.ZERO
var attached := true   # false during the adrift opening — no line, no leash
var in_dock := true
var laser_on := false
var laser_hit := Vector2.ZERO
var _hit_color := Color(1.0, 0.7, 0.4)
var _spark_cd := 0.0
var aim_dir := Vector2.RIGHT   # body and pistol face the mouse
var thrust_input := Vector2.ZERO
var _face := 1.0               # latched horizontal facing from last movement


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
	# latch facing from actual movement — thrust input first, else drift — so
	# the suit keeps facing the way it was going when the animation changes
	if absf(thrust_input.x) > 0.05:
		_face = signf(thrust_input.x)
	elif absf(velocity.x) > 20.0:
		_face = signf(velocity.x)
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
	Sfx.thrust_on(thrust_input.length() > 0.1 and not _dying)
	queue_redraw()


func _exit_tree() -> void:
	Sfx.stop_loops()


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


func _muzzle_world() -> Vector2:
	## The aim frame's actual gun tip, in world space — the beam and the
	## raycast both start HERE, so fire always leaves the barrel.
	var tex: Texture2D = ASTRO[4]
	# gun-tip pixel in a5.png, pixel-detected relative to the texture centre:
	# the barrel muzzle sits at the sprite's right edge, up near the shoulder
	var m := Vector2(tex.get_size().x * 0.48, -tex.get_size().y * 0.305)
	if aim_dir.x < 0.0:
		m.y = -m.y   # the aim pose mirrors vertically when firing left
	return global_position + (m * ASTRO_SCALE).rotated(aim_dir.angle())


func _update_laser(delta: float) -> void:
	laser_on = (Input.is_action_pressed("fire") \
		or OS.get_environment("SW_LASER") != "") and not _dying
	Sfx.laser_on(laser_on and not _dying)
	if not laser_on:
		return
	var from := _muzzle_world()
	var to := from + aim_dir * LASER_RANGE
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
			# throttled weld spatter flying back off the cut
			_spark_cd -= delta
			if _spark_cd <= 0.0:
				_spark_cd = 0.04
				Vfx.spark_hit(get_parent(), laser_hit, _hit_color, aim_dir)


func _update_oxygen(delta: float) -> void:
	if _dying:
		return   # already fainting — don't waste canisters on a dead tank
	if in_dock:
		GameState.refill_oxygen(REFILL_RATE * delta)
		return
	# crafted emergency canister kicks in before you fade
	if GameState.canisters > 0 \
			and GameState.oxygen < GameState.max_oxygen * 0.15:
		GameState.canisters -= 1
		GameState.refill_oxygen(40.0)
		Sfx.play("hiss", -6.0)
		GameState.say("Emergency O2 canister discharged. (%d left)" % GameState.canisters)
	var frac_before := GameState.oxygen / GameState.max_oxygen
	if GameState.drain_oxygen(OXYGEN_DRAIN * delta):
		_black_out()
	elif frac_before >= 0.25 and GameState.oxygen / GameState.max_oxygen < 0.25:
		Sfx.play("o2low", -4.0)   # crossing into the red


func _black_out() -> void:
	## You faint — a limp beat of tumbling, then the bunk.
	if _dying:
		return
	_dying = true
	_anim_t = 0.0
	Sfx.stop_loops()
	Sfx.play("thud", -4.0, 0.7)
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
	# SPACE always shows the stabilizer/stop pose — even if a thrust key is
	# also held (braking wins over the burn, the captain's call)
	if braking:
		return 3
	if not attached and global_position.distance_to(tether_anchor) < 340.0:
		return 5   # reaching for the line
	if thrust_input.length() > 0.1:
		return 2
	return 0 if fmod(_anim_t, 1.3) < 0.65 else 1


func _suit_state() -> Dictionary:
	## The frame AND the exact transform that places it — shared by the
	## suit, the tether clip and the laser muzzle, so everything stays
	## glued to the same body no matter the pose.
	var f := _pick_frame()
	# lean into the drift: a gentle tilt along the velocity, stronger the
	# faster you move (kept small so the suit stays upright)
	var rot := clampf(velocity.x * 0.0012, -0.32, 0.32) \
		+ clampf(velocity.y * 0.0004, -0.12, 0.12) * _face
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
		# clean instant flip toward the way we're moving (no squash pivot)
		var face := _face
		if f == 5:
			face = signf((tether_anchor - global_position).x)
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
	# the line clips to the BACKPACK, and follows the pose
	var hip: Vector2 = (st["xf"] as Transform2D) * Vector2(-13, -6)
	var a := to_local(tether_anchor)
	var dist := a.length()
	var slack := clampf(1.0 - dist / GameState.tether_length, 0.0, 1.0)
	# sag scales with the SPAN — a short line near the ship must not droop a
	# fixed 60px into a loop hanging below the astronaut
	var sag := slack * clampf(dist * 0.28, 0.0, 60.0)
	var pts := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := a.lerp(hip, t)
		p.y += sin(t * PI) * sag
		pts.append(p)
	# strain shows: gold when easy, hot red-orange and thin at full stretch
	var strain := clampf((dist - GameState.tether_length) / GameState.tether_stretch(), 0.0, 1.0)
	var col := Color(1.0, 0.85, 0.3, 0.9).lerp(Color(1.0, 0.35, 0.2, 1.0), strain)
	# a solid line, faintly SEGMENTED — small dashes over a continuous
	# under-line, so it reads as a woven lifeline without looking busy. The
	# dashes open a touch as it stretches. Visual only.
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.85), 1.8 - strain * 0.6)
	var w := 2.2 - strain * 0.7
	var dash := 4.0 + strain * 3.0
	var gap := 2.0
	var acc := 0.0
	var draw_on := true
	for i in pts.size() - 1:
		var seg := pts[i + 1] - pts[i]
		var seg_len := seg.length()
		if seg_len < 0.001:
			continue
		var dir := seg / seg_len
		var used := 0.0
		while used < seg_len:
			var span := (dash if draw_on else gap) - acc
			var step := minf(span, seg_len - used)
			if draw_on:
				draw_line(pts[i] + dir * used, pts[i] + dir * (used + step),
					col.lightened(0.15), w)
			used += step
			acc += step
			if acc >= (dash if draw_on else gap):
				acc = 0.0
				draw_on = not draw_on


func _draw_suit(st: Dictionary) -> void:
	var frame: int = st["frame"]
	var xf: Transform2D = st["xf"]
	var tex: Texture2D = ASTRO[frame]
	# thruster flame fires from the BOTTOM of the backpack, opposite the burn
	if thrust_input.length() > 0.1 and not _dying:
		var pack: Vector2 = xf * Vector2(-13, 2)   # backpack nozzle, pose-aware
		var flame_dir := -thrust_input.normalized()
		var base := pack + flame_dir * 3.0
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
	if braking:
		for i in 4:
			var a := TAU * float(i) / 4.0 + PI / 4.0
			draw_circle(Vector2.from_angle(a) * 14.0, 1.6 + randf() * 1.2,
				Color(0.7, 0.9, 1.0, 0.55))
	# idle bob — when just drifting (not thrusting / braking / mining / dying),
	# the suit rises and settles a hair, like floating breath in zero-g
	var bob := 0.0
	if not _dying and thrust_input.length() <= 0.1 and not braking and not laser_on:
		bob = sin(_anim_t * 1.6) * 1.3
	draw_set_transform_matrix(xf.translated(Vector2(0, bob)))
	if frame <= 1:
		# idle drift: CROSSFADE the two idle frames instead of hard-toggling,
		# so the float reads as a smooth loop rather than a two-frame flicker
		var blend := 0.5 + 0.5 * sin(_anim_t * 1.4)
		draw_texture(ASTRO[0], -ASTRO[0].get_size() * 0.5, Color(1, 1, 1, 1.0 - blend))
		draw_texture(ASTRO[1], -ASTRO[1].get_size() * 0.5, Color(1, 1, 1, blend))
	else:
		draw_texture(tex, -tex.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pistol(st: Dictionary) -> void:
	# the pistol lives in the aim frame's art — code draws only the beam,
	# which starts at the SAME muzzle point the raycast fires from
	if not laser_on:
		return
	var muzzle := to_local(_muzzle_world())
	var hit_local := to_local(laser_hit)
	draw_line(muzzle, hit_local, Color(1.0, 0.25, 0.2, 0.35), 6.0)
	draw_line(muzzle, hit_local, Color(1.0, 0.4, 0.3, 0.95), 2.0)
	# muzzle flash anchors the emission at the barrel
	draw_circle(muzzle, 3.0 + randf() * 1.5, Color(1.0, 0.9, 0.7, 0.9))
	draw_circle(muzzle, 6.5 + randf() * 2.0, Color(1.0, 0.5, 0.3, 0.3))
	draw_circle(hit_local, 4.0 + randf() * 2.0,
		Color(_hit_color.r, _hit_color.g, _hit_color.b, 0.85))
	draw_circle(hit_local, 8.0 + randf() * 3.0,
		Color(_hit_color.r, _hit_color.g, _hit_color.b, 0.25))
