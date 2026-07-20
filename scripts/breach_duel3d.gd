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
const MAX_ENERGY := 6

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
	"scrap_mite":     ["HOLLOW SHELL", "u_hollow", 0, 2, 1, []],
	# --- PLAYER intrusion units (cyan) ---
	"power_siphon":   ["POWER SIPHON", "u_siphon", 0, 1, 2, ["overcharge"]],
	"buckler_mite":   ["BUCKLER MITE", "u_buckler", 1, 1, 2, ["ablative_plating"]],
	"lance_drone":    ["LANCE DRONE", "u_lance", 1, 1, 3, ["targeting_laser"]],
	"fork_turret":    ["FORK TURRET", "u_fork", 2, 1, 6, ["split_bore"]],
	"grunt_bot":      ["GRUNT BOT", "u_grunt", 1, 1, 3, []],
	"piston_ram":     ["PISTON RAM", "u_piston", 2, 2, 6, []],
	"bulwark_breaker": ["BULWARK BREAKER", "u_bulwark", 1, 3, 5, []],
	"skip_worm":      ["SKIP WORM", "u_skipworm", 2, 3, 4, []],
	"screech_mote":   ["SCREECH MOTE", "u_screech", 2, 1, 3, ["provoke"]],
	"spike_mite":     ["SPIKE MITE", "u_spikemite", 1, 1, 2, ["spike_casing"]],
	"sapper_worm":    ["SAPPER WORM", "u_sapper", 1, 2, 3, ["meltdown"]],
	"charge_mite":    ["CHARGE MITE", "u_chargemite", 1, 1, 2, ["overcharge"]],
	"swarm_hound":    ["SWARM HOUND", "u_swarmhound", 2, 2, 6, ["mite_spawner"]],
	"prism_ripper":   ["PRISM RIPPER", "u_ripper", 3, 1, 5, []],
	"watcher_seed":   ["WATCHER SEED", "u_seed", 0, 1, 1, ["morphogen"]],
	# --- ENEMY firewall units (red); AI pays no energy so cost = 0 ---
	"barrier_node":   ["BARRIER NODE", "u_barrier", 0, 3, 0, []],
	"sentry_ice":     ["SENTRY ICE", "u_sentry", 1, 2, 0, ["autoturret"]],
	"packet_daemon":  ["PACKET DAEMON", "u_daemon", 3, 2, 0, []],
	"raptor_proc":    ["RAPTOR PROC", "u_raptor", 2, 3, 0, ["interpose"]],
	"heap_giant":     ["HEAP GIANT", "u_heap", 2, 4, 0, []],
	"spike_wall":     ["SPIKE WALL", "u_spikewall", 1, 2, 0, ["spike_casing"]],
	"trace_hound":    ["TRACE HOUND", "u_tracehound", 1, 1, 0, []],
	"null_relay":     ["NULL RELAY", "u_null", 0, 1, 0, []],
	"firewall_slab":  ["FIREWALL SLAB", "u_slab", 1, 5, 0, []],
	# --- BOSS / special firewall cards ---
	"freeze_frame":   ["FREEZE-FRAME", "u_freeze", 1, 1, 0, []],
	"index_warden":   ["INDEX WARDEN", "u_index", 1, 2, 0, ["ablative_plating"]],
	"kernel_ghost":   ["KERNEL GHOST", "u_kernel", 2, 2, 0, []],
	"daemon_ursa":    ["URSA-DAEMON", "u_ursa", 4, 4, 0, []],
	"daemon_vespa":   ["VESPA-DAEMON", "u_vespa", 2, 1, 0, ["interpose"]],
	"daemon_quill":   ["QUILL-DAEMON", "u_quill", 2, 2, 0, ["spike_casing"]],
}
# starter deck (11) — energy engine + blockers + snipers + a turn-6 finisher
const PLAYER_DECK := ["power_siphon", "power_siphon", "buckler_mite", "buckler_mite",
	"lance_drone", "lance_drone", "grunt_bot", "grunt_bot", "watcher_seed", "sapper_worm", "fork_turret"]
# HELIOS firewall decks per tier (T1/T2/T3 pools); zone bosses layered in later
const OPP_DECKS := {
	1: {"deck": ["barrier_node", "sentry_ice", "null_relay", "trace_hound", "sentry_ice", "barrier_node"], "per_turn": 1},
	2: {"deck": ["spike_wall", "packet_daemon", "sentry_ice", "trace_hound", "barrier_node", "packet_daemon", "spike_wall"], "per_turn": 1},
	3: {"deck": ["raptor_proc", "heap_giant", "firewall_slab", "daemon_ursa", "packet_daemon", "raptor_proc", "heap_giant"], "per_turn": 2},
}
const SIGIL_SHORT := {
	"overcharge": "OVERCHARGE", "ablative_plating": "ARMOR", "targeting_laser": "SNIPER",
	"split_bore": "SPLIT SHOT", "spike_casing": "SPIKES", "provoke": "PROVOKE",
	"meltdown": "MELTDOWN", "autoturret": "SENTRY", "interpose": "GUARD",
	"mite_spawner": "SWARM", "morphogen": "MORPH",
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
const DECK_POS := Vector3(6.7, 0.02, 1.9)
const MITE_POS := Vector3(5.4, 0.02, 1.9)

enum Phase { DRAW, MAIN, STRIKING, OPP_TURN, OVER }
var phase: int = Phase.MAIN            # turn 1 skips the draw
var tier := 1

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
			sm.albedo_texture = _tex.get("slot_cell")
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
	bs.pixel_size = 0.016
	bs.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bs.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bs.shaded = false
	bs.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
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


func _lane_x(l: int) -> float:
	return (l - (LANES - 1) * 0.5) * CELL_W


func _slot_pos(row: int, lane: int) -> Vector3:
	return Vector3(_lane_x(lane), 0.0, ROW_Z[row])


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
	var name_l := _label(str(c[0]), 40, Color(0.8, 0.9, 1.0, dim.a))
	name_l.position = Vector3(0, -CARD_H * 0.26, 0.02)
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
	# energy pips top-left (board cards keep them for readability)
	var cost := int(c[4])
	var cf: Texture2D = _tex.get("cell_full")
	for b in cost:
		var pip := Sprite3D.new()
		pip.texture = cf
		if cf != null:
			pip.pixel_size = (CARD_W * 0.09) / cf.get_width()
		pip.position = Vector3(-CARD_W * 0.38 + b * CARD_W * 0.11, CARD_H * 0.44, 0.02)
		pip.modulate = dim
		pip.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		pip.shaded = false
		root.add_child(pip)
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
	# a flat "docked card" plate on the slot, so the real card reads as lifting off it
	var bp: MeshInstance3D
	if _base_nodes.has(uid):
		bp = _base_nodes[uid]
	else:
		bp = MeshInstance3D.new()
		var qm := PlaneMesh.new()
		qm.size = Vector2(CARD_W * 0.92, CARD_H * 0.92)
		bp.mesh = qm
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_texture = _tex.get("card_frame")
		bmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.alpha_scissor_threshold = 0.5
		bmat.albedo_color = Color(0.22, 0.26, 0.32, 1.0)   # dark docked-card silhouette
		bp.mesh.surface_set_material(0, bmat)
		add_child(bp)
		_base_nodes[uid] = bp
	bp.position = Vector3(base.x, 0.028, base.z)
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
			_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
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
	## juicy button press: squash + sink hard, then elastic spring back, with a flash
	var tw := _bell_node.create_tween()
	tw.tween_property(_bell_node, "position:y", BELL_POS.y - 0.26, 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_bell_node, "position:y", BELL_POS.y, 0.6) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _bell_spr != null:
		var st := _bell_spr.create_tween()
		st.tween_property(_bell_spr, "scale", Vector3(1.22, 0.58, 1.0), 0.05) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.tween_property(_bell_spr, "scale", Vector3.ONE, 0.6) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var ft := _bell_spr.create_tween()
		ft.tween_property(_bell_spr, "modulate", Color(2.6, 1.8, 1.7), 0.04)
		ft.tween_property(_bell_spr, "modulate", Color(1, 1, 1), 0.4)


func _place_selected(lane: int) -> void:
	var id: String = hand[_sel]
	# Battery Bearer resolves BEFORE the cost is deducted (Act 3 rule)
	if _has(id, "overcharge"):
		energy_max = mini(energy_max + 1, MAX_ENERGY)
		energy = mini(energy + 1, MAX_ENERGY)
		_show_toast("OVERCHARGE — +1 energy", CYAN)
	energy -= int(CARDS[id][4])
	you[lane] = {"id": id, "hp": int(CARDS[id][3]), "armor": _has(id, "ablative_plating")}
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
	var tgt = opp[_strike_lane]
	var atk := int(CARDS[u["id"]][2])
	if tgt != null and _has(str(tgt["id"]), "provoke"):
		atk += 1   # PROVOKE: the card opposite a provoker strikes for +1
	if atk <= 0:
		_strike_t = 0.05
		return
	_lunge_unit(u, -1.0)
	if tgt != null:
		var pre := int(tgt["hp"])
		var died := _hit_unit(tgt, atk, 1, _strike_lane)
		if _has(str(tgt["id"]), "spike_casing"):   # SPIKES: struck target bites back for 1
			if _hit_unit(u, 1, 2, _strike_lane):
				you[_strike_lane] = null
		if died:
			opp[_strike_lane] = null
			# overkill spills into the queued unit behind (never to the scale)
			var excess := atk - pre
			var q = queue[_strike_lane]
			if excess > 0 and q != null:
				if _hit_unit(q, excess, 0, _strike_lane):
					queue[_strike_lane] = null
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
		var atk := int(CARDS[u["id"]][2])
		if tgt != null and _has(str(tgt["id"]), "provoke"):
			atk += 1
		if atk <= 0:
			_strike_t = 0.05
			return
		_lunge_unit(u, 1.0)
		if tgt != null:
			var died := _hit_unit(tgt, atk, 2, lane)
			if _has(str(tgt["id"]), "spike_casing"):
				if _hit_unit(u, 1, 1, lane):
					opp[lane] = null
			if died:
				you[lane] = null
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
	_hud_text(vp, s)


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
	_hud.draw_string(_font, r.position + Vector2(0, r.size.y * 0.76), str(c[0]),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, _fs(int(r.size.y * 0.09 / _s())), Color(0.8, 0.9, 1.0))
	if not (c[5] as Array).is_empty():
		_hud.draw_string(_font, r.position + Vector2(0, r.size.y * 0.85), _sig_label(c[5]),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, _fs(int(r.size.y * 0.07 / _s())),
			AMBER if _has(id, "ablative_plating") else CYAN)
	var fs := _fs(int(r.size.y * 0.12 / _s()))
	_hud_stat(r.position + Vector2(r.size.x * 0.08, r.size.y * 0.94), str(c[2]), AMBER, fs)
	_hud_stat(r.position + Vector2(r.size.x * 0.76, r.size.y * 0.94), str(c[3]), CYAN, fs)
	if not afford:
		_hud.draw_rect(r, Color(0, 0, 0, 0.42))
	# ENERGY COST — an unmissable top-left badge: battery icon + big number,
	# red when you can't pay it this turn
	var cost := int(c[4])
	if cost > 0:
		var bh := r.size.y * 0.155
		var br := Rect2(r.position + Vector2(r.size.x * 0.045, r.size.y * 0.03),
			Vector2(bh * 1.85, bh))
		var lack: bool = cost > energy and phase == Phase.MAIN
		_hud.draw_rect(br, Color(0.02, 0.05, 0.08, 0.94))
		_hud.draw_rect(br, RED if lack else CYAN, false, 2.0)
		var cf: Texture2D = _tex.get("cell_full")
		if cf != null:
			_hud.draw_texture_rect(cf, Rect2(br.position + Vector2(bh * 0.12, bh * 0.1),
				Vector2(bh * 0.55, bh * 0.8)), false,
				Color(1.0, 0.5, 0.45) if lack else Color(1, 1, 1))
		_hud.draw_string(_font, Vector2(br.position.x + bh * 0.78, br.end.y - bh * 0.18),
			str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(int(bh * 0.85 / _s())),
			RED if lack else CYAN)
	if i == _sel:
		_hud.draw_rect(r.grow(3.0), CYAN, false, 2.0)
	elif afford:
		_hud.draw_rect(r.grow(2.0), Color(CYAN.r, CYAN.g, CYAN.b, 0.2 + 0.2 * sin(_t * 3.0)), false, 1.0)


func _hud_stat(pos: Vector2, txt: String, col: Color, fs: int) -> void:
	_hud.draw_string(_font, pos + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
	_hud.draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _hud_energy(s: float) -> void:
	## the cell bank — and while a card is selected, the cells it will drain burn amber
	var vp := _hud.get_viewport_rect().size
	var p := Vector2(28.0 * s, vp.y - 150.0 * s)
	var cw := 30.0 * s
	var ch := 46.0 * s
	var full: Texture2D = _tex.get("cell_full")
	var empty: Texture2D = _tex.get("cell_empty")
	var sel_cost := 0
	if _sel >= 0 and _sel < hand.size():
		sel_cost = int(CARDS[hand[_sel]][4])
	_hud.draw_rect(Rect2(p - Vector2(10.0 * s, 34.0 * s),
		Vector2(MAX_ENERGY * (cw + 7.0 * s) + 14.0 * s, ch + 48.0 * s)),
		Color(0.02, 0.04, 0.06, 0.72))
	for i in energy_max:
		var r := Rect2(p + Vector2(i * (cw + 7.0 * s), 0), Vector2(cw, ch))
		var tex := full if i < energy else empty
		var mod := Color(1, 1, 1)
		if sel_cost > 0 and i >= energy - sel_cost and i < energy:
			mod = Color(1.0, 0.72, 0.35)   # about to be spent
		if tex != null:
			_hud.draw_texture_rect(tex, r, false, mod)
		else:
			_hud.draw_rect(r, CYAN if i < energy else Color(0.2, 0.3, 0.4), i >= energy, 2.0)
	_hud.draw_string(_font, p + Vector2(0, -12.0 * s), "ENERGY  %d / %d" % [energy, energy_max],
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(17), CYAN)
	_hud.draw_string(_font, p + Vector2(0, ch + 18.0 * s), "+1 max each turn, refills full",
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(11), Color(0.6, 0.75, 0.9, 0.6))


func _hud_scale(vp: Vector2, s: float) -> void:
	var w := 340.0 * s
	var r := Rect2(Vector2((vp.x - w) * 0.5, 58.0 * s), Vector2(w, 26.0 * s))
	_hud.draw_rect(r, PANEL)
	_hud.draw_rect(r, EDGE, false, 2.0)
	for i in range(1, 10):
		var x := r.position.x + r.size.x * (i / 10.0)
		_hud.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y),
			Color(EDGE.r, EDGE.g, EDGE.b, 0.25), 1.0)
	var ncol := CYAN if tip > 0 else (RED if tip < 0 else Color(0.8, 0.85, 0.9))
	var frac := clampf((_tip_anim + WIN_TIP) / float(WIN_TIP * 2), 0.0, 1.0)
	var cx := r.position.x + r.size.x * 0.5
	var nx := r.position.x + r.size.x * frac
	if absf(nx - cx) > 1.0:
		_hud.draw_rect(Rect2(minf(cx, nx), r.position.y, absf(nx - cx), r.size.y),
			Color(ncol.r, ncol.g, ncol.b, 0.3))
	_hud.draw_rect(Rect2(nx - 3.0, r.position.y - 5.0, 6.0, r.size.y + 10.0), ncol)
	_hud.draw_string(_font, Vector2(r.position.x - 92.0 * s, r.position.y + 19.0 * s), "EJECT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(13), RED)
	_hud.draw_string(_font, Vector2(r.end.x + 10.0 * s, r.position.y + 19.0 * s), "CRACK  %+d" % tip,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(13), ncol)


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
