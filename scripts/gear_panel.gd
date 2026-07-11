extends Control
## HUD gear rack — four cut-corner tiles for the player's gear:
## suit, lifeline (tether), O2 tank, laser pistol. Live stats, level pips,
## and a warm flash when something gets upgraded.

const TILE := 66.0
const GAP := 7.0

var _flash := 0.0
var _font: Font = ThemeDB.fallback_font


func _get_minimum_size() -> Vector2:
	return Vector2(4.0 * TILE + 3.0 * GAP, 82.0)


func _ready() -> void:
	custom_minimum_size = _get_minimum_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.gear_changed.connect(_on_gear_changed)
	GameState.oxygen_changed.connect(func(_c, _m): queue_redraw())


func _on_gear_changed() -> void:
	_flash = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 1.6, 0.0)
		queue_redraw()


func _draw() -> void:
	_draw_tile(0, "SUIT", "MK I", 0, func(c): _icon_suit(c))
	_draw_tile(1, "LINE", "%dm" % int(GameState.tether_length),
		GameState.tether_level, func(c): _icon_tether(c))
	_draw_tile(2, "O2", "%d" % int(GameState.max_oxygen),
		GameState.o2_level, func(c): _icon_tank(c))
	_draw_tile(3, "LASER", "%d" % int(GameState.laser_dps),
		GameState.laser_level, func(c): _icon_pistol(c))


func _draw_tile(i: int, title: String, value: String, level: int,
		icon: Callable) -> void:
	var x := i * (TILE + GAP)
	var rect := Rect2(x, 0, TILE, TILE + 14.0)
	var accent := UITheme.ACCENT
	if _flash > 0.0:
		accent = UITheme.ACCENT.lerp(UITheme.ACCENT_WARM, _flash)
	# steel tile
	UITheme.draw_sub_panel(self, rect)
	if _flash > 0.0:
		draw_rect(rect.grow(-2.0), Color(accent.r, accent.g, accent.b,
			0.5 * _flash), false, 2.0)
	# title
	draw_string(_font, Vector2(x, 13), title, HORIZONTAL_ALIGNMENT_CENTER,
		TILE, 9, UITheme.TEXT_DIM)
	# icon
	icon.call(Vector2(x + TILE * 0.5, 33.0))
	# value
	draw_string(_font, Vector2(x, TILE - 2), value, HORIZONTAL_ALIGNMENT_CENTER,
		TILE, 13, Color(0.7, 0.9, 1.0, 0.95))
	# level pips
	for p in 4:
		var px := x + TILE * 0.5 - 21.0 + p * 12.0
		draw_rect(Rect2(px, TILE + 6.0, 8.0, 3.0),
			UITheme.ACCENT_WARM if p < level else Color(1, 1, 1, 0.13))


# ------------------------------------------------------------------
# Icons — same visual language as the in-world placeholders
# ------------------------------------------------------------------
func _icon_suit(c: Vector2) -> void:
	draw_circle(c + Vector2(-7, 0), 6.0, Color(0.45, 0.48, 0.55))
	draw_circle(c, 10.0, Color(0.92, 0.94, 0.97))
	draw_circle(c + Vector2(3, -1), 5.5, Color(0.1, 0.2, 0.35))
	draw_circle(c + Vector2(1, -3), 1.6, Color(0.7, 0.9, 1.0, 0.85))


func _icon_tether(c: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 23:
		var t := float(i) / 22.0
		pts.append(c + Vector2(lerpf(-11.0, 11.0, t), sin(t * TAU * 1.5) * 6.0))
	draw_polyline(pts, Color(1.0, 0.85, 0.3, 0.95), 2.0)
	draw_circle(c + Vector2(-11, 0), 2.5, Color(0.25, 0.28, 0.34))
	draw_circle(c + Vector2(11, 0), 2.5, Color(0.25, 0.28, 0.34))


func _icon_tank(c: Vector2) -> void:
	draw_rect(Rect2(c.x - 6, c.y - 9, 12, 18), Color(0.35, 0.8, 1.0), true)
	draw_rect(Rect2(c.x - 6, c.y - 9, 12, 18), Color(0.1, 0.2, 0.3, 0.5), false, 1.0)
	draw_rect(Rect2(c.x - 2, c.y - 12, 4, 3), Color(0.55, 0.58, 0.66))
	draw_rect(Rect2(c.x - 5, c.y + 2, 10, 3), Color(1, 1, 1, 0.35))


func _icon_pistol(c: Vector2) -> void:
	draw_rect(Rect2(c.x - 10, c.y - 4, 16, 6), Color(0.6, 0.65, 0.7))
	draw_rect(Rect2(c.x - 6, c.y + 2, 5, 7), Color(0.45, 0.48, 0.55))
	draw_circle(c + Vector2(8, -1), 2.2, Color(1.0, 0.4, 0.3, 0.95))
	draw_line(c + Vector2(9, -1), c + Vector2(15, -1), Color(1.0, 0.3, 0.2, 0.7), 2.0)
