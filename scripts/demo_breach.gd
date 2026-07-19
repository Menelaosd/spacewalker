extends Control
## DELETABLE DEMO — the HELIOS firewall-breach roguelike.
##   MAP  : a Slay-the-Spire intrusion map — climb the station node-by-node,
##          choosing your path from the ACCESS PORT up to the HELIOS CORE.
##   BREACH: at a combat node, a Deus-Ex trace-race — capture nodes cyan while
##          HELIOS's amber trace spreads back toward your entry. Beat it to take
##          the node; if the trace reaches your entry you're ejected.
## Run: godot res://scenes/demo_breach.tscn   (delete scenes/demo_breach.* to remove)

enum Mode { MAP, BREACH, WON, LOST }
var mode: int = Mode.MAP
var _t := 0.0
var _font: Font = ThemeDB.fallback_font
var _msg := "Route your breach up to the HELIOS core. Click a lit node."

const CYAN := Color(0.35, 0.85, 1.0)
const AMBER := Color(0.95, 0.55, 0.15)
const GREEN := Color(0.45, 1.0, 0.6)
const PURPLE := Color(0.75, 0.55, 1.0)
const RED := Color(1.0, 0.35, 0.3)

# ---- MAP ----
const ROWS := 7
# type -> [label, color, combat_difficulty(0=none)]
const TYPES := {
	"access":  ["ACCESS", CYAN, 0], "firewall": ["FIREWALL", CYAN, 1],
	"sentinel": ["SENTINEL", AMBER, 2], "pod": ["SURVIVOR POD", GREEN, 0],
	"cache": ["CACHE", AMBER, 0], "ghost": ["GHOST SIGNAL", PURPLE, 0],
	"vault": ["DATA VAULT", CYAN, 0], "core": ["HELIOS CORE", RED, 3],
}
var nodes: Array = []     # {row,col,ncol,type,links:Array,state}
var cur := -1
var _breach_node := -1

# ---- BREACH (trace-race grid) ----
var BR := 4
var BC := 6
var cell: Array = []      # owner: 0 none / 1 you / 2 helios
var b_entry := 0
var b_target := 0
var b_trace_t := 0.0
var b_diff := 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gen_map()
	if OS.get_environment("SW_BREACH") != "":
		_start_breach(2)   # jump straight into a breach for the screenshot
	if OS.get_environment("SW_SHOT") != "":
		await get_tree().create_timer(0.6).timeout
		if is_inside_tree():
			get_viewport().get_texture().get_image().save_png(OS.get_environment("SW_SHOT"))
			get_tree().quit()


func _pick_type(row: int) -> String:
	if row == 0:
		return "access"
	if row == ROWS - 1:
		return "core"
	if row == ROWS - 2:
		return "pod"        # always patch before the boss
	if row == 3:
		return "vault"      # a guaranteed tool mid-run
	var roll := randf()
	if roll < 0.42: return "firewall"
	if roll < 0.60: return "sentinel"
	if roll < 0.74: return "cache"
	if roll < 0.88: return "ghost"
	return "pod"


func _gen_map() -> void:
	nodes = []
	var rc: Array = []
	for r in ROWS:
		rc.append(1 if (r == 0 or r == ROWS - 1) else (2 + (r % 3)))
	var idx := {}
	for r in ROWS:
		for c in rc[r]:
			idx[Vector2i(r, c)] = nodes.size()
			nodes.append({"row": r, "col": c, "ncol": rc[r],
				"type": _pick_type(r), "links": [], "state": "locked"})
	for i in nodes.size():
		var nd: Dictionary = nodes[i]
		var r: int = nd["row"]
		if r == ROWS - 1:
			continue
		var nn: int = rc[r + 1]
		var frac: float = (nd["col"] + 0.5) / float(nd["ncol"])
		var tc := clampi(int(frac * nn), 0, nn - 1)
		var targets := [tc]
		if randf() < 0.45:
			targets.append(clampi(tc + (1 if randf() < 0.5 else -1), 0, nn - 1))
		for c in targets:
			var j: int = idx[Vector2i(r + 1, c)]
			if not nd["links"].has(j):
				nd["links"].append(j)
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


func _node_pos(i: int) -> Vector2:
	var nd: Dictionary = nodes[i]
	var vp := get_viewport_rect().size
	var y: float = vp.y - 80.0 - nd["row"] * ((vp.y - 200.0) / (ROWS - 1))
	var span := vp.x * 0.7
	var x: float = vp.x * 0.5 + (nd["col"] - (nd["ncol"] - 1) * 0.5) * (span / maxf(nd["ncol"], 1))
	return Vector2(x, y)


func _enter_node(i: int) -> void:
	var t: String = nodes[i]["type"]
	var diff: int = TYPES[t][2]
	if diff > 0:
		_breach_node = i
		_start_breach(diff)
	else:
		_finish_node(i)


func _finish_node(i: int) -> void:
	var t: String = nodes[i]["type"]
	nodes[i]["state"] = "done"
	cur = i
	_update_reach()
	match t:
		"pod": _msg = "SURVIVOR POD — a cryo-berth wakes. Integrity patched."
		"cache": _msg = "CACHE — data siphoned. (spend it on tools)"
		"ghost": _msg = "GHOST SIGNAL — a survivor's log flickers in the dark."
		"vault": _msg = "DATA VAULT — breach tool acquired."
		"core": _msg = "HELIOS CORE CRACKED — the station is FREE. Survivors aboard."
	if t == "core":
		mode = Mode.WON


func _start_breach(diff: int) -> void:
	mode = Mode.BREACH
	b_diff = diff
	BC = 5 + diff
	BR = 4
	cell = []
	for _i in BR * BC:
		cell.append(0)
	b_entry = (BR - 1) * BC + BC / 2       # bottom-centre
	b_target = 0 + BC / 2                    # top-centre
	cell[b_entry] = 1
	cell[0] = 2                              # HELIOS trace source, top-left
	b_trace_t = 0.0
	_msg = "BREACH — capture the green core before HELIOS's trace reaches your port."


func _bi(r: int, c: int) -> int:
	return r * BC + c


func _b_adj(i: int) -> Array:
	var r := i / BC
	var c := i % BC
	var out := []
	if r > 0: out.append(_bi(r - 1, c))
	if r < BR - 1: out.append(_bi(r + 1, c))
	if c > 0: out.append(_bi(r, c - 1))
	if c < BC - 1: out.append(_bi(r, c + 1))
	return out


func _b_next_to(i: int, owner: int) -> bool:
	for j in _b_adj(i):
		if cell[j] == owner:
			return true
	return false


func _breach_tick(delta: float) -> void:
	b_trace_t += delta
	var interval := 1.6 - b_diff * 0.28
	if b_trace_t >= interval:
		b_trace_t = 0.0
		# spread the trace to one un-owned node adjacent to a helios node
		var opts := []
		for i in cell.size():
			if cell[i] == 0 and _b_next_to(i, 2):
				opts.append(i)
		if opts.size() > 0:
			cell[opts[int(randf() * opts.size()) % opts.size()]] = 2
		if cell[b_entry] == 2:
			mode = Mode.LOST
			_msg = "TRACE REACHED YOUR PORT — ejected. (the map re-seeds; survivors kept)"


func _process(delta: float) -> void:
	_t += delta
	if mode == Mode.BREACH:
		_breach_tick(delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var m: Vector2 = event.position
	if mode == Mode.MAP:
		for i in nodes.size():
			if nodes[i]["state"] == "reach" and m.distance_to(_node_pos(i)) < 28.0:
				_enter_node(i)
				return
	elif mode == Mode.BREACH:
		var g := _breach_cell_at(m)
		if g >= 0 and cell[g] == 0 and _b_next_to(g, 1):
			cell[g] = 1
			if g == b_target:
				_msg = "CORE CAPTURED — node breached."
				mode = Mode.MAP
				_finish_node(_breach_node)
	elif mode == Mode.WON or mode == Mode.LOST:
		if mode == Mode.LOST:
			mode = Mode.MAP
			_start_breach(b_diff)   # retry the node fresh
		else:
			_gen_map()
			mode = Mode.MAP


func _breach_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var w := minf(vp.x - 200.0, 900.0)
	var h := minf(vp.y - 220.0, 520.0)
	return Rect2((vp.x - w) * 0.5, 130.0, w, h)


func _breach_cell_at(m: Vector2) -> int:
	var rct := _breach_rect()
	var cw := rct.size.x / BC
	var ch := rct.size.y / BR
	if not rct.has_point(m):
		return -1
	var c := int((m.x - rct.position.x) / cw)
	var r := int((m.y - rct.position.y) / ch)
	return _bi(clampi(r, 0, BR - 1), clampi(c, 0, BC - 1))


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.05, 0.08))
	# scanlines
	for y in range(0, int(vp.y), 4):
		draw_line(Vector2(0, y), Vector2(vp.x, y), Color(0.4, 0.7, 0.9, 0.02), 1.0)
	if mode == Mode.MAP:
		_draw_map(vp)
	else:
		_draw_breach(vp)
	# banner
	draw_rect(Rect2(0, vp.y - 40, vp.x, 40), Color(0.02, 0.04, 0.07, 0.85))
	draw_string(_font, Vector2(20, vp.y - 15), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CYAN)
	draw_string(_font, Vector2(20, 28),
		"HELIOS FIREWALL BREACH — %s" % ("INTRUSION MAP" if mode == Mode.MAP else ("BREACH (tier %d)" % b_diff)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.9, 1.0))


func _draw_map(vp: Vector2) -> void:
	# edges
	for i in nodes.size():
		for j in nodes[i]["links"]:
			var a := _node_pos(i)
			var b := _node_pos(j)
			var lit: bool = nodes[i]["state"] == "done" and nodes[j]["state"] == "reach"
			draw_line(a, b, Color(0.4, 0.7, 0.9, 0.7 if lit else 0.18), 3.0 if lit else 1.5)
	# nodes
	for i in nodes.size():
		var nd: Dictionary = nodes[i]
		var p := _node_pos(i)
		var col: Color = TYPES[nd["type"]][1]
		var st: String = nd["state"]
		var r := 22.0 if nd["type"] == "core" else 17.0
		if st == "done":
			draw_circle(p, r, Color(col.r, col.g, col.b, 0.9))
			draw_circle(p, r * 0.5, Color(0.03, 0.05, 0.08))
		elif st == "reach":
			var pulse := 0.5 + 0.5 * sin(_t * 4.0)
			draw_arc(p, r + 4.0 + pulse * 3.0, 0, TAU, 24, Color(col.r, col.g, col.b, 0.6), 2.0)
			draw_circle(p, r, Color(col.r, col.g, col.b, 0.85))
		else:
			draw_circle(p, r, Color(col.r, col.g, col.b, 0.22))
			draw_arc(p, r, 0, TAU, 24, Color(col.r, col.g, col.b, 0.4), 1.5)
		# type glyph label under node
		draw_string(_font, Vector2(p.x - 46, p.y + r + 14), TYPES[nd["type"]][0],
			HORIZONTAL_ALIGNMENT_CENTER, 92, 10, Color(col.r, col.g, col.b, 0.85 if st != "locked" else 0.4))
	# you-are-here
	draw_string(_font, _node_pos(cur) + Vector2(-10, 5), "◉", HORIZONTAL_ALIGNMENT_CENTER, 20, 16, Color(1, 1, 1))


func _draw_breach(vp: Vector2) -> void:
	var rct := _breach_rect()
	var cw := rct.size.x / BC
	var ch := rct.size.y / BR
	# edges between orthogonal neighbours
	for i in cell.size():
		for j in _b_adj(i):
			if j > i:
				var a := rct.position + Vector2((i % BC + 0.5) * cw, (i / BC + 0.5) * ch)
				var b := rct.position + Vector2((j % BC + 0.5) * cw, (j / BC + 0.5) * ch)
				draw_line(a, b, Color(0.4, 0.6, 0.8, 0.25), 2.0)
	for i in cell.size():
		var c := rct.position + Vector2((i % BC + 0.5) * cw, (i / BC + 0.5) * ch)
		var owner: int = cell[i]
		var col := Color(0.3, 0.4, 0.5)
		if owner == 1: col = CYAN
		elif owner == 2: col = AMBER
		if i == b_target:
			col = GREEN
			draw_arc(c, 22.0 + 3.0 * sin(_t * 5.0), 0, TAU, 24, Color(GREEN.r, GREEN.g, GREEN.b, 0.7), 2.0)
		var r := 16.0
		draw_circle(c, r, Color(col.r, col.g, col.b, 0.9 if owner != 0 else 0.35))
		if owner != 0:
			draw_circle(c, r * 0.45, Color(0.03, 0.05, 0.08))
		# highlight capturable
		if mode == Mode.BREACH and owner == 0 and _b_next_to(i, 1):
			draw_arc(c, r + 4.0, 0, TAU, 20, Color(CYAN.r, CYAN.g, CYAN.b, 0.5), 2.0)
	draw_string(_font, rct.position + Vector2(0, -10), "your port (cyan) ▸ core (green)   ·   HELIOS trace (amber) spreading",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.85, 1.0, 0.8))
