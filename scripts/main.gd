extends Node2D
## World scene. Spawns the ship, player, asteroid field and HUD.
## Draws the star background and the tether range ring.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SHIP_SCENE := preload("res://scenes/ship.tscn")
const ASTEROID_SCENE := preload("res://scenes/asteroid.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")

const ASTEROID_COUNT := 22

var _stars: Array = []
var ship: Node2D
var player: Node2D


func _ready() -> void:
	_make_stars()

	ship = SHIP_SCENE.instantiate()
	add_child(ship)

	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(0, 100)
	add_child(player)
	player.tether_anchor = ship.anchor_point()

	_spawn_asteroids()
	add_child(HUD_SCENE.instantiate())

	if GameState.sector == Vector2.ZERO:
		GameState.say("Welcome aboard. Hold LMB to mine. Bring ore back to the ship.")
	else:
		GameState.say("Parked in %s — rich chance ~%d%%. Watch your O2." % [
			GameState.region_at(GameState.sector)["name"],
			int(GameState.sector_richness() * 100.0)])


func _process(_delta: float) -> void:
	queue_redraw()   # parallax stars follow the camera


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and player != null and player.in_dock:
			# Step inside the ship. Bank whatever we're carrying first.
			GameState.bank_cargo()
			get_tree().change_scene_to_file("res://scenes/ship_interior.tscn")


func _make_stars() -> void:
	## Three parallax depth layers: [pos, size, alpha, depth]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for layer in [[0.25, 220, 0.4, 1.0, 0.4], [0.55, 140, 0.8, 1.7, 0.65],
			[1.0, 90, 1.2, 2.6, 1.0]]:
		for i in int(layer[1]):
			_stars.append([
				Vector2(rng.randf_range(-2600, 2600), rng.randf_range(-2600, 2600)),
				rng.randf_range(layer[2], layer[3]),
				rng.randf_range(0.25, 0.9) * float(layer[4]),
				layer[0],
			])


func _spawn_asteroids() -> void:
	# the dive field takes on the character of the region you parked in:
	# Home Reach is sparse practice rock, The Belt is a dense quarry,
	# The Expanse is few-but-huge, nebulae are tinted and crystal-heavy
	var region: Dictionary = GameState.region_at(GameState.sector)
	var rich_chance := GameState.sector_richness()
	var size_mult: float = region["size"]
	var count := 14 + int(26.0 * float(region["chance"])) \
		+ mini(int(GameState.sector.length() / 4000.0), 8)
	var base_tint := Color(0.42, 0.4, 0.38)
	if region["tint"] != null:
		base_tint = base_tint.lerp(region["tint"], 0.35)
	var placed: Array = []
	var tries := 0
	while placed.size() < count and tries < 800:
		tries += 1
		var ang := randf() * TAU
		# some asteroids sit past the tether limit — upgrade bait
		var dist := randf_range(280.0, GameState.tether_length + 320.0)
		var pos := Vector2.from_angle(ang) * dist
		var r := randf_range(18.0, 40.0) * size_mult
		var ok := true
		for p in placed:
			if pos.distance_to(p[0]) < (r + p[1] + 60.0):
				ok = false
				break
		if not ok:
			continue
		placed.append([pos, r])
		var a := ASTEROID_SCENE.instantiate()
		a.setup(r, randf() < rich_chance, base_tint)
		a.position = pos
		add_child(a)


func _draw() -> void:
	# nebula haze when parked inside one — the dive site belongs to a place
	var region: Dictionary = GameState.region_at(GameState.sector)
	if region["nebula"]:
		var col: Color = region["tint"]
		var rng := RandomNumberGenerator.new()
		rng.seed = 4321
		for i in 5:
			var off := Vector2(rng.randf_range(-900, 900), rng.randf_range(-600, 600))
			draw_circle(off, rng.randf_range(500.0, 1100.0),
				Color(col.r, col.g, col.b, rng.randf_range(0.03, 0.055)))
	# parallax: far stars track the camera, near stars sweep past
	var cam := player.global_position if player != null else Vector2.ZERO
	for s in _stars:
		draw_circle(s[0] + cam * (1.0 - s[3]), s[1], Color(1, 1, 1, s[2]))
	# faint ring showing max tether reach
	draw_arc(Vector2(0, 48), GameState.tether_length, 0.0, TAU, 96,
		Color(1.0, 0.85, 0.3, 0.08), 2.0)
