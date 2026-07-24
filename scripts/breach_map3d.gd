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
	"gain": ["cache", "vault"], "util": ["pod", "ghost"], "battle": ["firewall", "sentinel"],
}
# type -> [label, icon, challenge difficulty (0 = event)]
const TYPES := {
	"access": ["ACCESS PORT", "icon_access", 0], "firewall": ["FIREWALL", "icon_firewall", 1],
	"sentinel": ["SENTINEL", "icon_sentinel", 2], "pod": ["SURVIVOR POD", "icon_pod", 0],
	"cache": ["DATA CACHE", "icon_cache", 0], "ghost": ["GHOST SIGNAL", "icon_ghost", 0],
	"vault": ["DATA VAULT", "icon_vault", 0], "core": ["HELIOS CORE", "icon_core", 3],
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
}

enum Mode { MAP, CHALLENGE, WON }
var mode: int = Mode.MAP

var nodes: Array = []      # {row,col,ncol,type,links,state,gx,gz, node:Node3D, token:MeshInstance3D}
var cur := -1
var _pending := -1
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
var _font: Font = ThemeDB.fallback_font
var _flows: Array = []      # {spr, pts:PackedVector3Array, cum, len, phase, speed}
var _overlay: CanvasLayer   # scanline/vignette/tilt-shift post overlay (hidden during duel)
var _emis_cache := {}       # shared emissive materials for set-piece windows


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
	_tex["token_base"] = _load_png(MAP_DIR + "token_base.png")
	for fx in ["dust", "flow_arrow", "node_ring", "shockwave"]:
		_tex[fx] = _load_png(MAP_DIR + "fx/" + fx + ".png")
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
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.5))
	g.set_color(0.55, Color(0, 0, 0, 0.32))
	g.set_color(1, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 96
	gt.height = 96
	_shadow_tex = gt


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
	e.ambient_light_color = Color(0.14, 0.2, 0.34)
	e.ambient_light_energy = 0.08   # almost nothing — darkness hides the map edges
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
	# NO global key light — the field falls to black at the edges; only the corridor
	# point lights + node lights + the rooms' own glowing windows carry the light/shadow.
	# NO global key light — the field must fall into black at the edges. Only the
	# lights placed ALONG the corridor illuminate anything (see _build_path_glow).
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
	_cube_side_mat.albedo_color = Color(0.66, 0.7, 0.78)
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
			nodes.append({"row": r, "col": c, "ncol": w, "type": _pick_variant(cat, c),
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
			if apron.has(Vector2i(gx, gz)):
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
			var pts := [Vector2i(nodes[i]["gx"], nodes[i]["gz"])]
			pts.append_array(_corridor_cells(i, j))
			pts.append(Vector2i(nodes[j]["gx"], nodes[j]["gz"]))
			for k in range(pts.size() - 1):
				var a := _cell_world(pts[k].x, pts[k].y)
				var b := _cell_world(pts[k + 1].x, pts[k + 1].y)
				if a.distance_to(b) < 0.01:
					continue
				var d := b - a
				var yaw := atan2(d.x, d.z)
				var mid := (a + b) * 0.5

				# soft floor halo (flat plane, oriented along the segment)
				var rib := MeshInstance3D.new()
				var rm := PlaneMesh.new()
				rm.size = Vector2(0.5, a.distance_to(b) + 0.12)
				rib.mesh = rm
				rib.mesh.surface_set_material(0, halo_mat)
				rib.position = mid + Vector3(0, 0.045, 0)
				rib.rotation.y = yaw
				add_child(rib)

				# crisp core
				var seg := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.05, 0.03, a.distance_to(b) + 0.06)
				seg.mesh = bm
				seg.mesh.surface_set_material(0, core_mat)
				seg.position = mid + Vector3(0, 0.08, 0)
				seg.look_at_from_position(seg.position, b, Vector3.UP)
				add_child(seg)
			# glow dot at each cell — hides corner seams, gives connector nodes
			for c in pts:
				if not dotted.has(c):
					dotted[c] = true
					var dot := MeshInstance3D.new()
					var dpm := PlaneMesh.new()
					dpm.size = Vector2(0.72, 0.72)
					dot.mesh = dpm
					dot.mesh.surface_set_material(0, dot_mat)
					dot.position = _cell_world(c.x, c.y) + Vector3(0, 0.05, 0)
					add_child(dot)
			# a blue point light on every path cell — lights the trench + nearby cube
			# walls, and everything past its reach falls to black
			for c in pts:
				if lit.has(c):
					continue
				lit[c] = true
				var lg := OmniLight3D.new()
				lg.position = _cell_world(c.x, c.y) + Vector3(0, 0.8, 0)
				lg.light_color = Color(0.4, 0.75, 1.0)
				lg.light_energy = 2.2
				lg.omni_range = 3.6
				add_child(lg)


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
	# drop shadow on the floor
	var sh := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	var ssz := CELL * (0.8 if big else 0.56)
	sp.size = Vector2(ssz, ssz)
	sh.mesh = sp
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = _shadow_tex
	sh.mesh.surface_set_material(0, smat)
	sh.position = Vector3(0.12, 0.02, 0.16)
	root.add_child(sh)
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
	# icon standing upright on the token, billboarded — kept small + tight
	var icon := Sprite3D.new()
	icon.texture = _tex.get(TYPES[nd["type"]][1])
	if icon.texture != null:
		icon.pixel_size = (CELL * (0.82 if big else 0.5)) / icon.texture.get_height()
	icon.position.y = CELL * (0.52 if big else 0.36)
	icon.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	icon.shaded = false
	icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	root.add_child(icon)
	nd["icon"] = icon   # hidden while the astronaut stands on this node
	# a light on the token in its own accent colour — pools of orange/teal/violet/red
	# down the corridor so the stage isn't one flat blue
	var acol: Color = TYPE_COLOR.get(nd["type"], CYAN)
	var lgt := OmniLight3D.new()
	lgt.position.y = 1.5
	lgt.light_color = acol
	lgt.light_energy = 3.4 if big else 2.0
	lgt.omni_range = 8.0 if big else 4.6
	root.add_child(lgt)
	nd["light"] = lgt
	# floating name label
	var lab := Label3D.new()
	lab.text = str(TYPES[nd["type"]][0])
	lab.font_size = 40
	lab.pixel_size = 0.004
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.8, 0.9, 1.0)
	lab.outline_size = 12
	lab.position.y = 0.08
	lab.position.z = CELL * 0.55
	root.add_child(lab)


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
const FOG_Y := 0.30            # height above the recessed floor
const FOG_PAD_CELLS := 1       # extra cells of mask bleed around the path
const MASK_PX_PER_CELL := 12   # coverage-mask resolution
const MASK_BLUR := 3           # soft-edge radius in mask pixels

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
	float n1 = fbm(wxz * noise_scale + vec2( TIME * scroll_speed,  TIME * scroll_speed * 0.6));
	float n2 = fbm(wxz * noise_scale * 1.9 + vec2(-TIME * scroll_speed * 0.7, TIME * scroll_speed * 0.4));
	float n  = mix(n1, n2, 0.5);
	float mist = smoothstep(coverage_bias, coverage_bias + edge_softness, n);
	vec2 muv = (wxz - mask_world_min) / mask_world_size;
	float mask = texture(corridor_mask, muv).r;
	mask *= step(0.0, muv.x) * step(muv.x, 1.0) * step(0.0, muv.y) * step(muv.y, 1.0);
	ALBEDO = fog_color;
	ALPHA  = clamp(mist * mask * density, 0.0, 1.0);
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
	_spawn_fog_layer(mat2, Vector3((xmin + xmax) * 0.5, FOG_Y + 0.35, (zmin + zmax) * 0.5),
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
	spr.shaded = false
	_marker.add_child(spr)
	_marker_spr = spr
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
	if int(TYPES[nodes[i]["type"]][2]) > 0:
		_start_duel(int(TYPES[nodes[i]["type"]][2]))
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
		_finish_node(_pending)
	else:
		_msg = "EJECTED — the node holds. Walk back in to breach again."


func _finish_node(i: int) -> void:
	nodes[i]["state"] = "done"
	cur = i
	_pending = -1
	_update_reach()
	match str(nodes[i]["type"]):
		"pod": _msg = "SURVIVOR POD — a cryo-berth wakes. Ready when the core falls."
		"ghost": _msg = "GHOST SIGNAL — a survivor's log crackles through."
		"cache": _msg = "DATA CACHE — spare code siphoned."
		"vault": _msg = "DATA VAULT — a breach tool for the climb."
		"firewall", "sentinel": _msg = "Node cleared. The corridor ahead unlocks."
		"core":
			_msg = "HELIOS CORE CRACKED — the station is FREE. Click to return."
			mode = Mode.WON


func _exit_to_flight(note: String) -> void:
	GameState.say(note)
	Transition.to_scene("res://scenes/flight.tscn")


# ==================================================================
# HUD text
# ==================================================================
func _on_hud_draw() -> void:
	var vp := _hud.get_viewport_rect().size
	_hud.draw_rect(Rect2(0, 0, vp.x, 58), Color(0.02, 0.03, 0.05, 0.82))
	var nm := station_name if station_name != "" else "UNKNOWN STATION"
	_hud.draw_string(_font, Vector2(24, 30), "THE BREACH — %s" % nm.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, CYAN)
	_hud.draw_string(_font, Vector2(24, 50),
		"walk the corridors to the HELIOS core   ·   ESC leaves the breach",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CYAN.r, CYAN.g, CYAN.b, 0.6))
	_hud.draw_rect(Rect2(0, vp.y - 40, vp.x, 40), Color(0.02, 0.03, 0.05, 0.82))
	_hud.draw_string(_font, Vector2(24, vp.y - 14), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.85, 0.92, 1.0))
	if mode == Mode.WON:
		_hud.draw_string(_font, Vector2(0, vp.y * 0.5), "STATION FREED",
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 40, CYAN)
