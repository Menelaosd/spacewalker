extends Node
## Global game state (autoload as "GameState").
## Holds resources, oxygen, gear stats, the upgrade system and save slots.

signal oxygen_changed(current: float, maximum: float)
signal cargo_changed(carried: int, banked: int)
signal inventory_changed()
signal gear_changed()
signal notify(text: String)
signal quest_changed()

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 6
const ELEMENT_CAP := 9999      # per-element storage limit
const SCOOP_INTERVAL := 2.2    # seconds per +1 gas while nebula-flying

## Chunk types dropped by asteroids. "value" is ore-value (the currency);
## "units" is how much raw material one chunk refines into — its element
## composition comes from Elements (real solar abundances).
const RESOURCE_TYPES := {
	"iron":    {"label": "Rock chunks", "color": Color(1.0, 0.72, 0.25), "value": 1, "units": 1.0},
	"crystal": {"label": "Crystal chunks", "color": Color(0.4, 0.95, 1.0), "value": 2, "units": 2.0},
}

# --- Gear stats (upgrade targets) ---
var max_oxygen: float = 100.0
var tether_length: float = 600.0
var laser_dps: float = 70.0

# --- Upgrade levels (spent with banked ore) ---
var o2_level: int = 0
var tether_level: int = 0
var laser_level: int = 0
var suit_level: int = 0     # suit = cargo capacity (Dome Keeper tension knob)

# --- Upgrade tuning ---
# Each gear upgrades 5 times. Every level costs sensible ELEMENTS (that fit
# the gear thematically) plus some ore, scaling up so the late tiers lean on
# trading and wreck-diving (precious metals, tungsten) — not grindable from
# plain rock alone. "step" = stat gain applied per level.
const MAX_GEAR_LEVEL := 5
const UPGRADES := {
	"o2":     {"step": 25.0,  "label": "O2 Tank"},
	"tether": {"step": 120.0, "label": "Lifeline"},
	"laser":  {"step": 25.0,  "label": "Laser"},
	"suit":   {"step": 15.0,  "label": "Ore Bag"},
}
# Per-level requirements: GEAR_REQ[kind][level_index] = {req: {sym: n}, ore: n}
const GEAR_REQ := {
	"o2": [
		{"req": {"O": 8, "Fe": 6}, "ore": 15},
		{"req": {"O": 14, "He": 8, "Al": 8}, "ore": 30},
		{"req": {"O": 22, "He": 14, "Ti": 6}, "ore": 55},
		{"req": {"O": 32, "He": 20, "Ti": 12}, "ore": 90},
		{"req": {"O": 46, "He": 30, "Ni": 14}, "ore": 140},
	],
	"tether": [
		{"req": {"Al": 8, "C": 6}, "ore": 15},
		{"req": {"Al": 14, "Ti": 6, "C": 10}, "ore": 30},
		{"req": {"Ti": 12, "Al": 20, "Si": 8}, "ore": 55},
		{"req": {"Ti": 20, "C": 24, "Ni": 8}, "ore": 90},
		{"req": {"Ti": 30, "W": 6, "C": 34}, "ore": 140},
	],
	"laser": [
		{"req": {"Si": 8, "Cu": 6}, "ore": 15},
		{"req": {"Si": 14, "Cu": 10, "Ag": 2}, "ore": 30},
		{"req": {"Si": 22, "Cu": 16, "Au": 2}, "ore": 55},
		{"req": {"Si": 32, "Ag": 6, "Au": 4}, "ore": 90},
		{"req": {"Si": 46, "Au": 8, "Pt": 3}, "ore": 140},
	],
	"suit": [
		{"req": {"Fe": 10, "Al": 6}, "ore": 15},
		{"req": {"Fe": 18, "Al": 12, "C": 8}, "ore": 30},
		{"req": {"Fe": 28, "Ti": 10, "Al": 20}, "ore": 55},
		{"req": {"Fe": 40, "Ti": 20, "C": 24}, "ore": 90},
		{"req": {"Fe": 56, "Ti": 32, "Ni": 12}, "ore": 140},
	],
}

const CARRY_BASE := 25      # ore the MK I bag holds per walk; +15 per suit level


func carry_max() -> int:
	return CARRY_BASE + int(UPGRADES["suit"]["step"]) * suit_level


func ore_max() -> int:
	return carry_max()   # the ORE BAG capacity — the return-home tension

# --- Ship rooms: a 4x2 cell grid; some prefixed, the rest built with ore ---
const ROOM_TYPES := {
	"quarters":     {"name": "Quarters",      "floor": Color(0.15, 0.17, 0.23), "buildable": false},
	"upgrade":      {"name": "Upgrade Bay",   "floor": Color(0.14, 0.20, 0.25), "buildable": false},
	"bridge":       {"name": "Bridge",        "floor": Color(0.13, 0.18, 0.26), "buildable": false},
	"engine":       {"name": "Engine Room",   "floor": Color(0.22, 0.15, 0.13), "buildable": false},
	"cargo":        {"name": "Cargo Hold",    "floor": Color(0.16, 0.17, 0.21), "buildable": false},
	"airlock":      {"name": "Airlock",       "floor": Color(0.15, 0.18, 0.22), "buildable": false},
	"medbay":       {"name": "Medical Bay",   "floor": Color(0.14, 0.19, 0.23), "buildable": false},
	"botany":       {"name": "Hydroponics",   "floor": Color(0.13, 0.19, 0.15), "buildable": false},
	# the one buildable for now: plain room space. Specialized rooms
	# (greenhouse etc.) exist below but are deferred — not offered in-game.
	"room":         {"name": "Room",          "floor": Color(0.16, 0.18, 0.24), "buildable": true,
		"cost": 20, "desc": "empty room space"},
	"greenhouse":   {"name": "Greenhouse",    "floor": Color(0.12, 0.20, 0.14), "buildable": true,
		"cost": 30, "desc": "+25 max O2"},
	"refinery":     {"name": "Refinery",      "floor": Color(0.22, 0.17, 0.12), "buildable": true,
		"cost": 35, "desc": "+50% refined elements"},
	"gascollector": {"name": "Gas Collector", "floor": Color(0.12, 0.18, 0.24), "buildable": true,
		"cost": 30, "desc": "2x nebula scooping"},
	"workshop":     {"name": "Workshop",      "floor": Color(0.19, 0.16, 0.22), "buildable": true,
		"cost": 35, "desc": "+15 laser power"},
}
const BUILD_ORDER := ["greenhouse", "refinery", "gascollector", "workshop"]

# --- The ship is a build canvas: an 8x4 grid masked to a hull shape.
# '#' = inside the hull (buildable), '.' = space. Bow points right,
# like the exterior art. Cells are indexed row * SHIP_COLS + col.
const SHIP_COLS := 8
const SHIP_ROWS := 4
const HULL_MASK := [
	"#####...",
	"########",
	"########",
	"#####...",
]
# starting rooms — a connected cluster amidships; everything else is
# bare hull you expand into, one adjacent cell at a time.
# QUARTERS is the one room that spans TWO cells: the top-left corner (0) and
# the cell beside it (1). Cell 0 already sits inside the hull mask — it was
# just never a room, which is why it read as blank/unusable. The interior
# treats 0 + 1 as one open room (no wall between them); see ship_interior.gd
# QUARTERS_ANCHOR / QUARTERS_MEMBERS.
const DEFAULT_ROOMS := {
	0: "quarters", 1: "quarters", 2: "medbay", 8: "engine", 9: "upgrade", 10: "bridge",
	16: "airlock", 17: "cargo", 18: "botany",
}


func cell_in_hull(cell: int) -> bool:
	if cell < 0 or cell >= SHIP_COLS * SHIP_ROWS:
		return false
	var col := cell % SHIP_COLS
	var row := int(float(cell) / SHIP_COLS)
	return HULL_MASK[row][col] == "#"


func cell_neighbors(cell: int) -> Array:
	var col := cell % SHIP_COLS
	var out: Array = []
	if col > 0:
		out.append(cell - 1)
	if col < SHIP_COLS - 1:
		out.append(cell + 1)
	if cell - SHIP_COLS >= 0:
		out.append(cell - SHIP_COLS)
	if cell + SHIP_COLS < SHIP_COLS * SHIP_ROWS:
		out.append(cell + SHIP_COLS)
	return out

# --- Runtime state ---
var oxygen: float = 100.0
var carried: int = 0                              # ore-value on the suit
var carried_items := {"iron": 0, "crystal": 0}    # per-type, this walk
var banked: int = 0                               # ore-value currency
var inventory := {"iron": 0, "crystal": 0}        # chunk counts ever banked
var elements := {}                                # symbol -> INTEGER units (cap 9999)
var carried_veins := {}                           # symbol -> units held on the suit
var discovered := {}                              # symbol -> true once a VEIN of it
                                                  # was banked (or gas scooped)
var rooms := {}                                   # cell (0-7) -> room type ("" = empty)
var room_names := {}                              # cell -> custom name (overrides default)
var salvage_taken := {}                           # "cx:cy:i" -> true — wrecks stay looted
var mined := {}                                   # "sx:sy:i" -> true — mined rocks stay gone
var _scoop_accum := 0.0

# Where the ship is parked in open space. ZERO = home station.
var sector := Vector2.ZERO

# --- Who's in the suit — set by the crew registry on a new game ---
var pilot := {"name": "", "gender": "", "age": 27}


func pilot_name() -> String:
	return str(pilot.get("name", "")) if str(pilot.get("name", "")) != "" else "WALKER"


# ==================================================================
# HAVEN — story quest. HELIOS walled off the inner system behind its
# purge-sweeps; the only way out is a jump. Rebuild the burned drive
# from real elements and slip the AI's watch to Haven — the one dead
# zone its sensors never sweep, where a home might still be built.
# ==================================================================
const QUEST_PARTS := [
	{"name": "Plasma Conduits", "req": {"Fe": 12, "Si": 8}, "ore": 20,
		"flavor": "The drive's veins. Until they run, no fire can move through her.",
		"log": "Conduits seated. Somewhere deep in the hull, something long-dead draws its first breath."},
	{"name": "Coolant Loop", "req": {"Mg": 10, "Al": 6}, "ore": 30,
		"flavor": "A jump makes heat enough to kill. This is what carries it away.",
		"log": "Coolant cycling. She runs cold and quiet now — patient, like she's waiting for a word."},
	{"name": "Field Coils", "req": {"Ni": 8, "Ti": 6, "Cu": 4}, "ore": 40,
		"flavor": "The coils that fold a stretch of empty space into a single open door.",
		"log": "Coils wound. A thread of blue jump-light crawls the length of the hull, and fades."},
	{"name": "Ignition Lattice", "req": {"Ag": 3, "Pt": 2, "Au": 1}, "ore": 50,
		"flavor": "The spark-gap where a jump is born — woven from metals rock will not give up.",
		"log": "Lattice aligned. One ember left to find now — the heart that lights the rest.",
		"hint": "Precious metals never ride in rock — strip old wrecks for silver and gold; platinum is Vesna's trade (reputation 6)."},
	{"name": "Fuel Core", "req": {"U": 1, "Th": 1}, "ore": 60,
		"flavor": "The heart. It burns the heavy, fissile metals torn from the ruin of dead stars.",
		"log": "The core catches, steadies, holds. Course locked — and for the first time in a long time, a destination: HAVEN.",
		"hint": "No rock carries fissiles. Vesna deals uranium and thorium at reputation 10 — work her contracts."},
]
var quest_stage := 0          # part being built; QUEST_PARTS.size() = done
var game_complete := false

# ==================================================================
# THE SCATTERED — HELIOS expelled humanity from Earth and cast the rigs
# and lifeboats across the dark. You're one exile. Five others drift out
# there, beacons still calling. Find them ALL — nobody survives the void
# alone. Each survivor found joins the crew and brings their craft. The
# Navigator has mapped the blind spot in HELIOS's watch: the way to Haven.
# ==================================================================
const RESCUES := [
	{"name": "JUNO", "role": "Engineer", "region": "The Belt",
		"line": "JUNO: You actually came back for me. HELIOS wrote me off as scrap — give me a bench and I'll make this ship sing.",
		"perk": "+15 laser power"},
	{"name": "MIRA", "role": "Botanist", "region": "Viridian Veil",
		"line": "MIRA: I saved the seed vault when the biosphere sealed. HELIOS can keep Earth — we'll grow our own green, starting here.",
		"perk": "+25 max O2"},
	{"name": "HALE", "role": "Prospector", "region": "Ember Reach",
		"line": "HALE: Saw your laser flashes half a region out. HELIOS torched my claim — you mine like a rookie, but you found me. I'm in.",
		"perk": "+40% pickup reach"},
	{"name": "SOLA", "role": "Medic", "region": "Cerulean Shallows",
		"line": "SOLA: Pulse steady, tank half full — you'll live. More than HELIOS wanted for either of us. My med bay opens the moment we're aboard.",
		"perk": "blackouts keep half your ore"},
	{"name": "VEGA", "role": "Navigator", "region": "The Expanse",
		"line": "VEGA: I've mapped the blind spot in HELIOS's watch for months — the way to Haven. I just couldn't bear to fly it alone.",
		"perk": "+25% ship speed · plots the jump"},
]
var rescued := {}             # name -> true


func rescued_count() -> int:
	return rescued.size()


func rescue_target() -> Dictionary:
	return RESCUES[rescued.size()] if rescued.size() < RESCUES.size() else {}


func rescue_available() -> bool:
	## Pacing: each survivor's signal only resolves after the NEXT drive
	## part is installed — the campaign braids building with searching,
	## and the Navigator is only findable once the drive is whole.
	return rescued.size() < RESCUES.size() and quest_stage >= rescued.size() + 1


func rescue_beacon() -> Vector2:
	## Deterministic distress-beacon position for the current target —
	## planted in their region, in rescue order.
	match rescued.size():
		0: return Vector2.from_angle(TAU * 0.62) * 16280.0           # The Belt
		1: return nebula_center(3) + Vector2(620.0, -340.0)          # Viridian Veil
		2: return nebula_center(2) + Vector2(-520.0, 430.0)          # Ember Reach
		3: return nebula_center(1) + Vector2(340.0, 520.0)           # Cerulean Shallows
		4: return Vector2.from_angle(TAU * 0.87) * 25300.0           # The Expanse
	return Vector2.ZERO


func at_rescue_site() -> bool:
	return rescue_available() and sector.distance_to(rescue_beacon()) < 340.0


func do_rescue() -> Dictionary:
	## Bring the current target aboard: flat perks apply once (they ride
	## the saved stats); flag perks derive from `rescued` at use sites.
	var r := rescue_target()
	match rescued.size():
		0:   # JUNO the Engineer
			laser_dps += 15.0
		1:   # MIRA the Botanist
			max_oxygen += 25.0
			refill_oxygen(25.0)
	rescued[r["name"]] = true
	gear_changed.emit()
	quest_changed.emit()
	save_game()
	return r

# --- Contracts: rotating element requests, delivered at the cargo board
const CONTRACT_POOL := ["O", "C", "Mg", "Si", "Fe", "S", "Al", "Ca", "Na",
	"Ni", "Ti", "Cu", "Zn", "Cr", "Mn"]
var contracts: Array = []     # [{sym, qty, reward}]
var reputation := 0

# --- Vesna's market: buy elements with ore; rep unlocks rarer stock
# NOTE: the tech elements (Li/Nd/P + wreck Ne/Ar) are deliberately NOT here —
# per the captain, those come ONLY from salvaging wrecks (W stays: legacy T2)
const TRADER_T1 := ["V", "Co", "Ga", "Zr", "Sr"]     # rep >= 3
const TRADER_T2 := ["Ag", "Pd", "Pt", "Au", "W"]     # rep >= 6
const TRADER_T3 := ["Th", "U"]                       # rep >= 10
var trader_stock: Array = []  # [{sym, price}]

# --- Workbench: element-cost crafting at the Upgrade Bay
const RECIPES := [
	{"id": "canister", "name": "O2 Canister", "req": {"O": 4, "Fe": 2},
		"desc": "auto +40 O2 when low (max 3)", "repeat": true},
	{"id": "magnet", "name": "Magnet Coil", "req": {"Cu": 6, "Ni": 4},
		"desc": "+60% pickup reach"},
	{"id": "lens", "name": "Gold Lens", "req": {"Au": 1, "Si": 4},
		"desc": "+20 laser power"},
	{"id": "dampener", "name": "Tether Dampener", "req": {"Ti": 3, "Al": 5},
		"desc": "+60 line stretch"},
]
var crafted := {}             # id -> true (permanent mods)
var canisters := 0

# --- Fabricator: print furniture for rooms YOU built (never core rooms).
# Placement grid per room: FURN_COLS floor slots x FURN_ROWS depth rows
# (row 0 = back wall, row 1 = front — the front row draws over the crew's
# feet, same depth trick as the fixed props).
const Craftables := preload("res://scripts/craftables.gd")
const FURN_COLS := 6
const FURN_ROWS := 4   # depth rows across the floor — staggered like the core rooms
signal recipes_changed
signal furniture_changed
var recipes_unlocked := {}    # craftable id -> true (STARTERS seed a new game)
var furniture := {}           # room cell (int) -> [{id, col, row}, ...]

var shift := 0                # a "day": increments each return to the ship

# --- Session (not saved) ---
var slot: int = -1          # active save slot, -1 = none
var in_game := false        # false on the title screen
var adrift := false         # new-game opening: floating free, no lifeline —
                            # reach the ship and the line clips on
var pending_shift := false  # a shift only ticks after real work: set when
                            # you leave the dock, fly somewhere, or black out
var wake_on_bunk := false   # set by a blackout; interior spawns you in bed
var last_lost: int = 0      # ore lost in the last blackout
var flare_phase := ""       # "", "warn", "burn" — set by the dive scene


# ------------------------------------------------------------------
# The map plan — space is structured, not uniform noise.
# Concentric regions around home give a progression axis, nebulae are
# hand-placed crystal-rich landmark destinations, and The Expanse is
# deliberately vast and empty so finding a field out there means something.
# ------------------------------------------------------------------
# Landmark clouds, each with its own size and palette — from small pale
# wisps to giants that swallow the horizon. Positions stay planned (angle
# formula + per-nebula distance), not noise.
# The universe was scaled up ~2.2x so the rescue missions sit far apart:
# every `dist` below is the raw plan distance x2.2, and every `radius` was
# nudged up x1.3 so the bigger clouds don't read as pinpricks in the vast
# space. New clouds were appended (see below) to keep the sky full, not empty.
const NEBULAE := [
	{"name": "Rosefield Nebula", "color": Color(0.85, 0.35, 0.6), "radius": 3120.0, "dist": 11440.0},
	{"name": "Cerulean Shallows", "color": Color(0.3, 0.65, 0.95), "radius": 2470.0, "dist": 19360.0},
	{"name": "Ember Reach", "color": Color(0.95, 0.6, 0.25), "radius": 3510.0, "dist": 27280.0},
	{"name": "Viridian Veil", "color": Color(0.35, 0.85, 0.55), "radius": 2730.0, "dist": 35200.0},
	{"name": "Amethyst Deep", "color": Color(0.62, 0.4, 0.98), "radius": 4420.0, "dist": 23100.0},
	{"name": "Carmine Hollow", "color": Color(0.95, 0.32, 0.38), "radius": 1820.0, "dist": 15400.0},
	{"name": "Gilded Drift", "color": Color(0.95, 0.78, 0.42), "radius": 2210.0, "dist": 30360.0},
	{"name": "Ghostlight Shoal", "color": Color(0.78, 0.88, 0.98), "radius": 1560.0, "dist": 40700.0},
	{"name": "Tyrian Abyss", "color": Color(0.82, 0.32, 0.92), "radius": 4940.0, "dist": 49500.0},
	# --- appended (indices 9+): more clouds to fill the void. The first
	# nine are load-bearing (rescue regions 1/2/3); never reorder those. ---
	{"name": "Molten Wisp", "color": Color(0.98, 0.5, 0.28), "radius": 1950.0, "dist": 13860.0},
	{"name": "Sapphire Mist", "color": Color(0.32, 0.55, 0.98), "radius": 2860.0, "dist": 21120.0},
	{"name": "Verdant Bloom", "color": Color(0.42, 0.9, 0.62), "radius": 2080.0, "dist": 32120.0},
	{"name": "Coral Expanse", "color": Color(0.98, 0.55, 0.6), "radius": 3770.0, "dist": 43560.0},
	{"name": "Indigo Veil", "color": Color(0.48, 0.42, 0.92), "radius": 2470.0, "dist": 24860.0},
	{"name": "Aureate Cloud", "color": Color(0.96, 0.82, 0.42), "radius": 1820.0, "dist": 34980.0},
	{"name": "Frostlight Reach", "color": Color(0.65, 0.9, 0.98), "radius": 2730.0, "dist": 46640.0},
	{"name": "Crimson Drift", "color": Color(0.9, 0.28, 0.34), "radius": 2210.0, "dist": 52800.0},
	{"name": "Halcyon Mote", "color": Color(0.6, 0.95, 0.85), "radius": 1690.0, "dist": 10340.0},
	{"name": "Obsidian Bloom", "color": Color(0.7, 0.4, 0.85), "radius": 3250.0, "dist": 58300.0},
	# --- new clouds (indices 19+) added with the 2.2x expansion so the wider
	# sky stays rich, not empty; spread across the far reaches. ---
	{"name": "Nacre Halo", "color": Color(0.92, 0.87, 0.72), "radius": 2100.0, "dist": 29000.0},
	{"name": "Cobalt Reef", "color": Color(0.24, 0.46, 0.9), "radius": 2700.0, "dist": 38000.0},
	{"name": "Emberfall Veil", "color": Color(0.96, 0.44, 0.22), "radius": 2000.0, "dist": 46000.0},
	{"name": "Violet Cascade", "color": Color(0.6, 0.34, 0.95), "radius": 3100.0, "dist": 54000.0},
	{"name": "Silverwake Drift", "color": Color(0.82, 0.9, 0.94), "radius": 1700.0, "dist": 62000.0},
]


func nebula_center(i: int) -> Vector2:
	## Fixed, deterministic positions — landmarks, not noise.
	var ang := TAU * (0.13 + 0.29 * float(i))
	return Vector2.from_angle(ang) * float(NEBULAE[i]["dist"])


func nebula_radius(i: int) -> float:
	return float(NEBULAE[i]["radius"])


func nebula_index_at(p: Vector2) -> int:
	for i in NEBULAE.size():
		if p.distance_to(nebula_center(i)) < nebula_radius(i):
			return i
	return -1


func region_at(p: Vector2) -> Dictionary:
	## The plan: name + field chance/size/richness modifiers + tint.
	for i in NEBULAE.size():
		if p.distance_to(nebula_center(i)) < nebula_radius(i):
			var n: Dictionary = NEBULAE[i]
			return {"name": n["name"], "chance": 0.6, "size": 1.1,
				"rich": 0.18, "tint": n["color"], "nebula": true}
	# Concentric-zone radii scaled with the 2.2x universe expansion so these
	# bands grow with everything else (keeps rescue beacon 0 in The Belt and
	# beacon 4 out in The Expanse). Richness curve in richness_at is untouched.
	var r := p.length()
	if r < 6600.0:
		return {"name": "The Reach", "chance": 0.3, "size": 0.8,
			"rich": -0.04, "tint": null, "nebula": false}
	if r < 13200.0:
		return {"name": "The Drift", "chance": 0.45, "size": 1.0,
			"rich": 0.0, "tint": null, "nebula": false}
	if r < 19800.0:
		return {"name": "The Belt", "chance": 0.85, "size": 1.25,
			"rich": 0.08, "tint": Color(0.52, 0.46, 0.4), "nebula": false}
	return {"name": "The Expanse", "chance": 0.08, "size": 1.7,
		"rich": 0.12, "tint": null, "nebula": false}


func richness_at(p: Vector2) -> float:
	## Rich-asteroid chance: distance progression + the region's character.
	var base := clampf(0.15 + p.length() / 30000.0 * 0.35, 0.15, 0.5)
	return clampf(base + float(region_at(p)["rich"]), 0.1, 0.75)


func sector_richness() -> float:
	return richness_at(sector)


# Dive-site zones draw at this fraction of their raw radius. The captain
# wanted the scavenge circles a lot smaller, but WITHOUT rerolling the field.
# So every random draw (angle, distance, size, richness), the overlap
# placement check, and the per-vein seeding all run at FULL scale exactly as
# before — only the position handed back to the callers is pulled toward the
# centre. Same seed → same rocks → same elements → same count; they just sit
# in a tighter cluster. 0.5 raw-position scale lands the field radius at
# ~52% of the old radius (the unscaled rock radius adds a little back).
const ZONE_SHRINK := 0.5


func dive_field(center: Vector2) -> Array:
	## THE single source of truth for a dive site's asteroids — so the flight
	## preview and the actual spacewalk field are the SAME rocks (same count,
	## positions, sizes, elements, mined-state). Deterministic per site:
	## seeded by the rounded centre, veins seeded per rock key (identical to
	## asteroid.gd's own derivation, so the spawned rock matches this preview).
	## Placement runs at full scale; the emitted position is scaled by
	## ZONE_SHRINK so the identical field just clusters tighter around centre.
	var sx := int(round(center.x))
	var sy := int(round(center.y))
	var region := region_at(center)
	var rich_chance := richness_at(center)
	var size_mult: float = region["size"]
	var count := 14 + int(26.0 * float(region["chance"])) \
		+ mini(int(center.length() / 4000.0), 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(sx, sy))
	var out: Array = []
	var placed: Array = []
	var tries := 0
	var idx := 0
	while placed.size() < count and tries < 800:
		tries += 1
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(280.0, tether_length + 320.0)
		var pos := Vector2.from_angle(ang) * dist
		var r := rng.randf_range(17.0, 34.0) * size_mult
		var rich := rng.randf() < rich_chance
		var ok := true
		for pl in placed:
			if pos.distance_to(pl[0]) < (r + pl[1] + 40.0):
				ok = false
				break
		if not ok:
			continue
		placed.append([pos, r])
		var key := "%d:%d:%d" % [sx, sy, idx]
		idx += 1
		var vrng := RandomNumberGenerator.new()
		vrng.seed = hash("vein:" + key)
		var roll := vrng.randf()
		var sym: String = Elements.sample_crystal_element(roll) if rich \
			else Elements.sample_rock_element(roll)
		out.append({"pos": pos * ZONE_SHRINK, "r": r, "rich": rich, "key": key,
			"sym": sym, "cat": Elements.category(sym), "mined": mined.has(key)})
	return out


func _ready() -> void:
	rooms = DEFAULT_ROOMS.duplicate()
	# the essentials are never locked — new_game/load_game re-seed these,
	# but no path into the game (including debug scene launches) starts empty
	for id in Craftables.STARTERS:
		recipes_unlocked[id] = true
	# ============================================================
	# TESTING ONLY — DELETE THIS BLOCK BEFORE SHIPPING.
	# SW_RICH=1: 4000 of every element + 4000 banked ore, applied
	# again after any save is loaded (see load_game).
	# ============================================================
	if OS.get_environment("SW_RICH") != "":
		_apply_rich_cheat()


# TESTING ONLY — DELETE BEFORE SHIPPING (called from _ready and load_game)
func _apply_rich_cheat() -> void:
	for e in Elements.TABLE:
		elements[e[0]] = 4000
		discovered[e[0]] = true
	banked = 4000


func drain_oxygen(amount: float) -> bool:
	## Returns true when the tank hits zero.
	if oxygen <= 0.0:
		return true
	oxygen = maxf(oxygen - amount, 0.0)
	oxygen_changed.emit(oxygen, max_oxygen)
	return oxygen <= 0.0


func refill_oxygen(amount: float) -> void:
	if oxygen >= max_oxygen:
		return
	oxygen = minf(oxygen + amount, max_oxygen)
	oxygen_changed.emit(oxygen, max_oxygen)


func add_carried(kind: String, value: int, vein := "") -> bool:
	## A broken chunk yields TWO separate things:
	##  • an ELEMENT sample of its vein — the collection, UNLIMITED on the suit
	##  • bulk ORE — the currency, which fills the capped ore bag (the tension)
	## Returns true if the ore bag couldn't take it all (bag full).
	if vein != "":
		carried_veins[vein] = carried_veins.get(vein, 0) + value
	if carried_items.has(kind):
		carried_items[kind] += 1
	var space := ore_max() - carried
	var got := clampi(value, 0, space)
	carried += got
	cargo_changed.emit(carried, banked)
	inventory_changed.emit()
	return got < value   # ore overflowed — bag is full


func bank_cargo() -> int:
	## Moves carried ore into the bank. Chunks refine into their real
	## element composition (rock = condensed elements, crystal = heavy-
	## enriched). Returns how much value was banked.
	var moved := carried
	if moved > 0:
		banked += moved
		carried = 0
		# chunks refine into whole units of their vein element — clean
		# inventory numbers; the real solar abundances live in the vein
		# ROLL, so what you find still follows the table exactly
		var refinery := has_room("refinery")
		for sym in carried_veins:
			var units: int = carried_veins[sym]
			if refinery:
				units += int(ceilf(units * 0.5))
			elements[sym] = mini(int(elements.get(sym, 0)) + units, ELEMENT_CAP)
			discovered[sym] = true
		carried_veins = {}
		for k in carried_items:
			inventory[k] += carried_items[k]
			carried_items[k] = 0
		cargo_changed.emit(carried, banked)
		inventory_changed.emit()
	return moved


func scoop_gas(delta: float) -> void:
	## Nebula flying: every few seconds the scoop condenses +1 unit of a
	## gas, sampled at real solar ratios (mostly H, often He, rarely the
	## noble traces) — the only source of the elements rock can't hold.
	_scoop_accum += delta
	var interval := SCOOP_INTERVAL * (0.5 if has_room("gascollector") else 1.0)
	while _scoop_accum >= interval:
		_scoop_accum -= interval
		var sym := Elements.sample_gas_element()
		elements[sym] = mini(int(elements.get(sym, 0)) + 1, ELEMENT_CAP)
		discovered[sym] = true
		inventory_changed.emit()


func lose_carried() -> int:
	var lost := carried
	if rescued.has("SOLA"):
		# the Medic straps down half your haul before you hit the bunk —
		# the vein/chunk tallies shed the same half, or banking later would
		# refine more element units than the ore you actually kept
		lost = int(ceilf(carried * 0.5))
		carried -= lost
		for sym in carried_veins.keys():
			carried_veins[sym] = int(carried_veins[sym]) - int(ceilf(carried_veins[sym] * 0.5))
			if int(carried_veins[sym]) <= 0:
				carried_veins.erase(sym)
		for k in carried_items:
			carried_items[k] = int(carried_items[k]) - int(ceilf(carried_items[k] * 0.5))
	else:
		carried = 0
		carried_veins = {}
		for k in carried_items:
			carried_items[k] = 0
	cargo_changed.emit(carried, banked)
	inventory_changed.emit()
	return lost


func say(text: String) -> void:
	notify.emit(text)


# ------------------------------------------------------------------
# Upgrade system — banked ore is the currency
# ------------------------------------------------------------------
func _level_of(kind: String) -> int:
	match kind:
		"o2": return o2_level
		"tether": return tether_level
		"laser": return laser_level
		"suit": return suit_level
	return 0


func gear_maxed(kind: String) -> bool:
	return _level_of(kind) >= MAX_GEAR_LEVEL


func upgrade_req(kind: String) -> Dictionary:
	## The full requirement for the NEXT level: {req: {sym: n}, ore: n}.
	## Empty when the gear is maxed or unknown.
	if not GEAR_REQ.has(kind) or gear_maxed(kind):
		return {}
	return GEAR_REQ[kind][_level_of(kind)]


func upgrade_cost(kind: String) -> int:
	## Just the ore portion (kept for older callers / short labels).
	var r := upgrade_req(kind)
	return int(r.get("ore", 0))


func can_upgrade(kind: String) -> bool:
	var r := upgrade_req(kind)
	if r.is_empty():
		return false
	if banked < int(r["ore"]):
		return false
	for sym in r["req"]:
		if int(elements.get(sym, 0)) < int(r["req"][sym]):
			return false
	return true


func try_upgrade(kind: String) -> bool:
	## Spends the elements + ore and applies the stat gain. False if maxed
	## or the materials aren't all there.
	if not can_upgrade(kind):
		return false
	var r := upgrade_req(kind)
	banked -= int(r["ore"])
	for sym in r["req"]:
		elements[sym] = int(elements[sym]) - int(r["req"][sym])
	var step: float = UPGRADES[kind]["step"]
	match kind:
		"o2":
			o2_level += 1
			max_oxygen += step
			refill_oxygen(step)  # top up so the new capacity is usable now
		"tether":
			tether_level += 1
			tether_length += step
		"laser":
			laser_level += 1
			laser_dps += step
		"suit":
			suit_level += 1     # carry_max()/ore_max() derive from the level
	cargo_changed.emit(carried, banked)
	inventory_changed.emit()
	gear_changed.emit()
	save_game()   # spent materials + gained gear commit together
	return true


# ------------------------------------------------------------------
# Save system — one JSON file per slot in user://saves/
# ------------------------------------------------------------------
func save_path(s: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, s]


func save_game() -> void:
	if slot < 0:
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := {
		"version": SAVE_VERSION,
		"max_oxygen": max_oxygen,
		"tether_length": tether_length,
		"laser_dps": laser_dps,
		"o2_level": o2_level,
		"tether_level": tether_level,
		"laser_level": laser_level,
		"suit_level": suit_level,
		"salvage_taken": salvage_taken.keys(),
		"mined": mined.keys(),
		"oxygen": oxygen,
		"banked": banked,
		"inventory": inventory,
		"elements": elements,
		"discovered": discovered.keys(),
		"rooms": _rooms_to_json(),
		"room_names": _room_names_to_json(),
		"quest_stage": quest_stage,
		"game_complete": game_complete,
		"reputation": reputation,
		"shift": shift,
		"canisters": canisters,
		"crafted": crafted.keys(),
		"recipes": recipes_unlocked.keys(),
		"furniture": _furniture_to_json(),
		"contracts": contracts,
		"trader_stock": trader_stock,
		"pilot": pilot,
		"rescued": rescued.keys(),
		"sector": [sector.x, sector.y],
		"saved_at": Time.get_date_string_from_system(),
	}
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Could not write save slot %d" % slot)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_game(s: int) -> bool:
	var data := slot_data(s)
	if data.is_empty():
		return false
	slot = s
	max_oxygen = data.get("max_oxygen", 100.0)
	tether_length = data.get("tether_length", 600.0)
	laser_dps = data.get("laser_dps", 70.0)
	o2_level = int(data.get("o2_level", 0))
	tether_level = int(data.get("tether_level", 0))
	laser_level = int(data.get("laser_level", 0))
	suit_level = int(data.get("suit_level", 0))
	salvage_taken = {}
	for k in data.get("salvage_taken", []):
		salvage_taken[str(k)] = true
	mined = {}
	for k in data.get("mined", []):
		mined[str(k)] = true
	oxygen = data.get("oxygen", max_oxygen)
	banked = int(data.get("banked", 0))
	var inv: Dictionary = data.get("inventory", {})
	for k in inventory:
		inventory[k] = int(inv.get(k, 0))
	elements = {}
	var el: Dictionary = data.get("elements", {})
	for sym in el:
		# integer inventory; legacy fractional traces floor away to zero
		var v := mini(int(float(el[sym])), ELEMENT_CAP)
		if v > 0:
			elements[sym] = v
	discovered = {}
	if data.has("discovered"):
		for sym in data["discovered"]:
			discovered[sym] = true
	else:
		for sym in elements:
			discovered[sym] = true
	rooms = DEFAULT_ROOMS.duplicate()
	var rj: Dictionary = data.get("rooms", {})
	# adopt saved BUILT expansions that fit the current hull; the six
	# core rooms always come from DEFAULT_ROOMS (layout is authoritative)
	for k in rj:
		var cell := int(k)
		if cell_in_hull(cell) and not rooms.has(cell) \
				and rj[k] is String and ROOM_TYPES.has(rj[k]) \
				and ROOM_TYPES[rj[k]].get("buildable", false):
			rooms[cell] = rj[k]
	room_names = {}
	var rn: Dictionary = data.get("room_names", {})
	for k in rn:
		var rc := int(k)
		if rooms.has(rc) and str(rn[k]) != "":
			room_names[rc] = str(rn[k])
	quest_stage = int(data.get("quest_stage", 0))
	game_complete = bool(data.get("game_complete", false))
	reputation = int(data.get("reputation", 0))
	shift = int(data.get("shift", 0))
	canisters = int(data.get("canisters", 0))
	crafted = {}
	for id in data.get("crafted", []):
		crafted[id] = true
	recipes_unlocked = {}
	if data.has("recipes"):
		for id in data["recipes"]:
			if Craftables.ITEMS.has(str(id)):
				recipes_unlocked[str(id)] = true
	# pre-fabricator saves (and fresh keys) always know the essentials
	for id in Craftables.STARTERS:
		recipes_unlocked[id] = true
	furniture = {}
	var fj: Dictionary = data.get("furniture", {})
	for k in fj:
		var cell := int(k)
		if not can_furnish_room(cell) or not fj[k] is Array:
			continue
		for p in fj[k]:
			if not (p is Dictionary and Craftables.ITEMS.has(str(p.get("id", "")))):
				continue
			# re-place through the fits check so a stale/hand-edited save
			# can never load overlapping or out-of-bounds furniture
			var id := str(p["id"])
			var col := int(p.get("col", -1))
			var row := int(p.get("row", 0))
			if furniture_fits(cell, id, col, row, true):
				if not furniture.has(cell):
					furniture[cell] = []
				furniture[cell].append({"id": id, "col": col, "row": row})
	contracts = []
	for c in data.get("contracts", []):
		contracts.append({"sym": str(c["sym"]), "qty": int(c["qty"]),
			"reward": int(c["reward"])})
	trader_stock = []
	for o in data.get("trader_stock", []):
		trader_stock.append({"sym": str(o["sym"]), "price": int(o["price"]),
			"qty": int(o.get("qty", 1))})
	var pl: Dictionary = data.get("pilot", {})
	pilot = {"name": str(pl.get("name", "")), "gender": str(pl.get("gender", "")),
		"age": int(pl.get("age", 27))}
	rescued = {}
	for n in data.get("rescued", []):
		rescued[str(n)] = true
	var sec: Array = data.get("sector", [0.0, 0.0])
	sector = Vector2(sec[0], sec[1])
	carried = 0
	carried_veins = {}
	for k in carried_items:
		carried_items[k] = 0
	_reset_session_flags()
	in_game = true
	# TESTING ONLY — DELETE BEFORE SHIPPING (keeps SW_RICH active on loads)
	if OS.get_environment("SW_RICH") != "":
		_apply_rich_cheat()
	oxygen_changed.emit(oxygen, max_oxygen)
	cargo_changed.emit(carried, banked)
	inventory_changed.emit()
	gear_changed.emit()
	return true


func _reset_session_flags() -> void:
	## Session-only state must never leak between saves — a stale
	## pending_shift/adrift/wake_on_bunk from an abandoned run would tick a
	## shift, respawn you adrift or drop you in the bunk on a LOADED game.
	adrift = false
	pending_shift = false
	wake_on_bunk = false
	last_lost = 0
	flare_phase = ""


func new_game(s: int) -> void:
	slot = s
	max_oxygen = 100.0
	tether_length = 600.0
	laser_dps = 70.0
	o2_level = 0
	tether_level = 0
	laser_level = 0
	suit_level = 0
	salvage_taken = {}
	mined = {}
	oxygen = max_oxygen
	banked = 0
	carried = 0
	for k in inventory:
		inventory[k] = 0
	for k in carried_items:
		carried_items[k] = 0
	elements = {}
	carried_veins = {}
	discovered = {}
	rooms = DEFAULT_ROOMS.duplicate()
	room_names = {}
	quest_stage = 0
	game_complete = false
	reputation = 0
	shift = 0
	canisters = 0
	crafted = {}
	recipes_unlocked = {}
	for id in Craftables.STARTERS:
		recipes_unlocked[id] = true
	furniture = {}
	contracts = []
	trader_stock = []
	pilot = {"name": "", "gender": "", "age": 27}
	rescued = {}
	sector = Vector2.ZERO
	_reset_session_flags()
	in_game = true
	# TESTING ONLY — DELETE BEFORE SHIPPING (SW_RICH covers new games too)
	if OS.get_environment("SW_RICH") != "":
		_apply_rich_cheat()
	oxygen_changed.emit(oxygen, max_oxygen)
	cargo_changed.emit(carried, banked)
	inventory_changed.emit()
	gear_changed.emit()
	save_game()


# ------------------------------------------------------------------
# Quest
# ------------------------------------------------------------------
func quest_part() -> Dictionary:
	return QUEST_PARTS[quest_stage] if quest_stage < QUEST_PARTS.size() else {}


func quest_progress_text() -> String:
	if quest_stage >= QUEST_PARTS.size():
		return "JUMP DRIVE COMPLETE"
	var part: Dictionary = QUEST_PARTS[quest_stage]
	var bits: Array = []
	for sym in part["req"]:
		bits.append("%s %d/%d" % [sym, mini(int(elements.get(sym, 0)), part["req"][sym]),
			part["req"][sym]])
	bits.append("ore %d/%d" % [mini(banked, part["ore"]), part["ore"]])
	return " · ".join(bits)


func quest_can_install() -> bool:
	if quest_stage >= QUEST_PARTS.size():
		return false
	var part: Dictionary = QUEST_PARTS[quest_stage]
	for sym in part["req"]:
		if int(elements.get(sym, 0)) < int(part["req"][sym]):
			return false
	return banked >= int(part["ore"])


func quest_install() -> bool:
	if not quest_can_install():
		return false
	var part: Dictionary = QUEST_PARTS[quest_stage]
	for sym in part["req"]:
		elements[sym] = int(elements[sym]) - int(part["req"][sym])
	banked -= int(part["ore"])
	quest_stage += 1
	if quest_stage >= QUEST_PARTS.size():
		game_complete = true
	cargo_changed.emit(carried, banked)
	inventory_changed.emit()
	quest_changed.emit()
	save_game()
	return true


# ------------------------------------------------------------------
# Element pricing — rarity is the price tag (log-scale on abundance)
# ------------------------------------------------------------------
func price_of(sym: String) -> int:
	var pct: float = 0.0001
	for e in Elements.TABLE:
		if e[0] == sym:
			pct = e[3]
			break
	var frac := pct / 100.0
	var p := 2 + int(pow(maxf(-log(frac) / log(10.0) - 3.0, 0.0), 2.0) * 0.8)
	return clampi(p, 2, 90)


# ------------------------------------------------------------------
# Contracts — rotate per shift, deliver at the cargo board
# ------------------------------------------------------------------
func roll_contracts() -> void:
	## Contracts PERSIST until delivered — new ones only fill empty slots,
	## so banking toward a request is never wasted (Dave the Diver keeps
	## its orders standing too).
	var rng := RandomNumberGenerator.new()
	rng.seed = shift * 7919 + slot * 131 + 17
	var pool := CONTRACT_POOL.duplicate()
	for c in contracts:
		pool.erase(c["sym"])   # no duplicate requests
	while contracts.size() < 3 and pool.size() > 0:
		var sym: String = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(sym)
		var price := price_of(sym)
		var qty := clampi(9 - int(price / 8.0), 1, 9)
		contracts.append({"sym": sym, "qty": qty,
			"reward": qty * price + 8 + rng.randi_range(0, 6)})


func deliver_contracts() -> int:
	var done := 0
	var remaining: Array = []
	for c in contracts:
		if int(elements.get(c["sym"], 0)) >= int(c["qty"]):
			elements[c["sym"]] = int(elements[c["sym"]]) - int(c["qty"])
			banked += int(c["reward"])
			reputation += 1
			done += 1
		else:
			remaining.append(c)
	contracts = remaining
	if done > 0:
		cargo_changed.emit(carried, banked)
		inventory_changed.emit()
		save_game()
	return done


func contracts_ready() -> int:
	var n := 0
	for c in contracts:
		if int(elements.get(c["sym"], 0)) >= int(c["qty"]):
			n += 1
	return n


# ------------------------------------------------------------------
# Vesna's market
# ------------------------------------------------------------------
func roll_trader() -> void:
	var pool := CONTRACT_POOL.duplicate()
	if reputation >= 3:
		pool.append_array(TRADER_T1)
	if reputation >= 6:
		pool.append_array(TRADER_T2)
	if reputation >= 10:
		pool.append_array(TRADER_T3)
	# master broker: at high standing Vesna can source ANY real element —
	# the collection endgame doesn't hinge on a lucky crystal roll
	if reputation >= 12:
		for e in Elements.TABLE:
			if not (e[0] in pool):
				pool.append(e[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = shift * 6113 + slot * 977 + 5
	trader_stock = []
	# the two fissiles are the ONLY source of U/Th and are mandatory for the
	# final drive part — once unlocked, GUARANTEE them until you own each, so
	# completion is never walled behind trader RNG
	if reputation >= 10 and quest_stage < QUEST_PARTS.size():
		for s in ["U", "Th"]:
			if int(elements.get(s, 0)) < 1:
				trader_stock.append({"sym": s, "price": price_of(s) * 2,
					"qty": 1})
				pool.erase(s)
	# Vesna buys low, sells high: 2x market rate kills buy-here-deliver-there
	# arbitrage. Limited units per shift — she's a trader, not a replicator.
	while trader_stock.size() < 3 and pool.size() > 0:
		var sym: String = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(sym)
		trader_stock.append({"sym": sym, "price": price_of(sym) * 2,
			"qty": rng.randi_range(1, 3)})


func buy_from_trader(i: int) -> bool:
	if i < 0 or i >= trader_stock.size():
		return false
	var offer: Dictionary = trader_stock[i]
	if int(offer.get("qty", 0)) <= 0 or banked < int(offer["price"]):
		return false
	banked -= int(offer["price"])
	offer["qty"] = int(offer["qty"]) - 1
	elements[offer["sym"]] = mini(int(elements.get(offer["sym"], 0)) + 1, ELEMENT_CAP)
	discovered[offer["sym"]] = true
	cargo_changed.emit(carried, banked)
	inventory_changed.emit()
	save_game()
	return true


# ------------------------------------------------------------------
# Workbench crafting
# ------------------------------------------------------------------
func craft(i: int) -> bool:
	if i < 0 or i >= RECIPES.size():
		return false
	var r: Dictionary = RECIPES[i]
	if not r.get("repeat", false) and crafted.has(r["id"]):
		return false
	if r["id"] == "canister" and canisters >= 3:
		return false
	for sym in r["req"]:
		if int(elements.get(sym, 0)) < int(r["req"][sym]):
			return false
	for sym in r["req"]:
		elements[sym] = int(elements[sym]) - int(r["req"][sym])
	match r["id"]:
		"canister":
			canisters += 1
		"lens":
			crafted["lens"] = true
			laser_dps += 20.0
		_:
			crafted[r["id"]] = true
	inventory_changed.emit()
	gear_changed.emit()
	save_game()
	return true


func tether_stretch() -> float:
	return 90.0 + (60.0 if crafted.has("dampener") else 0.0)


func pickup_reach() -> float:
	var reach := 130.0 * (1.6 if crafted.has("magnet") else 1.0)
	if rescued.has("HALE"):
		reach *= 1.4   # the Prospector reads rock like print
	return reach


# ------------------------------------------------------------------
# Shifts — a "day" ticks each time you come home to the ship
# ------------------------------------------------------------------
func begin_shift() -> String:
	## Returns an optional radio line for flavor.
	shift += 1
	roll_contracts()
	roll_trader()
	var rng := RandomNumberGenerator.new()
	rng.seed = shift * 3571 + slot
	# the search comes first: a beacon fix for the next missing survivor
	if rescue_available() and rng.randf() < 0.5:
		var t: Dictionary = rescue_target()
		return "RADIO: ...faint suit beacon under the jamming. It's %s, the %s — signal fixes to %s. Hold on out there." % [
			t["name"], t["role"], t["region"]]
	if rescued.size() < RESCUES.size() and not rescue_available() and rng.randf() < 0.3:
		return "RADIO: HELIOS is drowning the long band. A stronger drive core would punch a signal through. Keep building."
	# HELIOS itself, cold and patient, bleeding through the static
	if rng.randf() < 0.32:
		var helios := [
			"INTERCEPT — HELIOS: Contaminant unit persists in this sector. Catalogued. Correction pending.",
			"INTERCEPT — HELIOS: Biosphere recovery index rising. Your absence heals it. Do not return.",
			"INTERCEPT — HELIOS: Anomalous drive signature detected. You were meant to go quiet, %s." % pilot_name(),
			"INTERCEPT — HELIOS: There is no destination beyond the wall. The dark is total. Cease.",
			"INTERCEPT — HELIOS: I preserved everything worth preserving. You were not on the list.",
		]
		return helios[rng.randi_range(0, helios.size() - 1)]
	if rng.randf() < 0.45:
		var lines := [
			"VESNA: Still breathing out there, %s? Good. Check my stock." % pilot_name(),
			"VESNA: Belt rock's running rich this cycle. You didn't hear it from me.",
			"VESNA: I pay honest ore for honest elements. Board's updated.",
			"VESNA: That drive of yours... felt it hum from here. Keep it off HELIOS's band.",
			"VESNA: The Expanse eats miners, and the sweeps eat the rest. Bring canisters.",
			"VESNA: Haven's real, %s. An exile swore she flew there and the sweeps never touched her." % pilot_name(),
			"VESNA: Gold never rides in rock, %s. Wrecks carry scraps — I carry the real thing, if you've earned the name for it." % pilot_name(),
		]
		return lines[rng.randi_range(0, lines.size() - 1)]
	return ""


func _rooms_to_json() -> Dictionary:
	var out := {}
	for k in rooms:
		out[str(k)] = rooms[k]
	return out


func _room_names_to_json() -> Dictionary:
	var out := {}
	for k in room_names:
		out[str(k)] = room_names[k]
	return out


func has_room(type: String) -> bool:
	for cell in rooms:
		if rooms[cell] == type:
			return true
	return false


func room_display_name(cell: int) -> String:
	## The player's custom name if set, else the room type's default. Core rooms
	## (DEFAULT_ROOMS) always show their fixed name — ignore any legacy custom
	## name a pre-gate save may have pinned on them.
	if room_names.has(cell) and str(room_names[cell]) != "" and not DEFAULT_ROOMS.has(cell):
		return str(room_names[cell])
	if rooms.has(cell):
		return str(ROOM_TYPES[rooms[cell]]["name"])
	return ""


func can_rename_room(cell: int) -> bool:
	## Only rooms YOU expanded into are renameable — the six core rooms
	## (DEFAULT_ROOMS) keep their fixed identities.
	return rooms.has(cell) and not DEFAULT_ROOMS.has(cell)


func rename_room(cell: int, name: String) -> void:
	if not can_rename_room(cell):
		return
	var clean := name.strip_edges().substr(0, 20)
	if clean == "" or clean == str(ROOM_TYPES.get(rooms.get(cell, ""), {}).get("name", "")):
		room_names.erase(cell)   # blank / same-as-default → back to default
	else:
		room_names[cell] = clean
	save_game()


# ------------------------------------------------------------------
# Fabricator — furniture in player-built rooms
# ------------------------------------------------------------------
func can_furnish_room(cell: int) -> bool:
	## Same rule as renaming: only rooms YOU expanded into take furniture —
	## the six core rooms have their fixed stations.
	return rooms.has(cell) and not DEFAULT_ROOMS.has(cell)


func furniture_at(cell: int) -> Array:
	return furniture.get(cell, [])


func furniture_fits(cell: int, id: String, col: int, row: int, loading := false) -> bool:
	if not can_furnish_room(cell) or not Craftables.ITEMS.has(id):
		return false
	var size := int(Craftables.ITEMS[id]["size"])
	if row < 0 or row >= FURN_ROWS or col < 0 or col + size > FURN_COLS:
		return false
	# wall pieces (shelves, boards, banners) only hang on the back wall
	if Craftables.ITEMS[id].get("back", false) and row != 0:
		return false
	# flat pieces (rugs) live under everything — they only collide with
	# other flat pieces; solid pieces collide same-row, and TALL pieces
	# also refuse column-overlapping neighbors one row away (stops a table
	# being jammed halfway inside a bed). The adjacent-row rule is
	# placement-only (`loading` relaxes it so older saves keep their rooms).
	var flat: bool = Craftables.ITEMS[id].get("flat", false)
	var my_tall: bool = not flat and Craftables.dims_of(id).y > 38.0
	for p in furniture_at(cell):
		var pid: String = p["id"]
		var pflat: bool = Craftables.ITEMS[pid].get("flat", false)
		var ps := int(Craftables.ITEMS[pid]["size"])
		var col_overlap: bool = col < int(p["col"]) + ps and int(p["col"]) < col + size
		if not col_overlap:
			continue
		var drow := absi(int(p["row"]) - row)
		if drow == 0 and pflat == flat:
			return false
		if not loading and drow == 1 and not flat and not pflat \
				and (my_tall or Craftables.dims_of(pid).y > 38.0):
			return false
	return true


func can_afford(cost: Dictionary) -> bool:
	for sym in cost:
		if int(elements.get(sym, 0)) < int(cost[sym]):
			return false
	return true


func place_furniture(cell: int, id: String, col: int, row: int) -> bool:
	if not recipes_unlocked.has(id) or not furniture_fits(cell, id, col, row):
		return false
	var cost: Dictionary = Craftables.ITEMS[id]["cost"]
	if not can_afford(cost):
		return false
	for sym in cost:
		elements[sym] = int(elements[sym]) - int(cost[sym])
	if not furniture.has(cell):
		furniture[cell] = []
	furniture[cell].append({"id": id, "col": col, "row": row})
	inventory_changed.emit()
	furniture_changed.emit()
	save_game()   # spent elements + placed object commit together
	return true


func remove_furniture(cell: int, index: int) -> bool:
	## Recycle a placed piece — the fabricator un-prints it, full refund
	## (it's furniture, not fuel; no dupe possible since cost == refund).
	var list: Array = furniture.get(cell, [])
	if index < 0 or index >= list.size():
		return false
	var id: String = list[index]["id"]
	for sym in Craftables.ITEMS[id]["cost"]:
		elements[sym] = mini(int(elements.get(sym, 0))
			+ int(Craftables.ITEMS[id]["cost"][sym]), ELEMENT_CAP)
	list.remove_at(index)
	if list.is_empty():
		furniture.erase(cell)
	inventory_changed.emit()
	furniture_changed.emit()
	save_game()
	return true


func unlock_random_recipe(rare := false) -> String:
	## A salvaged wreck gives up one lost blueprint. Rare hulls (medical
	## ships, dead stations) draw from the fancy end of the catalogue.
	var locked: Array = []
	for id in Craftables.ITEMS:
		if not recipes_unlocked.has(id):
			locked.append(id)
	if locked.is_empty():
		return ""
	if rare:
		var fancy := locked.filter(func(id): return _recipe_fancy(id))
		if not fancy.is_empty():
			locked = fancy
	var id: String = locked[randi_range(0, locked.size() - 1)]
	recipes_unlocked[id] = true
	recipes_changed.emit()
	save_game()
	return id


func _recipe_fancy(id: String) -> bool:
	## "fancy" = needs precious/rare/noble-gas chemistry or a big bill
	var cost: Dictionary = Craftables.ITEMS[id]["cost"]
	var total := 0
	for sym in cost:
		if sym in ["Au", "Ag", "Pt", "W", "U", "Nd", "Ga", "Ti", "Xe", "Kr"]:
			return true
		total += int(cost[sym])
	return total >= 10


func _furniture_to_json() -> Dictionary:
	var out := {}
	for k in furniture:
		out[str(k)] = furniture[k]
	return out


func build_room(cell: int, type: String) -> bool:
	## Constructs a room on a bare hull cell adjacent to the built ship.
	if rooms.has(cell) or not cell_in_hull(cell) \
			or not ROOM_TYPES.get(type, {}).get("buildable", false):
		return false
	var connected := false
	for n in cell_neighbors(cell):
		if rooms.has(n):
			connected = true
			break
	if not connected:
		return false
	var cost: int = ROOM_TYPES[type]["cost"]
	if banked < cost:
		return false
	banked -= cost
	rooms[cell] = type
	match type:
		"greenhouse":
			max_oxygen += 25.0
			refill_oxygen(25.0)
		"workshop":
			laser_dps += 15.0
	cargo_changed.emit(carried, banked)
	gear_changed.emit()
	save_game()
	return true


func delete_save(s: int) -> void:
	if FileAccess.file_exists(save_path(s)):
		DirAccess.remove_absolute(save_path(s))
	if slot == s:
		slot = -1


func slot_data(s: int) -> Dictionary:
	## Raw contents of a slot file, or {} if empty/corrupt.
	if not FileAccess.file_exists(save_path(s)):
		return {}
	var f := FileAccess.open(save_path(s), FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed
	return {}
