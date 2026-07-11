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
const SAVE_VERSION := 4
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

# --- Upgrade tuning: [cost_base, gain_per_level] ---
const UPGRADES := {
	"o2":     {"base": 10, "step": 25.0},
	"tether": {"base": 15, "step": 120.0},
	"laser":  {"base": 12, "step": 25.0},
	"suit":   {"base": 12, "step": 15.0},
}

const CARRY_BASE := 25      # ore-value the MK I suit can haul per walk


func carry_max() -> int:
	return CARRY_BASE + int(UPGRADES["suit"]["step"]) * suit_level

# --- Ship rooms: a 4x2 cell grid; some prefixed, the rest built with ore ---
const ROOM_TYPES := {
	"quarters":     {"name": "Quarters",      "floor": Color(0.15, 0.17, 0.23), "buildable": false},
	"upgrade":      {"name": "Upgrade Bay",   "floor": Color(0.14, 0.20, 0.25), "buildable": false},
	"bridge":       {"name": "Bridge",        "floor": Color(0.13, 0.18, 0.26), "buildable": false},
	"engine":       {"name": "Engine Room",   "floor": Color(0.22, 0.15, 0.13), "buildable": false},
	"cargo":        {"name": "Cargo Hold",    "floor": Color(0.16, 0.17, 0.21), "buildable": false},
	"airlock":      {"name": "Airlock",       "floor": Color(0.15, 0.18, 0.22), "buildable": false},
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
# bare hull you expand into, one adjacent cell at a time
const DEFAULT_ROOMS := {
	1: "quarters", 8: "engine", 9: "upgrade", 10: "bridge",
	16: "airlock", 17: "cargo",
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
var salvage_taken := {}                           # "cx:cy:i" -> true — wrecks stay looted
var _scoop_accum := 0.0

# Where the ship is parked in open space. ZERO = home station.
var sector := Vector2.ZERO

# --- Who's in the suit — set by the crew registry on a new game ---
var pilot := {"name": "", "gender": "", "age": 27}


func pilot_name() -> String:
	return str(pilot.get("name", "")) if str(pilot.get("name", "")) != "" else "WALKER"


# ==================================================================
# HAVEN — story quest. Earth is gone; the arks jumped to Proxima and
# are building a colony there: Haven, a home you've never seen.
# Rebuild the jump drive from real elements to follow them.
# ==================================================================
const QUEST_PARTS := [
	{"name": "Plasma Conduits", "req": {"Fe": 12, "Si": 8}, "ore": 20,
		"log": "Conduits seated. The drive hums for the first time in years."},
	{"name": "Coolant Loop", "req": {"Mg": 10, "Al": 6}, "ore": 30,
		"log": "Coolant cycling. She runs cold and quiet now."},
	{"name": "Field Coils", "req": {"Ni": 8, "Ti": 6, "Cu": 4}, "ore": 40,
		"log": "Coils wound. Blue jump-field light flickers across the hull."},
	{"name": "Ignition Lattice", "req": {"Ag": 3, "Pt": 2, "Au": 1}, "ore": 50,
		"log": "Lattice aligned. One spark left to find — the heart.",
		"hint": "Precious metals never ride in rock — strip old wrecks for silver and gold; platinum is Vesna's trade (reputation 6)."},
	{"name": "Fuel Core", "req": {"U": 1, "Th": 1}, "ore": 60,
		"log": "The core burns steady. Course locked: HAVEN.",
		"hint": "No rock carries fissiles. Vesna deals uranium and thorium at reputation 10 — work her contracts."},
]
var quest_stage := 0          # part being built; QUEST_PARTS.size() = done
var game_complete := false

# --- Contracts: rotating element requests, delivered at the cargo board
const CONTRACT_POOL := ["O", "C", "Mg", "Si", "Fe", "S", "Al", "Ca", "Na",
	"Ni", "Ti", "Cu", "Zn", "Cr", "Mn"]
var contracts: Array = []     # [{sym, qty, reward}]
var reputation := 0

# --- Vesna's market: buy elements with ore; rep unlocks rarer stock
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
const NEBULAE := [
	{"name": "Rosefield Nebula", "color": Color(0.85, 0.35, 0.6)},
	{"name": "Cerulean Shallows", "color": Color(0.3, 0.65, 0.95)},
	{"name": "Ember Reach", "color": Color(0.95, 0.6, 0.25)},
	{"name": "Viridian Veil", "color": Color(0.35, 0.85, 0.55)},
]
const NEBULA_RADIUS := 2400.0


func nebula_center(i: int) -> Vector2:
	## Fixed, deterministic positions — landmarks, not noise.
	var ang := TAU * (0.13 + 0.29 * float(i))
	return Vector2.from_angle(ang) * (5200.0 + 3600.0 * float(i))


func nebula_index_at(p: Vector2) -> int:
	for i in NEBULAE.size():
		if p.distance_to(nebula_center(i)) < NEBULA_RADIUS:
			return i
	return -1


func region_at(p: Vector2) -> Dictionary:
	## The plan: name + field chance/size/richness modifiers + tint.
	for i in NEBULAE.size():
		if p.distance_to(nebula_center(i)) < NEBULA_RADIUS:
			var n: Dictionary = NEBULAE[i]
			return {"name": n["name"], "chance": 0.6, "size": 1.1,
				"rich": 0.18, "tint": n["color"], "nebula": true}
	var r := p.length()
	if r < 3000.0:
		return {"name": "Home Reach", "chance": 0.3, "size": 0.8,
			"rich": -0.04, "tint": null, "nebula": false}
	if r < 6000.0:
		return {"name": "The Drift", "chance": 0.45, "size": 1.0,
			"rich": 0.0, "tint": null, "nebula": false}
	if r < 9000.0:
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


func _ready() -> void:
	rooms = DEFAULT_ROOMS.duplicate()


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


func add_carried(kind: String, value: int, vein := "") -> void:
	## vein = the chunk's dominant element (rolled at real abundance by
	## the asteroid it came from) — over half its material is that element.
	carried += value
	if carried_items.has(kind):
		carried_items[kind] += 1
	if vein != "":
		# a chunk yields its ore-value in element units (crystal = 2)
		carried_veins[vein] = carried_veins.get(vein, 0) + value
	cargo_changed.emit(carried, banked)
	inventory_changed.emit()


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


func upgrade_cost(kind: String) -> int:
	## Cost scales with the current level: base * (level + 1).
	if not UPGRADES.has(kind):
		return 0
	return int(UPGRADES[kind]["base"]) * (_level_of(kind) + 1)


func try_upgrade(kind: String) -> bool:
	## Spends banked ore and applies the stat gain. Returns false if too poor.
	if not UPGRADES.has(kind):
		return false
	var cost := upgrade_cost(kind)
	if banked < cost:
		return false
	banked -= cost
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
			suit_level += 1     # carry_max() derives from the level
	cargo_changed.emit(carried, banked)
	gear_changed.emit()
	save_game()   # spent ore + gained gear commit together
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
		"oxygen": oxygen,
		"banked": banked,
		"inventory": inventory,
		"elements": elements,
		"discovered": discovered.keys(),
		"rooms": _rooms_to_json(),
		"quest_stage": quest_stage,
		"game_complete": game_complete,
		"reputation": reputation,
		"shift": shift,
		"canisters": canisters,
		"crafted": crafted.keys(),
		"contracts": contracts,
		"trader_stock": trader_stock,
		"pilot": pilot,
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
	quest_stage = int(data.get("quest_stage", 0))
	game_complete = bool(data.get("game_complete", false))
	reputation = int(data.get("reputation", 0))
	shift = int(data.get("shift", 0))
	canisters = int(data.get("canisters", 0))
	crafted = {}
	for id in data.get("crafted", []):
		crafted[id] = true
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
	var sec: Array = data.get("sector", [0.0, 0.0])
	sector = Vector2(sec[0], sec[1])
	carried = 0
	carried_veins = {}
	for k in carried_items:
		carried_items[k] = 0
	in_game = true
	oxygen_changed.emit(oxygen, max_oxygen)
	cargo_changed.emit(carried, banked)
	inventory_changed.emit()
	gear_changed.emit()
	return true


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
	quest_stage = 0
	game_complete = false
	reputation = 0
	shift = 0
	canisters = 0
	crafted = {}
	contracts = []
	trader_stock = []
	pilot = {"name": "", "gender": "", "age": 27}
	sector = Vector2.ZERO
	wake_on_bunk = false
	in_game = true
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
	var rng := RandomNumberGenerator.new()
	rng.seed = shift * 6113 + slot * 977 + 5
	trader_stock = []
	for i in 3:
		var sym: String = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(sym)
		# Vesna buys low, sells high: 2x market rate kills the buy-here-
		# deliver-there arbitrage (contracts pay ~1x + a small bonus).
		# Limited units per shift — she's a trader, not a replicator.
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
	return 130.0 * (1.6 if crafted.has("magnet") else 1.0)


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
	if rng.randf() < 0.45:
		var lines := [
			"VESNA: Still breathing out there, %s? Good. Check my stock." % pilot_name(),
			"VESNA: Belt rock's running rich this cycle. You didn't hear it from me.",
			"VESNA: I pay honest ore for honest elements. Board's updated.",
			"VESNA: That drive of yours... my scanner felt it hum from here.",
			"VESNA: The Expanse eats miners. Bring canisters.",
			"VESNA: Haven's real, %s. Caught an ark beacon on the long band last night." % pilot_name(),
			"VESNA: Gold never rides in rock, %s. Wrecks carry scraps — I carry the real thing, if you've earned the name for it." % pilot_name(),
		]
		return lines[rng.randi_range(0, lines.size() - 1)]
	return ""


func _rooms_to_json() -> Dictionary:
	var out := {}
	for k in rooms:
		out[str(k)] = rooms[k]
	return out


func has_room(type: String) -> bool:
	for cell in rooms:
		if rooms[cell] == type:
			return true
	return false


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
