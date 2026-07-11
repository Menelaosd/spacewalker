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
var _streaks: Array = []       # shooting stars: {pos, vel, size, life}
var _streak_timer := 4.0
var _t := 0.0
var ship: Node2D
var player: Node2D

# --- rescue encounter (THE SCATTERED SIX) ---
const NPC_TEX := preload("res://assets/sprites/astro/a1.png")
const NPC_TINTS := {
	"JUNO": Color(1.15, 1.0, 0.72), "MIRA": Color(0.78, 1.12, 0.85),
	"HALE": Color(0.8, 1.0, 1.15), "SOLA": Color(1.15, 0.85, 0.85),
	"VEGA": Color(1.0, 0.88, 1.2),
}
var _rescue_active := false
var _npc_pos := Vector2.ZERO

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

	if OS.get_environment("SW_ADRIFT") != "":
		GameState.adrift = true   # debug hook for screenshots/tests
	if GameState.adrift:
		# the opening: the flare threw you clear. No line. Get to the ship.
		player.attached = false
		player.in_dock = false
		player.position = Vector2.from_angle(randf_range(-2.4, -0.7)) \
			* randf_range(820.0, 980.0)
		GameState.say("You're adrift — no lifeline. That's your ship, %s. Reach it." \
			% GameState.pilot_name())
	elif GameState.sector == Vector2.ZERO:
		GameState.say("Welcome aboard. Hold LMB to mine. Bring ore back to the ship.")
	else:
		GameState.say("Parked in %s — rich chance ~%d%%. Watch your O2." % [
			GameState.region_at(GameState.sector)["name"],
			int(GameState.sector_richness() * 100.0)])

	# a lost friend drifts somewhere near the wreck
	_rescue_active = GameState.at_rescue_site()
	if _rescue_active:
		var rrng := RandomNumberGenerator.new()
		rrng.seed = GameState.rescued_count() * 991 + 55
		_npc_pos = Vector2.from_angle(rrng.randf() * TAU) \
			* rrng.randf_range(380.0, 520.0)
		Sfx.play("radio", -6.0)
		GameState.say("Short-range ping... %s is HERE. Find them, %s." % [
			GameState.rescue_target()["name"], GameState.pilot_name()])

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
	_t += delta
	_update_adrift()
	_update_rescue()
	_update_flare(delta)
	_update_debris(delta)
	_update_streaks(delta)
	queue_redraw()   # parallax stars + hazards follow the camera


func _update_rescue() -> void:
	## Reaching the drifting survivor brings them aboard — perk, radio
	## line, and one more bunk filled.
	if not _rescue_active or player == null:
		return
	if player.global_position.distance_to(_npc_pos) < 70.0:
		_rescue_active = false
		var r := GameState.do_rescue()
		Sfx.play("radio", -6.0)
		Sfx.play("upgrade", -3.0)
		GameState.say(r["line"])
		_rescue_followup(r)


func _rescue_followup(r: Dictionary) -> void:
	await get_tree().create_timer(3.2).timeout
	if is_inside_tree():
		GameState.say("%s the %s is aboard — %d/5 found. Perk: %s." % [
			r["name"], r["role"], GameState.rescued_count(), r["perk"]])


func _update_adrift() -> void:
	## The opening beat: float home, and the lifeline clips on when you
	## touch the hull's reach. From then on the game is the game.
	if not GameState.adrift or player == null:
		return
	if player.global_position.distance_to(ship.anchor_point()) < 150.0:
		GameState.adrift = false
		player.attached = true
		Sfx.play("clack", -2.0)
		GameState.say("CLACK. Lifeline secured. Never let it go, %s." \
			% GameState.pilot_name())


func _update_streaks(delta: float) -> void:
	## Shooting stars — a flick of light every so often keeps the sky alive.
	_streak_timer -= delta
	if _streak_timer <= 0.0 and player != null:
		_streak_timer = randf_range(5.0, 13.0)
		var a := randf() * TAU
		var start: Vector2 = player.global_position + Vector2.from_angle(a) * 780.0
		_streaks.append({
			"pos": start,
			"vel": (player.global_position - start).normalized() \
				.rotated(randf_range(-0.8, 0.8)) * randf_range(900.0, 1400.0),
			"size": randf_range(1.1, 1.9),
			"life": randf_range(0.6, 1.0),
		})
	var keep: Array = []
	for s in _streaks:
		s["pos"] += (s["vel"] as Vector2) * delta
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) > 0.0:
			keep.append(s)
	_streaks = keep


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
				Sfx.klaxon_on(true)
				GameState.say("⚠ SOLAR FLARE INBOUND — get behind rock or dock!")
		"warn":
			_flare_t -= delta
			if _flare_t <= 0.0:
				GameState.flare_phase = "burn"
				_flare_t = FLARE_BURN
				Sfx.klaxon_on(false)
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
			player.hit_flash()
			Sfx.play("thud", -3.0)
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
	## Four parallax depth layers, properly dense — the pattern square is
	## 5200px wide and the view sees ~4% of it, so counts must be big.
	## Off-screen stars are culled at draw time. [pos, size, alpha, depth]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for layer in [[0.12, 900, 0.3, 0.7, 0.3], [0.25, 1300, 0.4, 1.0, 0.4],
			[0.55, 800, 0.8, 1.7, 0.65], [1.0, 500, 1.2, 2.6, 1.0]]:
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
		# haze thickness follows the nebula's own size
		var fs: float = GameState.nebula_radius(neb) / 2400.0 * 14.0
		draw_set_transform(Vector2.ZERO, 0.4, Vector2(fs, fs))
		draw_texture(tex, -half_tex, Color(1, 1, 1, 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# parallax: far stars track the camera, near stars sweep past.
	# Only what's on screen gets drawn — the pattern is much bigger.
	var cam := player.global_position if player != null else Vector2.ZERO
	var vp := get_viewport_rect().size
	var star_view := Rect2(cam - vp * 0.5 - Vector2(8, 8), vp + Vector2(16, 16))
	for s in _stars:
		var p: Vector2 = s[0] + cam * (1.0 - s[3])
		if star_view.has_point(p):
			draw_circle(p, s[1], Color(1, 1, 1, s[2]))
	# shooting stars
	for st in _streaks:
		SpaceDressing.draw_comet(self, st, _t)
	# faint ring showing max tether reach
	draw_arc(Vector2(0, 48), GameState.tether_length, 0.0, TAU, 96,
		Color(1.0, 0.85, 0.3, 0.08), 2.0)

	# the drifting survivor at a rescue site — tinted suit, strobing ping
	if _rescue_active:
		var nname: String = GameState.rescue_target().get("name", "")
		var tint: Color = NPC_TINTS.get(nname, Color.WHITE)
		var bob := sin(_t * 1.3) * 5.0
		var np := _npc_pos + Vector2(0, bob)
		var pulse := 0.5 + 0.5 * sin(_t * 4.5)
		draw_arc(np, 30.0 + pulse * 16.0, 0.0, TAU, 32,
			Color(1.0, 0.85, 0.3, 0.55 - 0.35 * pulse), 2.0)
		draw_set_transform(np, sin(_t * 0.5) * 0.18, Vector2(0.45, 0.45))
		draw_texture(NPC_TEX, -NPC_TEX.get_size() * 0.5, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string(ThemeDB.fallback_font, np + Vector2(-50, -34), nname,
			HORIZONTAL_ALIGNMENT_CENTER, 100, 13,
			Color(1.0, 0.85, 0.3, 0.5 + 0.4 * pulse))

	# guidance chevrons: toward the ship while adrift, toward the
	# survivor at a rescue site
	var guide_to := Vector2.INF
	if GameState.adrift and player != null:
		guide_to = ship.anchor_point()
	elif _rescue_active and player != null:
		guide_to = _npc_pos
	if guide_to != Vector2.INF:
		var to_t: Vector2 = guide_to - player.global_position
		var dir := to_t.normalized()
		var side := dir.orthogonal() * 7.0
		for i in 3:
			var d := 60.0 + float(i) * 26.0 + fmod(_t * 40.0, 26.0)
			if d > to_t.length() - 100.0:
				continue
			var base: Vector2 = player.global_position + dir * d
			var a := 0.7 - float(i) * 0.15
			draw_polyline(PackedVector2Array([
				base - dir * 9.0 + side, base, base - dir * 9.0 - side]),
				Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, a), 2.5)

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
