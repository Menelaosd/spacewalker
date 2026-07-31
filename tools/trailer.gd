extends Node
## TRAILER DIRECTOR — records scripted gameplay clips for the launch trailer.
##
## Run one clip per process:
##   godot --path <repo> --resolution 1280x720 --write-movie out.avi --fixed-fps 30 \
##         --quit-after <frames> tools/trailer.tscn      (with SW_CLIP=<name>)
##
## WHY IT WORKS THIS WAY
##  * The debug env hooks (SW_NEBULA, SW_FAB, SW_MODAL, SW_BREACH_CH…) are read in each
##    scene's _ready, so they must be set BEFORE the scene is instantiated. This node sets
##    them itself and THEN adds the scene as a child — which is why the whole clip table
##    can live here in one file instead of being split across a shell runner.
##  * --fixed-fps makes delta exactly 1/30, so every cue time below is frame-exact and a
##    clip records identically every run. Do not use randomness in cue timing.
##  * Input goes through Input.action_press / parse_input_event, i.e. the same path a real
##    player's keyboard takes — the game cannot tell the difference and no scene needed a
##    recording-only code path.
##
## Cue verbs (strings, so the table stays declarative and diffable):
##   press:<action>  rel:<action>     held movement (move_up/down/left/right, fire)
##   key:<NAME>      keydn/keyup:<NAME>   a keyboard key, by KEY_ name
##   say:<text>      push a HUD toast

const FPS := 30.0

# ---------------------------------------------------------------- clip table
# secs is the recorded length. env is applied before the scene loads.
const CLIPS := {
# ---- FLIGHT: cruising, nebulae, stations -----------------------------------
"cruise_open": {
	"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_NEBULA": "4"},
	"cues": [[0.3, "press:move_up"], [2.2, "press:move_right"], [3.0, "rel:move_right"],
		[4.0, "press:move_left"], [4.8, "rel:move_left"]]},
"cruise_nebula_rose": {
	"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_NEBULA": "0"},
	"cues": [[0.2, "press:move_up"], [1.8, "press:move_left"], [3.4, "rel:move_left"]]},
"cruise_nebula_ember": {
	"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_NEBULA": "2"},
	"cues": [[0.2, "press:move_up"], [2.4, "press:move_right"], [4.0, "rel:move_right"]]},
"cruise_nebula_cerulean": {
	"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_NEBULA": "1"},
	"cues": [[0.2, "press:move_up"], [2.0, "press:move_left"], [3.2, "rel:move_left"],
		[4.2, "press:move_right"]]},
"cruise_nebula_tyrian": {
	"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_NEBULA": "8"},
	"cues": [[0.2, "press:move_up"], [2.6, "press:move_right"], [4.4, "rel:move_right"]]},
"cruise_field": {
	"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_FIELD": "1"},
	"cues": [[0.2, "press:move_up"], [2.8, "press:move_left"], [4.0, "rel:move_left"]]},
"wreck_recipe": {
	"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_WRECK": "1"},
	"cues": [[1.2, "press:move_up"], [2.4, "rel:move_up"]]},
"starchart": {
	"scene": "res://scenes/flight.tscn", "secs": 7.0,
	"env": {"SW_RICH": "1", "SW_CHART": "1", "SW_SHIPAT": "5"}, "cues": []},

# ---- FLIGHT: the station flybys (approach + pass, set by _setup) -----------
"station_aegis":    {"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1"}, "station": 0, "approach": 0.9, "cues": [[0.1, "press:move_up"], [1.1, "rel:move_up"]]},
"station_helios":   {"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1"}, "station": 5, "approach": 2.4, "cues": [[0.1, "press:move_up"], [1.1, "rel:move_up"]]},
"station_gilded":   {"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1"}, "station": 2, "approach": 4.1, "cues": [[0.1, "press:move_up"], [1.1, "rel:move_up"]]},
"station_halcyon":  {"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1"}, "station": 4, "approach": 5.6, "cues": [[0.1, "press:move_up"], [1.1, "rel:move_up"]]},
"station_longsleep": {"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1"}, "station": 1, "approach": 3.2, "cues": [[0.1, "press:move_up"], [1.1, "rel:move_up"]]},
"station_verdant":  {"scene": "res://scenes/flight.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1"}, "station": 8, "approach": 1.7, "cues": [[0.1, "press:move_up"], [1.1, "rel:move_up"]]},

# ---- FLIGHT: the rescues ---------------------------------------------------
"rescue_juno": {"scene": "res://scenes/flight.tscn", "secs": 8.0,
	"env": {"SW_RICH": "1", "SW_DIALOG": "JUNO"}, "cues": []},
"rescue_mira": {"scene": "res://scenes/flight.tscn", "secs": 8.0,
	"env": {"SW_RICH": "1", "SW_DIALOG": "MIRA"}, "cues": []},
"rescue_vega": {"scene": "res://scenes/flight.tscn", "secs": 8.0,
	"env": {"SW_RICH": "1", "SW_DIALOG": "VEGA"}, "cues": []},
"rescue_hale": {"scene": "res://scenes/flight.tscn", "secs": 8.0,
	"env": {"SW_RICH": "1", "SW_DIALOG": "HALE"}, "cues": []},
"rescue_sola": {"scene": "res://scenes/flight.tscn", "secs": 8.0,
	"env": {"SW_RICH": "1", "SW_DIALOG": "SOLA"}, "cues": []},

# ---- SPACEWALK -------------------------------------------------------------
"eva_drift": {"scene": "res://scenes/main.tscn", "secs": 6.0, "env": {"SW_RICH": "1"},
	"cues": [[0.3, "press:move_right"], [1.6, "rel:move_right"], [1.6, "press:move_up"],
		[2.8, "rel:move_up"], [3.2, "press:move_left"], [4.6, "rel:move_left"]]},
"mining_1": {"scene": "res://scenes/main.tscn", "secs": 7.0,
	"env": {"SW_RICH": "1"}, "mine": 0, "cues": []},
"mining_2": {"scene": "res://scenes/main.tscn", "secs": 7.0,
	"env": {"SW_RICH": "1"}, "mine": 1, "cues": []},
"mining_3": {"scene": "res://scenes/main.tscn", "secs": 7.0,
	"env": {"SW_RICH": "1"}, "mine": 2, "cues": []},
"adrift": {"scene": "res://scenes/main.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_ADRIFT": "1"}, "zoom": 1.25,
	"cues": [[0.4, "press:move_up"], [3.0, "press:move_right"], [4.2, "rel:move_right"]]},
"out_of_air": {"scene": "res://scenes/main.tscn", "secs": 8.0,
	"env": {"SW_RICH": "1"}, "starve": true,
	"cues": [[0.3, "press:move_up"], [1.4, "rel:move_up"], [1.8, "press:move_left"],
		[2.6, "rel:move_left"]]},
"solar_flare": {"scene": "res://scenes/main.tscn", "secs": 8.0,
	"env": {"SW_RICH": "1", "SW_FORCE_FLARE": "1"},
	"cues": [[0.4, "press:move_right"], [2.0, "rel:move_right"],
		[2.4, "press:move_down"], [3.6, "rel:move_down"]]},
"inventory_eva": {"scene": "res://scenes/main.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_SHOW_INV": "1"}, "cues": []},

# ---- INTERIOR --------------------------------------------------------------
"interior_walk": {"scene": "res://scenes/ship_interior.tscn", "secs": 7.0,
	"env": {"SW_RICH": "1"},
	"cues": [[0.4, "press:move_right"], [2.6, "rel:move_right"],
		[2.8, "press:move_up"], [4.0, "rel:move_up"],
		[4.2, "press:move_right"], [6.0, "rel:move_right"]]},
"periodic_table": {"scene": "res://scenes/ship_interior.tscn", "secs": 8.0,
	"env": {"SW_RICH": "1", "SW_SHOW_INV": "1"}, "scroll": true, "cues": []},
"element_detail": {"scene": "res://scenes/ship_interior.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_SHOW_INV": "1", "SW_DETAIL": "Fe"},
	"detail": true, "cues": []},
"upgrades": {"scene": "res://scenes/ship_interior.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_MODAL": "laser"},
	"cues": [[1.8, "key:E"], [3.6, "key:E"], [5.0, "key:E"]]},
"upgrades_o2": {"scene": "res://scenes/ship_interior.tscn", "secs": 6.0,
	"env": {"SW_RICH": "1", "SW_MODAL": "o2"},
	"cues": [[1.6, "key:E"], [3.2, "key:E"], [4.8, "key:E"]]},
"fabricator": {"scene": "res://scenes/ship_interior.tscn", "secs": 7.0,
	"env": {"SW_RICH": "1", "SW_FAB": "1"},
	"cues": [[1.2, "key:RIGHT"], [1.9, "key:RIGHT"], [2.6, "key:DOWN"],
		[3.4, "key:RIGHT"], [4.1, "key:2"], [5.0, "key:RIGHT"], [5.7, "key:RIGHT"]]},
"fabricate_place": {"scene": "res://scenes/ship_interior.tscn", "secs": 7.0,
	"env": {"SW_RICH": "1", "SW_FAB": "sofa"}, "place": true, "cues": []},
"furnished_room": {"scene": "res://scenes/ship_interior.tscn", "secs": 7.0,
	"env": {"SW_RICH": "1", "SW_FURN": "1"},
	"cues": [[0.5, "press:move_right"], [3.0, "rel:move_right"],
		[3.4, "press:move_down"], [5.0, "rel:move_down"]]},
"crew_id": {"scene": "res://scenes/ship_interior.tscn", "secs": 7.0,
	"env": {"SW_RICH": "1", "SW_ID": "JUNO"}, "cues": []},
"crew_id_vega": {"scene": "res://scenes/ship_interior.tscn", "secs": 7.0,
	"env": {"SW_RICH": "1", "SW_ID": "VEGA"}, "cues": []},

# ---- THE BREACH ------------------------------------------------------------
"breach_map": {"scene": "res://scenes/breach.tscn", "secs": 9.0,
	"env": {"SW_RICH": "1", "SW_SEED": "7", "SW_BREACH_ST": "helios_bloom_solar_array"}, "map": true, "cues": []},
"breach_map_deep": {"scene": "res://scenes/breach.tscn", "secs": 9.0,
	"env": {"SW_RICH": "1", "SW_SEED": "3", "SW_BREACH_AT": "5",
		"SW_BREACH_ST": "bastion_command_citadel"}, "map": true, "battles": true,
	"cues": []},
"breach_map_core": {"scene": "res://scenes/breach.tscn", "secs": 8.0,
	"env": {"SW_RICH": "1", "SW_SEED": "11", "SW_BREACH_AT": "8",
		"SW_BREACH_ST": "cryo_sleeper_vault_hexpod"}, "map": true, "battles": true,
	"cues": []},
"duel_open": {"scene": "res://scenes/breach.tscn", "secs": 10.0,
	"env": {"SW_RICH": "1", "SW_SEED": "5", "SW_BREACH_CH": "1",
		"SW_BREACH_ST": "helios_bloom_solar_array"}, "duel": true, "cues": []},
"duel_mid": {"scene": "res://scenes/breach.tscn", "secs": 12.0,
	"env": {"SW_RICH": "1", "SW_SEED": "13", "SW_BREACH_CH": "1",
		"SW_BREACH_ST": "vantage_quarantine_biolab"}, "duel": true, "cues": []},
"duel_boss": {"scene": "res://scenes/breach.tscn", "secs": 12.0,
	"env": {"SW_RICH": "1", "SW_SEED": "21", "SW_BREACH_CH": "1",
		"SW_BREACH_ST": "bastion_command_citadel"}, "duel": true, "cues": []},

# ==================================================================
# SECOND PASS — analog control, warm-up black, longer takes.
# `fly` is [start, end, amount] holds on the thrust and turn axes; `warmup` runs the first
# seconds under black so the HUD's opening toast has expired before the useful frame.
# ==================================================================

# ---- QUIET CRUISING: no toast, no dead start, a hand on the stick ----------
"fly_amethyst": {"scene": "res://scenes/flight.tscn", "secs": 14.0, "warmup": 4.5,
	"env": {"SW_RICH": "1", "SW_NEBULA": "4"},
	"fly": {"thr": [[0.2, 13.5, 0.85]],
		"turn": [[5.0, 7.4, 0.42], [9.2, 11.0, -0.34]]}, "cues": []},
"fly_rosefield": {"scene": "res://scenes/flight.tscn", "secs": 14.0, "warmup": 4.5,
	"env": {"SW_RICH": "1", "SW_NEBULA": "0"},
	"fly": {"thr": [[0.3, 8.0, 0.9], [9.0, 13.6, 0.6]],
		"turn": [[5.6, 7.8, -0.5], [10.4, 12.2, 0.3]]}, "cues": []},
"fly_ember": {"scene": "res://scenes/flight.tscn", "secs": 14.0, "warmup": 4.5,
	"env": {"SW_RICH": "1", "SW_NEBULA": "2"},
	"fly": {"thr": [[0.2, 13.6, 0.8]],
		"turn": [[6.2, 8.6, 0.55], [10.0, 11.4, -0.28]]}, "cues": []},
"fly_cerulean": {"scene": "res://scenes/flight.tscn", "secs": 14.0, "warmup": 4.5,
	"env": {"SW_RICH": "1", "SW_NEBULA": "1"},
	"fly": {"thr": [[0.4, 6.4, 0.75], [7.6, 13.5, 0.95]],
		"turn": [[5.0, 7.0, 0.46], [9.6, 11.8, -0.44]]}, "cues": []},
"fly_tyrian": {"scene": "res://scenes/flight.tscn", "secs": 14.0, "warmup": 4.5,
	"env": {"SW_RICH": "1", "SW_NEBULA": "8"},
	"fly": {"thr": [[0.2, 13.6, 0.88]],
		"turn": [[4.6, 6.4, -0.4], [8.4, 10.8, 0.52]]}, "cues": []},
"fly_obsidian": {"scene": "res://scenes/flight.tscn", "secs": 14.0, "warmup": 4.5,
	"env": {"SW_RICH": "1", "SW_NEBULA": "18"},
	"fly": {"thr": [[0.3, 13.4, 0.82]],
		"turn": [[5.4, 7.2, 0.5], [10.2, 12.4, -0.36]]}, "cues": []},
"fly_frostlight": {"scene": "res://scenes/flight.tscn", "secs": 14.0, "warmup": 4.5,
	"env": {"SW_RICH": "1", "SW_NEBULA": "15"},
	"fly": {"thr": [[0.2, 7.2, 0.9], [8.4, 13.5, 0.7]],
		"turn": [[6.0, 8.2, -0.48], [10.6, 12.0, 0.32]]}, "cues": []},
"fly_field_a": {"scene": "res://scenes/flight.tscn", "secs": 14.0, "warmup": 4.5,
	"env": {"SW_RICH": "1", "SW_FIELD": "1"},
	"fly": {"thr": [[0.3, 13.5, 0.7]],
		"turn": [[4.2, 6.6, 0.5], [8.8, 11.2, -0.55]]}, "cues": []},
"fly_field_b": {"scene": "res://scenes/flight.tscn", "secs": 14.0, "warmup": 4.5,
	"env": {"SW_RICH": "1", "SW_FIELD": "1", "SW_WRECK": "1"},
	"fly": {"thr": [[1.0, 5.4, 0.55], [7.0, 13.4, 0.85]],
		"turn": [[5.8, 8.0, -0.42], [10.4, 12.6, 0.38]]}, "cues": []},
"fly_deep": {"scene": "res://scenes/flight.tscn", "secs": 14.0, "warmup": 4.5,
	"env": {"SW_RICH": "1", "SW_NEBULA": "12"},
	"fly": {"thr": [[0.2, 13.6, 0.92]],
		"turn": [[3.8, 5.6, 0.36], [7.4, 9.0, -0.3], [11.0, 12.8, 0.44]]}, "cues": []},

# ---- THE SHADOW: straight over the hull, slow enough to read ---------------
"shadow_aegis": {"scene": "res://scenes/flight.tscn", "secs": 12.0, "warmup": 4.0,
	"env": {"SW_RICH": "1"}, "station": 0, "approach": 0.9, "over": true, "v0": 180.0,
	"fly": {"thr": [[0.2, 2.2, 0.55], [7.0, 9.0, 0.4]], "turn": []}, "cues": []},
"shadow_helios": {"scene": "res://scenes/flight.tscn", "secs": 12.0, "warmup": 4.0,
	"env": {"SW_RICH": "1"}, "station": 5, "approach": 2.4, "over": true, "v0": 180.0,
	"fly": {"thr": [[0.2, 2.4, 0.5], [7.4, 9.2, 0.42]], "turn": []}, "cues": []},
"shadow_halcyon": {"scene": "res://scenes/flight.tscn", "secs": 12.0, "warmup": 4.0,
	"env": {"SW_RICH": "1"}, "station": 4, "approach": 5.6, "over": true, "v0": 200.0,
	"fly": {"thr": [[0.2, 2.0, 0.55], [6.8, 8.8, 0.38]],
		"turn": [[4.2, 5.6, 0.22]]}, "cues": []},
"shadow_gilded": {"scene": "res://scenes/flight.tscn", "secs": 12.0, "warmup": 4.0,
	"env": {"SW_RICH": "1"}, "station": 2, "approach": 4.1, "over": true, "v0": 190.0,
	"fly": {"thr": [[0.2, 2.2, 0.5], [7.2, 9.4, 0.44]], "turn": []}, "cues": []},

# ---- GATHERING, slowly ----------------------------------------------------
"gather_a": {"scene": "res://scenes/main.tscn", "secs": 12.0, "warmup": 3.5,
	"env": {"SW_RICH": "1"}, "mine": 0, "cues": []},
"gather_b": {"scene": "res://scenes/main.tscn", "secs": 12.0, "warmup": 3.5,
	"env": {"SW_RICH": "1"}, "mine": 1, "cues": []},
"gather_c": {"scene": "res://scenes/main.tscn", "secs": 12.0, "warmup": 3.5,
	"env": {"SW_RICH": "1"}, "mine": 2, "cues": []},
"gather_d": {"scene": "res://scenes/main.tscn", "secs": 12.0, "warmup": 3.5,
	"env": {"SW_RICH": "1"}, "mine": 3, "cues": []},
"gather_close": {"scene": "res://scenes/main.tscn", "secs": 12.0, "warmup": 3.5,
	"env": {"SW_RICH": "1"}, "mine": 4, "zoom": 1.9, "cues": []},
"gather_wide": {"scene": "res://scenes/main.tscn", "secs": 12.0, "warmup": 3.5,
	"env": {"SW_RICH": "1"}, "mine": 5, "zoom": 0.95, "cues": []},

# ---- WALKING THE SHIP -----------------------------------------------------
# waypoints are [dx, dy, dwell] from the spawn, in interior pixels
"tour_forward": {"scene": "res://scenes/ship_interior.tscn", "secs": 14.0, "warmup": 3.0,
	"env": {"SW_RICH": "1"},
	"walk": [[190, 0, 1.1], [380, -150, 1.4], [560, -150, 1.0], [560, 30, 1.2]],
	"cues": []},
"tour_aft": {"scene": "res://scenes/ship_interior.tscn", "secs": 14.0, "warmup": 3.0,
	"env": {"SW_RICH": "1"},
	"walk": [[-170, 0, 1.2], [-170, 160, 1.5], [40, 160, 1.0], [230, 160, 1.3]],
	"cues": []},
"tour_crew": {"scene": "res://scenes/ship_interior.tscn", "secs": 14.0, "warmup": 3.0,
	"env": {"SW_RICH": "1", "SW_FURN": "1"},
	"walk": [[0, -160, 1.6], [200, -160, 1.4], [380, 0, 1.6], [380, 170, 1.2]],
	"cues": []},
"tour_furnished": {"scene": "res://scenes/ship_interior.tscn", "secs": 13.0, "warmup": 3.0,
	"env": {"SW_RICH": "1", "SW_FURN": "1"},
	"walk": [[210, 150, 2.0], [40, 150, 1.4], [-160, 20, 1.6]], "cues": []},

# ---- BUILDING OUT THE HULL ------------------------------------------------
"build_room_a": {"scene": "res://scenes/ship_interior.tscn", "secs": 14.0, "warmup": 3.0,
	"env": {"SW_RICH": "1"}, "build": true, "cues": []},
"build_room_b": {"scene": "res://scenes/ship_interior.tscn", "secs": 14.0, "warmup": 3.0,
	"env": {"SW_RICH": "1", "SW_FURN": "1"}, "build": true, "cues": []},

# ---- CONVERSATIONS that actually turn the page -----------------------------
"talk_juno": {"scene": "res://scenes/flight.tscn", "secs": 20.0,
	"env": {"SW_RICH": "1", "SW_DIALOG": "JUNO"}, "talk": true, "cues": []},
"talk_mira": {"scene": "res://scenes/flight.tscn", "secs": 20.0,
	"env": {"SW_RICH": "1", "SW_DIALOG": "MIRA"}, "talk": true, "cues": []},
"talk_hale": {"scene": "res://scenes/flight.tscn", "secs": 20.0,
	"env": {"SW_RICH": "1", "SW_DIALOG": "HALE"}, "talk": true, "cues": []},
"talk_sola": {"scene": "res://scenes/flight.tscn", "secs": 20.0,
	"env": {"SW_RICH": "1", "SW_DIALOG": "SOLA"}, "talk": true, "cues": []},
"talk_vega": {"scene": "res://scenes/flight.tscn", "secs": 20.0,
	"env": {"SW_RICH": "1", "SW_DIALOG": "VEGA"}, "talk": true, "cues": []},

# ---- THE BREACH, walked slowly --------------------------------------------
"crawl_helios": {"scene": "res://scenes/breach.tscn", "secs": 16.0, "warmup": 2.5,
	"env": {"SW_RICH": "1", "SW_SEED": "7",
		"SW_BREACH_ST": "helios_bloom_solar_array"},
	"map": true, "pace": 3.2, "cues": []},
"crawl_aegis": {"scene": "res://scenes/breach.tscn", "secs": 16.0, "warmup": 2.5,
	"env": {"SW_RICH": "1", "SW_SEED": "19",
		"SW_BREACH_ST": "bastion_command_citadel"},
	"map": true, "pace": 3.2, "cues": []},
"crawl_vault": {"scene": "res://scenes/breach.tscn", "secs": 16.0, "warmup": 2.5,
	"env": {"SW_RICH": "1", "SW_SEED": "23", "SW_BREACH_AT": "3",
		"SW_BREACH_ST": "cryo_sleeper_vault_hexpod"},
	"map": true, "pace": 3.4, "cues": []},
"crawl_quarantine": {"scene": "res://scenes/breach.tscn", "secs": 16.0, "warmup": 2.5,
	"env": {"SW_RICH": "1", "SW_SEED": "31", "SW_BREACH_AT": "5",
		"SW_BREACH_ST": "vantage_quarantine_biolab"},
	"map": true, "pace": 3.4, "battles": true, "cues": []},
"crawl_glacier": {"scene": "res://scenes/breach.tscn", "secs": 16.0, "warmup": 2.5,
	"env": {"SW_RICH": "1", "SW_SEED": "41", "SW_BREACH_AT": "6",
		"SW_BREACH_ST": "glacier_still_ice_harvester"},
	"map": true, "pace": 3.0, "battles": true, "cues": []},

# ==================================================================
# THIRD PASS — twenty more, one habit per clip rather than one location.
# Crossing an edge, carrying a full bag home, opening a screen and closing it again,
# standing somewhere for a moment. All analog, all warm-up black.
# ==================================================================

# ---- FLIGHT: crossing edges ----------------------------------------------
"edge_into_ember": {"scene": "res://scenes/flight.tscn", "secs": 15.0, "warmup": 4.0,
	"env": {"SW_RICH": "1"}, "neb_enter": 2, "bearing": 1.1,
	"fly": {"thr": [[0.2, 14.5, 0.9]], "turn": [[6.0, 7.8, 0.28]]}, "cues": []},
"edge_into_tyrian": {"scene": "res://scenes/flight.tscn", "secs": 15.0, "warmup": 4.0,
	"env": {"SW_RICH": "1"}, "neb_enter": 8, "bearing": 3.6,
	"fly": {"thr": [[0.2, 14.5, 0.95]], "turn": [[7.4, 9.6, -0.3]]}, "cues": []},
"edge_into_cerulean": {"scene": "res://scenes/flight.tscn", "secs": 15.0, "warmup": 4.0,
	"env": {"SW_RICH": "1"}, "neb_enter": 1, "bearing": 5.2, "out": 2.1,
	"fly": {"thr": [[0.2, 14.5, 0.92]], "turn": [[5.4, 7.0, 0.24]]}, "cues": []},
"edge_out_of_rose": {"scene": "res://scenes/flight.tscn", "secs": 15.0, "warmup": 4.0,
	"env": {"SW_RICH": "1"}, "neb_leave": 0, "bearing": 2.2,
	"fly": {"thr": [[0.2, 14.5, 0.88]], "turn": [[8.0, 10.2, 0.32]]}, "cues": []},
"long_burn": {"scene": "res://scenes/flight.tscn", "secs": 18.0, "warmup": 4.5,
	"env": {"SW_RICH": "1", "SW_NEBULA": "19"},
	"fly": {"thr": [[0.2, 17.6, 1.0]],
		"turn": [[4.0, 5.6, 0.3], [8.2, 10.4, -0.42], [13.0, 14.6, 0.36]]}, "cues": []},
"chart_check": {"scene": "res://scenes/flight.tscn", "secs": 18.0, "warmup": 4.0,
	"env": {"SW_RICH": "1", "SW_NEBULA": "10"},
	# fly, open the chart to look, sit with it, close it, fly on — the way anyone
	# actually uses a map
	"fly": {"thr": [[0.2, 4.4, 0.85], [13.0, 17.6, 0.9]],
		"turn": [[2.2, 3.6, 0.34], [14.4, 16.0, -0.3]]},
	"cues": [[5.2, "key:M"], [12.4, "key:M"]]},
"drift_wreck": {"scene": "res://scenes/flight.tscn", "secs": 15.0, "warmup": 4.0,
	"env": {"SW_RICH": "1", "SW_WRECK": "1", "SW_FIELD": "1"},
	"fly": {"thr": [[0.6, 3.0, 0.55], [9.0, 11.0, 0.4]],
		"turn": [[3.6, 5.4, 0.38], [11.6, 13.0, -0.34]]}, "cues": []},

# ---- SPACEWALK: the whole loop, not just the cutting ----------------------
"haul_home_a": {"scene": "res://scenes/main.tscn", "secs": 16.0, "warmup": 3.5,
	"env": {"SW_RICH": "1"}, "mine": 0, "haul": 9.0, "cues": []},
"haul_home_b": {"scene": "res://scenes/main.tscn", "secs": 16.0, "warmup": 3.5,
	"env": {"SW_RICH": "1"}, "mine": 2, "haul": 9.5, "zoom": 1.3, "cues": []},
"eva_out": {"scene": "res://scenes/main.tscn", "secs": 13.0, "warmup": 3.5,
	"env": {"SW_RICH": "1"},
	# leaving the ship: short bursts, coast, correct — nobody holds the thruster down
	"fly": {"thr": [[0.4, 1.9, 0.9], [5.0, 6.2, 0.6], [9.4, 10.6, 0.5]],
		"turn": [[2.6, 4.0, 0.5], [7.2, 8.6, -0.44]]}, "cues": []},
"eva_leash": {"scene": "res://scenes/main.tscn", "secs": 13.0, "warmup": 3.5,
	"env": {"SW_RICH": "1"}, "zoom": 0.9,
	# push out until the lifeline bites and hauls you back — the leash, shown
	"fly": {"thr": [[0.4, 8.5, 1.0]], "turn": [[3.0, 4.4, 0.22]]}, "cues": []},
"eva_inventory": {"scene": "res://scenes/main.tscn", "secs": 14.0, "warmup": 3.5,
	"env": {"SW_RICH": "1"},
	"fly": {"thr": [[0.4, 1.8, 0.8]], "turn": [[2.0, 3.0, 0.4]]},
	"cues": [[4.6, "key:I"], [11.8, "key:ESC"]]},

# ---- INTERIOR: going somewhere for a reason ------------------------------
"walk_bridge": {"scene": "res://scenes/ship_interior.tscn", "secs": 13.0, "warmup": 3.0,
	"env": {"SW_RICH": "1"},
	"walk": [[190, 0, 2.4], [190, -160, 1.8], [0, -160, 1.4], [0, 0, 1.0]], "cues": []},
"walk_cargo": {"scene": "res://scenes/ship_interior.tscn", "secs": 13.0, "warmup": 3.0,
	"env": {"SW_RICH": "1"},
	"walk": [[0, 160, 2.2], [-190, 160, 1.6], [-380, 160, 2.0], [-190, 0, 1.2]],
	"cues": []},
"walk_quarters": {"scene": "res://scenes/ship_interior.tscn", "secs": 13.0, "warmup": 3.0,
	"env": {"SW_RICH": "1", "SW_FURN": "1"},
	"walk": [[-190, -160, 2.0], [-380, -160, 2.2], [-190, 0, 1.4], [0, 0, 1.0]],
	"cues": []},
"walk_hydro": {"scene": "res://scenes/ship_interior.tscn", "secs": 13.0, "warmup": 3.0,
	"env": {"SW_RICH": "1"},
	"walk": [[190, 160, 2.4], [190, 0, 1.6], [0, 160, 1.8], [0, 0, 1.0]], "cues": []},
"open_inventory": {"scene": "res://scenes/ship_interior.tscn", "secs": 16.0, "warmup": 3.0,
	"env": {"SW_RICH": "1"},
	# walk over, open it, read it, close it, walk on
	"walk": [[190, 0, 9.0], [0, 0, 1.0]],
	"cues": [[5.0, "key:I"], [13.4, "key:ESC"]]},
"build_slow": {"scene": "res://scenes/ship_interior.tscn", "secs": 18.0, "warmup": 3.0,
	"env": {"SW_RICH": "1"}, "build": true, "cues": []},

# ---- THE BREACH: deliberating --------------------------------------------
"crawl_long": {"scene": "res://scenes/breach.tscn", "secs": 20.0, "warmup": 2.5,
	"env": {"SW_RICH": "1", "SW_SEED": "53",
		"SW_BREACH_ST": "halcyon_ring_habitat"},
	"map": true, "pace": 4.2, "cues": []},
"duel_slow": {"scene": "res://scenes/breach.tscn", "secs": 18.0, "warmup": 2.0,
	"env": {"SW_RICH": "1", "SW_SEED": "67", "SW_BREACH_CH": "1",
		"SW_BREACH_ST": "verdant_halo_hydroponics_ring"},
	"duel": true, "dpace": 1.9, "cues": []},
"duel_think": {"scene": "res://scenes/breach.tscn", "secs": 18.0, "warmup": 2.0,
	"env": {"SW_RICH": "1", "SW_SEED": "71", "SW_BREACH_CH": "1",
		"SW_BREACH_ST": "tanker_cluster_fuel_depot"},
	"duel": true, "dpace": 2.3, "cues": []},
}

const KEYS := {
	"1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4, "5": KEY_5, "6": KEY_6,
	"E": KEY_E, "I": KEY_I, "M": KEY_M, "Q": KEY_Q, "R": KEY_R,
	"SPACE": KEY_SPACE, "ENTER": KEY_ENTER, "ESC": KEY_ESCAPE, "TAB": KEY_TAB,
	"LEFT": KEY_LEFT, "RIGHT": KEY_RIGHT, "UP": KEY_UP, "DOWN": KEY_DOWN,
}

var _spec := {}
var _scene: Node = null
var _t := 0.0
var _cue := 0
var _held: Array[String] = []
var _duel_cd := 0.0
var _png_dir := ""     # SW_TRAILER_PNG=<dir>: also dump contact frames, for review
var _png_n := 0
var _png_next := 0.0
var _cover: ColorRect = null    # warm-up black, see _setup_cover
var _cursor := Vector2.ZERO     # eased virtual pointer for the gathering clips
var _cursor_set := false
var _beat := 0.0                # generic cooldown for the walk / talk / build drivers
var _leg := 0                   # which waypoint the walker is heading for
var _walk_home := Vector2.ZERO  # the walker's spawn, so waypoints can be written relative


func _ready() -> void:
	var clip := OS.get_environment("SW_CLIP")
	# SW_CLIP=__list__ prints "name secs" for every clip and exits. The runner used to keep
	# its own copy of the table; the two drifted the moment a clip was added, so the runner
	# now asks for it.
	if clip == "__list__":
		for k in CLIPS:
			print("CLIP %s %s" % [k, str(CLIPS[k]["secs"])])
		get_tree().quit()
		return
	if not CLIPS.has(clip):
		push_error("[TRAILER] unknown SW_CLIP '%s'" % clip)
		get_tree().quit(1)
		return
	_spec = CLIPS[clip]
	# env FIRST: every scene reads its debug hooks in _ready, so the instantiate below
	# has to happen after these are in place
	for k in _spec.get("env", {}):
		OS.set_environment(k, str(_spec["env"][k]))
	# The star chart and the inventory pause the tree while they are open. With the default
	# inherit mode the director paused with it, so the cue that closes the screen again
	# never fired and every "open it, read it, close it" clip froze on the open screen.
	# The overlays themselves use ALWAYS for exactly this reason.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_png_dir = OS.get_environment("SW_TRAILER_PNG")
	if _png_dir != "":
		DirAccess.make_dir_recursive_absolute(_png_dir)
	_seed_state()
	_scene = load(str(_spec["scene"])).instantiate()
	add_child(_scene)
	await get_tree().process_frame
	_setup()
	print("[TRAILER] %s  %.1fs  (%d frames)" % [clip, float(_spec["secs"]),
		int(float(_spec["secs"]) * FPS)])


func _seed_state() -> void:
	## A trailer must not show a save-file-shaped hole. Crew aboard, drive built, a name
	## on the pilot — everything the HUD, the quest log and the interior read.
	# SW_RICH IS USELESS HERE — and it was on every clip in the first pass, doing nothing.
	# GameState is an autoload: it reads that env var in its own _ready, which has already
	# run by the time this director exists to set it. So the stock is applied directly.
	# Symptom that gave it away: "BANKED ORE 0" under an "Expand the ship (20 ore)" prompt
	# the walker could never afford, and an empty periodic table.
	GameState._apply_rich_cheat()
	GameState.in_game = true
	GameState.pilot = {"name": "RIVA", "gender": "", "age": 31}
	for who in ["JUNO", "MIRA", "HALE", "SOLA", "VEGA"]:
		GameState.rescued[who] = true
	GameState.quest_stage = 5
	GameState.breach_colonists = 148
	for i in GameState.NEBULAE.size():
		if i % 2 == 0:
			GameState.seen_regions[i] = true


func _setup() -> void:
	## Per-clip staging that can only happen once the scene is alive.
	if _spec.has("station"):
		# A FLYBY, not a hero shot. Spawning on the hull (SW_SHIPAT) gives a static
		# postcard; the station has to GROW. Terminal speed here is ~1150 u/s and the
		# burn reaches it in about 3s, so ~4200 units of run-up means the station enters
		# frame early, fills it, and sweeps past at the end of a 6s clip. The bow aims a
		# few hundred units to one SIDE of it so it drifts across instead of being run
		# straight over, and the ship starts already moving — a dead start wastes a second.
		var sp: Vector2 = Stations.world_pos(int(_spec["station"]))
		var app: float = float(_spec.get("approach", 2.3))
		var dir := Vector2.from_angle(app)
		# `over` = fly straight across the middle of the hull instead of past its shoulder.
		# That is the only path that shows the ship's shadow: the hull shader only darkens
		# within about one hull-width of the ship, so a shoulder pass never triggers it.
		var side: float = 0.0 if _spec.has("over") else 480.0
		var run: float = 1050.0 if _spec.has("over") else 1450.0
		_scene.ship_pos = sp - dir * run
		var aim := sp + dir.orthogonal() * side
		_scene.heading = (aim - _scene.ship_pos).angle()
		_scene.vel = Vector2.from_angle(_scene.heading) * float(_spec.get("v0", 300.0))
		_scene.cam.position = _scene.ship_pos
		_scene.cam.reset_smoothing()
	if _spec.has("neb_enter"):
		# Park OUTSIDE the cloud and point the bow at its heart. SW_NEBULA drops the ship
		# on the inner edge, already surrounded — you never see the fog arrive. Coming in
		# from clear space is the shot: black, then the edge, then swallowed.
		var ni: int = int(_spec["neb_enter"])
		var c := GameState.nebula_center(ni)
		var r := GameState.nebula_radius(ni)
		var b := Vector2.from_angle(float(_spec.get("bearing", 1.1)))
		_scene.ship_pos = c + b * (r * float(_spec.get("out", 1.85)))
		_scene.heading = (c - _scene.ship_pos).angle()
		_scene.vel = Vector2.from_angle(_scene.heading) * 340.0
		_scene.cam.position = _scene.ship_pos
		_scene.cam.reset_smoothing()
	if _spec.has("neb_leave"):
		# the reverse: deep inside, nose out
		var ni2: int = int(_spec["neb_leave"])
		var c2 := GameState.nebula_center(ni2)
		var b2 := Vector2.from_angle(float(_spec.get("bearing", 1.1)))
		_scene.ship_pos = c2 - b2 * (GameState.nebula_radius(ni2) * 0.55)
		_scene.heading = b2.angle()
		_scene.vel = b2 * 340.0
		_scene.cam.position = _scene.ship_pos
		_scene.cam.reset_smoothing()
	if _spec.has("starve"):
		# Unclip from the dock first. The ship refills O2 at 45/s while docked, which ate
		# the low reading outright — the gauge read 94% for the whole "running out of air"
		# clip. Out here the real 1.5/s drain runs the tank down inside the take.
		_scene.player.position = Vector2(-560.0, 210.0)
		_scene.player.in_dock = false
		GameState.oxygen = 9.0
	if _spec.has("mine"):
		_stage_mining(int(_spec["mine"]))
	if _spec.has("zoom"):
		var pc := _scene.player.get_node_or_null("Camera") as Camera2D
		if pc != null:
			pc.zoom = Vector2.ONE * float(_spec["zoom"])
			pc.reset_smoothing()
	if _spec.has("walk") or _spec.has("build"):
		# Several interior debug hooks freeze the walker on purpose (SW_NPCDBG pulls the
		# camera back for a whole-ship still; the modals stop them so a menu can't be
		# walked away from). Any of those leaves a "walking" clip with a statue in it, so
		# the walker is explicitly re-enabled here.
		_scene.crew.set_process(true)
		_walk_home = _scene.crew.global_position
	if _spec.has("warmup"):
		_setup_cover()


func _setup_cover() -> void:
	## "Wait a bit before you start recording, so no text is on screen."
	##
	## Movie Maker records from frame zero — there is no way to start it late. So the take
	## starts UNDER BLACK: the scene runs, the HUD says its piece and the toast expires
	## behind the cover, and the cover fades off leaving a clean frame. Trim the head in
	## the edit. The alternative — hiding the HUD label — would have been a lie about what
	## the game looks like.
	var layer := CanvasLayer.new()
	layer.layer = 200
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_cover)
	add_child(layer)


func _tick_cover() -> void:
	if _cover == null:
		return
	var hold: float = float(_spec["warmup"])
	if _t < hold:
		return
	var fade: float = clampf((_t - hold) / 0.55, 0.0, 1.0)
	_cover.color = Color(0, 0, 0, 1.0 - fade)
	if fade >= 1.0:
		_cover.get_parent().queue_free()
		_cover = null


func _stage_mining(which: int) -> void:
	## Put the astronaut nose-to-nose with a rock and aim the pistol at it. Mining is a
	## mouse-aimed action, and a recorded process has no real cursor to aim with — so the
	## aim vector is written directly and the laser is held from the env hook.
	var p0: Node2D = _scene.player
	var anchor: Vector2 = p0.tether_anchor
	# ONLY rocks the lifeline can actually reach. The first cut of this clip aimed at the
	# nearest veined rock full stop — which sat past the 600-unit tether, so the line
	# hauled the astronaut backwards all take and the beam stretched off-screen. The
	# leash is a game rule; the shot has to respect it, not fight it.
	var rocks: Array = []
	for r in _rocks():
		if str(r.vein) != "" and anchor.distance_to(r.position) < 420.0:
			rocks.append(r)
	if rocks.is_empty():
		for r in _rocks():
			if anchor.distance_to(r.position) < 480.0:
				rocks.append(r)
	if rocks.is_empty():
		return
	# rich veins first — they carry the brighter icon and the bigger break-up
	rocks.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return (1 if a.is_rich else 0) > (1 if b.is_rich else 0))
	var rock: Node2D = rocks[which % rocks.size()]
	var p: Node2D = _scene.player
	# close in: the beam has 240px of range, and firing from the far end of it puts a
	# thin red thread across a wide frame instead of a laser cutting rock
	p.position = rock.position - Vector2.from_angle(0.5 + 0.8 * float(which)) * 105.0
	p.in_dock = false
	p.aim_dir = (rock.position - p.position).normalized()
	OS.set_environment("SW_LASER", "1")
	# push in. The spacewalk camera is framed for navigating a field; at that width the
	# astronaut is 26px of the screen and the beam is a thread. Mining is the close-up.
	var cam := p.get_node_or_null("Camera") as Camera2D
	if cam != null:
		cam.zoom = Vector2(1.45, 1.45)
		cam.reset_smoothing()


func _drive_mining(delta: float) -> void:
	## Gathering, at a human pace.
	##
	## AIM THE CURSOR, NEVER THE VECTOR. player._update_aim() recomputes aim_dir from
	## get_global_mouse_position() every physics tick, so writing aim_dir directly is
	## overwritten before it reaches the beam — the first take fired at max range into
	## empty space for seven seconds. Warping the real pointer is the only aim the game
	## keeps.
	##
	## And the pointer TRAVELS. Snapping it onto each new rock the instant the last one
	## broke looked like a turret, not a person: the beam teleported across the field
	## between frames. It now eases over, decelerating into the target, and the astronaut
	## thrusts across rather than sliding.
	var p: Node2D = _scene.player
	if not _cursor_set:
		_cursor = p.position + p.aim_dir * 120.0
		_cursor_set = true
	# `haul`: past this point stop cutting and carry the bag home. A gathering clip that
	# only ever mines misses the half of the loop that makes it tense — the walk back.
	if _spec.has("haul") and _t > float(_spec["haul"]):
		OS.set_environment("SW_LASER", "")
		var home: Vector2 = p.tether_anchor
		var back := home - p.position
		if back.length() > 70.0:
			var bd2 := back.normalized() * clampf(back.length() / 300.0, 0.5, 1.0)
			_analog("move_left", "move_right", bd2.x)
			_analog("move_up", "move_down", bd2.y)
		else:
			_analog("move_left", "move_right", 0.0)
			_analog("move_up", "move_down", 0.0)
		var vp2 := p.get_viewport()
		vp2.warp_mouse(vp2.get_canvas_transform() * home)
		return
	var best: Node2D = null
	var bd := 1e9
	for c in _rocks():
		# stay inside the leash, or the re-aim walks the shot off-screen while the tether
		# hauls the astronaut the other way
		if p.tether_anchor.distance_to(c.position) > 470.0:
			continue
		var d: float = p.position.distance_to(c.position)
		if d < bd:
			bd = d
			best = c
	if best == null:
		return
	# ease in, with a speed cap so a far switch is a sweep and a near one is a nudge
	var to := best.position - _cursor
	var step: float = minf(to.length(), 340.0 * delta)
	_cursor += to.normalized() * step * 0.9 + to * 0.06
	var vp := p.get_viewport()
	var scr: Vector2 = vp.get_canvas_transform() * _cursor
	var mm := InputEventMouseMotion.new()
	mm.position = scr
	mm.global_position = scr
	Input.parse_input_event(mm)
	vp.warp_mouse(scr)
	# close the distance on the thrusters, not by teleporting the body
	if bd > 165.0:
		var dir := (best.position - p.position).normalized() * clampf(bd / 260.0, 0.4, 1.0)
		_analog("move_left", "move_right", dir.x)
		_analog("move_up", "move_down", dir.y)
	else:
		_analog("move_left", "move_right", 0.0)
		_analog("move_up", "move_down", 0.0)


func _rocks() -> Array:
	var out: Array = []
	for c in _scene.get_children():
		if c.get_class() == "StaticBody2D" and c.has_method("take_damage"):
			out.append(c)
	return out


func _process(delta: float) -> void:
	_t += delta
	_tick_cover()
	if _png_dir != "":
		_grab()
	var cues: Array = _spec.get("cues", [])
	while _cue < cues.size() and float(cues[_cue][0]) <= _t:
		_do(str(cues[_cue][1]))
		_cue += 1
	if _spec.has("mine") and _scene != null and is_instance_valid(_scene.player):
		_drive_mining(delta)
	if _spec.has("fly"):
		_drive_fly()
	if _spec.has("walk"):
		_drive_walk()
	if _spec.has("talk"):
		_drive_talk(delta)
	if _spec.has("build"):
		_drive_build(delta)
	if _spec.has("map"):
		_drive_map(delta)
	if _spec.has("duel"):
		_drive_duel(delta)
	if _spec.has("scroll") and _scene != null:
		_scroll_inventory()
	if _spec.has("detail") and _scene != null:
		_cycle_detail()
	if _spec.has("place") and _scene != null:
		_drive_placement(delta)


func _scroll_inventory() -> void:
	## The element grid is taller than the screen; a still frame shows a third of it.
	## Wheel it slowly so the trailer sees the whole periodic table go by.
	var inv := _find(_scene, "_sorted")
	if inv != null and _t > 1.2 and fmod(_t, 0.34) < 0.034:
		inv._scroll += 1


# ==================================================================
# HUMAN-LIKE CONTROL
#
# The first pass drove everything with on/off key cues, and it showed: the ship snapped to
# full thrust, held it dead flat, then snapped off. Nobody flies like that. Everything
# below is analog — `Input.action_press(action, strength)` takes a 0..1 strength and
# `Input.get_axis` reads it, so the game can be flown with a stick it never knew it had.
# ==================================================================
func _trap(t: float, s: float, e: float, amt: float, ease := 0.5) -> float:
	## A press-and-HOLD, not a pulse: ramp on over `ease`, hold, ramp off over `ease`.
	## Raised-cosine ramps, because a linear ramp still reads as mechanical.
	if t <= s or t >= e:
		return 0.0
	var up := clampf((t - s) / maxf(ease, 0.001), 0.0, 1.0)
	var dn := clampf((e - t) / maxf(ease, 0.001), 0.0, 1.0)
	var env := minf(0.5 - 0.5 * cos(PI * up), 0.5 - 0.5 * cos(PI * dn))
	return amt * env


func _axis(beats: Array, t: float) -> float:
	var v := 0.0
	for b in beats:
		v += _trap(t, float(b[0]), float(b[1]), float(b[2]),
			float(b[3]) if b.size() > 3 else 0.5)
	return clampf(v, -1.0, 1.0)


func _analog(neg: String, pos: String, v: float) -> void:
	## One axis, two actions, fractional strength. Also releases the opposite side, or the
	## engine keeps the stale strength and the ship drifts into a permanent slow turn.
	if v > 0.005:
		Input.action_release(neg)
		Input.action_press(pos, v)
	elif v < -0.005:
		Input.action_release(pos)
		Input.action_press(neg, -v)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _drive_fly() -> void:
	## Analog helm. `thr` and `turn` are lists of [start, end, amount] holds; overlapping
	## ones sum. A real pilot burns, drifts, corrects — so most clips are one long burn
	## with two or three eased corrections laid over it, not a drum pattern.
	var f: Dictionary = _spec["fly"]
	_analog("move_down", "move_up", _axis(f.get("thr", []), _t))
	_analog("move_left", "move_right", _axis(f.get("turn", []), _t))


func _drive_walk() -> void:
	## Analog WASD toward a list of waypoints, in interior pixels relative to the spawn.
	## Arriving is a slow-down, not a stop: the walker eases off within 60px, holds a beat,
	## then leans into the next leg.
	var pts: Array = _spec["walk"]
	if _leg >= pts.size():
		_analog("move_left", "move_right", 0.0)
		_analog("move_up", "move_down", 0.0)
		return
	var here: Vector2 = _scene.crew.global_position
	var goal: Vector2 = _walk_home + Vector2(float(pts[_leg][0]), float(pts[_leg][1]))
	var d := goal - here
	if d.length() < 26.0:
		_beat -= 1.0 / FPS
		if _beat <= 0.0:
			_leg += 1
			_beat = float(pts[_leg - 1][2]) if pts[_leg - 1].size() > 2 else 0.5
		_analog("move_left", "move_right", 0.0)
		_analog("move_up", "move_down", 0.0)
		return
	var lean: float = clampf(d.length() / 90.0, 0.35, 1.0)
	var dir := d.normalized() * lean
	_analog("move_left", "move_right", dir.x)
	_analog("move_up", "move_down", dir.y)


func _drive_talk(delta: float) -> void:
	## Reads the conversation like a person: let the typewriter finish, sit with the line,
	## then press on. `_advance` deliberately makes the FIRST press finish the reveal and
	## only the second move on, so each beat is two presses a moment apart — pressing at a
	## flat rate would skip whole lines unread.
	_beat -= delta
	if _beat > 0.0:
		return
	var dlg = _scene.get("_dialog")
	if dlg == null or not is_instance_valid(dlg) or not dlg.visible:
		return
	_key("E", true)
	_key("E", false)
	# short beat if that press only finished the reveal, long one if it turned the page
	_beat = 0.55 if _leg % 2 == 0 else 2.6
	_leg += 1


func _drive_build(delta: float) -> void:
	## Walks the hull edge and builds out bare bays. An "expand" station sits just inside
	## the room at each buildable edge and wants the walker within INTERACT_RADIUS, so this
	## picks the nearest one, leans over to it, and presses E once it is live.
	_beat -= delta
	var best := Vector2.ZERO
	var found := false
	var bd := 1e9
	var here: Vector2 = _scene.crew.global_position
	for st in _scene._stations:
		if str(st.get("kind", "")) != "expand":
			continue
		var d: float = here.distance_to(st["pos"])
		if d < bd:
			bd = d
			best = st["pos"]
			found = true
	if not found:
		_analog("move_left", "move_right", 0.0)
		_analog("move_up", "move_down", 0.0)
		return
	if bd > 52.0:
		var dir := (best - here).normalized() * clampf(bd / 110.0, 0.4, 1.0)
		_analog("move_left", "move_right", dir.x)
		_analog("move_up", "move_down", dir.y)
		return
	_analog("move_left", "move_right", 0.0)
	_analog("move_up", "move_down", 0.0)
	if _beat <= 0.0 and int(_scene._active) >= 0:
		_key("E", true)
		_key("E", false)
		_beat = 1.9        # let the build animation and the toast land before the next bay


func _cycle_detail() -> void:
	## Walk the element trivia cards. One frozen card for six seconds is a screenshot;
	## the point of this clip is that there are eighty-three of them.
	var inv := _find(_scene, "_sorted")
	if inv == null:
		return
	var step := int(_t / 1.6)
	inv._detail = (7 + step * 11) % maxi(inv._sorted.size(), 1)
	inv.queue_redraw()


func _drive_placement(delta: float) -> void:
	## Prints furniture into a room. Placement is MOUSE-driven — the keyboard cues this
	## clip started with were moving the WALKER around behind the ghost while the ghost
	## itself sat still over an invalid cell, which is why the first take was a red X for
	## six seconds. Sweep the pointer across a furnishable room and confirm as it goes.
	if str(_scene._placing_id) == "":
		return
	var cell := -1
	for c in GameState.rooms:
		if GameState.can_furnish_room(c):
			cell = int(c)
			break
	if cell < 0:
		return
	var r: Rect2 = _scene.cell_rect(cell)
	# Frame the new room AGAINST the ship, not alone. The camera normally rides the walker,
	# who is wherever SW_FAB left them; centring on the walker put the bay off in a corner,
	# and centring on the bay put two thirds of the screen outside the hull — the debug
	# room is always on the hull EDGE, because that is where an unbuilt cell is. Sitting
	# between the hull's centre of mass and the bay keeps both in shot.
	var cam := _scene.crew.get_node_or_null("Camera") as Camera2D
	if cam != null and _t < 0.2:
		var hull := Vector2.ZERO
		var n := 0
		for c2 in GameState.rooms:
			hull += _scene.cell_rect(int(c2)).get_center()
			n += 1
		if n > 0:
			hull /= float(n)
			cam.position_smoothing_enabled = false
			cam.global_position = hull.lerp(r.get_center(), 0.55)
	# a slow left-to-right sweep across the room's floor, confirming at four stops
	var u: float = clampf((_t - 0.8) / 4.6, 0.0, 1.0)
	var target := Vector2(r.position.x + r.size.x * (0.16 + 0.66 * u),
		r.position.y + r.size.y * (0.62 + 0.16 * sin(u * 6.0)))
	var vp := _scene.get_viewport()
	vp.warp_mouse(vp.get_canvas_transform() * target)
	var mm := InputEventMouseMotion.new()
	mm.position = vp.get_canvas_transform() * target
	mm.global_position = mm.position
	Input.parse_input_event(mm)
	_duel_cd -= delta
	if _t > 1.4 and _duel_cd <= 0.0:
		_key("E", true)
		_key("E", false)
		_duel_cd = 1.25


func _drive_map(delta: float) -> void:
	## Walks the breach corridor. The map is MOUSE-driven — the number keys only answer a
	## rig's question — so the marker is moved through _walk_to(), the same call a click on
	## a lit node makes. Battle nodes are skipped for map clips: a duel opening mid-take
	## would replace the corridor with a card table.
	if _scene != null and _scene.get("_duel") != null:
		# a battle node opened under the marker — hand over to the duel autopilot rather
		# than freezing. The map→duel handover is one of the better things to have on tape.
		_drive_duel(delta)
		return
	_duel_cd -= delta
	if _duel_cd > 0.0 or _scene == null:
		return
	# A card picker is its own CanvasLayer on the tree with its own _input — it is not the
	# rig `_choice` dictionary, so the first take walked onto a RECYCLER and then sat on the
	# picker for the rest of the clip. Let it be READ for a beat, then take a card: it is a
	# good screen and deserves the dwell, but it must not eat the whole take.
	for c in _scene.get_children():
		if c is CanvasLayer and c.has_signal("chosen"):
			_key("1", true)
			_key("1", false)
			_duel_cd = 1.6
			return
	if not _scene._choice.is_empty():
		_key("1", true)      # answer whatever the rig asked and keep walking
		_key("1", false)
		_duel_cd = 1.0
		return
	if bool(_scene._moving):
		return
	var battle_ok: bool = bool(_spec.get("battles", false))
	var pick := -1
	for i in _scene.nodes.size():
		if str(_scene.nodes[i]["state"]) != "reach":
			continue
		var is_battle: bool = int(_scene.TYPES[_scene.nodes[i]["type"]][2]) > 0
		if is_battle and not battle_ok:
			if pick < 0:
				pick = i      # remember it, but keep looking for a corridor node
			continue
		pick = i
		break
	if pick >= 0:
		_scene._walk_to(pick)
		# `pace` buys dwell time between hops — the default reads as someone who already
		# knows the route. On a slow clip the marker arrives, the camera settles, the node
		# says what it is, and only then does the next leg start.
		_duel_cd = float(_spec.get("pace", 1.2))


func _drive_duel(delta: float) -> void:
	## Plays the duel like a competent player: draw, spend everything you can afford into
	## empty lanes, then ring STRIKE. Uses the SAME entry points a click does — no
	## trailer-only rules, so what the camera sees is what the game does.
	_duel_cd -= delta
	if _duel_cd > 0.0:
		return
	var d = _scene.get("_duel") if _scene != null else null
	if d == null or not is_instance_valid(d):
		return
	match int(d.phase):
		0:   # DRAW
			var ev := InputEventKey.new()
			ev.keycode = KEY_SPACE
			ev.physical_keycode = KEY_SPACE
			ev.pressed = true
			Input.parse_input_event(ev)
			_duel_cd = 0.7 * float(_spec.get("dpace", 1.0))
		1:   # MAIN
			var placed := false
			for i in d.hand.size():
				if not d._can_afford(d.hand[i]):
					continue
				for lane in d.you.size():
					if d.you[lane] == null:
						d._sel = i
						d._place_selected(lane)
						placed = true
						break
				if placed:
					break
			var k: float = float(_spec.get("dpace", 1.0))
			if placed:
				_duel_cd = 0.85 * k
			else:
				d._click(d._bell_screen_rect().get_center())
				_duel_cd = 1.4 * k
		_:
			_duel_cd = 0.25


func _grab() -> void:
	## Contact sheet frames. A recorded AVI cannot be inspected from here, so every clip
	## can also drop stills — that is how a clip gets verified as SHOWING the thing rather
	## than merely running without errors.
	if _t < _png_next:
		return
	_png_next = _t + 1.0
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	im.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	im.save_png("%s/%s_%02d.png" % [_png_dir, OS.get_environment("SW_CLIP"), _png_n])
	_png_n += 1


func _find(n: Node, prop: String) -> Node:
	## First descendant that exposes `prop` — the overlays are built in code, so there is
	## no stable node path to hang on to.
	for c in n.get_children():
		if prop in c:
			return c
		var r := _find(c, prop)
		if r != null:
			return r
	return null


func _do(cmd: String) -> void:
	var bits := cmd.split(":", true, 1)
	var verb := bits[0]
	var arg := bits[1] if bits.size() > 1 else ""
	match verb:
		"press":
			Input.action_press(arg, 1.0)
			if not _held.has(arg):
				_held.append(arg)
		"rel":
			Input.action_release(arg)
			_held.erase(arg)
		"key":
			_key(arg, true)
			_key(arg, false)
		"keydn":
			_key(arg, true)
		"keyup":
			_key(arg, false)
		"say":
			GameState.say(arg)


func _key(name: String, down: bool) -> void:
	if not KEYS.has(name):
		push_warning("[TRAILER] unknown key '%s'" % name)
		return
	var ev := InputEventKey.new()
	ev.keycode = KEYS[name]
	ev.physical_keycode = KEYS[name]
	ev.pressed = down
	Input.parse_input_event(ev)


func _exit_tree() -> void:
	for a in _held:
		Input.action_release(a)
