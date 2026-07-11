extends Node2D
## World scene. Spawns the ship, player, asteroid field and HUD.
## Draws the star background and the tether range ring.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SHIP_SCENE := preload("res://scenes/ship.tscn")
const ASTEROID_SCENE := preload("res://scenes/asteroid.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")

const ASTEROID_COUNT := 22
const FLARE_WARN := 7.0        # seconds of klaxon before the burn
const FLARE_BURN := 6.0
const FLARE_DRAIN := 5.0       # extra O2/s while exposed
const SHELTER_DIST := 130.0    # hide this close to a rock to survive it

var _stars: Array = []
var ship: Node2D
var player: Node2D

# --- hazards ---
var _flare_timer := 0.0
var _flare_t := 0.0
var _debris: Array = []        # {pos, vel, r}
var _debris_timer := 0.0
var _debris_hit_cd := 0.0


func _ready() -> void:
	_make_stars()

	ship = SHIP_SCENE.instantiate()
	add_child(ship)

	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(0, 100)
	add_child(player)
	player.tether_anchor = ship.anchor_point()

	_spawn_asteroids()
	add_child(HUD_SCENE.instantiate())

	if GameState.sector == Vector2.ZERO:
		GameState.say("Welcome aboard. Hold LMB to mine. Bring ore back to the ship.")
	else:
		GameState.say("Parked in %s — rich chance ~%d%%. Watch your O2." % [
			GameState.region_at(GameState.sector)["name"],
			int(GameState.sector_richness() * 100.0)])

	# hazard clocks — flares come sooner in Ember Reach and The Expanse
	GameState.flare_phase = ""
	var rname: String = GameState.region_at(GameState.sector)["name"]
	var hot := rname == "Ember Reach" or rname == "The Expanse"
	_flare_timer = randf_range(35.0, 70.0) if hot else randf_range(70.0, 140.0)
	if OS.get_environment("SW_FORCE_FLARE") != "":
		_flare_timer = 1.5
	_debris_timer = randf_range(6.0, 14.0) if rname == "The Belt" \
		else randf_range(18.0, 34.0)


func _process(delta: float) -> void:
	_update_flare(delta)
	_update_debris(delta)
	queue_redraw()   # parallax stars + hazards follow the camera


func _sheltered() -> bool:
	if player == null:
		return false
	if player.in_dock:
		return true
	for a in get_tree().get_nodes_in_group("asteroids"):
		if player.global_position.distance_to(a.global_position) < SHELTER_DIST + a.radius:
			return true
	return false


func _update_flare(delta: float) -> void:
	match GameState.flare_phase:
		"":
			_flare_timer -= delta
			if _flare_timer <= 0.0:
				GameState.flare_phase = "warn"
				_flare_t = FLARE_WARN
				GameState.say("⚠ SOLAR FLARE INBOUND — get behind rock or dock!")
		"warn":
			_flare_t -= delta
			if _flare_t <= 0.0:
				GameState.flare_phase = "burn"
				_flare_t = FLARE_BURN
		"burn":
			_flare_t -= delta
			if player != null and not _sheltered():
				if GameState.drain_oxygen(FLARE_DRAIN * delta):
					pass   # blackout is handled by the player as usual
			if _flare_t <= 0.0:
				GameState.flare_phase = ""
				_flare_timer = randf_range(80.0, 150.0)
				GameState.say("Flare passed. Radiation nominal.")


func _update_debris(delta: float) -> void:
	_debris_hit_cd = maxf(_debris_hit_cd - delta, 0.0)
	_debris_timer -= delta
	if _debris_timer <= 0.0 and player != null:
		_debris_timer = randf_range(9.0, 20.0)
		if GameState.region_at(GameState.sector)["name"] == "The Belt":
			_debris_timer *= 0.45
		var ang := randf() * TAU
		var start: Vector2 = player.global_position + Vector2.from_angle(ang) * 1300.0
		_debris.append({
			"pos": start,
			"vel": (player.global_position - start).normalized().rotated(
				randf_range(-0.3, 0.3)) * randf_range(170.0, 260.0),
			"r": randf_range(9.0, 16.0),
		})
	var keep: Array = []
	for d in _debris:
		d["pos"] += d["vel"] * delta
		if player != null and _debris_hit_cd <= 0.0 \
				and d["pos"].distance_to(player.global_position) < d["r"] + 14.0:
			_debris_hit_cd = 1.5
			player.velocity += d["vel"] * 0.7
			GameState.drain_oxygen(8.0)
			GameState.say("Debris strike! Suit integrity holding — O2 vented.")
		if player == null or d["pos"].distance_to(player.global_position) < 1800.0:
			keep.append(d)
	_debris = keep


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and player != null and player.in_dock:
			# Step inside the ship. Bank whatever we're carrying first.
			GameState.bank_cargo()
			get_tree().change_scene_to_file("res://scenes/ship_interior.tscn")


func _make_stars() -> void:
	## Three parallax depth layers: [pos, size, alpha, depth]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for layer in [[0.25, 220, 0.4, 1.0, 0.4], [0.55, 140, 0.8, 1.7, 0.65],
			[1.0, 90, 1.2, 2.6, 1.0]]:
		for i in int(layer[1]):
			_stars.append([
				Vector2(rng.randf_range(-2600, 2600), rng.randf_range(-2600, 2600)),
				rng.randf_range(layer[2], layer[3]),
				rng.randf_range(0.25, 0.9) * float(layer[4]),
				layer[0],
			])


func _spawn_asteroids() -> void:
	# the dive field takes on the character of the region you parked in:
	# Home Reach is sparse practice rock, The Belt is a dense quarry,
	# The Expanse is few-but-huge, nebulae are tinted and crystal-heavy
	var region: Dictionary = GameState.region_at(GameState.sector)
	var rich_chance := GameState.sector_richness()
	var size_mult: float = region["size"]
	var count := 14 + int(26.0 * float(region["chance"])) \
		+ mini(int(GameState.sector.length() / 4000.0), 8)
	var base_tint := Color(0.42, 0.4, 0.38)
	if region["tint"] != null:
		base_tint = base_tint.lerp(region["tint"], 0.35)
	var placed: Array = []
	var tries := 0
	while placed.size() < count and tries < 800:
		tries += 1
		var ang := randf() * TAU
		# some asteroids sit past the tether limit — upgrade bait
		var dist := randf_range(280.0, GameState.tether_length + 320.0)
		var pos := Vector2.from_angle(ang) * dist
		var r := randf_range(18.0, 40.0) * size_mult
		var ok := true
		for p in placed:
			if pos.distance_to(p[0]) < (r + p[1] + 60.0):
				ok = false
				break
		if not ok:
			continue
		placed.append([pos, r])
		var a := ASTEROID_SCENE.instantiate()
		a.setup(r, randf() < rich_chance, base_tint)
		a.position = pos
		add_child(a)


func _draw() -> void:
	# nebula fog when parked inside one — the dive site belongs to a place
	var neb := GameState.nebula_index_at(GameState.sector)
	if neb >= 0:
		var tex := NebulaFog.texture_for(neb)
		var half_tex := Vector2(NebulaFog.SIZE, NebulaFog.SIZE) * 0.5
		draw_set_transform(Vector2.ZERO, 0.4, Vector2(14.0, 14.0))
		draw_texture(tex, -half_tex, Color(1, 1, 1, 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# parallax: far stars track the camera, near stars sweep past
	var cam := player.global_position if player != null else Vector2.ZERO
	for s in _stars:
		draw_circle(s[0] + cam * (1.0 - s[3]), s[1], Color(1, 1, 1, s[2]))
	# faint ring showing max tether reach
	draw_arc(Vector2(0, 48), GameState.tether_length, 0.0, TAU, 96,
		Color(1.0, 0.85, 0.3, 0.08), 2.0)

	# debris — tumbling fast rock with a motion trail
	for d in _debris:
		var dp: Vector2 = d["pos"]
		var dv: Vector2 = (d["vel"] as Vector2).normalized()
		draw_line(dp - dv * d["r"] * 3.5, dp, Color(1.0, 0.7, 0.4, 0.25), d["r"] * 0.7)
		draw_circle(dp, d["r"], Color(0.45, 0.4, 0.36))
		draw_circle(dp + dv.orthogonal() * d["r"] * 0.3, d["r"] * 0.4, Color(0.3, 0.27, 0.24))
	# flare wash over the world
	if GameState.flare_phase != "" and player != null:
		var view := Rect2(player.global_position - Vector2(660, 380), Vector2(1320, 760))
		if GameState.flare_phase == "warn":
			draw_rect(view, Color(1.0, 0.5, 0.15,
				0.05 + 0.05 * absf(sin(Time.get_ticks_msec() * 0.008))), true)
		else:
			draw_rect(view, Color(1.0, 0.55, 0.2, 0.16), true)
			# radiation streaks racing across
			for i in 14:
				var yy := view.position.y + fmod(float(i) * 61.7 + Time.get_ticks_msec() * 0.12, 760.0)
				draw_line(Vector2(view.position.x, yy), Vector2(view.position.x + 260, yy - 30),
					Color(1.0, 0.8, 0.4, 0.18), 2.0)
