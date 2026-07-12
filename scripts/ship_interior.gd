extends Node2D
## The inside of the ship — a base-building canvas. An 8x4 grid masked to
## the hull silhouette (bow right, like the exterior). Six core rooms sit
## amidships; the rest is bare hull under a dark overlay with a visible
## grid. Walk to the edge of the built ship and press E on a glowing bay
## to expand into it (plain rooms for now — purposes come later).

const INTERACT_RADIUS := 72.0
const GEAR_PANEL := preload("res://scripts/gear_panel.gd")
const INVENTORY_SCREEN := preload("res://scripts/inventory_screen.gd")
const UPGRADE_MODAL := preload("res://scripts/upgrade_modal.gd")
const FABRICATOR_MODAL := preload("res://scripts/fabricator_modal.gd")
const Craftables := preload("res://scripts/craftables.gd")
const HintBar := preload("res://scripts/hint_bar.gd")
const Keymap := preload("res://scripts/keymap.gd")
const KeyPrompt := preload("res://scripts/key_prompt.gd")

# roomy cells — objects get distance between them and stay accessible
const CELL_W := 190.0
const CELL_H := 160.0
const ORIGIN := Vector2(-760, -320)   # grid top-left (8x4 cells)

# ------------------------------------------------------------------
# The captain's prop kit (game-assets sheets, cut by tools/extract_props.gd)
# ------------------------------------------------------------------
const P := {
	# floors (sheet 2) — one look per room type
	"fl_plain": preload("res://assets/props/s2_00.png"),
	"fl_brace": preload("res://assets/props/s2_01.png"),
	"fl_vent": preload("res://assets/props/s2_03.png"),
	"fl_rust": preload("res://assets/props/s2_04.png"),
	"fl_purple": preload("res://assets/props/s2_05.png"),
	"fl_hazard": preload("res://assets/props/s2_08.png"),
	"fl_grate": preload("res://assets/props/s2_10.png"),
	# walls (sheet 3)
	"wall_h": preload("res://assets/props/s3_00.png"),
	"wall_v": preload("res://assets/props/s3_01.png"),
	"wall_ctl": preload("res://assets/props/s3_02.png"),   # corner, trim top+left
	"wall_ctr": preload("res://assets/props/s3_03.png"),   # corner, trim top+right
	"wall_t": preload("res://assets/props/s3_08.png"),     # T: bar + stem down
	"wall_x": preload("res://assets/props/s3_09.png"),     # cross junction
	"window": preload("res://assets/props/s3_14.png"),
	"door_bar": preload("res://assets/props/s4_12.png"),
	# build markers (sheet 4)
	"cell_ok": preload("res://assets/props/s4_07.png"),
	"cell_no": preload("res://assets/props/s4_08.png"),
	# thin L corner-brackets, all four orientations (sheet 4) — the
	# native pieces for inner elbows. Named by their two arm directions.
	"elb_es": preload("res://assets/props/s4_00.png"),   # corner top-left
	"elb_ws": preload("res://assets/props/s4_01.png"),   # corner top-right
	"elb_en": preload("res://assets/props/s4_03.png"),   # corner bottom-left
	"elb_wn": preload("res://assets/props/s4_04.png"),   # corner bottom-right
	# engine room (sheet 5)
	"reactor": preload("res://assets/props/s5_01.png"),
	"batteries": preload("res://assets/props/s5_03.png"),
	"pipe": preload("res://assets/props/s5_06.png"),
	"tank": preload("res://assets/props/s5_09.png"),
	"cables": preload("res://assets/props/s5_12.png"),
	"generator": preload("res://assets/props/s5_13.png"),
	# quarters / workshop (sheet 6)
	"bunk": preload("res://assets/props/s6_00.png"),
	"locker": preload("res://assets/props/s6_02.png"),
	"wardrobe": preload("res://assets/props/s6_03.png"),
	"workbench": preload("res://assets/props/s6_05.png"),
	"chair": preload("res://assets/props/s6_08.png"),
	"medkit": preload("res://assets/props/s6_09.png"),
	"nightstand": preload("res://assets/props/s6_10.png"),
	"toolboard": preload("res://assets/props/s6_11.png"),
	# bridge (sheet 7)
	"helm": preload("res://assets/props/s7_00.png"),
	"console_wide": preload("res://assets/props/s7_01.png"),
	"radar_disp": preload("res://assets/props/s7_02.png"),
	"pedestal": preload("res://assets/props/s7_07.png"),
	"monitors": preload("res://assets/props/s7_06.png"),
	"holo_table": preload("res://assets/props/s7_10.png"),
	# cargo / airlock (sheet 8)
	"hatch": preload("res://assets/props/s8_00.png"),
	"crew_npc": preload("res://assets/props/s10_00.png"),
	"crate_quad": preload("res://assets/props/s8_01.png"),
	"crate_hazard": preload("res://assets/props/s8_05.png"),
	"barrel": preload("res://assets/props/s8_07.png"),
	"cylinders": preload("res://assets/props/s8_08.png"),
	"toolbox": preload("res://assets/props/s8_12.png"),
	# the fabricator — a 3D printer in the cargo hold (craft sheet 6;
	# its art is a STATION, never offered as a craftable)
	"fabricator": preload("res://assets/craft/fabricator.png"),
}

# per-room floor tile + furniture: [tex key, offset from cell center, width px]
const ROOM_FLOOR := {
	"quarters": "fl_purple", "engine": "fl_rust", "upgrade": "fl_brace",
	"bridge": "fl_vent", "cargo": "fl_grate", "airlock": "fl_hazard",
	"room": "fl_plain",
}
const ROOM_PROPS := {
	"quarters": [
		["bunk", Vector2(-54, -8), 62.0],
		["nightstand", Vector2(10, 40), 34.0],
		["locker", Vector2(66, -38), 28.0],
		["medkit", Vector2(70, 28), 26.0],
	],
	"engine": [
		["batteries", Vector2(-60, 42), 52.0],
		["tank", Vector2(72, 36), 30.0],
		["cables", Vector2(-84, -22), 16.0],
		["generator", Vector2(46, 54), 40.0],
	],
	"upgrade": [
		["toolboard", Vector2(-66, -52), 40.0],
	],
	"bridge": [
		["radar_disp", Vector2(42, -48), 38.0],
		["holo_table", Vector2(70, 26), 36.0],
	],
	"cargo": [
		["crate_quad", Vector2(58, 36), 52.0],
		["crate_hazard", Vector2(70, -42), 32.0],
		["barrel", Vector2(-68, 44), 28.0],
		["toolbox", Vector2(-14, 56), 28.0],
	],
	"airlock": [
		["cylinders", Vector2(-56, -40), 46.0],
		["wardrobe", Vector2(-64, 34), 36.0],
	],
	"room": [],
}

# rescued crew live aboard: room type, offset in that room, suit tint
const NPC_SPOTS := {
	"JUNO": ["upgrade", Vector2(-40, 50), Color(1.15, 1.0, 0.72)],
	"MIRA": ["quarters", Vector2(44, 6), Color(0.78, 1.12, 0.85)],
	"HALE": ["cargo", Vector2(-58, -6), Color(0.8, 1.0, 1.15)],
	"SOLA": ["quarters", Vector2(-14, 52), Color(1.15, 0.85, 0.85)],
	"VEGA": ["bridge", Vector2(-66, -40), Color(1.0, 0.88, 1.2)],
}

# ambient light halos drawn IN FRONT of glowing props: [color, radius]
const GLOWS := {
	"monitors": [Color(0.35, 0.8, 1.0), 30.0],
	"radar_disp": [Color(0.3, 0.7, 1.0), 26.0],
	"holo_table": [Color(0.35, 0.9, 1.0), 28.0],
	"console_wide": [Color(0.4, 0.8, 1.0), 28.0],
	"helm": [Color(0.35, 0.75, 1.0), 34.0],
	"reactor": [Color(1.0, 0.6, 0.2), 52.0],
	"batteries": [Color(0.4, 0.85, 1.0), 26.0],
	"tank": [Color(0.45, 0.8, 1.0), 20.0],
	"workbench": [Color(0.5, 1.0, 0.6), 20.0],
	"pedestal": [Color(0.4, 0.85, 1.0), 14.0],
	"window": [Color(0.5, 0.8, 1.0), 24.0],
	"generator": [Color(1.0, 0.7, 0.3), 18.0],
	"medkit": [Color(1.0, 0.5, 0.5), 12.0],
	"cylinders": [Color(0.5, 0.8, 1.0), 16.0],
	"hatch": [Color(0.9, 0.75, 0.3), 20.0],
	"fabricator": [Color(0.35, 0.85, 1.0), 24.0],
}

@onready var crew: Node2D = $Crew

var _font: Font = ThemeDB.fallback_font
var _stations: Array = []
var _active: int = -1
var _reactor := 0.0

# interior HUD
var _banked_label: Label
var _room_label: Label
var _prompt_label: Control
var _msg_label: Label
var _msg_tween: Tween
var _upgrade_modal: Control
var _fab_modal: Control
var _inventory: Control
var _rename_box: Control
var _rename_edit: LineEdit
var _ending_t := 0.0   # > 0 while the going-home sequence plays

# fabricator placement mode: a chosen object follows the mouse across the
# rooms YOU built, snapping to each room's floor grid; click / E to print
var _placing_id := ""
var _place_cell := -1
var _place_col := 0
var _place_row := 0
var _place_ok := false
var _hover_furn := -1   # placed piece under the mouse — right-click recycles it


# ------------------------------------------------------------------
# Grid helpers
# ------------------------------------------------------------------
func cell_rect(cell: int) -> Rect2:
	var col := cell % GameState.SHIP_COLS
	var row := int(float(cell) / GameState.SHIP_COLS)
	return Rect2(ORIGIN + Vector2(col * CELL_W, row * CELL_H), Vector2(CELL_W, CELL_H))


func cell_at(p: Vector2) -> int:
	var rel := p - ORIGIN
	if rel.x < 0.0 or rel.y < 0.0:
		return -1
	var col := int(rel.x / CELL_W)
	var row := int(rel.y / CELL_H)
	if col >= GameState.SHIP_COLS or row >= GameState.SHIP_ROWS:
		return -1
	return row * GameState.SHIP_COLS + col


func _built(cell: int) -> bool:
	return GameState.rooms.has(cell)


# directional wall margins: the sprite is ~33px above the feet, so the
# TOP wall needs a much deeper keep-out or the head climbs the plating
const WALL_MARGIN := 12.0        # left/right
const WALL_MARGIN_TOP := 28.0    # north walls (and the window glass)
const WALL_MARGIN_BOTTOM := 10.0

var _obstacles: Array[Rect2] = []   # furniture/station collision, feet-space


func _is_walkable(p: Vector2) -> bool:
	# ALL collision runs on the feet, not the sprite center — so neither
	# walls nor furniture can be overlapped by walking down onto them
	var feet := p + Vector2(0, 12)
	var cell := cell_at(feet)
	if not _built(cell):
		return false
	var r := cell_rect(cell)
	var col := cell % GameState.SHIP_COLS
	var row := int(float(cell) / GameState.SHIP_COLS)
	if feet.x < r.position.x + WALL_MARGIN and (col == 0 or not _built(cell - 1)):
		return false
	if feet.x > r.end.x - WALL_MARGIN and (col == GameState.SHIP_COLS - 1 or not _built(cell + 1)):
		return false
	if feet.y < r.position.y + WALL_MARGIN_TOP and (row == 0 or not _built(cell - GameState.SHIP_COLS)):
		return false
	if feet.y > r.end.y - WALL_MARGIN_BOTTOM and (row == GameState.SHIP_ROWS - 1 or not _built(cell + GameState.SHIP_COLS)):
		return false
	# furniture: a small foot BOX, so you can't clip corners diagonally
	for o in _obstacles:
		if o.intersects(Rect2(feet.x - 6, feet.y - 3, 12, 6)):
			return false
	return true


# what each station kind draws — used for both visuals and collision
const STATION_PROP := {
	"cockpit": ["helm", 84.0], "drive": ["reactor", 76.0],
	"board": ["console_wide", 64.0], "comms": ["monitors", 56.0],
	"workbench": ["workbench", 62.0], "exit": ["hatch", 58.0],
	"suit": ["locker", 28.0], "o2": ["pedestal", 26.0],
	"tether": ["pedestal", 26.0], "laser": ["pedestal", 26.0],
	"fabricator": ["fabricator", 54.0],
}


func _glow(pos: Vector2, col: Color, radius: float) -> void:
	## Dancing ambient light: the halo breathes, shimmers and sways a few
	## px around its prop, and casts a swaying pool on the floor below.
	var phase := pos.x * 0.7 + pos.y * 1.3
	var t := _reactor
	var a := 0.72 + 0.18 * sin(t * 1.8 + phase) + 0.10 * sin(t * 5.3 + phase * 2.0)
	if fmod(t * 0.9 + phase, 9.0) < 0.07:
		a *= 0.35   # rare electrical flicker
	var sway := Vector2(sin(t * 1.1 + phase) * 2.6, cos(t * 1.7 + phase * 0.7) * 1.8)
	var p := pos + sway
	_ci.draw_circle(p, radius * 0.45, Color(col.r, col.g, col.b, 0.11 * a))
	_ci.draw_circle(p, radius, Color(col.r, col.g, col.b, 0.06 * a))
	_ci.draw_circle(p, radius * 1.8, Color(col.r, col.g, col.b, 0.03 * a))
	# light pooled on the deck, counter-swaying — the "dance"
	_ci.draw_set_transform(pos + Vector2(-sway.x * 0.7, radius * 0.6), 0.0,
		Vector2(1.7, 0.5))
	_ci.draw_circle(Vector2.ZERO, radius * 0.7, Color(col.r, col.g, col.b, 0.045 * a))
	_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_obstacles() -> void:
	_obstacles = []
	for cell in GameState.rooms:
		var c := cell_rect(cell).get_center()
		var type: String = GameState.rooms[cell]
		for f in ROOM_PROPS.get(type, []):
			var tex: Texture2D = P[f[0]]
			var w: float = f[2]
			var h: float = w * tex.get_size().y / tex.get_size().x
			# sides stay near-full width (no slipping past when walking
			# vertically along a prop); only top/bottom shrink for depth
			_obstacles.append(Rect2(c + (f[1] as Vector2) - Vector2(w, h) * 0.5,
				Vector2(w, h)).grow_individual(-1.0, -w * 0.12, -1.0, -w * 0.12))
	for st in _stations:
		if not STATION_PROP.has(st["kind"]):
			continue
		var sp: Array = STATION_PROP[st["kind"]]
		var tex2: Texture2D = P[sp[0]]
		var w2: float = sp[1]
		var h2: float = w2 * tex2.get_size().y / tex2.get_size().x
		_obstacles.append(Rect2((st["pos"] as Vector2) - Vector2(w2, h2) * 0.5,
			Vector2(w2, h2)).grow_individual(-1.0, -w2 * 0.15, -1.0, -w2 * 0.15))
	# printed furniture — a slim base box at each piece's floor line, so the
	# crew walks BEHIND tall pieces but never through them (rugs stay walkable)
	for cell in GameState.furniture:
		for p in GameState.furniture_at(cell):
			var it: Dictionary = Craftables.ITEMS[p["id"]]
			if it.get("flat", false):
				continue
			var fw := _furn_w(int(it["size"]))
			_obstacles.append(Rect2(
				_furn_cx(cell, int(p["col"]), int(it["size"])) - fw * 0.5 + 1.0,
				_furn_base_y(cell, int(p["row"])) - 16.0, fw - 2.0, 14.0))


# ------------------------------------------------------------------
# Furniture geometry — each built room's floor is a FURN_COLS x FURN_ROWS
# placement grid (row 0 hugs the back wall, row 1 the front)
# ------------------------------------------------------------------
const FURN_MARGIN_X := 18.0


func _furn_slot_w() -> float:
	return (CELL_W - FURN_MARGIN_X * 2.0) / GameState.FURN_COLS


func _furn_w(size: int) -> float:
	return size * _furn_slot_w() - 6.0


func _furn_cx(cell: int, col: int, size: int) -> float:
	return cell_rect(cell).position.x + FURN_MARGIN_X + (col + size * 0.5) * _furn_slot_w()


func _furn_base_y(cell: int, row: int) -> float:
	## the piece's floor line (sprite bottom) for its depth row
	return cell_rect(cell).position.y + (66.0 if row == 0 else 122.0)


func _find_cell(type: String) -> int:
	for cell in GameState.rooms:
		if GameState.rooms[cell] == type:
			return cell
	return GameState.rooms.keys()[0] if GameState.rooms.size() > 0 else 0


# ------------------------------------------------------------------
var _overlay: Node2D


func _ready() -> void:
	# mipmapped filtering: hi-res prop art drawn small shimmers ("weird
	# pixelation") under plain linear minification
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_define_stations()

	# in-front-of-crew layer: added after Crew in the tree, so its draws
	# cover the crew — the depth passes decide what lands where
	_overlay = Node2D.new()
	_overlay.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)

	# dim the deck a touch so the prop lights carve real pools
	var cm := CanvasModulate.new()
	cm.color = Color(0.68, 0.72, 0.82)
	add_child(cm)
	_spawn_lights()

	crew.walk_check = _is_walkable

	GameState.refill_oxygen(GameState.max_oxygen)
	_build_hud()
	GameState.notify.connect(_on_notify)
	# printed furniture is solid — rebuild collision whenever it changes
	GameState.furniture_changed.connect(_build_obstacles)

	# boarding by ANY door ends the adrift opening — you're home now
	var was_adrift: bool = GameState.adrift
	GameState.adrift = false

	# a shift only ticks after real work (left the dock / flew / blacked
	# out) — walking in and out of the airlock, or loading a save, is free
	var radio := ""
	var ticked := false
	if GameState.pending_shift:
		GameState.pending_shift = false
		radio = GameState.begin_shift()
		ticked = true

	if GameState.wake_on_bunk:
		GameState.wake_on_bunk = false
		# beside the bunk — the bunk itself is solid now
		crew.position = cell_rect(_find_cell("quarters")).get_center() + Vector2(32, 10)
		if GameState.last_lost > 0:
			GameState.say("You black out... and wake in your bunk. The %d ore you carried is gone." %
				GameState.last_lost)
		elif was_adrift:
			GameState.say("You black out... and wake in your bunk. The suit's auto-return burned its last fuel getting you aboard.")
		else:
			GameState.say("You black out... and wake in your bunk. The lifeline reeled you home.")
		GameState.last_lost = 0
	else:
		crew.position = cell_rect(_find_cell("airlock")).get_center() + Vector2(-30, 0)
		if ticked:
			GameState.say("Shift %d. Board and market refreshed." % GameState.shift)
		elif was_adrift:
			GameState.say("Aboard. She's yours again, %s." % GameState.pilot_name())

	# never spawn inside furniture — nudge to the nearest open spot
	if not _is_walkable(crew.position):
		var home := cell_rect(cell_at(crew.position)).get_center()
		for off in [Vector2.ZERO, Vector2(26, 0), Vector2(-26, 0), Vector2(0, 26),
				Vector2(0, -26), Vector2(26, 26), Vector2(-26, 26)]:
			if _is_walkable(home + off):
				crew.position = home + off
				break

	if radio != "":
		await get_tree().create_timer(2.8).timeout
		if is_inside_tree():
			Sfx.play("radio", -12.0)
			GameState.say(radio)

	GameState.save_game()

	# debug: SW_MODAL=laser opens the upgrade modal at boot for screenshots
	if OS.get_environment("SW_MODAL") != "":
		crew.set_process(false)
		_upgrade_modal.open(OS.get_environment("SW_MODAL"))
	if OS.get_environment("SW_RENAME") != "":
		_open_rename()
	# SW_FAB=1 opens the fabricator catalogue; SW_FAB=<id> jumps straight
	# into placement with that object in hand
	var fab := OS.get_environment("SW_FAB")
	if fab != "":
		crew.set_process(false)
		if Craftables.ITEMS.has(fab):
			_debug_build_room()
			for sym in Craftables.ITEMS[fab]["cost"]:
				GameState.elements[sym] = maxi(int(GameState.elements.get(sym, 0)), 99)
			GameState.recipes_unlocked[fab] = true
			_begin_placement(fab)
		else:
			_fab_modal.open()
	# SW_FURN=1: pre-place a furnished room for screenshots
	if OS.get_environment("SW_FURN") != "":
		var rc := _debug_build_room()
		if rc >= 0:
			for sym in ["Fe", "C", "Al", "Cu", "Si", "Ar", "W"]:
				GameState.elements[sym] = maxi(int(GameState.elements.get(sym, 0)), 99)
			for pick in [["rug_round", 2, 1], ["bed_single", 0, 0], ["locker", 2, 0],
					["bookshelf", 3, 0], ["sofa", 0, 1], ["floor_lamp", 5, 0],
					["potted_plant", 4, 1]]:
				GameState.recipes_unlocked[pick[0]] = true
				GameState.place_furniture(rc, pick[0], pick[1], pick[2])


func _debug_build_room() -> int:
	## screenshots need a player-built room; force one next to the cluster
	for cell in GameState.rooms:
		if GameState.can_furnish_room(cell):
			return cell
	for cell in GameState.SHIP_COLS * GameState.SHIP_ROWS:
		if GameState.cell_in_hull(cell) and not GameState.rooms.has(cell):
			for n in GameState.cell_neighbors(cell):
				if GameState.rooms.has(n):
					GameState.rooms[cell] = "room"
					_define_stations()
					_spawn_lights()
					return cell
	return -1


func _define_stations() -> void:
	_stations = []
	for cell in GameState.rooms:
		var c := cell_rect(cell).get_center()
		match GameState.rooms[cell]:
			"upgrade":
				_stations.append({"pos": c + Vector2(-64, 30), "kind": "o2"})
				_stations.append({"pos": c + Vector2(-14, 30), "kind": "tether"})
				_stations.append({"pos": c + Vector2(38, 30), "kind": "laser"})
				_stations.append({"pos": c + Vector2(-22, -42), "kind": "suit"})
				_stations.append({"pos": c + Vector2(62, -40), "kind": "workbench"})
			"bridge":
				_stations.append({"pos": c + Vector2(-18, 28), "kind": "cockpit"})
				_stations.append({"pos": c + Vector2(-58, -38), "kind": "comms"})
			"airlock":
				_stations.append({"pos": c + Vector2(32, 16), "kind": "exit"})
			"engine":
				_stations.append({"pos": c + Vector2(0, -56), "kind": "drive"})
			"cargo":
				_stations.append({"pos": c + Vector2(-56, -44), "kind": "board"})
				_stations.append({"pos": c + Vector2(16, -46), "kind": "fabricator"})
	# expansion bays: for every built-room edge that faces bare hull, put an
	# expand prompt JUST INSIDE the built room at that edge — so you can
	# reach it from whichever room you're standing in (no dead corners).
	for cell in GameState.SHIP_COLS * GameState.SHIP_ROWS:
		if _built(cell) or not GameState.cell_in_hull(cell):
			continue
		for n in GameState.cell_neighbors(cell):
			if _built(n):
				var edge := (cell_rect(cell).get_center() + cell_rect(n).get_center()) * 0.5
				var inward := (cell_rect(n).get_center() - edge).normalized()
				_stations.append({"pos": edge + inward * 26.0, "kind": "expand", "cell": cell})
	_build_obstacles()


# all kit drawing goes through _ci so the same helpers can paint on the
# base canvas (behind the crew) or the overlay (in front of the crew)
var _ci: CanvasItem = self


func _prop(key: String, center: Vector2, width: float,
		tint := Color.WHITE, flip_h := false, flip_v := false) -> void:
	## Draw a kit prop centered at `center`, `width` px wide, aspect kept.
	var tex: Texture2D = P[key]
	var sz := tex.get_size()
	var h := width * sz.y / sz.x
	_ci.draw_set_transform(center, 0.0,
		Vector2(-1.0 if flip_h else 1.0, -1.0 if flip_v else 1.0))
	_ci.draw_texture_rect(tex, Rect2(-width * 0.5, -h * 0.5, width, h), false, tint)
	_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _prop_h(key: String, width: float) -> float:
	var sz: Vector2 = (P[key] as Texture2D).get_size()
	return width * sz.y / sz.x


func _prop_rect(key: String, rect: Rect2, tint := Color.WHITE,
		flip_h := false, flip_v := false) -> void:
	## Stretch a kit prop over an exact rect (floors, walls).
	_ci.draw_set_transform(rect.get_center(), 0.0,
		Vector2(-1.0 if flip_h else 1.0, -1.0 if flip_v else 1.0))
	_ci.draw_texture_rect(P[key], Rect2(-rect.size * 0.5, rect.size), false, tint)
	_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _prop_rot(key: String, center: Vector2, size: Vector2, rot: float,
		flip_v := false) -> void:
	## A kit prop centered and rotated — for wall junctions.
	_ci.draw_set_transform(center, rot, Vector2(1.0, -1.0 if flip_v else 1.0))
	_ci.draw_texture_rect(P[key], Rect2(-size * 0.5, size), false)
	_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tiled_wall_h(x0: float, x1: float, y: float, inside_s: bool) -> void:
	## A horizontal wall run tiled from the art's CLEAN MIDDLE band — no
	## baked end-caps repeating, segments join invisibly. Real ends are
	## dressed by the junction pieces.
	var tex: Texture2D = P["wall_h"]
	var ts := tex.get_size()
	var src := Rect2(ts.x * 0.28, 0, ts.x * 0.44, ts.y)
	var nat := 22.0 * src.size.x / ts.y   # slice length at 22px wall height
	var n := maxi(1, roundi((x1 - x0) / nat))
	var seg := (x1 - x0) / n
	var yc := y + (-3.0 if inside_s else 3.0)
	for i in n:
		draw_set_transform(Vector2(x0 + (i + 0.5) * seg, yc), 0.0,
			Vector2(1.0, 1.0 if inside_s else -1.0))
		draw_texture_rect_region(tex, Rect2(-seg * 0.5 - 0.25, -11, seg + 0.5, 22), src)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tiled_wall_v(y0: float, y1: float, x: float, inside_e: bool) -> void:
	## Vertical twin of _tiled_wall_h.
	var tex: Texture2D = P["wall_v"]
	var ts := tex.get_size()
	var src := Rect2(0, ts.y * 0.28, ts.x, ts.y * 0.44)
	var nat := 22.0 * src.size.y / ts.x
	var n := maxi(1, roundi((y1 - y0) / nat))
	var seg := (y1 - y0) / n
	var xc := x + (-3.0 if inside_e else 3.0)
	for i in n:
		draw_set_transform(Vector2(xc, y0 + (i + 0.5) * seg), 0.0,
			Vector2(1.0 if inside_e else -1.0, 1.0))
		draw_texture_rect_region(tex, Rect2(-11, -seg * 0.5 - 0.25, 22, seg + 0.5), src)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)




func _process(delta: float) -> void:
	_reactor += delta
	_animate_lights()
	if _ending_t > 0.0:
		_ending_t += delta
		if _ending_t > 8.0:
			GameState.in_game = false
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		queue_redraw()
		_overlay.queue_redraw()
		return
	if _placing_id != "":
		_update_placement()
	_update_active_station()
	var rn := _room_at(crew.position)
	# match the cell _open_rename() actually edits (the feet cell) so the hint
	# and the R action never disagree near a cell boundary
	if rn != "—" and GameState.can_rename_room(cell_at(crew.position + Vector2(0, 12))) \
			and not _rename_box.visible and _placing_id == "" \
			and not (_upgrade_modal != null and _upgrade_modal.visible) \
			and not (_fab_modal != null and _fab_modal.visible):
		rn += "      R  rename"
	_room_label.text = rn
	_banked_label.text = "BANKED ORE   %d" % GameState.banked
	if _active >= 0 and _placing_id == "" \
			and not (_fab_modal != null and _fab_modal.visible) \
			and not (_upgrade_modal != null and _upgrade_modal.visible):
		_prompt_label.set_prompt(_station_label(_stations[_active]))
		_prompt_label.modulate.a = 0.95
	else:
		_prompt_label.modulate.a = 0.0
	queue_redraw()
	_overlay.queue_redraw()


func _update_active_station() -> void:
	_active = -1
	var best := INTERACT_RADIUS
	for i in _stations.size():
		var d: float = crew.position.distance_to(_stations[i]["pos"])
		if d < best:
			best = d
			_active = i


func _station_label(st: Dictionary) -> String:
	match st["kind"]:
		"o2", "tether", "laser", "suit":
			var lbl: String = GameState.UPGRADES[st["kind"]]["label"]
			if GameState.gear_maxed(st["kind"]):
				return "%s — MAX (Lv %d)" % [lbl, GameState.MAX_GEAR_LEVEL]
			return "E    Upgrade %s   (Lv %d › %d)" % [lbl,
				GameState._level_of(st["kind"]), GameState._level_of(st["kind"]) + 1]
		"cockpit":
			return "E    Take the helm — explore space"
		"exit":
			return "E    Suit up & spacewalk"
		"expand":
			return "E    Expand the ship   (%d ore)" % int(GameState.ROOM_TYPES["room"]["cost"])
		"drive":
			if GameState.game_complete:
				if GameState.rescued_count() < GameState.RESCUES.size():
					return "DRIVE READY — %d OF THE SIX STILL OUT THERE. NOBODY GETS LEFT." % \
						(GameState.RESCUES.size() - GameState.rescued_count())
				return "E    ALL ABOARD — SET COURSE FOR HAVEN"
			var part: Dictionary = GameState.quest_part()
			if GameState.quest_can_install():
				return "E    Install the jump drive — %s" % part["name"]
			return "JUMP DRIVE · %s  —  %s" % [part["name"], GameState.quest_progress_text()]
		"board":
			var deliverable := GameState.contracts_ready()
			return "E    Deliver to the board   (%d ready)" % deliverable
		"comms":
			return "1-3    Buy from Vesna's market"
		"workbench":
			return "1-4    Craft at the workbench"
		"fabricator":
			return "E    Fabricator — print room objects"
	return ""


func _room_at(p: Vector2) -> String:
	var cell := cell_at(p)
	if _built(cell):
		return GameState.room_display_name(cell).to_upper()
	return "—"


func _unhandled_input(event: InputEvent) -> void:
	# fabricator placement mode owns ALL input while an object is in hand
	if _placing_id != "":
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_placement()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			_recycle_hovered()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_ESCAPE:
					_cancel_placement()
				KEY_E, KEY_ENTER, KEY_KP_ENTER:
					_confirm_placement()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# rename box open: Esc cancels it (Enter submits via the LineEdit)
	if _rename_box != null and _rename_box.visible:
		if event.physical_keycode == KEY_ESCAPE:
			_rename_box.visible = false
			_rename_edit.release_focus()
			crew.set_process(true)
			get_viewport().set_input_as_handled()
		return
	if _upgrade_modal != null and _upgrade_modal.visible:
		return   # the modal owns input while it's up
	if _fab_modal != null and _fab_modal.visible:
		return
	if _inventory != null and _inventory.visible:
		return   # no station/rename actions under the full-screen inventory
	# R renames the room you're standing in — no station needed
	if event.physical_keycode == KEY_R:
		_open_rename()
		get_viewport().set_input_as_handled()
		return
	if _active < 0:
		return
	var st: Dictionary = _stations[_active]
	if event.physical_keycode == KEY_E:
		_interact(st)
	elif st["kind"] == "comms" and event.physical_keycode in [KEY_1, KEY_2, KEY_3]:
		var i: int = event.physical_keycode - KEY_1
		if i < GameState.trader_stock.size():
			var offer: Dictionary = GameState.trader_stock[i]
			if GameState.buy_from_trader(i):
				Sfx.play("bank", -8.0)
				GameState.say("Bought 1 %s for %d ore. VESNA: Pleasure." % [
					Elements.name_of(offer["sym"]), offer["price"]])
			else:
				Sfx.play("deny", -12.0)
				GameState.say("VESNA: That's %d ore, friend. You have %d." % [
					offer["price"], GameState.banked])
	elif st["kind"] == "workbench" and event.physical_keycode in \
			[KEY_1, KEY_2, KEY_3, KEY_4]:
		var i: int = event.physical_keycode - KEY_1
		var r: Dictionary = GameState.RECIPES[i]
		if GameState.craft(i):
			Sfx.play("upgrade", -5.0)
			GameState.say("%s crafted — %s." % [r["name"], r["desc"]])
		else:
			Sfx.play("deny", -12.0)
			GameState.say("Can't craft %s — check materials." % r["name"])


func _interact(st: Dictionary) -> void:
	match st["kind"]:
		"drive":
			if GameState.game_complete:
				if GameState.rescued_count() < GameState.RESCUES.size():
					Sfx.play("deny", -8.0)
					GameState.say("The drive hums, ready. But %d beacon(s) still sing out there — nobody gets left behind." % \
						(GameState.RESCUES.size() - GameState.rescued_count()))
					return
				_ending_t = 0.001   # roll credits — all six, going home
				return
			var part: Dictionary = GameState.quest_part()
			if GameState.quest_install():
				Sfx.play("upgrade", -4.0)
				GameState.say("LOG: " + part["log"])
				if GameState.game_complete:
					GameState.say("THE JUMP DRIVE IS COMPLETE. Return to it when you're ready.")
			else:
				Sfx.play("deny", -10.0)
				GameState.say("Missing materials — %s" % GameState.quest_progress_text())
				# where to actually FIND them — mining can't drop everything
				if part.has("hint"):
					GameState.say(str(part["hint"]))
		"board":
			var n := GameState.deliver_contracts()
			if n > 0:
				Sfx.play("bank", -4.0)
				GameState.say("%d contract%s delivered. Reputation %d. VESNA: Word travels." % [
					n, "s" if n > 1 else "", GameState.reputation])
			else:
				Sfx.play("deny", -12.0)
				GameState.say("Nothing ready to deliver yet.")
		"expand":
			var cost: int = GameState.ROOM_TYPES["room"]["cost"]
			if GameState.build_room(st["cell"], "room"):
				Sfx.play("upgrade", -5.0)
				GameState.say("Hull section built out. What it becomes is up to you — later.")
				_define_stations()
				_spawn_lights()
			else:
				Sfx.play("deny", -10.0)
				GameState.say("Can't build — need %d ore (have %d)." % [cost, GameState.banked])
		"exit":
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		"cockpit":
			get_tree().change_scene_to_file("res://scenes/flight.tscn")
		"o2", "tether", "laser", "suit":
			# open the requirements modal instead of upgrading blind
			crew.set_process(false)
			_upgrade_modal.open(st["kind"])
		"fabricator":
			crew.set_process(false)
			_fab_modal.open()


# ==================================================================
# Fabricator placement — the printed object follows the mouse across
# the rooms YOU built, snapping into each room's floor grid
# ==================================================================
func _begin_placement(id: String) -> void:
	var any := false
	for cell in GameState.rooms:
		if GameState.can_furnish_room(cell):
			any = true
			break
	if not any:
		Sfx.play("deny", -12.0)
		GameState.say("The fabricator only prints for rooms YOU built — expand the hull first.")
		return
	_placing_id = id       # set BEFORE closing so the crew stays frozen
	_place_cell = -1
	_fab_modal.close()


func _update_placement() -> void:
	var m := get_global_mouse_position()
	var cell := cell_at(m)
	if not GameState.can_furnish_room(cell):
		_place_cell = -1
		_place_ok = false
		_hover_furn = -1
		return
	var it: Dictionary = Craftables.ITEMS[_placing_id]
	var size := int(it["size"])
	var r := cell_rect(cell)
	_place_cell = cell
	_place_col = clampi(int(floor((m.x - r.position.x - FURN_MARGIN_X) / _furn_slot_w()
		- (size - 1) * 0.5)), 0, GameState.FURN_COLS - size)
	_place_row = 0 if m.y < r.position.y + 94.0 else 1
	# wall pieces only hang on the back wall — snap the ghost there
	if it.get("back", false):
		_place_row = 0
	_place_ok = GameState.furniture_fits(cell, _placing_id, _place_col, _place_row) \
		and GameState.can_afford(it["cost"])
	# is an already-printed piece under the mouse? (right-click recycles it)
	_hover_furn = -1
	var mcol := int(floor((m.x - r.position.x - FURN_MARGIN_X) / _furn_slot_w()))
	var mrow := 0 if m.y < r.position.y + 94.0 else 1
	var list: Array = GameState.furniture_at(cell)
	for i in list.size():
		var pit: Dictionary = Craftables.ITEMS[list[i]["id"]]
		if int(list[i]["row"]) == mrow and mcol >= int(list[i]["col"]) \
				and mcol < int(list[i]["col"]) + int(pit["size"]):
			# prefer solid pieces over the rug beneath them
			if _hover_furn < 0 or not pit.get("flat", false):
				_hover_furn = i


func _confirm_placement() -> void:
	if _place_cell < 0 or not _place_ok:
		Sfx.play("deny", -12.0)
		return
	var id := _placing_id
	var it: Dictionary = Craftables.ITEMS[id]
	if GameState.place_furniture(_place_cell, id, _place_col, _place_row):
		Sfx.play("upgrade", -6.0)
		var w := _furn_w(int(it["size"]))
		var h: float = w * (it["tex"] as Texture2D).get_size().y \
			/ (it["tex"] as Texture2D).get_size().x
		Vfx.sparkle(self, Vector2(_furn_cx(_place_cell, _place_col, int(it["size"])),
			_furn_base_y(_place_cell, _place_row) - h * 0.5), Color(0.45, 0.9, 1.0))
		GameState.say("%s printed." % it["name"])
		_placing_id = ""
		_fab_modal.open()   # straight back to the catalogue
	else:
		Sfx.play("deny", -12.0)


func _cancel_placement() -> void:
	_placing_id = ""
	_fab_modal.open()


func _recycle_hovered() -> void:
	## right-click on a printed piece: un-print it, full material refund
	if _place_cell < 0 or _hover_furn < 0:
		Sfx.play("deny", -14.0)
		return
	var list: Array = GameState.furniture_at(_place_cell)
	if _hover_furn >= list.size():
		return
	var rid: String = list[_hover_furn]["id"]
	if GameState.remove_furniture(_place_cell, _hover_furn):
		Sfx.play("bank", -8.0)
		GameState.say("%s recycled — materials refunded." % Craftables.ITEMS[rid]["name"])
		_hover_furn = -1


func _draw_placement() -> void:
	## Placement overlay: every furnishable room shows its floor grid;
	## the object in hand ghosts at the snapped slot, green when it fits.
	var pulse := 0.5 + 0.5 * sin(_reactor * 3.0)
	for cell in GameState.rooms:
		if not GameState.can_furnish_room(cell):
			continue
		var r := cell_rect(cell)
		var hot: bool = cell == _place_cell
		# the room lights up as a build canvas — hot room glows brighter
		_ci.draw_rect(r.grow(-6.0), Color(0.35, 0.85, 1.0, 0.06 if hot else 0.03))
		_ci.draw_rect(r.grow(-6.0),
			Color(0.35, 0.85, 1.0, (0.7 if hot else 0.35) + 0.15 * pulse), false, 2.0)
		for row in GameState.FURN_ROWS:
			var by := _furn_base_y(cell, row)
			for col in GameState.FURN_COLS:
				var sx := r.position.x + FURN_MARGIN_X + col * _furn_slot_w()
				var sr := Rect2(sx + 1.0, by - 22.0, _furn_slot_w() - 2.0, 22.0)
				_ci.draw_rect(sr, Color(0.35, 0.85, 1.0, 0.07 if hot else 0.03))
				_ci.draw_rect(sr, Color(0.35, 0.85, 1.0,
					(0.55 if hot else 0.25) + 0.10 * pulse), false, 1.0)
	if _place_cell >= 0:
		var it: Dictionary = Craftables.ITEMS[_placing_id]
		var size := int(it["size"])
		var tex: Texture2D = it["tex"]
		var w := _furn_w(size)
		var h := w * tex.get_size().y / tex.get_size().x
		if it.get("flat", false):
			h *= 0.55
		var cx := _furn_cx(_place_cell, _place_col, size)
		var by2 := _furn_base_y(_place_cell, _place_row)
		var tint := Color(0.55, 1.0, 0.65, 0.72) if _place_ok else Color(1.0, 0.4, 0.35, 0.55)
		# claimed slots underline
		var ux := cell_rect(_place_cell).position.x + FURN_MARGIN_X \
			+ _place_col * _furn_slot_w()
		_ci.draw_rect(Rect2(ux + 1.0, by2 - 3.0, size * _furn_slot_w() - 2.0, 4.0),
			Color(tint.r, tint.g, tint.b, 0.8))
		_ci.draw_texture_rect(tex, Rect2(cx - w * 0.5, by2 - h, w, h), false, tint)
	# a printed piece under the mouse glows warm — right-click recycles it
	if _place_cell >= 0 and _hover_furn >= 0:
		var list: Array = GameState.furniture_at(_place_cell)
		if _hover_furn < list.size():
			var hp: Dictionary = list[_hover_furn]
			var hit: Dictionary = Craftables.ITEMS[hp["id"]]
			var hw := _furn_w(int(hit["size"]))
			var htex: Texture2D = hit["tex"]
			var hh: float = hw * htex.get_size().y / htex.get_size().x
			if hit.get("flat", false):
				hh *= 0.55
			_ci.draw_rect(Rect2(
				_furn_cx(_place_cell, int(hp["col"]), int(hit["size"])) - hw * 0.5 - 2.0,
				_furn_base_y(_place_cell, int(hp["row"])) - hh - 2.0,
				hw + 4.0, hh + 4.0), Color(1.0, 0.75, 0.3, 0.7), false, 1.5)
	# hint line under the cursor
	var m := get_global_mouse_position()
	var hint_txt := "MOVE TO A ROOM YOU BUILT      ESC  back"
	if _place_cell >= 0:
		hint_txt = "CLICK / E  print      ESC  back"
		if _hover_furn >= 0:
			hint_txt = "R-CLICK  recycle      CLICK / E  print      ESC  back"
	_ci.draw_string(_font, m + Vector2(-120, 26), hint_txt,
		HORIZONTAL_ALIGNMENT_CENTER, 280, 9, Color(0.8, 0.95, 1.0, 0.8))


# ==================================================================
# Interior HUD
# ==================================================================
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.make_theme()
	layer.add_child(root)
	_inventory = INVENTORY_SCREEN.new()
	# the inventory is a full-screen layer — never let it stack over a modal,
	# the rename box or fabricator placement
	_inventory.can_open = func() -> bool:
		return _placing_id == "" \
			and not (_upgrade_modal != null and _upgrade_modal.visible) \
			and not (_fab_modal != null and _fab_modal.visible) \
			and not (_rename_box != null and _rename_box.visible)
	root.add_child(_inventory)

	# gear upgrade modal — opens at a station, freezes the crew while up
	_upgrade_modal = UPGRADE_MODAL.new()
	root.add_child(_upgrade_modal)
	_upgrade_modal.closed.connect(func(): crew.set_process(true))
	_upgrade_modal.upgraded.connect(_on_upgraded)

	# fabricator catalogue — choosing an object drops into placement mode
	_fab_modal = FABRICATOR_MODAL.new()
	root.add_child(_fab_modal)
	_fab_modal.closed.connect(func(): if _placing_id == "": crew.set_process(true))
	_fab_modal.craft_chosen.connect(_begin_placement)

	# room-rename box — a clear titled panel, hidden until you press R
	_rename_box = PanelContainer.new()
	_rename_box.visible = false
	_rename_box.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_rename_box)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	_rename_box.add_child(rv)
	var rt := Label.new()
	rt.text = "RENAME ROOM"
	rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rt.add_theme_font_size_override("font_size", 14)
	rt.modulate = UITheme.ACCENT
	rv.add_child(rt)
	_rename_edit = LineEdit.new()
	_rename_edit.placeholder_text = "name this room…"
	_rename_edit.max_length = 20
	_rename_edit.custom_minimum_size = Vector2(280, 38)
	_rename_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(_rename_edit)
	var rhint := Label.new()
	rhint.text = "Enter to save   ·   Esc to cancel"
	rhint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rhint.add_theme_font_size_override("font_size", 10)
	rhint.modulate = Color(1, 1, 1, 0.5)
	rv.add_child(rhint)
	_rename_box.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_rename_edit.text_submitted.connect(_on_rename_submitted)
	# a focused LineEdit eats the first Esc (releases focus) before our
	# _unhandled_input sees it — catch it here so ONE Esc always cancels
	_rename_edit.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventKey and ev.pressed \
				and ev.physical_keycode == KEY_ESCAPE:
			_rename_box.visible = false
			_rename_edit.release_focus()
			crew.set_process(true)
			get_viewport().set_input_as_handled())

	var info := PanelContainer.new()
	info.position = Vector2(18, 18)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info)
	_banked_label = Label.new()
	info.add_child(_banked_label)

	var gear := GEAR_PANEL.new()
	root.add_child(gear)
	gear.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	UITheme.shrink(gear, true, true)

	_room_label = Label.new()
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.modulate = Color(0.55, 0.9, 1.0, 0.55)
	root.add_child(_room_label)
	_room_label.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 16)

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
	hint.items = Keymap.hint("interior")
	root.add_child(hint)


func _on_notify(text: String) -> void:
	_msg_label.text = text
	if _msg_tween:
		_msg_tween.kill()
	_msg_label.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(2.2)
	_msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.8)


func _on_upgraded(kind: String) -> void:
	Sfx.play("upgrade", -5.0)
	match kind:
		"o2":
			GameState.say("O2 tank upgraded — capacity now %d." % int(GameState.max_oxygen))
		"tether":
			GameState.say("Lifeline extended — reach now %dm." % int(GameState.tether_length))
		"laser":
			GameState.say("Laser tuned — power now %d." % int(GameState.laser_dps))
		"suit":
			GameState.say("Ore bag reinforced — holds %d ore per walk now." %
				GameState.ore_max())


func _open_rename() -> void:
	var cell := cell_at(crew.position + Vector2(0, 12))
	if not _built(cell):
		return
	if not GameState.can_rename_room(cell):
		GameState.say("Core rooms keep their names — only rooms you built can be renamed.")
		return
	_rename_edit.set_meta("cell", cell)
	_rename_edit.text = GameState.room_display_name(cell)
	_rename_box.visible = true
	_rename_edit.grab_focus()
	_rename_edit.select_all()
	crew.set_process(false)


func _on_rename_submitted(text: String) -> void:
	var cell: int = _rename_edit.get_meta("cell", -1)
	if cell >= 0:
		GameState.rename_room(cell, text)
		Sfx.play("bank", -10.0)
		GameState.say("Room renamed “%s”." % GameState.room_display_name(cell))
	_rename_box.visible = false
	_rename_edit.release_focus()
	crew.set_process(true)


# ==================================================================
# Visuals — hull silhouette, grid, rooms, walls, doors, stations
# ==================================================================
func _draw() -> void:
	_ci = self
	var total := GameState.SHIP_COLS * GameState.SHIP_ROWS
	# hull silhouette backdrop (grown dark plates under everything)
	for cell in total:
		if GameState.cell_in_hull(cell):
			draw_rect(cell_rect(cell).grow(10.0), Color(0.055, 0.065, 0.09), true)
	# bare hull cells: dark overlay + the visible build grid
	for cell in total:
		if not GameState.cell_in_hull(cell) or _built(cell):
			continue
		var r := cell_rect(cell)
		draw_rect(r, Color(0.045, 0.055, 0.08), true)
		# grid lines
		draw_rect(r, Color(0.55, 0.9, 1.0, 0.07), false, 1.0)
		draw_line(r.position + Vector2(CELL_W * 0.5, 4), r.position + Vector2(CELL_W * 0.5, CELL_H - 4),
			Color(0.55, 0.9, 1.0, 0.035), 1.0)
		draw_line(r.position + Vector2(4, CELL_H * 0.5), r.position + Vector2(CELL_W - 4, CELL_H * 0.5),
			Color(0.55, 0.9, 1.0, 0.035), 1.0)
		# structural cross-brace
		draw_line(r.position + Vector2(8, 8), r.end - Vector2(8, 8), Color(1, 1, 1, 0.02), 1.0)
		draw_line(Vector2(r.end.x - 8, r.position.y + 8), Vector2(r.position.x + 8, r.end.y - 8),
			Color(1, 1, 1, 0.02), 1.0)
	# built rooms
	for cell in GameState.rooms:
		_draw_room_cell(cell)
	# hull outer walls: the kit's plated wall runs along every space edge.
	# Two passes — straights first, then corner caps over the seams.
	var wall_sides := {}   # cell -> {top/bottom/left/right: bool}
	for cell in total:
		if not GameState.cell_in_hull(cell):
			continue
		var col := cell % GameState.SHIP_COLS
		var row := int(float(cell) / GameState.SHIP_COLS)
		var flags := {}
		for e in [["left", Vector2(col - 1, row)], ["right", Vector2(col + 1, row)],
				["top", Vector2(col, row - 1)], ["bottom", Vector2(col, row + 1)]]:
			var np: Vector2 = e[1]
			var outside := np.x < 0 or np.y < 0 or np.x >= GameState.SHIP_COLS \
				or np.y >= GameState.SHIP_ROWS \
				or not GameState.cell_in_hull(int(np.y) * GameState.SHIP_COLS + int(np.x))
			if not outside:
				# interior boundary: a built room walls off bare hull space
				var ncell := int(np.y) * GameState.SHIP_COLS + int(np.x)
				if _built(cell) and not _built(ncell):
					outside = true
			flags[e[0]] = outside
		wall_sides[cell] = flags
	# --- edge graph: every wall edge knows which side the floor is on ---
	var cols := GameState.SHIP_COLS
	var rows := GameState.SHIP_ROWS
	var hedges := {}   # Vector2i(col, rowline) -> floor is SOUTH of the line
	var vedges := {}   # Vector2i(colline, row) -> floor is EAST of the line
	for cell in wall_sides:
		var f: Dictionary = wall_sides[cell]
		var ccol: int = int(cell) % cols
		var crow: int = int(float(cell) / cols)
		if f["top"]:
			hedges[Vector2i(ccol, crow)] = true
		if f["bottom"]:
			hedges[Vector2i(ccol, crow + 1)] = false
		if f["left"]:
			vedges[Vector2i(ccol, crow)] = true
		if f["right"]:
			vedges[Vector2i(ccol + 1, crow)] = false
	# --- classify every grid point FIRST: inner elbows get no cap at all —
	# their two wall runs extend through the joint and overlap instead ---
	var elbows := {}     # Vector2i point -> true (run ends extend +14 here)
	var tees: Array = [] # [point Vector2i, missing arm "n/s/e/w"]
	var crosses: Array = []
	var lcorners: Array = []  # [point, harm_e, varm_s]
	for cy in rows + 1:
		for cx in cols + 1:
			var aw := hedges.has(Vector2i(cx - 1, cy))
			var ae := hedges.has(Vector2i(cx, cy))
			var an := vedges.has(Vector2i(cx, cy - 1))
			var asx := vedges.has(Vector2i(cx, cy))
			var cnt := int(aw) + int(ae) + int(an) + int(asx)
			if cnt < 2 or (cnt == 2 and ((aw and ae) or (an and asx))):
				continue
			var k := Vector2i(cx, cy)
			if cnt == 4:
				crosses.append(k)
			elif cnt == 3:
				tees.append([k, "n" if not an else ("s" if not asx else ("e" if not ae else "w"))])
			else:
				var harm_e := ae
				var varm_s := asx
				var inside_s2: bool = hedges[Vector2i(cx if harm_e else cx - 1, cy)]
				if inside_s2 == varm_s:
					lcorners.append([k, harm_e, varm_s])
				else:
					elbows[k] = {"he": harm_e, "vs": varm_s}
	# --- straight walls as merged RUNS: one stretched piece, no seams.
	# Ends meeting an inner elbow push 14px through so the walls butt
	# together — the joint is made of real wall art, no caps. ---
	for ry in rows + 1:
		var cx := 0
		while cx < cols:
			if hedges.has(Vector2i(cx, ry)):
				var inside_s: bool = hedges[Vector2i(cx, ry)]
				var cx2 := cx
				while cx2 + 1 < cols and hedges.has(Vector2i(cx2 + 1, ry)) \
						and hedges[Vector2i(cx2 + 1, ry)] == inside_s:
					cx2 += 1
				var y0 := ORIGIN.y + ry * CELL_H
				# at elbows, extend exactly to the crossing wall's far face
				var ext_l := 4.0
				if elbows.has(Vector2i(cx, ry)):
					var vk := Vector2i(cx, ry) if vedges.has(Vector2i(cx, ry)) else Vector2i(cx, ry - 1)
					ext_l = 14.0 if vedges[vk] else 8.0
				var ext_r := 4.0
				if elbows.has(Vector2i(cx2 + 1, ry)):
					var vk2 := Vector2i(cx2 + 1, ry) if vedges.has(Vector2i(cx2 + 1, ry)) else Vector2i(cx2 + 1, ry - 1)
					ext_r = 8.0 if vedges[vk2] else 14.0
				_tiled_wall_h(ORIGIN.x + cx * CELL_W - ext_l,
					ORIGIN.x + (cx2 + 1) * CELL_W + ext_r, y0, inside_s)
				cx = cx2 + 1
			else:
				cx += 1
	for rx in cols + 1:
		var cy := 0
		while cy < rows:
			if vedges.has(Vector2i(rx, cy)):
				var inside_e: bool = vedges[Vector2i(rx, cy)]
				var cy2 := cy
				while cy2 + 1 < rows and vedges.has(Vector2i(rx, cy2 + 1)) \
						and vedges[Vector2i(rx, cy2 + 1)] == inside_e:
					cy2 += 1
				var x0 := ORIGIN.x + rx * CELL_W
				var ext_t := 4.0
				if elbows.has(Vector2i(rx, cy)):
					var hk := Vector2i(rx, cy) if hedges.has(Vector2i(rx, cy)) else Vector2i(rx - 1, cy)
					ext_t = 14.0 if hedges[hk] else 8.0
				var ext_b := 4.0
				if elbows.has(Vector2i(rx, cy2 + 1)):
					var hk2 := Vector2i(rx, cy2 + 1) if hedges.has(Vector2i(rx, cy2 + 1)) else Vector2i(rx - 1, cy2 + 1)
					ext_b = 8.0 if hedges[hk2] else 14.0
				_tiled_wall_v(ORIGIN.y + cy * CELL_H - ext_t,
					ORIGIN.y + (cy2 + 1) * CELL_H + ext_b, x0, inside_e)
				cy = cy2 + 1
			else:
				cy += 1
	# --- caps: X, T (bar aligned to the through-wall's centerline), L ---
	for k in crosses:
		_prop_rot("wall_x", Vector2(ORIGIN.x + k.x * CELL_W, ORIGIN.y + k.y * CELL_H),
			Vector2(44, 44), 0.0)
	for t in tees:
		var k: Vector2i = t[0]
		var pt := Vector2(ORIGIN.x + k.x * CELL_W, ORIGIN.y + k.y * CELL_H)
		# native piece: bar E-W (bar center 10px above piece center), stem S.
		# The through-wall's centerline sits 3px toward its trim side.
		match t[1]:
			"n":   # bar E-W, stem S — horizontal wall runs through
				var off_s: float = -3.0 if hedges[Vector2i(k.x if hedges.has(Vector2i(k.x, k.y)) else k.x - 1, k.y)] else 3.0
				_prop_rot("wall_t", pt + Vector2(0, off_s + 10.0), Vector2(46, 40), 0.0)
			"s":   # stem N (flip_v: bar center 10px BELOW piece center)
				var off_n: float = -3.0 if hedges[Vector2i(k.x if hedges.has(Vector2i(k.x, k.y)) else k.x - 1, k.y)] else 3.0
				_prop_rot("wall_t", pt + Vector2(0, off_n - 10.0), Vector2(46, 40), 0.0, true)
			"w":   # bar N-S, stem E (rot -90: bar center 10px LEFT of center)
				var off_e: float = -3.0 if vedges[Vector2i(k.x, k.y if vedges.has(Vector2i(k.x, k.y)) else k.y - 1)] else 3.0
				_prop_rot("wall_t", pt + Vector2(off_e + 10.0, 0), Vector2(46, 40), -PI * 0.5)
			"e":   # bar N-S, stem W (rot +90: bar center 10px RIGHT of center)
				var off_w: float = -3.0 if vedges[Vector2i(k.x, k.y if vedges.has(Vector2i(k.x, k.y)) else k.y - 1)] else 3.0
				_prop_rot("wall_t", pt + Vector2(off_w - 10.0, 0), Vector2(46, 40), PI * 0.5)
	for lc in lcorners:
		var k2: Vector2i = lc[0]
		var pt2 := Vector2(ORIGIN.x + k2.x * CELL_W, ORIGIN.y + k2.y * CELL_H)
		var harm_e2: bool = lc[1]
		var varm_s2: bool = lc[2]
		if harm_e2 and varm_s2:
			_prop_rect("wall_ctl", Rect2(pt2.x - 14, pt2.y - 14, 48, 42))
		elif not harm_e2 and varm_s2:
			_prop_rect("wall_ctr", Rect2(pt2.x - 34, pt2.y - 14, 48, 42))
		elif harm_e2:
			_prop_rect("wall_ctl", Rect2(pt2.x - 14, pt2.y - 28, 48, 42),
				Color.WHITE, false, true)
		else:
			_prop_rect("wall_ctr", Rect2(pt2.x - 34, pt2.y - 28, 48, 42),
				Color.WHITE, false, true)
	# inner elbows: the kit's native L-brackets (sheet 4, all four
	# orientations) bolt over the joint where the wall runs meet
	for k3 in elbows:
		var e: Dictionary = elbows[k3]
		var pt3 := Vector2(ORIGIN.x + k3.x * CELL_W, ORIGIN.y + k3.y * CELL_H)
		var vk3 := Vector2i(k3.x, k3.y) if vedges.has(Vector2i(k3.x, k3.y)) \
			else Vector2i(k3.x, k3.y - 1)
		var hk3 := Vector2i(k3.x, k3.y) if hedges.has(Vector2i(k3.x, k3.y)) \
			else Vector2i(k3.x - 1, k3.y)
		# where the two wall centerlines actually cross
		var cross := pt3 + Vector2(-3.0 if vedges[vk3] else 3.0,
			-3.0 if hedges[hk3] else 3.0)
		var bw := 44.0
		var bh := 28.0
		if e["he"] and e["vs"]:
			_prop_rect("elb_es", Rect2(cross.x - 9, cross.y - 9, bw, bh))
		elif not e["he"] and e["vs"]:
			_prop_rect("elb_ws", Rect2(cross.x + 9 - bw, cross.y - 9, bw, bh))
		elif e["he"]:
			_prop_rect("elb_en", Rect2(cross.x - 9, cross.y + 9 - bh, bw, bh))
		else:
			_prop_rect("elb_wn", Rect2(cross.x + 9 - bw, cross.y + 9 - bh, bw, bh))
	# a viewport window on the quarters' top hull wall — stars behind glass
	var qr := cell_rect(_find_cell("quarters"))
	var win_pos := Vector2(qr.get_center().x + 38.0, qr.position.y - 3)
	_prop("window", win_pos, 66.0)
	_glow(win_pos + Vector2(0, 10), (GLOWS["window"][0] as Color), GLOWS["window"][1])
	# doorway thresholds between built neighbours
	for cell in GameState.rooms:
		for n in GameState.cell_neighbors(cell):
			if n > cell and _built(n):
				var mid := (cell_rect(cell).get_center() + cell_rect(n).get_center()) * 0.5
				var horizontal := absi(n - cell) == 1
				# left/right neighbours share a VERTICAL edge — rotate the bar
				draw_set_transform(mid, PI * 0.5 if horizontal else 0.0, Vector2.ONE)
				draw_texture_rect(P["door_bar"], Rect2(-28, -7, 56, 14), false,
					Color(1, 1, 1, 0.9))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_expansions()
	_draw_depth(true)   # props behind the crew; the rest go to _overlay


func _draw_ending() -> void:
	## Camera sits on the crew; paint the whole view. Fade to black,
	## then the words you crossed a galaxy for.
	var center: Vector2 = crew.position
	var rect := Rect2(center - Vector2(660, 380), Vector2(1320, 760))
	var fade := clampf(_ending_t / 2.5, 0.0, 1.0)
	_ci.draw_rect(rect, Color(0, 0.01, 0.02, fade), true)
	if _ending_t > 2.5:
		var a := clampf((_ending_t - 2.5) / 1.5, 0.0, 1.0)
		_ci.draw_string(_font, center + Vector2(-400, -20), "HAVEN",
			HORIZONTAL_ALIGNMENT_CENTER, 800, 42,
			Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, a))
	if _ending_t > 4.2:
		var a2 := clampf((_ending_t - 4.2) / 1.5, 0.0, 1.0)
		_ci.draw_string(_font, center + Vector2(-400, 24),
			"Shift %d. %d elements drawn from the dark. Six souls aboard.\nHELIOS never learned to look here, %s. This is Haven. Begin again." % [
				GameState.shift, GameState.discovered.size(), GameState.pilot_name()],
			HORIZONTAL_ALIGNMENT_CENTER, 800, 16, Color(1, 1, 1, a2))


func _draw_room_cell(cell: int) -> void:
	var rect := cell_rect(cell)
	var type: String = GameState.rooms[cell]
	# the kit's floor tiles, 2x2 per cell — each room type has its own deck.
	# Lifted a touch so rooms read warm against the dark hull.
	var fkey: String = ROOM_FLOOR.get(type, "fl_plain")
	for ty in 2:
		for tx in 2:
			_prop_rect(fkey, Rect2(rect.position.x + tx * CELL_W * 0.5,
				rect.position.y + ty * CELL_H * 0.5, CELL_W * 0.5, CELL_H * 0.5),
				Color(1.34, 1.34, 1.28))
	# gentle top shadow + soft room light
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6)), Color(0, 0, 0, 0.22))
	draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.42,
		Color(0.85, 0.92, 1.0, 0.05))
	# (furniture draws in the depth passes — see _draw_depth)
	# name plate bottom-left, where no prop or station covers it
	draw_string(_font, rect.position + Vector2(8, CELL_H - 8),
		GameState.room_display_name(cell).to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.9, 1.0, 0.6))


# ------------------------------------------------------------------
# Real 2D lights: the canvas is dimmed a touch and every glowing prop
# carries a PointLight2D — so the light actually falls on the crew and
# neighbouring props, dancing with the same rhythm as the halos.
# ------------------------------------------------------------------
var _lights: Array = []   # [node, base_pos, phase, base_energy]
var _light_tex: GradientTexture2D


func _spawn_lights() -> void:
	for l in _lights:
		(l[0] as PointLight2D).queue_free()
	_lights = []
	if _light_tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		_light_tex = GradientTexture2D.new()
		_light_tex.gradient = grad
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(0.5, 0.0)
		_light_tex.width = 256
		_light_tex.height = 256
	for cell in GameState.rooms:
		var c := cell_rect(cell).get_center()
		for f in ROOM_PROPS.get(GameState.rooms[cell], []):
			if GLOWS.has(f[0]):
				_add_light(c + (f[1] as Vector2), GLOWS[f[0]][0], GLOWS[f[0]][1])
	for st in _stations:
		if STATION_PROP.has(st["kind"]):
			var gk: String = STATION_PROP[st["kind"]][0]
			if GLOWS.has(gk):
				_add_light(st["pos"], (GLOWS[gk][0] as Color), GLOWS[gk][1])
	# the quarters viewport spills starlight
	var qr := cell_rect(_find_cell("quarters"))
	_add_light(Vector2(qr.get_center().x + 38.0, qr.position.y + 8.0),
		(GLOWS["window"][0] as Color), GLOWS["window"][1])


func _add_light(pos: Vector2, col: Color, glow_r: float) -> void:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.position = pos
	l.color = col
	l.energy = 0.0
	l.texture_scale = glow_r * 6.0 / 256.0
	add_child(l)
	_lights.append([l, pos, pos.x * 0.7 + pos.y * 1.3,
		clampf(glow_r / 34.0, 0.5, 1.4)])


func _animate_lights() -> void:
	var t := _reactor
	for l in _lights:
		var lt: PointLight2D = l[0]
		var ph: float = l[2]
		var a := 0.72 + 0.18 * sin(t * 1.8 + ph) + 0.10 * sin(t * 5.3 + ph * 2.0)
		if fmod(t * 0.9 + ph, 9.0) < 0.07:
			a *= 0.35   # rare electrical flicker
		lt.energy = (l[3] as float) * a
		lt.position = (l[1] as Vector2) \
			+ Vector2(sin(t * 1.1 + ph) * 3.0, cos(t * 1.7 + ph * 0.7) * 2.0)


func _feet_y() -> float:
	return crew.position.y + 12.0


func _draw_depth(behind: bool) -> void:
	## One of the two depth passes: props whose base sits at or above the
	## crew's feet draw BEHIND (base canvas); the rest draw on the overlay,
	## in front of the crew. Recomputed every frame as the crew walks.
	var fy := _feet_y()
	for cell in GameState.rooms:
		var type: String = GameState.rooms[cell]
		var c := cell_rect(cell).get_center()
		for f in ROOM_PROPS.get(type, []):
			var pos: Vector2 = c + (f[1] as Vector2)
			# depth line = the COLLISION bottom (obstacle shrink + foot box),
			# so "standing at its face" and "in front of it" always agree
			var base_y: float = pos.y + _prop_h(f[0], f[2]) * 0.5 \
				- (f[2] as float) * 0.12 - 4.0
			if (base_y <= fy) == behind:
				_prop(f[0], pos, f[2])
				if GLOWS.has(f[0]):
					_glow(pos, (GLOWS[f[0]][0] as Color), GLOWS[f[0]][1])
	# printed furniture — flats (rugs) first so they sit under everything,
	# then solids by the same feet-line depth rule as the fixed props
	if behind:
		_draw_furniture(fy, true, true)
	_draw_furniture(fy, behind, false)
	for i in _stations.size():
		var st: Dictionary = _stations[i]
		if st["kind"] == "expand":
			continue
		var sp: Array = STATION_PROP[st["kind"]]
		var base_y2: float = (st["pos"] as Vector2).y + _prop_h(sp[0], sp[1]) * 0.5 \
			- (sp[1] as float) * 0.15 - 4.0
		if (base_y2 <= fy) == behind:
			_draw_station_visual(st, i == _active)
	# the found — your crew, living aboard
	for nname in NPC_SPOTS:
		if not GameState.rescued.has(nname):
			continue
		var spot: Array = NPC_SPOTS[nname]
		var home := _find_cell(spot[0])
		var npos: Vector2 = cell_rect(home).get_center() + (spot[1] as Vector2)
		if (npos.y + 16.0 <= fy) == behind:
			_draw_npc(nname, npos, spot[2])


func _draw_furniture(fy: float, behind: bool, flats: bool) -> void:
	## One furniture sub-pass. Flats (rugs) always land in the behind pass,
	## drawn before solids; solids split across the feet line like props.
	for cell in GameState.furniture:
		for p in GameState.furniture_at(cell):
			var it: Dictionary = Craftables.ITEMS[p["id"]]
			if bool(it.get("flat", false)) != flats:
				continue
			var base_y := _furn_base_y(cell, int(p["row"]))
			if not flats and (base_y - 4.0 <= fy) != behind:
				continue
			var tex: Texture2D = it["tex"]
			var w := _furn_w(int(it["size"]))
			var h := w * tex.get_size().y / tex.get_size().x
			var cx := _furn_cx(cell, int(p["col"]), int(it["size"]))
			if flats:
				# floor mats lie down: squash to a floor-projected ellipse look
				h *= 0.55
			_ci.draw_texture_rect(tex, Rect2(cx - w * 0.5, base_y - h, w, h), false)


func _draw_npc(nname: String, pos: Vector2, tint: Color) -> void:
	var tex: Texture2D = P["crew_npc"]
	var s := 34.0 / tex.get_size().y
	var phase := pos.x * 0.31
	var bob := sin(_reactor * 1.5 + phase) * 1.4
	_ci.draw_set_transform(pos + Vector2(0, 12), 0.0, Vector2(1.0, 0.42))
	_ci.draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.25))
	_ci.draw_set_transform(pos + Vector2(0, bob), 0.0,
		Vector2(-s if sin(_reactor * 0.23 + phase) > 0.0 else s, s))
	_ci.draw_texture(tex, -tex.get_size() * 0.5, tint)
	_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ci.draw_string(_font, pos + Vector2(-40, -26), nname,
		HORIZONTAL_ALIGNMENT_CENTER, 80, 9, Color(0.55, 0.9, 1.0, 0.5))


func _draw_expansions() -> void:
	## Expansion bay markers + holo previews — always floor-level.
	for i in _stations.size():
		var st: Dictionary = _stations[i]
		if st["kind"] != "expand":
			continue
		var p: Vector2 = st["pos"]
		var on := (i == _active)
		var pulse := 0.5 + 0.5 * sin(_reactor * 2.2)
		var target := cell_rect(st["cell"])
		draw_circle(p, 9.0, Color(0.55, 0.9, 1.0, 0.10 + 0.10 * pulse))
		draw_string(_font, p + Vector2(-14, 5), "+", HORIZONTAL_ALIGNMENT_CENTER,
			28, 17, Color(0.55, 0.9, 1.0, 0.45 + 0.4 * pulse))
		if on:
			var afford: bool = GameState.banked >= int(GameState.ROOM_TYPES["room"]["cost"])
			_prop_rect("cell_ok" if afford else "cell_no", target.grow(-8.0),
				Color(1, 1, 1, 0.55 + 0.3 * pulse))


func _draw_station_visual(st: Dictionary, on: bool) -> void:
	var p: Vector2 = st["pos"]
	match st["kind"]:
		"exit":
			# the airlock hatch — the wheel you spin to step outside
			_prop("hatch", p, 58.0)
			if on:
				_ci.draw_arc(p, 34.0, 0.0, TAU, 32, Color(0.35, 0.8, 1.0, 0.7), 2.0)
		"cockpit":
			_prop("helm", p, 84.0)
			if on:
				_ci.draw_circle(p, 40.0, Color(0.35, 0.8, 1.0, 0.10))
				_ci.draw_arc(p, 48.0, 0.0, TAU, 32, Color(0.35, 0.8, 1.0, 0.8), 2.0)
		"drive":
			# the jump drive — the kit's reactor, waking up per installed part
			var stage := GameState.quest_stage
			var pulse2 := 0.5 + 0.5 * sin(_reactor * (1.0 + stage))
			var warmth := 0.55 + 0.09 * float(stage)   # dim until it lives
			_prop("reactor", p, 76.0, Color(warmth, warmth, warmth + 0.05))
			for s2 in 5:
				var lit := s2 < stage
				_ci.draw_rect(Rect2(p.x - 17 + s2 * 7, p.y + 36, 5, 7),
					Color(0.7, 0.5, 1.0, 0.5 + 0.5 * pulse2) if lit else Color(1, 1, 1, 0.14))
			if GameState.game_complete:
				_ci.draw_circle(p, 46.0, Color(0.7, 0.5, 1.0, 0.10 + 0.08 * pulse2))
			if on:
				_ci.draw_arc(p, 44.0, 0.0, TAU, 32, Color(0.7, 0.5, 1.0, 0.6), 2.0)
		"board":
			_prop("console_wide", p, 64.0)
			# ready-contract lights along the console top
			for li in 3:
				var cready: bool = li < GameState.contracts.size() and \
					int(GameState.elements.get(GameState.contracts[li]["sym"], 0)) >= \
					int(GameState.contracts[li]["qty"])
				_ci.draw_circle(Vector2(p.x - 13 + li * 13, p.y - 24), 2.6,
					Color(0.4, 1.0, 0.5, 0.9) if cready else Color(1, 1, 1, 0.2))
			if on:
				_ci.draw_arc(p, 38.0, 0.0, TAU, 32, Color(0.55, 0.9, 1.0, 0.6), 2.0)
		"comms":
			var pulse3 := 0.5 + 0.5 * sin(_reactor * 2.5)
			_prop("monitors", p, 56.0)
			_ci.draw_circle(p + Vector2(0, -24), 2.5, Color(1.0, 0.75, 0.3, 0.4 + 0.5 * pulse3))
			if on:
				_ci.draw_arc(p, 34.0, 0.0, TAU, 32, Color(1.0, 0.75, 0.3, 0.6), 2.0)
		"workbench":
			_prop("workbench", p, 62.0)
			if on:
				_ci.draw_arc(p, 36.0, 0.0, TAU, 32, Color(0.5, 1.0, 0.6, 0.6), 2.0)
		"fabricator":
			_prop("fabricator", p, 54.0)
			# the print head's working shimmer — a live machine, not a prop
			var fp := 0.5 + 0.5 * sin(_reactor * 3.1)
			_ci.draw_rect(Rect2(p.x - 11, p.y - 2 - fp * 3.0, 22, 1.6),
				Color(0.45, 0.9, 1.0, 0.25 + 0.35 * fp))
			if on:
				_ci.draw_arc(p, 34.0, 0.0, TAU, 32, Color(0.35, 0.85, 1.0, 0.7), 2.0)
		_:
			# the upgrade consoles: kit pedestal, tinted per system
			var tint := Color.WHITE
			match st["kind"]:
				"o2": tint = Color(0.75, 1.0, 1.1)
				"tether": tint = Color(1.15, 1.0, 0.7)
				"laser": tint = Color(1.2, 0.8, 0.75)
			if st["kind"] == "suit":
				_prop("locker", p, 28.0)
			else:
				_prop("pedestal", p, 26.0, tint)
			if on:
				_ci.draw_circle(p, 28.0, Color(0.35, 0.8, 1.0, 0.08))
				_ci.draw_arc(p, 25.0, 0.0, TAU, 24, Color(0.35, 0.8, 1.0, 0.7), 1.5)
	# ambient light halo in front of every lit station prop
	var gk: String = STATION_PROP[st["kind"]][0]
	if GLOWS.has(gk):
		_glow(p, (GLOWS[gk][0] as Color), GLOWS[gk][1])


func _draw_overlay() -> void:
	## Everything that must render IN FRONT of the crew: props below the
	## feet line, the active station's info panel, and the ending fade.
	_ci = _overlay
	_draw_depth(false)
	if _placing_id != "":
		_draw_placement()
	if _active >= 0 and _placing_id == "":
		var st: Dictionary = _stations[_active]
		match st["kind"]:
			"board":
				_draw_board_panel(st)
			"comms":
				_draw_comms_panel(st)
			"workbench":
				_draw_workbench_panel(st)
	if _ending_t > 0.0:
		_draw_ending()
	_ci = self


func _menu_panel(p: Vector2, w: float, h: float) -> Rect2:
	var rect := Rect2(p + Vector2(-w * 0.5, -h - 26.0), Vector2(w, h))
	_ci.draw_rect(rect, Color(0.02, 0.09, 0.13, 0.92))
	_ci.draw_rect(rect, Color(0.55, 0.9, 1.0, 0.6), false, 1.2)
	return rect


func _draw_board_panel(st: Dictionary) -> void:
	var rect := _menu_panel(st["pos"], 196.0, 20.0 + GameState.contracts.size() * 16.0)
	_ci.draw_string(_font, rect.position + Vector2(8, 13), "OPEN CONTRACTS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.9, 1.0, 0.7))
	for i in GameState.contracts.size():
		var c: Dictionary = GameState.contracts[i]
		var have: int = int(GameState.elements.get(c["sym"], 0))
		var ok: bool = have >= int(c["qty"])
		_ci.draw_string(_font, rect.position + Vector2(8, 28 + i * 16),
			"%d× %s (%d/%d)" % [c["qty"], Elements.name_of(c["sym"]), mini(have, c["qty"]), c["qty"]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.4, 1.0, 0.5) if ok else UITheme.TEXT_DIM)
		_ci.draw_string(_font, rect.position + Vector2(0, 28 + i * 16),
			"%d ore  " % c["reward"], HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 6, 10,
			UITheme.ACCENT_WARM)


func _draw_comms_panel(st: Dictionary) -> void:
	# wide enough that the longest element name never runs under the price column
	var rect := _menu_panel(st["pos"], 224.0, 20.0 + GameState.trader_stock.size() * 16.0)
	_ci.draw_string(_font, rect.position + Vector2(8, 13), "VESNA'S STOCK · SHIFT %d" % GameState.shift,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.75, 0.3, 0.8))
	for i in GameState.trader_stock.size():
		var o: Dictionary = GameState.trader_stock[i]
		var left: int = int(o.get("qty", 1))
		var afford: bool = GameState.banked >= int(o["price"]) and left > 0
		_ci.draw_string(_font, rect.position + Vector2(8, 28 + i * 16),
			"[%d] %s — %s ×%d" % [i + 1, o["sym"], Elements.name_of(o["sym"]), left] \
				if left > 0 else "[%d] %s — SOLD OUT" % [i + 1, o["sym"]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UITheme.TEXT if afford else Color(1, 1, 1, 0.3))
		_ci.draw_string(_font, rect.position + Vector2(0, 28 + i * 16),
			"%d ore  " % o["price"], HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 6, 10,
			Color(0.4, 1.0, 0.5) if afford else Color(1.0, 0.4, 0.3, 0.6))


func _draw_workbench_panel(st: Dictionary) -> void:
	var rect := _menu_panel(st["pos"], 224.0, 20.0 + GameState.RECIPES.size() * 16.0)
	_ci.draw_string(_font, rect.position + Vector2(8, 13),
		"WORKBENCH · CANISTERS %d/3" % GameState.canisters,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 1.0, 0.6, 0.8))
	for i in GameState.RECIPES.size():
		var r: Dictionary = GameState.RECIPES[i]
		var owned: bool = not r.get("repeat", false) and GameState.crafted.has(r["id"])
		var req_bits: Array = []
		for sym in r["req"]:
			req_bits.append("%d %s" % [r["req"][sym], sym])
		var label: String = "[%d] %s" % [i + 1, r["name"]]
		if owned:
			label += " ✓"
		_ci.draw_string(_font, rect.position + Vector2(8, 28 + i * 16), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.5, 1.0, 0.6) if owned else UITheme.TEXT)
		_ci.draw_string(_font, rect.position + Vector2(0, 28 + i * 16),
			", ".join(req_bits) + "  ", HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 6, 9,
			UITheme.TEXT_DIM)