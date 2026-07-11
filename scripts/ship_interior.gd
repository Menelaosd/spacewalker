extends Node2D
## The inside of the ship — the "restaurant half" of the loop.
## Walk between rooms (WASD), stand at a station and press E:
##   Upgrade Bay  → spend banked ore on O2 / lifeline / laser
##   Airlock      → suit up and head back out on a spacewalk
## Everything is placeholder _draw() art, laid out to read like real rooms.

const INTERACT_RADIUS := 52.0
const GEAR_PANEL := preload("res://scripts/gear_panel.gd")

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
	crew.position = Vector2(220, 118)   # step in from the airlock

	# you're safe and breathing ship air inside — top the tank off
	GameState.refill_oxygen(GameState.max_oxygen)

	_build_hud()
	GameState.notify.connect(_on_notify)
	GameState.say("Inside the ship. Visit the Upgrade Bay to spend ore. Airlock to head out.")


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
	layer.add_child(root)

	_banked_label = Label.new()
	_banked_label.text = "Banked ore:  0"
	_banked_label.position = Vector2(16, 16)
	root.add_child(_banked_label)

	var gear := GEAR_PANEL.new()
	root.add_child(gear)
	gear.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)

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
	hint.text = "WASD walk · E interact · Airlock to spacewalk"
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
	# hull shell behind everything
	var shell := _bounds.grow(14.0)
	draw_rect(shell, Color(0.10, 0.12, 0.16), true)
	draw_rect(shell, Color(0.4, 0.44, 0.52), false, 4.0)

	for r in _rooms:
		_draw_room(r)

	# corridor band linking the two room rows
	var corridor := Rect2(-360, -40, 720, 80)
	draw_rect(corridor, Color(0.19, 0.21, 0.26), true)
	draw_line(Vector2(-360, -40), Vector2(360, -40), Color(0, 0, 0, 0.25), 2.0)
	draw_line(Vector2(-360, 40), Vector2(360, 40), Color(0, 0, 0, 0.25), 2.0)

	_draw_furniture()
	_draw_stations()


func _draw_room(r: Dictionary) -> void:
	var rect: Rect2 = r["rect"]
	draw_rect(rect, r["floor"], true)
	draw_rect(rect, Color(0.32, 0.36, 0.44), false, 2.0)
	# room name, small, top-left inside
	draw_string(_font, rect.position + Vector2(8, 18), r["name"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.35))


func _draw_furniture() -> void:
	# --- Quarters: a bunk ---
	draw_rect(Rect2(-345, -110, 90, 40), Color(0.28, 0.3, 0.38))
	draw_rect(Rect2(-345, -110, 26, 40), Color(0.85, 0.86, 0.9))  # pillow

	# --- Bridge: forward window + console + chair ---
	draw_rect(Rect2(298, -168, 60, 122), Color(0.04, 0.06, 0.12))  # window void
	for s in _win_stars:
		draw_circle(s[0], s[1], Color(1, 1, 1, s[2]))
	draw_rect(Rect2(120, -150, 150, 20), Color(0.24, 0.3, 0.4))    # console
	draw_circle(Vector2(150, -110), 12.0, Color(0.3, 0.33, 0.4))   # pilot chair
	draw_circle(Vector2(150, -110), 12.0, Color(0.5, 0.7, 0.9, 0.15))

	# --- Engine Room: pulsing reactor + pipes ---
	var pulse := 0.5 + 0.5 * sin(_reactor * 3.0)
	draw_circle(Vector2(-250, 105), 34.0, Color(1.0, 0.5, 0.1, 0.12 + 0.10 * pulse))
	draw_circle(Vector2(-250, 105), 20.0, Color(1.0, 0.55, 0.2, 0.5 + 0.4 * pulse))
	draw_circle(Vector2(-250, 105), 9.0, Color(1.0, 0.85, 0.5, 0.7 + 0.3 * pulse))
	draw_line(Vector2(-300, 60), Vector2(-200, 60), Color(0.4, 0.42, 0.5), 5.0)
	draw_line(Vector2(-300, 150), Vector2(-200, 150), Color(0.4, 0.42, 0.5), 5.0)

	# --- Cargo Hold: crate stack that grows with banked ore ---
	var crates: int = clampi(GameState.banked / 3, 0, 12)
	for i in crates:
		var col := i % 4
		var row := i / 4
		var cp := Vector2(-125 + col * 24, 150 - row * 24)
		draw_rect(Rect2(cp.x, cp.y - 20, 20, 20), Color(0.55, 0.42, 0.2))
		draw_rect(Rect2(cp.x, cp.y - 20, 20, 20), Color(0, 0, 0, 0.3), false, 1.5)
	if crates == 0:
		draw_string(_font, Vector2(-125, 120), "(empty)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.3))

	# --- Airlock: hatch with hazard stripes ---
	draw_circle(Vector2(300, 105), 30.0, Color(0.18, 0.2, 0.26))
	draw_circle(Vector2(300, 105), 30.0, Color(0.7, 0.75, 0.85), false, 3.0)
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		draw_line(Vector2(300, 105), Vector2(300, 105) + Vector2.from_angle(a) * 30.0,
			Color(0.9, 0.7, 0.1, 0.5), 3.0)


func _draw_stations() -> void:
	for i in _stations.size():
		var st: Dictionary = _stations[i]
		var p: Vector2 = st["pos"]
		var on := (i == _active)
		if st["kind"] == "exit":
			continue  # the airlock hatch itself is the marker
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
