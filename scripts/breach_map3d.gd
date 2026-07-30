extends Node3D
## THE BREACH MAP — now a 3D corridor crawl through the station, same angled perspective
## as the duel. Nodes are round tokens standing on deck-plate cells; grid-square corridors
## (Manhattan bends) link them over the void. You walk the marker node-to-node up to the
## HELIOS core. Battle nodes open THE DUEL (breach_duel3d.gd). Rows are category-typed exactly
## like the old chart (gain / utility / battle, core on top). ESC / freeing the core → flight.
## Run standalone: godot res://scenes/breach.tscn   (SW_BREACH_CH=1 jumps into a duel)

static var station_name := ""
static var station_id := ""

const DUEL := preload("res://scripts/breach_duel3d.gd")
const ART_DIRS := ["res://assets/sprites/breach/hd/", "res://assets/sprites/breach/scifi/"]
const MAP_DIR := "res://assets/sprites/breach/map3d/"
const THEME_DIR := "res://assets/sprites/breach/themes/"

const ROW_PLAN := ["access", "gain", "util", "battle", "gain", "util", "battle", "gain", "util", "core"]
const CATEGORY := {
	"gain": ["cache", "vault", "recycler", "cache"],
	# quarantine IS in the pool — it was defined in TYPES with art and an effect but never
	# listed here, so the gate (and therefore the vault tool that opens it) never spawned
	"util": ["pod", "ghost", "splicer", "overclock", "exchange", "merge", "uplink", "blackice",
		"quarantine"],
	"battle": ["firewall", "sentinel", "bounty"],
}
# type -> [label, icon, challenge difficulty (0 = event)]
const TYPES := {
	"access": ["ACCESS PORT", "icon_access", 0], "firewall": ["FIREWALL", "icon_firewall", 1],
	"sentinel": ["SENTINEL", "icon_sentinel", 2], "pod": ["SURVIVOR POD", "icon_pod", 0],
	"cache": ["DATA CACHE", "icon_cache", 0], "ghost": ["GHOST SIGNAL", "icon_ghost", 0],
	"vault": ["DATA VAULT", "icon_vault", 0], "core": ["HELIOS CORE", "icon_core", 5],   # 5 = SOLAR WARDEN boss deck
	# --- the sigil economy: shards fund the deck-editing rigs (Act 3 Robobucks) ---
	"recycler": ["RECYCLER", "icon_recycler", 0],
	"splicer": ["CODE SPLICER", "icon_splicer", 0],
	"overclock": ["OVERCLOCK RIG", "icon_overclock", 0],
	"exchange": ["EXCHANGE TERMINAL", "icon_exchange", 0],
	"bounty": ["BOUNTY DAEMON", "icon_bounty", 2],
	"merge": ["MERGE LAB", "icon_merge", 0],
	"blackice": ["BLACK ICE", "icon_blackice", 0],
	"uplink": ["UPLINK RELAY", "icon_uplink", 0],
	"quarantine": ["QUARANTINE GATE", "icon_quarantine", 0],
}
# what each rig costs in code shards (0 = free / grants shards)
const NODE_COST := {
	"splicer": 12, "overclock": 9, "exchange": 7, "merge": 6, "blackice": 0, "uplink": 3,
}

const GRIDW := 7           # corridor grid columns
const CELL := 1.75         # world size of one grid cell
const ROWSTEP := 2         # grid cells between node rows (room for a corridor bend)
const CYAN := Color(0.5, 0.9, 1.0)
const RED := Color(1.0, 0.4, 0.32)
# per-node accent colour — breaks the all-blue stage; drives each node's light + glow
# restrained: your objectives glow one cool cyan family, only the threats run warm
const TYPE_COLOR := {
	"access": Color(0.5, 0.8, 0.95), "firewall": Color(0.9, 0.55, 0.3),
	"sentinel": Color(0.9, 0.48, 0.34), "pod": Color(0.46, 0.82, 0.9),
	"cache": Color(0.54, 0.8, 0.92), "ghost": Color(0.5, 0.76, 0.9),
	"vault": Color(0.5, 0.8, 0.95), "core": Color(0.95, 0.42, 0.26),
	"recycler": Color(0.55, 0.86, 0.6), "splicer": Color(0.5, 0.82, 0.95),
	"overclock": Color(0.74, 0.55, 0.96), "exchange": Color(0.52, 0.86, 0.8),
	"bounty": Color(0.95, 0.36, 0.3), "merge": Color(0.6, 0.9, 0.62),
	"blackice": Color(0.76, 0.5, 0.96), "uplink": Color(0.6, 0.85, 0.95),
	"quarantine": Color(0.92, 0.72, 0.36),
}

enum Mode { MAP, CHALLENGE, WON }
var mode: int = Mode.MAP

# ---- run state: what you carry through this station ----
var shards := 0             # code shards — the Act 3 Robobucks equivalent
var colonists := 0          # SURVIVOR PODs banked; they land when the core falls
var has_tool := false       # DATA VAULT breach tool — opens QUARANTINE GATEs
var streak := 0             # duels won this run; BOUNTY DAEMON scales off it
var revealed := false       # UPLINK RELAY: upcoming rows show their threat tier
# keyboard choice modal: {"title": String, "opts": Array[String], "cb": Callable}
var _choice := {}

var nodes: Array = []      # {row,col,ncol,type,links,state,gx,gz, node:Node3D, token:MeshInstance3D}
var cur := -1
var _pending := -1
var _ice_fought := false   # did the player ACCEPT the BLACK ICE fight (vs walk past it)
var _msg := "Breach open. Walk the marker to a lit node."
var _t := 0.0

var _cam: Camera3D
var _cam_ahead := Vector3.ZERO   # camera lead toward the destination while moving
var _look_at := Vector3.ZERO
var _cam_init := false
var _walk_dest := Vector3.ZERO
var _hud: Control
var _marker: Node3D
var _marker_spr: Sprite3D
var _marker_frames: Array = []         # PixelLab astronaut walk-cycle frames (front)
var _mf_left: Array = []
var _mf_right: Array = []
var _mf_back: Array = []
var _marker_walk_dist := 0.0
var _last_side: Array = []   # side profile used when moving toward the camera (no front walk)
var _marker_last_pos := Vector3.ZERO
var _moving := false
var _tex := {}
var _duel: Node3D = null
var _hidden: Array = []     # map nodes hidden while a duel is on screen
var _path_mat: StandardMaterial3D       # recessed walkway floor
var _cube_top_mat: StandardMaterial3D   # top of the raised block field
var _cube_side_mat: StandardMaterial3D  # block side walls
var _shadow_tex: Texture2D
var _sigil_ok := false            # did SIGIL_SHADER compile? props fall back if not
var _sigil_shader: Shader          # SIGIL_SHADER, one instance shared by every prop
var _font: Font = ThemeDB.fallback_font
var _flows: Array = []      # {spr, pts:PackedVector3Array, cum, len, phase, speed}
var _overlay: CanvasLayer   # scanline/vignette/tilt-shift post overlay (hidden during duel)
var _emis_cache := {}       # shared emissive materials for set-piece windows
var _icon_anim := {}        # node type -> ping-ponged frame list for its idle animation
const ICON_FPS := 7.0
var _edge_mats := {}        # Vector2i(from,to) -> [halo mat, core mat] for that corridor
var _edge_cells := {}       # Vector2i(from,to) -> Array[Vector2i] cells that corridor covers
var _cell_light := {}       # cell -> its corridor OmniLight3D
var _cell_dot := {}         # cell -> its junction dot material
var _seg_owners := {}       # Vector4i(cellA,cellB) -> Array of edge keys using that stretch
var _conduit: MeshInstance3D          # the whole corridor network, one mesh
var _conduit_mat: StandardMaterial3D
var _hover_node := -1       # reachable node the cursor is over; its corridor previews yellow
const EDGE_LIVE := Color(0.75, 0.92, 1.0)    # walkable from here
const EDGE_PICK := Color(1.0, 0.86, 0.32)    # the route you're pointing at
const EDGE_DEAD := Color(0.30, 0.33, 0.38)   # spent or unreachable


func _ready() -> void:
	print("BREACH: entering '", station_name, "' (", station_id, ")")
	if OS.get_environment("SW_SEED") != "":
		seed(int(OS.get_environment("SW_SEED")))   # DEV: fixed map layout for A/B shots
	if OS.get_environment("SW_BREACH_ST") != "":
		station_id = OS.get_environment("SW_BREACH_ST")
		station_name = station_id.replace("_", " ")
	for t in TYPES:
		_tex[TYPES[t][1]] = _load_art(str(TYPES[t][1]))
	_tex["marker"] = _load_art("marker")
	for _mi in range(1, 33):   # sets may be 8 or 16 frames (smoothed); stop at the first gap
		var mf := _load_png(MAP_DIR + "marker_walk_%02d.png" % _mi)
		if mf != null and _marker_frames.size() == _mi - 1:
			_marker_frames.append(mf)
		var ml := _load_png(MAP_DIR + "marker_walk_left_%02d.png" % _mi)
		if ml != null and _mf_left.size() == _mi - 1:
			_mf_left.append(ml)
		var mr := _load_png(MAP_DIR + "marker_walk_right_%02d.png" % _mi)
		if mr != null and _mf_right.size() == _mi - 1:
			_mf_right.append(mr)
		var mb := _load_png(MAP_DIR + "marker_walk_back_%02d.png" % _mi)
		if mb != null and _mf_back.size() == _mi - 1:
			_mf_back.append(mb)
	# per-sigil idle animations (PixelLab, 6 frames each) — the props breathe on the map
	for t in TYPES:
		var frames: Array = []
		for fi in range(1, 7):
			var ft := _load_png(ART_DIRS[0] + "anim/%s_%02d.png" % [t, fi])
			if ft != null:
				frames.append(ft)
		if frames.size() >= 2:
			# ping-pong: several sigils fade monotonically bright->dark, so wrapping would
			# pop. Bouncing the sequence reads smooth whatever the frames do.
			var seq: Array = frames.duplicate()
			for bi in range(frames.size() - 2, 0, -1):
				seq.append(frames[bi])
			_icon_anim[t] = seq
	_tex["token_base"] = _load_png(MAP_DIR + "token_base.png")
	for fx in ["dust", "flow_arrow", "node_ring", "shockwave", "light_shaft", "spark"]:
		_tex[fx] = _load_png(MAP_DIR + "fx/" + fx + ".png")
	# a fresh station means a fresh deck: the sigil rigs edit THIS array all run long
	DUEL.run_deck = DUEL.PLAYER_DECK.duplicate()
	DUEL.atk_boost = {}
	DUEL.graft = {}
	DUEL.fragile = []
	_build_shadow_tex()
	_build_stage()
	_gen_map()
	_build_map_nodes()
	_place_marker()
	_build_atmosphere()
	_build_floor_fog()
	if OS.get_environment("SW_BREACH_CH") != "":
		for i in nodes.size():
			if int(TYPES[nodes[i]["type"]][2]) > 0:
				_pending = i
				_start_duel(int(TYPES[nodes[i]["type"]][2]))
				break
	# debug: SW_BREACH_AT=<row> teleports the marker that many rows in, clearing everything
	# behind it. Without this, rows 4+ — INCLUDING THE HELIOS CORE — could not be
	# screenshotted at all, because the camera hard-follows a marker that starts at row 0.
	# Half the board was unreviewable. Set SW_BREACH_AT=9 to stand at the core.
	if OS.get_environment("SW_BREACH_AT") != "":
		var want_row: int = clampi(int(OS.get_environment("SW_BREACH_AT")), 0, ROW_PLAN.size() - 1)
		var hop := 0
		while hop < 40 and int(nodes[cur]["row"]) < want_row:
			var links: Array = nodes[cur]["links"]
			if links.is_empty():
				break
			# prefer a link that actually advances a row, so this cannot loop sideways
			var step: int = int(links[0])
			for l in links:
				if int(nodes[int(l)]["row"]) > int(nodes[cur]["row"]):
					step = int(l)
					break
			shards = 60                  # fund anything on the way so nothing gates the hop
			has_tool = true
			_pending = step
			if nodes[cur].has("icon"):
				nodes[cur]["icon"].visible = true
			_finish_node(step)           # resolve it outright: no walk, no duel
			hop += 1
		# the nodes resolved on the way opened their reward modals; drop them so the shot is
		# of the CORRIDOR, which is the whole point of the hook
		_choice = {}
		for c in get_children():
			if c.has_signal("chosen"):
				c.queue_free()
		_marker.position = _cell_world(int(nodes[cur]["gx"]), int(nodes[cur]["gz"]))
		_marker_last_pos = _marker.position
		if nodes[cur].has("icon"):
			nodes[cur]["icon"].visible = false
		# put the camera on him straight away rather than letting it fly in from row 0
		_cam.position = _marker.position + Vector3(0.0, 8.0, 8.3).normalized() * 14.0
		_look_at = _marker.position + Vector3(0, 0.3, -0.2)
		_cam_init = true
		_cam.look_at(_look_at)
		_paint_edges()
	# debug: SW_SIGIL=<type> retypes the first reachable node and resolves it, so a rig's
	# modal can be screenshotted (e.g. SW_SIGIL=vault, =recycler, =splicer)
	if OS.get_environment("SW_SIGIL") != "":
		var want := OS.get_environment("SW_SIGIL")
		if TYPES.has(want):
			for i in nodes.size():
				if i != cur:
					nodes[i]["type"] = want
					shards = 40           # fund the rig so the cost gate doesn't block the shot
					has_tool = true
					_pending = i
					_finish_node(i)
					break
	if OS.get_environment("SW_SHOT") != "":
		await get_tree().create_timer(0.6).timeout
		if is_inside_tree():
			get_viewport().get_texture().get_image().save_png(OS.get_environment("SW_SHOT"))
			get_tree().quit()


func _load_png(res_path: String) -> Texture2D:
	var p := ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(p):
		return null
	var img := Image.load_from_file(p)
	return ImageTexture.create_from_image(img) if img != null else null


func _load_art(name: String) -> Texture2D:
	for dir in ART_DIRS:
		var t := _load_png(dir + name + ".png")
		if t != null:
			return t
	return null


func _build_shadow_tex() -> void:
	# TRAP: Gradient.set_color() takes a POINT INDEX, not an offset. This used to read
	# `set_color(0.55, ...)` / `set_color(1, ...)`, which truncate to index 0 and index 1 —
	# so the "0.55 knee" silently overwrote the centre stop and the curve was never what it
	# looked like. Worse, on a 4-point gradient the same mistake left the outermost stop at
	# Godot's DEFAULT opaque white, which made every texel past UV radius 0.5 — corners
	# included — fully opaque: a black rectangle with hard corners instead of a soft pool.
	# That was the "stupid shadow". Set offsets and colours as arrays so it cannot recur.
	# These values reproduce what actually shipped and was approved for the astronaut: a
	# plain linear ramp from alpha 0.32 to 0.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.32), Color(0, 0, 0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 96
	gt.height = 96
	_shadow_tex = gt
	_sigil_shader = Shader.new()
	_sigil_shader.code = SIGIL_SHADER
	# Verify the shader compiled before any prop is built on it. Godot reports a failed
	# spatial shader by leaving it with no uniforms, so probing for one we know we declared
	# is a reliable check that needs no error hook. If it fails the props keep their plain
	# Sprite3D material: no fog dissolve and no per-node tint, but they still READ.
	var probe := ShaderMaterial.new()
	probe.shader = _sigil_shader
	var names: Array = []
	for u in _sigil_shader.get_shader_uniform_list():
		names.append(str(u["name"]))
	_sigil_ok = names.has("fog_top") and names.has("tint")
	if not _sigil_ok:
		push_warning("BREACH: SIGIL_SHADER failed to compile — props fall back to plain sprites")


# ==================================================================
# Stage: camera, lights, floor material, backdrop, HUD
# ==================================================================
func _build_stage() -> void:
	_cam = Camera3D.new()
	# near-isometric: a LONG lens from far away — parallel-ish lines with just a tad of
	# perspective depth. O toggles to pure orthographic for comparison.
	_cam.fov = 20.0
	_cam.position = Vector3(0, 24.1, 28.0)
	add_child(_cam)
	_cam.look_at(Vector3(0, 0, 0))
	_cam.current = true
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.015, 0.025)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.30, 0.36, 0.46)
	e.ambient_light_energy = 0.62   # fill so the block faces shade instead of reading as black cutouts
	e.fog_enabled = true
	e.fog_light_color = Color(0.0, 0.0, 0.0)
	e.fog_density = 0.05            # thick black fog eats the far cubes
	e.glow_enabled = true
	e.glow_intensity = 0.95
	e.glow_strength = 1.15
	e.glow_bloom = 0.2
	e.glow_hdr_threshold = 0.85
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.environment = e
	add_child(env)
	# NO global key light — the field must fall into black at the edges. Only the lights
	# placed ALONG the corridor illuminate anything (see _build_path_glow).
	# The one exception: a very dim, SHADOWLESS fill from the camera side purely so the
	# blocks' unlit faces shade instead of reading as flat black cutouts. Kept far below
	# the corridor lights so the falloff into darkness is untouched.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-42.0, 26.0, 0.0)
	fill.light_color = Color(0.62, 0.70, 0.80)   # cold steel: bounce off bare hull, no colour story
	fill.light_energy = 0.72
	fill.shadow_enabled = false
	fill.light_specular = 0.0
	add_child(fill)
	# a second, dimmer fill from the OPPOSITE side. One directional light always leaves the
	# faces turned away from it pure black; a counter-fill gives those faces a readable
	# edge without lifting the whole scene (which is what flattens the falloff).
	var back := DirectionalLight3D.new()
	back.rotation_degrees = Vector3(-28.0, -142.0, 0.0)
	back.light_color = Color(0.48, 0.56, 0.70)
	back.light_energy = 0.46
	back.shadow_enabled = false
	back.light_specular = 0.0
	add_child(back)
	_path_mat = StandardMaterial3D.new()
	var pf := _load_png(MAP_DIR + "path_floor.png")
	if pf == null:
		pf = _load_png(MAP_DIR + "floor_top.png")
	_path_mat.albedo_texture = pf
	_path_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_path_mat.albedo_color = Color(0.46, 0.5, 0.58)
	_path_mat.roughness = 0.92
	_cube_top_mat = StandardMaterial3D.new()
	var ct := _load_png(MAP_DIR + "cube_top.png")
	if ct == null:
		ct = _load_png(MAP_DIR + "floor_top.png")
	_cube_top_mat.albedo_texture = ct
	_cube_top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_cube_top_mat.albedo_color = Color(0.62, 0.66, 0.74)
	_cube_top_mat.roughness = 0.7
	_cube_side_mat = StandardMaterial3D.new()
	var cs := _load_png(MAP_DIR + "cube_side.png")
	if cs == null:
		cs = _load_png(MAP_DIR + "wall_panel.png")
	_cube_side_mat.albedo_texture = cs
	_cube_side_mat.uv1_triplanar = true
	_cube_side_mat.uv1_scale = Vector3(0.55, 0.55, 0.55)
	_cube_side_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_cube_side_mat.albedo_color = Color(0.78, 0.82, 0.90)
	_cube_side_mat.roughness = 0.72
	# DEV: override the cube texture at runtime from an external PNG (candidate preview);
	# loads outside res:// so it never touches the repo import system. Default: unused.
	var _cube_ovr := OS.get_environment("SW_CUBE_TEX")
	if _cube_ovr != "":
		var _img := Image.load_from_file(_cube_ovr)
		if _img != null:
			var _ovt := ImageTexture.create_from_image(_img)
			_cube_side_mat.albedo_texture = _ovt
			_cube_top_mat.albedo_texture = _ovt
	# screen-space post: vignette + faint scanlines + grain (below the HUD)
	_overlay = CanvasLayer.new()
	_overlay.layer = 0
	add_child(_overlay)
	var post := ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n" \
		+ "void fragment() {\n" \
		+ "	vec2 uv = SCREEN_UV;\n" \
		+ "	float scan = sin(uv.y * 340.0) * 0.5 + 0.5;\n" \
		+ "	float vig = 1.0 - smoothstep(0.35, 0.95, distance(uv, vec2(0.5)));\n" \
		+ "	float grain = fract(sin(dot(uv * (TIME * 40.0 + 1.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;\n" \
		+ "	float dark = 0.045 * scan + (1.0 - vig) * 0.5 + grain * 0.03;\n" \
		+ "	COLOR = vec4(0.0, 0.0, 0.0, clamp(dark, 0.0, 0.78));\n" \
		+ "}\n"
	var smat := ShaderMaterial.new()
	smat.shader = sh
	post.material = smat
	_overlay.add_child(post)
	# HUD overlay for text (above the post overlay)
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	_hud.draw.connect(_on_hud_draw)


func _cell_world(gx: int, gz: int) -> Vector3:
	return Vector3((gx - (GRIDW - 1) * 0.5) * CELL, 0.0, -gz * CELL)


# ==================================================================
# Map generation (same category rules as the 2D chart)
# ==================================================================
func _pick_variant(cat: String, c: int) -> String:
	if not CATEGORY.has(cat):
		return cat
	var v: Array = (CATEGORY[cat] as Array).duplicate()
	v.shuffle()
	return v[c % v.size()]


func _gen_map() -> void:
	nodes = []
	var idx := {}
	for r in ROW_PLAN.size():
		var cat: String = ROW_PLAN[r]
		var w := 1 if (cat == "access" or cat == "core") else (1 + (1 if randf() < 0.5 else 2))
		for c in w:
			idx[Vector2i(r, c)] = nodes.size()
			var gx := 3 if w == 1 else clampi(int(round((c + 0.5) / w * (GRIDW - 1))), 0, GRIDW - 1)
			var kind: String = _pick_variant(cat, c)
			# difficulty ramp: the FIRST battle row is always the tier-1 FIREWALL. Rolling
			# a SENTINEL (tier 2) or a BOUNTY DAEMON as the opening fight was brutal.
			if cat == "battle":
				kind = "firewall" if r < 5 else kind
			nodes.append({"row": r, "col": c, "ncol": w, "type": kind,
				"links": [], "state": "locked", "gx": gx, "gz": r * ROWSTEP})
	# spread same-row columns apart so tokens don't overlap
	for r in ROW_PLAN.size():
		var same := []
		for i in nodes.size():
			if nodes[i]["row"] == r:
				same.append(i)
		if same.size() == 2:
			nodes[same[0]]["gx"] = 2
			nodes[same[1]]["gx"] = 4
		elif same.size() == 3:
			nodes[same[0]]["gx"] = 1
			nodes[same[1]]["gx"] = 3
			nodes[same[2]]["gx"] = 5
	# link each node to 1-2 nodes in the next row
	for i in nodes.size():
		var nd: Dictionary = nodes[i]
		var r: int = nd["row"]
		if r == ROW_PLAN.size() - 1:
			continue
		var nxt := []
		for j in nodes.size():
			if nodes[j]["row"] == r + 1:
				nxt.append(j)
		nxt.sort_custom(func(a, b): return abs(nodes[a]["gx"] - nd["gx"]) < abs(nodes[b]["gx"] - nd["gx"]))
		nd["links"].append(nxt[0])
		if nxt.size() > 1 and randf() < 0.4:
			nd["links"].append(nxt[1])
	# guarantee every next-row node has an inbound link
	for r in range(1, ROW_PLAN.size()):
		for j in nodes.size():
			if nodes[j]["row"] != r:
				continue
			var has_in := false
			for i in nodes.size():
				if nodes[i]["links"].has(j):
					has_in = true
					break
			if not has_in:
				var best := -1
				for i in nodes.size():
					if nodes[i]["row"] == r - 1 and (best == -1 or abs(nodes[i]["gx"] - nodes[j]["gx"]) < abs(nodes[best]["gx"] - nodes[j]["gx"])):
						best = i
				if best >= 0:
					nodes[best]["links"].append(j)
	cur = 0
	nodes[cur]["state"] = "done"
	_update_reach()


func _update_reach() -> void:
	for n in nodes:
		if n["state"] == "reach":
			n["state"] = "locked"
	for j in nodes[cur]["links"]:
		if nodes[j]["state"] == "locked":
			nodes[j]["state"] = "reach"
	_paint_edges()


func _paint_edges() -> void:
	## Corridors read their own state: the ones you can take from here glow cyan, the one
	## under the cursor previews YELLOW, and everything spent or unreachable goes grey so
	## the route you've burned is visibly behind you.
	var live_cells := {}
	var hot_cells := {}
	var live_edges := {}
	var hot_edges := {}
	for key in _edge_cells:
		var k: Vector2i = key
		if k.x != cur or nodes[k.y]["state"] != "reach":
			continue
		live_edges[key] = true
		var hot: bool = k.y == _hover_node
		if hot:
			hot_edges[key] = true
		for c in (_edge_cells[key] as Array):
			live_cells[c] = true
			if hot:
				hot_cells[c] = true
	# one colour per CELL, then the whole network is rebuilt as a single mesh — that's what
	# makes it read as one conduit instead of a row of separately-lit pieces
	var cell_col := {}
	for key in _edge_cells:
		for c in (_edge_cells[key] as Array):
			var col: Color = EDGE_DEAD * 0.55
			if hot_cells.has(c):
				col = EDGE_PICK * 1.5
			elif live_cells.has(c):
				col = EDGE_LIVE
			cell_col[c] = col
	_rebuild_conduit(cell_col)
	# the conduit's own lights + junction dots follow the same states, so a corridor you
	# have already walked goes properly dark instead of staying lit behind you
	for c in _cell_light:
		var lg: OmniLight3D = _cell_light[c]
		if live_cells.has(c):
			var hotc: bool = hot_cells.has(c)
			lg.light_color = Color(1.0, 0.88, 0.46) if hotc else Color(0.4, 0.75, 1.0)
			lg.light_energy = 4.6 if hotc else 2.2
			lg.omni_range = 7.0 if hotc else 5.0
		else:
			lg.light_color = Color(0.42, 0.48, 0.58)
			lg.light_energy = 0.34
	for c in _cell_dot:
		var dm: StandardMaterial3D = _cell_dot[c]
		if live_cells.has(c):
			dm.albedo_color = EDGE_PICK if hot_cells.has(c) else Color(0.82, 0.82, 0.82)
		else:
			dm.albedo_color = Color(0.26, 0.29, 0.34)


func _quad(im: ImmediateMesh, a: Vector3, b: Vector3, w: float, ca: Color, cb: Color) -> void:
	var d := (b - a)
	d.y = 0.0
	if d.length() < 0.0001:
		return
	var n := Vector3(-d.z, 0.0, d.x).normalized() * w * 0.5
	im.surface_set_color(ca)
	im.surface_add_vertex(a - n)
	im.surface_set_color(ca)
	im.surface_add_vertex(a + n)
	im.surface_set_color(cb)
	im.surface_add_vertex(b + n)
	im.surface_set_color(ca)
	im.surface_add_vertex(a - n)
	im.surface_set_color(cb)
	im.surface_add_vertex(b + n)
	im.surface_set_color(cb)
	im.surface_add_vertex(b - n)


func _patch(im: ImmediateMesh, c: Vector3, w: float, col: Color) -> void:
	## square joint filler, coplanar with the stretches so corners read continuous
	var h := w * 0.5
	for v in [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h),
			Vector3(-h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]:
		im.surface_set_color(col)
		im.surface_add_vertex(c + v)


func _rebuild_conduit(cell_col: Dictionary) -> void:
	## Rewrites the single conduit mesh. Called whenever states change (walk / hover) —
	## it's ~40 quads, so rebuilding is cheaper than juggling per-segment materials.
	if _conduit == null:
		return
	var im: ImmediateMesh = _conduit.mesh
	im.clear_surfaces()
	var W_HALO := CELL * 0.20
	var W_CORE := CELL * 0.035
	# pass 1: wide soft body, pass 2: bright core, both in the same surface
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _conduit_mat)
	for pass_i in 2:
		var w: float = W_HALO if pass_i == 0 else W_CORE
		var mul: float = 0.30 if pass_i == 0 else 1.0
		var y: float = 0.05 if pass_i == 0 else 0.062
		for key in _seg_owners:
			var k: Vector4i = key
			var ca: Color = cell_col.get(Vector2i(k.x, k.y), EDGE_DEAD) * mul
			var cb: Color = cell_col.get(Vector2i(k.z, k.w), EDGE_DEAD) * mul
			_quad(im, _cell_world(k.x, k.y) + Vector3(0, y, 0),
				_cell_world(k.z, k.w) + Vector3(0, y, 0), w, ca, cb)
		for c in cell_col:
			_patch(im, _cell_world((c as Vector2i).x, (c as Vector2i).y) + Vector3(0, y, 0),
				w, (cell_col[c] as Color) * mul)
	im.surface_end()


func _hover_at(m: Vector2) -> int:
	## which reachable node the cursor is over (same y=0 ray pick as _click)
	if mode != Mode.MAP or _moving:
		return -1
	var from := _cam.project_ray_origin(m)
	var dir := _cam.project_ray_normal(m)
	if absf(dir.y) < 0.0001:
		return -1
	var hit := from + dir * (-from.y / dir.y)
	var p2 := Vector2(hit.x, hit.z)
	# the node itself
	for i in nodes.size():
		if nodes[i]["state"] != "reach":
			continue
		var np := _cell_world(nodes[i]["gx"], nodes[i]["gz"])
		if p2.distance_to(Vector2(np.x, np.z)) < CELL * 0.85:
			return i
	# ...or anywhere along the CORRIDOR leading to it, so pointing at the route counts too
	var best := -1
	var best_d := CELL * 0.6
	for key in _edge_cells:
		var k: Vector2i = key
		if k.x != cur or nodes[k.y]["state"] != "reach":
			continue
		for c in (_edge_cells[key] as Array):
			var cw := _cell_world((c as Vector2i).x, (c as Vector2i).y)
			var d := p2.distance_to(Vector2(cw.x, cw.z))
			if d < best_d:
				best_d = d
				best = k.y
	return best


func _corridor_cells(i: int, j: int) -> Array:
	## Manhattan L-path in grid cells from node i up to node j (next row).
	var a: Dictionary = nodes[i]
	var b: Dictionary = nodes[j]
	var cells := []
	var midz: int = a["gz"] + 1
	cells.append(Vector2i(a["gx"], midz))          # up one into the corridor lane
	# walk across TOWARD b's column (direction-aware — never zigzag on leftward moves)
	var step: int = 1 if b["gx"] >= a["gx"] else -1
	var gx: int = a["gx"]
	while gx != b["gx"]:
		gx += step
		cells.append(Vector2i(gx, midz))
	if b["gz"] - 1 != midz:                         # up into b (skip if adjacent-row dup)
		cells.append(Vector2i(b["gx"], b["gz"] - 1))
	return cells


# ==================================================================
# Build the 3D map: floor cells, node tokens, icons, shadows
# ==================================================================
const CUBE_H := 1.2


func _build_map_nodes() -> void:
	## The whole field is solid raised cubes; the walkable PATH (nodes + corridors) is
	## carved in as a recessed channel, so only the path is "lodged in" below the blocks.
	var path_cells := {}
	for i in nodes.size():
		path_cells[Vector2i(nodes[i]["gx"], nodes[i]["gz"])] = true
		for j in nodes[i]["links"]:
			for c in _corridor_cells(i, j):
				path_cells[c] = true
	var minx := 999
	var maxx := -999
	var minz := 999
	var maxz := -999
	for c in path_cells:
		minx = mini(minx, c.x)
		maxx = maxi(maxx, c.x)
		minz = mini(minz, c.y)
		maxz = maxi(maxz, c.y)
	minx -= 1
	maxx += 1
	minz -= 1
	maxz += 1
	# keep the cells BEHIND the access node free of raised blocks — the astronaut must be
	# fully visible when the breach opens, not peeking over a cube
	var apron := {}
	for i in nodes.size():
		if str(nodes[i]["type"]) == "access":
			for adx in range(-2, 3):
				for adz in [-2, -1, 1, 2]:
					apron[Vector2i(int(nodes[i]["gx"]) + adx, int(nodes[i]["gz"]) + adz)] = true
	for gz in range(minz, maxz + 1):
		for gx in range(minx, maxx + 1):
			var w := _cell_world(gx, gz)
			if apron.has(Vector2i(gx, gz)) and not path_cells.has(Vector2i(gx, gz)):
				# no BLOCK here (it would hide the astronaut at the start node) — but the
				# cell still needs a floor, or you get a black hole in the deck. `continue`
				# used to skip both, which is the gap the captain spotted in front of him.
				var afl := MeshInstance3D.new()
				var afp := PlaneMesh.new()
				afp.size = Vector2(CELL, CELL)
				afl.mesh = afp
				afl.mesh.surface_set_material(0, _cube_top_mat)   # plating, not walkway
				afl.position = w
				add_child(afl)
				continue
			if path_cells.has(Vector2i(gx, gz)):
				var fl := MeshInstance3D.new()
				var fp := PlaneMesh.new()
				fp.size = Vector2(CELL, CELL)
				fl.mesh = fp
				fl.mesh.surface_set_material(0, _path_mat)
				fl.position = w
				add_child(fl)
			else:
				_build_setpiece(gx, gz, w)
	_build_path_glow()
	for i in nodes.size():
		_build_token(i)
	_paint_edges()   # the corridor materials only exist now — colour them for the start node


func _emis_mat(c: Color) -> StandardMaterial3D:
	var key := "%0.2f_%0.2f_%0.2f" % [c.r, c.g, c.b]
	if _emis_cache.has(key):
		return _emis_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.6
	_emis_cache[key] = m
	return m


func _build_setpiece(gx: int, gz: int, w: Vector3) -> void:
	## Each void cell becomes a little textured ROOM/machine with random height,
	## a slight tilt, and glowing window/vent strips — so the field reads as a
	## physical model of the station, not a grid of identical blocks.
	var h := absi((gx * 928371) ^ (gz * 1237657) ^ 0x9e3779b9)
	var rh := CUBE_H * (0.65 + float(h % 100) / 100.0 * 0.9)
	var yaw := (float((h >> 3) % 5) - 2.0) * 0.05
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(CELL * 0.94, rh, CELL * 0.94)
	body.mesh = bm
	body.mesh.surface_set_material(0, _cube_side_mat)
	body.position = w + Vector3(0, rh * 0.5, 0)
	body.rotation.y = yaw
	add_child(body)
	var top := MeshInstance3D.new()
	var tp := PlaneMesh.new()
	tp.size = Vector2(CELL * 0.94, CELL * 0.94)
	top.mesh = tp
	top.mesh.surface_set_material(0, _cube_top_mat)
	top.position = w + Vector3(0, rh + 0.004, 0)
	top.rotation.y = yaw
	add_child(top)
	# (glowing window strips removed — captain didn't want a colourful side on the cubes)


func _build_plinth(minx: int, maxx: int, minz: int, maxz: int) -> void:
	var c0 := _cell_world(minx, minz)
	var c1 := _cell_world(maxx, maxz)
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(absf(c1.x - c0.x) + CELL * 2.2, 0.6, absf(c1.z - c0.z) + CELL * 2.2)
	slab.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.04, 0.045, 0.055)
	m.roughness = 0.85
	slab.mesh.surface_set_material(0, m)
	slab.position = (c0 + c1) * 0.5 + Vector3(0, -0.32, 0)
	add_child(slab)


func _build_path_glow() -> void:
	## An energy conduit down the carved corridors: a soft glowing floor ribbon
	## (halo), a crisp bright core line on top, and a glow dot at every junction
	## cell so corners read as smooth connectors instead of notched box seams.
	var ribbon_tex := _glow_line_tex()
	var dot_tex := _glow_dot_tex()

	# soft wide halo laid flat on the floor
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	halo_mat.albedo_texture = ribbon_tex
	halo_mat.albedo_color = Color(0.82, 0.82, 0.82)   # glow, don't flood the trench
	halo_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	# crisp bright core line (thin emissive strip riding just above the halo)
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.75, 0.92, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.4, 0.85, 1.0)
	core_mat.emission_energy_multiplier = 3.4

	# junction glow-dot material (reuses the halo look, radial)
	var dot_mat := halo_mat.duplicate()
	dot_mat.albedo_texture = dot_tex

	var lit := {}   # cells that already have a corridor light (avoid piling them up)
	var dotted := {}
	for i in nodes.size():
		for j in nodes[i]["links"]:
			# each corridor owns its own material pair so it can be tinted on its own:
			# cyan = walkable, YELLOW = the route you're pointing at, grey = spent/locked
			var e_halo: StandardMaterial3D = halo_mat.duplicate()
			var e_core: StandardMaterial3D = core_mat.duplicate()
			_edge_mats[Vector2i(i, j)] = [e_halo, e_core]
			var pts := [Vector2i(nodes[i]["gx"], nodes[i]["gz"])]
			pts.append_array(_corridor_cells(i, j))
			pts.append(Vector2i(nodes[j]["gx"], nodes[j]["gz"]))
			_edge_cells[Vector2i(i, j)] = pts.duplicate()
			# CLAIM segments instead of drawing them: sibling corridors leaving the same
			# node share their first cells, so drawing per-edge stacked two strips on the
			# same stretch — with different states they read as a grey line offset behind
			# the cyan one, which is the "broken, not straight" look. Each stretch is now
			# built exactly once, and remembers every edge that uses it.
			for k in range(pts.size() - 1):
				var ca: Vector2i = pts[k]
				var cb: Vector2i = pts[k + 1]
				if ca == cb:
					continue
				# order-independent key so A->B and B->A are the same stretch
				var key := Vector4i(ca.x, ca.y, cb.x, cb.y)
				if ca.x > cb.x or (ca.x == cb.x and ca.y > cb.y):
					key = Vector4i(cb.x, cb.y, ca.x, ca.y)
				if not _seg_owners.has(key):
					_seg_owners[key] = []
				(_seg_owners[key] as Array).append(Vector2i(i, j))
			# junction glow dot at each cell, on THIS edge's material — sharing one dot
			# material was what kept crossed corridors lit and made the run read as a
			# chain of blobs instead of one conduit
			for c in pts:
				if not dotted.has(c):
					dotted[c] = true
					var dot := MeshInstance3D.new()
					var dpm := PlaneMesh.new()
					dpm.size = Vector2(0.72, 0.72)
					dot.mesh = dpm
					var d_mat: StandardMaterial3D = dot_mat.duplicate()
					d_mat.albedo_texture = dot_tex
					dot.mesh.surface_set_material(0, d_mat)
					dot.position = _cell_world(c.x, c.y) + Vector3(0, 0.05, 0)
					add_child(dot)
					_cell_dot[c] = d_mat
			# a blue point light on every path cell — lights the trench + nearby cube
			# walls, and everything past its reach falls to black. Registered per cell so
			# _paint_edges can dim the stretches you've already walked.
			# EVERY SECOND CELL, in a checker. GL Compatibility caps positional lights at 32
			# renderable and 8 PER OBJECT, both enforced silently. One light per cell built
			# 61-95 omnis and overlapped every floor tile with 9-25 of them, so ~60% of the
			# lights could never reach the screen — and because the 32-cap keeps the LAST 32
			# in creation order rather than the nearest, which ones survived shifted as the
			# camera moved. That is a brightness-popping source, not just wasted work.
			# The wider range below keeps the trench continuously lit at half the count.
			for c in pts:
				if lit.has(c):
					continue
				if (c.x + c.y) % 2 != 0:
					continue
				lit[c] = true
				var lg := OmniLight3D.new()
				lg.position = _cell_world(c.x, c.y) + Vector3(0, 0.8, 0)
				lg.light_color = Color(0.4, 0.75, 1.0)
				lg.light_energy = 2.2
				lg.omni_range = 5.0
				add_child(lg)
				_cell_light[c] = lg
	# --- ONE mesh for the whole conduit ---
	# Per-segment planes could never look unified: every stretch was its own object with
	# its own soft edges, so joints double-brightened and states lit "in pieces". The
	# network is now a single ImmediateMesh — a quad per stretch plus a square patch at
	# every cell to fill the joints — with state carried in VERTEX COLOUR, so it is one
	# object, one material, one draw, and colour transitions are continuous.
	_conduit_mat = StandardMaterial3D.new()
	_conduit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_conduit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_conduit_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_conduit_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_conduit_mat.vertex_color_use_as_albedo = true
	_conduit = MeshInstance3D.new()
	_conduit.mesh = ImmediateMesh.new()
	_conduit.material_override = _conduit_mat
	_conduit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_conduit.custom_aabb = AABB(Vector3(-60, -1, -60), Vector3(120, 2, 120))
	add_child(_conduit)


func _glow_line_tex() -> Texture2D:
	## Soft cross-section: bright plateau in the center fading to transparent edges.
	var w := 64
	var img := Image.create(w, 4, false, Image.FORMAT_RGBA8)
	for x in w:
		var t: float = absf(float(x) / float(w - 1) * 2.0 - 1.0)   # 0 center .. 1 edge
		var a: float = pow(clampf(1.0 - smoothstep(0.10, 1.0, t), 0.0, 1.0), 1.4)
		for y in 4:
			img.set_pixel(x, y, Color(0.5, 0.85, 1.0, a))
	return ImageTexture.create_from_image(img)


func _glow_dot_tex() -> Texture2D:
	## Radial soft glow used to round the corridor junctions.
	var s := 48
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := float(s - 1) * 0.5
	for y in s:
		for x in s:
			var d: float = Vector2(float(x) - c, float(y) - c).length() / c
			var a: float = pow(clampf(1.0 - smoothstep(0.0, 1.0, d), 0.0, 1.0), 1.6)
			img.set_pixel(x, y, Color(0.5, 0.85, 1.0, a))
	return ImageTexture.create_from_image(img)


func _build_token(i: int) -> void:
	var nd: Dictionary = nodes[i]
	var big: bool = nd["type"] == "core"
	var root := Node3D.new()
	root.position = _cell_world(nd["gx"], nd["gz"])
	add_child(root)
	nd["node"] = root
	# NO painted drop shadow here. There used to be one, and a second broad one was later
	# added below it — both invisible, and the reason is worth keeping: at a node almost all
	# the visible brightness IS the additive fog sheet, and the deck under it is near-black.
	# A black alpha plane BENEATH an additive layer cannot darken that layer. Cranking its
	# alpha only punched a hard-cornered black rectangle through the mist. Props are grounded
	# instead by THINNING THE FOG under each node (see _build_floor_fog) so the prop stands
	# in a clearing and the deck's own darkness does the work.
	# round token disc
	var disc := MeshInstance3D.new()
	var dp := PlaneMesh.new()
	var dsz := CELL * (0.8 if big else 0.58)
	dp.size = Vector2(dsz, dsz)
	disc.mesh = dp
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.alpha_scissor_threshold = 0.4
	dmat.albedo_texture = _tex.get("token_base")
	dmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	disc.mesh.surface_set_material(0, dmat)
	disc.position.y = 0.04
	# the sigil art carries its own isometric pedestal, so the old round token disc
	# just fought with it — kept in the tree (the pulse code and reach feedback ride
	# on it) but invisible: the pedestal IS the base now.
	disc.visible = false
	root.add_child(disc)
	nd["token"] = disc
	# a pulsing target ring on the floor, shown only when the node is reachable
	if _tex.get("node_ring") != null:
		var ring := MeshInstance3D.new()
		var rp := PlaneMesh.new()
		rp.size = Vector2(CELL * 0.95, CELL * 0.95)
		ring.mesh = rp
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rmat.albedo_texture = _tex["node_ring"]
		rmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		rmat.albedo_color = TYPE_COLOR.get(nd["type"], CYAN)
		ring.mesh.surface_set_material(0, rmat)
		ring.position.y = 0.05
		ring.visible = false
		root.add_child(ring)
		nd["ring"] = ring
	# the sigil itself, billboarded and standing ON the deck — its pedestal is the base,
	# so it's sized bigger than the old floating icon and sits with its feet at y=0
	var icon := Sprite3D.new()
	icon.texture = _tex.get(TYPES[nd["type"]][1])
	if icon.texture != null:
		icon.pixel_size = (CELL * (0.92 if big else 0.62)) / icon.texture.get_height()
		icon.scale = Vector3(0.88, 1.0, 1.0)   # the art runs wide; narrow it a touch
		icon.position.y = icon.texture.get_height() * icon.pixel_size * 0.5 + 0.02
	else:
		icon.position.y = CELL * (0.52 if big else 0.36)
	# NOT billboarded: a sigil is a machine bolted to the deck, so it keeps a fixed facing
	# and gets lit + shadowed like scenery. Billboarding was a big part of why they read as
	# stickers floating over the map.
	icon.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	icon.rotation_degrees.y = 0.0
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	icon.shaded = false
	icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# it throws a real shadow from the node light above it and the astronaut's suit lamp
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	# per-node material: it owns this prop's light tint, so each one is lit independently.
	# Only applied if the shader actually COMPILED — `_sigil_ok` is checked once at startup.
	# Without this guard, a driver that rejects the shader renders all 17 props as flat grey
	# rectangles with no fallback (seen for real during development), which is a far worse
	# failure than simply losing the fog dissolve.
	if icon.texture != null and _sigil_ok:
		var imat := ShaderMaterial.new()
		imat.shader = _sigil_shader
		imat.set_shader_parameter("tex", icon.texture)
		imat.set_shader_parameter("fog_color", FOG_TINT)
		imat.set_shader_parameter("tint", Color(1, 1, 1, 1))
		imat.set_shader_parameter("fog_top", 0.26)
		icon.material_override = imat
		nd["imat"] = imat
	root.add_child(icon)
	# NO painted shadow under a prop — four attempts all failed and the reasons are worth
	# keeping. An alpha-black plane is invisible: the floor fog is blend_add, so at a node
	# nearly all the on-screen brightness IS the fog and a plane underneath cannot subtract
	# from it (measured: luminance ROSE toward the prop centre; a shadow is a dip). A hard
	# core read as an oval decal. A multiply quad was the right blend but rendered as a hard
	# rectangle. Grounding comes from the fog itself parting around raised geometry — see the
	# depth fade at the end of FLOOR_FOG_SHADER.
	nd["icon"] = icon   # hidden while the astronaut stands on this node
	# stagger each prop's idle so a row of them doesn't pulse in lockstep
	nd["iphase"] = randf() * 6.0
	nd["ifi"] = -1
	# a light on the token in its own accent colour — pools of orange/teal/violet/red
	# down the corridor so the stage isn't one flat blue
	var acol: Color = TYPE_COLOR.get(nd["type"], CYAN)
	var lgt := OmniLight3D.new()
	# STRAIGHT OVERHEAD, and it must stay that way. Offsetting it so the prop would throw a
	# real cast shadow was tried: the prop is a flat quad, so lighting it from behind casts a
	# hard-edged RECTANGLE across the deck — far worse than the degenerate sliver it replaced.
	lgt.position.y = 1.5
	lgt.light_color = acol
	lgt.light_energy = 3.4 if big else 2.0
	lgt.omni_range = 8.0 if big else 4.6
	# real cast shadows — ONLY on node lights (one per node, 19-27 in practice, NOT the
	# ~10 this once claimed — see the shadow-cost note in DEVLOG v0.229). The per-cell
	# corridor lights stay shadowless fill; shadowing all of them would tank GL compat.
	lgt.shadow_enabled = big
	lgt.shadow_bias = 0.04
	lgt.shadow_normal_bias = 1.4
	lgt.shadow_opacity = 0.82
	# NOTE: distance_fade_* is silently IGNORED by the GL Compatibility renderer (measured:
	# identical brightness with and without it at 28 units). It was here to cull distant node
	# lights against the 32-light cap; it never did. Left off rather than left misleading.
	root.add_child(lgt)
	nd["light"] = lgt
	# a shaft of light standing in the haze above the node — GL compat has no volumetric
	# fog, so the beam is an additive billboard: the light looks like it hangs in the air
	if _tex.get("light_shaft") != null:
		var shaft := Sprite3D.new()
		shaft.texture = _tex["light_shaft"]
		shaft.pixel_size = (CELL * (2.5 if big else 1.7)) / shaft.texture.get_height()
		shaft.position.y = CELL * (1.25 if big else 0.9)
		shaft.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		shaft.shaded = false
		shaft.transparent = true
		shaft.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		shaft.modulate = Color(acol.r, acol.g, acol.b, 0.05 if big else 0.035)
		shaft.render_priority = -1     # behind the icon, in front of the floor haze
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shaft)
		nd["shaft"] = shaft
	# The name is drawn in 2D from _on_hud_draw (see _draw_node_names), NOT as a Label3D.
	# A Label3D is depth-tested and the Environment's black fog applies to it, so names lost
	# ~45% of peak luminance by row 2 and were unreadable by row 3 (measured peak 160 -> 227
	# -> 123 -> 26 across the rows), and set-piece cubes ate leading glyphs — "EXCHANGE
	# TERMINAL" rendered as "XCHANGE TERMINAL". Only the anchor lives in 3D.
	nd["label_anchor"] = Vector3(0.0, CELL * (1.12 if big else 0.86), CELL * 0.22)


func _build_atmosphere() -> void:
	# --- drifting dust motes through the corridor volume ---
	if _tex.get("dust") != null:
		var minx := 999
		var maxx := -999
		var minz := 999
		var maxz := -999
		for nd in nodes:
			minx = mini(minx, nd["gx"])
			maxx = maxi(maxx, nd["gx"])
			minz = mini(minz, nd["gz"])
			maxz = maxi(maxz, nd["gz"])
		var c0 := _cell_world(minx, minz)
		var c1 := _cell_world(maxx, maxz)
		var p := GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(absf(c1.x - c0.x) * 0.5 + CELL * 2.0, 1.8,
			absf(c1.z - c0.z) * 0.5 + CELL * 2.0)
		pm.gravity = Vector3(0.04, 0.07, 0.0)
		pm.initial_velocity_min = 0.03
		pm.initial_velocity_max = 0.18
		pm.scale_min = 0.4
		pm.scale_max = 1.1
		p.process_material = pm
		var qm := QuadMesh.new()
		qm.size = Vector2(0.13, 0.13)
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		dm.albedo_texture = _tex["dust"]
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		dm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		qm.material = dm
		p.draw_pass_1 = qm
		p.amount = 150
		p.lifetime = 9.0
		p.position = (c0 + c1) * 0.5 + Vector3(0, 1.3, 0)
		p.visibility_aabb = AABB(Vector3(-50, -12, -50), Vector3(100, 30, 100))
		add_child(p)
	# (flow chevrons removed — captain didn't want the arrows on the path)


# ------------------------------------------------------------------
# Low-lying floor mist. One additive noise-scrolling plane hugging the
# corridor, confined to the path by a baked coverage mask. No depth
# texture (unsupported in GL Compatibility) — additive blend of near-
# black is its own soft edge, and the scene's black fog fades distance.
# ------------------------------------------------------------------
const LIGHT_FLOOR := Color(0.43, 0.49, 0.59)   # ambient + corridor fill, shared
const LIGHT_CEIL := Color(1.07, 1.07, 1.09)    # soft blowout guard, shared
const LIGHT_SAMPLE_Y := 0.55                   # mid-body: figure and machine lit alike
const NAME_PX := 13            # node-name size, drawn in 2D from _on_hud_draw
const FOG_TINT := Color(0.30, 0.62, 0.85)   # MUST match FLOOR_FOG_SHADER's fog_color
const FOG_Y := 0.11            # low: the sigil props must stand clear of it
const FOG_PAD_CELLS := 1       # extra cells of mask bleed around the path
const MASK_PX_PER_CELL := 12   # coverage-mask resolution
const MASK_BLUR := 3           # soft-edge radius in mask pixels

# A sigil prop used to be a flat unshaded sprite standing in an ADDITIVE fog sheet, which
# is the worst possible combination: nothing in the engine tinted it, so it stayed at full
# brightness while the deck around it was lit and hazed, and the additive fog quads crossing
# its lower body BRIGHTENED it into a hard band instead of passing in front of it. That band
# is what read as "a sticker floating in the fog".
# This material fixes all three at once, per pixel:
#   * `tint` carries the light actually reaching the node (fed by _light_sigils), so a prop
#     darkens on a dead branch and warms in its own accent pool.
#   * the bottom of the prop DISSOLVES into the haze colour, so the fog envelops its feet
#     instead of cutting across them.
#   * distant props recede toward the same haze, so the whole corridor shares one atmosphere.
const SIGIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;   // no depth prepass exists in GL Compatibility

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4  tint       : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3  fog_color  : source_color = vec3(0.30, 0.62, 0.85);
uniform float fog_top    = 0.26;   // world Y where the floor haze thins out
uniform float fog_amount = 0.16;   // low: the fog no longer washes the base (depth fade)
uniform float fog_grain  = 4.2;    // noise cells per world unit across the prop
uniform float fog_wobble = 0.95;   // how far the waterline rides; 0.0 = a clean gradient
uniform float base_dark  = 0.60;   // contact darkening right where it meets the deck

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// the SAME value noise FLOOR_FOG_SHADER is drawn with, so the prop dissolves along the
// fog's own fingers rather than along a line of its own invention
float sg_hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}
float sg_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = sg_hash(i);
	float b = sg_hash(i + vec2(1.0, 0.0));
	float c = sg_hash(i + vec2(0.0, 1.0));
	float d = sg_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float sg_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int i = 0; i < 3; i++) {
		v += a * sg_vnoise(p);
		p = m * p;
		a *= 0.5;
	}
	return v / 0.875;
}

void fragment() {
	vec4 t = texture(tex, UV);
	vec2 np = vec2(wpos.x + wpos.z * 0.7, wpos.y * 1.55) * fog_grain
		+ vec2(TIME * 0.050, TIME * 0.021);
	// A REAL dissolve has to act on COVERAGE, not colour. Tinting toward the haze leaves
	// ALPHA at 1.0, so the silhouette stays a razor-straight cut however the pixels inside
	// it are coloured — which is why the base kept reading as a sticker edge no matter how
	// the mix was tuned. Raising the alpha-cut with the haze factor and jittering it on the
	// fog's own noise genuinely punches the bottom rows out in a ragged pattern: hard PIXEL
	// edges (correct for pixel art), soft SHAPE edge.
	float fg0 = 1.0 - smoothstep(-fog_top * 0.35, fog_top * 1.45, wpos.y);
	fg0 = fg0 * fg0 * (3.0 - 2.0 * fg0);
	float cut = 0.5 + fg0 * 0.30 * sg_fbm(np * 1.3);
	if (t.a < cut) {
		discard;                     // keeps the hard pixel edge AND the cast shadow
	}
	vec3 c = t.rgb * tint.rgb;
	// occlusion first: the pixels sitting on the deck go darker, not foggier
	float contact = 1.0 - smoothstep(0.0, 0.30, wpos.y);
	c *= 1.0 - contact * base_dark;
	// Then the base sinks into the haze. The boundary is (a) eased twice for a long soft
	// shoulder and (b) pushed up and down by the SAME value noise the floor fog is drawn
	// with, so the prop dissolves along the fog's own fingers instead of along a clean line.
	// Band-limited ON PURPOSE — features are ~15-20px wide, so it reads as blur and does not
	// crawl when the camera glides. A per-pixel hash was tried here first: it was white-noise
	// grain 380x above Nyquist that re-randomised on sub-pixel camera moves, and because it
	// was scaled BY fg it peaked deep inside the haze and was zero at the shoulder — it could
	// not soften the transition it was added to soften.
	float wob = (sg_fbm(np) - 0.5) * fog_top * fog_wobble;
	float fg = 1.0 - smoothstep(-fog_top * 0.35, fog_top * 1.45, wpos.y - wob);
	fg = fg * fg * (3.0 - 2.0 * fg);
	// CRITICAL: go DOWN, not toward fog_color. The prop art is dark (~0.08 after tint) and
	// fog_color is a mid-bright blue, so mixing toward it TRIPLED the brightness of the feet
	// — and then the additive fog sheet added fog_color over the same pixels again, counting
	// the haze twice. The result was a glowing skirt exactly where the pedestal should be
	// seated. The additive pass supplies the brightness; the prop only supplies the cool
	// cast and gets out of the way.
	c *= mix(1.0, 0.62, fg);
	c = mix(c, fog_color * 0.55, fg * 0.40);
	// NO distance haze here: the Environment's own fog (fog_light_color black, density 0.05)
	// already applies to unshaded materials in GL Compatibility — verified. Mixing toward a
	// light blue here while the engine mixed toward black pulled props two opposite ways and
	// made them recede differently from the deck and cubes around them.
	ALBEDO = c;
}
"""

const FLOOR_FOG_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3  fog_color : source_color = vec3(0.30, 0.62, 0.85);
uniform float density        = 0.72;
uniform float noise_scale    = 0.35;
uniform float scroll_speed   = 0.06;
uniform float coverage_bias  = 0.22;
uniform float edge_softness  = 0.35;
uniform sampler2D corridor_mask : source_color, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float clear_from = 0.04;   // world Y where the fog begins to give way
uniform float clear_to   = 0.34;   // world Y where it is fully out of the way
uniform vec2 mask_world_min;
uniform vec2 mask_world_size;

varying vec3 world_pos;

float hash(vec2 p){
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}
float vnoise(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p){
	float v = 0.0;
	float a = 0.5;
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int i = 0; i < 5; i++){
		v += a * vnoise(p);
		p = m * p;
		a *= 0.5;
	}
	return v;
}

void vertex(){
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment(){
	vec2 wxz = world_pos.xz;
	// MASK FIRST. The two 5-octave FBMs used to run before this fetch, so every fragment
	// outside the corridor — most of a full-screen quad — paid for noise that the mask then
	// multiplied to zero. Gating them (and the depth fetch below) measured 31.25 ms -> 17.06
	// ms per frame at 2560x1440 with 96 amplified layers. Free on a fast GPU, worth an
	// estimated 2-4 ms on a Steam Deck or Iris Xe.
	vec2 muv = (wxz - mask_world_min) / mask_world_size;
	float mask = texture(corridor_mask, muv).r;
	mask *= step(0.0, muv.x) * step(muv.x, 1.0) * step(0.0, muv.y) * step(muv.y, 1.0);
	if (mask < 0.004) {
		discard;
	}
	float n1 = fbm(wxz * noise_scale + vec2( TIME * scroll_speed,  TIME * scroll_speed * 0.6));
	float n2 = fbm(wxz * noise_scale * 1.9 + vec2(-TIME * scroll_speed * 0.7, TIME * scroll_speed * 0.4));
	float n  = mix(n1, n2, 0.5);
	float mist = smoothstep(coverage_bias, coverage_bias + edge_softness, n);
	// THE FOG PARTS AROUND WHATEVER IS STANDING ON THE DECK.
	// This is what finally solved "the sigils look wrong in the fog", after three painted
	// shadows failed: alpha-under-additive is mathematically invisible, a hard core reads as
	// an oval decal, and a multiply quad reads as a rectangle. The problem was never the
	// shadow — it was that this ADDITIVE sheet washes straight across the props' bases.
	// So: reconstruct the WORLD Y of whatever the depth buffer holds at this pixel. Bare
	// deck (y~0) keeps full fog; anything raised — a sigil, a wall block, the astronaut —
	// pushes the haze aside, so it laps AROUND the base instead of over it. One fetch, and
	// it fixes every object at once instead of per-prop.
	// NOTE: `d * 2.0 - 1.0` is the GL/Compatibility depth convention. Forward+ uses
	// reverse-Z and would need vec3(SCREEN_UV * 2.0 - 1.0, d) instead.
	float dpt = texture(depth_tex, SCREEN_UV).r;
	vec4 vpos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dpt * 2.0 - 1.0, 1.0);
	vpos.xyz /= vpos.w;
	float hit_y = (INV_VIEW_MATRIX * vec4(vpos.xyz, 1.0)).y;
	// clear_from sits above the reconstruction jitter around y=0 so the deck never shimmers
	float clear_amt = smoothstep(clear_from, clear_to, hit_y);
	ALBEDO = fog_color;
	ALPHA  = clamp(mist * mask * density * (1.0 - clear_amt), 0.0, 1.0);
}
"""


func _build_floor_fog() -> void:
	# same path cells the corridors are carved from
	var path_cells := {}
	for i in nodes.size():
		path_cells[Vector2i(nodes[i]["gx"], nodes[i]["gz"])] = true
		for j in nodes[i]["links"]:
			for c in _corridor_cells(i, j):
				path_cells[c] = true
	if path_cells.is_empty():
		return
	var minx := 999
	var maxx := -999
	var minz := 999
	var maxz := -999
	for c in path_cells:
		minx = mini(minx, c.x)
		maxx = maxi(maxx, c.x)
		minz = mini(minz, c.y)
		maxz = maxi(maxz, c.y)
	minx -= FOG_PAD_CELLS
	maxx += FOG_PAD_CELLS
	minz -= FOG_PAD_CELLS
	maxz += FOG_PAD_CELLS

	var w0 := _cell_world(minx, minz)
	var w1 := _cell_world(maxx, maxz)
	var xmin := minf(w0.x, w1.x) - CELL * 0.5
	var xmax := maxf(w0.x, w1.x) + CELL * 0.5
	var zmin := minf(w0.z, w1.z) - CELL * 0.5
	var zmax := maxf(w0.z, w1.z) + CELL * 0.5

	# rasterize a fat disc per path cell, then box-blur for soft corridor edges
	var iw := (maxx - minx + 1) * MASK_PX_PER_CELL
	var ih := (maxz - minz + 1) * MASK_PX_PER_CELL
	var img := Image.create(iw, ih, false, Image.FORMAT_L8)
	img.fill(Color(0, 0, 0))
	var rad := int(MASK_PX_PER_CELL * 0.62)
	for c in path_cells:
		var w := _cell_world(c.x, c.y)
		var px := int((w.x - xmin) / (xmax - xmin) * float(iw))
		var py := int((w.z - zmin) / (zmax - zmin) * float(ih))
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if dx * dx + dy * dy > rad * rad:
					continue
				var x := px + dx
				var y := py + dy
				if x >= 0 and x < iw and y >= 0 and y < ih:
					img.set_pixel(x, y, Color(1, 1, 1))
	# CLEARING UNDER EACH PROP. This is what actually grounds the sigils. Painting a dark
	# blob on the deck does nothing, because at a node the brightness on screen IS this
	# additive fog and a black plane underneath cannot subtract from it. So instead the fog
	# itself thins where a prop stands: the mist opens around the machine, the near-black
	# deck shows through beneath it, and THAT reads as the shadow. It also gives the base
	# dissolve in SIGIL_SHADER something true to dissolve into.
	var crad := int(MASK_PX_PER_CELL * 0.62)
	for nd in nodes:
		var nw := _cell_world(int(nd["gx"]), int(nd["gz"]))
		var npx := int((nw.x - xmin) / (xmax - xmin) * float(iw))
		var npy := int((nw.z - zmin) / (zmax - zmin) * float(ih))
		for dy in range(-crad, crad + 1):
			for dx in range(-crad, crad + 1):
				var dd: float = sqrt(float(dx * dx + dy * dy))
				if dd > float(crad):
					continue
				var x := npx + dx
				var y := npy + dy
				if x < 0 or x >= iw or y < 0 or y >= ih:
					continue
				# deepest right under the prop, feathering back to full fog at the rim, so
				# there is no disc edge — just a soft well in the mist
				var k: float = 0.42 + 0.58 * smoothstep(0.35, 1.0, dd / float(crad))
				var v: float = img.get_pixel(x, y).r * k
				img.set_pixel(x, y, Color(v, v, v))
	for _pass in MASK_BLUR:
		var src := img.duplicate()
		for y in ih:
			for x in iw:
				var acc := 0.0
				var cnt := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var xx := x + dx
						var yy := y + dy
						if xx >= 0 and xx < iw and yy >= 0 and yy < ih:
							acc += src.get_pixel(xx, yy).r
							cnt += 1
				var v := acc / float(cnt)
				img.set_pixel(x, y, Color(v, v, v))
	var mask_tex := ImageTexture.create_from_image(img)

	var sh := Shader.new()
	sh.code = FLOOR_FOG_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("corridor_mask", mask_tex)
	mat.set_shader_parameter("mask_world_min", Vector2(xmin, zmin))
	mat.set_shader_parameter("mask_world_size", Vector2(xmax - xmin, zmax - zmin))

	_spawn_fog_layer(mat, Vector3((xmin + xmax) * 0.5, FOG_Y, (zmin + zmax) * 0.5),
		Vector2(xmax - xmin, zmax - zmin))
	# thinner, higher, counter-scrolling parallax sheet for a rolling-volume feel
	var mat2 := mat.duplicate()
	mat2.set_shader_parameter("density", 0.46)
	mat2.set_shader_parameter("noise_scale", 0.22)
	mat2.set_shader_parameter("scroll_speed", -0.04)
	_spawn_fog_layer(mat2, Vector3((xmin + xmax) * 0.5, FOG_Y + 0.10, (zmin + zmax) * 0.5),
		Vector2(xmax - xmin, zmax - zmin))


func _spawn_fog_layer(mat: ShaderMaterial, pos: Vector3, size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# transparent planes get frustum-culled early on the steep cam — force a wide AABB
	mi.custom_aabb = AABB(Vector3(-size.x, -4, -size.y), Vector3(size.x * 2.0, 8, size.y * 2.0))
	add_child(mi)


func _add_flow(i: int, j: int) -> void:
	var raw := [Vector2i(nodes[i]["gx"], nodes[i]["gz"])]
	raw.append_array(_corridor_cells(i, j))
	raw.append(Vector2i(nodes[j]["gx"], nodes[j]["gz"]))
	var pts := PackedVector3Array()
	for c in raw:
		var w := _cell_world(c.x, c.y) + Vector3(0, 0.14, 0)
		if pts.is_empty() or pts[pts.size() - 1].distance_to(w) > 0.01:
			pts.append(w)
	if pts.size() < 2:
		return
	var cum := PackedFloat32Array()
	cum.append(0.0)
	var total := 0.0
	for k in range(1, pts.size()):
		total += pts[k - 1].distance_to(pts[k])
		cum.append(total)
	for n in 2:
		var spr := Sprite3D.new()
		spr.texture = _tex["flow_arrow"]
		spr.pixel_size = 0.85 / maxf(spr.texture.get_height(), 1.0)
		spr.modulate = Color(0.5, 0.95, 1.0)
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.shaded = false
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		add_child(spr)
		_flows.append({"spr": spr, "pts": pts, "cum": cum, "len": total,
			"phase": total * (n / 2.0), "speed": 1.7})


func _sample_poly(pts: PackedVector3Array, cum: PackedFloat32Array, d: float) -> Vector3:
	for k in range(1, cum.size()):
		if d <= cum[k]:
			var seg := cum[k] - cum[k - 1]
			var f := 0.0 if seg <= 0.0001 else (d - cum[k - 1]) / seg
			return pts[k - 1].lerp(pts[k], f)
	return pts[pts.size() - 1]


func _tick_sigils() -> void:
	## step every visible sigil's idle animation. Only touches the sprite when its frame
	## index actually changes, so this is a handful of assignments a second, not per-frame work.
	if _icon_anim.is_empty():
		return
	for nd in nodes:
		var seq = _icon_anim.get(nd["type"])
		if seq == null:
			continue
		var icon = nd.get("icon")
		if icon == null or not is_instance_valid(icon) or not (icon as Sprite3D).visible:
			continue
		var fi: int = int((_t + float(nd.get("iphase", 0.0))) * ICON_FPS) % (seq as Array).size()
		if fi != int(nd.get("ifi", -1)):
			nd["ifi"] = fi
			var frame: Texture2D = (seq as Array)[fi]
			(icon as Sprite3D).texture = frame
			# the prop draws through SIGIL_SHADER via material_override, which samples its
			# OWN "tex" uniform — setting Sprite3D.texture alone froze every idle on frame 1
			var im = nd.get("imat")
			if im != null:
				(im as ShaderMaterial).set_shader_parameter("tex", frame)


func _light_at(p: Vector3, floor_col: Color) -> Color:
	## Light actually reaching a world point: the cool corridor wash plus every node's
	## coloured pool, falling off with distance. Shared by the astronaut and the sigil props
	## so a figure and the machine beside it are never lit by different rules.
	## O(callers x nodes). Maps run 18-26 nodes; the whole pass measures ~0.21 ms/frame here,
	## ~0.5-0.7 ms on a modest Steam CPU. The cost is GDScript overhead (dict lookups,
	## is_instance_valid, pow), not the maths. If the node count ever grows past ~40, cache the
	## lights into flat Packed*Array tables — that measured 7.9x faster — before doing anything
	## else; at n=90 this shape costs 3.3 ms/frame on a FAST machine.
	var lit := floor_col
	for nd in nodes:
		var lg = nd.get("light")
		if lg == null or not is_instance_valid(lg):
			continue
		var ol := lg as OmniLight3D
		var d := p.distance_to(ol.global_position)
		var rng: float = maxf(ol.omni_range, 0.001)
		if d >= rng:
			continue            # out of range: skip the pow() entirely, most pairs most frames
		var fall: float = pow(1.0 - d / rng, 1.7)
		if fall <= 0.001:
			continue
		var c: Color = ol.light_color * (ol.light_energy * 0.34 * fall)
		lit = Color(lit.r + c.r, lit.g + c.g, lit.b + c.b, 1.0)
	return lit


func _light_sigils(delta: float) -> void:
	## Feed each prop's material the light at its own feet. Before this the props were flat
	## full-brightness sprites — the single biggest reason they read as pasted on rather than
	## standing in the corridor. A prop on a dead/unreachable branch is pushed cold and dim
	## so the map's reachability is legible in the LIGHTING, not just the line colour.
	if nodes.is_empty() or not _hidden.is_empty():
		return                  # a duel is on screen: nothing here is visible to light
	for i in nodes.size():
		var nd = nodes[i]
		var imat = nd.get("imat")
		if imat == null:
			continue
		var icon = nd.get("icon")
		if icon == null or not is_instance_valid(icon) or not (icon as Sprite3D).visible:
			continue
		# sample at the SHARED height, not at the sprite's centre. The icon's centre sits
		# ~0.54 up and the astronaut was sampled at his feet (y=0), which put the props
		# ~30% brighter than him purely from the falloff on the node light at y=1.5 — a
		# figure and the machine one cell away must be lit by the same rule.
		var sp: Vector3 = (icon as Sprite3D).global_position
		sp.y = LIGHT_SAMPLE_Y
		var lit := _light_at(sp, LIGHT_FLOOR)
		# _update_reach writes done / reach / locked — reuse its words rather than recompute
		var st := str(nd.get("state", "locked"))
		if st == "locked" and str(nd.get("type", "")) != "core":
			# unreachable: drain the warmth so a branch you cannot take recedes into the
			# haze. Desaturate TOWARD grey, never TO it — collapsing to luminance first
			# flipped a FIREWALL's orange to cold blue and erased the accent palette on the
			# ~14 of 17 props that are locked at any moment. The CORE is exempt: it is
			# locked for almost the whole run and it is the goal beacon.
			var g: float = (lit.r + lit.g + lit.b) / 3.0
			lit = lit.lerp(Color(g, g, g, 1.0), 0.7) * Color(0.66, 0.72, 0.84, 1.0)
		elif st == "done" and i != cur:
			# spent: matches the grey EDGE_DEAD corridor behind you, but it KEEPS its accent
			# so you can still read what you already took
			lit = Color(lit.r * 0.62, lit.g * 0.66, lit.b * 0.72, 1.0)
		var tone := Color(minf(lit.r, LIGHT_CEIL.r), minf(lit.g, LIGHT_CEIL.g),
			minf(lit.b, LIGHT_CEIL.b), 1.0)
		var prev: Color = nd.get("itint", tone)
		# frame-rate independent, matching this file's own convention elsewhere
		var mixed: Color = prev.lerp(tone, 1.0 - exp(-9.0 * delta))
		nd["itint"] = mixed
		var sm := imat as ShaderMaterial
		sm.set_shader_parameter("tint", mixed)
		# The haze target has to TRACK THE LOCAL LIGHT, not sit at a constant. The floor fog
		# is additive over near-black deck, so the brightness a prop must blend into varies
		# roughly 30x across one screen — a fixed fog_color made every base either a glowing
		# skirt (on a dark node) or a black cut-out (on a bright one), depending only on where
		# the prop happened to stand.
		sm.set_shader_parameter("fog_color", Color(FOG_TINT.r * mixed.r, FOG_TINT.g * mixed.g,
			FOG_TINT.b * mixed.b, 1.0))


func _light_marker(delta: float) -> void:
	## The astronaut is an unshaded sprite, so nothing in the engine tints him and he
	## reads as pasted onto the scene. Gather the light actually reaching his cell —
	## the cool corridor wash plus each node's coloured pool, falling off with distance
	## — and modulate him with it. Now he darkens between nodes and picks up the
	## orange of a FIREWALL or the cyan of a cache as he steps into it.
	if _marker_spr == null:
		return
	# HIS OWN NUMBERS, deliberately not the shared LIGHT_* constants. Moving him onto the
	# props' sample height and floor measured +12-15% brighter on R/G and warmer — a visible
	# change to an asset that was tuned over many iterations and signed off. The shared
	# helper below is the part worth sharing; the tuning is not. If props and marker ever
	# need to agree, move the PROPS to these values, not him to theirs.
	var lit := _light_at(_marker.position, Color(0.42, 0.48, 0.58))
	# soft ceiling so a bright node never blows him out, and never let him go black
	var tone := Color(minf(lit.r, 1.06), minf(lit.g, 1.06), minf(lit.b, 1.08), 1.0)
	# frame-rate independent; -8.2 is the closest match to the approved 0.12/frame @60fps
	# (the old constant ran 2.4x faster on a 144Hz panel and smeared at 30)
	_marker_spr.modulate = _marker_spr.modulate.lerp(tone, 1.0 - exp(-8.2 * delta))


func _place_marker() -> void:
	_marker = Node3D.new()
	add_child(_marker)
	var sh := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(CELL * 0.55, CELL * 0.55)
	sh.mesh = sp
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = _shadow_tex
	sh.mesh.surface_set_material(0, smat)
	sh.position = Vector3(0.1, 0.03, 0.14)
	_marker.add_child(sh)
	var spr := Sprite3D.new()
	spr.texture = _tex.get("marker")
	if spr.texture != null:
		spr.pixel_size = (CELL * 0.62) / spr.texture.get_height()   # smaller overall
		spr.scale = Vector3(0.72, 1.0, 1.0)                          # narrow the bulky suit
		spr.position.y = spr.texture.get_height() * spr.pixel_size * 0.5 + 0.03   # feet on the floor
		spr.position.z = 0.0
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.shaded = false                                  # tinted by hand in _process instead
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD      # opaque pixels: sorts + casts shadows
	# a camera-facing billboard casts a degenerate shadow when a light is straight
	# overhead (it showed up as a dark ring at his feet) — the soft contact blob under
	# him sells the grounding instead
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(spr)
	_marker_spr = spr
	# his suit lamp: a small warm pool that travels with him, so the deck brightens
	# under his boots and he belongs to the scene instead of floating over it
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 0.62, 0.1)
	lamp.light_color = Color(0.86, 0.93, 1.0)
	lamp.light_energy = 1.35
	lamp.omni_range = 2.9
	lamp.omni_attenuation = 1.8
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.05
	_marker.add_child(lamp)
	_marker.position = _cell_world(nodes[cur]["gx"], nodes[cur]["gz"])
	_marker_last_pos = _marker.position
	if cur >= 0 and nodes[cur].has("icon"):
		nodes[cur]["icon"].visible = false   # he stands here — the node icon would mask him
	# entry shot: start CLOSE on the astronaut, aimed straight at him — the existing
	# follow lerp then eases the camera out to the map view over the first second
	var cam_off := Vector3(0.0, 8.0, 8.3).normalized() * 14.0   # entry: same angle, closer
	_cam.position = _marker.position + cam_off
	_look_at = _marker.position + Vector3(0, 0.3, -0.2)
	_cam_init = true
	_cam.look_at(_look_at)


# ==================================================================
# Process: camera follow, token pulse
# ==================================================================
func _process(delta: float) -> void:
	_t += delta
	if _marker != null:
		# lead the camera toward the destination while walking, then settle
		var target_ahead := Vector3.ZERO
		if _moving:
			target_ahead = (_walk_dest - _marker.position).limit_length(2.2) * 0.4
		_cam_ahead = _cam_ahead.lerp(target_ahead, 1.0 - exp(-3.0 * delta))
		# the dark version's angle + a faint idle drift for life
		var drift := Vector3(sin(_t * 0.27) * 0.14, 0.0, cos(_t * 0.21) * 0.1)
		# long-lens follow: same flat angle, pulled far back (tad of perspective at fov 20)
		var cam_off := Vector3(0.0, 8.0, 8.3).normalized() * (34.0 if _cam.projection == Camera3D.PROJECTION_PERSPECTIVE else 11.3)   # flat-ish with a small tilt — proportions stay right, sees a bit into the trench
		var want := _marker.position + _cam_ahead + drift + cam_off
		_cam.position = _cam.position.lerp(want, 1.0 - exp(-2.8 * delta))
		var look_target := _marker.position + _cam_ahead + Vector3(0, 0.3, -0.2)   # aim at the marker himself — always fully in frame, start node included
		if not _cam_init:
			_look_at = look_target
			_cam_init = true
		_look_at = _look_at.lerp(look_target, 1.0 - exp(-3.5 * delta))
		_cam.look_at(_look_at)
		# soft frame-clamp: if the marker drifts out of the middle band, pull the aim back
		var vps := _hud.get_viewport_rect().size if _hud != null else Vector2(1152, 648)
		var sp := _cam.unproject_position(_marker.position + Vector3(0, 0.8, 0))
		var over := Vector2.ZERO
		over.x = minf(sp.x - vps.x * 0.2, 0.0) + maxf(sp.x - vps.x * 0.8, 0.0)
		over.y = minf(sp.y - vps.y * 0.18, 0.0) + maxf(sp.y - vps.y * 0.72, 0.0)
		if over != Vector2.ZERO:
			var wpp: float = (_cam.size / vps.y) if _cam.projection == Camera3D.PROJECTION_ORTHOGONAL \
				else (2.0 * 34.0 * tan(deg_to_rad(_cam.fov * 0.5)) / vps.y)
			var bx := _cam.global_transform.basis
			_look_at += (bx.x * over.x - bx.y * over.y) * wpp
			_cam.look_at(_look_at)
		_light_marker(delta)
		_light_sigils(delta)
		if _hud != null:
			_hud.queue_redraw()   # node names are screen-space now; they track the camera
		# re-evaluate hover from the live cursor position, not only on mouse-motion events:
		# after a walk or a duel the mouse often hasn't moved, so the flare used to stay
		# stale (or never appear at all) until you wiggled it
		if mode == Mode.MAP and not _moving and _hud != null:
			var h := _hover_at(_hud.get_viewport().get_mouse_position())
			if h != _hover_node:
				_hover_node = h
				_paint_edges()
		# astronaut walk cycle — advance frames by DISTANCE moved; idle when stopped
		if _marker_spr != null and not (_mf_left.is_empty() and _mf_right.is_empty() and _mf_back.is_empty()):
			var dpos := _marker.position - _marker_last_pos
			var moved := dpos.length()
			_marker_last_pos = _marker.position
			if _moving and moved > 0.00001:
				_marker_walk_dist += moved
				# 3 facings only: side profiles + back. Moving toward camera keeps the last side.
				var setf: Array = _last_side
				if absf(dpos.x) > absf(dpos.z) + 0.0001:
					setf = _mf_left if dpos.x < 0.0 else _mf_right
					_last_side = setf
				elif dpos.z < 0.0 and not _mf_back.is_empty():
					setf = _mf_back   # walking away from camera (toward the core)
				if setf.is_empty():
					setf = _mf_right if not _mf_right.is_empty() else _mf_back
				# cycle distance stays constant whether a set has 8 or 16 (smoothed) frames;
				# the back view runs a longer cycle so its pace matches the sides
				var cyc: float = 3.6 * (1.15 if setf == _mf_back else 1.0)   # quick steps; back only slightly lazier (1.5x read as moonwalking)
				var fstep: float = cyc / setf.size()
				var fi: int = int(_marker_walk_dist / fstep) % setf.size()
				_marker_spr.texture = setf[fi]
				# walk bob — two beats per stride cycle, locked to the active set's cadence;
				# gentler on the back view (its art already carries some vertical motion)
				var bamp: float = 0.03 if setf == _mf_back else 0.045
				var mh: float = _marker_spr.texture.get_height() * _marker_spr.pixel_size
				_marker_spr.position.y = mh * 0.5 + 0.03 + mh * bamp * absf(sin(_marker_walk_dist * PI / (cyc * 0.5)))
			elif not _moving:
				_marker_spr.texture = _tex.get("marker")
				var mh: float = _marker_spr.texture.get_height() * _marker_spr.pixel_size
				_marker_spr.position.y = mh * 0.5 + 0.03
	_tick_sigils()
	# pulse reachable tokens + their target rings
	var pulse := 0.6 + 0.4 * sin(_t * 4.0)
	for nd in nodes:
		if nd.get("token") == null:
			continue
		var disc: MeshInstance3D = nd["token"]
		var m: StandardMaterial3D = disc.mesh.surface_get_material(0)
		var reach: bool = nd["state"] == "reach"
		if reach:
			m.albedo_color = Color(CYAN.r, CYAN.g, CYAN.b) * (0.7 + 0.5 * pulse) + Color(0.3, 0.3, 0.3)
		elif nd["state"] == "done":
			m.albedo_color = Color(0.5, 0.55, 0.62)
		else:
			m.albedo_color = Color(0.35, 0.38, 0.44)
		var ring = nd.get("ring")
		if ring != null:
			ring.visible = reach
			if reach:
				var s := 0.9 + 0.18 * sin(_t * 3.2)
				ring.scale = Vector3(s, s, s)
				var rm: StandardMaterial3D = ring.mesh.surface_get_material(0)
				rm.albedo_color.a = 0.4 + 0.35 * (0.5 + 0.5 * sin(_t * 3.2))
	# stream the energy chevrons up each corridor toward the core
	for fl in _flows:
		fl["phase"] = fmod(float(fl["phase"]) + float(fl["speed"]) * delta, float(fl["len"]))
		(fl["spr"] as Sprite3D).position = _sample_poly(fl["pts"], fl["cum"], float(fl["phase"]))
	if _hud != null:
		_hud.queue_redraw()


# ==================================================================
# Input
# ==================================================================
func _unhandled_input(event: InputEvent) -> void:
	if _duel != null:
		return
	# a sigil rig is asking a question — it owns the keyboard until answered
	if not _choice.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_choice = {}
			_msg = "Walked away from the rig."
			_hud.queue_redraw()
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_6:
			_choose(int(event.physical_keycode) - int(KEY_1))
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		_exit_to_flight("Breach aborted — back to the helm.")
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_O:
		# toggle: long-lens near-iso (default, a tad of perspective) <-> pure orthographic
		if _cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
			_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			_cam.fov = 20.0
			_msg = "Camera: near-iso long lens (default)"
		else:
			_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			_cam.size = 13.0
			_msg = "Camera: pure orthographic (O to switch back)"
		return
	if event is InputEventMouseMotion:
		var h := _hover_at((event as InputEventMouseMotion).position)
		if h != _hover_node:
			_hover_node = h
			_paint_edges()   # yellow-preview the corridor under the cursor
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)


func _click(m: Vector2) -> void:
	if mode == Mode.WON:
		_exit_to_flight("The station is freed. Survivors signal the ship.")
		return
	if mode != Mode.MAP or _moving:
		return
	var from := _cam.project_ray_origin(m)
	var dir := _cam.project_ray_normal(m)
	if absf(dir.y) < 0.0001:
		return
	var hit := from + dir * (-from.y / dir.y)   # intersect y=0
	for i in nodes.size():
		if nodes[i]["state"] != "reach":
			continue
		var np := _cell_world(nodes[i]["gx"], nodes[i]["gz"])
		if Vector2(hit.x, hit.z).distance_to(Vector2(np.x, np.z)) < CELL * 0.6:
			_walk_to(i)
			return


const WALK_SPEED := 3.1   # world units / second — slow enough for the walk cycle to read


func _walk_to(i: int) -> void:
	if cur >= 0 and nodes[cur].has("icon"):
		nodes[cur]["icon"].visible = true   # leaving — the node gets its icon back
	_moving = true
	_pending = i
	_walk_dest = _cell_world(nodes[i]["gx"], nodes[i]["gz"])
	Sfx.play("clack", -9.0)
	# build a clean ordered path: start cell → corridor → target, de-duped so there
	# are no zero-length backtrack steps
	var raw := [Vector2i(nodes[cur]["gx"], nodes[cur]["gz"])]
	raw.append_array(_corridor_cells(cur, i))
	raw.append(Vector2i(nodes[i]["gx"], nodes[i]["gz"]))
	var path: Array = []
	for c in raw:
		if path.is_empty() or path[path.size() - 1] != c:
			path.append(c)
	var segs := path.size() - 1
	var tw := _marker.create_tween()
	for k in range(1, path.size()):
		var a := _cell_world(path[k - 1].x, path[k - 1].y)
		var b := _cell_world(path[k].x, path[k].y)
		var t := tw.tween_property(_marker, "position", b, maxf(a.distance_to(b) / WALK_SPEED, 0.08))
		# constant speed through the middle; only ease the first take-off and last stop
		if segs == 1:
			t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		elif k == 1:
			t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		elif k == segs:
			t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			t.set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(_finish_walk.bind(i))


func _finish_walk(i: int) -> void:
	_moving = false
	if nodes[i].has("icon"):
		nodes[i]["icon"].visible = false   # he stands on this node now
	# arrival: no scale bump (read as cartoonish) — just the node light flash
	if nodes[i].has("light") and is_instance_valid(nodes[i]["light"]):
		var lg: OmniLight3D = nodes[i]["light"]
		var base := lg.light_energy
		var lt := lg.create_tween()
		lt.tween_property(lg, "light_energy", base * 2.3, 0.09)
		lt.tween_property(lg, "light_energy", base, 0.32)
	_spawn_shockwave(_cell_world(nodes[i]["gx"], nodes[i]["gz"]),
		TYPE_COLOR.get(nodes[i]["type"], CYAN))
	Sfx.play("clack", -6.0)
	_arrive(i)


func _spawn_shockwave(pos: Vector3, col: Color) -> void:
	if _tex.get("shockwave") == null:
		return
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(CELL, CELL)
	q.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _tex["shockwave"]
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_color = Color(col.r, col.g, col.b, 0.9)
	q.mesh.surface_set_material(0, m)
	q.position = pos + Vector3(0, 0.08, 0)
	q.scale = Vector3(0.3, 0.3, 0.3)
	add_child(q)
	var tw := q.create_tween().set_parallel(true)
	tw.tween_property(q, "scale", Vector3(2.6, 2.6, 2.6), 0.55).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(q.queue_free)


# ==================================================================
# Resolve nodes / duel
# ==================================================================
func _arrive(i: int) -> void:
	var t := str(nodes[i]["type"])
	if t == "quarantine" and not has_tool:
		# The gate stays shut and the node stays OPEN — come back with a vault tool.
		# BUT never when it is the ONLY way on: about half the rows generate a single link
		# (randf() < 0.4 for a second one), so a toolless run whose one exit was this gate
		# was hard-dead — no node advances, nothing rebuilds the reachable set, and
		# _exit_to_flight banks nothing because banking only happens at the core. If it is
		# the last door, it forces itself open and the ICE takes its toll in trace instead.
		var only_way: bool = nodes[cur]["links"].size() <= 1
		if not only_way:
			_pending = -1
			_msg = "QUARANTINE GATE is sealed. Find a DATA VAULT's breach tool and return."
			return
		_msg = "No tool and no way back — you tear the QUARANTINE GATE open. ICE-9 is awake."
		_start_duel(7)          # boss 7 ICE-9 QUARANTINE: the price of forcing it
		return
	if t == "blackice":
		# BLACK ICE is the run's OPT-IN apex fight, and the only home the expansion's top
		# tiers can have. It used to be a coin flip (randi() % 2: +8-12 shards or -4) with no
		# decision in it, while tier 4 COUNTERINTRUSION and boss 6 WARRANT SUITE sat
		# unreachable — they cannot go on a node you are forced onto (measured: a mandatory
		# tier-4 second fight cleared 14% and took whole-run clears to 3%). Choosing it is
		# the point: refuse and nothing happens, accept and it is the hardest thing in the
		# station. Deep ice is the WARRANT SUITE itself.
		var deep: bool = int(nodes[i]["row"]) >= 8
		var ice_diff: int = 6 if deep else 4
		var ice_name: String = "WARRANT SUITE" if deep else "COUNTERINTRUSION"
		_ice_fought = false
		_ask("BLACK ICE — %s is awake behind it" % ice_name,
			["Cut into it  ·  hardest fight on the station, and it pays like it",
			"Leave it sealed  ·  walk on, nothing gained, nothing lost"],
			func(k: int):
				if k == 0:
					_ice_fought = true
					_pending = i
					_start_duel(ice_diff)
				else:
					_msg = "You leave the BLACK ICE sealed. It watches you go."
					_finish_node(i))
		return
	if int(TYPES[t][2]) > 0:
		var diff: int = int(TYPES[t][2])
		if t == "bounty":
			# SCALE BY DEPTH, NOT STREAK. `streak` counts won duels, and ROW_PLAN gives a run
			# exactly three fights (battle / battle / core) — so at the second battle row the
			# streak is ALWAYS exactly 1, and the old `clampi(1 + streak / 2, 1, 4)` resolved
			# to tier 1. A BOUNTY DAEMON was fighting with the TEACHING deck at the deepest
			# battle row, i.e. the easiest fight in the game where it should be the hardest.
			# `streak >= 6` was unreachable for the same reason. Depth is the real lever.
			# Capped at 3: the bounty is ROLLED, not chosen, so it must not be able to hand
			# you a fight you cannot refuse. Measured on the real 3-fight ladder, a tier-4
			# second battle cleared only 14% and dropped whole-run clears to 3%; at tier 3 the
			# same slot sits where the difficulty curve wants it. Tier 4 and the apex boss
			# belong on an OPT-IN node — see the BLACK ICE note in DEVLOG v0.230.
			var row := int(nodes[i]["row"])
			diff = 3 if row >= 5 else 2
		_start_duel(diff)
	else:
		_finish_node(i)


func _start_duel(diff: int) -> void:
	mode = Mode.CHALLENGE
	_msg = "%s engaged — duel for the node." % TYPES[nodes[_pending]["type"]][0]
	# hide the whole 3D corridor world (+ map HUD) so it can't render through the duel
	_hidden = []
	for c in get_children():
		if c is Node3D:
			c.visible = false
			_hidden.append(c)
	if _hud != null:
		_hud.visible = false
	if _overlay != null:
		_overlay.visible = false
	_duel = DUEL.make(diff)
	add_child(_duel)
	_duel.finished.connect(_on_duel_finished)


func _on_duel_finished(won: bool) -> void:
	if _duel != null:
		_duel.queue_free()
		_duel = null
	for c in _hidden:
		if is_instance_valid(c):
			c.visible = true
	_hidden = []
	if _hud != null:
		_hud.visible = true
	if _overlay != null:
		_overlay.visible = true
	_cam.current = true   # take the view back from the duel camera
	mode = Mode.MAP
	if won:
		streak += 1
		_finish_node(_pending)
	else:
		# losing ENDS the run: HELIOS throws you off the station and everything banked in
		# there is gone — shards, colonists, deck edits. Fly back to breach it again fresh.
		streak = 0
		DUEL.run_deck = []
		DUEL.atk_boost = {}
		DUEL.graft = {}
		DUEL.fragile = []
		mode = Mode.CHALLENGE   # locks map input while the fade runs
		_msg = "FIREWALL HOLDS — ejected from the station."
		if _hud != null:
			_hud.queue_redraw()
		await get_tree().create_timer(1.1).timeout
		_exit_to_flight("Ejected from %s — the breach collapsed. Everything aboard is lost."
			% (station_name if station_name != "" else "the station"))


const LORE := [
	"…the crew logged 41 days of silence before HELIOS answered them.",
	"…she kept feeding the greenhouse long after the lights went.",
	"…HELIOS learned to imitate the captain's voice on the intercom.",
	"…the last entry is a lullaby, hummed, no words.",
	"…they voted to stay. All of them. Twice.",
]


func _deck() -> Array:
	return DUEL.run_deck


func _card_name(id: String) -> String:
	var c: Array = DUEL.CARDS.get(id, [])
	if c.is_empty():
		return id
	var boost: int = int(DUEL.atk_boost.get(id, 0))
	var extra: String = "  +%d" % boost if boost > 0 else ""
	return "%s  %d/%d  c%d%s" % [str(c[0]), int(c[2]) + boost, int(c[3]), int(c[4]), extra]


func _sig_count(id: String) -> int:
	var c: Array = DUEL.CARDS.get(id, [])
	var n: int = 0 if c.is_empty() else (c[5] as Array).size()
	return n + (DUEL.graft.get(id, []) as Array).size()


func _loot_pool(n: int) -> Array:
	## Cards you can be OFFERED. Enemy and boss cards are excluded outright: every HELIOS
	## card costs 0, so without this filter a vault could hand you a free 4/4 daemon and
	## the whole energy curve stops meaning anything.
	var foe := {}
	for tier in DUEL.OPP_DECKS:
		for id in (DUEL.OPP_DECKS[tier]["deck"] as Array):
			foe[id] = true
	var pool: Array = []
	for id in DUEL.CARDS:
		if foe.has(id):
			continue
		var cost: int = int(DUEL.CARDS[id][4])
		if cost >= 1 and cost <= 4 and _deck().count(id) < 3:
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, n)


func _ask_cards(title: String, ids: Array, note: String, cb: Callable) -> void:
	## card choices get the real thing: art, cost, stats, sigils, hover — see
	## breach_card_picker.gd. It frees itself after emitting, and it swallows the keys it
	## uses so the map's own hover/click never sees them.
	if ids.is_empty():
		_msg = "%s — nothing applicable." % title
		return
	var p = load("res://scripts/breach_card_picker.gd").make(ids, title, note)
	p.power_bonus = DUEL.atk_boost     # show OVERCLOCK / MERGE upgrades
	p.extra_sigils = DUEL.graft        # ...and anything a SPLICER grafted on
	p.chosen.connect(func(i: int):
		cb.call(i)
		_hud.queue_redraw())
	p.cancelled.connect(func():
		_msg = "Walked away from the rig."
		_hud.queue_redraw())
	add_child(p)


func _ask(title: String, opts: Array, cb: Callable) -> void:
	## tiny keyboard modal — 1..6 choose, ESC walks away. Cheap, and it keeps the map
	## readable instead of throwing a full card-picker UI over the corridor.
	if opts.is_empty():
		_msg = "%s — nothing applicable." % title
		return
	_choice = {"title": title, "opts": opts.slice(0, 6), "cb": cb}
	_hud.queue_redraw()


func _choose(k: int) -> void:
	if _choice.is_empty():
		return
	var opts: Array = _choice["opts"]
	if k < 0 or k >= opts.size():
		return
	var cb: Callable = _choice["cb"]
	_choice = {}
	cb.call(k)
	_hud.queue_redraw()


func _spend(n: int) -> bool:
	if shards < n:
		_msg = "Needs %d shards — you carry %d." % [n, shards]
		return false
	shards -= n
	return true


func _finish_node(i: int) -> void:
	nodes[i]["state"] = "done"
	cur = i
	_pending = -1
	_update_reach()
	var t := str(nodes[i]["type"])
	match t:
		"pod":
			colonists += 1
			_msg = "SURVIVOR POD — a cryo-berth wakes. %d aboard when the core falls." % colonists
		"ghost":
			shards += 2
			_msg = "GHOST SIGNAL %s  (+2 shards)" % LORE[randi() % LORE.size()]
		"cache":
			var g := 5 + randi() % 3
			shards += g
			_msg = "DATA CACHE — %d code shards siphoned." % g
		"vault":
			has_tool = true
			var offer := _loot_pool(3)
			_msg = "DATA VAULT — breach tool secured. Pick a card to carry."
			_ask_cards("DATA VAULT — keep one", offer, "free",
				func(k: int):
					_deck().append(offer[k])
					_msg = "%s joins the deck." % str(DUEL.CARDS[offer[k]][0]))
		"recycler":
			var d := _deck().duplicate()
			d.shuffle()
			var opts := d.slice(0, 5)
			_ask_cards("RECYCLER — scrap one for shards", opts, "pays 4 + 3 per sigil",
				func(k: int):
					var id: String = opts[k]
					var pay: int = mini(16, 4 + 3 * _sig_count(id))
					_deck().erase(id)
					shards += pay
					_msg = "%s shredded — +%d shards." % [str(DUEL.CARDS[id][0]), pay])
		"splicer":
			if not _spend(int(NODE_COST["splicer"])):
				return
			var donors: Array = []
			for id in _deck():
				# must have a BASE sigil to donate: gating on _sig_count would also count
				# grafted ones, then indexing CARDS[id][5][0] below would run off the end
				if not (DUEL.CARDS[id][5] as Array).is_empty() and not donors.has(id):
					donors.append(id)
			_ask_cards("CODE SPLICER — donor card (destroyed)", donors, "its sigil moves on",
				func(k: int):
					var dn: String = donors[k]
					var sig = (DUEL.CARDS[dn][5] as Array)[0]
					var targets := _deck().duplicate()
					targets.erase(dn)
					var uniq: Array = []
					for id in targets:
						if not uniq.has(id):
							uniq.append(id)
					# the donor is destroyed only once the graft actually happens — erasing it
					# here meant cancelling the second prompt ate the card for nothing
					_ask_cards("Graft %s onto…" % str(sig).to_upper(), uniq, "keeps its own sigils",
						func(j: int):
							var tg: String = uniq[j]
							_deck().erase(dn)
							var cur_g: Array = DUEL.graft.get(tg, [])
							cur_g = cur_g.duplicate()
							cur_g.append(sig)
							DUEL.graft[tg] = cur_g
							_msg = "%s now carries %s." % [str(DUEL.CARDS[tg][0]), str(sig).to_upper()]))
		"overclock":
			if not _spend(int(NODE_COST["overclock"])):
				return
			var d2 := _deck().duplicate()
			d2.shuffle()
			var uniq2: Array = []
			for id in d2:
				if not uniq2.has(id) and uniq2.size() < 6:
					uniq2.append(id)
			_ask_cards("OVERCLOCK RIG — weld one card permanently stronger", uniq2,
				"the card you pick gets +1 POWER for the rest of the run — but if it ever dies in a duel it is gone from your deck forever   ·   costs 9 shards",
				func(k: int):
					var id: String = uniq2[k]
					DUEL.atk_boost[id] = int(DUEL.atk_boost.get(id, 0)) + 1
					if not DUEL.fragile.has(id):
						DUEL.fragile.append(id)
					_msg = "%s overclocked — it will not survive a death." % str(DUEL.CARDS[id][0]))
		"exchange":
			if not _spend(int(NODE_COST["exchange"])):
				return
			var d3 := _deck().duplicate()
			d3.shuffle()
			var give := d3.slice(0, 4)
			_ask_cards("EXCHANGE — trade away", give, "one for one",
				func(k: int):
					var out_id: String = give[k]
					var offer2 := _loot_pool(3)
					_ask_cards("…for one of these", offer2, "",
						func(j: int):
							_deck().erase(out_id)
							_deck().append(offer2[j])
							_msg = "%s traded for %s." % [str(DUEL.CARDS[out_id][0]),
								str(DUEL.CARDS[offer2[j]][0])]))
		"merge":
			var dupes: Array = []
			for id in _deck():
				if _deck().count(id) >= 2 and not dupes.has(id):
					dupes.append(id)
			if dupes.is_empty():
				shards += 4
				_msg = "MERGE LAB — no matching pair to fuse. Stripped for 4 shards."
			elif _spend(int(NODE_COST["merge"])):
				_ask_cards("MERGE LAB — fuse a pair", dupes, "two become one, +1 power",
					func(k: int):
						var id: String = dupes[k]
						_deck().erase(id)   # two become one, and the one is stronger
						DUEL.atk_boost[id] = int(DUEL.atk_boost.get(id, 0)) + 1
						_msg = "%s fused — +1 power on every copy." % str(DUEL.CARDS[id][0]))
		"uplink":
			if not _spend(int(NODE_COST["uplink"])):
				return
			revealed = true
			_msg = "UPLINK RELAY — the corridor ahead resolves. Threat tiers exposed."
		"blackice":
			if not _ice_fought:
				pass          # declined — the _ask already wrote the message
			else:
				# beat the hardest fight on the station and it pays like it: a purse that
				# actually reaches a 12-shard SPLICER, plus a pick from the top of the pool
				var deep_ice: bool = int(nodes[i]["row"]) >= 8
				var pay3: int = 26 if deep_ice else 18
				shards += pay3
				_msg = "BLACK ICE BROKEN — %d shards torn out of it." % pay3
				var strong: Array = []
				for id in _loot_pool(40):
					if int(DUEL.CARDS[id][4]) >= 3:      # its drop is top-end only
						strong.append(id)
				strong.shuffle()
				var offer: Array = strong.slice(0, 3)
				if offer.is_empty():
					offer = _loot_pool(3)
				if not offer.is_empty():
					# The salvage comes out WELDED: +1 power permanently, and unlike the
					# OVERCLOCK RIG there is no `fragile` drawback — the rig charges 9 shards
					# for a buff that can lose you the card, whereas this was paid for with
					# the hardest fight in the run. Measured, taking the ice drops whole-run
					# clears from 16% to 3%, so a single extra card was nowhere near worth it.
					_ask_cards("BLACK ICE — salvage from the wreck", offer,
						"top-end only, and it comes out WELDED: +1 POWER for the rest of the run, with none of the OVERCLOCK RIG's burn-out risk",
						func(k: int):
							var got: String = offer[k]
							_deck().append(got)
							DUEL.run_deck = _deck()
							DUEL.atk_boost[got] = int(DUEL.atk_boost.get(got, 0)) + 1
							_msg = "%s cut out of the ice and welded — +1 POWER." \
								% str(DUEL.CARDS[got][0]))
				_ice_fought = false
		"bounty":
			var pay2 := 10 + 4 * streak
			shards += pay2
			_msg = "BOUNTY DAEMON put down — %d shards claimed." % pay2
		"firewall", "sentinel":
			_msg = "Node cleared. The corridor ahead unlocks."
		"quarantine":
			shards += 8
			_msg = "QUARANTINE GATE forced with the breach tool — +8 shards."
		"core":
			_msg = "HELIOS CORE CRACKED — the station is FREE. Click to return."
			# BANK the run's takings — until now colonists and shards existed only as a
			# toast and died with the scene, so a whole cleared station rewarded nothing
			if colonists > 0:
				_msg += "  %d survivors bound for Haven." % colonists
				GameState.breach_colonists += colonists
			if shards > 0:
				GameState.banked += shards * 2   # leftover code shards cash out as ore-value
				_msg += "  %d shards cashed out." % shards
			GameState.save_game()
			mode = Mode.WON


func _draw_choice(vp: Vector2) -> void:
	var opts: Array = _choice["opts"]
	var w := 560.0
	var h := 66.0 + opts.size() * 34.0
	var r := Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)
	_hud.draw_rect(r, Color(0.03, 0.05, 0.08, 0.94))
	_hud.draw_rect(r, Color(CYAN.r, CYAN.g, CYAN.b, 0.5), false, 2.0)
	_hud.draw_string(_font, r.position + Vector2(22, 34), str(_choice["title"]).to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, w - 44, 18, CYAN)
	for i in opts.size():
		var y := r.position.y + 62.0 + i * 34.0
		_hud.draw_string(_font, Vector2(r.position.x + 26, y), "%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, 30, 17, Color(0.95, 0.8, 0.4))
		_hud.draw_string(_font, Vector2(r.position.x + 56, y), str(opts[i]),
			HORIZONTAL_ALIGNMENT_LEFT, w - 80, 17, Color(0.86, 0.93, 1.0))
	_hud.draw_string(_font, Vector2(r.position.x + 22, r.end.y - 12),
		"press 1-%d   ·   ESC walks away" % opts.size(), HORIZONTAL_ALIGNMENT_LEFT, w - 44, 12,
		Color(CYAN.r, CYAN.g, CYAN.b, 0.6))


func _exit_to_flight(note: String) -> void:
	GameState.say(note)
	Transition.to_scene("res://scenes/flight.tscn")


# ==================================================================
# HUD text
# ==================================================================
func _draw_node_names() -> void:
	## Node names, in SCREEN space. Constant contrast at every depth, no cube can occlude a
	## glyph, and the Environment's black fog cannot dim them — the three things that made
	## the old Label3D approach unreadable past the second row.
	if _cam == null or nodes.is_empty():
		return
	var vp := _hud.get_viewport_rect().size
	for i in nodes.size():
		var nd = nodes[i]
		if not nd.has("label_anchor") or not nd.has("node"):
			continue
		var root = nd["node"]
		if root == null or not is_instance_valid(root):
			continue
		var wpos: Vector3 = (root as Node3D).global_position + (nd["label_anchor"] as Vector3)
		if _cam.is_position_behind(wpos):
			continue
		var sp := _cam.unproject_position(wpos)
		if sp.x < -160.0 or sp.x > vp.x + 160.0 or sp.y < 54.0 or sp.y > vp.y - 40.0:
			continue                     # off screen, or under the HUD banner / status bar
		var txt := str(TYPES[nd["type"]][0])
		var st := str(nd.get("state", "locked"))
		# a name you can walk to is white; one you cannot is dimmed but still legible —
		# reachability reads in the type, not by making text unreadable
		var col := Color(1, 1, 1, 1.0) if (i == cur or st != "locked") \
			else Color(0.72, 0.79, 0.88, 0.62)
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PX).x
		var at := Vector2(sp.x - w * 0.5, sp.y)
		# fat black stroke, drawn as 8 offset copies: the name has to read over lit plating,
		# a glowing pedestal or pure black void
		for ox in [-2, 0, 2]:
			for oy in [-2, 0, 2]:
				if ox == 0 and oy == 0:
					continue
				_hud.draw_string(_font, at + Vector2(ox, oy), txt, HORIZONTAL_ALIGNMENT_LEFT,
					-1, NAME_PX, Color(0, 0, 0, col.a))
		_hud.draw_string(_font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PX, col)


func _on_hud_draw() -> void:
	_draw_node_names()
	var vp := _hud.get_viewport_rect().size
	_hud.draw_rect(Rect2(0, 0, vp.x, 58), Color(0.02, 0.03, 0.05, 0.82))
	var nm := station_name if station_name != "" else "UNKNOWN STATION"
	_hud.draw_string(_font, Vector2(24, 30), "THE BREACH — %s" % nm.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, CYAN)
	_hud.draw_string(_font, Vector2(24, 50),
		"walk the corridors to the HELIOS core   ·   ESC leaves the breach",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CYAN.r, CYAN.g, CYAN.b, 0.6))
	# run purse: shards fund the rigs, colonists ride home when the core cracks
	var purse := "◈ %d SHARDS" % shards
	if colonists > 0:
		purse += "    ☻ %d SURVIVORS" % colonists
	if has_tool:
		purse += "    ⚿ BREACH TOOL"
	if streak > 1:
		purse += "    ✦ STREAK %d" % streak
	_hud.draw_string(_font, Vector2(vp.x - 470, 30), purse, HORIZONTAL_ALIGNMENT_RIGHT, 446, 17,
		Color(0.72, 0.9, 1.0))
	_hud.draw_rect(Rect2(0, vp.y - 40, vp.x, 40), Color(0.02, 0.03, 0.05, 0.82))
	_hud.draw_string(_font, Vector2(24, vp.y - 14), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.85, 0.92, 1.0))
	if not _choice.is_empty():
		_draw_choice(vp)
	if mode == Mode.WON:
		_hud.draw_string(_font, Vector2(0, vp.y * 0.5), "STATION FREED",
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 40, CYAN)
