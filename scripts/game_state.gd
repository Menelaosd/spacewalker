extends Node
## Global game state (autoload as "GameState").
## Holds resources, oxygen, gear stats, the upgrade system and save slots.

signal oxygen_changed(current: float, maximum: float)
signal cargo_changed(carried: int, banked: int)
signal inventory_changed()
signal gear_changed()
signal notify(text: String)

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 3
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

# --- Upgrade tuning: [cost_base, gain_per_level] ---
const UPGRADES := {
	"o2":     {"base": 10, "step": 25.0},
	"tether": {"base": 15, "step": 120.0},
	"laser":  {"base": 12, "step": 25.0},
}

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
# 4x2 grid: six prefixed rooms + two empty construction bays (cells 2, 6).
const DEFAULT_ROOMS := {
	0: "quarters", 1: "upgrade", 2: "", 3: "bridge",
	4: "engine", 5: "cargo", 6: "", 7: "airlock",
}

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
var _scoop_accum := 0.0

# Where the ship is parked in open space. ZERO = home station.
var sector := Vector2.ZERO

# --- Session (not saved) ---
var slot: int = -1          # active save slot, -1 = none
var in_game := false        # false on the title screen
var wake_on_bunk := false   # set by a blackout; interior spawns you in bed
var last_lost: int = 0      # ore lost in the last blackout


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
	cargo_changed.emit(carried, banked)
	gear_changed.emit()
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
		"oxygen": oxygen,
		"banked": banked,
		"inventory": inventory,
		"elements": elements,
		"discovered": discovered.keys(),
		"rooms": _rooms_to_json(),
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
	for k in rj:
		var cell := int(k)
		if rooms.has(cell) and ROOM_TYPES.has(rj[k]):
			rooms[cell] = rj[k]
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
	sector = Vector2.ZERO
	wake_on_bunk = false
	in_game = true
	oxygen_changed.emit(oxygen, max_oxygen)
	cargo_changed.emit(carried, banked)
	inventory_changed.emit()
	gear_changed.emit()
	save_game()


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
	## Spends banked ore to construct a room in an empty cell.
	if rooms.get(cell, "x") != "" or not ROOM_TYPES.get(type, {}).get("buildable", false):
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
