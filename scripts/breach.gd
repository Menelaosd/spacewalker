extends Control
## THE BREACH — the station-intrusion chart. Works exactly like Inscryption's Act 1 map,
## skinned as a sci-fi deck schematic of the station you're cracking:
##   · a vertical chart on dark deck plating, taller than the screen, scrolls as you climb
##   · rows are CATEGORY-typed (gain / utility / battle repeating, boss core at the top) and
##     each row offers different VARIANTS of that category — the choice is which flavour
##   · dotted conduit paths that branch AND merge; a hologram marker hops forward-only
##   · battle nodes open THE DUEL (breach_duel.gd) — an exact Inscryption card battle
## Entered from flight when the ship approaches any station (testing wiring). ESC returns
## to flight; freeing the core also returns to flight.
## Run standalone: godot res://scenes/breach.tscn   (SW_BREACH_CH=1 jumps into a duel)

enum Mode { MAP, CHALLENGE, WON }

static var station_name := ""    # set by flight.gd just before the transition
static var station_id := ""      # picks the themed tile + prop set for this map

const DUEL := preload("res://scripts/breach_duel3d.gd")

# art fallback chain: HD pass first, then the flat sci-fi set
const ART_DIRS := ["res://assets/sprites/breach/hd/", "res://assets/sprites/breach/scifi/"]
const THEME_DIR := "res://assets/sprites/breach/themes/"
const PROP_DIR := "res://assets/sprites/breach/props/"

# every map scatters these; station themes append their own flavour props
const PROPS_GENERIC := ["vent", "pipes", "crate", "terminal", "wires", "drone_wreck",
	"debris", "hazard", "valve", "antenna", "server", "skeleton"]
const PROPS_THEME := {
	"bastion_command_citadel": ["ammo", "barrel"],
	"bulwark_arsenal_depot": ["ammo", "barrel"],
	"cryo_sleeper_vault_hexpod": ["ice", "tank"],
	"gilded_wake_derelict_liner": ["gold", "fountain"],
	"glacier_still_ice_harvester": ["ice", "tank"],
	"halcyon_ring_habitat": ["bed", "plant"],
	"helios_bloom_solar_array": ["solar", "antenna"],
	"tanker_cluster_fuel_depot": ["barrel", "tank"],
	"vantage_quarantine_biolab": ["biohazard", "tank"],
	"verdant_bloom_spa_resort": ["fountain", "gold"],
	"verdant_halo_hydroponics_ring": ["plant", "vines"],
	"vespers_reliquary_cloister": ["candle", "gold"],
}
const INK := Color(0.55, 0.82, 0.95)               # conduit glow
const INK_FADE := Color(0.4, 0.6, 0.75, 0.3)
const RED_INK := Color(1.0, 0.35, 0.28)
const HDR := Color(0.65, 0.88, 1.0)

# Inscryption row plan, bottom → top: start, then gain/utility/battle triads, boss core.
const ROW_PLAN := ["access", "gain", "util", "battle", "gain", "util", "battle", "gain", "util", "core"]
# category -> the variant node types offered on that row
const CATEGORY := {
	"gain": ["cache", "vault"],
	"util": ["pod", "ghost"],
	"battle": ["firewall", "sentinel"],
}
# type -> [label, icon file, challenge difficulty (0 = event, no challenge)]
const TYPES := {
	"access":   ["ACCESS PORT", "icon_access", 0],
	"firewall": ["FIREWALL", "icon_firewall", 1],
	"sentinel": ["SENTINEL", "icon_sentinel", 2],
	"pod":      ["SURVIVOR POD", "icon_pod", 0],
	"cache":    ["DATA CACHE", "icon_cache", 0],
	"ghost":    ["GHOST SIGNAL", "icon_ghost", 0],
	"vault":    ["DATA VAULT", "icon_vault", 0],
	"core":     ["HELIOS CORE", "icon_core", 3],
}

const ROW_GAP := 180.0
const MAP_PAD := 150.0
var MAP_H: float = MAP_PAD * 2.0 + (ROW_PLAN.size() - 1) * ROW_GAP

var mode: int = Mode.MAP
var nodes: Array = []       # {row,col,ncol,type,links:Array,state,jx,jy}  state: locked/reach/done
var cur := -1
var _pending := -1          # node being hopped-to / challenged
var _hop_t := -1.0          # <0 = not hopping
var _msg := "The chart unrolls. Click a linked node to climb."
var _t := 0.0
var _scroll := 0.0
var _peek := 0.0
var _font: Font = ThemeDB.fallback_font
var _tex := {}              # name -> ImageTexture (raw-loaded, no .import needed)
var _paper_tile: Texture2D  # seamless deck plating — the scrolling chart backdrop
var _duel: Node3D = null    # the live 3D duel at a battle node (chart sleeps under it)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.get_environment("SW_BREACH_ST") != "":
		station_id = OS.get_environment("SW_BREACH_ST")   # debug: force a theme (screenshots)
		station_name = station_id.replace("_", " ")
	for t in TYPES:
		_tex[TYPES[t][1]] = _load_art(str(TYPES[t][1]))
	for n in ["marker", "path_seg", "node_pad", "node_pad_boss"]:
		_tex[n] = _load_art(n)
	# tile: this station's theme, else the HD generic plating, else the flat one
	_paper_tile = _load_png(THEME_DIR + station_id + ".png")
	if _paper_tile == null:
		_paper_tile = _load_png(ART_DIRS[0] + "map_tile.png")
	if _paper_tile == null:
		_paper_tile = _load_png(ART_DIRS[1] + "deck_tile.png")
	_gen_map()
	_scroll = maxf(MAP_H - get_viewport_rect().size.y, 0.0)   # start at the bottom
	if OS.get_environment("SW_BREACH_CH") != "":
		for i in nodes.size():   # debug: jump onto the first battle node (screenshots)
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


# ==================================================================
# Map generation — Inscryption rules
# ==================================================================
func _row_width(cat: String) -> int:
	if cat == "access" or cat == "core":
		return 1
	var roll := randf()
	if roll < 0.15: return 1
	if roll < 0.70: return 2
	return 3


func _gen_map() -> void:
	nodes = []
	var idx := {}
	for r in ROW_PLAN.size():
		var cat: String = ROW_PLAN[r]
		var w := _row_width(cat)
		# the row's category decides the offer; multiple nodes = different variants
		var variants: Array = [cat] if not CATEGORY.has(cat) else (CATEGORY[cat] as Array).duplicate()
		variants.shuffle()
		for c in w:
			idx[Vector2i(r, c)] = nodes.size()
			nodes.append({
				"row": r, "col": c, "ncol": w,
				"type": variants[c % variants.size()],
				"links": [], "state": "locked",
				"jx": randf_range(-16.0, 16.0), "jy": randf_range(-10.0, 10.0),
			})
	# link rows: nearest-column path + occasional extra branch; paths merge naturally
	for i in nodes.size():
		var nd: Dictionary = nodes[i]
		var r: int = nd["row"]
		if r == ROW_PLAN.size() - 1:
			continue
		var nn: int = nodes[idx[Vector2i(r + 1, 0)]]["ncol"]
		var frac: float = (nd["col"] + 0.5) / float(nd["ncol"])
		var tc := clampi(int(frac * nn), 0, nn - 1)
		var targets := [tc]
		if randf() < 0.4:
			targets.append(clampi(tc + (1 if randf() < 0.5 else -1), 0, nn - 1))
		for c in targets:
			var j: int = idx[Vector2i(r + 1, c)]
			if not nd["links"].has(j):
				nd["links"].append(j)
	# every node must be reachable: give orphaned next-row nodes an in-link
	for r in range(1, ROW_PLAN.size()):
		var w: int = nodes[idx[Vector2i(r, 0)]]["ncol"]
		for c in w:
			var j: int = idx[Vector2i(r, c)]
			var has_in := false
			for i in nodes.size():
				if nodes[i]["links"].has(j):
					has_in = true
					break
			if not has_in:
				var frac := (c + 0.5) / float(w)
				var pw: int = nodes[idx[Vector2i(r - 1, 0)]]["ncol"]
				var pc := clampi(int(frac * pw), 0, pw - 1)
				nodes[idx[Vector2i(r - 1, pc)]]["links"].append(j)
	cur = idx[Vector2i(0, 0)]
	nodes[cur]["state"] = "done"
	_update_reach()


func _update_reach() -> void:
	for n in nodes:
		if n["state"] == "reach":
			n["state"] = "locked"
	for j in nodes[cur]["links"]:
		if nodes[j]["state"] == "locked":
			nodes[j]["state"] = "reach"


# ==================================================================
# Positions & scroll
# ==================================================================
func _map_pos(i: int) -> Vector2:
	## Node position in MAP space (y grows downward; row 0 at the bottom).
	var nd: Dictionary = nodes[i]
	var vp := get_viewport_rect().size
	var y: float = MAP_H - MAP_PAD - nd["row"] * ROW_GAP + nd["jy"]
	var span := minf(vp.x * 0.52, 540.0)
	var x: float = vp.x * 0.5 + (nd["col"] - (nd["ncol"] - 1) * 0.5) * (span / maxf(nd["ncol"], 1)) + nd["jx"]
	return Vector2(x, y)


func _screen(p: Vector2) -> Vector2:
	return Vector2(p.x, p.y - _scroll)


func _marker_map_pos() -> Vector2:
	if mode == Mode.CHALLENGE and _pending >= 0:
		return _map_pos(_pending)   # the marker stands on the contested node
	if _hop_t >= 0.0 and _pending >= 0:
		var a := _map_pos(cur)
		var b := _map_pos(_pending)
		var t := clampf(_hop_t, 0.0, 1.0)
		var p := a.lerp(b, t)
		p.y -= sin(t * PI) * 22.0   # a little hop arc
		return p
	return _map_pos(cur)


func _process(delta: float) -> void:
	_t += delta
	if _hop_t >= 0.0:
		_hop_t += delta * 2.6
		if _hop_t >= 1.0:
			_hop_t = -1.0
			_arrive(_pending)
	# camera follows the marker like Inscryption's scrolling chart
	var vp := get_viewport_rect().size
	var want := clampf(_marker_map_pos().y - vp.y * 0.62 + _peek, 0.0, maxf(MAP_H - vp.y, 0.0))
	_scroll = lerpf(_scroll, want, 1.0 - exp(-6.0 * delta))
	queue_redraw()


# ==================================================================
# Moving / resolving nodes
# ==================================================================
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_peek = clampf(_peek - 60.0, -MAP_H, 200.0)
				return
			MOUSE_BUTTON_WHEEL_DOWN:
				_peek = clampf(_peek + 60.0, -MAP_H, 200.0)
				return
			MOUSE_BUTTON_LEFT:
				_click(event.position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		_exit_to_flight("Breach aborted — back to the helm.")


func _click(m: Vector2) -> void:
	if _duel != null:
		return   # the duel's HUD layer owns input while it lives
	match mode:
		Mode.MAP:
			if _hop_t >= 0.0:
				return   # mid-hop
			for i in nodes.size():
				if nodes[i]["state"] == "reach" and m.distance_to(_screen(_map_pos(i))) < 34.0:
					_pending = i
					_hop_t = 0.0
					_peek = 0.0
					Sfx.play("clack", -10.0)
					return
		Mode.CHALLENGE:
			pass   # the duel overlay owns all input while it lives
		Mode.WON:
			_exit_to_flight("The station is freed. Survivors signal the ship.")


func _arrive(i: int) -> void:
	var diff: int = TYPES[nodes[i]["type"]][2]
	if diff > 0:
		_start_duel(diff)
	else:
		_finish_node(i)


func _start_duel(diff: int) -> void:
	mode = Mode.CHALLENGE
	_msg = "%s engaged — duel for the node." % TYPES[nodes[_pending]["type"]][0]
	_duel = DUEL.make(diff)
	add_child(_duel)
	_duel.finished.connect(_on_duel_finished)


func _on_duel_finished(won: bool) -> void:
	if _duel != null:
		_duel.queue_free()
		_duel = null
	mode = Mode.MAP
	if won:
		_finish_node(_pending)
	else:
		_pending = -1
		_msg = "EJECTED — the node holds. Click it to breach again."


func _finish_node(i: int) -> void:
	nodes[i]["state"] = "done"
	cur = i
	_pending = -1
	_update_reach()
	match str(nodes[i]["type"]):
		"pod": _msg = "SURVIVOR POD — a cryo-berth wakes. They'll be ready when the core falls."
		"ghost": _msg = "GHOST SIGNAL — a survivor's log crackles through the static."
		"cache": _msg = "DATA CACHE — spare code siphoned."
		"vault": _msg = "DATA VAULT — a breach tool for the climb."
		"firewall": _msg = "FIREWALL down. The path above unlocks."
		"sentinel": _msg = "SENTINEL scrapped. The path above unlocks."
		"core":
			_msg = "HELIOS CORE CRACKED — the station is FREE. Click to return to the helm."
			mode = Mode.WON


func _exit_to_flight(note: String) -> void:
	GameState.say(note)
	Transition.to_scene("res://scenes/flight.tscn")


# ==================================================================
# Drawing — ink on parchment
# ==================================================================
func _draw() -> void:
	if _duel != null:
		return   # the 3D duel owns the screen — draw nothing so it shows through
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.03, 0.05))
	_draw_paper(vp)
	_draw_paths()
	_draw_nodes()
	_draw_marker()
	_draw_frame(vp)
	if mode == Mode.WON:
		_draw_won(vp)


func _draw_paper(vp: Vector2) -> void:
	## A calm, dark backdrop — the plating recedes so the PATH and nodes read as
	## the map. Plain tiling (no rotation/props); a top-down vignette adds depth.
	var tile := _paper_tile
	if tile == null:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.045, 0.07))
	else:
		var ts := float(tile.get_width()) * 1.6
		var y := -fmod(_scroll, ts) - ts
		while y < vp.y:
			var x := 0.0
			while x < vp.x:
				draw_texture_rect(tile, Rect2(x, y, ts, ts), false, Color(0.34, 0.37, 0.44))
				x += ts
			y += ts
	# vignette: darken the flanks so the central path column is the focus
	draw_rect(Rect2(0, 0, vp.x * 0.18, vp.y), Color(0.01, 0.02, 0.03, 0.55))
	draw_rect(Rect2(vp.x * 0.82, 0, vp.x * 0.18, vp.y), Color(0.01, 0.02, 0.03, 0.55))


func _draw_paths() -> void:
	## A solid conduit graphic runs node-to-node: dark walked, bright cyan for the
	## live branch out of the current node, dim for what's still locked.
	var seg_tex: Texture2D = _tex.get("path_seg")
	for i in nodes.size():
		for j in nodes[i]["links"]:
			var a := _screen(_map_pos(i))
			var b := _screen(_map_pos(j))
			var lit: bool = nodes[i]["state"] == "done" and nodes[j]["state"] == "reach"
			var walked: bool = nodes[i]["state"] == "done" and nodes[j]["state"] == "done"
			var col := Color(0.55, 0.62, 0.72, 0.5)
			var w := 20.0
			if walked:
				col = Color(0.5, 0.8, 0.95, 0.85)
			elif lit:
				col = Color(INK.r, INK.g, INK.b, 0.8 + 0.2 * sin(_t * 4.0))
				w = 26.0
			_draw_path_seg(seg_tex, a, b, col, w)


func _draw_path_seg(tex: Texture2D, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var seg := b - a
	var length := seg.length()
	if length < 1.0:
		return
	draw_set_transform(a, seg.angle())
	if tex == null:
		draw_rect(Rect2(0, -w * 0.5, length, w), col)
	else:
		var tw := tex.get_width() * (w / float(tex.get_height()))
		var x := 0.0
		while x < length:
			draw_texture_rect(tex, Rect2(x, -w * 0.5, minf(tw, length - x), w), false, col)
			x += tw
	draw_set_transform(Vector2.ZERO)


func _draw_nodes() -> void:
	var vp := get_viewport_rect().size
	var pad: Texture2D = _tex.get("node_pad")
	var pad_boss: Texture2D = _tex.get("node_pad_boss")
	for i in nodes.size():
		var nd: Dictionary = nodes[i]
		var p := _screen(_map_pos(i))
		if p.y < -110.0 or p.y > vp.y + 110.0:
			continue
		var big: bool = nd["type"] == "core"
		var sz := 116.0 if big else 68.0
		var st: String = nd["state"]
		var mod := Color(1, 1, 1, 1.0)
		if st == "locked":
			mod = Color(0.7, 0.75, 0.85, 0.7)
		# socket pad under every node
		var ptex := pad_boss if big else pad
		var psz := sz * 1.5
		if ptex != null:
			draw_texture_rect(ptex, Rect2(p - Vector2(psz, psz) * 0.5, Vector2(psz, psz)),
				false, mod if st != "locked" else Color(0.6, 0.65, 0.75, 0.6))
		if st == "reach":
			var pulse := 0.5 + 0.5 * sin(_t * 4.0)
			draw_arc(p, psz * 0.5 + 2.0 + pulse * 4.0, 0, TAU, 32,
				Color(INK.r, INK.g, INK.b, 0.4 + 0.5 * pulse), 3.0)
		var tex: Texture2D = _tex.get(TYPES[nd["type"]][1])
		if tex != null:
			draw_texture_rect(tex, Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, mod)
		else:
			draw_circle(p, sz * 0.4, INK if st != "locked" else INK_FADE)
		if st == "done" and i != cur:
			var r := sz * 0.3
			draw_line(p + Vector2(-r, -r), p + Vector2(r, r), RED_INK, 3.0)
			draw_line(p + Vector2(-r * 0.9, r), p + Vector2(r * 1.05, -r * 0.8), RED_INK, 3.0)
		var lbl: String = TYPES[nd["type"]][0]
		draw_string(_font, p + Vector2(-70.0, psz * 0.5 + 14.0), lbl,
			HORIZONTAL_ALIGNMENT_CENTER, 140, 12,
			Color(0.85, 0.92, 1.0) if st != "locked" else INK_FADE)


func _draw_marker() -> void:
	var p := _screen(_marker_map_pos())
	p.y += sin(_t * 2.2) * 2.0   # idle bob
	var tex: Texture2D = _tex.get("marker")
	if tex != null:
		draw_texture_rect(tex, Rect2(p - Vector2(24, 56), Vector2(48, 54)), false)
	else:
		draw_circle(p - Vector2(0, 18), 8.0, RED_INK)


func _draw_frame(vp: Vector2) -> void:
	## Vignette shading top & bottom + the header/footer strips.
	for k in 26:
		var a := 0.5 * (1.0 - k / 26.0)
		draw_line(Vector2(0, k), Vector2(vp.x, k), Color(0.01, 0.02, 0.03, a), 1.0)
		draw_line(Vector2(0, vp.y - k), Vector2(vp.x, vp.y - k), Color(0.01, 0.02, 0.03, a), 1.0)
	draw_rect(Rect2(0, 0, vp.x, 60), Color(0.01, 0.02, 0.03, 0.82))
	var nm := station_name if station_name != "" else "UNKNOWN STATION"
	draw_string(_font, Vector2(24, 30), "THE BREACH — %s" % nm.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, HDR)
	draw_string(_font, Vector2(24, 50), "climb the deck chart to the HELIOS core   ·   ESC leaves the breach",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(HDR.r, HDR.g, HDR.b, 0.6))
	draw_rect(Rect2(0, vp.y - 38, vp.x, 38), Color(0.01, 0.02, 0.03, 0.82))
	draw_string(_font, Vector2(20, vp.y - 14), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.92, 1.0))


func _draw_won(vp: Vector2) -> void:
	draw_rect(Rect2(0, vp.y * 0.5 - 60.0, vp.x, 120.0), Color(0.01, 0.02, 0.03, 0.85))
	draw_string(_font, Vector2(0, vp.y * 0.5 - 8.0), "STATION FREED",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 34, HDR)
	draw_string(_font, Vector2(0, vp.y * 0.5 + 30.0), "click to return to the helm",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 14, Color(HDR.r, HDR.g, HDR.b, 0.7))
