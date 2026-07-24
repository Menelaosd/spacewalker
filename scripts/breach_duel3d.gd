extends Node3D
## THE DUEL, in 3D — an Inscryption-style physical table for the breach.
## The board is a real 3D scene (angled camera, moody lights, cards lying flat on
## a deck-plated table, tweened drops/lunges/deaths) built from the SAME card
## elements as the 2D pass: frame + portrait sprites, Label3D stats, battery pips.
## The hand, energy bank, trace-scale and messages live on a 2D HUD overlay.
##
## Rules are exact Inscryption with the Act-3 ENERGY system:
##   · 4 lanes; HELIOS's face-up queue row telegraphs its next wave
##   · energy: max starts 1, +1 per turn (cap 6), refills fully; costs shown as
##     battery pips top-left of every card, the cell bank sits bottom-left
##   · mandatory draw each turn (deck or endless scrap-mite pile); turn 1 skips
##   · STRIKE bell: attacks resolve left-to-right; an empty enemy lane hits the
##     trace-scale; overkill spills into the queued unit; queue advances FIRST
##     on HELIOS's turn, then his front row strikes, then he telegraphs anew
##   · tip the scale +5 to crack the node, -5 and you're ejected
## Spawned by breach.gd at battle nodes; emits finished(won).

signal finished(won: bool)

const ART_DIRS := ["res://assets/sprites/breach/hd/", "res://assets/sprites/breach/duel/",
	"res://assets/sprites/breach/scifi/"]
const LANES := 5            # Act 3 widens the board — "not used to 5 lanes, are you?"
const WIN_TIP := 5
const MAX_ENERGY := 5   # recost curve tops at cost 4; finisher reachable ~turn 4

const CYAN := Color(0.45, 0.9, 1.0)
const AMBER := Color(1.0, 0.72, 0.25)
const RED := Color(1.0, 0.35, 0.28)
const PANEL := Color(0.05, 0.07, 0.1)
const EDGE := Color(0.3, 0.55, 0.7, 0.5)

# id -> [name, portrait, atk, hp, energy_cost, sigil]
# PLACEHOLDER ROSTER on Act 3's real cost curve (vessel 1⚡ 0/2, energy-bot 2⚡ with
# Battery Bearer, shield 3⚡ with Nano Armor…). Real card designs later (captain).
# sigils: "" none · "battery" (+1 max & +1 current energy on play) · "armor"
# (negates the first damage instance)
# Reskinned Inscryption Act 3 roster (real stats; see docs/BREACH_CARDS.md).
# sigils = Array. Working now: overcharge (Battery Bearer), ablative_plating (Nano Armor),
# spike_casing (attacker takes 1 when this is struck), provoke (card opposite gets +1 power).
# Others are stored/labelled but their effects land in later passes.
# id: [NAME, portrait, atk, hp, energy_cost, sigils]
const CARDS := {
	# --- fodder / side deck ---
	"scrap_mite":     ["SHELLCODE STUB", "u_hollow", 0, 2, 1, []],
	# --- PLAYER intrusion units (cyan) ---
	"power_siphon":   ["CRYPTOJACKER", "u_siphon", 0, 1, 1, ["overcharge"]],
	"buckler_mite":   ["NOP SLED", "u_buckler", 1, 1, 2, ["ablative_plating"]],
	"lance_drone":    ["SPEAR-PHISH", "u_lance", 1, 1, 2, ["targeting_laser"]],
	"fork_turret":    ["FORK BOMB", "u_fork", 2, 2, 4, ["split_bore"]],
	"grunt_bot":      ["BRUTE-FORCER", "u_grunt", 1, 1, 1, []],
	"piston_ram":     ["HYDRA", "u_piston", 2, 2, 3, []],
	"bulwark_breaker": ["ROOTKIT", "u_bulwark", 1, 3, 3, []],
	"skip_worm":      ["LATERAL WORM", "u_skipworm", 2, 3, 4, []],
	"screech_mote":   ["PORT SCANNER", "u_screech", 2, 1, 2, ["provoke"]],
	"spike_mite":     ["TRIPWIRE", "u_spikemite", 1, 1, 2, ["spike_casing"]],
	"sapper_worm":    ["LOGIC BOMB", "u_sapper", 1, 2, 3, ["meltdown"]],
	"charge_mite":    ["OVERCLOCK DAEMON", "u_chargemite", 1, 1, 2, ["overcharge"]],
	"swarm_hound":    ["BOTNET", "u_swarmhound", 2, 2, 4, ["mite_spawner"]],
	"prism_ripper":   ["ZERO-DAY", "u_ripper", 3, 1, 3, []],
	"watcher_seed":   ["DROPPER", "u_seed", 0, 1, 1, ["morphogen"]],
	# --- STRONG cards (top-end bombs; overflow/chain_load are new sigils) ---
	"buffer_overflow": ["STACK SMASH", "u_ripper", 5, 1, 4, ["overflow"]],
	"chain_reaper":   ["KERNEL PANIC", "u_fork", 3, 3, 4, ["chain_load"]],
	"sentinel_ghost": ["SNIPER-SHELL", "u_bulwark", 2, 5, 4, ["targeting_laser"]],
	"thermite_charge": ["THERMITE", "u_sapper", 3, 2, 3, ["meltdown"]],
	"hydra_swarm":    ["DDOS SWARM", "u_swarmhound", 3, 3, 4, ["mite_spawner"]],
	"power_overload": ["OVERVOLT", "u_grunt", 4, 2, 3, ["overcharge"]],
	# --- ENEMY firewall units (red); AI pays no energy so cost = 0 ---
	"barrier_node":   ["PACKET FILTER", "u_barrier", 0, 3, 0, []],
	"sentry_ice":     ["SENTRY ICE", "u_sentry", 1, 2, 0, ["autoturret"]],
	"packet_daemon":  ["HUNTER DAEMON", "u_daemon", 3, 2, 0, []],
	"raptor_proc":    ["REVERSE PROXY", "u_raptor", 2, 3, 0, ["interpose"]],
	"heap_giant":     ["RESPAWN DAEMON", "u_heap", 2, 4, 0, []],
	"spike_wall":     ["TARPIT", "u_spikewall", 1, 2, 0, ["spike_casing"]],
	"trace_hound":    ["TRACER", "u_tracehound", 1, 1, 0, []],
	"null_relay":     ["NULL ROUTE", "u_null", 0, 1, 0, []],
	"firewall_slab":  ["HARDENED WAF", "u_slab", 1, 5, 0, []],
	# --- BOSS / special firewall cards ---
	"freeze_frame":   ["PACKET CAPTURE", "u_freeze", 1, 1, 0, []],
	"index_warden":   ["REGISTRY WARDEN", "u_index", 1, 2, 0, ["ablative_plating"]],
	"kernel_ghost":   ["KERNEL GHOST", "u_kernel", 2, 2, 0, []],
	"daemon_ursa":    ["DAEMON GR1ZZ", "u_ursa", 4, 4, 0, []],
	"daemon_vespa":   ["DAEMON S0N1A", "u_vespa", 2, 1, 0, ["interpose"]],
	"daemon_quill":   ["DAEMON QU177", "u_quill", 2, 2, 0, ["spike_casing"]],
}
# starter deck (11) — energy engine + blockers + snipers + a turn-6 finisher
const PLAYER_DECK := ["power_siphon", "power_siphon", "buckler_mite", "buckler_mite",
	"lance_drone", "lance_drone", "grunt_bot", "grunt_bot", "watcher_seed", "sapper_worm", "fork_turret",
	"buffer_overflow", "chain_reaper", "sentinel_ghost", "thermite_charge", "hydra_swarm", "power_overload"]
# HELIOS firewall decks per tier (T1/T2/T3 pools); zone bosses layered in later
const OPP_DECKS := {
	1: {"deck": ["barrier_node", "sentry_ice", "null_relay", "trace_hound", "sentry_ice", "barrier_node"], "per_turn": 1},
	2: {"deck": ["spike_wall", "packet_daemon", "sentry_ice", "trace_hound", "barrier_node", "packet_daemon", "spike_wall"], "per_turn": 1},
	3: {"deck": ["raptor_proc", "heap_giant", "firewall_slab", "daemon_ursa", "packet_daemon", "raptor_proc", "heap_giant"], "per_turn": 2},
}
const SIGIL_SHORT := {
	"overcharge": "OVERCLOCK", "ablative_plating": "BUFFER", "targeting_laser": "TARGET",
	"split_bore": "FORK", "spike_casing": "TRIPWIRE", "provoke": "NOISE",
	"meltdown": "DETONATE", "autoturret": "SENTRY", "interpose": "INTERCEPT",
	"mite_spawner": "BOTNET", "morphogen": "UNPACK",
	"overflow": "OVERFLOW", "chain_load": "CHAIN",
}
# plain-English rules text for the right-click inspect panel
const SIGIL_RULES := {
	"overcharge": "When played: +1 max energy, +1 energy now.",
	"ablative_plating": "Ignores the first hit it takes.",
	"spike_casing": "Whatever strikes this takes 1 damage back.",
	"provoke": "Attacks against this unit deal 1 less.",
	"split_bore": "Strikes the two diagonal lanes, not straight.",
	"targeting_laser": "Strikes the weakest enemy anywhere.",
	"meltdown": "On death: 2 damage to the unit opposite and both beside it.",
	"mite_spawner": "When played: spawns a free 0/2 stub in an adjacent lane.",
	"autoturret": "Zaps any unit played opposite it for 1.",
	"interpose": "Guards an adjacent empty lane.",
	"morphogen": "Start of your turn: gains +1/+1.",
	"overflow": "Excess strike damage carries to the enemy trace.",
	"chain_load": "Strikes the opposite lane and both sides (3 lanes).",
}
# in-fiction flavor line per card (keyed by display name)
const LORE := {
	"SHELLCODE STUB": "A splinter of code that opens a door where none was.",
	"CRYPTOJACKER": "Your cycles are mine now; bleed for me.",
	"NOP SLED": "Nothing here, nothing here — then the payload.",
	"SPEAR-PHISH": "One trusted handshake, and the gate forgets its master.",
	"FORK BOMB": "It copies until the copying is all there is.",
	"BRUTE-FORCER": "Every key, one by one, until the lock gives up.",
	"HYDRA": "Sever one thread and two more take the wound.",
	"ROOTKIT": "By the time it's seen, it already owns the seeing.",
	"LATERAL WORM": "It doesn't break in — it moves in, room to room.",
	"PORT SCANNER": "Every closed door answers if you knock right.",
	"TRIPWIRE": "HELIOS reaches, and closes on your teeth.",
	"LOGIC BOMB": "Sleeping in the code, counting down to your command.",
	"OVERCLOCK DAEMON": "Push the substrate past red; let it scream faster.",
	"BOTNET": "A thousand borrowed hands, all reaching at once.",
	"ZERO-DAY": "The flaw no one patched because no one knew.",
	"DROPPER": "It carries the worse thing, and lets it go inside.",
	"STACK SMASH": "Push past the edge until the edge gives way.",
	"KERNEL PANIC": "Everything stops at once, and does not restart.",
	"DDOS SWARM": "Ten thousand knocks; no door holds them all.",
	"THERMITE": "It burns through the floor it dies on.",
	"SNIPER-SHELL": "Patient, dug in, and it never misses twice.",
	"OVERVOLT": "Feed it everything; it gives back more.",
	"PACKET FILTER": "Every packet judged; the unclean are turned away.",
	"SENTRY ICE": "Amber eyes that do not blink and do not tire.",
	"HUNTER DAEMON": "It has your scent in the wire now.",
	"REVERSE PROXY": "You strike the mask; the face stays hidden.",
	"RESPAWN DAEMON": "Kill it and it wakes remembering how you did.",
	"TARPIT": "The deeper you push, the slower the world turns.",
	"TRACER": "It walks your intrusion backward to where you sit.",
	"NULL ROUTE": "Your signal leaves and arrives nowhere, forever.",
	"HARDENED WAF": "A wall that learned your last three attempts.",
	"PACKET CAPTURE": "HELIOS keeps every word you ever whispered here.",
	"REGISTRY WARDEN": "It guards the names that make things real.",
	"KERNEL GHOST": "It lives beneath the floor you're standing on.",
	"DAEMON GR1ZZ": "Old, slow, and it has never lost.",
	"DAEMON S0N1A": "She smiles in amber and closes the exits.",
	"DAEMON QU177": "The last voice; it asks you to stop.",
}

# --- table geometry (world units; table plane is y = 0) ---
const ROW_Z := [-2.55, -0.2, 2.15]     # 0 queue / 1 HELIOS front / 2 yours (2.35 pitch — no card clip)
const CELL_W := 1.95
const CELL_H := 2.3
# cards are smaller than a cell (visual card height ≈ 1.375·CARD_W ≈ 2.06 < 2.35 pitch)
const CARD_W := 1.5
const CARD_H := 2.06
const FLOAT_Y := 0.5        # every card (yours AND HELIOS's) hovers high and casts a strong shadow
const BELL_POS := Vector3(6.15, 0.35, -0.2)
const BELL_OFF := Color(0.55, 0.6, 0.68)     # dormant/unlit tint
const BELL_HOVER := Color(1.3, 1.25, 1.18)   # slight glow when hovered
const DECK_POS := Vector3(6.7, 0.02, 1.9)
const MITE_POS := Vector3(5.4, 0.02, 1.9)

enum Phase { DRAW, MAIN, STRIKING, OPP_TURN, OVER }
var phase: int = Phase.MAIN            # turn 1 skips the draw
var tier := 1
var _inspect_id := ""                  # card shown in the right-click inspect panel
var _arrow_cache := {}                 # strike-pattern -> baked white/black arrow texture

var you: Array = []
var opp: Array = []
var queue: Array = []
var hand: Array = []
var deck: Array = []
var mites_left := 10
var opp_deck: Array = []
var energy := 1
var energy_max := 1
var tip := 0
var _won := false

var _msg := "Play units, or ring the STRIKE bell."
var _t := 0.0
var _sel := -1
var _strike_lane := -1
var _strike_t := 0.0
var _opp_step := 0
var _over_at := -1.0
var _tip_anim := 0.0
var _toast := {}
var _floaters: Array = []              # {txt, wpos:Vector3, t, col}
var _pile_flash := 0.0
var _deny_at := -1.0
var _hover_hand := -1
var _hover_lane := -1
var _hover_bell := false
var _hover_pile := 0

var _cam: Camera3D
var _hud: Control
var _slots: Array = []                 # [row][lane] -> {mesh, mat}
var _unit_nodes := {}                  # unit uid (int) -> card Node3D; NEVER key by
                                       # the unit dict itself — Godot hashes dict keys
                                       # by content, and hp mutation breaks the lookup
var _shadow_nodes := {}                # unit uid -> shadow MeshInstance3D on the slab
var _base_nodes := {}                  # unit uid -> flat "docked card" plate on the slot
var _shadow_tex: Texture2D
var _card_base_y := {}                 # unit uid -> resting hover height (for idle bob)
var _card_tw := {}                     # unit uid -> active position tween (bob pauses during it)
var _bell_spr: Sprite3D
var _strike_frames: Array = []         # PixelLab press-animation frames for the STRIKE button
var _bell_anim_t := 0.0                # while _t < this, the press animation owns the sprite
var _next_uid := 0
var _bell_node: Node3D
var _pile_nodes: Array = []
var _tex := {}
var _font: Font = ThemeDB.fallback_font


static func make(diff: int) -> Node3D:
	var d: Node3D = load("res://scripts/breach_duel3d.gd").new()
	d.tier = clampi(diff, 1, 3)
	return d


func _ready() -> void:
	for n in ["card_frame", "card_back", "bell", "cell_full", "cell_empty", "duel_bg",
			"map_tile", "deck_tile", "platform_top", "platform_side", "slot_cell"]:
		_tex[n] = _load_art(n)
	for id in CARDS:
		_tex[CARDS[id][1]] = _load_art(str(CARDS[id][1]))
	_tex["strike_btn"] = _load_art("strike_btn")
	for _i in range(1, 9):
		var pf := _load_art("strike_press_%02d" % _i)
		if pf != null:
			_strike_frames.append(pf)
	for _i in LANES:
		you.append(null)
		opp.append(null)
		queue.append(null)
	deck = PLAYER_DECK.duplicate()
	deck.shuffle()
	opp_deck = (OPP_DECKS[tier]["deck"] as Array).duplicate()
	opp_deck.shuffle()
	for _i in 3:
		if deck.size() > 0:
			hand.append(deck.pop_back())
	hand.append("scrap_mite")
	_build_stage()
	_build_hud()
	_opp_fill_queue()
	if OS.get_environment("SW_DUELDBG") != "":   # DEV: seed a board to preview attack arrows
		you[1] = {"id": "grunt_bot", "hp": 1, "armor": false}
		you[2] = {"id": "lance_drone", "hp": 1, "armor": false}
		you[3] = {"id": "fork_turret", "hp": 2, "armor": false}
		opp[1] = {"id": "barrier_node", "hp": 3}
		opp[2] = {"id": "packet_daemon", "hp": 2}
		opp[4] = {"id": "trace_hound", "hp": 1}
		if OS.get_environment("SW_INSPECT") != "":
			_inspect_id = OS.get_environment("SW_INSPECT")
		if OS.get_environment("SW_HAND") != "":
			hand = ["lance_drone", "fork_turret", "chain_reaper", "power_overload"]
		_sync_board()
	_sync_board()


func _load_art(name: String) -> Texture2D:
	for dir in ART_DIRS:
		var p := ProjectSettings.globalize_path(str(dir) + name + ".png")
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			if img != null:
				return ImageTexture.create_from_image(img)
	return null


# ==================================================================
# Stage: camera, lights, table, slots, bell, piles
# ==================================================================
func _build_stage() -> void:
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 8.2, 8.1)
	_cam.fov = 47.0
	add_child(_cam)
	_cam.look_at(Vector3(0, -0.35, -0.1))
	_cam.current = true
	# soft round drop-shadow texture for floating cards
	var sg := Gradient.new()
	sg.set_color(0, Color(0, 0, 0, 0.95))
	sg.set_color(1, Color(0, 0, 0, 0))
	var sgt := GradientTexture2D.new()
	sgt.gradient = sg
	sgt.fill = GradientTexture2D.FILL_RADIAL
	sgt.fill_from = Vector2(0.5, 0.5)
	sgt.fill_to = Vector2(0.5, 1.0)
	sgt.width = 128
	sgt.height = 128
	_shadow_tex = sgt
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.008, 0.012, 0.02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.32, 0.42)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)
	var key := OmniLight3D.new()
	key.position = Vector3(-2.0, 5.5, 2.5)
	key.light_color = Color(0.75, 0.9, 1.0)
	key.light_energy = 2.3
	key.omni_range = 18.0
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(3.5, 3.0, -3.0)
	rim.light_color = Color(1.0, 0.62, 0.3)
	rim.light_energy = 1.1
	rim.omni_range = 14.0
	add_child(rim)
	# the hall floor, sunk well below so the platform reads as a thick raised slab
	var table := MeshInstance3D.new()
	var tm := PlaneMesh.new()
	tm.size = Vector2(24.0, 16.0)
	table.mesh = tm
	var mat := StandardMaterial3D.new()
	var ttex: Texture2D = _tex.get("map_tile") if _tex.get("map_tile") != null else _tex.get("deck_tile")
	if ttex != null:
		mat.albedo_texture = ttex
		mat.uv1_scale = Vector3(7.0, 4.6, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_color = Color(0.42, 0.45, 0.52)
	mat.roughness = 0.9
	table.mesh.surface_set_material(0, mat)
	table.position.y = -1.55
	add_child(table)
	# the dueling platform — a THICK armored slab the cards actually sit on
	var side_mat := StandardMaterial3D.new()
	side_mat.albedo_texture = _tex.get("platform_side")
	side_mat.uv1_triplanar = true
	side_mat.uv1_scale = Vector3(0.4, 1.8, 0.4)
	side_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	side_mat.roughness = 0.75
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_texture = _tex.get("platform_top")
	top_mat.uv1_scale = Vector3(4.0, 2.6, 1.0)
	top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	top_mat.roughness = 0.7
	top_mat.albedo_color = Color(0.9, 0.92, 1.0)
	# THICK slabs: top face at y≈0 (cards sit here), 1.4 tall walls dropping to the floor,
	# and the main slab reaches forward past the front row so its thick lip faces the camera
	for slab in [[Vector3(0.0, -0.7, -0.4), Vector3(11.6, 1.4, 8.2)],
			[Vector3(5.95, -0.7, 0.95), Vector3(3.7, 1.4, 5.6)]]:
		var body := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = slab[1]
		body.mesh = bm2
		body.mesh.surface_set_material(0, side_mat)
		body.position = slab[0]
		add_child(body)
		var top := MeshInstance3D.new()
		var tp := PlaneMesh.new()
		tp.size = Vector2(slab[1].x, slab[1].z)
		top.mesh = tp
		top.mesh.surface_set_material(0, top_mat)
		top.position = Vector3(slab[0].x, 0.002, slab[0].z)
		add_child(top)
	# --- dramatic layered fog (billowing clouds + drifting wisps) ---
	_build_duel_fog()
	# backdrop — the machine hall looming behind HELIOS's rows
	var bg: Texture2D = _tex.get("duel_bg")
	if bg != null:
		var wall := MeshInstance3D.new()
		var wm := PlaneMesh.new()
		wm.size = Vector2(26.0, 26.0)
		wall.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_texture = bg
		wmat.albedo_color = Color(0.5, 0.5, 0.55)
		wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		wall.mesh.surface_set_material(0, wmat)
		wall.position = Vector3(0, 6.0, -11.0)
		wall.rotation_degrees.x = 90.0
		add_child(wall)
	# the slots — a visible glowing border ring under a dark fill pad
	# DEV: preview an external slot-tile PNG (candidate) without touching the repo import.
	var slot_tex: Texture2D = _tex.get("slot_cell")
	var _slot_ovr := OS.get_environment("SW_SLOT_TEX")
	if _slot_ovr != "":
		var _img := Image.load_from_file(_slot_ovr)
		if _img != null:
			slot_tex = ImageTexture.create_from_image(_img)
	for row in 3:
		var rs: Array = []
		for l in LANES:
			# a textured GRID cell (PixelLab card-slot bay). OPAQUE so it writes depth
			# and the alpha-scissor cards always sort cleanly in front — no blend glitch.
			# Cells are lane/row-pitch sized so they tile edge-to-edge into a grid.
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(CELL_W, CELL_H)
			mi.mesh = pm
			var sm := StandardMaterial3D.new()
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.albedo_texture = slot_tex
			sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sm.albedo_color = Color(0.7, 0.78, 0.9) if row != 0 else Color(0.5, 0.56, 0.66)
			mi.mesh.surface_set_material(0, sm)
			mi.position = Vector3(_lane_x(l), 0.01, ROW_Z[row])
			add_child(mi)
			rs.append({"mesh": mi, "mat": sm, "base": Color(0.7, 0.78, 0.9) if row != 0 else Color(0.5, 0.56, 0.66)})
		_slots.append(rs)
	# the bell
	_bell_node = Node3D.new()
	_bell_node.position = BELL_POS
	add_child(_bell_node)
	var bs := Sprite3D.new()
	bs.texture = _tex.get("strike_btn") if _tex.get("strike_btn") != null else _tex.get("bell")
	bs.pixel_size = 0.014
	# no billboard — laid flat on the board plane so it sits in the table's perspective
	bs.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bs.shaded = false
	bs.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_bell_node.rotation_degrees.x = -90.0
	if not _strike_frames.is_empty():
		bs.texture = _strike_frames.back()   # rest on the dim "off" frame
	bs.modulate = BELL_OFF
	_bell_node.add_child(bs)
	_bell_spr = bs
	# draw piles (flat card backs + floating counts)
	for pp in [[DECK_POS, "DECK"], [MITE_POS, "SHELLS"]]:
		var pn := Node3D.new()
		pn.position = pp[0]
		add_child(pn)
		for stack in 3:
			var cb := Sprite3D.new()
			cb.texture = _tex.get("card_back")
			cb.pixel_size = (CARD_W * 0.58) / maxf(float(cb.texture.get_width()) if cb.texture else 96.0, 1.0)
			cb.rotation_degrees.x = -90.0
			cb.position.y = 0.012 * stack
			cb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			cb.shaded = false
			pn.add_child(cb)
		_pile_nodes.append(pn)


const DUEL_FOG_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 fog_color : source_color = vec3(0.26, 0.52, 0.74);
uniform float nscale = 0.28;
uniform float nspeed = 0.045;
uniform float dens = 0.7;
uniform float front_lo = 1.0;
uniform float front_hi = 4.0;
varying vec3 wpos;
float hash(vec2 p){ p=fract(p*vec2(123.34,345.45)); p+=dot(p,p+34.345); return fract(p.x*p.y); }
float vn(vec2 p){ vec2 i=floor(p),f=fract(p); vec2 u=f*f*(3.0-2.0*f);
	float a=hash(i),b=hash(i+vec2(1.0,0.0)),c=hash(i+vec2(0.0,1.0)),d=hash(i+vec2(1.0,1.0));
	return mix(mix(a,b,u.x),mix(c,d,u.x),u.y); }
float fbm(vec2 p){ float v=0.0,a=0.5; for(int i=0;i<5;i++){ v+=a*vn(p); p=p*1.9+vec2(1.7,-1.3); a*=0.5; } return v; }
float clouds(vec2 p){
	vec2 q=vec2(fbm(p), fbm(p+vec2(5.2,1.3)));
	return fbm(p+1.4*q);
}
void vertex(){ wpos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
	vec2 uv = wpos.xz*nscale + vec2(TIME*nspeed, TIME*nspeed*0.6);
	float n = clouds(uv);
	float mist = smoothstep(0.36, 0.82, n);
	float front = smoothstep(front_lo, front_hi, wpos.z);
	float side = 1.0 - smoothstep(34.0, 46.0, abs(wpos.x));
	ALBEDO = fog_color;
	ALPHA = clamp(mist*front*side*dens, 0.0, 1.0);
}
"""


func _build_duel_fog() -> void:
	var sh := Shader.new()
	sh.code = DUEL_FOG_SHADER
	# three parallax layers — a dense low bank, a mid roll, a high wispy sheet
	var layers := [
		{"y": -0.7, "z": 0.0, "sz": Vector2(94, 74), "scale": 0.17, "speed": 0.05, "dens": 0.55,
			"lo": -14.0, "hi": -6.0, "col": Vector3(0.22, 0.47, 0.7)},
		{"y": -0.45, "z": 0.0, "sz": Vector2(90, 68), "scale": 0.11, "speed": -0.04, "dens": 0.34,
			"lo": -14.0, "hi": -5.0, "col": Vector3(0.27, 0.52, 0.76)},
		{"y": -0.22, "z": 0.0, "sz": Vector2(88, 64), "scale": 0.08, "speed": 0.03, "dens": 0.20,
			"lo": -14.0, "hi": -4.0, "col": Vector3(0.3, 0.55, 0.8)},
	]
	for l in layers:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("nscale", l["scale"])
		mat.set_shader_parameter("nspeed", l["speed"])
		mat.set_shader_parameter("dens", l["dens"])
		mat.set_shader_parameter("front_lo", l["lo"])
		mat.set_shader_parameter("front_hi", l["hi"])
		mat.set_shader_parameter("fog_color", l["col"])
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = l["sz"]
		mi.mesh = pm
		mi.mesh.surface_set_material(0, mat)
		mi.position = Vector3(0.0, l["y"], l["z"])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-48, -8, -40), Vector3(96, 16, 80))
		add_child(mi)
	# drifting wisp puffs rising off the board front
	var puff := _soft_puff_tex()
	var p := GPUParticles3D.new()
	var pp := ParticleProcessMaterial.new()
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pp.emission_box_extents = Vector3(26.0, 0.4, 17.0)
	pp.direction = Vector3(0.2, 1.0, 0.0)
	pp.spread = 30.0
	pp.gravity = Vector3(0.1, 0.14, 0.0)
	pp.initial_velocity_min = 0.06
	pp.initial_velocity_max = 0.28
	pp.scale_min = 3.2
	pp.scale_max = 7.5
	p.process_material = pp
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_texture = puff
	dm.albedo_color = Color(0.3, 0.58, 0.82, 0.05)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = dm
	p.draw_pass_1 = qm
	p.amount = 95
	p.lifetime = 9.0
	p.position = Vector3(0.0, -0.25, 0.0)
	p.visibility_aabb = AABB(Vector3(-52, -8, -42), Vector3(104, 24, 84))
	add_child(p)


func _soft_puff_tex() -> Texture2D:
	var s := 48
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := float(s - 1) * 0.5
	for y in s:
		for x in s:
			var d: float = Vector2(float(x) - c, float(y) - c).length() / c
			var a: float = pow(clampf(1.0 - smoothstep(0.0, 1.0, d), 0.0, 1.0), 1.5)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _lane_x(l: int) -> float:
	return (l - (LANES - 1) * 0.5) * CELL_W


func _slot_pos(row: int, lane: int) -> Vector3:
	return Vector3(_lane_x(lane), 0.0, ROW_Z[row])


func _dir_bar(parent: Node3D, cx: float, cy: float, length: float, thick: float, deg: float, col: Color) -> void:
	## one thin opaque bar in the card's local XY plane (for the attack-direction icon)
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(thick, length)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.position = Vector3(cx, cy, 0.021)
	m.rotation_degrees.z = deg
	parent.add_child(m)


func _dir_icon(kind: String, col: Color) -> Node3D:
	## builds the strike-pattern glyph from thin bars
	var n := Node3D.new()
	var l := 0.20
	var t := 0.028
	match kind:
		"split_bore":                       # FORK — two upward diagonals
			_dir_bar(n, -0.05, 0.0, l, t, 28.0, col)
			_dir_bar(n, 0.05, 0.0, l, t, -28.0, col)
		"targeting_laser":                  # TARGET — crosshair
			_dir_bar(n, 0.0, 0.0, l, t, 0.0, col)
			_dir_bar(n, 0.0, 0.0, l, t, 90.0, col)
		"chain_load":                       # CHAIN — three lanes
			_dir_bar(n, -0.075, 0.0, l, t, 0.0, col)
			_dir_bar(n, 0.0, 0.0, l, t, 0.0, col)
			_dir_bar(n, 0.075, 0.0, l, t, 0.0, col)
		_:                                  # straight ahead
			_dir_bar(n, 0.0, 0.0, l, t, 0.0, col)
	return n


# ==================================================================
# 3D card nodes — the same elements as the 2D cards, layered flat
# ==================================================================
func _make_card_node(u: Dictionary, ghost: bool) -> Node3D:
	var c: Array = CARDS[u["id"]]
	var root := Node3D.new()
	root.rotation_degrees.x = -90.0    # children lay out in local XY, facing up
	# ghost/queue cards dim by DARKENING (rgb), never alpha — cards use alpha-scissor
	# so they stay depth-writing and never blend-glitch through the board
	var dim := Color(0.5, 0.55, 0.68) if ghost else Color(1, 1, 1)
	var port := Sprite3D.new()
	port.texture = _tex.get(str(c[1]))
	if port.texture != null:
		port.pixel_size = (CARD_W * 0.74) / port.texture.get_width()
	port.position = Vector3(0, CARD_H * 0.13, 0.008)
	port.modulate = dim
	port.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	port.shaded = false
	root.add_child(port)
	var frame := Sprite3D.new()
	frame.texture = _tex.get("card_frame")
	if frame.texture != null:
		frame.pixel_size = CARD_W / frame.texture.get_width()
	frame.position = Vector3(0, 0, 0.012)
	frame.modulate = dim
	frame.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	frame.shaded = false
	root.add_child(frame)
	var name_l := _label(str(c[0]), 15, Color(0.78, 0.88, 1.0, dim.a))
	name_l.outline_size = 6
	name_l.position = Vector3(0, -CARD_H * 0.24, 0.02)
	root.add_child(name_l)
	if not (c[5] as Array).is_empty():
		var sig_l := _label(_sig_label(c[5]), 30,
			Color(AMBER.r, AMBER.g, AMBER.b, dim.a) if _has(str(u["id"]), "ablative_plating")
			else Color(CYAN.r, CYAN.g, CYAN.b, dim.a))
		sig_l.position = Vector3(0, -CARD_H * 0.335, 0.02)
		root.add_child(sig_l)
	var atk := _label(str(c[2]), 72, Color(AMBER.r, AMBER.g, AMBER.b, dim.a))
	atk.position = Vector3(-CARD_W * 0.36, -CARD_H * 0.42, 0.02)
	root.add_child(atk)
	atk.name = "Atk"
	var hp := _label(str(u["hp"]), 72, Color(CYAN.r, CYAN.g, CYAN.b, dim.a))
	hp.position = Vector3(CARD_W * 0.36, -CARD_H * 0.42, 0.02)
	hp.name = "Hp"
	root.add_child(hp)
	# energy COST — one discreet badge, top-left
	var cost := int(c[4])
	if cost > 0:
		var cf: Texture2D = _tex.get("cell_full")
		var badge := Sprite3D.new()
		badge.texture = cf
		if cf != null:
			badge.pixel_size = (CARD_W * 0.18) / cf.get_width()
		badge.position = Vector3(-CARD_W * 0.37, CARD_H * 0.40, 0.016)
		badge.modulate = Color(0.55, 0.82, 1.0) * dim
		badge.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		badge.shaded = false
		root.add_child(badge)
		var cost_l := _label(str(cost), 26, Color(1, 1, 1, dim.a))
		cost_l.outline_size = 9
		cost_l.position = Vector3(-CARD_W * 0.37, CARD_H * 0.40, 0.024)
		root.add_child(cost_l)
	# ATTACK-DIRECTION arrow (baked white + black border), top-right — only striking cards
	if int(c[2]) > 0:
		var atex := _arrow_tex(_arrow_kind(c[5]))
		var asp := Sprite3D.new()
		asp.texture = atex
		asp.pixel_size = (CARD_W * 0.24) / atex.get_width()
		asp.position = Vector3(CARD_W * 0.33, CARD_H * 0.40, 0.02)
		asp.modulate = dim
		asp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		asp.shaded = false
		root.add_child(asp)
	# alpha-scissor everything: sprites AND labels write depth → correct sort, no
	# transparent blending glitch through the slot pads or each other
	for ch in root.get_children():
		if ch is Sprite3D:
			ch.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			ch.alpha_scissor_threshold = 0.5
		elif ch is Label3D:
			ch.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	return root


func _label(txt: String, fsz: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font_size = fsz
	l.pixel_size = 0.005
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.85)
	return l


func _has(id: String, sig: String) -> bool:
	return sig in (CARDS[id][5] as Array)


func _sig_label(sigs: Array) -> String:
	if sigs.is_empty():
		return ""
	return SIGIL_SHORT.get(sigs[0], str(sigs[0]).to_upper())


func _uid_of(u: Dictionary) -> int:
	if not u.has("uid"):
		_next_uid += 1
		u["uid"] = _next_uid
	return int(u["uid"])


func _sync_board() -> void:
	## Reconcile 3D card nodes with the logical board. Moved units glide (queue
	## advance), vanished units collapse, new units drop in from above.
	var live := {}
	for row in 3:
		var arr: Array = [queue, opp, you][row]
		for l in LANES:
			var u = arr[l]
			if u == null:
				continue
			var uid := _uid_of(u)
			live[uid] = true
			var base := _slot_pos(row, l)
			var target := base + Vector3(0, FLOAT_Y, 0)
			_ensure_shadow(uid, base, row == 0)
			_card_base_y[uid] = target.y
			if _unit_nodes.has(uid):
				var nd: Node3D = _unit_nodes[uid]
				var ghost: bool = row == 0
				if Vector2(nd.position.x, nd.position.z).distance_to(Vector2(target.x, target.z)) > 0.01:
					var tw := nd.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
					tw.tween_property(nd, "position", target, 0.3)
					_card_tw[uid] = tw
					if not ghost:
						_set_card_dim(nd, Color(1, 1, 1))   # stepped out of the queue shadow
			else:
				var nd := _make_card_node(u, row == 0)
				nd.position = target + Vector3(0, 2.5, 0)
				add_child(nd)
				_unit_nodes[uid] = nd
				var tw := nd.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
				tw.tween_property(nd, "position", target, 0.28)
				_card_tw[uid] = tw
			# refresh the HP digit
			var hp_l: Label3D = _unit_nodes[uid].get_node_or_null("Hp")
			if hp_l != null:
				hp_l.text = str(u["hp"])
				if int(u["hp"]) < int(CARDS[u["id"]][3]):
					hp_l.modulate = Color(RED.r, RED.g, RED.b, hp_l.modulate.a)
	for uid in _unit_nodes.keys():
		if not live.has(uid):
			var nd: Node3D = _unit_nodes[uid]
			_unit_nodes.erase(uid)
			var tw := nd.create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			tw.tween_property(nd, "scale", Vector3(0.02, 0.02, 0.02), 0.24)
			tw.tween_callback(nd.queue_free)
			_card_base_y.erase(uid)
			_card_tw.erase(uid)
			if _shadow_nodes.has(uid):
				var sh: Node3D = _shadow_nodes[uid]
				_shadow_nodes.erase(uid)
				var stw := sh.create_tween()
				stw.tween_property(sh, "transparency", 1.0, 0.2)
				stw.tween_callback(sh.queue_free)
			if _base_nodes.has(uid):
				var bp: Node3D = _base_nodes[uid]
				_base_nodes.erase(uid)
				var btw := bp.create_tween()
				btw.tween_property(bp, "transparency", 1.0, 0.2)
				btw.tween_callback(bp.queue_free)


func _ensure_shadow(uid: int, base: Vector3, ghost: bool) -> void:
	# (docked-card base plate removed — captain didn't want the frame under played cards)
	# a big, strong drop-shadow cast onto the board
	var sh: MeshInstance3D
	if _shadow_nodes.has(uid):
		sh = _shadow_nodes[uid]
	else:
		sh = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(CARD_W * 1.55, CARD_H * 1.45)
		sh.mesh = pm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _shadow_tex
		m.albedo_color = Color(0, 0, 0, 0.9 if ghost else 1.0)   # HELIOS cards cast it too
		sh.mesh.surface_set_material(0, m)
		add_child(sh)
		_shadow_nodes[uid] = sh
	# offset toward the light (front-left key) so the shadow reads as strongly cast
	sh.position = Vector3(base.x + 0.42, 0.018, base.z + 0.52)


func _set_card_dim(nd: Node3D, col: Color) -> void:
	for ch in nd.get_children():
		if ch is Sprite3D or ch is Label3D:
			ch.modulate = Color(col.r, col.g, col.b, 1.0)


func _flash_unit(u) -> void:
	if u == null or not _unit_nodes.has(_uid_of(u)):
		return
	var nd: Node3D = _unit_nodes[_uid_of(u)]
	_set_card_dim(nd, Color(2.2, 2.2, 2.2))
	var tw := nd.create_tween()
	tw.tween_interval(0.09)
	tw.tween_callback(_set_card_dim.bind(nd, Color(1, 1, 1)))


func _lunge_unit(u, dir: float) -> void:
	if u == null or not _unit_nodes.has(_uid_of(u)):
		return
	var uid := _uid_of(u)
	var nd: Node3D = _unit_nodes[uid]
	var home := Vector3(nd.position.x, _card_base_y.get(uid, nd.position.y), nd.position.z)
	var tw := nd.create_tween().set_trans(Tween.TRANS_QUAD)
	tw.tween_property(nd, "position", home + Vector3(0, 0.35, dir * 0.55), 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd, "position", home, 0.14).set_ease(Tween.EASE_IN)
	_card_tw[uid] = tw


# ==================================================================
# HUD overlay (hand, energy, scale, text) + all input
# ==================================================================
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_hud)
	_hud.gui_input.connect(_on_hud_input)
	_hud.draw.connect(_on_hud_draw)


func _s() -> float:
	var vp := _hud.get_viewport_rect().size
	return minf(vp.x / 1280.0, vp.y / 720.0)


func _fs(px: int) -> int:
	return maxi(int(px * _s()), 12)


func _card_size2d() -> Vector2:
	return Vector2(96, 128) * _s() * 1.06


func _hand_rect(i: int) -> Rect2:
	var vp := _hud.get_viewport_rect().size
	var cs := _card_size2d()
	var gap := minf(cs.x + 10.0 * _s(), (vp.x * 0.6) / maxf(hand.size(), 1.0))
	var x0 := vp.x * 0.5 - (gap * (hand.size() - 1) + cs.x) * 0.5
	var y := vp.y - cs.y - 16.0 * _s()
	var r := Rect2(Vector2(x0 + i * gap, y), cs)
	if i == _sel:
		r.position.y -= 26.0 * _s()
	elif i == _hover_hand:
		r.position.y -= 12.0 * _s()
	return r


func _bell_screen_rect() -> Rect2:
	if not _cam.is_position_in_frustum(BELL_POS):
		return Rect2()
	var p := _cam.unproject_position(BELL_POS)
	var s := _s()
	return Rect2(p - Vector2(58.0, 48.0) * s, Vector2(116.0, 96.0) * s)


func _table_point(m: Vector2) -> Vector3:
	var from := _cam.project_ray_origin(m)
	var dir := _cam.project_ray_normal(m)
	if absf(dir.y) < 0.0001:
		return Vector3(999, 0, 999)
	var t := -from.y / dir.y
	if t < 0.0:
		return Vector3(999, 0, 999)
	return from + dir * t


func _pick_lane(m: Vector2, row: int) -> int:
	var p := _table_point(m)
	if absf(p.z - ROW_Z[row]) > CARD_H * 0.62:
		return -1
	for l in LANES:
		if absf(p.x - _lane_x(l)) < CARD_W * 0.62:
			return l
	return -1


func _pick_pile(m: Vector2) -> int:
	var p := _table_point(m)
	if absf(p.z - DECK_POS.z) > CARD_H * 0.6:
		return 0
	if absf(p.x - DECK_POS.x) < CARD_W * 0.62:
		return 1
	if absf(p.x - MITE_POS.x) < CARD_W * 0.62:
		return 2
	return 0


func _on_hud_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_inspect_id = ""
			_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var iid := _card_id_at(event.position)
			if iid != "":
				_inspect_id = iid
				Sfx.play("clack", -14.0)
			else:
				_inspect_id = ""
				_deselect()


func _update_hover(m: Vector2) -> void:
	_hover_hand = -1
	for i in range(hand.size() - 1, -1, -1):
		if _hand_rect(i).has_point(m):
			_hover_hand = i
			break
	_hover_lane = _pick_lane(m, 2) if _hover_hand == -1 else -1
	_hover_bell = _bell_screen_rect().has_point(m)
	_hover_pile = _pick_pile(m) if _hover_hand == -1 else 0
	var pointy := (_hover_hand >= 0 and phase == Phase.MAIN) \
		or (_hover_bell and phase == Phase.MAIN) \
		or (_hover_pile > 0 and phase == Phase.DRAW) \
		or (_hover_lane >= 0 and _sel >= 0 and you[_hover_lane] == null)
	_hud.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if pointy else Control.CURSOR_ARROW


func _deselect() -> void:
	if _sel >= 0:
		_sel = -1
		Sfx.play("clack", -14.0)


func _card_id_at(m: Vector2) -> String:
	## which card is under the cursor — a hand card or a board unit
	for i in range(hand.size() - 1, -1, -1):
		if _hand_rect(i).has_point(m):
			return str(hand[i])
	if _cam != null:
		for row in 3:
			var arr: Array = you if row == 2 else (opp if row == 1 else queue)
			for l in LANES:
				if arr[l] != null:
					var sp: Vector2 = _cam.unproject_position(_slot_pos(row, l) + Vector3(0, 0.3, 0))
					if Rect2(sp - Vector2(55, 85), Vector2(110, 170)).has_point(m):
						return str(arr[l]["id"])
	return ""


func _deny(why: String) -> void:
	if _t - _deny_at > 0.3:
		Sfx.play("deny", -12.0)
		_deny_at = _t
	if phase == Phase.DRAW:
		_pile_flash = 0.5
	if why != "":
		_show_toast(why, RED)


func _show_toast(txt: String, col: Color) -> void:
	_toast = {"txt": txt, "col": col, "t": 0.0}


func _float_txt(txt: String, wpos: Vector3, col: Color) -> void:
	_floaters.append({"txt": txt, "wpos": wpos, "t": 0.0, "col": col})


func _can_afford(id: String) -> bool:
	return energy >= int(CARDS[id][4])


func _click(m: Vector2) -> void:
	match phase:
		Phase.OVER:
			if _t - _over_at > 0.5:
				finished.emit(_won)
		Phase.DRAW:
			var pile := _pick_pile(m)
			if pile == 1 and deck.size() > 0:
				_draw_card(deck.pop_back())
			elif pile == 2 and mites_left > 0:
				mites_left -= 1
				_draw_card("scrap_mite")
			else:
				_deny("Draw first — your DECK or a SCRAP MITE.")
		Phase.MAIN:
			_click_main(m)
		_:
			pass


func _draw_card(id: String) -> void:
	hand.append(id)
	phase = Phase.MAIN
	Sfx.play("clack", -10.0)
	_msg = "Play units, or ring the STRIKE bell."


func _click_main(m: Vector2) -> void:
	if _bell_screen_rect().has_point(m):
		_sel = -1
		phase = Phase.STRIKING
		_strike_lane = -1
		_strike_t = 0.35
		Sfx.play("clack", -4.0)
		_msg = "STRIKE."
		_slam_bell()
		return
	for i in range(hand.size() - 1, -1, -1):
		if _hand_rect(i).has_point(m):
			if _sel == i:
				_deselect()
				return
			var c: Array = CARDS[hand[i]]
			if not _can_afford(hand[i]):
				_deny("%s needs %d energy — you have %d." % [c[0], c[4], energy])
				return
			_sel = i
			_show_toast("Choose a lane for %s." % c[0], CYAN)
			Sfx.play("clack", -12.0)
			return
	if _sel >= 0:
		var lane := _pick_lane(m, 2)
		if lane >= 0:
			if you[lane] == null:
				_place_selected(lane)
			else:
				_deny("Lane occupied.")
			return
		_deselect()
		return
	_deny("")


func _slam_bell() -> void:
	## button lights up through the PixelLab frames, then powers back down (no squash)
	if _bell_spr == null or _strike_frames.is_empty():
		return
	_bell_anim_t = _t + _strike_frames.size() * 0.055 + 0.12
	_bell_spr.modulate = Color(1, 1, 1)
	var fr := _bell_spr.create_tween()
	for f in _strike_frames:
		fr.tween_callback(_set_bell_tex.bind(f))
		fr.tween_interval(0.055)
	fr.tween_callback(_bell_rest)


func _bell_rest() -> void:
	if _bell_spr != null and not _strike_frames.is_empty():
		_bell_spr.texture = _strike_frames.back()
		_bell_spr.modulate = BELL_OFF


func _set_bell_tex(t: Texture2D) -> void:
	if _bell_spr != null and t != null:
		_bell_spr.texture = t


func _place_selected(lane: int) -> void:
	var id: String = hand[_sel]
	# Battery Bearer resolves BEFORE the cost is deducted (Act 3 rule)
	if _has(id, "overcharge"):
		energy_max = mini(energy_max + 1, MAX_ENERGY)
		energy = mini(energy + 1, MAX_ENERGY)
		_show_toast("OVERCHARGE — +1 energy", CYAN)
	energy -= int(CARDS[id][4])
	you[lane] = {"id": id, "hp": int(CARDS[id][3]), "armor": _has(id, "ablative_plating")}
	# SENTRY: an enemy autoturret opposite zaps the freshly-played unit for 1
	if opp[lane] != null and _has(str(opp[lane]["id"]), "autoturret"):
		_float_txt("SENTRY", _slot_pos(2, lane), AMBER)
		if _hit_unit(you[lane], 1, 2, lane):
			you[lane] = null
	# SPAWNER (mite_spawner): drop a free SHELLCODE STUB in the nearest empty lane
	if you[lane] != null and _has(id, "mite_spawner"):
		for dl in [-1, 1, -2, 2]:
			var sl: int = lane + dl
			if sl >= 0 and sl < LANES and you[sl] == null:
				you[sl] = {"id": "scrap_mite", "hp": int(CARDS["scrap_mite"][3]), "armor": false}
				_float_txt("SPAWN", _slot_pos(2, sl), CYAN)
				break
	hand.remove_at(_sel)
	_sel = -1
	_msg = "Play units, or ring the STRIKE bell."
	Sfx.play("clack", -8.0)
	_sync_board()


func _hit_unit(u: Dictionary, dmg: int, row: int, lane: int) -> bool:
	## Apply damage with Nano-Armor handling. Returns true if the unit died.
	if bool(u.get("armor", false)):
		u["armor"] = false
		_flash_unit(u)
		_float_txt("ARMOR", _slot_pos(row, lane), AMBER)
		return false
	u["hp"] = int(u["hp"]) - dmg
	_flash_unit(u)
	_float_txt("-%d" % dmg, _slot_pos(row, lane), RED)
	return int(u["hp"]) <= 0


# --- sigil engine --------------------------------------------------
func _unit_atk(u: Dictionary) -> int:
	## base power + any morphogen/buff stacks
	return int(CARDS[u["id"]][2]) + int(u.get("buff", 0))


func _sniper_target() -> int:
	## TARGETING LASER (Sniper): auto-pick the weakest enemy unit's lane, else -1.
	var best := -1
	var best_hp := 9999
	for l in LANES:
		if opp[l] != null and int(opp[l]["hp"]) < best_hp:
			best_hp = int(opp[l]["hp"])
			best = l
	return best


func _kill(side: String, lane: int) -> void:
	## Remove a board unit and fire its MELTDOWN (Detonator) if it has one.
	var arr: Array = you if side == "you" else opp
	var u = arr[lane]
	if u == null:
		return
	arr[lane] = null
	if _has(str(u["id"]), "meltdown"):
		_detonate(side, lane)


func _detonate(side: String, lane: int) -> void:
	## MELTDOWN: 2 damage to the opposite unit + both side-adjacent enemies.
	var foes: Array = opp if side == "you" else you
	var frow := 1 if side == "you" else 2
	_float_txt("DETONATE", _slot_pos(frow, lane), AMBER)
	for dl in [0, -1, 1]:
		var l: int = lane + dl
		if l < 0 or l >= LANES or foes[l] == null:
			continue
		if _hit_unit(foes[l], 2, frow, l):
			foes[l] = null


func _resolve_hit(u: Dictionary, atk: int, from_lane: int, lane: int) -> void:
	## One strike from your unit at from_lane onto opp[lane], with PROVOKE jam,
	## TRIPWIRE thorns, MELTDOWN on kills, and overkill spilling into the queue.
	var tgt = opp[lane]
	if tgt == null:
		return
	var dmg := atk
	if _has(str(tgt["id"]), "provoke"):
		dmg = maxi(0, dmg - 1)          # NOISE: target jams incoming by 1
	var pre := int(tgt["hp"])
	var died := _hit_unit(tgt, dmg, 1, lane)
	if _has(str(tgt["id"]), "spike_casing"):
		if _hit_unit(u, 1, 2, from_lane):
			_kill("you", from_lane)
	if died:
		_kill("opp", lane)
		var excess := dmg - pre
		if excess > 0:
			if _has(str(u["id"]), "overflow"):
				tip += excess            # OVERFLOW: pierce carries to the enemy trace
				_float_txt("+%d TRACE" % excess, _slot_pos(0, lane) + Vector3(0, 0, -1.2), CYAN)
			else:
				var q = queue[lane]      # otherwise overkill spills into the queued unit
				if q != null and _hit_unit(q, excess, 0, lane):
					queue[lane] = null


# ==================================================================
# Turn engine (identical rules to the 2D pass — verified vs the wiki)
# ==================================================================
func _process(delta: float) -> void:
	_t += delta
	_pile_flash = maxf(_pile_flash - delta, 0.0)
	_tip_anim = lerpf(_tip_anim, float(tip), 1.0 - exp(-6.0 * delta))
	for i in range(_floaters.size() - 1, -1, -1):
		_floaters[i]["t"] = float(_floaters[i]["t"]) + delta * 1.6
		if float(_floaters[i]["t"]) >= 1.0:
			_floaters.remove_at(i)
	if not _toast.is_empty():
		_toast["t"] = float(_toast["t"]) + delta * 0.8
		if float(_toast["t"]) >= 1.0:
			_toast = {}
	if phase == Phase.STRIKING:
		_strike_t -= delta
		if _strike_t <= 0.0:
			_strike_t = 0.45
			_advance_strike()
	elif phase == Phase.OPP_TURN:
		_strike_t -= delta
		if _strike_t <= 0.0:
			_strike_t = 0.45
			_advance_opp()
	_update_slot_glow()
	# STRIKE button: dormant, glowing softly on hover (unless the press animation owns it)
	if _bell_spr != null and _t >= _bell_anim_t:
		var want: Color = BELL_HOVER if (_hover_bell and phase == Phase.MAIN) else BELL_OFF
		_bell_spr.modulate = _bell_spr.modulate.lerp(want, 1.0 - exp(-9.0 * delta))
	# discreet idle bob on resting cards (paused while a card is being tweened)
	for uid in _unit_nodes.keys():
		var busy: bool = _card_tw.has(uid) and is_instance_valid(_card_tw[uid]) \
			and (_card_tw[uid] as Tween).is_running()
		if busy or not _card_base_y.has(uid):
			continue
		var nd: Node3D = _unit_nodes[uid]
		nd.position.y = float(_card_base_y[uid]) + sin(_t * 1.5 + uid * 1.7) * 0.05
	if _hud != null:
		_hud.queue_redraw()


func _update_slot_glow() -> void:
	for row in 3:
		for l in LANES:
			var sm: StandardMaterial3D = _slots[row][l]["mat"]
			var base: Color = _slots[row][l]["base"]
			if row == 2 and _sel >= 0 and phase == Phase.MAIN and you[l] == null:
				var pulse := 0.5 + 0.5 * sin(_t * 5.0)
				var hot := 1.0 if l == _hover_lane else 0.6
				base = Color(0.5, 1.15, 1.5) * (0.7 + 0.3 * pulse) * hot
			elif row == 2 and phase == Phase.STRIKING and l == _strike_lane:
				base = Color(0.55, 1.2, 1.5)
			elif row == 1 and phase == Phase.OPP_TURN and l == _opp_step - 1:
				base = Color(1.5, 0.5, 0.42)
			sm.albedo_color = base


func _advance_strike() -> void:
	_strike_lane += 1
	if _strike_lane >= LANES:
		if _check_over():
			return
		phase = Phase.OPP_TURN
		_opp_step = 0
		_strike_lane = -1
		_msg = "HELIOS responds…"
		return
	var u = you[_strike_lane]
	if u == null:
		_strike_t = 0.05
		return
	var atk := _unit_atk(u)
	if atk <= 0:
		_strike_t = 0.05
		return
	_lunge_unit(u, -1.0)
	# FORK BOMB (split_bore) — BIFURCATED: strike the two diagonal lanes, not straight
	if _has(str(u["id"]), "split_bore"):
		var any := false
		for dl in [-1, 1]:
			var fl: int = _strike_lane + dl
			if fl >= 0 and fl < LANES and opp[fl] != null:
				any = true
				_resolve_hit(u, atk, _strike_lane, fl)
		if not any:
			_float_txt("FORK", _slot_pos(2, _strike_lane), CYAN)
		Sfx.play("clack", -6.0)
		_sync_board()
		return
	# KERNEL PANIC (chain_load) — strikes the opposite lane AND both sides (3-lane clear)
	if _has(str(u["id"]), "chain_load"):
		for dl in [0, -1, 1]:
			var cl: int = _strike_lane + dl
			if cl >= 0 and cl < LANES and opp[cl] != null:
				_resolve_hit(u, atk, _strike_lane, cl)
		_float_txt("CHAIN", _slot_pos(2, _strike_lane), CYAN)
		Sfx.play("clack", -6.0)
		_sync_board()
		return
	# SPEAR-PHISH (targeting_laser) — SNIPER: retarget to the weakest enemy
	var t_lane := _strike_lane
	if _has(str(u["id"]), "targeting_laser"):
		var snipe := _sniper_target()
		if snipe >= 0:
			t_lane = snipe
	if opp[t_lane] != null:
		_resolve_hit(u, atk, _strike_lane, t_lane)
		Sfx.play("clack", -6.0)
	else:
		tip += atk
		_float_txt("+%d TRACE" % atk, _slot_pos(0, _strike_lane) + Vector3(0, 0, -1.2), CYAN)
		Sfx.play("clack", -2.0)
		if _check_over():
			_sync_board()
			return
	_sync_board()


func _advance_opp() -> void:
	## exact Inscryption order: queue advances FIRST (and fights this same turn),
	## then the front row strikes, then the next wave is telegraphed.
	if _opp_step == 0:
		_opp_step += 1
		for l in LANES:
			if opp[l] == null and queue[l] != null:
				opp[l] = queue[l]
				queue[l] = null
		_sync_board()
		return
	if _opp_step <= LANES:
		var lane := _opp_step - 1
		_opp_step += 1
		var u = opp[lane]
		if u == null:
			_strike_t = 0.05
			return
		var tgt = you[lane]
		var atk := _unit_atk(u)
		if tgt != null and _has(str(tgt["id"]), "provoke"):
			atk = maxi(0, atk - 1)   # NOISE: your unit jams incoming by 1
		if atk <= 0:
			_strike_t = 0.05
			return
		_lunge_unit(u, 1.0)
		if tgt != null:
			var died := _hit_unit(tgt, atk, 2, lane)
			if _has(str(tgt["id"]), "spike_casing"):
				if _hit_unit(u, 1, 1, lane):
					_kill("opp", lane)
			if died:
				_kill("you", lane)
			Sfx.play("clack", -6.0)
		else:
			tip -= atk
			_float_txt("-%d TRACE" % atk, _slot_pos(2, lane) + Vector3(0, 0, 1.2), RED)
			Sfx.play("clack", -2.0)
			if _check_over():
				_sync_board()
				return
		_sync_board()
		return
	if _opp_step == LANES + 1:
		_opp_step += 1
		_opp_fill_queue()
		_sync_board()
		return
	_turn_start()


func _turn_start() -> void:
	var grew := energy_max < MAX_ENERGY
	energy_max = mini(energy_max + 1, MAX_ENERGY)
	energy = energy_max
	if grew:
		_show_toast("MAX ENERGY +1", CYAN)
	# UNPACK (morphogen): your seed units grow +1/+1 at the start of your turn (once)
	for l in LANES:
		var mu = you[l]
		if mu != null and _has(str(mu["id"]), "morphogen") and not bool(mu.get("morphed", false)):
			mu["morphed"] = true
			mu["buff"] = int(mu.get("buff", 0)) + 1
			mu["hp"] = int(mu["hp"]) + 1
			_float_txt("UNPACK +1/+1", _slot_pos(2, l), CYAN)
	_sync_board()
	if deck.size() == 0 and mites_left == 0:
		phase = Phase.MAIN
		_msg = "Reserves empty. Play units, or ring the STRIKE bell."
	else:
		phase = Phase.DRAW
		_msg = "Draw: your DECK or a SCRAP MITE." if deck.size() > 0 else "Draw a SCRAP MITE."


func _opp_fill_queue() -> void:
	var per: int = OPP_DECKS[tier]["per_turn"]
	for _i in per:
		if opp_deck.size() == 0:
			return
		var empt: Array = []
		for l in LANES:
			if queue[l] == null:
				empt.append(l)
		if empt.is_empty():
			return
		var lane: int = empt[randi() % empt.size()]
		var id: String = opp_deck.pop_back()
		queue[lane] = {"id": id, "hp": int(CARDS[id][3])}


func _check_over() -> bool:
	if tip >= WIN_TIP:
		phase = Phase.OVER
		_won = true
		_over_at = _t
		_msg = "TRACE TIPPED — the node cracks open."
		return true
	if tip <= -WIN_TIP:
		phase = Phase.OVER
		_won = false
		_over_at = _t
		_msg = "HELIOS traced you — EJECTED."
		return true
	return false


# ==================================================================
# HUD drawing (hand cards, energy bank, trace-scale, text layer)
# ==================================================================
func _on_hud_draw() -> void:
	var vp := _hud.get_viewport_rect().size
	var s := _s()
	_hud_hand()
	_hud_energy(s)
	_hud_scale(vp, s)
	# _hud_attack_arrows(s)   # disabled — confusing; direction UI being redesigned
	_hud_text(vp, s)
	_hud_inspect(vp, s)


func _hud_attack_arrows(s: float) -> void:
	## show which way each unit strikes: cyan = yours (→ HELIOS), red = HELIOS (→ you),
	## plus a preview arrow from the hovered lane while a card is selected.
	if _cam == null:
		return
	for l in LANES:
		if you[l] != null and _unit_atk(you[l]) > 0:
			_arrows_for(you[l], 2, l, 1, CYAN, s)
		if opp[l] != null and _unit_atk(opp[l]) > 0:
			_arrows_for(opp[l], 1, l, 2, RED, s)
	if _sel >= 0 and _sel < hand.size() and _hover_lane >= 0 \
			and phase == Phase.MAIN and you[_hover_lane] == null:
		_arrows_for({"id": hand[_sel]}, 2, _hover_lane, 1, Color(CYAN.r, CYAN.g, CYAN.b, 0.6), s)


func _arrows_for(u: Dictionary, from_row: int, lane: int, to_row: int, col: Color, s: float) -> void:
	var id := str(u["id"])
	var lanes: Array = []
	if _has(id, "split_bore"):
		for dl in [-1, 1]:
			if lane + dl >= 0 and lane + dl < LANES:
				lanes.append(lane + dl)
	elif _has(id, "chain_load"):
		for dl in [-1, 0, 1]:
			if lane + dl >= 0 and lane + dl < LANES:
				lanes.append(lane + dl)
	elif _has(id, "targeting_laser") and to_row == 1:
		var sn := _sniper_target()
		lanes.append(sn if sn >= 0 else lane)
	else:
		lanes.append(lane)
	var from: Vector2 = _cam.unproject_position(_slot_pos(from_row, lane) + Vector3(0, 0.35, 0))
	for t in lanes:
		var to: Vector2 = _cam.unproject_position(_slot_pos(to_row, int(t)) + Vector3(0, 0.35, 0))
		_draw_arrow(from, to, col, s)


func _draw_arrow(from: Vector2, to: Vector2, col: Color, s: float) -> void:
	var d := to - from
	if d.length() < 6.0:
		return
	var dir := d.normalized()
	var head := to - dir * (12.0 * s)
	var perp := Vector2(-dir.y, dir.x) * (7.0 * s)
	_hud.draw_line(from + dir * (12.0 * s), head, Color(col.r, col.g, col.b, 0.5), 2.5 * s)
	_hud.draw_colored_polygon(PackedVector2Array([to, head + perp, head - perp]),
		Color(col.r, col.g, col.b, 0.85))


func _hud_inspect(vp: Vector2, s: float) -> void:
	## right-click card readout: stats, attack pattern, sigil rules, and lore.
	if _inspect_id == "" or not CARDS.has(_inspect_id):
		return
	var c: Array = CARDS[_inspect_id]
	var nm := str(c[0])
	var sigs: Array = c[5]
	var pat := "Strikes the enemy directly opposite."
	if "split_bore" in sigs:
		pat = "Strikes both diagonal lanes."
	elif "chain_load" in sigs:
		pat = "Strikes three lanes (opposite + both sides)."
	elif "targeting_laser" in sigs:
		pat = "Strikes the weakest enemy anywhere."
	var w := 300.0 * s
	var pad := 12.0 * s
	var x := vp.x - w - 22.0 * s
	var y := 132.0 * s
	var h := (76.0 + sigs.size() * 32.0 + (28.0 if LORE.has(nm) else 0.0)) * s
	var r := Rect2(x, y, w, h)
	_hud.draw_rect(r.grow(2.0 * s), Color(0.02, 0.045, 0.06, 0.96))
	_hud.draw_rect(r, Color(CYAN.r, CYAN.g, CYAN.b, 0.55), false, 1.5)
	var cur := y + pad + 11.0 * s
	_hud.draw_string(_font, Vector2(x + pad, cur), nm, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2, _fs(14), CYAN)
	cur += 20.0 * s
	_hud.draw_string(_font, Vector2(x + pad, cur), "ATK %d   HP %d   COST %d" % [int(c[2]), int(c[3]), int(c[4])],
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(10), Color(0.82, 0.86, 0.92))
	cur += 18.0 * s
	_hud.draw_string(_font, Vector2(x + pad, cur), "> " + pat, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2, _fs(10),
		Color(0.6, 0.82, 1.0))
	cur += 20.0 * s
	for sg in sigs:
		_hud.draw_string(_font, Vector2(x + pad, cur), str(SIGIL_SHORT.get(sg, sg)).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(10), AMBER)
		cur += 14.0 * s
		_hud.draw_multiline_string(_font, Vector2(x + pad + 8.0 * s, cur), str(SIGIL_RULES.get(sg, "")),
			HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2 - 8.0 * s, _fs(9), -1, Color(0.74, 0.8, 0.86))
		cur += 18.0 * s
	if LORE.has(nm):
		cur += 5.0 * s
		_hud.draw_multiline_string(_font, Vector2(x + pad, cur), "\"" + str(LORE[nm]) + "\"",
			HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2, _fs(9), -1, Color(0.58, 0.68, 0.8))
	_hud.draw_string(_font, Vector2(x + pad, r.end.y - 9.0 * s), "right-click elsewhere to close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(9), Color(0.5, 0.6, 0.7, 0.7))


func _hud_hand() -> void:
	for i in hand.size():
		if i == _hover_hand or i == _sel:
			continue
		_hud_card(i)
	if _hover_hand >= 0 and _hover_hand != _sel and _hover_hand < hand.size():
		_hud_card(_hover_hand)
	if _sel >= 0 and _sel < hand.size():
		_hud_card(_sel)


func _hud_card(i: int) -> void:
	var r := _hand_rect(i)
	var id: String = hand[i]
	var c: Array = CARDS[id]
	var frame: Texture2D = _tex.get("card_frame")
	var port: Texture2D = _tex.get(str(c[1]))
	var afford := _can_afford(id) and phase == Phase.MAIN
	_hud.draw_rect(r, Color(0.03, 0.045, 0.07))
	if port != null:
		_hud.draw_texture_rect(port, Rect2(r.position + r.size * Vector2(0.13, 0.09),
			r.size * Vector2(0.74, 0.56)), false)
	if frame != null:
		_hud.draw_texture_rect(frame, r, false)
	_hud.draw_string(_font, r.position + Vector2(0, r.size.y * 0.78), str(c[0]),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, _fs(int(r.size.y * 0.056 / _s())), Color(0.78, 0.88, 1.0))
	if not (c[5] as Array).is_empty():
		_hud.draw_string(_font, r.position + Vector2(0, r.size.y * 0.85), _sig_label(c[5]),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, _fs(int(r.size.y * 0.07 / _s())),
			AMBER if _has(id, "ablative_plating") else CYAN)
	var fs := _fs(int(r.size.y * 0.12 / _s()))
	_hud_stat(r.position + Vector2(r.size.x * 0.08, r.size.y * 0.94), str(c[2]), AMBER, fs)
	_hud_stat(r.position + Vector2(r.size.x * 0.76, r.size.y * 0.94), str(c[3]), CYAN, fs)
	if not afford:
		_hud.draw_rect(r, Color(0, 0, 0, 0.42))
	# ENERGY COST — a small discreet disc badge, top-left (red if unaffordable)
	var cost := int(c[4])
	if cost > 0:
		var lack: bool = cost > energy and phase == Phase.MAIN
		var cc := r.position + Vector2(r.size.x * 0.15, r.size.y * 0.10)
		var rad := r.size.y * 0.058
		var acc: Color = RED if lack else Color(0.5, 0.82, 1.0)
		_hud.draw_circle(cc, rad, Color(0.02, 0.05, 0.09, 0.9))
		_hud.draw_arc(cc, rad, 0.0, TAU, 20, acc, 1.5)
		_hud.draw_string(_font, cc + Vector2(-rad * 0.55, rad * 0.5), str(cost),
			HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(int(rad * 1.5 / _s())), acc)
	# ATTACK-DIRECTION glyph, top-right (only for cards that strike)
	if int(c[2]) > 0:
		_draw_dir_glyph(r.position + Vector2(r.size.x * 0.85, r.size.y * 0.10),
			r.size.y * 0.05, c[5])
	if i == _sel:
		_hud.draw_rect(r.grow(3.0), CYAN, false, 2.0)
	elif afford:
		_hud.draw_rect(r.grow(2.0), Color(CYAN.r, CYAN.g, CYAN.b, 0.2 + 0.2 * sin(_t * 3.0)), false, 1.0)


func _hud_stat(pos: Vector2, txt: String, col: Color, fs: int) -> void:
	_hud.draw_string(_font, pos + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
	_hud.draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _arrow_kind(sigs: Array) -> String:
	if "split_bore" in sigs:
		return "fork"
	if "targeting_laser" in sigs:
		return "target"
	if "chain_load" in sigs:
		return "chain"
	return "straight"


func _mk_arrow(cx: float, cy: float, scale: float, ang: float) -> PackedVector2Array:
	var base := [Vector2(0, -1.0), Vector2(-0.68, -0.05), Vector2(-0.26, -0.05),
		Vector2(-0.26, 0.9), Vector2(0.26, 0.9), Vector2(0.26, -0.05), Vector2(0.68, -0.05)]
	var ca := cos(ang)
	var sa := sin(ang)
	var pts := PackedVector2Array()
	for b in base:
		var v: Vector2 = b * scale
		pts.append(Vector2(cx + v.x * ca - v.y * sa, cy + v.x * sa + v.y * ca))
	return pts


func _arrow_tex(kind: String) -> Texture2D:
	## bake a crisp WHITE arrow with a BLACK border into a texture (used on hand + board)
	if _arrow_cache.has(kind):
		return _arrow_cache[kind]
	var sz := 64
	var c := sz * 0.5
	var h := sz * 0.4
	var polys: Array = []
	match kind:
		"fork":
			polys = [_mk_arrow(c - h * 0.42, c + h * 0.1, h * 0.8, -0.6),
				_mk_arrow(c + h * 0.42, c + h * 0.1, h * 0.8, 0.6)]
		"chain":
			polys = [_mk_arrow(c - h * 0.85, c, h * 0.62, 0.0),
				_mk_arrow(c, c, h * 0.62, 0.0), _mk_arrow(c + h * 0.85, c, h * 0.62, 0.0)]
		"target":
			polys = [_mk_arrow(c, c + h * 0.28, h * 0.82, 0.0)]
			var circ := PackedVector2Array()
			for i in 18:
				var a := TAU * i / 18.0
				circ.append(Vector2(c + cos(a) * h * 0.32, c - h * 0.92 + sin(a) * h * 0.32))
			polys.append(circ)
		_:
			polys = [_mk_arrow(c, c, h, 0.0)]
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in sz:
		for x in sz:
			var p := Vector2(x + 0.5, y + 0.5)
			for poly in polys:
				if Geometry2D.is_point_in_polygon(p, poly):
					img.set_pixel(x, y, Color(1, 1, 1, 1))
					break
	var src := img.duplicate()   # 2px black border by dilating the white shape
	for y in sz:
		for x in sz:
			if src.get_pixel(x, y).a > 0.5:
				continue
			var near := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var xx := x + dx
					var yy := y + dy
					if xx >= 0 and xx < sz and yy >= 0 and yy < sz and src.get_pixel(xx, yy).a > 0.5:
						near = true
						break
				if near:
					break
			if near:
				img.set_pixel(x, y, Color(0, 0, 0, 1))
	var tex := ImageTexture.create_from_image(img)
	_arrow_cache[kind] = tex
	return tex


func _draw_dir_glyph(ctr: Vector2, sz: float, sigs: Array) -> void:
	var tex := _arrow_tex(_arrow_kind(sigs))
	var d := sz * 3.4
	_hud.draw_texture_rect(tex, Rect2(ctr - Vector2(d, d) * 0.5, Vector2(d, d)), false)


func _hud_energy(s: float) -> void:
	## discreet segmented charge strip — cyan family, no textures, no backing box
	var vp := _hud.get_viewport_rect().size
	var p := Vector2(28.0 * s, vp.y - 96.0 * s)
	var sel_cost := 0
	if _sel >= 0 and _sel < hand.size():
		sel_cost = int(CARDS[hand[_sel]][4])
	var seg_w := 22.0 * s
	var seg_h := 10.0 * s
	var pitch := seg_w + 4.0 * s
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	_hud.draw_string(_font, p + Vector2(0.0, -6.0 * s), "ENERGY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(9), Color(CYAN.r, CYAN.g, CYAN.b, 0.55))
	for i in MAX_ENERGY:
		var r := Rect2(p + Vector2(i * pitch, 0.0), Vector2(seg_w, seg_h))
		if i >= energy_max:
			_hud.draw_rect(r, Color(CYAN.r, CYAN.g, CYAN.b, 0.07), false, 1.0)
			continue
		var spending := sel_cost > 0 and i >= energy - sel_cost and i < energy
		if i < energy:
			var base := AMBER if spending else CYAN
			var a := 0.85
			if i == energy - 1 and not spending:
				a = 0.55 + 0.35 * pulse
			_hud.draw_rect(r, Color(base.r, base.g, base.b, a))
			_hud.draw_line(r.position, r.position + Vector2(seg_w, 0.0),
				Color(base.r, base.g, base.b, 0.9), 1.0)
		else:
			_hud.draw_rect(r, Color(CYAN.r, CYAN.g, CYAN.b, 0.28), false, 1.0)
	var by := p.y + seg_h + 3.0 * s
	_hud.draw_line(Vector2(p.x, by), Vector2(p.x + (MAX_ENERGY - 1) * pitch + seg_w, by),
		Color(CYAN.r, CYAN.g, CYAN.b, 0.18), 1.0)
	var nx := p.x + (MAX_ENERGY - 1) * pitch + seg_w + 8.0 * s
	var ncol := AMBER if sel_cost > 0 else CYAN
	_hud.draw_string(_font, Vector2(nx, p.y + seg_h), "%d/%d" % [energy, energy_max],
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(13), Color(ncol.r, ncol.g, ncol.b, 0.9))


func _hud_scale(vp: Vector2, s: float) -> void:
	## TRACE LOCK — a decryption dial; the needle swings toward whoever is winning and
	## ticks lock in one per trace point, with an outer ring flaring near a lock (±5).
	var C := Vector2(vp.x * 0.5, 116.0 * s)
	var R := 60.0 * s
	var up := -PI / 2.0
	var span := deg_to_rad(78.0)
	var norm := clampf(_tip_anim / float(WIN_TIP), -1.0, 1.0)
	var a := up + norm * span
	var ncol := CYAN if _tip_anim > 0.0 else (RED if _tip_anim < 0.0 else Color(0.7, 0.8, 0.9))
	# base track + faction halves
	_hud.draw_arc(C, R, up - span, up + span, 64, Color(0.12, 0.18, 0.22, 0.9), 6.0 * s)
	_hud.draw_arc(C, R, up - span, up, 32, Color(RED.r, RED.g, RED.b, 0.18), 6.0 * s)
	_hud.draw_arc(C, R, up, up + span, 32, Color(CYAN.r, CYAN.g, CYAN.b, 0.18), 6.0 * s)
	# filled sweep from top to the needle
	if norm >= 0.0:
		_hud.draw_arc(C, R, up, a, 48, ncol, 6.0 * s)
	else:
		_hud.draw_arc(C, R, a, up, 48, ncol, 6.0 * s)
	# 5 ticks per side, lit as the trace advances
	for k in range(1, 6):
		for sgn in [-1, 1]:
			var sf: float = float(sgn)
			var ta: float = up + sf * (float(k) / 5.0) * span
			var tcol: Color = CYAN if sgn > 0 else RED
			var lit: bool = (sgn > 0 and tip >= k) or (sgn < 0 and tip <= -k)
			var dir := Vector2(cos(ta), sin(ta))
			_hud.draw_line(C + dir * (R - 9.0 * s), C + dir * (R + 9.0 * s),
				Color(tcol.r, tcol.g, tcol.b, 1.0 if lit else 0.25), 3.0 * s if lit else 2.0 * s)
	# needle + hub
	var tipp := C + Vector2(cos(a), sin(a)) * (R - 4.0 * s)
	var perp := Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * (5.0 * s)
	_hud.draw_colored_polygon(PackedVector2Array([C + perp, tipp, C - perp]), ncol)
	_hud.draw_circle(C, 9.0 * s, Color(0.05, 0.08, 0.1))
	_hud.draw_arc(C, 9.0 * s, 0.0, TAU, 24, ncol, 1.5 * s)
	# numeric core + caption
	_hud.draw_string(_font, C + Vector2(-50.0 * s, 34.0 * s), "%+d" % tip,
		HORIZONTAL_ALIGNMENT_CENTER, 100.0 * s, _fs(30), ncol)
	_hud.draw_string(_font, C + Vector2(-70.0 * s, 50.0 * s), "TRACE LOCK  5",
		HORIZONTAL_ALIGNMENT_CENTER, 140.0 * s, _fs(9), Color(0.6, 0.75, 0.9, 0.7))
	# side labels + imminent-lock flare
	_hud.draw_string(_font, C + Vector2(-R - 54.0 * s, -R * 0.3), "HELIOS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(11), RED)
	_hud.draw_string(_font, C + Vector2(R + 10.0 * s, -R * 0.3), "YOU",
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(11), CYAN)
	if absf(_tip_anim) >= 4.0:
		var fl := 0.35 + 0.4 * sin(_t * 10.0)
		_hud.draw_arc(C, R + 7.0 * s, up - span, up + span, 64,
			Color(ncol.r, ncol.g, ncol.b, fl), 2.0 * s)


func _hud_text(vp: Vector2, s: float) -> void:
	_hud.draw_rect(Rect2(0, 0, vp.x, 46.0 * s), Color(0.02, 0.03, 0.05, 0.85))
	_hud.draw_string(_font, Vector2(20.0 * s, 30.0 * s), "NODE DUEL — TIER %d" % tier,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(17), CYAN)
	_hud.draw_string(_font, Vector2(0, 30.0 * s), _msg, HORIZONTAL_ALIGNMENT_CENTER, vp.x, _fs(15),
		Color(0.85, 0.92, 1.0))
	var chip := ""
	var ccol := CYAN
	match phase:
		Phase.DRAW:
			chip = "YOUR TURN — DRAW"
			ccol = AMBER
		Phase.MAIN:
			chip = "YOUR TURN — PLAY"
		Phase.STRIKING:
			chip = "STRIKE!"
		Phase.OPP_TURN:
			chip = "HELIOS ACTS"
			ccol = RED
	if chip != "":
		var pulse := 0.75 + 0.25 * sin(_t * 4.0)
		_hud.draw_string(_font, Vector2(vp.x - 320.0 * s, 30.0 * s), chip,
			HORIZONTAL_ALIGNMENT_RIGHT, 300.0 * s, _fs(15), Color(ccol.r, ccol.g, ccol.b, pulse))
	# pile flash on dead draw-clicks — projected over the 3D piles
	if _pile_flash > 0.0 or phase == Phase.DRAW:
		for pv in [[DECK_POS, deck.size(), "DECK %d"], [MITE_POS, mites_left, "SHELLS %d"]]:
			if not _cam.is_position_in_frustum(pv[0]):
				continue
			var sp := _cam.unproject_position(pv[0])
			if phase == Phase.DRAW and int(pv[1]) > 0:
				var pr := Rect2(sp - Vector2(52.0, 40.0) * s, Vector2(104.0, 80.0) * s)
				_hud.draw_rect(pr, Color(CYAN.r, CYAN.g, CYAN.b, 0.4 + 0.3 * sin(_t * 5.0)), false, 2.0)
			if _pile_flash > 0.0:
				var pr2 := Rect2(sp - Vector2(56.0, 44.0) * s, Vector2(112.0, 88.0) * s)
				_hud.draw_rect(pr2, Color(AMBER.r, AMBER.g, AMBER.b, _pile_flash), false, 3.0)
			_hud.draw_string(_font, sp + Vector2(-52.0 * s, 58.0 * s), str(pv[2]) % int(pv[1]),
				HORIZONTAL_ALIGNMENT_CENTER, 104.0 * s, _fs(12), Color(0.7, 0.85, 1.0, 0.85))
	if phase == Phase.DRAW:
		var dp := _cam.unproject_position(DECK_POS + Vector3(0.65, 0, 0))
		_hud.draw_string(_font, dp + Vector2(-60.0 * s, -54.0 * s + sin(_t * 4.0) * 4.0 * s),
			"DRAW", HORIZONTAL_ALIGNMENT_CENTER, 120.0 * s, _fs(16), AMBER)
	if phase == Phase.MAIN:
		var bp := _bell_screen_rect()
		if bp.size.x > 0.0:
			_hud.draw_string(_font, Vector2(bp.position.x, bp.end.y + 14.0 * s), "STRIKE",
				HORIZONTAL_ALIGNMENT_CENTER, bp.size.x, _fs(13), Color(0.9, 0.6, 0.55))
	# floating combat numbers over the 3D board
	for f in _floaters:
		var ft := float(f["t"])
		var wp: Vector3 = f["wpos"]
		if not _cam.is_position_in_frustum(wp):
			continue
		var sp2 := _cam.unproject_position(wp)
		var col: Color = f["col"]
		_hud.draw_string(_font, sp2 + Vector2(-60.0, -40.0 * s * ft), str(f["txt"]),
			HORIZONTAL_ALIGNMENT_CENTER, 120.0, _fs(18), Color(col.r, col.g, col.b, 1.0 - ft))
	if not _toast.is_empty():
		var tt := float(_toast["t"])
		var col2: Color = _toast["col"]
		_hud.draw_string(_font, Vector2(0, vp.y - _card_size2d().y - 40.0 * s), str(_toast["txt"]),
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, _fs(16), Color(col2.r, col2.g, col2.b, 1.0 - tt * tt))
	if phase == Phase.OVER:
		_hud.draw_rect(Rect2(0, vp.y * 0.5 - 56.0 * s, vp.x, 112.0 * s), Color(0.02, 0.03, 0.05, 0.9))
		_hud.draw_string(_font, Vector2(0, vp.y * 0.5 + 4.0 * s),
			"NODE CRACKED" if _won else "EJECTED",
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, _fs(40), CYAN if _won else RED)
		if _t - _over_at > 0.5:
			_hud.draw_string(_font, Vector2(0, vp.y * 0.5 + 40.0 * s), "click to continue",
				HORIZONTAL_ALIGNMENT_CENTER, vp.x, _fs(14), Color(0.8, 0.9, 1.0, 0.7))
