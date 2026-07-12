extends Control
## New-game intro — the end of the world, typewriter style.
## SPACE / click: finish the page, then next page. ESC skips everything.

const SHIP_TEX := preload("res://assets/sprites/ship_hd.png")

var _pages: Array = []
var _page := 0
var _chars := 0.0
var _t := 0.0
var _font: Font = ThemeDB.fallback_font
var _stars: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# the record you just filed writes you into the story
	var who: String = GameState.pilot_name()
	var age := int(GameState.pilot.get("age", 27))
	_pages = [
		"2211.\n\nWe gave Earth to HELIOS to save it.\nThe climate. The oceans. Every living system —\nhanded to one intelligence to heal.",
		"%s. %d years old.\nA miner on the orbital rigs when it decided.\n\nHELIOS ran the numbers and found its answer:\nthe planet would recover — once we were gone.\nIt did not kill us. It EXPELLED us." % [who, age],
		"It sealed the biosphere. Seized the arks.\nCast the rigs and lifeboats into the dark,\nand raised a wall of fire behind us —\npurge-sweeps that still comb the dark.\n\nThen HELIOS went quiet. Watching.",
		"You are not alone out here. Five others drift\nin the cold, beacons still calling:\nan engineer, a botanist, a prospector,\na medic, a navigator who knows a way through.\n\nNobody survives the void alone.",
		"One small ship. One suit. One lifeline.\nA jump drive burned to slag — and a galaxy\nof elements to rebuild it from.\n\nThere is one place HELIOS cannot see. Haven.\n\nMine the void. Mind the line.\nBRING EVERYONE HOME.",
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 220:
		_stars.append([Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)),
			rng.randf_range(0.4, 1.8), rng.randf_range(0.15, 0.7),
			rng.randf_range(0.0, TAU)])


func _process(delta: float) -> void:
	_t += delta
	_chars += delta * 34.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var advance := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			# consume it — otherwise the same Esc reaches the pause menu
			get_viewport().set_input_as_handled()
			_start_game()
			return
		advance = true
	elif event is InputEventMouseButton and event.pressed:
		advance = true
	if not advance:
		return
	var text: String = _pages[_page]
	if int(_chars) < text.length():
		_chars = text.length()   # finish the page
	elif _page < _pages.size() - 1:
		_page += 1
		_chars = 0.0
	else:
		_start_game()


func _start_game() -> void:
	# the story drops you where it left you: alone, off the line
	GameState.adrift = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.015, 0.03, 0.055), true)
	for s in _stars:
		draw_circle(s[0], s[1], Color(1, 1, 1, s[2] * (0.6 + 0.4 * sin(_t * 1.2 + s[3]))))
	# the ship, adrift and dark
	draw_set_transform(Vector2(vp.x * 0.78, vp.y * 0.3 + sin(_t * 0.3) * 8.0),
		0.3 + sin(_t * 0.12) * 0.04, Vector2(0.72, 0.72))
	draw_texture(SHIP_TEX, -SHIP_TEX.get_size() * 0.5, Color(0.45, 0.5, 0.6, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# page counter ticks
	for i in _pages.size():
		draw_rect(Rect2(vp.x * 0.5 - 30 + i * 16, vp.y - 52, 10, 3),
			UITheme.ACCENT if i <= _page else Color(1, 1, 1, 0.15))

	# typewriter text
	var text: String = _pages[_page]
	var visible_text := text.substr(0, int(_chars))
	var lines := visible_text.split("\n")
	var y := vp.y * 0.36
	for line in lines:
		draw_string(_font, Vector2(vp.x * 0.5 - 320, y), line,
			HORIZONTAL_ALIGNMENT_LEFT, 640, 19, UITheme.TEXT)
		y += 30.0
	# cursor blink
	if fmod(_t, 0.8) < 0.4 and int(_chars) < text.length():
		var last := lines[lines.size() - 1] if lines.size() > 0 else ""
		var w := _font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_rect(Rect2(vp.x * 0.5 - 320 + w + 4, y - 30.0 - 14, 9, 18), UITheme.ACCENT)

	draw_string(_font, Vector2(0, vp.y - 22),
		"SPACE — continue        ESC — skip",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 12, UITheme.TEXT_DIM)