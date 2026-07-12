extends Control
## HUD gear rack — four cut-corner tiles for the player's gear:
## suit, lifeline (tether), O2 tank, laser pistol. Live stats, level pips,
## and a warm flash when something gets upgraded.

const TILE := 66.0
const GAP := 7.0

const ICON_HELMET := preload("res://assets/icons/helmet.svg")
const ICON_LINE := preload("res://assets/icons/line.svg")
const ICON_TANK := preload("res://assets/icons/tank.svg")
const ICON_LASER := preload("res://assets/icons/laser.svg")

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


const MK := ["I", "II", "III", "IV", "V", "VI"]


func _draw() -> void:
	_draw_tile(0, "SUIT", "MK %s · %d" % [
		MK[mini(GameState.suit_level, MK.size() - 1)], GameState.carry_max()],
		GameState.suit_level, ICON_HELMET)
	_draw_tile(1, "LINE", "%dm" % int(GameState.tether_length),
		GameState.tether_level, ICON_LINE)
	_draw_tile(2, "O2", "%d" % int(GameState.max_oxygen),
		GameState.o2_level, ICON_TANK)
	_draw_tile(3, "LASER", "%d" % int(GameState.laser_dps),
		GameState.laser_level, ICON_LASER)


func _draw_tile(i: int, title: String, value: String, level: int,
		icon: Texture2D) -> void:
	var x := i * (TILE + GAP)
	var rect := Rect2(x, 0, TILE, TILE + 14.0)
	var accent := UITheme.ACCENT
	if _flash > 0.0:
		accent = UITheme.ACCENT.lerp(UITheme.ACCENT_WARM, _flash)
	UITheme.draw_sub_panel(self, rect, accent)
	if _flash > 0.0:
		draw_rect(rect.grow(-2.0), Color(accent.r, accent.g, accent.b,
			0.5 * _flash), false, 2.0)
	# title
	draw_string(_font, Vector2(x, 13), title, HORIZONTAL_ALIGNMENT_CENTER,
		TILE, 9, UITheme.TEXT_DIM)
	# SVG icon, cyan
	UITheme.draw_icon(self, icon, Vector2(x + TILE * 0.5, 34.0), 26.0)
	# value
	draw_string(_font, Vector2(x, TILE - 2), value, HORIZONTAL_ALIGNMENT_CENTER,
		TILE, 13, Color(0.7, 0.95, 1.0, 0.95))
	# level pips — one per upgrade (5), maxed reads all-lit warm
	var pips := GameState.MAX_GEAR_LEVEL
	var maxed := level >= pips
	for p in pips:
		var px := x + TILE * 0.5 - float(pips) * 5.0 + p * 10.0
		var on := p < level
		draw_rect(Rect2(px, TILE + 6.0, 7.0, 3.0),
			(UITheme.ACCENT_WARM if maxed else UITheme.ACCENT) if on else Color(1, 1, 1, 0.13))


# icons are SVG assets (assets/icons/), tinted via UITheme.draw_icon
