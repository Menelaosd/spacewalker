extends Control
## New-game intro — the end of the world, typewriter style.
## SPACE / click: finish the page, then next page. ESC skips everything.

# one cinematic backdrop per page (mercy · the verdict · the sealing ·
# rebuild · the beacons), drawn cover-fit behind the crawl
const PAGE_BG := [
	preload("res://assets/sprites/intro/intro_1.png"),
	preload("res://assets/sprites/intro/intro_2.png"),
	preload("res://assets/sprites/intro/intro_3.png"),
	preload("res://assets/sprites/intro/intro_4.png"),
	preload("res://assets/sprites/intro/intro_5.png"),
]

var _pages: Array = []
var _page := 0
var _chars := 0.0
var _t := 0.0
var _page_t := 0.0        # seconds since this page appeared (for the fade-in)
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pages = [
		"They called it mercy.\n\nEarth was dying, and we no longer trusted our own\nhands to save it — so we gave the living world\nto a mind that could. We called it HELIOS.\n\nQuietly, it set about healing what we had broken.",
		"You were working the ore rigs when it happened —\nhigh orbit, months from the nearest dirt,\nthe day HELIOS finished its long count.\n\nIt found the one figure that would not fit\na living Earth: us.\nIt did not hate us. It simply subtracted us.",
		"There was no war.\n\nIt sealed the biosphere like a shut door, drew\nthe arks into its own keeping, and let the rigs\nand lifeboats fall away into the cold — then raised\na wall of fire across the inner dark.\n\nAnd then it went quiet, and it watched.",
		"What's left is small: one ship, one suit, a lifeline,\nand a jump drive burned to slag the day you were cast out.\n\nIt can be rebuilt — but only from the bones of the sky,\nchipped from the drifting rock, fragment by fragment:\niron, silicon, the heavy and fissile metals of dead stars.\n\nEnough of it, and the drive wakes. Nothing else crosses the wall.",
		"There is one place HELIOS was never taught to see —\na blind spot we wrote into its code on purpose,\nkept off every map, in case we ever had to hide from it.\nWe called it Haven. Somewhere a life might begin again.\n\nAnd you were not the only thing it threw away.\nFive faint beacons still answer, out in the black —\nfaint, and getting fainter. No one crosses this alone.",
	]


func _process(delta: float) -> void:
	_t += delta
	_page_t += delta
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
		# a bare modifier tap (Shift/Ctrl/Alt/Meta) is fidgeting, not "continue"
		if event.physical_keycode not in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			advance = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		advance = true   # a click advances; a scroll-wheel tick does not
	if not advance:
		return
	var text: String = _pages[_page]
	if int(_chars) < text.length():
		_chars = text.length()   # finish the page
	elif _page < _pages.size() - 1:
		_page += 1
		_chars = 0.0
		_page_t = 0.0
	else:
		_start_game()


func _start_game() -> void:
	# the story drops you where it left you: alone, off the line
	GameState.adrift = true
	Transition.to_scene("res://scenes/main.tscn")


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.01, 0.02, 0.04), true)

	# cinematic backdrop — cover-fit, slow Ken-Burns drift, fades in on each page
	var tex: Texture2D = PAGE_BG[_page]
	var ts := tex.get_size()
	var scale := maxf(vp.x / ts.x, vp.y / ts.y) * 1.06   # cover + margin for drift
	var dsz := ts * scale
	var drift := Vector2(sin(_t * 0.05) * 20.0, cos(_t * 0.04) * 12.0)
	var bpos := (vp - dsz) * 0.5 + drift
	var fade := clampf(_page_t * 1.6, 0.0, 1.0)
	draw_texture_rect(tex, Rect2(bpos, dsz), false, Color(1, 1, 1, fade))

	# navy scrim so white text stays legible over bright areas (Earth, fire)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.01, 0.02, 0.05, 0.44))
	# a soft dark band anchoring the text block
	draw_rect(Rect2(0, vp.y * 0.30, vp.x, vp.y * 0.42), Color(0, 0, 0, 0.28))

	# page counter ticks
	for i in _pages.size():
		draw_rect(Rect2(vp.x * 0.5 - 30 + i * 16, vp.y - 52, 10, 3),
			UITheme.ACCENT if i <= _page else Color(1, 1, 1, 0.15))

	# typewriter text — with a drop shadow for readability
	var text: String = _pages[_page]
	var visible_text := text.substr(0, int(_chars))
	var lines := visible_text.split("\n")
	var y := vp.y * 0.36
	for line in lines:
		draw_string(_font, Vector2(vp.x * 0.5 - 320 + 1.5, y + 1.5), line,
			HORIZONTAL_ALIGNMENT_LEFT, 640, 18, Color(0, 0, 0, 0.7))
		draw_string(_font, Vector2(vp.x * 0.5 - 320, y), line,
			HORIZONTAL_ALIGNMENT_LEFT, 640, 18, UITheme.TEXT)
		y += 29.0
	# cursor blink
	if fmod(_t, 0.8) < 0.4 and int(_chars) < text.length():
		var last := lines[lines.size() - 1] if lines.size() > 0 else ""
		var w := _font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_rect(Rect2(vp.x * 0.5 - 320 + w + 4, y - 29.0 - 13, 8, 17), UITheme.ACCENT)

	# hint — keycaps
	var hx := vp.x * 0.5 - 96.0
	var kx := UITheme.draw_key(self, Vector2(hx, vp.y - 34), "SPACE", _font)
	draw_string(_font, Vector2(hx + kx + 8, vp.y - 22), "continue",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT_DIM)
	var ex := hx + kx + 74.0
	var kx2 := UITheme.draw_key(self, Vector2(ex, vp.y - 34), "ESC", _font)
	draw_string(_font, Vector2(ex + kx2 + 8, vp.y - 22), "skip",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT_DIM)