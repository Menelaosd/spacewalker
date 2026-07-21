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
const TYPE_COLOR := {
	"access": Color(0.45, 0.85, 1.0), "firewall": Color(1.0, 0.5, 0.2),
	"sentinel": Color(1.0, 0.32, 0.28), "pod": Color(0.3, 0.95, 0.8),
	"cache": Color(1.0, 0.72, 0.25), "ghost": Color(0.72, 0.45, 1.0),
	"vault": Color(0.45, 0.85, 1.0), "core": Color(1.0, 0.45, 0.2),
}

enum Mode { MAP, CHALLENGE, WON }
var mode: int = Mode.MAP

var nodes: Array = []      # {row,col,ncol,type,links,state,gx,gz, node:Node3D, token:MeshInstance3D}
var cur := -1
var _pending := -1
var _msg := "Breach open. Walk the marker to a lit node."
var _t := 0.0

var _cam: Camera3D
var _hud: Control
var _marker: Node3D
var _moving := false
var _tex := {}
var _duel: Node3D = null
var _hidden: Array = []     # map nodes hidden while a duel is on screen
var _path_mat: StandardMaterial3D       # recessed walkway floor
var _cube_top_mat: StandardMaterial3D   # top of the raised block field
var _cube_side_mat: StandardMaterial3D  # block side walls
var _shadow_tex: Texture2D
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	if OS.get_environment("SW_BREACH_ST") != "":
		station_id = OS.get_environment("SW_BREACH_ST")
		station_name = station_id.replace("_", " ")
	for t in TYPES:
		_tex[TYPES[t][1]] = _load_art(str(TYPES[t][1]))
	_tex["marker"] = _load_art("marker")
	_tex["token_base"] = _load_png(MAP_DIR + "token_base.png")
	_build_shadow_tex()
	_build_stage()
	_gen_map()
	_build_map_nodes()
	_place_marker()
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
	_cam.fov = 48.0
	_cam.position = Vector3(0, 8.0, 6.0)
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
	env.environment = e
	add_child(env)
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
		ct = _load_png(THEME_DIR + station_id + ".png")
	if ct == null:
		ct = _load_png(MAP_DIR + "floor_top.png")
	_cube_top_mat.albedo_texture = ct
	_cube_top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_cube_top_mat.albedo_color = Color(0.56, 0.6, 0.68)
	_cube_top_mat.roughness = 0.9
	_cube_side_mat = StandardMaterial3D.new()
	var cs := _load_png(MAP_DIR + "cube_side.png")
	if cs == null:
		cs = _load_png(MAP_DIR + "wall_panel.png")
	_cube_side_mat.albedo_texture = cs
	_cube_side_mat.uv1_triplanar = true
	_cube_side_mat.uv1_scale = Vector3(0.55, 0.55, 0.55)
	_cube_side_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_cube_side_mat.roughness = 0.85
	# HUD overlay for text
	var layer := CanvasLayer.new()
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
	var lo: int = mini(a["gx"], b["gx"])
	var hi: int = maxi(a["gx"], b["gx"])
	for gx in range(lo, hi + 1):
		cells.append(Vector2i(gx, midz))           # across
	cells.append(Vector2i(b["gx"], b["gz"] - 1))   # up into b (== midz when adjacent, dedup later)
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
	for gz in range(minz, maxz + 1):
		for gx in range(minx, maxx + 1):
			var w := _cell_world(gx, gz)
			if path_cells.has(Vector2i(gx, gz)):
				var fl := MeshInstance3D.new()
				var fp := PlaneMesh.new()
				fp.size = Vector2(CELL, CELL)
				fl.mesh = fp
				fl.mesh.surface_set_material(0, _path_mat)
				fl.position = w
				add_child(fl)
			else:
				var body := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(CELL, CUBE_H, CELL)
				body.mesh = bm
				body.mesh.surface_set_material(0, _cube_side_mat)
				body.position = w + Vector3(0, CUBE_H * 0.5, 0)
				add_child(body)
				var top := MeshInstance3D.new()
				var tp := PlaneMesh.new()
				tp.size = Vector2(CELL, CELL)
				top.mesh = tp
				top.mesh.surface_set_material(0, _cube_top_mat)
				top.position = w + Vector3(0, CUBE_H + 0.002, 0)
				add_child(top)
	_build_path_glow()
	for i in nodes.size():
		_build_token(i)


func _build_path_glow() -> void:
	## A glowing blue line runs down the middle of the carved corridors.
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.albedo_color = Color(0.3, 0.8, 1.0)
	gmat.emission_enabled = true
	gmat.emission = Color(0.35, 0.8, 1.0)
	gmat.emission_energy_multiplier = 3.0
	var lit := {}   # cells that already have a corridor light (avoid piling them up)
	for i in nodes.size():
		for j in nodes[i]["links"]:
			var pts := [Vector2i(nodes[i]["gx"], nodes[i]["gz"])]
			pts.append_array(_corridor_cells(i, j))
			pts.append(Vector2i(nodes[j]["gx"], nodes[j]["gz"]))
			for k in range(pts.size() - 1):
				var a := _cell_world(pts[k].x, pts[k].y) + Vector3(0, 0.06, 0)
				var b := _cell_world(pts[k + 1].x, pts[k + 1].y) + Vector3(0, 0.06, 0)
				if a.distance_to(b) < 0.01:
					continue
				var seg := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.07, 0.035, a.distance_to(b) + 0.07)   # thin line
				seg.mesh = bm
				seg.mesh.surface_set_material(0, gmat)
				seg.position = (a + b) * 0.5
				seg.look_at_from_position(seg.position, b, Vector3.UP)
				add_child(seg)
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
	# a light on the token in its own accent colour — pools of orange/teal/violet/red
	# down the corridor so the stage isn't one flat blue
	var acol: Color = TYPE_COLOR.get(nd["type"], CYAN)
	var lgt := OmniLight3D.new()
	lgt.position.y = 1.5
	lgt.light_color = acol
	lgt.light_energy = 3.4 if big else 2.0
	lgt.omni_range = 8.0 if big else 4.6
	root.add_child(lgt)
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
		spr.pixel_size = (CELL * 0.62) / spr.texture.get_height()
	spr.position.y = CELL * 0.42
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.shaded = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_marker.add_child(spr)
	_marker.position = _cell_world(nodes[cur]["gx"], nodes[cur]["gz"])


# ==================================================================
# Process: camera follow, token pulse
# ==================================================================
func _process(delta: float) -> void:
	_t += delta
	if _marker != null:
		var want := _marker.position + Vector3(0.0, 9.4, 6.4)
		_cam.position = _cam.position.lerp(want, 1.0 - exp(-4.0 * delta))
		_cam.look_at(_marker.position + Vector3(0, 0.2, -2.2))
	# pulse reachable tokens
	for nd in nodes:
		if nd.get("token") == null:
			continue
		var disc: MeshInstance3D = nd["token"]
		var m: StandardMaterial3D = disc.mesh.surface_get_material(0)
		if nd["state"] == "reach":
			var p := 0.6 + 0.4 * sin(_t * 4.0)
			m.albedo_color = Color(CYAN.r, CYAN.g, CYAN.b) * (0.7 + 0.5 * p) + Color(0.3, 0.3, 0.3)
		elif nd["state"] == "done":
			m.albedo_color = Color(0.5, 0.55, 0.62)
		else:
			m.albedo_color = Color(0.35, 0.38, 0.44)
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


func _walk_to(i: int) -> void:
	_moving = true
	_pending = i
	Sfx.play("clack", -10.0)
	# walk the marker cell-by-cell along the corridor
	var path := _corridor_cells(cur, i)
	path.append(Vector2i(nodes[i]["gx"], nodes[i]["gz"]))
	var tw := _marker.create_tween().set_trans(Tween.TRANS_SINE)
	for c in path:
		tw.tween_property(_marker, "position", _cell_world(c.x, c.y), 0.14)
	tw.tween_callback(func():
		_moving = false
		_arrive(i))


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
