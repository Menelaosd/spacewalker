extends Node2D
## The inside of the ship — now a modular 4x2 room grid. Six rooms come
## prefixed; empty cells can be BUILT with ore (greenhouse, refinery, gas
## collector, workshop — each with a real effect). Walk (WASD), E to
## interact, number keys to choose what to build at an empty bay.
## All visuals are placeholder _draw() shapes on the room grid.

const INTERACT_RADIUS := 56.0
const GEAR_PANEL := preload("res://scripts/gear_panel.gd")
const INVENTORY_SCREEN := preload("res://scripts/inventory_screen.gd")

const COLS := 4
const CELL_W := 180.0
const CELL_H := 130.0
const TOP_Y := -172.0
const BOT_Y := 28.0          # corridor spans [-42, 28]

@onready var crew: Node2D = $Crew

var _font: Font = ThemeDB.fallback_font
var _bounds := Rect2(-360, -172, 720, 330)
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


func cell_rect(i: int) -> Rect2:
	var col := i % COLS
	var row := int(float(i) / COLS)
	return Rect2(-360.0 + col * CELL_W, TOP_Y if row == 0 else BOT_Y, CELL_W, CELL_H)


func _ready() -> void:
	_define_stations()
	_make_window_stars()

	crew.bounds = _bounds.grow(-16.0)

	# you're safe and breathing ship air inside — top the tank off
	GameState.refill_oxygen(GameState.max_oxygen)

	_build_hud()
	GameState.notify.connect(_on_notify)

	if GameState.wake_on_bunk:
		GameState.wake_on_bunk = false
		crew.position = cell_rect(_find_cell("quarters")).get_center() + Vector2(-20, 10)
		if GameState.last_lost > 0:
			GameState.say("You black out... and wake in your bunk. The %d ore you carried is gone." %
				GameState.last_lost)
		else:
			GameState.say("You black out... and wake in your bunk. The lifeline reeled you home.")
		GameState.last_lost = 0
	else:
		crew.position = cell_rect(_find_cell("airlock")).get_center() + Vector2(-40, 0)
		GameState.say("Inside the ship. Hazard-taped bays can be built into new rooms.")

	GameState.save_game()   # entering the ship is a safe moment — autosave


func _find_cell(type: String) -> int:
	for cell in GameState.rooms:
		if GameState.rooms[cell] == type:
			return cell
	return 0


func _define_stations() -> void:
	_stations = []
	for cell in GameState.rooms:
		var r := cell_rect(cell)
		var c := r.get_center()
		match GameState.rooms[cell]:
			"upgrade":
				_stations.append({"pos": c + Vector2(-52, 14), "kind": "o2"})
				_stations.append({"pos": c + Vector2(0, 14), "kind": "tether"})
				_stations.append({"pos": c + Vector2(52, 14), "kind": "laser"})
			"bridge":
				_stations.append({"pos": c + Vector2(-14, 8), "kind": "cockpit"})
			"airlock":
				_stations.append({"pos": c + Vector2(26, 8), "kind": "exit"})
			"":
				_stations.append({"pos": c, "kind": "build", "cell": cell})


func _make_window_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var r := cell_rect(_find_cell("bridge"))
	for i in 26:
		_win_stars.append([
			Vector2(rng.randf_range(r.end.x - 26, r.end.x - 6),
				rng.randf_range(r.position.y + 24, r.end.y - 10)),
			rng.randf_range(0.5, 1.4),
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
		"build":
			return "E    Construct room   (%d ore)" % int(GameState.ROOM_TYPES["room"]["cost"])
	return ""


func _room_at(p: Vector2) -> String:
	for cell in GameState.rooms:
		if cell_rect(cell).has_point(p):
			var t: String = GameState.rooms[cell]
			if t == "":
				return "EMPTY BAY"
			return str(GameState.ROOM_TYPES[t]["name"]).to_upper()
	return "CORRIDOR"


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _active < 0 or event.physical_keycode != KEY_E:
		return
	_interact(_stations[_active])


func _interact(st: Dictionary) -> void:
	var kind: String = st["kind"]
	match kind:
		"build":
			var cost: int = GameState.ROOM_TYPES["room"]["cost"]
			if GameState.build_room(st["cell"], "room"):
				GameState.say("Room constructed. What it becomes is up to you — later.")
				_define_stations()
			else:
				GameState.say("Can't build — need %d ore (have %d)." % [cost, GameState.banked])
		"exit":
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		"cockpit":
			get_tree().change_scene_to_file("res://scenes/flight.tscn")
		"o2", "tether", "laser":
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
	hint.text = "WASD walk · E interact / build · I inventory · Esc menu"
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
# Visuals — hull, room grid, per-type furniture, stations
# ==================================================================
func _draw() -> void:
	var shell := _bounds.grow(14.0)
	draw_rect(shell.grow(6.0), Color(0.06, 0.075, 0.10), true)
	draw_rect(shell, Color(0.10, 0.12, 0.16), true)
	draw_rect(shell, Color(0.4, 0.44, 0.52), false, 4.0)
	draw_rect(shell.grow(6.0), Color(0.25, 0.28, 0.34), false, 2.0)

	# corridor
	var corridor := Rect2(-360, -42, 720, 70)
	draw_rect(corridor, Color(0.17, 0.19, 0.24), true)
	_draw_floor_grid(corridor)
	for i in 5:
		var lx := -300.0 + i * 150.0
		var pulse := 0.8 + 0.2 * sin(_reactor * 2.2 + float(i) * 1.7)
		draw_circle(Vector2(lx, -7), 30.0, Color(0.8, 0.9, 1.0, 0.05 * pulse))
		draw_rect(Rect2(lx - 9, -9, 18, 4), Color(0.85, 0.95, 1.0, 0.55 * pulse))

	for cell in GameState.rooms:
		_draw_cell(cell)
	_draw_stations()


func _draw_floor_grid(rect: Rect2) -> void:
	var x := rect.position.x + 28.0
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y + 2), Vector2(x, rect.end.y - 2),
			Color(1, 1, 1, 0.03), 1.0)
		x += 28.0
	var y := rect.position.y + 28.0
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x + 2, y), Vector2(rect.end.x - 2, y),
			Color(1, 1, 1, 0.03), 1.0)
		y += 28.0


func _draw_cell(cell: int) -> void:
	var rect := cell_rect(cell)
	var type: String = GameState.rooms[cell]
	var is_top := rect.position.y < -42.0

	if type == "":
		# empty construction bay — dark, hazard-taped, waiting
		draw_rect(rect, Color(0.07, 0.085, 0.115), true)
		var dash := rect.position.x + 10.0
		while dash < rect.end.x - 10.0:
			draw_line(Vector2(dash, rect.position.y + 8), Vector2(dash + 9, rect.position.y + 8),
				Color(0.9, 0.75, 0.2, 0.30), 2.0)
			draw_line(Vector2(dash, rect.end.y - 8), Vector2(dash + 9, rect.end.y - 8),
				Color(0.9, 0.75, 0.2, 0.30), 2.0)
			dash += 16.0
		draw_rect(rect, Color(0.32, 0.36, 0.44), false, 2.0)
		draw_string(_font, rect.position + Vector2(9, 21), "EMPTY BAY",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.75, 0.2, 0.35))
	else:
		var info: Dictionary = GameState.ROOM_TYPES[type]
		draw_rect(rect, info["floor"], true)
		_draw_floor_grid(rect)
		draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.42,
			Color(0.85, 0.92, 1.0, 0.03))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7)), Color(0, 0, 0, 0.22))
		draw_rect(rect, Color(0.32, 0.36, 0.44), false, 2.0)
		draw_string(_font, rect.position + Vector2(9, 19), str(info["name"]).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.9, 1.0, 0.4))
		_draw_furniture(type, rect)

	# doorway toward the corridor
	var door_y := rect.end.y if is_top else rect.position.y
	var cx := rect.get_center().x
	draw_rect(Rect2(cx - 20, door_y - 3, 40, 6), Color(0.17, 0.19, 0.24))
	draw_rect(Rect2(cx - 22, door_y - 2, 4, 4), Color(0.55, 0.9, 1.0, 0.6))
	draw_rect(Rect2(cx + 18, door_y - 2, 4, 4), Color(0.55, 0.9, 1.0, 0.6))


func _draw_furniture(type: String, r: Rect2) -> void:
	var c := r.get_center()
	match type:
		"quarters":
			draw_rect(Rect2(r.position.x + 12, r.position.y + 30, 76, 34), Color(0.28, 0.3, 0.38))
			draw_rect(Rect2(r.position.x + 12, r.position.y + 30, 22, 34), Color(0.85, 0.86, 0.9))
			draw_rect(Rect2(r.position.x + 14, r.position.y + 58, 72, 5), Color(0.2, 0.55, 0.75))
			draw_rect(Rect2(r.end.x - 40, r.position.y + 26, 26, 46), Color(0.22, 0.25, 0.32))
			draw_rect(Rect2(r.end.x - 31, r.position.y + 44, 3, 8), Color(0.7, 0.75, 0.85))
			draw_rect(Rect2(r.position.x + 26, r.end.y - 44, 30, 20), Color(0.3, 0.5, 0.7, 0.5))
			draw_circle(Vector2(r.position.x + 41, r.end.y - 34), 6.0, Color(0.9, 0.7, 0.3, 0.6))
		"upgrade":
			# consoles are drawn by the station pass; add a parts shelf
			draw_rect(Rect2(r.position.x + 14, r.end.y - 30, 60, 12), Color(0.24, 0.27, 0.34))
			for i in 4:
				draw_circle(Vector2(r.position.x + 22 + i * 14, r.end.y - 24), 3.0,
					Color(0.55, 0.9, 1.0, 0.4))
		"bridge":
			draw_rect(Rect2(r.end.x - 28, r.position.y + 20, 22, r.size.y - 34),
				Color(0.04, 0.06, 0.12))
			for s in _win_stars:
				draw_circle(s[0], s[1], Color(1, 1, 1, s[2]))
			draw_rect(Rect2(r.end.x - 28, r.position.y + 20, 22, r.size.y - 34),
				Color(0.4, 0.44, 0.52), false, 2.0)
			draw_rect(Rect2(r.position.x + 14, r.position.y + 26, 90, 16), Color(0.24, 0.3, 0.4))
			for i in 5:
				var led_on := sin(_reactor * (1.3 + float(i) * 0.7) + float(i) * 2.1) > 0.0
				draw_rect(Rect2(r.position.x + 20 + i * 16, r.position.y + 30, 8, 5),
					Color(0.4, 0.95, 0.6, 0.8) if led_on else Color(0.9, 0.4, 0.3, 0.8))
			draw_circle(c + Vector2(-14, 8), 11.0, Color(0.3, 0.33, 0.4))
		"engine":
			var pulse := 0.5 + 0.5 * sin(_reactor * 3.0)
			draw_circle(c, 34.0, Color(0.12, 0.10, 0.09))
			for i in 12:
				var a0 := TAU * float(i) / 12.0
				draw_arc(c, 34.0, a0, a0 + TAU / 24.0, 6, Color(0.9, 0.7, 0.1, 0.5), 3.0)
			draw_circle(c, 27.0, Color(1.0, 0.5, 0.1, 0.12 + 0.10 * pulse))
			draw_circle(c, 16.0, Color(1.0, 0.55, 0.2, 0.5 + 0.4 * pulse))
			draw_circle(c, 7.0, Color(1.0, 0.85, 0.5, 0.7 + 0.3 * pulse))
			draw_line(r.position + Vector2(12, 18), Vector2(r.end.x - 12, r.position.y + 18),
				Color(0.4, 0.42, 0.5), 5.0)
		"cargo":
			var zone := Rect2(r.position.x + 16, r.position.y + 30, r.size.x - 32, r.size.y - 46)
			var dash := zone.position.x
			while dash < zone.end.x:
				draw_line(Vector2(dash, zone.position.y), Vector2(minf(dash + 8, zone.end.x), zone.position.y),
					Color(0.9, 0.75, 0.2, 0.4), 2.0)
				draw_line(Vector2(dash, zone.end.y), Vector2(minf(dash + 8, zone.end.x), zone.end.y),
					Color(0.9, 0.75, 0.2, 0.4), 2.0)
				dash += 14.0
			var crates: int = clampi(int(GameState.banked / 3.0), 0, 12)
			for i in crates:
				var col := i % 4
				var row := int(float(i) / 4.0)
				var cp := zone.position + Vector2(6 + col * 24, zone.size.y - 6 - row * 24)
				draw_rect(Rect2(cp.x, cp.y - 20, 20, 20), Color(0.55, 0.42, 0.2))
				draw_rect(Rect2(cp.x, cp.y - 20, 20, 20), Color(0, 0, 0, 0.3), false, 1.5)
		"airlock":
			for i in 3:
				var chx := c.x - 52.0 + float(i) * 16.0
				draw_polyline(PackedVector2Array([
					Vector2(chx, c.y - 12), Vector2(chx + 9, c.y + 2), Vector2(chx, c.y + 16)]),
					Color(0.9, 0.7, 0.1, 0.30 + 0.25 * sin(_reactor * 2.5 - float(i))), 3.0)
			draw_circle(c + Vector2(26, 8), 26.0, Color(0.18, 0.2, 0.26))
			draw_circle(c + Vector2(26, 8), 26.0, Color(0.7, 0.75, 0.85), false, 3.0)
			for i in 4:
				var a := TAU * float(i) / 4.0 + 0.4
				draw_line(c + Vector2(26, 8), c + Vector2(26, 8) + Vector2.from_angle(a) * 26.0,
					Color(0.9, 0.7, 0.1, 0.5), 3.0)
			draw_circle(c + Vector2(26, 8), 5.0, Color(0.45, 0.5, 0.6))
		"greenhouse":
			for row in 2:
				var py := r.position.y + 42.0 + row * 38.0
				draw_rect(Rect2(r.position.x + 16, py, r.size.x - 32, 12), Color(0.25, 0.2, 0.15))
				for i in 6:
					var px := r.position.x + 26.0 + i * 24.0
					var sway := sin(_reactor * 1.5 + float(i) + row) * 1.5
					draw_circle(Vector2(px + sway, py - 4), 6.0, Color(0.3, 0.75, 0.35))
					draw_circle(Vector2(px + sway - 3, py - 8), 4.0, Color(0.4, 0.85, 0.45))
			draw_circle(c, 40.0, Color(0.5, 0.9, 0.5, 0.05))
		"refinery":
			draw_rect(Rect2(c.x - 30, c.y - 16, 60, 40), Color(0.3, 0.28, 0.3))
			var glow := 0.6 + 0.4 * sin(_reactor * 4.0)
			draw_rect(Rect2(c.x - 20, c.y + 2, 40, 14), Color(1.0, 0.5, 0.15, glow))
			draw_rect(Rect2(c.x - 20, c.y + 2, 40, 14), Color(1.0, 0.8, 0.4, glow * 0.5), false, 2.0)
			draw_rect(Rect2(c.x + 12, c.y - 34, 12, 20), Color(0.35, 0.33, 0.36))
			for i in 3:
				draw_rect(Rect2(c.x - 34 + i * 6, c.y + 28 - i * 5, 16, 6), Color(0.8, 0.7, 0.35))
		"gascollector":
			for i in 3:
				var tx := c.x - 40.0 + i * 34.0
				var fill := 0.3 + 0.2 * float(i) + 0.08 * sin(_reactor * 2.0 + i)
				draw_rect(Rect2(tx, c.y - 30, 22, 60), Color(0.14, 0.2, 0.28))
				draw_rect(Rect2(tx + 2, c.y + 30 - 56.0 * fill, 18, 56.0 * fill),
					Color(0.4, 0.85, 1.0, 0.5))
				draw_rect(Rect2(tx, c.y - 30, 22, 60), Color(0.5, 0.6, 0.7), false, 1.5)
			draw_line(Vector2(c.x - 40, c.y - 34), Vector2(c.x + 36, c.y - 34),
				Color(0.4, 0.42, 0.5), 4.0)
		"room":
			# freshly built, waiting for a purpose — unopened crates, a lamp
			draw_rect(Rect2(r.position.x + 18, r.end.y - 44, 22, 22), Color(0.32, 0.34, 0.4))
			draw_rect(Rect2(r.position.x + 18, r.end.y - 44, 22, 22), Color(0, 0, 0, 0.3), false, 1.5)
			draw_rect(Rect2(r.position.x + 44, r.end.y - 36, 18, 14), Color(0.28, 0.3, 0.36))
			var lp := r.get_center() + Vector2(30, -14)
			draw_line(lp, lp + Vector2(0, 26), Color(0.4, 0.44, 0.52), 3.0)
			draw_circle(lp, 5.0, Color(1.0, 0.95, 0.8, 0.9))
			draw_circle(lp, 22.0, Color(1.0, 0.95, 0.8, 0.06))
		"workshop":
			draw_rect(Rect2(r.position.x + 16, c.y - 6, r.size.x - 60, 14), Color(0.35, 0.3, 0.25))
			draw_rect(Rect2(r.position.x + 16, c.y + 8, 6, 22), Color(0.25, 0.22, 0.2))
			draw_rect(Rect2(r.end.x - 50, c.y + 8, 6, 22), Color(0.25, 0.22, 0.2))
			draw_line(Vector2(c.x - 30, c.y - 12), Vector2(c.x - 18, c.y - 22), Color(0.6, 0.65, 0.7), 3.0)
			draw_circle(Vector2(c.x + 4, c.y - 14), 4.0, Color(0.6, 0.65, 0.7))
			if fmod(_reactor, 1.3) < 0.15:
				draw_circle(Vector2(c.x - 24, c.y - 16), 3.0 + randf() * 3.0,
					Color(1.0, 0.8, 0.3, 0.8))


func _draw_stations() -> void:
	for i in _stations.size():
		var st: Dictionary = _stations[i]
		var p: Vector2 = st["pos"]
		var on := (i == _active)
		match st["kind"]:
			"exit":
				continue  # the airlock hatch itself is the marker
			"cockpit":
				if on:
					draw_circle(p, 24.0, Color(0.35, 0.8, 1.0, 0.10))
					draw_arc(p, 17.0, 0.0, TAU, 32, Color(0.35, 0.8, 1.0, 0.8), 2.0)
			"build":
				_draw_build_station(st, on)
			_:
				# upgrade console
				var glow := Color(0.35, 0.8, 1.0, 0.9) if on else Color(0.3, 0.5, 0.7, 0.7)
				draw_rect(Rect2(p.x - 14, p.y - 4, 28, 22), Color(0.22, 0.25, 0.32))
				draw_rect(Rect2(p.x - 14, p.y - 22, 28, 18), Color(0.12, 0.16, 0.22))
				draw_rect(Rect2(p.x - 14, p.y - 22, 28, 18), glow, false, 2.0)
				match st["kind"]:
					"o2":
						draw_circle(p + Vector2(0, -13), 5.0, Color(0.35, 0.8, 1.0, 0.9))
					"tether":
						draw_circle(p + Vector2(0, -13), 5.0, Color(1.0, 0.85, 0.3, 0.9))
					"laser":
						draw_circle(p + Vector2(0, -13), 5.0, Color(1.0, 0.4, 0.3, 0.9))
				if on:
					draw_circle(p + Vector2(0, 6), 40.0, Color(0.35, 0.8, 1.0, 0.06))


func _draw_build_station(st: Dictionary, on: bool) -> void:
	var p: Vector2 = st["pos"]
	var pulse := 0.5 + 0.5 * sin(_reactor * 2.0)
	# holo-pedestal
	draw_circle(p, 11.0, Color(0.55, 0.9, 1.0, 0.10 + 0.08 * pulse))
	draw_arc(p, 11.0, 0.0, TAU, 24, Color(0.55, 0.9, 1.0, 0.5), 1.5)
	draw_string(_font, p + Vector2(-20, 4), "+", HORIZONTAL_ALIGNMENT_CENTER, 40,
		20, Color(0.55, 0.9, 1.0, 0.5 + 0.4 * pulse))
	if not on:
		return
	# hologram preview of the room-to-be
	var rect := cell_rect(st["cell"])
	var afford: bool = GameState.banked >= int(GameState.ROOM_TYPES["room"]["cost"])
	var holo := Color(0.55, 0.9, 1.0, 0.10 + 0.06 * pulse) if afford \
		else Color(1.0, 0.4, 0.3, 0.08 + 0.04 * pulse)
	draw_rect(rect.grow(-8.0), holo, true)
	draw_rect(rect.grow(-8.0), Color(holo.r, holo.g, holo.b, 0.5), false, 1.5)