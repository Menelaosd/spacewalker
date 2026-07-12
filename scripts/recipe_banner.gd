extends Control
## "RECIPE RECOVERED" — the reward moment when a salvaged wreck gives up a
## lost blueprint. A sci-panel banner slides a breath downward while it
## fades in, holds with the item's art and cost, then dissolves. Non-modal:
## flying continues underneath.

const Craftables := preload("res://scripts/craftables.gd")

const LIFE := 5.0
const PANEL_W := 380.0
const PANEL_H := 118.0

var _font: Font = ThemeDB.fallback_font
var _id := ""
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 190
	visible = false


func show_recipe(id: String) -> void:
	_id = id
	_t = 0.0
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t >= LIFE:
		visible = false
	queue_redraw()


func _alpha() -> float:
	# quick fade-in, long hold, gentle fade-out
	return clampf(_t * 3.0, 0.0, 1.0) * clampf((LIFE - _t) * 1.2, 0.0, 1.0)


func _draw() -> void:
	if _id == "" or not Craftables.ITEMS.has(_id):
		return
	var it: Dictionary = Craftables.ITEMS[_id]
	var a := _alpha()
	var vp := get_viewport_rect().size
	# eases down a few px as it lands
	var slide := (1.0 - clampf(_t * 3.0, 0.0, 1.0)) * -14.0
	var panel := Rect2((vp.x - PANEL_W) * 0.5, vp.y * 0.16 + slide, PANEL_W, PANEL_H)

	var ac := UITheme.ACCENT
	draw_rect(panel, Color(0.03, 0.06, 0.10, 0.88 * a))
	draw_rect(panel, Color(ac.r, ac.g, ac.b, 0.75 * a), false, 1.5)
	# corner ticks — the sci-panel signature
	for c in [panel.position, Vector2(panel.end.x, panel.position.y),
			Vector2(panel.position.x, panel.end.y), panel.end]:
		var dx: float = 10.0 if c.x <= panel.position.x else -10.0
		var dy: float = 10.0 if c.y <= panel.position.y else -10.0
		draw_line(c, c + Vector2(dx, 0), Color(ac.r, ac.g, ac.b, a), 2.5)
		draw_line(c, c + Vector2(0, dy), Color(ac.r, ac.g, ac.b, a), 2.5)

	# item art in a soft glow well
	var tex: Texture2D = it["tex"]
	var box := 72.0
	var cx := panel.position.x + 52.0
	var cy := panel.position.y + PANEL_H * 0.5
	draw_circle(Vector2(cx, cy), 40.0, Color(ac.r, ac.g, ac.b, 0.10 * a))
	var s := box / maxf(tex.get_size().x, tex.get_size().y)
	var dsz := tex.get_size() * s
	draw_texture_rect(tex, Rect2(Vector2(cx, cy) - dsz * 0.5, dsz), false,
		Color(1, 1, 1, a))

	var tx := panel.position.x + 104.0
	var shimmer := 0.75 + 0.25 * sin(_t * 6.0)
	draw_string(_font, Vector2(tx, panel.position.y + 34), "RECIPE RECOVERED",
		HORIZONTAL_ALIGNMENT_LEFT, 260, 13,
		Color(ac.r, ac.g, ac.b, a * shimmer))
	draw_string(_font, Vector2(tx, panel.position.y + 58), it["name"],
		HORIZONTAL_ALIGNMENT_LEFT, 260, 17, Color(1, 1, 1, a))
	draw_string(_font, Vector2(tx, panel.position.y + 76), it["desc"],
		HORIZONTAL_ALIGNMENT_LEFT, 260, 9, Color(0.75, 0.85, 0.95, 0.8 * a))
	draw_string(_font, Vector2(tx, panel.position.y + 98),
		"added to the fabricator catalogue",
		HORIZONTAL_ALIGNMENT_LEFT, 260, 9, Color(1, 1, 1, 0.45 * a))
