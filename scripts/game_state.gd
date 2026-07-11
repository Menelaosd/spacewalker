extends Node
## Global game state (autoload as "GameState").
## Holds resources, oxygen and gear stats. Everything upgradeable later.

signal oxygen_changed(current: float, maximum: float)
signal cargo_changed(carried: int, banked: int)
signal gear_changed()
signal notify(text: String)

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

# --- Runtime state ---
var oxygen: float = 100.0
var carried: int = 0
var banked: int = 0


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


func add_carried(value: int) -> void:
	carried += value
	cargo_changed.emit(carried, banked)


func bank_cargo() -> int:
	## Moves carried ore into the bank. Returns how much was banked.
	var moved := carried
	if moved > 0:
		banked += moved
		carried = 0
		cargo_changed.emit(carried, banked)
	return moved


func lose_carried() -> int:
	var lost := carried
	carried = 0
	cargo_changed.emit(carried, banked)
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
