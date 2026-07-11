extends Node2D
## The inside of the ship — the "restaurant half" of the loop.
## Walk between rooms (WASD), stand at a station and press E:
##   Upgrade Bay  → spend banked ore on O2 / lifeline / laser
##   Airlock      → suit up and head back out on a spacewalk
## Everything is placeholder _draw() art, laid out to read like real rooms.

const INTERACT_RADIUS := 52.0
const GEAR_PANEL := preload("res://scripts/gear_panel.gd")
const INVENTORY_SCREEN := preload("res://scripts/inventory_screen.gd")
const BUNK_POS := Vector2(-300, -85)

@onready var crew: Node2D = $Crew

var _font: Font = ThemeDB.fallback_font
var _bounds := Rect2(-360, -170, 720, 340)
var _rooms: Array = []
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


func _ready() -> void:
	_define_rooms()
	_define_stations()
	_make_window_stars()

	crew.bounds = _bounds

	# you're safe and breathing ship air inside — top the tank off
	GameState.refill_oxygen(GameState.max_oxygen)

	_build_hud()
	GameState.notify.connect(_on_notify)

	if GameState.wake_on_bunk:
		# fainted outside — the lifeline reeled you home, crew put you to bed
		GameState.wake_on_bunk = false
		crew.position = BUNK_POS
		if GameState.last_lost > 0:
			GameState.say("You black out... and wake in your bunk. The %d ore you carried is gone." %
				GameState.last_lost)
		else:
			GameState.say("You black out... and wake in your bunk. The lifeline reeled you home.")
		GameState.last_lost = 0
	else:
		crew.position = Vector2(220, 118)   # step in from the airlock
		GameState.say("Inside the ship. Upgrade Bay to spend ore, Bridge helm to fly, Airlock to spacewalk.")

	GameState.save_game()   # entering the ship is a safe moment — autosave


func _define_rooms() -> void:
	_rooms = [
		{"rect": Rect2(-360, -170, 220, 130), "name": "QUARTERS",    "floor": Color(0.15, 0.17, 0.23)},
		{"rect": Rect2(-140, -170, 220, 130), "name": "UPGRADE BAY", "floor": Color(0.14, 0.20, 0.25)},
		{"rect": Rect2(80, -170, 280, 130),   "name": "BRIDGE",      "floor": Color(0.13, 0.18, 0.26)},
		{"rect": Rect2(-360, 40, 220, 130),   "name": "ENGINE ROOM", "floor": Color(0.22, 0.15, 0.13)},
		{"rect": Rect2(-140, 40, 220, 130),   "name": "CARGO HOLD",  "floor": Color(0.16, 0.17, 0.21)},
		{"rect": Rect2(80, 40, 280, 130),     "name": "AIRLOCK",     "floor": Color(0.15, 0.18, 0.22)},
	]


func _define_stations() -> void:
	_stations = [
		{"pos": Vector2(-95, -70), "kind": "o2"},
		{"pos": Vector2(-30, -70), "kind": "tether"},
		{"pos": Vector2(35, -70),  "kind": "laser"},
		{"pos": Vector2(150, -110), "kind": "cockpit"},
		{"pos": Vector2(300, 105), "kind": "exit"},
	]


func _make_window_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 40:
		_win_stars.append([
			Vector2(rng.randf_range(300, 356), rng.randf_range(-165, -45)),
			rng.randf_range(0.6, 1.6),
			rng.randf_range(0.3, 0.9),
		])


func _process(delta: float) -> void:
	_reactor += delta
	_update_active_station()
	_room_label.text = _room_at(crew.position)
	_banked_label.text = "Banked ore:  %d" % GameState.banked
	if _active >= 0:
		_prompt_label.text = "E    " + _station_label(_stations[_active])
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
			return "Upgrade O2 Tank   (%d ore)" % GameState.upgrade_cost("o2")
		"tether":
			return "Upgrade Lifeline   (%d ore)" % GameState.upgrade_cost("tether")
		"laser":
			return "Upgrade Laser   (%d ore)" % GameState.upgrade_cost("laser")
		"cockpit":
			return "Take the helm — explore space"
		"exit":
			return "Suit up & spacewalk"
	return ""


func _room_at(p: Vector2) -> String:
	for r in _rooms:
		if (r["rect"] as Rect2).has_point(p):
			return r["name"]
	return "CORRIDOR"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and _active >= 0:
			_interact(_stations[_active]["kind"])


func _interact(kind: String) -> void:
	if kind == "exit":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	if kind == "cockpit":
		get_tree().change_scene_to_file("res://scenes/flight.tscn")
		return
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
# Interior HUD (built in code, like the exterior HUD)
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

	var info := PanelContainer.new()
	info.position = Vector2(18, 18)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info)
	_banked_label = Label.new()
	_banked_label.text = "Banked ore:  0"
	info.add_child(_banked_label)

	var gear := GEAR_PANEL.new()
	root.add_child(gear)
	gear.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)

	root.add_child(INVENTORY_SCREEN.new())

	_room_label = Label.new()
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.modulate = Color(1, 1, 1, 0.55)
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
	hint.text = "WASD walk · E interact · I inventory · Esc menu"
	hint.modulate = Color(1, 1, 1, 0.55)
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
# Placeholder visuals — hull, rooms, furniture, stations
# ==================================================================
func _draw() -> void:
	# hull shell behind everything, double-plated
	var shell := _bounds.grow(14.0)
	draw_rect(shell.grow(6.0), Color(0.06, 0.075, 0.10), true)
	draw_rect(shell, Color(0.10, 0.12, 0.16), true)
	draw_rect(shell, Color(0.4, 0.44, 0.52), false, 4.0)
	draw_rect(shell.grow(6.0), Color(0.25, 0.28, 0.34), false, 2.0)

	# corridor band linking the two room rows
	var corridor := Rect2(-360, -40, 720, 80)
	draw_rect(corridor, Color(0.17, 0.19, 0.24), true)
	_draw_floor_grid(corridor)
	# corridor light fixtures with soft pools
	for i in 5:
		var lx := -300.0 + i * 150.0
		var pulse := 0.8 + 0.2 * sin(_reactor * 2.2 + float(i) * 1.7)
		draw_circle(Vector2(lx, 0), 30.0, Color(0.8, 0.9, 1.0, 0.05 * pulse))
		draw_rect(Rect2(lx - 9, -2, 18, 4), Color(0.85, 0.95, 1.0, 0.55 * pulse))

	for r in _rooms:
		_draw_room(r)

	_draw_furniture()
	_draw_stations()


func _draw_floor_grid(rect: Rect2) -> void:
	## Subtle deck plating.
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


func _draw_room(r: Dictionary) -> void:
	var rect: Rect2 = r["rect"]
	draw_rect(rect, r["floor"], true)
	_draw_floor_grid(rect)
	# soft ambient light pool in the middle of the room
	draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.42,
		Color(0.85, 0.92, 1.0, 0.03))
	# wall shadow along the top edge
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7)), Color(0, 0, 0, 0.22))
	draw_rect(rect, Color(0.32, 0.36, 0.44), false, 2.0)
	# doorway facing the corridor — a lit gap in the wall
	var door_y := rect.end.y if rect.position.y < -40.0 else rect.position.y
	var cx := rect.get_center().x
	draw_rect(Rect2(cx - 20, door_y - 3, 40, 6), Color(0.17, 0.19, 0.24))
	draw_rect(Rect2(cx - 22, door_y - 2, 4, 4), Color(0.55, 0.9, 1.0, 0.6))
	draw_rect(Rect2(cx + 18, door_y - 2, 4, 4), Color(0.55, 0.9, 1.0, 0.6))
	# room name, small, top-left inside
	draw_string(_font, rect.position + Vector2(9, 19), r["name"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.9, 1.0, 0.4))


func _draw_furniture() -> void:
	# --- Quarters: bunk, locker, wall poster ---
	draw_rect(Rect2(-345, -110, 90, 40), Color(0.28, 0.3, 0.38))
	draw_rect(Rect2(-345, -110, 90, 40), Color(0, 0, 0, 0.3), false, 1.5)
	draw_rect(Rect2(-345, -110, 26, 40), Color(0.85, 0.86, 0.9))  # pillow
	draw_rect(Rect2(-343, -78, 86, 6), Color(0.2, 0.55, 0.75))    # blanket edge
	draw_rect(Rect2(-230, -158, 30, 52), Color(0.22, 0.25, 0.32)) # locker
	draw_rect(Rect2(-230, -158, 30, 52), Color(0, 0, 0, 0.35), false, 1.5)
	draw_line(Vector2(-215, -152), Vector2(-215, -112), Color(0, 0, 0, 0.4), 1.5)
	draw_rect(Rect2(-219, -136, 3, 8), Color(0.7, 0.75, 0.85))    # handle
	draw_rect(Rect2(-300, -160, 34, 24), Color(0.3, 0.5, 0.7, 0.5))  # poster
	draw_circle(Vector2(-283, -148), 7.0, Color(0.9, 0.7, 0.3, 0.6)) # ...of a sun

	# --- Bridge: forward star window, console row with live LEDs, chair ---
	draw_rect(Rect2(298, -168, 60, 122), Color(0.04, 0.06, 0.12))
	for s in _win_stars:
		draw_circle(s[0], s[1], Color(1, 1, 1, s[2]))
	draw_rect(Rect2(298, -168, 60, 122), Color(0.4, 0.44, 0.52), false, 2.0)
	draw_rect(Rect2(120, -150, 150, 20), Color(0.24, 0.3, 0.4))
	draw_rect(Rect2(120, -150, 150, 20), Color(0, 0, 0, 0.3), false, 1.5)
	for i in 6:
		var led_on := sin(_reactor * (1.3 + float(i) * 0.7) + float(i) * 2.1) > 0.0
		var led_col := Color(0.4, 0.95, 0.6) if led_on else Color(0.9, 0.4, 0.3)
		draw_rect(Rect2(129 + i * 23, -145, 9, 5), Color(led_col.r, led_col.g, led_col.b, 0.8))
	draw_rect(Rect2(132, -144, 40, 12), Color(0.35, 0.8, 1.0, 0.10 + 0.05 * sin(_reactor * 3.0)))
	draw_circle(Vector2(150, -110), 12.0, Color(0.3, 0.33, 0.4))
	draw_circle(Vector2(150, -110), 12.0, Color(0.5, 0.7, 0.9, 0.15))

	# --- Engine Room: reactor in a hazard ring, pipes, wall gauge ---
	var pulse := 0.5 + 0.5 * sin(_reactor * 3.0)
	# hazard ring around the reactor pit
	draw_circle(Vector2(-250, 105), 42.0, Color(0.12, 0.10, 0.09))
	for i in 12:
		var a0 := TAU * float(i) / 12.0
		draw_arc(Vector2(-250, 105), 42.0, a0, a0 + TAU / 24.0, 6,
			Color(0.9, 0.7, 0.1, 0.5), 3.0)
	draw_circle(Vector2(-250, 105), 34.0, Color(1.0, 0.5, 0.1, 0.12 + 0.10 * pulse))
	draw_circle(Vector2(-250, 105), 20.0, Color(1.0, 0.55, 0.2, 0.5 + 0.4 * pulse))
	draw_circle(Vector2(-250, 105), 9.0, Color(1.0, 0.85, 0.5, 0.7 + 0.3 * pulse))
	draw_line(Vector2(-300, 60), Vector2(-200, 60), Color(0.4, 0.42, 0.5), 5.0)
	draw_line(Vector2(-300, 150), Vector2(-200, 150), Color(0.4, 0.42, 0.5), 5.0)
	draw_line(Vector2(-300, 60), Vector2(-300, 150), Color(0.4, 0.42, 0.5), 5.0)
	# wall gauge with a nervous needle
	draw_circle(Vector2(-180, 70), 11.0, Color(0.16, 0.18, 0.24))
	draw_circle(Vector2(-180, 70), 11.0, Color(0.5, 0.55, 0.65), false, 1.5)
	var needle := -PI * 0.75 + (0.6 + 0.15 * sin(_reactor * 5.0)) * PI
	draw_line(Vector2(-180, 70),
		Vector2(-180, 70) + Vector2.from_angle(needle) * 8.0,
		Color(1.0, 0.6, 0.2), 1.6)

	# --- Cargo Hold: marked loading zone + crate stack from banked ore ---
	var zone := Rect2(-132, 100, 110, 62)
	var dash := zone.position.x
	while dash < zone.end.x:   # dashed yellow floor marking
		draw_line(Vector2(dash, zone.position.y), Vector2(minf(dash + 8, zone.end.x), zone.position.y),
			Color(0.9, 0.75, 0.2, 0.4), 2.0)
		draw_line(Vector2(dash, zone.end.y), Vector2(minf(dash + 8, zone.end.x), zone.end.y),
			Color(0.9, 0.75, 0.2, 0.4), 2.0)
		dash += 14.0
	var crates: int = clampi(int(GameState.banked / 3.0), 0, 12)
	for i in crates:
		var col := i % 4
		var row := int(float(i) / 4.0)
		var cp := Vector2(-125 + col * 24, 150 - row * 24)
		draw_rect(Rect2(cp.x, cp.y - 20, 20, 20), Color(0.55, 0.42, 0.2))
		draw_rect(Rect2(cp.x, cp.y - 20, 20, 20), Color(0, 0, 0, 0.3), false, 1.5)
		draw_line(cp + Vector2(3, -10), cp + Vector2(17, -10), Color(0, 0, 0, 0.25), 1.0)
	if crates == 0:
		draw_string(_font, Vector2(-122, 135), "LOADING ZONE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.75, 0.2, 0.3))

	# --- Airlock: hatch, hazard chevrons pointing the way out ---
	for i in 3:
		var chx := 230.0 + float(i) * 18.0
		draw_polyline(PackedVector2Array([
			Vector2(chx, 90), Vector2(chx + 10, 105), Vector2(chx, 120)]),
			Color(0.9, 0.7, 0.1, 0.30 + 0.25 * sin(_reactor * 2.5 - float(i))), 3.0)
	draw_circle(Vector2(300, 105), 30.0, Color(0.18, 0.2, 0.26))
	draw_circle(Vector2(300, 105), 30.0, Color(0.7, 0.75, 0.85), false, 3.0)
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		draw_line(Vector2(300, 105), Vector2(300, 105) + Vector2.from_angle(a) * 30.0,
			Color(0.9, 0.7, 0.1, 0.5), 3.0)
	draw_circle(Vector2(300, 105), 6.0, Color(0.45, 0.5, 0.6))  # hatch wheel hub


func _draw_stations() -> void:
	for i in _stations.size():
		var st: Dictionary = _stations[i]
		var p: Vector2 = st["pos"]
		var on := (i == _active)
		if st["kind"] == "exit":
			continue  # the airlock hatch itself is the marker
		if st["kind"] == "cockpit":
			# the pilot chair is the marker; just glow when in reach
			if on:
				draw_circle(p, 26.0, Color(0.35, 0.8, 1.0, 0.10))
				draw_arc(p, 18.0, 0.0, TAU, 32, Color(0.35, 0.8, 1.0, 0.8), 2.0)
			continue
		# upgrade console: a small terminal on a base
		var glow := Color(0.35, 0.8, 1.0, 0.9) if on else Color(0.3, 0.5, 0.7, 0.7)
		draw_rect(Rect2(p.x - 14, p.y - 4, 28, 22), Color(0.22, 0.25, 0.32))  # base
		draw_rect(Rect2(p.x - 14, p.y - 22, 28, 18), Color(0.12, 0.16, 0.22)) # screen
		draw_rect(Rect2(p.x - 14, p.y - 22, 28, 18), glow, false, 2.0)
		# icon hint per station
		match st["kind"]:
			"o2":
				draw_circle(p + Vector2(0, -13), 5.0, Color(0.35, 0.8, 1.0, 0.9))
			"tether":
				draw_circle(p + Vector2(0, -13), 5.0, Color(1.0, 0.85, 0.3, 0.9))
			"laser":
				draw_circle(p + Vector2(0, -13), 5.0, Color(1.0, 0.4, 0.3, 0.9))
		if on:
			draw_circle(p + Vector2(0, 6), 40.0, Color(0.35, 0.8, 1.0, 0.06))
