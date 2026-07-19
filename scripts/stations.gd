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

# INSPECTION LAYOUT: all 12 sit together in a grid, a short flight NORTH of home, so
# you can cruise up and look at every one side by side. (Gameplay placement — scattering
# them across the map as breach targets — is a later step; see ROADMAP / the memory.)
const CLUSTER := Vector2(0.0, -3600.0)  # grid centre, world units (north of origin)
const GRID_COLS := 4
const GAP := 1000.0                     # spacing between stations (each is ~655px)

const LIST := [
	{"id": "bastion_command_citadel",     "name": "Aegis Bastion"},
	{"id": "bulwark_arsenal_depot",       "name": "Iron Chamber Arsenal"},
	{"id": "cryo_sleeper_vault_hexpod",   "name": "Longsleep Vault Persephone"},
	{"id": "gilded_wake_derelict_liner",  "name": "The Gilded Wake"},
	{"id": "glacier_still_ice_harvester", "name": "The Glacier Still"},
	{"id": "halcyon_ring_habitat",        "name": "Halcyon Ring"},
	{"id": "helios_bloom_solar_array",    "name": "Helios Bloom"},
	{"id": "tanker_cluster_fuel_depot",   "name": "Cistern Row (Slosh-9)"},
	{"id": "vantage_quarantine_biolab",   "name": "Vantage Quarantine"},
	{"id": "verdant_bloom_spa_resort",    "name": "The Verdant Bloom"},
	{"id": "verdant_halo_hydroponics_ring", "name": "Verdant Halo"},
	{"id": "vespers_reliquary_cloister",  "name": "The Vespers Reliquary"},
]

static var _cache := {}


static func count() -> int:
	return LIST.size()


static func world_pos(i: int) -> Vector2:
	## All 12 laid out in a 4-wide grid around CLUSTER, so they sit next to each other.
	var rows: int = int(ceil(LIST.size() / float(GRID_COLS)))
	var col: int = i % GRID_COLS
	var row: int = i / GRID_COLS
	return CLUSTER + Vector2((col - (GRID_COLS - 1) * 0.5) * GAP,
		(row - (rows - 1) * 0.5) * GAP)


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
