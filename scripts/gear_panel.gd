extends Control
## HUD gear rack — four code-drawn tiles for the player's gear:
## suit, lifeline (tether), O2 tank, laser pistol. Each tile shows the
## current stat so upgrades read back visibly. Placeholder _draw() art.

const TILE := 64.0
const GAP := 6.0
const ICON_CY := 24.0   # icon centre height inside a tile


func _get_minimum_size() -> Vector2:
	## Anchor presets (PRESET_MODE_MINSIZE) size the control from this,
	## not from custom_minimum_size — without it the panel collapses to
	## zero width and the tiles draw off-screen.
	return Vector2(4.0 * TILE + 3.0 * GAP, 78.0)


func _ready() -> void:
	custom_minimum_size = _get_minimum_size()
	GameState.gear_changed.connect(queue_redraw)
	GameState.oxygen_changed.connect(func(_c, _m): queue_redraw())


func _tile_origin(i: int) -> float:
	return i * (TILE + GAP)


func _draw() -> void:
	_draw_tile(0, "SUIT", "MK I", func(c): _icon_suit(c))
	_draw_tile(1, "LINE", "%dm" % int(GameState.tether_length), func(c): _icon_tether(c))
	_draw_tile(2, "O2", "%d" % int(GameState.max_oxygen), func(c): _icon_tank(c))
	_draw_tile(3, "LASER", "%d" % int(GameState.laser_dps), func(c): _icon_pistol(c))


func _draw_tile(i: int, title: String, value: String, icon: Callable) -> void:
	var font := get_theme_default_font()
	var x := _tile_origin(i)
	var bg := Rect2(x, 0, TILE, TILE)
	draw_rect(bg, Color(0.08, 0.11, 0.17, 0.72), true)
	draw_rect(bg, Color(0.35, 0.8, 1.0, 0.25), false, 1.0)
	# title (top)
	draw_string(font, Vector2(x, 12), title, HORIZONTAL_ALIGNMENT_CENTER,
		TILE, 9, Color(1, 1, 1, 0.5))
	# icon, drawn centred within the tile
	icon.call(Vector2(x + TILE * 0.5, ICON_CY + 4.0))
	# value (bottom)
	draw_string(font, Vector2(x, TILE - 6), value, HORIZONTAL_ALIGNMENT_CENTER,
		TILE, 12, Color(0.7, 0.9, 1.0, 0.95))


# ------------------------------------------------------------------
# Icons — same visual language as the in-world placeholders
# ------------------------------------------------------------------
func _icon_suit(c: Vector2) -> void:
	# backpack + helmet + visor (mirrors the astronaut in player.gd)
	draw_circle(c + Vector2(-7, 0), 6.0, Color(0.45, 0.48, 0.55))
	draw_circle(c, 10.0, Color(0.92, 0.94, 0.97))
	draw_circle(c + Vector2(3, -1), 5.5, Color(0.1, 0.2, 0.35))
	draw_circle(c + Vector2(1, -3), 1.6, Color(0.7, 0.9, 1.0, 0.85))


func _icon_tether(c: Vector2) -> void:
	# a coiled lifeline
	var pts := PackedVector2Array()
	var steps := 22
	for i in steps + 1:
		var t := float(i) / float(steps)
		var px := lerpf(-11.0, 11.0, t)
		var py := sin(t * TAU * 1.5) * 6.0
		pts.append(c + Vector2(px, py))
	draw_polyline(pts, Color(1.0, 0.85, 0.3, 0.95), 2.0)
	draw_circle(c + Vector2(-11, 0), 2.5, Color(0.25, 0.28, 0.34))
	draw_circle(c + Vector2(11, 0), 2.5, Color(0.25, 0.28, 0.34))


func _icon_tank(c: Vector2) -> void:
	# O2 cylinder with a valve on top
	draw_rect(Rect2(c.x - 6, c.y - 9, 12, 18), Color(0.35, 0.8, 1.0), true)
	draw_rect(Rect2(c.x - 6, c.y - 9, 12, 18), Color(0.1, 0.2, 0.3, 0.5), false, 1.0)
	draw_rect(Rect2(c.x - 2, c.y - 12, 4, 3), Color(0.55, 0.58, 0.66))
	draw_rect(Rect2(c.x - 5, c.y + 2, 10, 3), Color(1, 1, 1, 0.35))


func _icon_pistol(c: Vector2) -> void:
	# blocky laser pistol
	draw_rect(Rect2(c.x - 10, c.y - 4, 16, 6), Color(0.6, 0.65, 0.7))     # barrel/body
	draw_rect(Rect2(c.x - 6, c.y + 2, 5, 7), Color(0.45, 0.48, 0.55))     # grip
	draw_circle(c + Vector2(8, -1), 2.2, Color(1.0, 0.4, 0.3, 0.95))      # muzzle glow
	draw_line(c + Vector2(9, -1), c + Vector2(15, -1), Color(1.0, 0.3, 0.2, 0.7), 2.0)
