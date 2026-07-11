extends Node2D
## Piloting mode — take the helm and fly the ship through infinite space.
## Space is generated in deterministic chunks (same coordinates always hold
## the same stars and asteroid fields), and fields get richer with distance
## from home. Park near a field (E) to move your dive site there, then
## spacewalk it. Q hands back the helm and returns inside.
## All visuals are placeholder _draw() shapes.

const THRUST := 560.0
const THRUST_REV := 260.0
const TURN_RATE := 2.6          # rad/s — A/D yaw
const MAX_SPEED := 720.0
const DAMP := 0.45
const STAR_CHUNK := 640.0
const FIELD_CHUNK := 1600.0
const PARK_REACH := 140.0        # extra reach beyond a field's radius
const HOME_DOCK_RADIUS := 300.0
const SCOOP_RATE := 0.4          # gas units per second inside a nebula
const INVENTORY_SCREEN := preload("res://scripts/inventory_screen.gd")

@onready var cam: Camera2D = $Camera

var ship_pos := Vector2.ZERO
var vel := Vector2.ZERO
var heading := 0.0
var _thr := 0.0     # -1..1  W forward / S reverse
var _turn := 0.0    # -1..1  A / D

var _field_cache := {}
var _near_field: Dictionary = {}
var _near_home := false
var _scooping := false
var _font: Font = ThemeDB.fallback_font

var _pos_label: Label
var _cargo_label: Label
var _prompt_label: Label
var _msg_label: Label
var _msg_tween: Tween


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR   # painted hull, not pixel art
	ship_pos = GameState.sector
	cam.position = ship_pos
	cam.reset_smoothing()
	_build_hud()
	GameState.notify.connect(_on_notify)
	GameState.say("You have the helm. Fields get richer the farther you fly.")


func _process(delta: float) -> void:
	# helm controls: A/D yaw the ship, W burns the main drive, S retro-burns
	_turn = Input.get_axis("move_left", "move_right")
	_thr = Input.get_axis("move_down", "move_up")
	heading += _turn * TURN_RATE * delta
	if absf(_thr) > 0.01:
		var power := THRUST if _thr > 0.0 else THRUST_REV
		vel += Vector2.from_angle(heading) * _thr * power * delta
	vel = vel.limit_length(MAX_SPEED)
	vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-DAMP * delta))
	ship_pos += vel * delta
	cam.position = ship_pos

	_near_home = ship_pos.length() < HOME_DOCK_RADIUS
	_near_field = _find_near_field()

	# nebula flying scoops gas into the tanks — the only source of H/He & co
	_scooping = bool(GameState.region_at(ship_pos)["nebula"])
	if _scooping:
		GameState.scoop_gas(SCOOP_RATE * delta)

	_update_hud()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_E:
			if _near_home:
				GameState.sector = Vector2.ZERO
				GameState.save_game()
				GameState.say("Docked at home.")
				get_tree().change_scene_to_file("res://scenes/main.tscn")
			elif not _near_field.is_empty():
				GameState.sector = _near_field["center"]
				GameState.save_game()
				GameState.say("Parked at the field. Suit up and mine.")
				get_tree().change_scene_to_file("res://scenes/main.tscn")
		KEY_Q:
			# hold position out here; the airlock can spacewalk this spot too
			GameState.sector = ship_pos
			get_tree().change_scene_to_file("res://scenes/ship_interior.tscn")


# ==================================================================
# Deterministic chunked space
# ==================================================================
func _chunk_seed(cx: int, cy: int, salt: int) -> int:
	return (cx * 73856093) ^ (cy * 19349663) ^ (salt * 83492791)


func _field_in_chunk(cx: int, cy: int) -> Dictionary:
	var key := Vector2i(cx, cy)
	if _field_cache.has(key):
		return _field_cache[key]
	if _field_cache.size() > 512:
		_field_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(cx, cy, 1)
	var field := {}
	var origin := Vector2(cx, cy) * FIELD_CHUNK
	# the region plan decides how likely, big and rich fields are here
	var region := GameState.region_at(origin + Vector2.ONE * FIELD_CHUNK * 0.5)
	# the home chunk stays clear — that's where the dock lives
	if not (cx == 0 and cy == 0) and rng.randf() < float(region["chance"]):
		var center := origin + Vector2(
			rng.randf_range(FIELD_CHUNK * 0.2, FIELD_CHUNK * 0.8),
			rng.randf_range(FIELD_CHUNK * 0.2, FIELD_CHUNK * 0.8))
		var radius: float = rng.randf_range(170.0, 300.0) * float(region["size"])
		var rich: float = GameState.richness_at(center)
		var rocks: Array = []
		for i in rng.randi_range(6, 13):
			rocks.append({
				"off": Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.15, 0.85),
				"r": rng.randf_range(9.0, 24.0) * float(region["size"]),
				"rich": rng.randf() < rich,
			})
		field = {"center": center, "radius": radius, "rich": rich,
			"rocks": rocks, "tint": region["tint"]}
	_field_cache[key] = field
	return field


func _find_near_field() -> Dictionary:
	var cc := Vector2i((ship_pos / FIELD_CHUNK).floor())
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var f := _field_in_chunk(cc.x + dx, cc.y + dy)
			if f.is_empty():
				continue
			if ship_pos.distance_to(f["center"]) < f["radius"] + PARK_REACH:
				return f
	return {}


# ==================================================================
# HUD
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

	var nav := PanelContainer.new()
	nav.position = Vector2(18, 18)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nav)
	var box := VBoxContainer.new()
	nav.add_child(box)
	_pos_label = Label.new()
	box.add_child(_pos_label)
	_cargo_label = Label.new()
	_cargo_label.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_cargo_label)

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
	hint.text = "W/S thrust · A/D turn · E park / dock · Q leave the helm · Esc menu"
	hint.modulate = Color(1, 1, 1, 0.55)
	root.add_child(hint)
	hint.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)


func _update_hud() -> void:
	var km := ship_pos.length() / 100.0
	var region_name: String = GameState.region_at(ship_pos)["name"]
	_pos_label.text = "%s   ·   Sector (%d, %d)   ·   Home %.1f km" % [
		region_name.to_upper(), int(ship_pos.x / 100.0), int(ship_pos.y / 100.0), km]
	_cargo_label.text = "Banked ore: %d" % GameState.banked
	if _near_home:
		_prompt_label.text = "E    Dock at home"
		_prompt_label.modulate.a = 0.95
	elif not _near_field.is_empty():
		_prompt_label.text = "E    Park & spacewalk this field  (~%d%% rich)" % int(
			_near_field["rich"] * 100.0)
		_prompt_label.modulate.a = 0.95
	elif _scooping:
		_prompt_label.text = "◌  Scooping nebula gas — H %s · He %s" % [
			Elements.fmt(GameState.elements.get("H", 0.0)),
			Elements.fmt(GameState.elements.get("He", 0.0))]
		_prompt_label.modulate.a = 0.75
	else:
		_prompt_label.modulate.a = 0.0


func _on_notify(text: String) -> void:
	_msg_label.text = text
	if _msg_tween:
		_msg_tween.kill()
	_msg_label.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(2.2)
	_msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.8)


# ==================================================================
# Placeholder visuals
# ==================================================================
func _draw() -> void:
	var center := cam.get_screen_center_position()
	var half := get_viewport_rect().size * 0.5 + Vector2(STAR_CHUNK, STAR_CHUNK)
	_draw_nebulae(center, half)
	_draw_stars(center, half)
	_draw_fields(center, half)
	_draw_home()
	_draw_home_compass()
	_draw_ship()


func _draw_nebulae(center: Vector2, half: Vector2) -> void:
	## Soft dust clouds behind everything — visible from far off, so they
	## work as landmarks you can steer by.
	for i in GameState.NEBULAE.size():
		var nc: Vector2 = GameState.nebula_center(i)
		if (nc - center).length() > half.length() + GameState.NEBULA_RADIUS + 900.0:
			continue
		var col: Color = GameState.NEBULAE[i]["color"]
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + i
		draw_circle(nc, GameState.NEBULA_RADIUS * 0.95, Color(col.r, col.g, col.b, 0.035))
		for b in 8:
			var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, GameState.NEBULA_RADIUS * 0.65)
			draw_circle(nc + off, rng.randf_range(450.0, 1200.0),
				Color(col.r, col.g, col.b, rng.randf_range(0.03, 0.06)))


func _draw_stars(center: Vector2, half: Vector2) -> void:
	for cy in range(floori((center.y - half.y) / STAR_CHUNK), floori((center.y + half.y) / STAR_CHUNK) + 1):
		for cx in range(floori((center.x - half.x) / STAR_CHUNK), floori((center.x + half.x) / STAR_CHUNK) + 1):
			var rng := RandomNumberGenerator.new()
			rng.seed = _chunk_seed(cx, cy, 2)
			for i in 13:
				var p := Vector2(cx, cy) * STAR_CHUNK + Vector2(rng.randf(), rng.randf()) * STAR_CHUNK
				draw_circle(p, rng.randf_range(0.6, 2.0),
					Color(1, 1, 1, rng.randf_range(0.25, 0.85)))


func _draw_fields(center: Vector2, half: Vector2) -> void:
	var pad := half + Vector2(400, 400)
	for cy in range(floori((center.y - pad.y) / FIELD_CHUNK), floori((center.y + pad.y) / FIELD_CHUNK) + 1):
		for cx in range(floori((center.x - pad.x) / FIELD_CHUNK), floori((center.x + pad.x) / FIELD_CHUNK) + 1):
			var f := _field_in_chunk(cx, cy)
			if f.is_empty():
				continue
			var fc: Vector2 = f["center"]
			var base := Color(0.42, 0.4, 0.38)
			if f["tint"] != null:
				base = base.lerp(f["tint"], 0.3)
			for rock in f["rocks"]:
				var p: Vector2 = fc + rock["off"]
				var r: float = rock["r"]
				draw_circle(p, r, base)
				draw_circle(p + Vector2(r * 0.3, -r * 0.2), r * 0.35, base.darkened(0.25))
				var fleck := Color(0.4, 0.95, 1.0) if rock["rich"] else Color(1.0, 0.72, 0.25)
				draw_circle(p + Vector2(-r * 0.25, r * 0.2), 2.5, fleck)
			if not _near_field.is_empty() and _near_field["center"] == fc:
				draw_arc(fc, f["radius"] + PARK_REACH, 0.0, TAU, 64,
					Color(0.35, 0.8, 1.0, 0.25), 2.0)


func _draw_home() -> void:
	draw_arc(Vector2.ZERO, HOME_DOCK_RADIUS, 0.0, TAU, 64,
		Color(0.3, 0.8, 1.0, 0.15), 2.0)
	# mini home station
	var hull := Color(0.55, 0.58, 0.66)
	draw_rect(Rect2(-26, -14, 52, 28), hull)
	draw_circle(Vector2(-26, 0), 14.0, hull)
	draw_circle(Vector2(26, 0), 14.0, hull)
	draw_rect(Rect2(-26, -3, 52, 6), Color(0.9, 0.45, 0.15))
	draw_string(_font, Vector2(-24, -HOME_DOCK_RADIUS - 10), "HOME",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.9, 1.0, 0.6))


func _draw_home_compass() -> void:
	if ship_pos.length() < 600.0:
		return
	var dir := -ship_pos.normalized()
	var base := ship_pos + dir * 84.0
	var side := dir.orthogonal() * 6.0
	draw_colored_polygon(
		PackedVector2Array([base + dir * 14.0, base + side, base - side]),
		Color(1.0, 0.85, 0.3, 0.7))
	draw_string(_font, base + dir * 26.0 + Vector2(-18, 4),
		"%.1f km" % (ship_pos.length() / 100.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.85, 0.3, 0.55))


## The captain's ship, bow facing +X (see tools/process_ship_art.gd).
const SHIP_TEX := preload("res://assets/sprites/ship_hd.png")
const SHIP_SCALE := 0.5


func _draw_ship() -> void:
	# engine effects in ship space (unscaled world px)
	draw_set_transform(ship_pos, heading, Vector2.ONE)
	if _thr > 0.05:
		# twin main drives on the broad stern towers
		var flick := randf() * 9.0
		for ey in [-21.0, 21.0]:
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(-66, ey - 6), Vector2(-66, ey + 6),
					Vector2(-88.0 - flick, ey)]),
				Color(0.4, 0.85, 1.0, 0.85))
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(-66, ey - 3), Vector2(-66, ey + 3),
					Vector2(-78.0 - flick * 0.5, ey)]),
				Color(0.9, 0.98, 1.0, 0.9))
	elif _thr < -0.05:
		# bow retro jets, braking / backing up
		for ey in [-10.0, 10.0]:
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(66, ey - 3), Vector2(66, ey + 3),
					Vector2(80.0 + randf() * 5.0, ey)]),
				Color(0.4, 0.85, 1.0, 0.7))
	if absf(_turn) > 0.05:
		# the wingtip turbine on the pushing side fires during a yaw —
		# the wings sit aft of midship on this hull
		var wy := -66.0 if _turn > 0.0 else 66.0
		draw_circle(Vector2(-26, wy), 4.5 + randf() * 2.5,
			Color(0.4, 0.85, 1.0, 0.7))
		draw_circle(Vector2(-26, wy), 8.0, Color(0.4, 0.85, 1.0, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# painted hull, rotated toward the heading
	draw_set_transform(ship_pos, heading, Vector2(SHIP_SCALE, SHIP_SCALE))
	draw_texture(SHIP_TEX, -SHIP_TEX.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
