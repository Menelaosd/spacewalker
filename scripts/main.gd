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
var _streaks: Array = []       # shooting stars: {pos, vel, life, aframe}
var _streak_timer := 4.0
const STAR_SPRITE_DIR := "res://assets/sprites/comets/"
const STAR_ID := "comet_star"  # the "shooting star" look (matches cruise)
const STAR_FRAMES := 7
const STAR_ANIM_FPS := 11.0
const STAR_DRAW_MAX := 78.0    # longest side px
var _streak_frames: Array[Texture2D] = []
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


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # keep the small streak crisp
	_make_stars()
	_load_streak_sprite()
	Sfx.ambient("amb_suit")   # the suit's close, breathing hum on a spacewalk

	ship = SHIP_SCENE.instantiate()
	add_child(ship)

	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(0, 100)
	add_child(player)
	player.tether_anchor = ship.anchor_point()

	_spawn_asteroids()
	add_child(HUD_SCENE.instantiate())

	if OS.get_environment("SW_GAMEOVER") != "":
		# debug hook for screenshots — pop the out-of-oxygen screen on load
		var _golay := CanvasLayer.new()
		_golay.layer = 100
		_golay.add_child(preload("res://scripts/game_over.gd").new())
		add_child(_golay)

	if OS.get_environment("SW_ADRIFT") != "":
		GameState.adrift = true   # debug hook for screenshots/tests
	if GameState.adrift:
		# the opening: HELIOS cast you out, untethered. No line. Get to the ship.
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

	# rescues happen at the HELM now — you board their broken ship and meet
	# them face to face (dialog_scene). Spacewalking near the site just
	# points the player back to the cockpit.
	_rescue_active = false
	if GameState.at_rescue_site():
		Sfx.play("radio", -6.0)
		GameState.say("That's %s's ship out there, dead in the black. Take the helm and board it." % \
			GameState.rescue_target()["name"])

	# hazard clocks — flares come sooner in Ember Reach and The Expanse
	GameState.flare_phase = ""
	var rname: String = GameState.region_at(GameState.sector)["name"]
	var hot := rname == "Ember Reach" or rname == "The Expanse"
	_flare_timer = randf_range(35.0, 70.0) if hot else randf_range(70.0, 140.0)
	if OS.get_environment("SW_FORCE_FLARE") != "":
		_flare_timer = 1.5


func _process(delta: float) -> void:
	_t += delta
	if _leaving:
		queue_redraw()   # keep the view coherent during the helm-fade, but freeze
		return           # hazards/O2 so a burn can't kill the run mid-transition
	_update_adrift()
	_update_rescue()
	_update_flare(delta)
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


func _load_streak_sprite() -> void:
	## The animated shooting-star sprite (same look as cruise), mipmapped so a fast
	## small sprite doesn't shimmer.
	_streak_frames.clear()
	for i in STAR_FRAMES:
		var abs_path := ProjectSettings.globalize_path(STAR_SPRITE_DIR + "%s_%d.png" % [STAR_ID, i])
		if not FileAccess.file_exists(abs_path):
			continue
		var img := Image.load_from_file(abs_path)
		if img != null:
			img.generate_mipmaps()
			_streak_frames.append(ImageTexture.create_from_image(img))


func _update_streaks(delta: float) -> void:
	## Shooting stars — a flick of light every so often keeps the sky alive.
	_streak_timer -= delta
	if _streak_timer <= 0.0 and player != null:
		_streak_timer = randf_range(2.5, 7.0)
		var a := randf() * TAU
		var start: Vector2 = player.global_position + Vector2.from_angle(a) * 780.0
		_streaks.append({
			"pos": start,
			"vel": (player.global_position - start).normalized() \
				.rotated(randf_range(-0.8, 0.8)) * randf_range(900.0, 1400.0),
			"life": randf_range(0.6, 1.0),
			"aframe": randf() * STAR_FRAMES,
		})
	var keep: Array = []
	for s in _streaks:
		s["pos"] += (s["vel"] as Vector2) * delta
		s["life"] = float(s["life"]) - delta
		s["aframe"] = float(s["aframe"]) + delta * STAR_ANIM_FPS
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
				GameState.say("⚠ HELIOS PURGE SWEEP INBOUND — get behind rock or dock!")
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
				GameState.say("Sweep passed. It didn't find you. Radiation nominal.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and player != null and player.in_dock \
				and not _leaving:
			# Step inside the ship. Bank whatever we're carrying first.
			# (guarded by _leaving so E can't race a helm-fade already in progress)
			GameState.bank_cargo()
			Transition.to_scene("res://scenes/ship_interior.tscn")
		elif event.physical_keycode == KEY_F and player != null \
				and not GameState.adrift and not _leaving:
			# take the helm straight from the walk — smooth fade to the outer view
			_drive_ship()


var _leaving := false
var _fade: ColorRect


func _drive_ship() -> void:
	_leaving = true
	# freeze the suit for the fade — no drifting, firing or O2 drain mid-swap
	for pl in get_tree().get_nodes_in_group("player"):
		pl.set_process(false)
		pl.set_physics_process(false)
	GameState.bank_cargo()
	GameState.pending_shift = true
	GameState.say("Reeling in the line — taking the helm.")
	# Clear the field FIRST so you never watch the elements pop out during the
	# fade — hide every rock/pickup instantly (1 frame) before the black rolls in.
	for a in get_tree().get_nodes_in_group("asteroids"):
		a.visible = false
	for p in get_tree().get_nodes_in_group("pickups"):
		p.visible = false
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 120
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	tw.tween_callback(func(): Transition.to_scene("res://scenes/flight.tscn"))


func _draw_bg_nebulae() -> void:
	## Faint distant colour hangs in the black, biased toward whichever
	## clouds are nearest our parked sector — so the dive never feels empty.
	var cam := player.global_position if player != null else Vector2.ZERO
	var order: Array = []
	for i in GameState.NEBULAE.size():
		order.append([GameState.nebula_center(i).distance_to(GameState.sector), i])
	order.sort_custom(func(a, b): return a[0] < b[0])
	for n in mini(4, order.size()):
		var i: int = order[n][1]
		var col: Color = GameState.NEBULAE[i]["color"]
		var dir := GameState.nebula_center(i) - GameState.sector
		dir = dir.normalized() if dir.length() > 1.0 else Vector2.from_angle(float(i))
		var drift := Vector2(sin(_t * 0.05 + float(i)) * 30.0, cos(_t * 0.04 + float(i)) * 26.0)
		var pos := cam + dir * (260.0 + n * 95.0) + drift
		# fractal fog, not flat circles — faint, slowly turning
		var tex := NebulaFog.texture_for(i)
		var half := Vector2(NebulaFog.SIZE, NebulaFog.SIZE) * 0.5
		var sc := (1050.0 - n * 90.0) / float(NebulaFog.SIZE)
		draw_set_transform(pos, float(i) * 0.7 + _t * 0.008, Vector2(sc, sc))
		draw_texture(tex, -half, Color(col.r, col.g, col.b, 0.13))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _make_stars() -> void:
	## Four parallax depth layers, properly dense — the pattern square is
	## 5200px wide and the view sees ~4% of it, so counts must be big.
	## Off-screen stars are culled at draw time. [pos, size, alpha, depth]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for layer in [[0.12, 1000, 0.3, 0.7, 0.32], [0.25, 1350, 0.4, 1.0, 0.42],
			[0.55, 850, 0.8, 1.7, 0.68], [1.0, 520, 1.2, 2.6, 1.0]]:
		for i in int(layer[1]):
			_stars.append([
				Vector2(rng.randf_range(-2600, 2600), rng.randf_range(-2600, 2600)),
				rng.randf_range(layer[2], layer[3]),
				rng.randf_range(0.25, 0.9) * float(layer[4]),
				layer[0],
			])


func _spawn_asteroids() -> void:
	# the dive field takes on the character of the region you parked in;
	# GameState.dive_field is the SHARED generator, so this field is exactly
	# what the flight-mode preview showed (same rocks, same veins, same
	# mined-out gaps). Revisiting shows the same field.
	var region: Dictionary = GameState.region_at(GameState.sector)
	var base_tint := Color(0.42, 0.4, 0.38)
	if region["tint"] != null:
		base_tint = base_tint.lerp(region["tint"], 0.35)
	for rock in GameState.dive_field(GameState.sector):
		if rock["mined"]:
			continue   # already mined out — don't respawn it
		var a := ASTEROID_SCENE.instantiate()
		a.setup(rock["r"], rock["rich"], base_tint)
		a.position = rock["pos"]
		a.mine_key = rock["key"]
		add_child(a)


func _draw() -> void:
	_draw_bg_nebulae()
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
	# shooting stars — animated sprite, pointed along its velocity, drawn small
	if not _streak_frames.is_empty():
		for st in _streaks:
			var tex: Texture2D = _streak_frames[int(st["aframe"]) % _streak_frames.size()]
			var ts := tex.get_size()
			var sc: float = STAR_DRAW_MAX / maxf(ts.x, maxf(ts.y, 1.0))
			draw_set_transform(st["pos"], (st["vel"] as Vector2).angle(), Vector2(sc, sc))
			draw_texture(tex, -ts * 0.5, Color(1, 1, 1))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# tether reach — discreet concentric rings, both centred on the ship (the
	# centre of the zone). Faint; just enough to read the safe range.
	if not GameState.adrift and player != null:
		var anc: Vector2 = player.tether_anchor
		var reach: float = GameState.tether_length
		draw_arc(anc, reach, 0.0, TAU, 96, Color(1.0, 0.85, 0.3, 0.08), 1.5)
		draw_arc(anc, reach * 0.66, 0.0, TAU, 72, Color(1.0, 0.85, 0.3, 0.045), 1.0)

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
