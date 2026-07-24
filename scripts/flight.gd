extends Node2D
## Piloting mode — take the helm and fly the ship through infinite space.
## Space is generated in deterministic chunks (same coordinates always hold
## the same stars and asteroid fields), and fields get richer with distance
## from the origin. Park near a field (E) to move your dive site there, then
## spacewalk it. Q hands back the helm and returns inside.
## Ships and debris are real sprite art; the space backdrop (stars, nebulae,
## fields, HUD) is still placeholder _draw() shapes.

const HintBar := preload("res://scripts/hint_bar.gd")
const Keymap := preload("res://scripts/keymap.gd")
const KeyPrompt := preload("res://scripts/key_prompt.gd")
const THRUST := 560.0
const THRUST_REV := 260.0
const TURN_RATE := 2.6          # rad/s — A/D yaw
const MAX_SPEED := 1152.0        # crossing the ~2.2× vaster universe stays epic, not a slog
const DAMP := 0.45
const STAR_CHUNK := 640.0
const FIELD_CHUNK := 3600.0      # big chunks = scavenge zones sit far apart, open space between
const PARK_REACH := 80.0         # extra reach beyond a field's (now ~half-size) radius
const INVENTORY_SCREEN := preload("res://scripts/inventory_screen.gd")
const FLOAT_TEXT := preload("res://scripts/float_text.gd")
const RADAR_PANEL := preload("res://scripts/radar_panel.gd")
const QUEST_LOG := preload("res://scripts/quest_log.gd")
const STARCHART := preload("res://scripts/starchart.gd")

# Derelict debris — old wrecks and lost cargo. Human-made, so its metal
# mix is scrap composition, not solar: mostly Al/Fe hulls, Ti struts,
# Ni/Cu wiring, the rare silver contact or gold connector.
const SCRAP_METALS := [
	["Al", 30], ["Fe", 30], ["Ti", 15], ["Ni", 10],
	["Cu", 10], ["Ag", 4], ["Au", 1],
]
const TRASH_COLLECT_RADIUS := 115.0
const TRASH_SPRITE_DIR := "res://assets/sprites/trash/"
# Debris is SPACE TRASH — tiny next to the ~156px ship hull. Every crop is
# normalised so its longest side draws at this many px, whatever its source
# resolution, so a huge crop and a small one both read small.
const TRASH_DRAW_MAX := 52.0
# how long a picked-up piece takes to shrink+fade as it's sucked into the ship
const TRASH_ABSORB_TIME := 0.45

# Animated comet / shooting-star sprites (PixelLab). Small, fast, drawn BELOW the
# foreground. Comets amble; shooting stars flash by.
const COMET_SPRITE_DIR := "res://assets/sprites/comets/"
const COMET_FRAMES := 7
const COMET_TYPES := ["rcomet_a", "rcomet_b", "comet_big"]   # the 3 comet looks
const STAR_TYPES := ["comet_star"]                           # the shooting star
const COMET_DRAW_MAX := 86.0   # longest side px — a bit bigger, still under the ~156px ship
const STAR_DRAW_MAX := 70.0
const COMET_ANIM_FPS := 11.0

# Derelict WRECKS — whole dead ships (salvage-sheet art), much rarer than
# loose junk. Stripping one pays a real scrap haul and can recover a lost
# fabricator recipe; medical ships and dead stations carry the fancy ones.
const Craftables := preload("res://scripts/craftables.gd")
const RECIPE_BANNER := preload("res://scripts/recipe_banner.gd")
const DIALOG_SCENE := preload("res://scripts/dialog_scene.gd")
const WRECK_COLLECT_RADIUS := 120.0
const WRECK_CHANCE := 0.07
const WRECK_SCALE := 0.42
# Tech salvage — dead ships carry what ships are MADE of, not what rock is:
# lithium battery banks, neodymium motor magnets, tungsten tooling, food and
# fertilizer stores (P), signage neon and welding argon. This is the primary
# source for the recipe elements that mining can't realistically supply.
const WRECK_TECH := [
	["Li", 25], ["Nd", 20], ["W", 20], ["P", 15], ["Ne", 12], ["Ar", 8],
]

@onready var cam: Camera2D = $Camera

var ship_pos := Vector2.ZERO
var vel := Vector2.ZERO
var heading := 0.0
var _thr := 0.0     # -1..1  W forward / S reverse
var _turn := 0.0    # -1..1  A / D

var _field_cache := {}
var _trash_cache := {}
var _wreck_cache := {}
# pieces mid-suck-in: each {pos0, sprite_roll, spin, t} — pure visual, the salvage
# is already granted the instant it's collected. Drawn shrinking/fading into the ship.
var _absorbing: Array = []
# Real debris sprites (the croppers drop trash_*.png in TRASH_SPRITE_DIR).
# Loaded dynamically in _ready() so ANY count works — no hardcoded filenames.
# Left empty when the PNGs aren't imported yet; _draw_trash then falls back to
# the placeholder polygons so the game never breaks.
var _trash_tex: Array[Texture2D] = []
var _recipe_banner: Control
var _dialog: Control        # first-meeting conversation overlay
var _in_dialog := false     # helm frozen while the meeting plays
var _comets: Array = []          # {id, star, pos, vel, life, scale, aframe}
var _comet_timer := 6.0
var _comet_frames := {}          # id -> Array[Texture2D] (7 animation frames)
var _near_beacon := false        # in reach of the current distress beacon
var _near_field: Dictionary = {}
var _scooping := false
var _t := 0.0
var _font: Font = ThemeDB.fallback_font

var _pos_label: Label
var _cargo_label: Label
var _prompt_label: Control
var _msg_label: Label
var _msg_tween: Tween


var _flight_origin := Vector2.ZERO


const FLIGHT_ZOOM := 0.68   # <1 = pulled back; see much more space while flying

# --- GPU-batched background (stars / deep-space / nebulae) ----------------
# The starfield, deep-space specks and nebula fog USED to be drawn in
# immediate-mode _draw() every frame — thousands of draw_circle/draw_texture
# calls, the fast-travel bottleneck. They are now GPU-batched:
#   * each parallax STAR layer  -> one MultiMeshInstance2D (one draw call each)
#   * the DEEP-SPACE specks     -> one MultiMeshInstance2D
#   * each NEBULA's fog + glow  -> Sprite2D nodes placed in the world
# Generation stays byte-identical (same seeded _star_chunk/_deep_chunk), so the
# sky is unchanged; only the *rendering* moved off the CPU. Instances live in
# a rolling chunk window that only refills when the view leaves it (rare), and
# per-frame parallax is a single node.position set per layer.
const STAR_PAD := 1          # extra chunks buffered around the view (fewer refills)
const DEEP_PAD := 1
var _dot_tex: ImageTexture   # soft round dot painted on the MultiMesh quads
var _star_mm: Array = []     # MultiMeshInstance2D, one per STAR_LAYERS entry
var _star_built: Array = []  # [cx0,cy0,cx1,cy1] chunk window each layer holds
var _deep_mm: MultiMeshInstance2D
var _deep_built: Array = [1, 1, 0, 0]   # min>max => "empty", forces first fill
var _neb_nodes := {}         # i -> {fogA, fogB} sprites (built lazily, on first sight)
var _neb_stars_node: DrawProxy   # packed cloud stars (few) kept immediate-mode
var _glints: DrawProxy       # near-layer glint crosses (no per-instance lines in a MM)


## A tiny Node2D that forwards its _draw() to a Callable — lets a couple of
## small immediate-mode overlays (near-star glint crosses, nebula cloud stars)
## sit on their own z-layer, behind the foreground but in front of the batched
## sky, without a separate script file.
class DrawProxy extends Node2D:
	var fn: Callable
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


func _ready() -> void:
	# painted hull/debris, not pixel art — mipmaps keep small-scaled debris and
	# derelicts from shimmering as the camera drifts
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_build_background()
	_load_trash_sprites()
	_load_comet_sprites()
	_build_stations()   # real GPU-lit station nodes (Sprite2D + PointLight2D)
	ship_pos = GameState.sector
	_flight_origin = ship_pos
	cam.position = ship_pos
	Sfx.ambient("amb_space")        # the void hum under cruising
	Sfx.play("engine_start", -6.0)  # spinning up as you take the helm
	cam.zoom = Vector2(FLIGHT_ZOOM, FLIGHT_ZOOM)
	cam.reset_smoothing()
	_build_hud()
	GameState.notify.connect(_on_notify)
	GameState.say("You have the helm. Fields get richer the farther you fly.")
	# debug: SW_FIELD=1 jumps the ship to the nearest asteroid zone (screenshots)
	if OS.get_environment("SW_FIELD") != "":
		for ring in range(1, 12):
			var found := false
			for dy in range(-ring, ring + 1):
				for dx in range(-ring, ring + 1):
					var fdb := _field_in_chunk(dx, dy)
					if not fdb.is_empty():
						ship_pos = fdb["center"]
						cam.position = ship_pos
						cam.reset_smoothing()
						found = true
						break
				if found: break
			if found: break
	# debug: SW_NEBULA=<i> parks the ship at the edge of nebula i so the cloud
	# fills the view (there's no in-game shortcut to a nebula — screenshots only)
	if OS.get_environment("SW_NEBULA") != "":
		var ni := int(OS.get_environment("SW_NEBULA"))
		ni = clampi(ni, 0, GameState.NEBULAE.size() - 1)
		ship_pos = GameState.nebula_center(ni) + Vector2(GameState.nebula_radius(ni) * 0.9, 0.0)
		cam.position = ship_pos
		cam.reset_smoothing()
	# debug: SW_DIALOG=JUNO opens that crew member's first-meeting dialog
	if OS.get_environment("SW_DIALOG") != "":
		_in_dialog = true
		_dialog.start(OS.get_environment("SW_DIALOG"))
	# debug: SW_WRECK=1 parks a rare derelict beside the ship and pops the
	# recipe banner, for screenshots
	if OS.get_environment("SW_WRECK") != "":
		var cc := Vector2i((ship_pos / FIELD_CHUNK).floor())
		_wreck_cache[cc] = {
			"pos": ship_pos + Vector2(420, -160), "idx": mini(13, Craftables.WRECKS.size() - 1), "rot": 0.3,
			"rare": true, "key": "w:debug", "taken": false,
		}
		_recipe_banner.show_recipe("jukebox")
	# debug: SW_STATIONS=1 parks the ship at the station inspection cluster
	if OS.get_environment("SW_STATIONS") != "":
		ship_pos = Stations.CLUSTER
		cam.position = ship_pos
		_flight_origin = ship_pos
		cam.reset_smoothing()
	# if the save drops us inside a station's reach, that station stays quiet
	# until we fly clear once — everything else can breach immediately
	_breach_ignore = _near_station_idx()
	# populate the batched sky for ship_pos's FINAL location (post SW_FIELD /
	# SW_NEBULA teleports) so there's no one-frame empty flash on entry
	_update_background()
	if OS.get_environment("SW_SHOT") != "":
		await get_tree().create_timer(0.9).timeout
		if is_inside_tree():
			get_viewport().get_texture().get_image().save_png(OS.get_environment("SW_SHOT"))
			get_tree().quit()


func _process(delta: float) -> void:
	if _in_dialog:
		_t += delta
		_update_background()   # nebula fog keeps drifting behind the dialog dim
		queue_redraw()   # the wreck keeps drifting behind the dialog dim
		return
	# A frame hitch (heavy per-frame draw / chunk-gen at high speed) spikes delta;
	# uncapped, the damp lerp below then zeroes velocity in one frame (the felt
	# "kick-back") and ship_pos jumps. Cap delta so movement stays smooth through
	# stutters — physics feel is unchanged at normal frame rates.
	delta = minf(delta, 0.05)
	# helm controls: A/D yaw the ship, W burns the main drive, S retro-burns
	_turn = Input.get_axis("move_left", "move_right")
	_thr = Input.get_axis("move_down", "move_up")
	if OS.get_environment("SW_THRUST") != "":
		_thr = 1.0   # debug: force the main burn for screenshots
	if OS.get_environment("SW_TURN") != "":
		_turn = 1.0  # debug: force a turn burn for screenshots
		heading = 0.0   # freeze bow-right so the jet is readable
	if OS.get_environment("SW_REV") != "":
		_thr = -1.0  # debug: force a reverse burn for screenshots
	heading += _turn * TURN_RATE * delta
	if absf(_thr) > 0.01:
		var power := THRUST if _thr > 0.0 else THRUST_REV
		vel += Vector2.from_angle(heading) * _thr * power * delta
	# VEGA the Navigator trims the drive — she knows every gravity well
	var vmax := MAX_SPEED * (1.25 if GameState.rescued.has("VEGA") else 1.0)
	vel = vel.limit_length(vmax)
	vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-DAMP * delta))
	ship_pos += vel * delta
	GameState.note_ship_at(ship_pos)   # reveal nearby nebulae on the star chart
	# keep the saved position live (so a mid-flight save/quit doesn't rewind you)
	# — BUT NOT once a scene-leave has begun: parking sets sector to the FIELD
	# centre, and clobbering it back to ship_pos mid-fade drops you into a
	# different asteroid field than the one you parked on.
	if not Transition.is_busy():
		GameState.sector = ship_pos
	cam.position = ship_pos

	_near_field = _find_near_field()
	GameState.at_field = not _near_field.is_empty()   # the interior airlock reads this
	_near_beacon = GameState.rescue_available() \
		and ship_pos.distance_to(GameState.rescue_beacon()) < 300.0
	_check_station_breach()   # TESTING: any station opens THE BREACH on approach
	if not GameState.pending_shift \
			and ship_pos.distance_to(_flight_origin) > 600.0:
		GameState.pending_shift = true   # you actually flew somewhere

	_t += delta
	# nebula flying scoops gas into the tanks — the only source of H/He & co
	_scooping = bool(GameState.region_at(ship_pos)["nebula"])
	if _scooping:
		GameState.scoop_gas(delta)

	_collect_trash()
	_tick_absorbing(delta)
	_collect_wrecks()
	_update_comets(delta)
	_update_stations(delta)   # float + rotation + breathing lights
	_update_hud()
	_update_background()
	# cut the thrust loop the instant a dialog takes over, so it can't drone on
	# under a rescue conversation that opened mid-burn
	Sfx.thrust_on((absf(_thr) > 0.05 or absf(_turn) > 0.05) and not _in_dialog)
	queue_redraw()


func _on_rescue_dialog_done() -> void:
	## The screen is solid black under the dialog's fade — bring them aboard
	## and cut to the ship interior, where they now live at their spot.
	var r: Dictionary = GameState.do_rescue()
	GameState.sector = ship_pos
	GameState.say("%s is aboard — %s." % [r.get("name", ""), r.get("perk", "")])
	Transition.to_scene("res://scenes/ship_interior.tscn")


func _exit_tree() -> void:
	Sfx.stop_loops()


func _update_comets(delta: float) -> void:
	## Animated sprite comets that cross the view fast, drawn BELOW the foreground.
	## Two flavours: rock/ice comets (slower, bigger tail) and shooting stars (a
	## quick flash). Each cycles its 7-frame loop and points along its velocity.
	_comet_timer -= delta
	if _comet_timer <= 0.0:
		var shooting := randf() < 0.45
		_comet_timer = randf_range(2.5, 5.5) if shooting else randf_range(6.0, 12.0)
		var pool: Array = STAR_TYPES if shooting else COMET_TYPES
		var id: String = pool[randi() % pool.size()]
		# spawn off-screen and streak across past the ship
		var a := randf() * TAU
		var start: Vector2 = ship_pos + Vector2.from_angle(a) * 1050.0
		var across := (ship_pos - start).normalized().rotated(randf_range(-0.6, 0.6))
		var spd := randf_range(1300.0, 1900.0) if shooting else randf_range(520.0, 820.0)
		_comets.append({
			"id": id, "star": shooting,
			"pos": start, "vel": across * spd,
			"life": randf_range(1.2, 2.0) if shooting else randf_range(3.5, 6.0),
			"scale": randf_range(0.82, 1.15),
			"aframe": randf() * COMET_FRAMES,   # random starting frame
		})
	var keep: Array = []
	for c in _comets:
		c["pos"] += (c["vel"] as Vector2) * delta
		c["life"] = float(c["life"]) - delta
		c["aframe"] = float(c["aframe"]) + delta * COMET_ANIM_FPS
		if float(c["life"]) > 0.0 and (c["pos"] as Vector2).distance_to(ship_pos) < 2600.0:
			keep.append(c)
	_comets = keep


func _unhandled_input(event: InputEvent) -> void:
	if _in_dialog:
		return   # the dialog overlay owns all input
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_E:
			if _near_beacon:
				# board the broken ship — meet them face to face
				_in_dialog = true
				vel = Vector2.ZERO
				Sfx.play("radio", -4.0)
				_dialog.start(str(GameState.rescue_target()["name"]))
			elif not _near_field.is_empty():
				GameState.sector = _near_field["center"]
				GameState.save_game()
				Sfx.play("clack", -8.0)
				GameState.say("Parked at the field. Suit up and mine.")
				Transition.to_scene("res://scenes/main.tscn")
			# (no open-space E branch — E only acts at a field/beacon. What it should
			#  do in open space is a captain decision — awaiting the answer.)
		KEY_Q:
			# step inside while cruising — fade to the interior and appear at the
			# pilot screen (bridge cockpit). Holds position so you can fly back
			# out or spacewalk from this spot.
			GameState.sector = ship_pos
			GameState.enter_at_cockpit = true
			Transition.to_scene("res://scenes/ship_interior.tscn")


# ==================================================================
# Deterministic chunked space
# ==================================================================
func _chunk_seed(cx: int, cy: int, salt: int) -> int:
	return (cx * 73856093) ^ (cy * 19349663) ^ (salt * 83492791)


func _field_in_chunk(cx: int, cy: int) -> Dictionary:
	var key := Vector2i(cx, cy)
	if _field_cache.has(key):
		return _field_cache[key]
	if _field_cache.size() > 2048:
		_field_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(cx, cy, 1)
	var field := {}
	var origin := Vector2(cx, cy) * FIELD_CHUNK
	# the region plan decides how likely, big and rich fields are here
	var region := GameState.region_at(origin + Vector2.ONE * FIELD_CHUNK * 0.5)
	if rng.randf() < float(region["chance"]):
		var center := origin + Vector2(
			rng.randf_range(FIELD_CHUNK * 0.2, FIELD_CHUNK * 0.8),
			rng.randf_range(FIELD_CHUNK * 0.2, FIELD_CHUNK * 0.8))
		# THE ACTUAL dive field — same rocks, SAME POSITIONS you'll mine when you
		# park (shared generator, one seed per zone). No compression: a rock's
		# offset out here is exactly where it sits inside. Mined-state is checked
		# LIVE at draw time (below), so mining a rock removes it from here too.
		var real: Array = GameState.dive_field(center)
		var maxd := 1.0
		for rk in real:
			maxd = maxf(maxd, (rk["pos"] as Vector2).length() + float(rk["r"]))
		var rocks: Array = []
		for rk in real:
			rocks.append({
				"off": rk["pos"],
				"r": rk["r"],
				"rich": rk["rich"],
				"key": rk["key"],
				"sym": rk["sym"],   # element → RockFamily colour-family rock (see _draw_fields)
				"var": int(hash(rk["key"]) % 16),
			})
		field = {"center": center, "radius": maxd,
			"rich": GameState.richness_at(center),
			"rocks": rocks, "tint": region["tint"]}
	_field_cache[key] = field
	return field


func _load_trash_sprites() -> void:
	## Scan the trash sprite folder and load every PNG into _trash_tex. Dynamic
	## on purpose — the croppers decide how many sprites exist, and this picks up
	## whatever landed. Result is sorted by path so the per-piece sprite roll maps
	## to a STABLE index across runs. Empty result => placeholder fallback.
	_trash_tex.clear()
	if not DirAccess.dir_exists_absolute(TRASH_SPRITE_DIR):
		return
	var seen := {}
	for f in DirAccess.get_files_at(TRASH_SPRITE_DIR):
		# in the editor the listing includes .import sidecars — map them back to
		# their source PNG, and dedupe so each sprite is loaded exactly once
		var fname := f.trim_suffix(".import")
		if not fname.to_lower().ends_with(".png") or seen.has(fname):
			continue
		seen[fname] = true
		var path := TRASH_SPRITE_DIR + fname
		if ResourceLoader.exists(path):
			var tex := ResourceLoader.load(path) as Texture2D
			if tex != null:
				_trash_tex.append(tex)
	_trash_tex.sort_custom(func(a, b): return a.resource_path < b.resource_path)


func _load_comet_sprites() -> void:
	## Load the 7-frame animation for each comet / shooting-star type. Raw-loaded
	## with mipmaps so a small, fast-moving sprite doesn't shimmer.
	_comet_frames.clear()
	for id in COMET_TYPES + STAR_TYPES:
		var frames: Array[Texture2D] = []
		for i in COMET_FRAMES:
			var abs_path := ProjectSettings.globalize_path(
				COMET_SPRITE_DIR + "%s_%d.png" % [id, i])
			if not FileAccess.file_exists(abs_path):
				continue
			var img := Image.load_from_file(abs_path)
			if img != null:
				img.generate_mipmaps()
				frames.append(ImageTexture.create_from_image(img))
		if not frames.is_empty():
			_comet_frames[id] = frames


func _trash_in_chunk(cx: int, cy: int) -> Array:
	var key := Vector2i(cx, cy)
	if _trash_cache.has(key):
		return _trash_cache[key]
	if _trash_cache.size() > 2048:
		_trash_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(cx, cy, 3)
	var pieces: Array = []
	# sparse scrap everywhere
	if rng.randf() < 0.3:
		var origin := Vector2(cx, cy) * FIELD_CHUNK
		for i in rng.randi_range(1, 3):
			# weighted scrap-metal roll
			var total := 0
			for m in SCRAP_METALS:
				total += m[1]
			var roll := rng.randi_range(1, total)
			var metal := "Fe"
			for m in SCRAP_METALS:
				roll -= m[1]
				if roll <= 0:
					metal = m[0]
					break
			# rare: a synthetic element left in the wreck's old reactor core —
			# the "find them all" hunt (collection only, never used in crafting)
			if rng.randf() < 0.06:
				var syn: Array = Elements.synthetic_symbols()
				metal = syn[rng.randi_range(0, syn.size() - 1)]
			pieces.append({
				"pos": origin + Vector2(rng.randf_range(60, FIELD_CHUNK - 60),
					rng.randf_range(60, FIELD_CHUNK - 60)),
				"kind": rng.randi_range(0, 3),   # placeholder shape (fallback only)
				# which real sprite to draw — a stable [0,1) roll hashed from the
				# piece key, NOT off the shared rng, so it survives the chunk cache
				# and load timing without shifting the metal/units rolls above.
				# Mapped to a texture index at draw time.
				"sprite_roll": float(hash("%d:%d:%d:spr" % [cx, cy, i]) % 100000) / 100000.0,
				"metal": metal,
				"units": rng.randi_range(1, 3),
				"spin": rng.randf_range(-0.6, 0.6),
				# looted-state lives in GameState (and the save), so wrecks
				# stay stripped even after the chunk cache is dropped
				"key": "%d:%d:%d" % [cx, cy, i],
				"taken": GameState.salvage_taken.has("%d:%d:%d" % [cx, cy, i]),
			})
	_trash_cache[key] = pieces
	return pieces


func _wreck_in_chunk(cx: int, cy: int) -> Dictionary:
	## At most one derelict per chunk, deterministic, much rarer than junk.
	## The hull index decides the art AND the loot class (RARE_WRECKS =
	## medical ships / dead stations = bigger haul, fancier recipe).
	var key := Vector2i(cx, cy)
	if _wreck_cache.has(key):
		return _wreck_cache[key]
	if _wreck_cache.size() > 2048:
		_wreck_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(cx, cy, 7)
	var wreck := {}
	if not (cx == 0 and cy == 0) and rng.randf() < WRECK_CHANCE:
		var idx: int
		if rng.randf() < 0.2:   # rare hulls stay rare
			idx = Craftables.RARE_WRECKS[rng.randi_range(0, Craftables.RARE_WRECKS.size() - 1)]
		else:
			idx = rng.randi_range(0, Craftables.WRECKS.size() - 1)
			while idx in Craftables.RARE_WRECKS:
				idx = rng.randi_range(0, Craftables.WRECKS.size() - 1)
		var wkey := "w:%d:%d" % [cx, cy]
		wreck = {
			"pos": Vector2(cx, cy) * FIELD_CHUNK + Vector2(
				rng.randf_range(160, FIELD_CHUNK - 160),
				rng.randf_range(160, FIELD_CHUNK - 160)),
			"idx": idx,
			"rot": rng.randf_range(-0.5, 0.5),
			"rare": idx in Craftables.RARE_WRECKS,
			"key": wkey,
			"taken": GameState.salvage_taken.has(wkey),
		}
	_wreck_cache[key] = wreck
	return wreck


func _collect_wrecks() -> void:
	var cc := Vector2i((ship_pos / FIELD_CHUNK).floor())
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var w := _wreck_in_chunk(cc.x + dx, cc.y + dy)
			if w.is_empty() or w["taken"]:
				continue
			if ship_pos.distance_to(w["pos"]) > WRECK_COLLECT_RADIUS:
				continue
			w["taken"] = true
			GameState.salvage_taken[w["key"]] = true
			# the scrap haul — several metals, doubled for rare hulls.
			# NOT every hull still holds a readable blueprint (deterministic
			# per wreck, so reloading can't reroll it); recipe-less hulls
			# pay out extra materials instead — their cargo hold is intact.
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(str(w["key"], ":loot"))
			var gives_recipe: bool = w["rare"] or rng.randf() < 0.55
			var kinds := (3 if w["rare"] else 2) + (0 if gives_recipe else 2)
			var y := -20.0
			for i in kinds:
				var total := 0
				for m in SCRAP_METALS:
					total += m[1]
				var roll := rng.randi_range(1, total)
				var metal := "Fe"
				for m in SCRAP_METALS:
					roll -= m[1]
					if roll <= 0:
						metal = m[0]
						break
				var units := rng.randi_range(2, 5) * (2 if w["rare"] else 1)
				GameState.elements[metal] = mini(
					int(GameState.elements.get(metal, 0)) + units, GameState.ELEMENT_CAP)
				GameState.discovered[metal] = true
				var ft := FLOAT_TEXT.new()
				ft.text = "+%d %s  (wreck)" % [units, Elements.name_of(metal)]
				ft.color = Elements.hue_of(metal)
				ft.position = w["pos"] + Vector2(0, y)
				add_child(ft)
				y -= 18.0
			# every hull also gives up one TECH find — battery lithium, magnet
			# neodymium, tungsten tooling... the recipe chemistry's lifeline
			var ttotal := 0
			for t in WRECK_TECH:
				ttotal += t[1]
			var troll := rng.randi_range(1, ttotal)
			var tech := "Li"
			for t in WRECK_TECH:
				troll -= t[1]
				if troll <= 0:
					tech = t[0]
					break
			var tunits := rng.randi_range(1, 2) * (2 if w["rare"] else 1) \
				+ (0 if gives_recipe else 1)   # intact cargo = extra tech find
			GameState.elements[tech] = mini(
				int(GameState.elements.get(tech, 0)) + tunits, GameState.ELEMENT_CAP)
			GameState.discovered[tech] = true
			var tft := FLOAT_TEXT.new()
			tft.text = "+%d %s  (tech salvage)" % [tunits, Elements.name_of(tech)]
			tft.color = Elements.hue_of(tech)
			tft.position = w["pos"] + Vector2(0, y)
			add_child(tft)
			GameState.inventory_changed.emit()
			# the real prize — IF this hull still holds a readable blueprint
			if gives_recipe:
				var rid := GameState.unlock_random_recipe(bool(w["rare"]))
				if rid != "":
					_recipe_banner.show_recipe(rid)
				else:
					var ft2 := FLOAT_TEXT.new()
					ft2.text = "hull stripped — no new recipes left aboard"
					ft2.color = Color(0.7, 0.8, 0.9)
					ft2.position = w["pos"] + Vector2(0, y + 18.0)   # clear the salvage line above
					add_child(ft2)
			else:
				var ft3 := FLOAT_TEXT.new()
				ft3.text = "data banks fried — but the cargo hold was intact"
				ft3.color = Color(0.7, 0.8, 0.9)
				ft3.position = w["pos"] + Vector2(0, y - 18.0)
				add_child(ft3)
			GameState.save_game()


func _collect_trash() -> void:
	var cc := Vector2i((ship_pos / FIELD_CHUNK).floor())
	var got_any := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for piece in _trash_in_chunk(cc.x + dx, cc.y + dy):
				if piece["taken"]:
					continue
				if ship_pos.distance_to(piece["pos"]) < TRASH_COLLECT_RADIUS:
					piece["taken"] = true
					GameState.salvage_taken[piece["key"]] = true
					# hand the visual off to the suck-in animation (grant is immediate)
					_absorbing.append({
						"pos0": piece["pos"], "sprite_roll": piece["sprite_roll"],
						"spin": piece["spin"], "t": 0.0,
					})
					var sym: String = piece["metal"]
					GameState.elements[sym] = mini(
						int(GameState.elements.get(sym, 0)) + piece["units"],
						GameState.ELEMENT_CAP)
					GameState.discovered[sym] = true
					GameState.inventory_changed.emit()
					got_any = true
					var ft := FLOAT_TEXT.new()
					ft.text = "+%d %s  (salvage)" % [piece["units"], Elements.name_of(sym)]
					ft.color = Elements.hue_of(sym)
					ft.position = piece["pos"] + Vector2(0, -20)
					add_child(ft)
	if got_any:
		GameState.save_game()   # commit like wrecks do — a crash can't lose it


func _tick_absorbing(delta: float) -> void:
	## Advance the suck-in timers and drop finished pieces. Drawing happens in
	## _draw_trash (which reads .t); here we only age them.
	if _absorbing.is_empty():
		return
	var i := _absorbing.size() - 1
	while i >= 0:
		_absorbing[i]["t"] += delta
		if _absorbing[i]["t"] >= TRASH_ABSORB_TIME:
			_absorbing.remove_at(i)
		i -= 1
	queue_redraw()


func _find_near_field() -> Dictionary:
	var cc := Vector2i((ship_pos / FIELD_CHUNK).floor())
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var f := _field_in_chunk(cc.x + dx, cc.y + dy)
			if f.is_empty():
				continue
			if ship_pos.distance_to(f["center"]) < f["radius"] + PARK_REACH:
				return f
	return {}


# ==================================================================
# THE BREACH — station approach trigger (testing wiring: every station
# runs the same breach; scattering/gating them is a later step)
# ==================================================================
# arms only in open space, so returning from a breach beside the hull
# doesn't instantly re-trigger it — fly away and back to breach again
var _breach_armed := false
var _breach_ignore := -1   # station the ship spawned inside reach of — quiet until you fly clear


func _near_station_idx() -> int:
	var reach: float = Stations.display_px() * 0.75
	for i in Stations.count():
		if ship_pos.distance_to(Stations.world_pos(i)) < reach:
			return i
	return -1


func _check_station_breach() -> void:
	var near := _near_station_idx()
	if near == -1:
		_breach_armed = true
		_breach_ignore = -1
		return
	if not _breach_armed and near != _breach_ignore:
		# saves can drop the ship barely INSIDE a station's reach (post-breach respawn)
		# — that one station stays quiet until you fly clear, but any OTHER station,
		# or the same one after leaving its radius once, triggers normally.
		_breach_armed = true
	if not _breach_armed or _in_dialog or Transition.is_busy():
		return
	_breach_armed = false
	GameState.sector = ship_pos   # come back to this exact spot after the breach
	var breach_gd := load("res://scripts/breach_map3d.gd")
	breach_gd.station_name = str(Stations.LIST[near]["name"])
	breach_gd.station_id = str(Stations.LIST[near]["id"])
	Sfx.play("radio", -6.0)
	GameState.say("Docking clamps bite — HELIOS firewall detected. Breaching.")
	Transition.to_scene("res://scenes/breach.tscn")


# ==================================================================
# HUD
# ==================================================================
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.make_theme()
	layer.add_child(root)
	root.add_child(INVENTORY_SCREEN.new())

	# helm scanner — same hologram, field/wreck/nebula scale
	var radar := RADAR_PANEL.new()
	radar.mode = "flight"
	radar.flight = self
	root.add_child(radar)
	radar.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	UITheme.shrink(radar, true, false, UITheme.RADAR_SCALE)

	# quest log, tucked under the (larger) radar
	var qlog := QUEST_LOG.new()
	root.add_child(qlog)
	qlog.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	qlog.offset_top += 206.0
	qlog.offset_bottom += 206.0
	UITheme.shrink(qlog, true, false)

	var nav := PanelContainer.new()
	nav.position = Vector2(18, 18)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nav)
	var box := VBoxContainer.new()
	nav.add_child(box)
	_pos_label = Label.new()
	_pos_label.add_theme_font_size_override("font_size", 10)
	box.add_child(_pos_label)
	_cargo_label = Label.new()
	_cargo_label.modulate = Color(1, 1, 1, 0.75)
	_cargo_label.add_theme_font_size_override("font_size", 10)
	box.add_child(_cargo_label)
	# the status bar was the ONE HUD panel never shrunk — bring it in line
	UITheme.shrink(nav, false, false, 0.72)

	_prompt_label = KeyPrompt.new()
	_prompt_label.modulate = Color(0.6, 0.9, 1.0, 0.0)
	root.add_child(_prompt_label)

	_msg_label = Label.new()
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.modulate.a = 0.0
	root.add_child(_msg_label)
	# same toast band as the other HUDs — clear of prompts and gear cards
	_msg_label.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 150)
	# text is set later — grow from the center anchor so it STAYS centered
	_msg_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_msg_label.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var hint := HintBar.new()
	hint.items = Keymap.hint("flight")
	root.add_child(hint)

	# "RECIPE RECOVERED" reveal — the payoff for stripping a derelict
	_recipe_banner = RECIPE_BANNER.new()
	root.add_child(_recipe_banner)

	# STAR CHART overlay (M) — the whole known universe drawn to scale. Added
	# last-but-one so it covers the HUD when open; blocked while a dialog owns input.
	var chart := STARCHART.new()
	chart.flight = self
	chart.z_index = 200   # above the inventory (z=100) and recipe banner
	# don't open the map over a dialog OR the pause menu
	chart.can_open = func() -> bool: return not _in_dialog and not GameMenu.visible
	root.add_child(chart)

	# first-meeting dialog — boarding a survivor's broken ship plays this,
	# then fades to black and brings them aboard
	_dialog = DIALOG_SCENE.new()
	root.add_child(_dialog)
	_dialog.finished.connect(_on_rescue_dialog_done)


func _update_hud() -> void:
	var region_name: String = GameState.region_at(ship_pos)["name"]
	var line := "%s   ·   Sector (%d, %d)" % [
		region_name.to_upper(), int(ship_pos.x / 100.0), int(ship_pos.y / 100.0)]
	if GameState.rescue_available():
		var t: Dictionary = GameState.rescue_target()
		line += "   ·   ✦ %s'S BEACON: %s" % [t["name"], str(t["region"]).to_upper()]
	elif GameState.rescued_count() < GameState.RESCUES.size():
		line += "   ·   ✦ NEXT SIGNAL NEEDS DRIVE PART %d" % (GameState.rescued_count() + 1)
	_pos_label.text = line
	_cargo_label.text = "BANKED ORE   %d" % GameState.banked
	if _near_beacon:
		_prompt_label.set_prompt("E    Board the wreck — %s, %s" % [
			GameState.rescue_target()["name"], GameState.rescue_target()["role"]])
		_prompt_label.modulate.a = 0.95
	elif not _near_field.is_empty():
		_prompt_label.set_prompt("E    Park & spacewalk this field  (~%d%% rich)" % int(
			_near_field["rich"] * 100.0))
		_prompt_label.modulate.a = 0.95
	elif _scooping:
		_prompt_label.set_prompt("Scooping nebula gas — H ×%d, He ×%d" % [
			int(GameState.elements.get("H", 0)),
			int(GameState.elements.get("He", 0))])
		_prompt_label.modulate.a = 0.75
	else:
		_prompt_label.modulate.a = 0.0


func _on_notify(text: String) -> void:
	_msg_label.text = text
	if _msg_tween:
		_msg_tween.kill()
	_msg_label.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(2.2)
	_msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.8)


# ==================================================================
# GPU-batched background — build + per-frame update
# ==================================================================
func _make_dot_tex() -> ImageTexture:
	## A small round dot: solid core with a 1-2px antialiased rim, so the
	## MultiMesh quads read as round points like the old draw_circle discs
	## (a quad of side 2*r scaled around this keeps the bright core ~= r).
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := sz * 0.5
	for y in sz:
		for x in sz:
			var dd := Vector2(x - c + 0.5, y - c + 0.5).length() / c
			var a := 1.0 - smoothstep(0.82, 1.0, dd)   # solid to 0.82, soft rim
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _make_dot_mm(z: int) -> MultiMeshInstance2D:
	var mmi := MultiMeshInstance2D.new()
	mmi.z_index = z            # negative => behind this node's foreground _draw
	mmi.texture = _dot_tex
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = _dot_mesh
	mmi.multimesh = mm
	add_child(mmi)
	return mmi


var _dot_mesh: QuadMesh


func _build_background() -> void:
	## Create the batched-sky nodes once. z-order (back -> front): deep-space
	## specks (-60), nebula fog (-50), nebula glow (-45), cloud stars (-35),
	## the five parallax star layers (-30..-26, deepest first), near-star glint
	## crosses (-25); the foreground _draw() sits at 0, on top of all of it.
	_dot_tex = _make_dot_tex()
	_dot_mesh = QuadMesh.new()
	_dot_mesh.size = Vector2(1, 1)
	_deep_mm = _make_dot_mm(-60)
	for li in STAR_LAYERS.size():
		_star_mm.append(_make_dot_mm(-30 + li))
		_star_built.append([1, 1, 0, 0])   # min>max => empty, forces first fill
	_neb_stars_node = DrawProxy.new()
	_neb_stars_node.fn = _draw_neb_stars
	_neb_stars_node.z_index = -35
	add_child(_neb_stars_node)
	_glints = DrawProxy.new()
	_glints.fn = _draw_near_glints
	_glints.z_index = -25
	add_child(_glints)


func _update_background() -> void:
	## Drives the batched sky each frame: parallax offsets + rare buffer refills
	## for the star/deep MultiMeshes, nebula sprite drift, and a queue_redraw on
	## the two small immediate-mode proxies (glints, cloud stars).
	var center := cam.get_screen_center_position()
	var half := get_viewport_rect().size * 0.5 / cam.zoom.x + Vector2(STAR_CHUNK, STAR_CHUNK)
	_update_deep(center, half)
	for li in STAR_LAYERS.size():
		_update_star_layer(li, center, half)
	_update_nebulae(center, half)
	_neb_stars_node.queue_redraw()
	_glints.queue_redraw()


# ==================================================================
# Placeholder visuals
# ==================================================================
func _draw() -> void:
	# Background (deep-space specks, nebula fog/glow, parallax stars) is now
	# GPU-batched in child nodes (MultiMeshInstance2D / Sprite2D) sitting behind
	# this node's draw via negative z_index — see _update_background(). Only the
	# foreground (fields / wrecks / trash / beacon / comets / ship) is still
	# drawn immediate-mode here (far fewer items than the starfield).
	var center := cam.get_screen_center_position()
	# the visible world is bigger than the viewport by 1/zoom — expand the cull
	# bounds to match, or stars/fields pop in at the edges
	var half := get_viewport_rect().size * 0.5 / cam.zoom.x + Vector2(STAR_CHUNK, STAR_CHUNK)
	_draw_comets()          # BELOW everything — drift past behind the asteroids/ship
	_draw_fields(center, half)
	_draw_wrecks(center, half)
	_draw_trash(center, half)
	_draw_stations(center, half)
	_draw_beacon(center)
	_draw_ship()


func _draw_comets() -> void:
	for c in _comets:
		var frames: Array = _comet_frames.get(c["id"], [])
		if frames.is_empty():
			continue
		var tex: Texture2D = frames[int(c["aframe"]) % frames.size()]
		var ts := tex.get_size()
		var box: float = STAR_DRAW_MAX if c["star"] else COMET_DRAW_MAX
		var s: float = (box / maxf(ts.x, maxf(ts.y, 1.0))) * float(c["scale"])
		# sprites face +x (head right, tail left) — point along the velocity so the
		# head leads and the tail streams behind
		var ang: float = (c["vel"] as Vector2).angle()
		draw_set_transform(c["pos"], ang, Vector2(s, s))
		draw_texture(tex, -ts * 0.5, Color(1, 1, 1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# varied ambient light colours so the fleet reads warm/cool, not one flat teal
const STATION_GLOW := [
	Color(0.30, 0.85, 0.95), Color(0.42, 0.68, 1.0), Color(1.0, 0.62, 0.30),
	Color(0.72, 0.52, 1.0), Color(0.42, 0.95, 0.60), Color(0.98, 0.82, 0.42),
]

var _station_nodes: Array = []      # [{node, base, phase, brot, lights}]
var _slight_tex: GradientTexture2D


func _build_stations() -> void:
	## REAL GPU-lit stations. Each hull is a Sprite2D on its own light layer, drawn a
	## touch DARK, then lit by two coloured PointLight2Ds (ADD blend) from different
	## sides — so parts of the hull sit in shadow and parts glow in colour. The lights
	## breathe and the whole thing floats + slowly rotates (updated in _update_stations).
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	_slight_tex = GradientTexture2D.new()
	_slight_tex.gradient = grad
	_slight_tex.fill = GradientTexture2D.FILL_RADIAL
	_slight_tex.fill_from = Vector2(0.5, 0.5)
	_slight_tex.fill_to = Vector2(0.5, 0.0)
	_slight_tex.width = 256
	_slight_tex.height = 256
	var dpx: float = Stations.display_px()
	for i in Stations.count():
		var tex: Texture2D = Stations.tex(Stations.LIST[i]["id"])
		if tex == null:
			continue
		var cont := Node2D.new()
		cont.position = Stations.world_pos(i)
		cont.z_index = -1
		add_child(cont)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2.ONE * (dpx / maxf(tex.get_size().x, tex.get_size().y))
		spr.light_mask = 2                                # only station-layer lights hit it
		spr.self_modulate = Color(0.46, 0.49, 0.55)       # dark base so the lights read
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		cont.add_child(spr)
		var gcol: Color = STATION_GLOW[i % STATION_GLOW.size()]
		var lights: Array = []
		for k in 2:
			var lgt := PointLight2D.new()
			lgt.texture = _slight_tex
			lgt.color = gcol if k == 0 else gcol.lerp(Color(1, 1, 1), 0.55)
			lgt.energy = 1.5
			lgt.blend_mode = Light2D.BLEND_MODE_ADD
			lgt.range_item_cull_mask = 2                  # light ONLY the station sprites
			lgt.texture_scale = dpx / 150.0
			lgt.position = Vector2.from_angle(float(i) * 1.7 + float(k) * PI) * dpx * 0.34
			cont.add_child(lgt)
			lights.append(lgt)
		_station_nodes.append({
			"node": cont, "base": Stations.world_pos(i),
			"phase": float(i) * 1.618, "brot": (fmod(float(i) * 2.399, 1.0) - 0.5) * 0.7,
			"spin": (fmod(float(i) * 1.73, 1.0) - 0.5) * 0.045,  # very slow continuous rotation, varied dir
			"lights": lights,
		})


func _update_stations(_delta: float) -> void:
	## Visible zero-g drift + rotation wobble + breathing lights, each on its own phase.
	for st in _station_nodes:
		var ph: float = st["phase"]
		var cont: Node2D = st["node"]
		# gentle zero-g float + a very slow, smooth, continuous rotation (loops seamlessly)
		cont.position = (st["base"] as Vector2) + Vector2(
			sin(_t * 0.14 + ph) * 22.0, cos(_t * 0.11 + ph * 1.3) * 18.0)
		cont.rotation = float(st["brot"]) + _t * float(st["spin"])
		var pulse := 1.2 + 0.22 * sin(_t * 0.5 + ph)
		for lg in st["lights"]:
			(lg as PointLight2D).energy = pulse


func _draw_stations(center: Vector2, half: Vector2) -> void:
	## Just the name plates now — the hulls + lighting are real nodes (_build_stations).
	var dpx: float = Stations.display_px()
	for i in _station_nodes.size():
		var p: Vector2 = (_station_nodes[i]["node"] as Node2D).position
		if absf(p.x - center.x) > half.x + dpx or absf(p.y - center.y) > half.y + dpx:
			continue
		var gcol: Color = STATION_GLOW[i % STATION_GLOW.size()]
		draw_string(ThemeDB.fallback_font, p + Vector2(-140.0, dpx * 0.55 + 34.0),
			str(Stations.LIST[i]["name"]), HORIZONTAL_ALIGNMENT_CENTER, 280.0, 22,
			Color(gcol.r, gcol.g, gcol.b, 0.92))


func _draw_wrecks(center: Vector2, half: Vector2) -> void:
	## Whole derelict hulls, ship-sized, slowly tumbling nowhere. A faint
	## salvage ring marks the ones still worth boarding.
	for cy in range(floori((center.y - half.y) / FIELD_CHUNK), floori((center.y + half.y) / FIELD_CHUNK) + 1):
		for cx in range(floori((center.x - half.x) / FIELD_CHUNK), floori((center.x + half.x) / FIELD_CHUNK) + 1):
			var w := _wreck_in_chunk(cx, cy)
			if w.is_empty() or w["taken"]:
				continue
			var p: Vector2 = w["pos"]
			var tex: Texture2D = Craftables.WRECKS[w["idx"]]
			var sz := tex.get_size()
			# barely-alive drift so it reads as adrift, not parked
			var rot: float = w["rot"] + sin(_t * 0.08 + p.x * 0.01) * 0.04
			draw_set_transform(p, rot, Vector2(WRECK_SCALE, WRECK_SCALE))
			draw_texture(tex, -sz * 0.5, Color(0.82, 0.85, 0.9))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# salvage ring — warm for rare hulls, teal for common
			var ring := Color(1.0, 0.8, 0.35) if w["rare"] else Color(0.4, 0.85, 1.0)
			var pulse := 0.5 + 0.5 * sin(_t * 2.0 + p.y * 0.02)
			draw_arc(p, WRECK_COLLECT_RADIUS, 0.0, TAU, 48,
				Color(ring.r, ring.g, ring.b, 0.08 + 0.10 * pulse), 1.5)
			draw_string(_font, p + Vector2(-80, WRECK_COLLECT_RADIUS + 16),
				"DERELICT — fly close to salvage", HORIZONTAL_ALIGNMENT_CENTER,
				160, 9, Color(ring.r, ring.g, ring.b, 0.25 + 0.25 * pulse))


func _draw_trash(center: Vector2, half: Vector2) -> void:
	for cy in range(floori((center.y - half.y) / FIELD_CHUNK), floori((center.y + half.y) / FIELD_CHUNK) + 1):
		for cx in range(floori((center.x - half.x) / FIELD_CHUNK), floori((center.x + half.x) / FIELD_CHUNK) + 1):
			for piece in _trash_in_chunk(cx, cy):
				if piece["taken"]:
					continue
				var p: Vector2 = piece["pos"]
				var mcol: Color = Elements.hue_of(piece["metal"])
				if _trash_tex.is_empty():
					# sprites not imported yet — placeholder polygons keep it alive
					_draw_trash_placeholder(p, mcol, piece)
					continue
				# real debris sprite. Map the stable per-piece roll to a texture
				# index — deterministic, and unaffected by how many sprites loaded.
				var idx: int = clampi(int(piece["sprite_roll"] * _trash_tex.size()),
					0, _trash_tex.size() - 1)
				var tex: Texture2D = _trash_tex[idx]
				var ts := tex.get_size()
				# normalise the longest side to TRASH_DRAW_MAX so any source
				# resolution draws SMALL (~28px, ~1/5.5 of the ~156px ship)
				var s: float = TRASH_DRAW_MAX / maxf(ts.x, maxf(ts.y, 1.0))
				# STATIC per-piece tilt (piece["spin"] as a fixed angle, NOT *_t) —
				# detailed sprites spinning continuously read as nauseating; tumbled
				# but still looks like real drifting debris
				draw_set_transform(p, piece["spin"], Vector2(s, s))
				draw_texture(tex, -ts * 0.5, Color(0.86, 0.88, 0.94))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# pieces being sucked into the ship: fly from where they were toward the hull,
	# shrinking and fading as they go (ease-in so it accelerates like a vacuum)
	if not _absorbing.is_empty() and not _trash_tex.is_empty():
		for a in _absorbing:
			var u: float = clampf(a["t"] / TRASH_ABSORB_TIME, 0.0, 1.0)
			var pos: Vector2 = a["pos0"].lerp(ship_pos, u * u)   # accelerate inward
			var idx: int = clampi(int(a["sprite_roll"] * _trash_tex.size()),
				0, _trash_tex.size() - 1)
			var tex: Texture2D = _trash_tex[idx]
			var ts := tex.get_size()
			var s: float = (TRASH_DRAW_MAX / maxf(ts.x, maxf(ts.y, 1.0))) * (1.0 - u * 0.85)
			draw_set_transform(pos, a["spin"] + u * 3.0, Vector2(s, s))   # slight spin-up
			draw_texture(tex, -ts * 0.5, Color(0.86, 0.88, 0.94, 1.0 - u))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_trash_placeholder(p: Vector2, mcol: Color, piece: Dictionary) -> void:
	## Fallback when no trash sprites are imported: the original hand-drawn
	## polygon shapes so the salvage field is never invisible.
	draw_set_transform(p, _t * piece["spin"], Vector2.ONE)
	match int(piece["kind"]):
		0:   # hull shard
			draw_colored_polygon(PackedVector2Array([
				Vector2(-9, -4), Vector2(10, -7), Vector2(4, 8), Vector2(-6, 6)]),
				Color(0.5, 0.54, 0.62))
			draw_polyline(PackedVector2Array([
				Vector2(-9, -4), Vector2(10, -7), Vector2(4, 8), Vector2(-6, 6), Vector2(-9, -4)]),
				Color(0.2, 0.22, 0.28), 1.5)
		1:   # dead solar panel
			draw_rect(Rect2(-12, -7, 24, 14), Color(0.16, 0.24, 0.42))
			draw_rect(Rect2(-12, -7, 24, 14), Color(0.45, 0.5, 0.6), false, 1.5)
			draw_line(Vector2(0, -7), Vector2(0, 7), Color(0.45, 0.5, 0.6), 1.0)
			draw_line(Vector2(-12, 0), Vector2(12, 0), Color(0.45, 0.5, 0.6), 1.0)
		2:   # cargo ring
			draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 20, Color(0.55, 0.58, 0.66), 3.5)
		3:   # bent strut
			draw_line(Vector2(-10, -6), Vector2(2, 2), Color(0.5, 0.54, 0.62), 3.0)
			draw_line(Vector2(2, 2), Vector2(10, -2), Color(0.5, 0.54, 0.62), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# faint glint in its metal's color
	draw_circle(p, 14.0, Color(mcol.r, mcol.g, mcol.b, 0.10))
	draw_circle(p + Vector2(3, -4), 1.5, Color(1, 1, 1, 0.7))


func _update_nebulae(center: Vector2, half: Vector2) -> void:
	## Smoke, now as world-placed Sprite2D nodes instead of per-frame
	## draw_texture. Two fog layers drift against each other and a soft glowing
	## heart sits inside; the tinted cloud stars stay immediate-mode (few, in
	## _draw_neb_stars). Fog textures are still generated lazily (first sight of
	## each cloud), so no startup hitch — nodes are built the first frame a
	## nebula comes into view and then kept (offscreen sprites auto-cull).
	for i in GameState.NEBULAE.size():
		var nc: Vector2 = GameState.nebula_center(i)
		var nr: float = GameState.nebula_radius(i)
		if (nc - center).length() > half.length() + nr + 1400.0:
			continue
		var nodes: Dictionary = _neb_nodes.get(i, {})
		if nodes.is_empty():
			nodes = _make_nebula_nodes(i, nc, nr)
			_neb_nodes[i] = nodes
		# the only per-frame work: the slow counter-drift of the two fog layers
		# (same rates/offsets as the old draw_set_transform rotations)
		(nodes["fogA"] as Sprite2D).rotation = _t * 0.008
		(nodes["fogB"] as Sprite2D).rotation = 2.4 - _t * 0.005


func _make_nebula_nodes(i: int, nc: Vector2, nr: float) -> Dictionary:
	## Build a nebula's four sprites once: two drifting fog layers (0.6 / 0.38
	## alpha) and the two-layer soft glow heart. Every position/scale/tint/alpha
	## matches the old immediate-mode draw exactly.
	var col: Color = GameState.NEBULAE[i]["color"]
	var tex := NebulaFog.texture_for(i)
	# base fog layer, drifting — scale follows this nebula's own size
	var s := nr * 2.9 / float(NebulaFog.SIZE)
	var fog_a := Sprite2D.new()
	fog_a.texture = tex
	fog_a.position = nc
	fog_a.scale = Vector2(s, s)
	fog_a.modulate = Color(1, 1, 1, 0.33)
	fog_a.z_index = -50
	add_child(fog_a)
	# second layer: bigger, rotated, counter-drifting — parallax smoke. Both
	# layers kept LIGHT (0.33 / 0.2) so flying INTO a nebula is a gentle colour
	# tint, not a big whole-screen brightness swing (bright inside / dark out).
	var fog_b := Sprite2D.new()
	fog_b.texture = tex
	fog_b.position = nc
	fog_b.scale = Vector2(s * 1.3, s * 1.15)
	fog_b.modulate = Color(1, 1, 1, 0.2)
	fog_b.z_index = -50   # same layer, added after fog_a => draws on top of it
	add_child(fog_b)
	# glowing heart, proportional to the cloud — the soft radial glow texture
	# (NOT stacked draw_circle discs, whose crisp edges read as concentric
	# rings). Two smoothly-faded layers give the core gentle depth. The heart
	# offset consumes the SAME rng.randf() the cloud stars replay (seed 7000+i),
	# so both stay identical to the old single-rng sequence.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + i
	var heart := nc + Vector2.from_angle(rng.randf() * TAU) * nr * 0.2
	var glow := NebulaFog.glow_texture()
	var gh: float = glow.get_size().x * 0.5
	var lc := col.lightened(0.35)
	var gso := nr * 0.30 / gh          # outer soft halo
	var glow_out := Sprite2D.new()
	glow_out.texture = glow
	glow_out.position = heart
	glow_out.scale = Vector2(gso, gso)
	glow_out.modulate = Color(lc.r, lc.g, lc.b, 0.09)
	glow_out.z_index = -45
	add_child(glow_out)
	var lc2 := col.lightened(0.6)
	var gsi := nr * 0.12 / gh          # inner brighter core
	var glow_in := Sprite2D.new()
	glow_in.texture = glow
	glow_in.position = heart
	glow_in.scale = Vector2(gsi, gsi)
	glow_in.modulate = Color(lc2.r, lc2.g, lc2.b, 0.13)
	glow_in.z_index = -45
	add_child(glow_in)
	return {"fogA": fog_a, "fogB": fog_b}


func _draw_neb_stars(ci: CanvasItem) -> void:
	## Stars packed through each visible cloud, tinted by it — few enough to
	## stay immediate-mode. Drawn on the _neb_stars_node proxy (z below the
	## parallax starfield, above the fog/glow) so the layering matches the old
	## single-_draw order exactly. The rng sequence (seed 7000+i) discards ONE
	## randf() first — the heart offset consumed in _make_nebula_nodes — so the
	## star pattern is byte-identical to before.
	var center := cam.get_screen_center_position()
	var half := get_viewport_rect().size * 0.5 / cam.zoom.x + Vector2(STAR_CHUNK, STAR_CHUNK)
	for i in GameState.NEBULAE.size():
		var nc: Vector2 = GameState.nebula_center(i)
		var nr: float = GameState.nebula_radius(i)
		if (nc - center).length() > half.length() + nr + 1400.0:
			continue
		var col: Color = GameState.NEBULAE[i]["color"]
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + i
		rng.randf()   # heart offset angle — consumed to keep the sequence identical
		var lc := col.lightened(0.65)
		for b in int(20.0 + nr / 60.0):
			var sp := nc + Vector2.from_angle(rng.randf() * TAU) \
				* rng.randf_range(0.0, nr * 0.95)
			ci.draw_circle(sp, rng.randf_range(0.7, 2.4),
				Color(lc.r, lc.g, lc.b, rng.randf_range(0.4, 0.9)))


## Parallax starfield: three depth layers scrolling at different rates.
## A star's world position = its pattern position + camera * (1 - depth),
## so far layers crawl and near layers sweep past — cheap, convincing 3D.
const STAR_LAYERS := [
	# [depth, count/chunk, size lo, size hi, alpha, tint]
	# NOTE: the nearest (brightest, glinted) layer must stay LAST — the glint
	# flag keys off the final index. Add deeper layers at the FRONT.
	[0.05, 75, 0.2, 0.5, 0.22, Color(0.62, 0.7, 0.95)],  # deepest micro-dust — packs the black
	[0.12, 80, 0.3, 0.8, 0.32, Color(0.7, 0.78, 1.0)],   # far dust
	[0.25, 55, 0.4, 1.0, 0.5, Color(0.75, 0.85, 1.0)],
	[0.55, 34, 0.8, 1.7, 0.72, Color(0.9, 0.95, 1.0)],
	[1.0, 18, 1.2, 2.6, 1.0, Color(1.0, 1.0, 1.0)],
]

# Rare "jewel" stars — a saturated tint on a small % of stars so the mostly
# neutral sky gets the occasional coloured spark (captain's request). Tasteful,
# not a rainbow: warm gold, soft coral-red, ice-blue, magenta, teal-green.
const STAR_JEWELS := [
	Color(1.0, 0.78, 0.35),   # warm gold / amber
	Color(1.0, 0.46, 0.42),   # soft coral red
	Color(0.5, 0.85, 1.0),    # cyan / ice-blue
	Color(1.0, 0.5, 0.9),     # magenta
	Color(0.5, 0.95, 0.72),   # teal-green
]
# per-layer jewel probability — absent on the faint deep micro-dust, a touch
# more present on the nearer, brighter layers (index matches STAR_LAYERS)
const STAR_JEWEL_CHANCE := [0.0, 0.015, 0.035, 0.05, 0.06]

# star patterns cached per (chunk, layer) — never regenerate RNGs per frame
var _star_cache := {}


func _star_chunk(cx: int, cy: int, li: int) -> Array:
	## The star PATTERN for a chunk+layer, generated once and cached — no
	## per-frame RNG churn. Each entry: [local_offset, size, alpha, glint, color].
	var key := Vector3i(cx, cy, li)
	if _star_cache.has(key):
		return _star_cache[key]
	if _star_cache.size() > 12000:
		_star_cache.clear()
	var layer: Array = STAR_LAYERS[li]
	var tint: Color = layer[5]
	var jchance: float = STAR_JEWEL_CHANCE[li]
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(cx, cy, 20 + li)
	var out: Array = []
	var near := li == STAR_LAYERS.size() - 1
	for i in int(layer[1]):
		# NOTE: consume the rng in the EXACT original order (pos, size, alpha,
		# then glint ONLY on the near layer via short-circuit) so the neutral
		# starfield's positions/sizes/glints are byte-identical to before.
		var pos := Vector2(rng.randf(), rng.randf()) * STAR_CHUNK
		var size := rng.randf_range(layer[2], layer[3])
		var alpha := rng.randf_range(0.3, 0.9) * float(layer[4])
		var glint: bool = near and rng.randf() < 0.08
		var col := tint
		# Rare jewel star: rolled from a HASH (not the rng) so it doesn't shift
		# the sequence — the neutral sky is unchanged and jewels layer on top.
		# Coloured ones are biased brighter/larger so they pop a little.
		if jchance > 0.0 \
				and float(hash("%d:%d:%d:%d:jw" % [cx, cy, li, i]) % 100000) / 100000.0 < jchance:
			col = STAR_JEWELS[hash("%d:%d:%d:%d:jc" % [cx, cy, li, i]) % STAR_JEWELS.size()]
			size *= 1.35
			alpha = clampf(alpha * 1.4 + 0.12, 0.0, 1.0)
		out.append([pos, size, alpha, glint, col])
	_star_cache[key] = out
	return out


func _update_star_layer(li: int, center: Vector2, half: Vector2) -> void:
	## Per-frame: park the layer's MultiMeshInstance2D at the parallax offset
	## (cheap). Its instances hold pattern-space star positions in a rolling
	## chunk window; the node.position = shift slides the whole layer, so the
	## rendered position (shift + pattern) exactly equals the old
	## `origin = chunk*STAR_CHUNK + shift; p = origin + st[0]`. The instance
	## buffer only rebuilds when the view leaves the buffered window (rare).
	var layer: Array = STAR_LAYERS[li]
	var depth: float = layer[0]
	var shift := center * (1.0 - depth)          # parallax offset
	var mmi: MultiMeshInstance2D = _star_mm[li]
	mmi.position = shift
	var vc := center - shift                     # pattern-space view center
	var cx0 := floori((vc.x - half.x) / STAR_CHUNK)
	var cy0 := floori((vc.y - half.y) / STAR_CHUNK)
	var cx1 := floori((vc.x + half.x) / STAR_CHUNK)
	var cy1 := floori((vc.y + half.y) / STAR_CHUNK)
	var b: Array = _star_built[li]
	if cx0 >= b[0] and cy0 >= b[1] and cx1 <= b[2] and cy1 <= b[3]:
		return   # still inside the buffered window — nothing to rebuild
	# view escaped the window: refill, padded so refills stay infrequent
	cx0 -= STAR_PAD; cy0 -= STAR_PAD; cx1 += STAR_PAD; cy1 += STAR_PAD
	_star_built[li] = [cx0, cy0, cx1, cy1]
	var xf: Array = []
	var cols: Array = []
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var origin := Vector2(cx, cy) * STAR_CHUNK
			for st in _star_chunk(cx, cy, li):
				var p: Vector2 = origin + st[0]
				var d: float = float(st[1]) * 2.0   # quad size = dot diameter
				var sc: Color = st[4]                # per-star tint (jewel or layer)
				xf.append(Transform2D(Vector2(d, 0), Vector2(0, d), p))
				cols.append(Color(sc.r, sc.g, sc.b, st[2]))
	var mm: MultiMesh = mmi.multimesh
	mm.instance_count = xf.size()
	for idx in xf.size():
		mm.set_instance_transform_2d(idx, xf[idx])
		mm.set_instance_color(idx, cols[idx])


func _draw_near_glints(ci: CanvasItem) -> void:
	## The near-layer glint: a bright cross of two lines on ~8% of the nearest
	## stars. A MultiMesh can't do per-instance line crosses, so these few
	## crosses stay immediate-mode on the _glints proxy (z just above the near
	## star layer, still behind the foreground). Positions/colours are identical
	## to the old inline glint — the near layer's depth is 1.0 so shift = 0 and
	## the world position is simply the pattern position.
	var li := STAR_LAYERS.size() - 1
	var center := cam.get_screen_center_position()
	var half := get_viewport_rect().size * 0.5 / cam.zoom.x + Vector2(STAR_CHUNK, STAR_CHUNK)
	var depth: float = STAR_LAYERS[li][0]
	var shift := center * (1.0 - depth)
	var vc := center - shift
	for cy in range(floori((vc.y - half.y) / STAR_CHUNK), floori((vc.y + half.y) / STAR_CHUNK) + 1):
		for cx in range(floori((vc.x - half.x) / STAR_CHUNK), floori((vc.x + half.x) / STAR_CHUNK) + 1):
			var origin := Vector2(cx, cy) * STAR_CHUNK + shift
			for st in _star_chunk(cx, cy, li):
				if st[3]:
					var p: Vector2 = origin + st[0]
					ci.draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), Color(1, 1, 1, 0.35), 1.0)
					ci.draw_line(p + Vector2(0, -4), p + Vector2(0, 4), Color(1, 1, 1, 0.35), 1.0)


# ==================================================================
# Deep-space dressing — fills the open space between destinations so the
# vast (~2.2×) universe reads RICH, never empty. A far parallax layer BEHIND
# the stars: tiny distant rock specks (distant asteroids too far to reach).
# No new art, no shaders. Everything is STATIC in world space and only
# crawls via ship-driven parallax — no wobble/rotation/pulse (motion-sickness
# safe). Generated once per coarse chunk and cached, like the star patterns.
const DEEP_CHUNK := 2400.0
const DEEP_DEPTH := 0.03          # BELOW every STAR_LAYERS depth (min 0.05), so the
                                  # layer drawn behind the stars also crawls slowest —
                                  # was 0.18, which made it parallax faster than the
                                  # two deepest star layers sitting in front of it
var _deep_cache := {}


func _deep_chunk(cx: int, cy: int) -> Dictionary:
	var key := Vector2i(cx, cy)
	if _deep_cache.has(key):
		return _deep_cache[key]
	if _deep_cache.size() > 2048:
		_deep_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(cx, cy, 40)
	var d := {}
	var origin := Vector2(cx, cy) * DEEP_CHUNK
	# a scatter of far-off rock specks — distant asteroids too far to reach
	var specks: Array = []
	for i in rng.randi_range(6, 12):
		specks.append([origin + Vector2(rng.randf(), rng.randf()) * DEEP_CHUNK,
			rng.randf_range(0.8, 2.4), rng.randf_range(0.25, 0.55)])
	d["specks"] = specks
	_deep_cache[key] = d
	return d


func _update_deep(center: Vector2, half: Vector2) -> void:
	## Deep-space specks (distant asteroids), now one MultiMeshInstance2D. Same
	## rolling-window + parallax scheme as the star layers, one node.position
	## per frame; instances only rebuild when the view leaves the buffer.
	var shift := center * (1.0 - DEEP_DEPTH)   # parallax: far layer crawls
	_deep_mm.position = shift
	var vc := center - shift                   # pattern-space view center
	var cx0 := floori((vc.x - half.x) / DEEP_CHUNK)
	var cy0 := floori((vc.y - half.y) / DEEP_CHUNK)
	var cx1 := floori((vc.x + half.x) / DEEP_CHUNK)
	var cy1 := floori((vc.y + half.y) / DEEP_CHUNK)
	if cx0 >= _deep_built[0] and cy0 >= _deep_built[1] \
			and cx1 <= _deep_built[2] and cy1 <= _deep_built[3]:
		return
	cx0 -= DEEP_PAD; cy0 -= DEEP_PAD; cx1 += DEEP_PAD; cy1 += DEEP_PAD
	_deep_built = [cx0, cy0, cx1, cy1]
	var xf: Array = []
	var cols: Array = []
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			for sp in _deep_chunk(cx, cy)["specks"]:
				var d: float = float(sp[1]) * 2.0
				xf.append(Transform2D(Vector2(d, 0), Vector2(0, d), sp[0] as Vector2))
				cols.append(Color(0.5, 0.52, 0.58, sp[2]))
	var mm: MultiMesh = _deep_mm.multimesh
	mm.instance_count = xf.size()
	for idx in xf.size():
		mm.set_instance_transform_2d(idx, xf[idx])
		mm.set_instance_color(idx, cols[idx])


func _draw_fields(center: Vector2, half: Vector2) -> void:
	var pad := half + Vector2(400, 400)
	for cy in range(floori((center.y - pad.y) / FIELD_CHUNK), floori((center.y + pad.y) / FIELD_CHUNK) + 1):
		for cx in range(floori((center.x - pad.x) / FIELD_CHUNK), floori((center.x + pad.x) / FIELD_CHUNK) + 1):
			var f := _field_in_chunk(cx, cy)
			if f.is_empty():
				continue
			var fc: Vector2 = f["center"]
			for rock in f["rocks"]:
				# LIVE mined-sync: a rock you mined inside is gone out here too
				if GameState.mined.has(rock["key"]):
					continue
				var p: Vector2 = fc + rock["off"]
				var r: float = rock["r"]
				# gentle floaty drift + slow spin, deterministic per rock (tiny in-place
				# motion only — keeps the no-lurch rule; no camera move)
				var _fph := float(hash(str(rock["key"]) + ":fl") % 1000) / 1000.0 * TAU
				var _spin := (0.10 + 0.12 * (float(hash(str(rock["key"]) + ":sp") % 100) / 99.0)) \
					* (1.0 if hash(rock["key"]) % 2 == 0 else -1.0)
				p += Vector2(sin(_t * 0.35 + _fph), cos(_t * 0.28 + _fph)) * (r * 0.07)
				# a PAINTED rock from the element's COLOUR FAMILY (grouped by the colour
				# the element's icon looks like) — shown AS-IS, never tinted. Which of
				# the family's variants shows is a stable per-rock random pick, so a
				# field draws varied rocks that all read as the right colour.
				var tex := RockFamily.rock_art(rock["sym"], rock["key"])
				if tex != null:
					var sz := tex.get_size()
					var s := clampf(r * 1.7, 30.0, 64.0) / maxf(sz.x, sz.y)
					draw_set_transform(p, _t * _spin + _fph, Vector2(s, s))
					draw_texture(tex, -sz * 0.5, Color(1, 1, 1))
					# the SHIP passing over the rock throws a shadow onto it —
					# the hull draws on top afterward, so this darkening reads as
					# a shadow peeking out from under the passing hull
					var over := 1.0 - clampf(
						ship_pos.distance_to(p) / (SHIP_SHADOW_R + r), 0.0, 1.0)
					if over > 0.0:
						draw_texture(tex, -sz * 0.5, Color(0, 0, 0, 0.6 * over))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					draw_circle(p, r, Elements.glow_for(rock["sym"]).darkened(0.3))
			if not _near_field.is_empty() and _near_field["center"] == fc:
				# faint 1px hint of the park extent — the "E · Park" prompt carries
				# the affordance; the captain dislikes bold drawn circles
				draw_arc(fc, f["radius"] + PARK_REACH, 0.0, TAU, 64,
					Color(0.35, 0.8, 1.0, 0.08), 1.0)


func _draw_beacon(center: Vector2) -> void:
	## The current survivor's BROKEN SHIP — their own hull, dead in the black,
	## distress strobe still blinking. Board it (E) to meet them.
	if not GameState.rescue_available():
		return
	var bp := GameState.rescue_beacon()
	if (bp - center).length() > 1600.0:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var tname := str(GameState.rescue_target().get("name", ""))
	var tex := _crew_wreck_tex(tname)
	if tex != null:
		# player-ship scale (~156px hull) — their craft, not a mothership
		var s := 160.0 / tex.get_size().x
		draw_set_transform(bp, 0.18, Vector2(s, s))
		draw_texture(tex, -tex.get_size() * 0.5, Color(0.85, 0.88, 0.95))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_set_transform(bp, 0.35, Vector2.ONE)
		draw_rect(Rect2(-16, -7, 32, 14), Color(0.45, 0.48, 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(bp + Vector2(0, -12), 3.0, Color(1.0, 0.85, 0.3, 0.4 + 0.6 * pulse))
	draw_arc(bp, 90.0 + pulse * 14.0, 0.0, TAU, 40,
		Color(1.0, 0.85, 0.3, 0.4 - 0.25 * pulse), 2.0)
	draw_arc(bp, 300.0, 0.0, TAU, 64, Color(1.0, 0.85, 0.3, 0.14), 2.0)
	draw_string(_font, bp + Vector2(-90, -84), "%s'S SHIP — NO POWER" % tname,
		HORIZONTAL_ALIGNMENT_CENTER, 180, 11,
		Color(1.0, 0.85, 0.3, 0.5 + 0.4 * pulse))


var _crew_wreck_cache := {}


func _crew_wreck_tex(tname: String) -> Texture2D:
	if tname == "":
		return null
	if not _crew_wreck_cache.has(tname):
		_crew_wreck_cache[tname] = load(
			"res://assets/sprites/crew/%s_wreck.png" % tname.to_lower())
	return _crew_wreck_cache[tname]


## The captain's ship, bow facing +X (see tools/process_ship_art.gd).
const SHIP_TEX := preload("res://assets/sprites/ship_hd.png")
const SHIP_SCALE := 0.46
const SHIP_SHADOW_R := 90.0   # how far the hull's shadow reaches onto rocks


func _draw_ship() -> void:
	# engine effects in ship space, mapped to the hull's real nozzles.
	# The flame block is tuned in the old 0.5-scale space, so it's drawn at
	# SHIP_SCALE*2 — the offsets track the hull at any scale.
	# Twin big orange mains astern (the pair sits ~17px apart, centred just
	# below the spine), front wing turbines fire forward for reverse, and
	# axial aft-facing wing pods burn differentially to yaw.
	draw_set_transform(ship_pos, heading, Vector2(SHIP_SCALE * 2.0, SHIP_SCALE * 2.0))
	if _thr > 0.05:
		# twin main drives — ship2's two big orange nozzles astern
		# (pixel-detected at flame-space y −8 / +11, ~19px apart)
		var flick := randf() * 9.0
		for ey in [-8.0, 11.0]:
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(-82, ey - 7), Vector2(-82, ey + 7),
					Vector2(-110.0 - flick, ey)]),
				Color(1.0, 0.7, 0.25, 0.85))
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(-82, ey - 3.5), Vector2(-82, ey + 3.5),
					Vector2(-97.0 - flick * 0.5, ey)]),
				Color(1.0, 0.92, 0.6, 0.9))
			draw_circle(Vector2(-84, ey), 9.0, Color(1.0, 0.6, 0.2, 0.14))
	elif _thr < -0.05:
		# reverse: BOTH bow pods fire FORWARD (+X). Bell centres pixel-mapped
		# at flame-space (37.5, ±52) — the +X face of the nose pods
		var rflick := randf() * 5.0
		for ey in [-52.0, 52.0]:
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(37, ey - 5), Vector2(37, ey + 5),
					Vector2(58.0 + rflick, ey)]),
				Color(0.4, 0.85, 1.0, 0.82))
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(37, ey - 2.5), Vector2(37, ey + 2.5),
					Vector2(50.0 + rflick * 0.5, ey)]),
				Color(0.92, 0.98, 1.0, 0.9))
	if absf(_turn) > 0.05:
		# turning: ONE aft SIDE turbine fires aft-and-outward. These are the
		# small nozzles on the aft hull sides (pixel-mapped top −48/−34,
		# bottom −50/+36), the ship's real maneuvering thrusters
		var top := _turn > 0.0
		var base := Vector2(-48.0, -34.0) if top else Vector2(-50.0, 36.0)
		var dir := (Vector2(-1.0, -0.6) if top else Vector2(-1.0, 0.6)).normalized()
		var perp := dir.orthogonal()
		var flick := randf() * 6.0
		draw_colored_polygon(PackedVector2Array([
			base + perp * 5.0, base - perp * 5.0, base + dir * (16.0 + flick)]),
			Color(0.4, 0.85, 1.0, 0.82))
		draw_colored_polygon(PackedVector2Array([
			base + perp * 2.5, base - perp * 2.5, base + dir * (9.0 + flick * 0.5)]),
			Color(0.92, 0.98, 1.0, 0.9))
		draw_circle(base + dir * 5.0, 6.0, Color(0.4, 0.85, 1.0, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# painted hull, rotated toward the heading
	draw_set_transform(ship_pos, heading, Vector2(SHIP_SCALE, SHIP_SCALE))
	draw_texture(SHIP_TEX, -SHIP_TEX.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
