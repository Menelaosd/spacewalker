extends Node2D
## The inside of the ship — a base-building canvas. An 8x4 grid masked to
## the hull silhouette (bow right, like the exterior). Six core rooms sit
## amidships; the rest is bare hull under a dark overlay with a visible
## grid. Walk to the edge of the built ship and press E on a glowing bay
## to expand into it (plain rooms for now — purposes come later).

const INTERACT_RADIUS := 60.0
const GEAR_PANEL := preload("res://scripts/gear_panel.gd")
const INVENTORY_SCREEN := preload("res://scripts/inventory_screen.gd")

const CELL_W := 130.0
const CELL_H := 110.0
const ORIGIN := Vector2(-520, -220)   # grid top-left (8x4 cells)

@onready var crew: Node2D = $Crew

var _font: Font = ThemeDB.fallback_font
var _stations: Array = []
var _active: int = -1
var _reactor := 0.0
var _win_stars: Array = []

# interior HUD
var _banked_label: Label
var _room_label: Label
var _prompt_label: Label
var _msg_label: Label
var _msg_tween: Tween


# ------------------------------------------------------------------
# Grid helpers
# ------------------------------------------------------------------
func cell_rect(cell: int) -> Rect2:
	var col := cell % GameState.SHIP_COLS
	var row := int(float(cell) / GameState.SHIP_COLS)
	return Rect2(ORIGIN + Vector2(col * CELL_W, row * CELL_H), Vector2(CELL_W, CELL_H))


func cell_at(p: Vector2) -> int:
	var rel := p - ORIGIN
	if rel.x < 0.0 or rel.y < 0.0:
		return -1
	var col := int(rel.x / CELL_W)
	var row := int(rel.y / CELL_H)
	if col >= GameState.SHIP_COLS or row >= GameState.SHIP_ROWS:
		return -1
	return row * GameState.SHIP_COLS + col


func _built(cell: int) -> bool:
	return GameState.rooms.has(cell)


func _is_walkable(p: Vector2) -> bool:
	return _built(cell_at(p))


func _find_cell(type: String) -> int:
	for cell in GameState.rooms:
		if GameState.rooms[cell] == type:
			return cell
	return GameState.rooms.keys()[0] if GameState.rooms.size() > 0 else 0


# ------------------------------------------------------------------
func _ready() -> void:
	_define_stations()
	_make_window_stars()

	crew.walk_check = _is_walkable

	GameState.refill_oxygen(GameState.max_oxygen)
	_build_hud()
	GameState.notify.connect(_on_notify)

	if GameState.wake_on_bunk:
		GameState.wake_on_bunk = false
		crew.position = cell_rect(_find_cell("quarters")).get_center() + Vector2(-14, 8)
		if GameState.last_lost > 0:
			GameState.say("You black out... and wake in your bunk. The %d ore you carried is gone." %
				GameState.last_lost)
		else:
			GameState.say("You black out... and wake in your bunk. The lifeline reeled you home.")
		GameState.last_lost = 0
	else:
		crew.position = cell_rect(_find_cell("airlock")).get_center() + Vector2(-24, 0)
		GameState.say("Inside the ship. Glowing bays at the hull edge can be built out.")

	GameState.save_game()


func _define_stations() -> void:
	_stations = []
	for cell in GameState.rooms:
		var c := cell_rect(cell).get_center()
		match GameState.rooms[cell]:
			"upgrade":
				_stations.append({"pos": c + Vector2(-40, 16), "kind": "o2"})
				_stations.append({"pos": c + Vector2(0, 16), "kind": "tether"})
				_stations.append({"pos": c + Vector2(40, 16), "kind": "laser"})
			"bridge":
				_stations.append({"pos": c + Vector2(-10, 10), "kind": "cockpit"})
			"airlock":
				_stations.append({"pos": c + Vector2(20, 10), "kind": "exit"})
	# expansion bays: bare hull cells touching the built ship — station
	# sits just inside the built neighbor, at the shared edge
	for cell in GameState.SHIP_COLS * GameState.SHIP_ROWS:
		if _built(cell) or not GameState.cell_in_hull(cell):
			continue
		for n in GameState.cell_neighbors(cell):
			if _built(n):
				var edge := (cell_rect(cell).get_center() + cell_rect(n).get_center()) * 0.5
				var inward := (cell_rect(n).get_center() - edge).normalized()
				_stations.append({"pos": edge + inward * 26.0, "kind": "expand", "cell": cell})
				break


func _make_window_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var r := cell_rect(_find_cell("bridge"))
	for i in 20:
		_win_stars.append([
			Vector2(rng.randf_range(r.end.x - 22, r.end.x - 6),
				rng.randf_range(r.position.y + 22, r.end.y - 10)),
			rng.randf_range(0.5, 1.3),
			rng.randf_range(0.3, 0.9),
		])


func _process(delta: float) -> void:
	_reactor += delta
	_update_active_station()
	_room_label.text = _room_at(crew.position)
	_banked_label.text = "BANKED ORE   %d" % GameState.banked
	if _active >= 0:
		_prompt_label.text = _station_label(_stations[_active])
		_prompt_label.modulate.a = 0.95
	else:
		_prompt_label.modulate.a = 0.0
	queue_redraw()


func _update_active_station() -> void:
	_active = -1
	var best := INTERACT_RADIUS
	for i in _stations.size():
		var d: float = crew.position.distance_to(_stations[i]["pos"])
		if d < best:
			best = d
			_active = i


func _station_label(st: Dictionary) -> String:
	match st["kind"]:
		"o2":
			return "E    Upgrade O2 Tank   (%d ore)" % GameState.upgrade_cost("o2")
		"tether":
			return "E    Upgrade Lifeline   (%d ore)" % GameState.upgrade_cost("tether")
		"laser":
			return "E    Upgrade Laser   (%d ore)" % GameState.upgrade_cost("laser")
		"cockpit":
			return "E    Take the helm — explore space"
		"exit":
			return "E    Suit up & spacewalk"
		"expand":
			return "E    Expand the ship   (%d ore)" % int(GameState.ROOM_TYPES["room"]["cost"])
	return ""


func _room_at(p: Vector2) -> String:
	var cell := cell_at(p)
	if _built(cell):
		return str(GameState.ROOM_TYPES[GameState.rooms[cell]]["name"]).to_upper()
	return "—"


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _active < 0 or event.physical_keycode != KEY_E:
		return
	_interact(_stations[_active])


func _interact(st: Dictionary) -> void:
	match st["kind"]:
		"expand":
			var cost: int = GameState.ROOM_TYPES["room"]["cost"]
			if GameState.build_room(st["cell"], "room"):
				GameState.say("Hull section built out. What it becomes is up to you — later.")
				_define_stations()
			else:
				GameState.say("Can't build — need %d ore (have %d)." % [cost, GameState.banked])
		"exit":
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		"cockpit":
			get_tree().change_scene_to_file("res://scenes/flight.tscn")
		"o2", "tether", "laser":
			var kind: String = st["kind"]
			var cost := GameState.upgrade_cost(kind)
			if GameState.try_upgrade(kind):
				match kind:
					"o2":
						GameState.say("O2 tank upgraded — capacity now %d." % int(GameState.max_oxygen))
					"tether":
						GameState.say("Lifeline extended — reach now %dm." % int(GameState.tether_length))
					"laser":
						GameState.say("Laser tuned — power now %d." % int(GameState.laser_dps))
			else:
				GameState.say("Not enough ore — need %d, have %d." % [cost, GameState.banked])


# ==================================================================
# Interior HUD
# ==================================================================
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.make_theme()
	layer.add_child(root)
	root.add_child(preload("res://scripts/screen_fx.gd").new())
	root.add_child(INVENTORY_SCREEN.new())

	var info := PanelContainer.new()
	info.position = Vector2(18, 18)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info)
	_banked_label = Label.new()
	info.add_child(_banked_label)

	var gear := GEAR_PANEL.new()
	root.add_child(gear)
	gear.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 18)

	_room_label = Label.new()
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.modulate = Color(0.55, 0.9, 1.0, 0.55)
	root.add_child(_room_label)
	_room_label.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 16)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.modulate = Color(0.6, 0.9, 1.0, 0.0)
	root.add_child(_prompt_label)
	_prompt_label.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 110)

	_msg_label = Label.new()
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.modulate.a = 0.0
	root.add_child(_msg_label)
	_msg_label.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 70)

	var hint := Label.new()
	hint.text = "WASD walk · E interact / expand · I inventory · Esc menu"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.4)
	root.add_child(hint)
	hint.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)


func _on_notify(text: String) -> void:
	_msg_label.text = text
	if _msg_tween:
		_msg_tween.kill()
	_msg_label.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(2.2)
	_msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.8)


# ==================================================================
# Visuals — hull silhouette, grid, rooms, walls, doors, stations
# ==================================================================
func _draw() -> void:
	var total := GameState.SHIP_COLS * GameState.SHIP_ROWS
	# hull silhouette backdrop (grown dark plates under everything)
	for cell in total:
		if GameState.cell_in_hull(cell):
			draw_rect(cell_rect(cell).grow(10.0), Color(0.055, 0.065, 0.09), true)
	# bare hull cells: dark overlay + the visible build grid
	for cell in total:
		if not GameState.cell_in_hull(cell) or _built(cell):
			continue
		var r := cell_rect(cell)
		draw_rect(r, Color(0.045, 0.055, 0.08), true)
		# grid lines
		draw_rect(r, Color(0.55, 0.9, 1.0, 0.07), false, 1.0)
		draw_line(r.position + Vector2(CELL_W * 0.5, 4), r.position + Vector2(CELL_W * 0.5, CELL_H - 4),
			Color(0.55, 0.9, 1.0, 0.035), 1.0)
		draw_line(r.position + Vector2(4, CELL_H * 0.5), r.position + Vector2(CELL_W - 4, CELL_H * 0.5),
			Color(0.55, 0.9, 1.0, 0.035), 1.0)
		# structural cross-brace
		draw_line(r.position + Vector2(8, 8), r.end - Vector2(8, 8), Color(1, 1, 1, 0.02), 1.0)
		draw_line(Vector2(r.end.x - 8, r.position.y + 8), Vector2(r.position.x + 8, r.end.y - 8),
			Color(1, 1, 1, 0.02), 1.0)
	# built rooms
	for cell in GameState.rooms:
		_draw_room_cell(cell)
	# hull outer walls: edges between hull and space
	for cell in total:
		if not GameState.cell_in_hull(cell):
			continue
		var r := cell_rect(cell)
		var col := cell % GameState.SHIP_COLS
		var row := int(float(cell) / GameState.SHIP_COLS)
		var edges := [
			[Vector2(col - 1, row), r.position, r.position + Vector2(0, CELL_H)],
			[Vector2(col + 1, row), r.position + Vector2(CELL_W, 0), r.end],
			[Vector2(col, row - 1), r.position, r.position + Vector2(CELL_W, 0)],
			[Vector2(col, row + 1), r.position + Vector2(0, CELL_H), r.end],
		]
		for e in edges:
			var np: Vector2 = e[0]
			var outside := np.x < 0 or np.y < 0 or np.x >= GameState.SHIP_COLS \
				or np.y >= GameState.SHIP_ROWS \
				or not GameState.cell_in_hull(int(np.y) * GameState.SHIP_COLS + int(np.x))
			if outside:
				draw_line(e[1], e[2], Color(0.42, 0.46, 0.55), 5.0)
				draw_line(e[1], e[2], Color(0.16, 0.18, 0.24), 2.0)
	# doorways between built neighbours
	for cell in GameState.rooms:
		for n in GameState.cell_neighbors(cell):
			if n > cell and _built(n):
				var mid := (cell_rect(cell).get_center() + cell_rect(n).get_center()) * 0.5
				var horizontal := absi(n - cell) == 1
				var dir := Vector2(0, 1) if horizontal else Vector2(1, 0)
				draw_line(mid - dir * 16.0, mid + dir * 16.0, Color(0.17, 0.19, 0.24), 6.0)
				draw_rect(Rect2(mid - dir * 20.0 - Vector2(2, 2), Vector2(4, 4)),
					Color(0.55, 0.9, 1.0, 0.6))
				draw_rect(Rect2(mid + dir * 16.0 - Vector2(2, 2) + dir * 2.0, Vector2(4, 4)),
					Color(0.55, 0.9, 1.0, 0.6))
	_draw_stations()


func _draw_room_cell(cell: int) -> void:
	var rect := cell_rect(cell)
	var type: String = GameState.rooms[cell]
	var info: Dictionary = GameState.ROOM_TYPES[type]
	draw_rect(rect, info["floor"], true)
	_draw_floor_grid(rect)
	draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.42,
		Color(0.85, 0.92, 1.0, 0.03))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6)), Color(0, 0, 0, 0.2))
	draw_rect(rect, Color(0.30, 0.34, 0.42), false, 1.5)
	draw_string(_font, rect.position + Vector2(8, 17), str(info["name"]).to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.9, 1.0, 0.4))
	_draw_furniture(type, rect)


func _draw_floor_grid(rect: Rect2) -> void:
	var x := rect.position.x + 26.0
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y + 2), Vector2(x, rect.end.y - 2),
			Color(1, 1, 1, 0.03), 1.0)
		x += 26.0
	var y := rect.position.y + 26.0
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x + 2, y), Vector2(rect.end.x - 2, y),
			Color(1, 1, 1, 0.03), 1.0)
		y += 26.0


func _draw_furniture(type: String, r: Rect2) -> void:
	var c := r.get_center()
	match type:
		"quarters":
			draw_rect(Rect2(r.position.x + 10, r.position.y + 26, 62, 30), Color(0.28, 0.3, 0.38))
			draw_rect(Rect2(r.position.x + 10, r.position.y + 26, 18, 30), Color(0.85, 0.86, 0.9))
			draw_rect(Rect2(r.position.x + 12, r.position.y + 50, 58, 4), Color(0.2, 0.55, 0.75))
			draw_rect(Rect2(r.end.x - 34, r.position.y + 24, 22, 40), Color(0.22, 0.25, 0.32))
			draw_rect(Rect2(r.end.x - 27, r.position.y + 38, 3, 7), Color(0.7, 0.75, 0.85))
		"upgrade":
			draw_rect(Rect2(r.position.x + 10, r.end.y - 24, 50, 10), Color(0.24, 0.27, 0.34))
			for i in 3:
				draw_circle(Vector2(r.position.x + 18 + i * 14, r.end.y - 19), 2.5,
					Color(0.55, 0.9, 1.0, 0.4))
		"bridge":
			draw_rect(Rect2(r.end.x - 24, r.position.y + 18, 18, r.size.y - 30),
				Color(0.04, 0.06, 0.12))
			for s in _win_stars:
				draw_circle(s[0], s[1], Color(1, 1, 1, s[2]))
			draw_rect(Rect2(r.end.x - 24, r.position.y + 18, 18, r.size.y - 30),
				Color(0.4, 0.44, 0.52), false, 2.0)
			draw_rect(Rect2(r.position.x + 10, r.position.y + 22, 66, 14), Color(0.24, 0.3, 0.4))
			for i in 4:
				var led_on := sin(_reactor * (1.3 + float(i) * 0.7) + float(i) * 2.1) > 0.0
				draw_rect(Rect2(r.position.x + 15 + i * 15, r.position.y + 26, 7, 4),
					Color(0.4, 0.95, 0.6, 0.8) if led_on else Color(0.9, 0.4, 0.3, 0.8))
			draw_circle(c + Vector2(-10, 10), 10.0, Color(0.3, 0.33, 0.4))
		"engine":
			var pulse := 0.5 + 0.5 * sin(_reactor * 3.0)
			draw_circle(c, 28.0, Color(0.12, 0.10, 0.09))
			for i in 10:
				var a0 := TAU * float(i) / 10.0
				draw_arc(c, 28.0, a0, a0 + TAU / 20.0, 5, Color(0.9, 0.7, 0.1, 0.5), 3.0)
			draw_circle(c, 22.0, Color(1.0, 0.5, 0.1, 0.12 + 0.10 * pulse))
			draw_circle(c, 13.0, Color(1.0, 0.55, 0.2, 0.5 + 0.4 * pulse))
			draw_circle(c, 6.0, Color(1.0, 0.85, 0.5, 0.7 + 0.3 * pulse))
		"cargo":
			var crates: int = clampi(int(GameState.banked / 3.0), 0, 9)
			for i in crates:
				var col := i % 3
				var row := int(float(i) / 3.0)
				var cp := Vector2(r.position.x + 14 + col * 22, r.end.y - 14 - row * 22)
				draw_rect(Rect2(cp.x, cp.y - 18, 18, 18), Color(0.55, 0.42, 0.2))
				draw_rect(Rect2(cp.x, cp.y - 18, 18, 18), Color(0, 0, 0, 0.3), false, 1.5)
			if crates == 0:
				draw_string(_font, r.position + Vector2(12, r.size.y - 18), "LOADING ZONE",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.75, 0.2, 0.3))
		"airlock":
			draw_circle(c + Vector2(20, 10), 22.0, Color(0.18, 0.2, 0.26))
			draw_circle(c + Vector2(20, 10), 22.0, Color(0.7, 0.75, 0.85), false, 3.0)
			for i in 4:
				var a := TAU * float(i) / 4.0 + 0.4
				draw_line(c + Vector2(20, 10), c + Vector2(20, 10) + Vector2.from_angle(a) * 22.0,
					Color(0.9, 0.7, 0.1, 0.5), 3.0)
			draw_circle(c + Vector2(20, 10), 5.0, Color(0.45, 0.5, 0.6))
		"room":
			draw_rect(Rect2(r.position.x + 12, r.end.y - 36, 18, 18), Color(0.32, 0.34, 0.4))
			draw_rect(Rect2(r.position.x + 12, r.end.y - 36, 18, 18), Color(0, 0, 0, 0.3), false, 1.5)
			var lp := c + Vector2(22, -10)
			draw_line(lp, lp + Vector2(0, 22), Color(0.4, 0.44, 0.52), 3.0)
			draw_circle(lp, 4.0, Color(1.0, 0.95, 0.8, 0.9))
			draw_circle(lp, 18.0, Color(1.0, 0.95, 0.8, 0.06))
		"greenhouse":
			for i in 5:
				var px := r.position.x + 18.0 + i * 20.0
				var sway := sin(_reactor * 1.5 + float(i)) * 1.5
				draw_circle(Vector2(px + sway, c.y), 5.0, Color(0.3, 0.75, 0.35))
				draw_circle(Vector2(px + sway - 2, c.y - 4), 3.5, Color(0.4, 0.85, 0.45))
		"refinery":
			draw_rect(Rect2(c.x - 22, c.y - 12, 44, 30), Color(0.3, 0.28, 0.3))
			draw_rect(Rect2(c.x - 14, c.y + 2, 28, 10),
				Color(1.0, 0.5, 0.15, 0.6 + 0.4 * sin(_reactor * 4.0)))
		"gascollector":
			for i in 3:
				var tx := c.x - 30.0 + i * 24.0
				draw_rect(Rect2(tx, c.y - 20, 16, 42), Color(0.14, 0.2, 0.28))
				draw_rect(Rect2(tx, c.y - 20, 16, 42), Color(0.5, 0.6, 0.7), false, 1.5)
		"workshop":
			draw_rect(Rect2(r.position.x + 12, c.y, r.size.x - 44, 10), Color(0.35, 0.3, 0.25))
			if fmod(_reactor, 1.3) < 0.15:
				draw_circle(Vector2(c.x - 14, c.y - 4), 2.5 + randf() * 2.5,
					Color(1.0, 0.8, 0.3, 0.8))


func _draw_stations() -> void:
	for i in _stations.size():
		var st: Dictionary = _stations[i]
		var p: Vector2 = st["pos"]
		var on := (i == _active)
		match st["kind"]:
			"exit":
				continue
			"cockpit":
				if on:
					draw_circle(p, 22.0, Color(0.35, 0.8, 1.0, 0.10))
					draw_arc(p, 15.0, 0.0, TAU, 32, Color(0.35, 0.8, 1.0, 0.8), 2.0)
			"expand":
				var pulse := 0.5 + 0.5 * sin(_reactor * 2.2)
				var target := cell_rect(st["cell"])
				# glowing bay marker on the shared edge
				draw_circle(p, 9.0, Color(0.55, 0.9, 1.0, 0.10 + 0.10 * pulse))
				draw_string(_font, p + Vector2(-14, 5), "+", HORIZONTAL_ALIGNMENT_CENTER,
					28, 17, Color(0.55, 0.9, 1.0, 0.45 + 0.4 * pulse))
				if on:
					# hologram of the future room over the bay
					var afford: bool = GameState.banked >= int(GameState.ROOM_TYPES["room"]["cost"])
					var holo := Color(0.55, 0.9, 1.0, 0.10 + 0.06 * pulse) if afford \
						else Color(1.0, 0.4, 0.3, 0.08 + 0.05 * pulse)
					draw_rect(target.grow(-6.0), holo, true)
					draw_rect(target.grow(-6.0), Color(holo.r, holo.g, holo.b, 0.55), false, 1.5)
			_:
				var glow := Color(0.35, 0.8, 1.0, 0.9) if on else Color(0.3, 0.5, 0.7, 0.7)
				draw_rect(Rect2(p.x - 12, p.y - 4, 24, 18), Color(0.22, 0.25, 0.32))
				draw_rect(Rect2(p.x - 12, p.y - 20, 24, 16), Color(0.12, 0.16, 0.22))
				draw_rect(Rect2(p.x - 12, p.y - 20, 24, 16), glow, false, 2.0)
				match st["kind"]:
					"o2":
						draw_circle(p + Vector2(0, -12), 4.0, Color(0.35, 0.8, 1.0, 0.9))
					"tether":
						draw_circle(p + Vector2(0, -12), 4.0, Color(1.0, 0.85, 0.3, 0.9))
					"laser":
						draw_circle(p + Vector2(0, -12), 4.0, Color(1.0, 0.4, 0.3, 0.9))
				if on:
					draw_circle(p + Vector2(0, 4), 34.0, Color(0.35, 0.8, 1.0, 0.06))