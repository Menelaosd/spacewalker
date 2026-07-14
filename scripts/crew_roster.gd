extends Control
## CREW ROSTER HUD — a top-right indicator of the five rescuable crew.
##
## Shows five circular portraits in a row. A crew you have NOT rescued shows
## DARK + grayscale; once rescued it shows in full COLOUR. A live "n / 5 crew
## rescued" readout, meant to sit in the interior's top-right corner.
##
## Instantiate and drop onto a CanvasLayer's root Control:
##     var roster = preload("res://scripts/crew_roster.gd").new()
##     hud_root.add_child(roster)
## The interior's _build_hud() wires it in; positioning here self-anchors to
## the top-right and can be fine-tuned by the caller.

# Rescue order — must match GameState.RESCUES. Keys into GameState.rescued
# are UPPERCASE; icon files are lowercase.
const CREW := ["JUNO", "MIRA", "HALE", "SOLA", "VEGA"]

const DIAM := 44.0            # circle diameter
const GAP := 9.0             # gap between circles
const MARGIN := 18.0          # inset from the screen's top-right corner
const RING := 2.0            # ring border thickness

var _color_tex := {}          # NAME -> Texture2D (rescued look)
var _bw_tex := {}             # NAME -> Texture2D (unrescued look)
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := CREW.size() * DIAM + (CREW.size() - 1) * GAP
	var h := DIAM + 16.0
	custom_minimum_size = Vector2(w, h)
	# self-position to the top-right corner; the wiring step may override the
	# offsets. Anchor both horizontal edges to the parent's right so the row
	# stays right-aligned and fully on-screen.
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -(w + MARGIN)
	offset_right = -MARGIN
	offset_top = MARGIN
	offset_bottom = MARGIN + h
	for name in CREW:
		var lower := (name as String).to_lower()
		_color_tex[name] = _load_icon(
			"res://assets/sprites/crew/roster/%s_face.png" % lower)
		_bw_tex[name] = _load_icon(
			"res://assets/sprites/crew/roster/%s_face_bw.png" % lower)


func _process(_delta: float) -> void:
	# rescued state changes rarely; five textures a frame is cheap, and this
	# keeps the readout live without wiring a signal.
	if visible:
		queue_redraw()


func refresh() -> void:
	queue_redraw()


func _load_icon(path: String) -> Texture2D:
	## Robust load: use the imported resource when available, else read the PNG
	## straight off disk (so it works before a project --import).
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res is Texture2D:
			return res
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) == OK:
		return ImageTexture.create_from_image(img)
	return null


func _rescued(name: String) -> bool:
	var gs := _game_state()
	if gs == null:
		return false
	return gs.rescued.has(name)


func _game_state() -> Object:
	# GameState is an autoload in-game; guard so the script is safe elsewhere.
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root.has_node("GameState"):
		return (loop as SceneTree).root.get_node("GameState")
	return null


func _draw() -> void:
	var count := 0
	for name in CREW:
		if _rescued(name):
			count += 1

	# tiny right-aligned caption above the row
	var cap := "CREW %d / %d" % [count, CREW.size()]
	draw_string(_font, Vector2(0, 11), cap, HORIZONTAL_ALIGNMENT_RIGHT,
		size.x, 11, Color(0.88, 0.99, 1.0, 0.55))

	var accent := Color8(74, 222, 255)             # cyan (UITheme.ACCENT)
	var y := 16.0
	for i in CREW.size():
		var name: String = CREW[i]
		var has := _rescued(name)
		var x := i * (DIAM + GAP)
		var rect := Rect2(x, y, DIAM, DIAM)
		var c := rect.get_center()
		var r := DIAM * 0.5

		# backing disc so a not-yet-loaded icon still reads as a slot
		draw_circle(c, r, Color(0.05, 0.09, 0.12, 0.85))

		var tex: Texture2D = _color_tex[name] if has else _bw_tex[name]
		if tex != null:
			draw_texture_rect(tex, rect, false)

		# ring border: bright cyan when rescued, dim when not
		var ring_col := accent if has else Color(0.4, 0.55, 0.62, 0.7)
		draw_arc(c, r - RING * 0.5, 0.0, TAU, 48, ring_col, RING, true)
