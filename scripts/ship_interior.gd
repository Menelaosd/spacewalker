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
const ID_MODAL := preload("res://scripts/id_modal.gd")
const CrewDialogs := preload("res://scripts/crew_dialogs.gd")
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
	# medbay + botany fixtures — the same craft art the fabricator prints,
	# so the fixed rooms and player-built pieces share one scale/style
	"med_bed": preload("res://assets/craft/med_bed.png"),
	"sample_fridge": preload("res://assets/craft/sample_fridge.png"),
	"ecg": preload("res://assets/craft/ecg_monitor.png"),
	"grow_rack": preload("res://assets/craft/grow_rack.png"),
	"hydro_tray": preload("res://assets/craft/hydroponic_tray.png"),
	"seedling": preload("res://assets/craft/seedling_table.png"),
	"terrarium": preload("res://assets/craft/terrarium_dome.png"),
	"plant": preload("res://assets/craft/potted_plant.png"),
	"rug_round": preload("res://assets/craft/rug_round.png"),
}

# ROOM_PROPS keys that are FLOOR DECALS, not standing furniture: they draw flat
# on the deck (squashed, always in the behind pass, under everything) and are
# NEVER added to the obstacle set — the crew walks straight over them.
const FLAT_PROPS := ["rug_round"]

# per-room floor tile + furniture: [tex key, offset from cell center, width px]
const ROOM_FLOOR := {
	"quarters": "fl_purple", "engine": "fl_rust", "upgrade": "fl_brace",
	"bridge": "fl_vent", "cargo": "fl_grate", "airlock": "fl_hazard",
	"medbay": "fl_plain", "botany": "fl_plain",
	"room": "fl_plain",
}
const ROOM_PROPS := {
	# QUARTERS spans TWO cells (0 + 1) and is furnished like real crew berths.
	# Offsets are relative to the COMBINED 2-cell centre (see _prop_center) —
	# x runs -190..+190 across the 380px-wide room, y runs -80..+80. Doorways
	# open on the BOTTOM wall to Engine (x~-95) and Upgrade (x~+95), and on the
	# RIGHT wall to Medbay (y~0); the whole LEFT wall (x=-190) is exterior and
	# free to furnish. Everything hugs the walls/corners so the mid + lower
	# floor stays an open walkable lane to all three doors and the bunk-wake
	# spawn (0,+24). Layout:
	#   • THREE double beds along the top plating (heads to the wall), each a
	#     pair of bunks, with two tall lockers standing between them, plus a
	#     nightstand at each row end as a bedside table.
	#   • LEFT wall = personal nook: a wardrobe, a reading chair and a potted
	#     plant down the far-left plating (the old pin/tool board is gone — tool
	#     desks make no sense in crew berths).
	#   • LOWER-RIGHT = a cosy seat: a reading chair beside a potted plant in the
	#     corner (clear of the Medbay door at y~0 and the Upgrade door at x~+95).
	#     This corner used to hold a workbench desk — removed for the same reason.
	#   • a round RUG anchors the open mid-floor as a cosy centrepiece. It is a
	#     FLOOR DECAL (see FLAT_PROPS): drawn flat + non-blocking, listed FIRST
	#     so it lies UNDER every standing piece.
	"quarters": [
		["rug_round", Vector2(0, 20), 96.0],
		["bunk", Vector2(-140, -46), 40.0],
		["bunk", Vector2(-100, -46), 40.0],
		["bunk", Vector2(-20, -46), 40.0],
		["bunk", Vector2(20, -46), 40.0],
		["bunk", Vector2(100, -46), 40.0],
		["bunk", Vector2(140, -46), 40.0],
		["locker", Vector2(-60, -42), 26.0],
		["locker", Vector2(60, -42), 26.0],
		# bedside tables at the ends of the bunk row (top corners)
		["nightstand", Vector2(-172, -33), 18.0],
		["nightstand", Vector2(172, -33), 18.0],
		# left-wall personal nook (no tool board — makes no sense in a berth)
		["wardrobe", Vector2(-172, -4), 34.0],
		["chair", Vector2(-146, 24), 18.0],
		["plant", Vector2(-176, 52), 22.0],
		# cosy seat in the lower-right corner (was a workbench desk — removed)
		["chair", Vector2(156, 58), 18.0],
		["plant", Vector2(182, 64), 20.0],
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
	# medbay: THREE med beds along the back wall (heads to the plating), the
	# cryo sample fridge in the back corner, vitals monitor at the foot end.
	# Sizes match the FABRICATOR's printed versions exactly — dims_of box-fits
	# med_bed into 33x52 (H_CAP), so the fixed beds use the same footprint.
	"medbay": [
		["med_bed", Vector2(-60, -14), 33.0],
		["med_bed", Vector2(-14, -14), 33.0],
		["med_bed", Vector2(32, -14), 33.0],
		["sample_fridge", Vector2(66, -36), 28.0],
		["ecg", Vector2(64, 32), 40.0],
	],
	# botany: grow gear against the back wall, living green up front
	"botany": [
		["grow_rack", Vector2(-66, -36), 30.0],
		["hydro_tray", Vector2(-6, -32), 46.0],
		["seedling", Vector2(56, -32), 44.0],
		["terrarium", Vector2(-58, 34), 42.0],
		["plant", Vector2(66, 36), 24.0],
	],
	"room": [],
}

# rescued crew live aboard: room type, offset in that room, suit tint.
# Offsets land on CLEAR floor — never on a prop's footprint, never in a
# doorway lane. Verified walkable via SW_NPCDBG (see _ready).
const NPC_SPOTS := {
	# the Engineer, at her reactor — stands mid-deck, clear of the reactor
	# (top), batteries/generator (bottom) and the east/south doorways
	"JUNO": ["engine", Vector2(6, 8), Color(1.15, 1.0, 0.72)],
	"MIRA": ["botany", Vector2(10, 30), Color(0.78, 1.12, 0.85)],   # the Botanist, home turf
	"HALE": ["cargo", Vector2(-16, 14), Color(0.8, 1.0, 1.15)],
	"SOLA": ["medbay", Vector2(-40, 34), Color(1.15, 0.85, 0.85)],  # the Medic, on shift
	# the Navigator, beside the helm/nav console (not on it)
	"VEGA": ["bridge", Vector2(34, 22), Color(1.0, 0.88, 1.2)],
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
	"sample_fridge": [Color(0.5, 0.85, 1.0), 16.0],
	"ecg": [Color(0.4, 1.0, 0.6), 16.0],
	"grow_rack": [Color(0.55, 1.0, 0.5), 20.0],
	"terrarium": [Color(0.45, 0.95, 0.6), 18.0],
}

# Free-standing ambient point-glows placed around each room type — NOT tied to
# a prop — to give every room a distinct colour wash. Each entry is
# [offset-from-cell-centre, colour, radius]; spawned as soft PointLight2D pools
# by _spawn_lights, animated by the same calm breathe/flicker as prop halos.
# Offsets are cell-centre-relative (±95 x, ±80 y); quarters is the merged 2-cell
# room so its offsets run the wider ±190 x about the combined centre.
const ROOM_AMBIENT := {
	# engine — hot reactor bay: warm orange/red wash, corner to corner
	"engine": [
		[Vector2(-72, 58), Color(1.0, 0.42, 0.18), 32.0],
		[Vector2(78, -46), Color(1.0, 0.55, 0.25), 26.0],
		[Vector2(-40, -30), Color(1.0, 0.36, 0.14), 24.0],
	],
	# medbay — clinical but WARM: soft rose pulse + warm overhead white so the
	# ward reads inviting against the cool steel of the neighbouring decks
	"medbay": [
		[Vector2(-64, 44), Color(1.0, 0.6, 0.58), 30.0],
		[Vector2(60, 50), Color(1.0, 0.82, 0.76), 28.0],
		[Vector2(-8, -28), Color(1.0, 0.88, 0.82), 26.0],
	],
	# bridge — cool cyan/blue command deck, washed across the whole floor
	"bridge": [
		[Vector2(-70, 40), Color(0.26, 0.54, 1.0), 30.0],
		[Vector2(58, 54), Color(0.3, 0.8, 1.0), 26.0],
		[Vector2(-6, -26), Color(0.34, 0.68, 1.0), 28.0],
	],
	# botany — grow lights: rich green with a magenta LED accent
	"botany": [
		[Vector2(-70, 52), Color(0.32, 1.0, 0.38), 30.0],
		[Vector2(70, 50), Color(0.96, 0.28, 0.9), 28.0],
		[Vector2(2, -40), Color(0.46, 1.0, 0.42), 28.0],
	],
	# quarters — cosy amber berths (wide, merged 2-cell room). Amber pools low
	# AND up by the bunks so the whole berth reads warm against its purple deck
	"quarters": [
		[Vector2(-150, 58), Color(1.0, 0.7, 0.38), 32.0],
		[Vector2(150, 58), Color(1.0, 0.68, 0.36), 32.0],
		[Vector2(0, 42), Color(1.0, 0.76, 0.48), 30.0],
		[Vector2(-72, -18), Color(1.0, 0.72, 0.42), 28.0],
		[Vector2(72, -18), Color(1.0, 0.7, 0.4), 28.0],
	],
	# cargo — neutral steel working light, faintly warm
	"cargo": [
		[Vector2(-60, -30), Color(0.82, 0.84, 0.92), 26.0],
		[Vector2(60, 46), Color(0.9, 0.86, 0.8), 24.0],
	],
	# airlock — cold exterior light bleeding in, with a hazard-amber warning wash
	"airlock": [
		[Vector2(58, 40), Color(0.55, 0.78, 1.0), 24.0],
		[Vector2(-44, -28), Color(1.0, 0.74, 0.28), 26.0],
		[Vector2(30, -40), Color(1.0, 0.66, 0.2), 22.0],
	],
	# upgrade / workshop — green-lit bench area
	"upgrade": [
		[Vector2(60, 42), Color(0.55, 0.95, 0.68), 24.0],
		[Vector2(-40, -20), Color(0.6, 0.92, 0.72), 22.0],
	],
	# generic player-built room — neutral cool fill
	"room": [
		[Vector2(0, 42), Color(0.78, 0.85, 0.98), 26.0],
	],
}

# per-room halo TEMPO: multiplies the breathe/sway rate (not amplitude, so no
# jarring motion). Calm rooms drift slowly; the engine bay pulses a touch more.
const ROOM_TEMPO := {
	"quarters": 0.7, "botany": 0.72, "medbay": 0.85,
	"engine": 1.25, "bridge": 1.0, "cargo": 0.9, "airlock": 0.9,
	"upgrade": 1.0, "room": 0.9,
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
var _id_modal: Control
var _inventory: Control
var _rename_box: Control
var _rename_edit: LineEdit
var _rename_hint: Control
var _ending_t := 0.0   # > 0 while the going-home sequence plays

# fabricator placement mode: a chosen object follows the mouse across the
# rooms YOU built, snapping to each room's floor grid; click / E to print
var _placing_id := ""
var _place_cell := -1
var _place_col := 0
var _place_row := 0
var _place_ok := false
var _hover_furn := -1   # placed piece under the mouse — right-click recycles it
const PRINT_TIME := 0.9
var _prints := {}       # "cell:col:row" -> seconds since printed (reveal effect)


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


# --- Multi-cell room support -------------------------------------------------
# Quarters is the one room that occupies TWO grid cells: cell 0 (top-left
# corner) and cell 1 (top row, 2nd col). Floor, walls and walkability fall out
# of the normal per-cell rules for free — adjacent BUILT cells never wall each
# other off (see _draw_room_cell / _is_walkable) and share continuous deck.
# Only two things need care: (a) ROOM_PROPS is keyed by room TYPE, so its
# furniture would otherwise be painted once per cell; and (b) the nameplate /
# doorway threshold between 0 and 1 must not split the open room. We paint the
# quarters props + label ONCE, anchored at the combined footprint's centre.
const QUARTERS_ANCHOR := 0
const QUARTERS_MEMBERS := [0, 1]


func _quarters_merged() -> bool:
	return GameState.rooms.get(0, "") == "quarters" and GameState.rooms.get(1, "") == "quarters"


func _draws_props(cell: int) -> bool:
	## false only for the NON-anchor member of the merged quarters, so its
	## ROOM_PROPS and nameplate are drawn a single time across both cells
	if cell != QUARTERS_ANCHOR and cell in QUARTERS_MEMBERS and _quarters_merged():
		return false
	return true


func _prop_center(cell: int) -> Vector2:
	## the point a cell's ROOM_PROPS lay out from: the COMBINED centre for the
	## quarters anchor (so beds/lockers span both cells), else the cell centre
	if cell == QUARTERS_ANCHOR and _quarters_merged():
		return (cell_rect(0).get_center() + cell_rect(1).get_center()) * 0.5
	return cell_rect(cell).get_center()


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
		if not _draws_props(cell):
			continue   # merged quarters: its props collide once, from the anchor
		var c := _prop_center(cell)
		var type: String = GameState.rooms[cell]
		for f in ROOM_PROPS.get(type, []):
			if f[0] in FLAT_PROPS:
				continue   # floor decals (rugs) are walked over, never collide
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
		if st["kind"] == "exit":
			continue   # the airlock HATCH is flush floor plating — walk over it
		var sp: Array = STATION_PROP[st["kind"]]
		var tex2: Texture2D = P[sp[0]]
		var w2: float = sp[1]
		var h2: float = w2 * tex2.get_size().y / tex2.get_size().x
		_obstacles.append(Rect2((st["pos"] as Vector2) - Vector2(w2, h2) * 0.5,
			Vector2(w2, h2)).grow_individual(-1.0, -w2 * 0.15, -1.0, -w2 * 0.15))
	# printed furniture — a BASE box (bottom ~55% of the sprite): deep enough
	# that the crew can't slip in behind a bed and vanish, shallow enough
	# that two water coolers don't wall off a corridor; rugs stay walkable
	for cell in GameState.furniture:
		for p in GameState.furniture_at(cell):
			var it: Dictionary = Craftables.ITEMS[p["id"]]
			if it.get("flat", false):
				continue
			var fd := _furn_dims(p["id"])
			var bh := maxf(fd.y * 0.55, 14.0)
			_obstacles.append(Rect2(
				_furn_cx(cell, int(p["col"]), int(it["size"])) - fd.x * 0.5 + 1.0,
				_furn_base_y(cell, int(p["row"])) - bh, fd.x - 2.0, bh))


# ------------------------------------------------------------------
# Furniture geometry — each built room's floor is a FURN_COLS x FURN_ROWS
# placement grid (row 0 hugs the back wall, row 1 the front)
# ------------------------------------------------------------------
const FURN_MARGIN_X := 18.0
# floor lines of the four depth rows — staggered down the room the way the
# fixed props are, so player rooms can look as organic as the core ones
const FURN_ROW_Y := [58.0, 86.0, 114.0, 142.0]


func _furn_slot_w() -> float:
	return (CELL_W - FURN_MARGIN_X * 2.0) / GameState.FURN_COLS


func _furn_dims(id: String) -> Vector2:
	## DISPLAY size — box-fit of hand-tuned width + height cap (shared with
	## GameState's placement rules via Craftables.dims_of)
	return Craftables.dims_of(id)


func _furn_cx(cell: int, col: int, size: int) -> float:
	return cell_rect(cell).position.x + FURN_MARGIN_X + (col + size * 0.5) * _furn_slot_w()


func _furn_base_y(cell: int, row: int) -> float:
	## the piece's floor line (sprite bottom) for its depth row
	return cell_rect(cell).position.y + FURN_ROW_Y[clampi(row, 0, FURN_ROW_Y.size() - 1)]


func _furn_row_at(cell: int, my: float) -> int:
	## which depth row the mouse y falls into (band midpoints between rows)
	return clampi(int((my - cell_rect(cell).position.y - 44.0) / 28.0),
		0, GameState.FURN_ROWS - 1)


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
	_load_device_anims()   # cache any device loop frames (silent if none on disk)
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
		# open floor at the foot of the middle bed — the beds are solid now
		crew.position = _prop_center(_find_cell("quarters")) + Vector2(0, 24)
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
	# SW_ID=JUNO: rescue them and open their ID card, for screenshots
	if OS.get_environment("SW_ID") != "":
		var idn := OS.get_environment("SW_ID")
		GameState.rescued[idn] = true
		_define_stations()
		crew.set_process(false)
		_id_modal.open(idn)
	# SW_FURN=1: pre-place a furnished room for screenshots
	if OS.get_environment("SW_FURN") != "":
		var rc := _debug_build_room()
		if rc >= 0:
			for sym in ["Fe", "C", "Al", "Cu", "Si", "Ar", "W"]:
				GameState.elements[sym] = maxi(int(GameState.elements.get(sym, 0)), 99)
			for pick in [["rug_round", 1, 2], ["bed_single", 0, 0], ["locker", 2, 0],
					["bookshelf", 3, 0], ["floor_lamp", 5, 0], ["nightstand", 4, 1],
					["sofa", 0, 3], ["potted_plant", 4, 2]]:
				GameState.recipes_unlocked[pick[0]] = true
				GameState.place_furniture(rc, pick[0], pick[1], pick[2])
	# SW_NPCDBG=1: rescue everyone, then print each aboard-NPC's spot,
	# walkability and any feet-box overlap with a prop — placement QA for the
	# crew idles (env-gated; harmless in normal play). DELETE BEFORE SHIPPING.
	if OS.get_environment("SW_NPCDBG") != "":
		for rn2 in NPC_SPOTS:
			GameState.rescued[rn2] = true
		_define_stations()
		for nn in NPC_SPOTS:
			var sp2: Array = NPC_SPOTS[nn]
			var np: Vector2 = cell_rect(_find_cell(sp2[0])).get_center() + (sp2[1] as Vector2)
			var fbox := Rect2(np.x + 12.0 - 6.0, np.y + 12.0 - 3.0, 12.0, 6.0)
			var hit := "clear"
			for o in _obstacles:
				if o.intersects(fbox):
					hit = "OVERLAP %s" % str(o)
					break
			print("NPCDBG %s room=%s off=%s walkable=%s feet=%s" % [
				nn, sp2[0], str(sp2[1]), str(_is_walkable(np)), hit])
		# capture aid: freeze the player, pull the camera back and centre it so
		# a single windowed frame shows every room + crew at once. Fit is
		# computed from the ACTUAL built-cell bounds and the viewport size, so it
		# frames correctly at any window/DPI (a fixed zoom cropped at 200% DPI).
		crew.set_process(false)
		var bb := Rect2()
		for cell in GameState.rooms:
			bb = cell_rect(cell) if bb.size == Vector2.ZERO else bb.merge(cell_rect(cell))
		if bb.size == Vector2.ZERO:
			bb = Rect2(ORIGIN, Vector2(CELL_W, CELL_H))
		crew.position = bb.get_center()
		var cam := crew.get_node_or_null("Camera") as Camera2D
		if cam != null:
			cam.position_smoothing_enabled = false
			var vp := get_viewport().get_visible_rect().size
			var z := minf(vp.x / (bb.size.x + 160.0), vp.y / (bb.size.y + 160.0))
			cam.zoom = Vector2(z, z)


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
	# the rescued crew are people, not consoles — walk up and talk to them
	for nname in NPC_SPOTS:
		if not GameState.rescued.has(nname):
			continue
		var spot: Array = NPC_SPOTS[nname]
		_stations.append({"pos": cell_rect(_find_cell(spot[0])).get_center()
			+ (spot[1] as Vector2), "kind": "npc", "name": nname})
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


# ------------------------------------------------------------------
# Animated device props — subtle looping machines. Frame sets live at
# res://assets/sprites/device_anim/<id>_<n>.png (seamless loops, authored
# at the device's static-sprite size/anchor). Loaded ONCE on _ready; any
# device with no frames on disk silently keeps drawing its static sprite,
# so this layer is fully non-destructive / fallback-safe.
# ------------------------------------------------------------------
const DEV_ANIM_DIR := "res://assets/sprites/device_anim"
const DEV_ANIM_FPS := 3.0   # base loop speed; per-device rate jitter varies it
# P-key / prop-key -> device_anim id, for the few FIXED room props whose kit
# key differs from the craft-file stem the frames are named after. Craft
# furniture (keyed by stem) and same-named props fall through to identity.
const DEV_ANIM_ALIAS := {
	"ecg": "ecg_monitor",
	"hydro_tray": "hydroponic_tray",
	"seedling": "seedling_table",
	"terrarium": "terrarium_dome",
}
var _dev_anim := {}   # device id -> Array[Texture2D] (frames, sorted 0..n)
var _dev_rate := {}   # device id -> per-device speed multiplier (desync)
var _dev_phase := {}  # device id -> per-device start phase in loops (desync)


func _load_device_anims() -> void:
	## Scan device_anim/ ONCE and cache each <id>_<n>.png frame set, sorted by
	## frame index. The id is everything before the LAST underscore (ids contain
	## underscores, e.g. console_wide_3.png -> "console_wide"). Guarded on
	## ResourceLoader.exists + a null check so missing / not-yet-imported frames
	## are simply skipped — a device with no frames keeps its static sprite.
	_dev_anim = {}
	var d := DirAccess.open(DEV_ANIM_DIR)
	if d == null:
		return   # folder not present yet — everything falls back to static
	var groups := {}   # id -> Array of [frame_index:int, filename:String]
	for f in d.get_files():
		if not f.ends_with(".png"):
			continue
		var base := f.substr(0, f.length() - 4)   # strip ".png"
		var us := base.rfind("_")
		if us < 0:
			continue
		var idx_str := base.substr(us + 1)
		if not idx_str.is_valid_int():
			continue
		var id := base.substr(0, us)
		if not groups.has(id):
			groups[id] = []
		(groups[id] as Array).append([int(idx_str), f])
	for id in groups:
		var list: Array = groups[id]
		list.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
		var frames: Array = []
		for e in list:
			var path := "%s/%s" % [DEV_ANIM_DIR, e[1]]
			if ResourceLoader.exists(path):   # .import present -> safe to load
				var tex: Texture2D = load(path)
				if tex != null:
					frames.append(tex)
		if not frames.is_empty():
			_dev_anim[id] = frames
			# per-device speed + start phase so no two devices ever step in
			# unison (the old shared int(clock*fps) made them all flip together).
			var hp := absi(hash(id))
			_dev_phase[id] = float(hp % 997) / 997.0
			_dev_rate[id] = 0.8 + float((hp / 997) % 401) / 1000.0


func _dev_anim_id(key: String) -> String:
	return DEV_ANIM_ALIAS.get(key, key)


func _dev_frame(id: String) -> Texture2D:
	## Current loop frame for a cached device. Each device advances on its own
	## speed (_dev_rate) and start phase (_dev_phase) off the shared _reactor
	## clock, so they drift and never pulse in sync. Single crisp frame per draw
	## (no crossfade — a half-opaque tween frame ghosts badly when the ship
	## scrolls). Loops forever.
	var frames: Array = _dev_anim[id]
	var n := frames.size()
	var t: float = _reactor * DEV_ANIM_FPS * float(_dev_rate.get(id, 1.0)) \
		+ float(_dev_phase.get(id, 0.0)) * float(n)
	return frames[int(floor(t)) % n]


# all kit drawing goes through _ci so the same helpers can paint on the
# base canvas (behind the crew) or the overlay (in front of the crew)
var _ci: CanvasItem = self


func _prop(key: String, center: Vector2, width: float,
		tint := Color.WHITE, flip_h := false, flip_v := false) -> void:
	## Draw a kit prop centered at `center`, `width` px wide, aspect kept. If the
	## prop is an ANIMATED device (frames cached in _dev_anim), the current loop
	## frame is drawn in place of the static sprite — same position, width, aspect,
	## flip and tint. Devices without frames fall through to the static P[key].
	var tex: Texture2D = P[key]
	var aid := _dev_anim_id(key)
	if _dev_anim.has(aid):
		tex = _dev_frame(aid)
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


func _draw_doorway(mid: Vector2, rot: float, edge_half: float,
		cap_a: bool, cap_b: bool) -> void:
	## The passage between two rooms is an ABSENCE, not an object: the deck
	## simply continues through the open edge. The only markings are small
	## flush jamb caps where the flanking wall trim meets the gap — the wall
	## just terminates cleanly. Local +X runs along the shared edge; cap_a
	## sits at the -X end, cap_b at +X (skipped where the corner is open
	## floor and there is no wall to terminate).
	_ci.draw_set_transform(mid, rot, Vector2.ONE)
	var run := edge_half - 14.0   # inner faces of the flanking walls
	for e in [[-1.0, cap_a], [1.0, cap_b]]:
		if not e[1]:
			continue
		var sx: float = e[0]
		var rx := sx * run
		var cap := Rect2(minf(rx, rx + sx * 6.0), -4.0, 6.0, 8.0)
		_ci.draw_rect(cap, Color(0.20, 0.24, 0.30), true)
		_ci.draw_rect(cap, Color(0, 0, 0, 0.35), false, 1.0)
		# 1px accent on the cap's inner face — the trim's clean end
		_ci.draw_line(Vector2(rx, -3.0), Vector2(rx, 3.0),
			Color(0.55, 0.7, 0.8, 0.45), 1.0)
	_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _process(delta: float) -> void:
	_reactor += delta
	_animate_lights()
	_update_npcs()
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
	# tick the fabricator print-in reveals
	if not _prints.is_empty():
		var done: Array = []
		for k in _prints:
			_prints[k] = float(_prints[k]) + delta
			if float(_prints[k]) >= PRINT_TIME:
				done.append(k)
		for k in done:
			_prints.erase(k)
	_update_active_station()
	var rn := _room_at(crew.position + Vector2(0, 12))   # feet cell — matches the rename target
	# match the cell _open_rename() actually edits (the feet cell) so the hint
	# and the R action never disagree near a cell boundary
	var show_rename: bool = rn != "—" \
		and GameState.can_rename_room(cell_at(crew.position + Vector2(0, 12))) \
		and not _rename_box.visible and _placing_id == "" \
		and not (_upgrade_modal != null and _upgrade_modal.visible) \
		and not (_fab_modal != null and _fab_modal.visible) \
		and not (_inventory != null and _inventory.visible)
	_rename_hint.modulate.a = 0.85 if show_rename else 0.0
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


func _update_npcs() -> void:
	## Drive the crew's rest/gesture state machine. Each NPC rests (looping the
	## slow breathe animation) ~90% of the time, then plays ONE gesture picked at
	## random from its pool, ONCE and slowly, then settles back to the breathe loop.
	##
	## INDEPENDENT TIMING (crew must NEVER gesture in unison): every NPC owns its
	## own RNG (`_npc_rng`), seeded from a fresh randomize() at first sight, so
	## their schedules are provably independent AND non-deterministic across runs.
	## The FIRST trigger is staggered over a WIDE 3-25s window; every later rest
	## is an INFREQUENT 12-30s. No shared clock advances them together — each keeps
	## its own absolute `next` time and re-rolls it independently.
	for nname in NPC_SPOTS:
		if not GameState.rescued.has(nname):
			continue
		var a: Dictionary = _npc_anim.get(nname, {})
		if a.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.randomize()   # own seed per NPC — no two schedules line up
			_npc_rng[nname] = rng
			a = {"mode": "rest", "gstart": 0.0, "anim": 0,
				"next": _reactor + rng.randf_range(NPC_FIRST_MIN, NPC_FIRST_MAX)}
			_npc_anim[nname] = a
		var rng2: RandomNumberGenerator = _npc_rng[nname]
		var pool := _npc_idle_pool(nname)
		if a["mode"] == "rest":
			if _reactor >= float(a["next"]):
				# gesture groups are pool[1..] (pool[0] is the resting/base idle):
				# only gesture when a real one exists, and never pick the base group
				if pool.size() >= 2:
					# pick a RANDOM gesture from the pool, play it once
					a["anim"] = rng2.randi_range(1, pool.size() - 1)
					a["mode"] = "gesture"
					a["gstart"] = _reactor
				else:
					# no real gesture yet (token / not imported) — wait again
					a["next"] = _reactor + rng2.randf_range(NPC_REST_MIN, NPC_REST_MAX)
		else:
			var gi: int = clampi(int(a["anim"]), 0, pool.size() - 1)
			var nframes := (pool[gi] as Array).size() if pool.size() > 0 else 1
			var gdur := float(maxi(nframes, 1)) / NPC_GESTURE_FPS
			if _reactor - float(a["gstart"]) >= gdur:
				a["mode"] = "rest"
				a["next"] = _reactor + rng2.randf_range(NPC_REST_MIN, NPC_REST_MAX)


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
		"npc":
			return "E    Talk to %s   ·   I  check ID" % st["name"]
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
	if _id_modal != null and _id_modal.visible:
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
	elif st["kind"] == "npc" and event.physical_keycode == KEY_I:
		# their exile papers — HELIOS filed us all before it threw us out
		crew.set_process(false)
		_id_modal.open(st["name"])
		get_viewport().set_input_as_handled()
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
		"npc":
			# a line in their own voice — random, personality-true
			var quotes: Array = CrewDialogs.QUOTES.get(st["name"], [])
			if quotes.size() > 0:
				Sfx.play("radio", -14.0)
				GameState.say("%s: %s" % [st["name"], quotes[randi() % quotes.size()]])


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
	_place_row = _furn_row_at(cell, m.y)
	# wall pieces only hang on the back wall — snap the ghost there
	if it.get("back", false):
		_place_row = 0
	_place_ok = GameState.furniture_fits(cell, _placing_id, _place_col, _place_row) \
		and GameState.can_afford(it["cost"])
	# is an already-printed piece under the mouse? (right-click recycles it)
	_hover_furn = -1
	var mcol := int(floor((m.x - r.position.x - FURN_MARGIN_X) / _furn_slot_w()))
	var mrow := _furn_row_at(cell, m.y)
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
		var d := _furn_dims(id)
		Vfx.sparkle(self, Vector2(_furn_cx(_place_cell, _place_col, int(it["size"])),
			_furn_base_y(_place_cell, _place_row) - d.y * 0.5), Color(0.45, 0.9, 1.0))
		# the print-in reveal: the piece materializes bottom-up in fab blue
		_prints["%d:%d:%d" % [_place_cell, _place_col, _place_row]] = 0.0001
		GameState.say("%s printed." % it["name"])
		# STAY in placement — print more, or Esc back to the catalogue
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
		# the WHOLE grid stays visible while building — every row's floor line
		# and slots; the targeted row burns brightest
		for row in GameState.FURN_ROWS:
			var by := _furn_base_y(cell, row)
			var rhot: bool = hot and row == _place_row
			_ci.draw_line(Vector2(r.position.x + FURN_MARGIN_X, by),
				Vector2(r.end.x - FURN_MARGIN_X, by),
				Color(0.35, 0.85, 1.0, (0.5 if rhot else 0.18) + 0.08 * pulse), 1.0)
			for col in GameState.FURN_COLS:
				var sx := r.position.x + FURN_MARGIN_X + col * _furn_slot_w()
				var sr := Rect2(sx + 1.0, by - 14.0, _furn_slot_w() - 2.0, 14.0)
				_ci.draw_rect(sr, Color(0.35, 0.85, 1.0, 0.07 if rhot else 0.03))
				_ci.draw_rect(sr, Color(0.35, 0.85, 1.0,
					(0.35 if rhot else 0.14) + 0.08 * pulse), false, 1.0)
	if _place_cell >= 0:
		var it: Dictionary = Craftables.ITEMS[_placing_id]
		var size := int(it["size"])
		var tex: Texture2D = it["tex"]
		var d := _furn_dims(_placing_id)
		if it.get("flat", false):
			d.y *= 0.55
		var cx := _furn_cx(_place_cell, _place_col, size)
		var by2 := _furn_base_y(_place_cell, _place_row)
		var tint := Color(0.55, 1.0, 0.65, 0.72) if _place_ok else Color(1.0, 0.4, 0.35, 0.55)
		# claimed slots underline
		var ux := cell_rect(_place_cell).position.x + FURN_MARGIN_X \
			+ _place_col * _furn_slot_w()
		_ci.draw_rect(Rect2(ux + 1.0, by2 - 3.0, size * _furn_slot_w() - 2.0, 4.0),
			Color(tint.r, tint.g, tint.b, 0.8))
		_ci.draw_texture_rect(tex, Rect2(cx - d.x * 0.5, by2 - d.y, d.x, d.y), false, tint)
	# a printed piece under the mouse glows warm — right-click recycles it
	if _place_cell >= 0 and _hover_furn >= 0:
		var list: Array = GameState.furniture_at(_place_cell)
		if _hover_furn < list.size():
			var hp: Dictionary = list[_hover_furn]
			var hit: Dictionary = Craftables.ITEMS[hp["id"]]
			var hd := _furn_dims(hp["id"])
			if hit.get("flat", false):
				hd.y *= 0.55
			_ci.draw_rect(Rect2(
				_furn_cx(_place_cell, int(hp["col"]), int(hit["size"])) - hd.x * 0.5 - 2.0,
				_furn_base_y(_place_cell, int(hp["row"])) - hd.y - 2.0,
				hd.x + 4.0, hd.y + 4.0), Color(1.0, 0.75, 0.3, 0.7), false, 1.5)
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

	# crew roster indicator — five circular portraits, self-anchored to the
	# top-right corner (the info panel lives top-left, so they never overlap on
	# the 1280-wide viewport). Colour when rescued, dark until then.
	var roster := preload("res://scripts/crew_roster.gd").new()
	root.add_child(roster)

	_inventory = INVENTORY_SCREEN.new()
	# the inventory is a full-screen layer — never let it stack over a modal,
	# the rename box or fabricator placement
	_inventory.can_open = func() -> bool:
		return _placing_id == "" \
			and not (_upgrade_modal != null and _upgrade_modal.visible) \
			and not (_fab_modal != null and _fab_modal.visible) \
			and not (_id_modal != null and _id_modal.visible) \
			and not (_rename_box != null and _rename_box.visible) \
			and not (_active >= 0 and _stations[_active]["kind"] == "npc")
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

	# crew ID viewer — I beside a rescued crewmate
	_id_modal = ID_MODAL.new()
	root.add_child(_id_modal)
	_id_modal.closed.connect(func(): crew.set_process(true))

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

	# "R rename" under the room name — a real keycap, not label text
	_rename_hint = KeyPrompt.new()
	_rename_hint.from_top = 46.0
	_rename_hint.set_prompt("R    rename this room")
	_rename_hint.modulate = Color(0.6, 0.9, 1.0, 0.0)
	root.add_child(_rename_hint)

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
	# a viewport window on the quarters' top hull wall — stars behind glass.
	# Centred on the COMBINED 2-cell room so it sits over the middle bed.
	var qc := _prop_center(_find_cell("quarters"))
	var win_pos := Vector2(qc.x, cell_rect(_find_cell("quarters")).position.y - 3)
	_prop("window", win_pos, 66.0)
	_glow(win_pos + Vector2(0, 10), (GLOWS["window"][0] as Color), GLOWS["window"][1])
	# doorway thresholds between built neighbours
	var dcols := GameState.SHIP_COLS
	for cell in GameState.rooms:
		for n in GameState.cell_neighbors(cell):
			# no threshold WITHIN the merged quarters — 0 and 1 are one open room
			if cell in QUARTERS_MEMBERS and n in QUARTERS_MEMBERS and _quarters_merged():
				continue
			if n > cell and _built(n):
				var mid := (cell_rect(cell).get_center() + cell_rect(n).get_center()) * 0.5
				var horizontal := absi(n - cell) == 1
				# jamb caps only where a wall actually flanks that end of the
				# gap — at fully open corners the floor continues, no trim
				var cap_a: bool
				var cap_b: bool
				if horizontal:
					# shared VERTICAL edge; local -X = north end, +X = south
					cap_a = not (_built(cell - dcols) and _built(n - dcols))
					cap_b = not (_built(cell + dcols) and _built(n + dcols))
				else:
					# shared HORIZONTAL edge; local -X = west end, +X = east
					var dcol: int = cell % dcols
					cap_a = dcol == 0 or not (_built(cell - 1) and _built(n - 1))
					cap_b = dcol == dcols - 1 or not (_built(cell + 1) and _built(n + 1))
				# left/right neighbours share a VERTICAL edge — rotate the piece
				_draw_doorway(mid, PI * 0.5 if horizontal else 0.0,
					(CELL_H if horizontal else CELL_W) * 0.5, cap_a, cap_b)
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
	# which sides are real walls (ship edge or unbuilt space) — shading and
	# shadows hug the walls and leave open passages between rooms bright
	var col := cell % GameState.SHIP_COLS
	var row := int(float(cell) / GameState.SHIP_COLS)
	var wall_n := row == 0 or not _built(cell - GameState.SHIP_COLS)
	var wall_s := row == GameState.SHIP_ROWS - 1 or not _built(cell + GameState.SHIP_COLS)
	var wall_w := col == 0 or not _built(cell - 1)
	var wall_e := col == GameState.SHIP_COLS - 1 or not _built(cell + 1)
	# the kit's floor tiles, 2x2 per cell — each room type has its own deck.
	# Lifted a touch so rooms read warm against the dark hull; each quarter
	# drifts a hair in brightness so big floors don't read as one flat sheet.
	var fkey: String = ROOM_FLOOR.get(type, "fl_plain")
	for ty in 2:
		for tx in 2:
			var drift := fposmod(sin(cell * 12.99 + tx * 78.23 + ty * 37.72) * 437.585, 1.0) * 0.09 - 0.045
			_prop_rect(fkey, Rect2(rect.position.x + tx * CELL_W * 0.5,
				rect.position.y + ty * CELL_H * 0.5, CELL_W * 0.5, CELL_H * 0.5),
				Color(1.34 + drift, 1.34 + drift, 1.28 + drift))
	# walls throw soft shade onto the deck — north deepest (the plating
	# stands tall there), sides and south just enough to seat the floor
	if wall_n:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6)), Color(0, 0, 0, 0.22))
		draw_rect(Rect2(rect.position + Vector2(0, 6), Vector2(rect.size.x, 5)), Color(0, 0, 0, 0.10))
	if wall_w:
		draw_rect(Rect2(rect.position, Vector2(5, rect.size.y)), Color(0, 0, 0, 0.12))
	if wall_e:
		draw_rect(Rect2(rect.position + Vector2(rect.size.x - 5, 0), Vector2(5, rect.size.y)), Color(0, 0, 0, 0.12))
	if wall_s:
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 4), Vector2(rect.size.x, 4)), Color(0, 0, 0, 0.12))
	# pooled shadow where two walls meet — grounds the room in its shell
	for c in [[wall_n, wall_w, rect.position], [wall_n, wall_e, Vector2(rect.end.x - 24, rect.position.y)],
			[wall_s, wall_w, Vector2(rect.position.x, rect.end.y - 24)], [wall_s, wall_e, rect.end - Vector2(24, 24)]]:
		if c[0] and c[1]:
			draw_rect(Rect2(c[2] as Vector2, Vector2(24, 24)), Color(0, 0, 0, 0.05))
			draw_rect(Rect2((c[2] as Vector2) + Vector2(5, 5), Vector2(14, 14)), Color(0, 0, 0, 0.07))
	# soft room light
	draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.42,
		Color(0.85, 0.92, 1.0, 0.05))
	# (furniture draws in the depth passes — see _draw_depth)
	# name plate bottom-left, where no prop or station covers it. The merged
	# quarters shows ONE label (only its anchor cell draws it).
	if _draws_props(cell):
		draw_string(_font, rect.position + Vector2(8, CELL_H - 8),
			GameState.room_display_name(cell).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.9, 1.0, 0.6))


# ------------------------------------------------------------------
# Real 2D lights: the canvas is dimmed a touch and every glowing prop
# carries a PointLight2D — so the light actually falls on the crew and
# neighbouring props, dancing with the same rhythm as the halos.
# ------------------------------------------------------------------
var _lights: Array = []   # [node, base_pos, phase, base_energy, tempo]
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
		if not _draws_props(cell):
			continue
		var c := _prop_center(cell)
		var type: String = GameState.rooms[cell]
		var tempo: float = ROOM_TEMPO.get(type, 1.0)
		for f in ROOM_PROPS.get(type, []):
			if GLOWS.has(f[0]):
				_add_light(c + (f[1] as Vector2), GLOWS[f[0]][0], GLOWS[f[0]][1], tempo)
		# (Free-standing ROOM_AMBIENT colour pools removed — they read as ugly
		# soft "opacity circles" in the middle of every room. Room colour now
		# comes only from the glows on actual lit props.)
	for st in _stations:
		if STATION_PROP.has(st["kind"]):
			var gk: String = STATION_PROP[st["kind"]][0]
			if GLOWS.has(gk):
				_add_light(st["pos"], (GLOWS[gk][0] as Color), GLOWS[gk][1])
	# the quarters viewport spills starlight (centred on the merged room)
	var qc := _prop_center(_find_cell("quarters"))
	_add_light(Vector2(qc.x, cell_rect(_find_cell("quarters")).position.y + 8.0),
		(GLOWS["window"][0] as Color), GLOWS["window"][1])


func _add_light(pos: Vector2, col: Color, glow_r: float, tempo := 1.0,
		e_scale := 1.0) -> void:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.position = pos
	l.color = col
	l.energy = 0.0
	l.texture_scale = glow_r * 6.0 / 256.0
	add_child(l)
	_lights.append([l, pos, pos.x * 0.7 + pos.y * 1.3,
		clampf(glow_r / 34.0, 0.5, 1.4) * e_scale, tempo])


func _animate_lights() -> void:
	var t := _reactor
	for l in _lights:
		var lt: PointLight2D = l[0]
		var ph: float = l[2]
		var rate: float = l[4]   # per-room tempo — scales speed, never amplitude
		var a := 0.72 + 0.18 * sin(t * 1.8 * rate + ph) + 0.10 * sin(t * 5.3 * rate + ph * 2.0)
		if fmod(t * 0.9 + ph, 9.0) < 0.07:
			a *= 0.35   # rare electrical flicker
		lt.energy = (l[3] as float) * a
		lt.position = (l[1] as Vector2) \
			+ Vector2(sin(t * 1.1 * rate + ph) * 3.0, cos(t * 1.7 * rate + ph * 0.7) * 2.0)


func _feet_y() -> float:
	return crew.position.y + 12.0


func _draw_depth(behind: bool) -> void:
	## One of the two depth passes: props whose base sits at or above the
	## crew's feet draw BEHIND (base canvas); the rest draw on the overlay,
	## in front of the crew. Recomputed every frame as the crew walks.
	var fy := _feet_y()
	for cell in GameState.rooms:
		if not _draws_props(cell):
			continue
		var type: String = GameState.rooms[cell]
		var c := _prop_center(cell)
		for f in ROOM_PROPS.get(type, []):
			var pos: Vector2 = c + (f[1] as Vector2)
			if f[0] in FLAT_PROPS:
				# floor decal (rug): lies flat, squashed to a floor ellipse,
				# always in the behind pass so it sits under crew + furniture
				if behind:
					var rw: float = f[2]
					var rh: float = _prop_h(f[0], rw) * 0.55
					_prop_rect(f[0], Rect2(pos.x - rw * 0.5, pos.y - rh * 0.5, rw, rh))
				continue
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
		if st["kind"] == "expand" or st["kind"] == "npc":
			continue   # npc bodies draw in the crew pass below
		if st["kind"] == "exit":
			# the airlock HATCH is flush floor plating — always UNDER the crew
			if behind:
				_draw_station_visual(st, i == _active)
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
		var pieces: Array = GameState.furniture_at(cell).duplicate()
		pieces.sort_custom(func(a, b): return int(a["row"]) < int(b["row"]))
		for p in pieces:
			var it: Dictionary = Craftables.ITEMS[p["id"]]
			if bool(it.get("flat", false)) != flats:
				continue
			var base_y := _furn_base_y(cell, int(p["row"]))
			var d := _furn_dims(p["id"])
			# depth line = the collision base line
			if not flats and (base_y - 2.0 <= fy) != behind:
				continue
			var tex: Texture2D = it["tex"]
			var cx := _furn_cx(cell, int(p["col"]), int(it["size"]))
			if flats:
				# floor mats lie down: squash to a floor-projected ellipse look
				d.y *= 0.55
			var pk := "%d:%d:%d" % [cell, int(p["col"]), int(p["row"])]
			if _prints.has(pk):
				# FABRICATOR PRINT-IN: the piece materializes bottom-up — only
				# the printed portion exists yet, glowing fab-blue and cooling
				# to true color, with a bright print line at the build edge
				var k := clampf(float(_prints[pk]) / PRINT_TIME, 0.0, 1.0)
				var reveal := clampf(k * 1.25, 0.0, 1.0)     # height fraction built
				var ts := tex.get_size()
				var src_h := ts.y * reveal
				var dst_h := d.y * reveal
				var tint := Color(0.5, 0.95, 1.0).lerp(Color.WHITE, k)
				tint.a = clampf(k * 3.0, 0.35, 1.0)
				_ci.draw_texture_rect_region(tex,
					Rect2(cx - d.x * 0.5, base_y - dst_h, d.x, dst_h),
					Rect2(0, ts.y - src_h, ts.x, src_h), tint)
				if reveal < 1.0:
					var ly := base_y - dst_h
					_ci.draw_rect(Rect2(cx - d.x * 0.5 - 2.0, ly - 1.2, d.x + 4.0, 2.4),
						Color(0.7, 1.0, 1.0, 0.9))
					_ci.draw_rect(Rect2(cx - d.x * 0.5 - 6.0, ly - 3.5, d.x + 12.0, 7.0),
						Color(0.45, 0.9, 1.0, 0.22))
				continue
			# ANIMATED device fixtures (fabricator craft, keyed by their stem)
			# swap in the current loop frame; all others draw their static tex.
			# (The <1s print-in reveal above stays static — a transient effect.)
			var dtex: Texture2D = tex
			if _dev_anim.has(p["id"]):
				dtex = _dev_frame(p["id"])
			_ci.draw_texture_rect(dtex, Rect2(cx - d.x * 0.5, base_y - d.y, d.x, d.y), false)


var _token_cache := {}
var _idle_cache := {}   # name -> Array[{tex, feet}] BASE idle frames ([] = none yet)
var _pool_cache := {}   # name -> Array of gesture groups (each Array[{tex, feet}])
var _breathe_cache := {}   # name -> Array[{tex, feet}] resting BREATHE loop ([] = none yet)
var _npc_anim := {}     # name -> {mode:"rest"/"gesture", next, gstart, anim}
var _npc_rng := {}      # name -> its own RandomNumberGenerator (independent schedule)
const NPC_TALL := 40.0  # aboard crew height in px — crew-scale, feet on floor
# per-NPC size scale on the draw height — HALE is a big man, rendered noticeably
# larger. Scaled ABOUT THE FEET baseline (grows upward), so feet + shadow stay
# planted on the deck. Default 1.0 for anyone not listed.
const NPC_SCALE := {"HALE": 1.15}
# aboard crew whose sprite art faces RIGHT but who should stand facing LEFT:
# their frames are mirrored horizontally about the figure's centre (feet/shadow
# stay put — the shadow is symmetric). The rest keep their native right-facing.
const NPC_FACE_LEFT := {"JUNO": true, "MIRA": true}
# The crew REST by playing a slow, subtle looping BREATHE animation (real
# PixelLab frames — NOT a code deformation of a still). ~90% of the time they
# loop this breathe cycle; INFREQUENTLY (each on its OWN randomised 12-30s clock,
# first trigger staggered over 3-25s, so they never sync) they play ONE gesture
# picked at random from their pool, ONCE and slowly, then settle back to the
# breathe loop. No left/right flipping ever.
const NPC_GESTURE_FPS := 3.0    # deliberate one-shot gesture (slow — never fast)
const NPC_BREATHE_FPS := 3.5    # the resting breathe loop — slow and seamless
const NPC_FIRST_MIN := 1.5      # first-gesture stagger window (per NPC)
const NPC_FIRST_MAX := 8.0
const NPC_REST_MIN := 4.5       # seconds resting between gestures (more frequent)
const NPC_REST_MAX := 10.0


func _npc_token(nname: String) -> Texture2D:
	if not _token_cache.has(nname):
		_token_cache[nname] = load(
			"res://assets/sprites/crew/%s_token.png" % nname.to_lower())
	return _token_cache[nname]


func _npc_idle_pool(nname: String) -> Array:
	## Build the crew member's POOL of gesture animations and cache it. Globs
	## res://assets/sprites/crew/idle/<name>_idle*_<n>.png and GROUPS the frames
	## by their animation token: the base set <name>_idle_<n> plus every extra
	## set <name>_idle2_<n>, <name>_idle3_<n>, <name>_idle4_<n> (5 other agents
	## generate these concurrently — any number of groups is accepted). Returns an
	## Array of groups, each a sorted Array of {tex, feet}; the base "idle" group
	## is always first (element 0), used as the resting pose. Each frame's `feet`
	## is the fraction of canvas height where the FEET sit (bottom of the opaque
	## pixels), so transparent padding never floats the figure.
	##
	## Missing/not-yet-imported files are simply skipped (ResourceLoader.exists +
	## null-guard), so this never errors while the art is still being made. Empty
	## groups are dropped; [] is returned (and the draw falls back to the token)
	## when no frames exist at all.
	if _pool_cache.has(nname):
		return _pool_cache[nname]
	var dir := "res://assets/sprites/crew/idle"
	var base := nname.to_lower() + "_idle"   # e.g. "hale_idle"
	var groups := {}   # group token ("" | "2" | "3" | ...) -> Array of filenames
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".png") or not f.begins_with(base):
				continue
			# strip the "<name>_idle" prefix and ".png": leaves "<G>_<frame>",
			# where <G> is "" for the base set or "2"/"3"/"4"... for extra sets
			var rest := f.substr(base.length(), f.length() - base.length() - 4)
			var us := rest.rfind("_")
			if us < 0:
				continue   # no frame index (e.g. a stray "<name>_idle.png") — skip
			var gkey := rest.substr(0, us)
			if not groups.has(gkey):
				groups[gkey] = []
			(groups[gkey] as Array).append(f)
	var keys: Array = groups.keys()
	keys.sort()   # "" < "2" < "3" < "4" — base group lands first
	var pool: Array = []
	for gk in keys:
		var names: Array = groups[gk]
		names.sort_custom(func(a, b): return _trail_idx(a) < _trail_idx(b))
		var frames: Array = []
		for f in names:
			var path := "%s/%s" % [dir, f]
			# only load once the .import exists, or load() errors on the raw png
			if ResourceLoader.exists(path):
				var tex: Texture2D = load(path)
				if tex != null:
					frames.append({"tex": tex, "feet": _feet_frac(tex)})
		if not frames.is_empty():
			pool.append(frames)
	_pool_cache[nname] = pool
	return pool


func _npc_idle_frames(nname: String) -> Array:
	## The BASE idle group (pool element 0) — the resting-pose source. [] if none
	## are imported yet, in which case the draw falls back to the static token.
	if _idle_cache.has(nname):
		return _idle_cache[nname]
	var pool := _npc_idle_pool(nname)
	var frames: Array = pool[0] if pool.size() > 0 else []
	_idle_cache[nname] = frames
	return frames


func _npc_breathe_frames(nname: String) -> Array:
	## The crew member's resting BREATHE loop, cached. Globs the SEPARATE set
	## res://assets/sprites/crew/idle/<name>_breathe_<n>.png (sorted) — this is
	## NOT part of the gesture pool (which globs "<name>_idle*_<n>"; "breathe"
	## never matches "idle*", so the two stay independent). Returns a sorted
	## Array of {tex, feet}; [] when no breathe frames are imported yet, in which
	## case _draw_npc falls back to a static base idle frame (no deformation).
	## Missing/not-yet-imported files are skipped (ResourceLoader.exists +
	## null-guard) so this never errors while 5 agents generate frames concurrently.
	if _breathe_cache.has(nname):
		return _breathe_cache[nname]
	var dir := "res://assets/sprites/crew/idle"
	var base := nname.to_lower() + "_breathe"   # e.g. "hale_breathe"
	var names: Array = []
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".png") and f.begins_with(base):
				names.append(f)
	names.sort_custom(func(a, b): return _trail_idx(a) < _trail_idx(b))
	var frames: Array = []
	for f in names:
		var path := "%s/%s" % [dir, f]
		# only load once the .import exists, or load() errors on the raw png
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex != null:
				frames.append({"tex": tex, "feet": _feet_frac(tex)})
	_breathe_cache[nname] = frames
	return frames


func _trail_idx(fname: String) -> int:
	## trailing integer of a frame filename ("hale_breathe_10.png" -> 10), so frame
	## sets sort NUMERICALLY — a plain string sort puts "_10" before "_2".
	var base := fname.get_basename()   # strip ".png"
	var us := base.rfind("_")
	if us < 0:
		return 0
	var s := base.substr(us + 1)
	return int(s) if s.is_valid_int() else 0


func _feet_frac(tex: Texture2D) -> float:
	## fraction of the canvas height where the opaque figure's FEET are (1.0 =
	## feet flush with the canvas bottom). Falls back to 1.0 if the image can't
	## be read on the CPU.
	var im := tex.get_image()
	if im == null:
		return 1.0
	if im.is_compressed():
		im.decompress()   # get_used_rect() errors on a VRAM-compressed image
	var ch := im.get_height()
	if ch <= 0:
		return 1.0
	var ur := im.get_used_rect()
	return float(ur.position.y + ur.size.y) / float(ch)


func _draw_npc(nname: String, pos: Vector2, tint: Color) -> void:
	## the crew member, standing aboard: feet planted on the deck, a soft ground
	## shadow beneath them. When RESTING they play a slow, seamless looping
	## BREATHE animation (real frames — no code deformation); this is their state
	## almost all the time. The gesture plays once, slowly, when _update_npcs flips
	## them to "gesture" mode (see there), then they settle back to the breathe
	## loop. Each faces one FIXED direction: right by default, or left if listed in
	## NPC_FACE_LEFT (JUNO/MIRA) — the mirror is a clean reflection about the
	## figure's centre (see _draw_npc_frame), so feet + the symmetric ground shadow
	## stay planted. Fallback chain when frames aren't imported yet: breathe loop →
	## static base idle frame 0 → static token → generic tinted kit astronaut.
	# per-NPC height scale — HALE stands taller than the rest. Applied to the
	# draw height AND the ground shadow so a bigger body casts a bigger footprint;
	# the shadow stays pinned to the deck line, the figure grows UPWARD from it.
	var scale: float = NPC_SCALE.get(nname, 1.0)
	var tall := NPC_TALL * scale

	# feet sit at pos.y + 12 (the deck line); a soft elliptical ground shadow
	# hugs it, a hair above — two stacked low-alpha circles, flattened, exactly
	# like interior_player's, so the crew read as grounded on any floor
	_ci.draw_set_transform(pos + Vector2(0, 11.0), 0.0, Vector2(1.0, 0.42))
	_ci.draw_circle(Vector2.ZERO, 12.0 * scale, Color(0, 0, 0, 0.18))
	_ci.draw_circle(Vector2.ZERO, 9.0 * scale, Color(0, 0, 0, 0.28))
	_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var feet_y := pos.y + 12.0
	var flip: bool = NPC_FACE_LEFT.get(nname, false)
	var pool := _npc_idle_pool(nname)
	var anim: Dictionary = _npc_anim.get(nname, {})
	# gesturing only ever fires with a real pool (see _update_npcs), but guard anyway
	var gesturing: bool = anim.get("mode", "rest") == "gesture" and not pool.is_empty()
	if gesturing:
		# ONE slow pass through the RANDOMLY-PICKED gesture group, then
		# _update_npcs settles back to rest (both index the same group)
		var g: Array = pool[clampi(int(anim.get("anim", 0)), 0, pool.size() - 1)]
		var gi := int((_reactor - float(anim["gstart"])) * NPC_GESTURE_FPS)
		var f: Dictionary = g[clampi(gi, 0, g.size() - 1)]
		_draw_npc_frame(f["tex"], pos.x, feet_y, float(f["feet"]), flip, tall)
	else:
		# RESTING — play the slow breathe loop seamlessly if we have one
		var br := _npc_breathe_frames(nname)
		if not br.is_empty():
			var bi := int(_reactor * NPC_BREATHE_FPS) % br.size()
			var fb: Dictionary = br[bi]
			_draw_npc_frame(fb["tex"], pos.x, feet_y, float(fb["feet"]), flip, tall)
		elif not pool.is_empty():
			# no breathe frames yet — hold a static base idle frame 0 (plain)
			var f0: Dictionary = (pool[0] as Array)[0]
			_draw_npc_frame(f0["tex"], pos.x, feet_y, float(f0["feet"]), flip, tall)
		else:
			var tok := _npc_token(nname)
			if tok != null:
				# token canvases are bottom-anchored (feet at the canvas bottom)
				_draw_npc_frame(tok, pos.x, feet_y, 1.0, flip, tall)
			else:
				var tex: Texture2D = P["crew_npc"]
				var s2 := 34.0 * scale / tex.get_size().y
				_ci.draw_set_transform(Vector2(pos.x, feet_y - 17.0 * scale), 0.0,
					Vector2(s2, s2))
				_ci.draw_texture(tex, -tex.get_size() * 0.5, tint)
				_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ci.draw_string(_font, pos + Vector2(-40, -34), nname,
		HORIZONTAL_ALIGNMENT_CENTER, 80, 9, Color(0.55, 0.9, 1.0, 0.5))


func _draw_npc_frame(tex: Texture2D, cx: float, feet_y: float,
		feet_frac: float, flip := false, tall := NPC_TALL) -> void:
	## Draw one crew frame `tall` px tall (default NPC_TALL; larger for HALE), its
	## feet planted on feet_y (using the frame's own feet fraction, so transparent
	## padding never floats it, and so a taller figure grows UPWARD from the deck).
	## A plain, undistorted texture draw — motion comes from the frame sequence,
	## never from deforming a still. `flip` mirrors the figure horizontally ABOUT
	## its centre line cx: the reflection (translate 2*cx, x-scale -1, y-scale +1)
	## leaves feet_y and all vertical geometry untouched, so the crew turns to face
	## left without any positional shift.
	var s := tall / tex.get_size().y
	var dw := tex.get_size().x * s
	var top := feet_y - feet_frac * tall   # canvas top in world space
	if flip:
		_ci.draw_set_transform(Vector2(2.0 * cx, 0.0), 0.0, Vector2(-1.0, 1.0))
	_ci.draw_texture_rect(tex, Rect2(cx - dw * 0.5, top, dw, tall), false)
	if flip:
		_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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