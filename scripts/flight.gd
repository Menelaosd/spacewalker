extends Node2D
## Piloting mode — take the helm and fly the ship through infinite space.
## Space is generated in deterministic chunks (same coordinates always hold
## the same stars and asteroid fields), and fields get richer with distance
## from home. Park near a field (E) to move your dive site there, then
## spacewalk it. Q hands back the helm and returns inside.
## All visuals are placeholder _draw() shapes.

const HintBar := preload("res://scripts/hint_bar.gd")
const Keymap := preload("res://scripts/keymap.gd")
const KeyPrompt := preload("res://scripts/key_prompt.gd")
const THRUST := 560.0
const THRUST_REV := 260.0
const TURN_RATE := 2.6          # rad/s — A/D yaw
const MAX_SPEED := 720.0
const DAMP := 0.45
const STAR_CHUNK := 640.0
const FIELD_CHUNK := 1600.0
const PARK_REACH := 140.0        # extra reach beyond a field's radius
const HOME_DOCK_RADIUS := 300.0
const INVENTORY_SCREEN := preload("res://scripts/inventory_screen.gd")
const FLOAT_TEXT := preload("res://scripts/float_text.gd")
const RADAR_PANEL := preload("res://scripts/radar_panel.gd")
const QUEST_LOG := preload("res://scripts/quest_log.gd")

# Derelict debris — old wrecks and lost cargo. Human-made, so its metal
# mix is scrap composition, not solar: mostly Al/Fe hulls, Ti struts,
# Ni/Cu wiring, the rare silver contact or gold connector.
const SCRAP_METALS := [
	["Al", 30], ["Fe", 30], ["Ti", 15], ["Ni", 10],
	["Cu", 10], ["Ag", 4], ["Au", 1],
]
const TRASH_COLLECT_RADIUS := 70.0

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
var _recipe_banner: Control
var _dialog: Control        # first-meeting conversation overlay
var _in_dialog := false     # helm frozen while the meeting plays
var _comets: Array = []          # {pos, vel, size, life}
var _comet_timer := 6.0
var _near_beacon := false        # in reach of the current distress beacon
var _near_field: Dictionary = {}
var _near_home := false
var _scooping := false
var _t := 0.0
var _font: Font = ThemeDB.fallback_font

var _pos_label: Label
var _cargo_label: Label
var _prompt_label: Control
var _msg_label: Label
var _msg_tween: Tween


var _flight_origin := Vector2.ZERO


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR   # painted hull, not pixel art
	ship_pos = GameState.sector
	_flight_origin = ship_pos
	cam.position = ship_pos
	cam.reset_smoothing()
	_build_hud()
	GameState.notify.connect(_on_notify)
	GameState.say("You have the helm. Fields get richer the farther you fly.")
	# debug: SW_DIALOG=JUNO opens that crew member's first-meeting dialog
	if OS.get_environment("SW_DIALOG") != "":
		_in_dialog = true
		_dialog.start(OS.get_environment("SW_DIALOG"))
	# debug: SW_WRECK=1 parks a rare derelict beside the ship and pops the
	# recipe banner, for screenshots
	if OS.get_environment("SW_WRECK") != "":
		var cc := Vector2i((ship_pos / FIELD_CHUNK).floor())
		_wreck_cache[cc] = {
			"pos": ship_pos + Vector2(420, -160), "idx": 13, "rot": 0.3,
			"rare": true, "key": "w:debug", "taken": false,
		}
		_recipe_banner.show_recipe("jukebox")


func _process(delta: float) -> void:
	if _in_dialog:
		_t += delta
		queue_redraw()   # the wreck keeps drifting behind the dialog dim
		return
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
	cam.position = ship_pos

	_near_home = ship_pos.length() < HOME_DOCK_RADIUS
	_near_field = _find_near_field()
	_near_beacon = GameState.rescue_available() \
		and ship_pos.distance_to(GameState.rescue_beacon()) < 300.0
	if not GameState.pending_shift \
			and ship_pos.distance_to(_flight_origin) > 600.0:
		GameState.pending_shift = true   # you actually flew somewhere

	_t += delta
	# nebula flying scoops gas into the tanks — the only source of H/He & co
	_scooping = bool(GameState.region_at(ship_pos)["nebula"])
	if _scooping:
		GameState.scoop_gas(delta)

	_collect_trash()
	_collect_wrecks()
	_update_comets(delta)
	_update_hud()
	Sfx.thrust_on(absf(_thr) > 0.05 or absf(_turn) > 0.05)
	queue_redraw()


func _on_rescue_dialog_done() -> void:
	## The screen is solid black under the dialog's fade — bring them aboard
	## and cut to the ship interior, where they now live at their spot.
	var r: Dictionary = GameState.do_rescue()
	GameState.sector = ship_pos
	GameState.say("%s is aboard — %s." % [r.get("name", ""), r.get("perk", "")])
	get_tree().change_scene_to_file("res://scenes/ship_interior.tscn")


func _exit_tree() -> void:
	Sfx.stop_loops()


func _update_comets(delta: float) -> void:
	## Two flavors share the list: slow ice comets that amble across the
	## view, and quick shooting stars that flash by in under a second.
	_comet_timer -= delta
	if _comet_timer <= 0.0:
		var shooting := randf() < 0.6
		_comet_timer = randf_range(1.8, 4.5) if shooting else randf_range(6.0, 13.0)
		var a := randf() * TAU
		var start: Vector2 = ship_pos + Vector2.from_angle(a) * 860.0
		var across := (ship_pos - start).normalized().rotated(randf_range(-0.7, 0.7))
		_comets.append({
			"pos": start,
			"vel": across * (randf_range(950.0, 1500.0) if shooting
				else randf_range(120.0, 210.0)),
			"size": randf_range(1.2, 2.0) if shooting else randf_range(2.6, 4.2),
			"life": randf_range(0.7, 1.1) if shooting else randf_range(9.0, 14.0),
		})
	var keep: Array = []
	for c in _comets:
		c["pos"] += (c["vel"] as Vector2) * delta
		c["life"] = float(c["life"]) - delta
		if float(c["life"]) > 0.0 and (c["pos"] as Vector2).distance_to(ship_pos) < 2400.0:
			keep.append(c)
	_comets = keep


func _unhandled_input(event: InputEvent) -> void:
	if _in_dialog:
		return   # the dialog overlay owns all input
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_E:
			if _near_home:
				GameState.sector = Vector2.ZERO
				GameState.save_game()
				Sfx.play("bank", -8.0)
				GameState.say("Docked at home.")
				get_tree().change_scene_to_file("res://scenes/main.tscn")
			elif _near_beacon:
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
				get_tree().change_scene_to_file("res://scenes/main.tscn")
		KEY_Q:
			# hold position out here; the airlock can spacewalk this spot too
			GameState.sector = ship_pos
			get_tree().change_scene_to_file("res://scenes/ship_interior.tscn")


# ==================================================================
# Deterministic chunked space
# ==================================================================
func _chunk_seed(cx: int, cy: int, salt: int) -> int:
	return (cx * 73856093) ^ (cy * 19349663) ^ (salt * 83492791)


func _field_in_chunk(cx: int, cy: int) -> Dictionary:
	var key := Vector2i(cx, cy)
	if _field_cache.has(key):
		return _field_cache[key]
	if _field_cache.size() > 512:
		_field_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(cx, cy, 1)
	var field := {}
	var origin := Vector2(cx, cy) * FIELD_CHUNK
	# the region plan decides how likely, big and rich fields are here
	var region := GameState.region_at(origin + Vector2.ONE * FIELD_CHUNK * 0.5)
	# the home chunk stays clear — that's where the dock lives
	if not (cx == 0 and cy == 0) and rng.randf() < float(region["chance"]):
		var center := origin + Vector2(
			rng.randf_range(FIELD_CHUNK * 0.2, FIELD_CHUNK * 0.8),
			rng.randf_range(FIELD_CHUNK * 0.2, FIELD_CHUNK * 0.8))
		var radius: float = rng.randf_range(170.0, 300.0) * float(region["size"])
		var rich: float = GameState.richness_at(center)
		var rocks: Array = []
		for i in rng.randi_range(6, 13):
			rocks.append({
				"off": Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.15, 0.85),
				"r": rng.randf_range(9.0, 24.0) * float(region["size"]),
				"rich": rng.randf() < rich,
			})
		field = {"center": center, "radius": radius, "rich": rich,
			"rocks": rocks, "tint": region["tint"]}
	_field_cache[key] = field
	return field


func _trash_in_chunk(cx: int, cy: int) -> Array:
	var key := Vector2i(cx, cy)
	if _trash_cache.has(key):
		return _trash_cache[key]
	if _trash_cache.size() > 512:
		_trash_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(cx, cy, 3)
	var pieces: Array = []
	# no junk in the home chunk; sparse everywhere else
	if not (cx == 0 and cy == 0) and rng.randf() < 0.3:
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
				"kind": rng.randi_range(0, 3),
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
	if _wreck_cache.size() > 512:
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
					ft2.position = w["pos"] + Vector2(0, y)
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
	UITheme.shrink(radar, true, false)

	# quest log, tucked under the radar (offset scaled to match)
	var qlog := QUEST_LOG.new()
	root.add_child(qlog)
	qlog.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	qlog.offset_top += 150.0
	qlog.offset_bottom += 150.0
	UITheme.shrink(qlog, true, false)

	var nav := PanelContainer.new()
	nav.position = Vector2(18, 18)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nav)
	var box := VBoxContainer.new()
	nav.add_child(box)
	_pos_label = Label.new()
	box.add_child(_pos_label)
	_cargo_label = Label.new()
	_cargo_label.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_cargo_label)

	_prompt_label = KeyPrompt.new()
	_prompt_label.modulate = Color(0.6, 0.9, 1.0, 0.0)
	root.add_child(_prompt_label)

	_msg_label = Label.new()
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.modulate.a = 0.0
	root.add_child(_msg_label)
	_msg_label.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 70)

	var hint := HintBar.new()
	hint.items = Keymap.hint("flight")
	root.add_child(hint)

	# "RECIPE RECOVERED" reveal — the payoff for stripping a derelict
	_recipe_banner = RECIPE_BANNER.new()
	root.add_child(_recipe_banner)

	# first-meeting dialog — boarding a survivor's broken ship plays this,
	# then fades to black and brings them aboard
	_dialog = DIALOG_SCENE.new()
	root.add_child(_dialog)
	_dialog.finished.connect(_on_rescue_dialog_done)


func _update_hud() -> void:
	var km := ship_pos.length() / 100.0
	var region_name: String = GameState.region_at(ship_pos)["name"]
	var line := "%s   ·   Sector (%d, %d)   ·   Home %.1f km" % [
		region_name.to_upper(), int(ship_pos.x / 100.0), int(ship_pos.y / 100.0), km]
	if GameState.rescue_available():
		var t: Dictionary = GameState.rescue_target()
		line += "   ·   ✦ %s'S BEACON: %s" % [t["name"], str(t["region"]).to_upper()]
	elif GameState.rescued_count() < GameState.RESCUES.size():
		line += "   ·   ✦ NEXT SIGNAL NEEDS DRIVE PART %d" % (GameState.rescued_count() + 1)
	_pos_label.text = line
	_cargo_label.text = "Banked ore: %d" % GameState.banked
	if _near_beacon:
		_prompt_label.set_prompt("E    Board the wreck — %s, %s" % [
			GameState.rescue_target()["name"], GameState.rescue_target()["role"]])
		_prompt_label.modulate.a = 0.95
	elif _near_home:
		_prompt_label.set_prompt("E    Dock at home")
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
# Placeholder visuals
# ==================================================================
func _draw() -> void:
	var center := cam.get_screen_center_position()
	var half := get_viewport_rect().size * 0.5 + Vector2(STAR_CHUNK, STAR_CHUNK)
	_draw_nebulae(center, half)
	_draw_stars(center, half)
	_draw_fields(center, half)
	_draw_wrecks(center, half)
	_draw_trash(center, half)
	_draw_beacon(center)
	_draw_home()
	_draw_home_compass()
	for c in _comets:
		SpaceDressing.draw_comet(self, c, _t)
	_draw_ship()


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
				var ang: float = _t * piece["spin"]
				draw_set_transform(p, ang, Vector2.ONE)
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


func _draw_nebulae(center: Vector2, half: Vector2) -> void:
	## Smoke. Two layers of fractal-noise fog (NebulaFog) drifting slowly
	## against each other, a glowing heart, and stars tinted by the cloud.
	for i in GameState.NEBULAE.size():
		var nc: Vector2 = GameState.nebula_center(i)
		var nr: float = GameState.nebula_radius(i)
		if (nc - center).length() > half.length() + nr + 1400.0:
			continue
		var col: Color = GameState.NEBULAE[i]["color"]
		var tex := NebulaFog.texture_for(i)
		var half_tex := Vector2(NebulaFog.SIZE, NebulaFog.SIZE) * 0.5
		# base fog layer, drifting — scale follows this nebula's own size
		var s := nr * 2.9 / float(NebulaFog.SIZE)
		draw_set_transform(nc, _t * 0.008, Vector2(s, s))
		draw_texture(tex, -half_tex)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# second layer: bigger, rotated, counter-drifting — parallax smoke
		draw_set_transform(nc, 2.4 - _t * 0.005, Vector2(s * 1.3, s * 1.15))
		draw_texture(tex, -half_tex, Color(1, 1, 1, 0.7))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# glowing heart, proportional to the cloud
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + i
		var heart := nc + Vector2.from_angle(rng.randf() * TAU) * nr * 0.2
		draw_circle(heart, nr * 0.125, Color(col.lightened(0.3).r, col.lightened(0.3).g,
			col.lightened(0.3).b, 0.05))
		draw_circle(heart, nr * 0.046, Color(col.lightened(0.55).r, col.lightened(0.55).g,
			col.lightened(0.55).b, 0.07))
		# stars packed through the cloud, tinted by it — big clouds get more
		for b in int(20.0 + nr / 60.0):
			var sp := nc + Vector2.from_angle(rng.randf() * TAU) \
				* rng.randf_range(0.0, nr * 0.95)
			draw_circle(sp, rng.randf_range(0.7, 2.4),
				Color(col.lightened(0.65).r, col.lightened(0.65).g,
					col.lightened(0.65).b, rng.randf_range(0.4, 0.9)))


## Parallax starfield: three depth layers scrolling at different rates.
## A star's world position = its pattern position + camera * (1 - depth),
## so far layers crawl and near layers sweep past — cheap, convincing 3D.
const STAR_LAYERS := [
	# [depth, count/chunk, size lo, size hi, alpha, tint]
	[0.12, 80, 0.3, 0.8, 0.32, Color(0.7, 0.78, 1.0)],   # far dust
	[0.25, 55, 0.4, 1.0, 0.5, Color(0.75, 0.85, 1.0)],
	[0.55, 34, 0.8, 1.7, 0.72, Color(0.9, 0.95, 1.0)],
	[1.0, 18, 1.2, 2.6, 1.0, Color(1.0, 1.0, 1.0)],
]

# star patterns cached per (chunk, layer) — never regenerate RNGs per frame
var _star_cache := {}


func _star_chunk(cx: int, cy: int, li: int) -> Array:
	## The star PATTERN for a chunk+layer, generated once and cached — no
	## per-frame RNG churn. Each entry: [local_offset, size, alpha, glint].
	var key := Vector3i(cx, cy, li)
	if _star_cache.has(key):
		return _star_cache[key]
	if _star_cache.size() > 3000:
		_star_cache.clear()
	var layer: Array = STAR_LAYERS[li]
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(cx, cy, 20 + li)
	var out: Array = []
	var near := li == STAR_LAYERS.size() - 1
	for i in int(layer[1]):
		out.append([Vector2(rng.randf(), rng.randf()) * STAR_CHUNK,
			rng.randf_range(layer[2], layer[3]),
			rng.randf_range(0.3, 0.9) * float(layer[4]),
			near and rng.randf() < 0.08])
	_star_cache[key] = out
	return out


func _draw_stars(center: Vector2, half: Vector2) -> void:
	for li in STAR_LAYERS.size():
		var layer: Array = STAR_LAYERS[li]
		var depth: float = layer[0]
		var shift := center * (1.0 - depth)          # parallax offset
		var vc := center - shift                     # pattern-space view center
		var tint: Color = layer[5]
		for cy in range(floori((vc.y - half.y) / STAR_CHUNK), floori((vc.y + half.y) / STAR_CHUNK) + 1):
			for cx in range(floori((vc.x - half.x) / STAR_CHUNK), floori((vc.x + half.x) / STAR_CHUNK) + 1):
				var origin := Vector2(cx, cy) * STAR_CHUNK + shift
				for st in _star_chunk(cx, cy, li):
					var p: Vector2 = origin + st[0]
					draw_circle(p, st[1], Color(tint.r, tint.g, tint.b, st[2]))
					if st[3]:
						draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), Color(1, 1, 1, 0.35), 1.0)
						draw_line(p + Vector2(0, -4), p + Vector2(0, 4), Color(1, 1, 1, 0.35), 1.0)


func _draw_fields(center: Vector2, half: Vector2) -> void:
	var pad := half + Vector2(400, 400)
	for cy in range(floori((center.y - pad.y) / FIELD_CHUNK), floori((center.y + pad.y) / FIELD_CHUNK) + 1):
		for cx in range(floori((center.x - pad.x) / FIELD_CHUNK), floori((center.x + pad.x) / FIELD_CHUNK) + 1):
			var f := _field_in_chunk(cx, cy)
			if f.is_empty():
				continue
			var fc: Vector2 = f["center"]
			var base := Color(0.42, 0.4, 0.38)
			if f["tint"] != null:
				base = base.lerp(f["tint"], 0.3)
			for rock in f["rocks"]:
				var p: Vector2 = fc + rock["off"]
				var r: float = rock["r"]
				draw_circle(p, r, base)
				# sun-side sheen, night-side shadow — same light as everything
				draw_circle(p + SpaceDressing.SUN_DIR * r * 0.3, r * 0.5,
					base.lightened(0.18))
				draw_circle(p - SpaceDressing.SUN_DIR * r * 0.35, r * 0.5,
					base.darkened(0.3))
				var fleck := Color(0.4, 0.95, 1.0) if rock["rich"] else Color(1.0, 0.72, 0.25)
				draw_circle(p + Vector2(-r * 0.25, r * 0.2), 2.5, fleck)
			if not _near_field.is_empty() and _near_field["center"] == fc:
				draw_arc(fc, f["radius"] + PARK_REACH, 0.0, TAU, 64,
					Color(0.35, 0.8, 1.0, 0.25), 2.0)


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


func _draw_home() -> void:
	draw_arc(Vector2.ZERO, HOME_DOCK_RADIUS, 0.0, TAU, 64,
		Color(0.3, 0.8, 1.0, 0.15), 2.0)
	# mini home station
	var hull := Color(0.55, 0.58, 0.66)
	draw_rect(Rect2(-26, -14, 52, 28), hull)
	draw_circle(Vector2(-26, 0), 14.0, hull)
	draw_circle(Vector2(26, 0), 14.0, hull)
	draw_rect(Rect2(-26, -3, 52, 6), Color(0.9, 0.45, 0.15))
	draw_string(_font, Vector2(-24, -HOME_DOCK_RADIUS - 10), "HOME",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.9, 1.0, 0.6))


func _draw_home_compass() -> void:
	if ship_pos.length() < 600.0:
		return
	var dir := -ship_pos.normalized()
	var base := ship_pos + dir * 84.0
	var side := dir.orthogonal() * 6.0
	draw_colored_polygon(
		PackedVector2Array([base + dir * 14.0, base + side, base - side]),
		Color(1.0, 0.85, 0.3, 0.7))
	draw_string(_font, base + dir * 26.0 + Vector2(-18, 4),
		"%.1f km" % (ship_pos.length() / 100.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.85, 0.3, 0.55))


## The captain's ship, bow facing +X (see tools/process_ship_art.gd).
const SHIP_TEX := preload("res://assets/sprites/ship_hd.png")
const SHIP_SCALE := 0.46


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
