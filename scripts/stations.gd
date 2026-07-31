class_name Stations
## The 12 endgame rescue stations — HUGE landmarks (>= 4x the ship) placed across the
## star map, each sitting just outside a distinct nebula. Data-only for now: an ARRAY to
## be wired into the breach / Haven endgame later (visitable locations, breach targets).
## Art: res://assets/sprites/stations_v2/<id>.png (transparent, generate-image-v2).
##
## world_pos(i) resolves against GameState's nebula layout so the stations move with the
## map if it's ever rescaled. display_px() is the in-world draw size — >= 4x the ~156px ship.

const DIR := "res://assets/sprites/stations_v2/"
const SHIP_PX := 156.0
const SCALE_MULT := 4.2                 # stations render at least 4x the ship

# SCATTERED across the whole map, each moored just outside ONE nebula — they are the
# survivor pickups, so they have to be destinations you fly to, not a showroom shelf.
# (They used to sit in a 4-wide inspection grid north of home; that was for eyeballing
# the art side by side and it made the endgame read as one single place.)
#
# `nebula` picks the cloud each one is moored to and is therefore also its RANGE, since
# nebula distance is fixed data. The spread is deliberate: four inside 16k so the early
# game has reachable targets, the rest laddering out to 47k.
# `bearing` is which side of its cloud it parks on, as a turn (0..1).
const LIST := [
	{"id": "bastion_command_citadel",     "name": "Aegis Bastion",
		"nebula": 0,  "bearing": 0.13},   # Rosefield Nebula      ~11.4k
	{"id": "cryo_sleeper_vault_hexpod",   "name": "Longsleep Vault Persephone",
		"nebula": 7,  "bearing": 0.61},   # Ghostlight Shoal      ~40.7k
	{"id": "gilded_wake_derelict_liner",  "name": "The Gilded Wake",
		"nebula": 6,  "bearing": 0.88},   # Gilded Drift          ~30.4k
	{"id": "glacier_still_ice_harvester", "name": "The Glacier Still",
		"nebula": 15, "bearing": 0.34},   # Frostlight Reach      ~46.6k
	{"id": "halcyon_ring_habitat",        "name": "Halcyon Ring",
		"nebula": 17, "bearing": 0.76},   # Halcyon Mote          ~10.3k
	{"id": "helios_bloom_solar_array",    "name": "Helios Bloom",
		"nebula": 2,  "bearing": 0.05},   # Ember Reach           ~27.3k
	{"id": "tanker_cluster_fuel_depot",   "name": "Cistern Row (Slosh-9)",
		"nebula": 9,  "bearing": 0.47},   # Molten Wisp           ~13.9k
	{"id": "vantage_quarantine_biolab",   "name": "Vantage Quarantine",
		"nebula": 5,  "bearing": 0.22},   # Carmine Hollow        ~15.4k
	{"id": "verdant_bloom_spa_resort",    "name": "The Verdant Bloom",
		"nebula": 11, "bearing": 0.69},   # Verdant Bloom         ~32.1k
	{"id": "verdant_halo_hydroponics_ring", "name": "Verdant Halo",
		"nebula": 3,  "bearing": 0.41},   # Viridian Veil         ~35.2k
]

static var _cache := {}


static func count() -> int:
	return LIST.size()


static func world_pos(i: int) -> Vector2:
	## Moored just OUTSIDE its nebula: cloud edge, plus the station's own half-width, plus
	## clear water. Resolved against GameState so the stations follow if the map is ever
	## rescaled — the same reason nebula_center() is a function and not a baked table.
	var ni: int = int(LIST[i]["nebula"])
	var stand_off: float = GameState.nebula_radius(ni) + display_px() * 0.5 + 780.0
	return GameState.nebula_center(ni) \
		+ Vector2.from_angle(TAU * float(LIST[i]["bearing"])) * stand_off


static func centroid() -> Vector2:
	## Mean station position — the chart's fallback anchor when it has to collapse them.
	var s := Vector2.ZERO
	for i in LIST.size():
		s += world_pos(i)
	return s / float(LIST.size())


static func display_px() -> float:
	## In-world draw size — the station is a giant, >= 4x the ship.
	return SHIP_PX * SCALE_MULT


static func tex(id: String) -> Texture2D:
	## Raw-loaded so it works in editor/export/headless without the .import step.
	if _cache.has(id):
		return _cache[id]
	var t: Texture2D = null
	var p := ProjectSettings.globalize_path(DIR + id + ".png")
	if FileAccess.file_exists(p):
		var img := Image.load_from_file(p)
		if img != null:
			t = ImageTexture.create_from_image(img)
	_cache[id] = t
	return t
