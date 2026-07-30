extends Control
## "RECIPE RECOVERED" — the reward moment when a salvaged wreck gives up a
## lost blueprint. A compact banner slides a breath downward while it fades
## in, holds with the item's art and name, then dissolves. Non-modal and
## quiet: flying continues underneath, and nothing here costs or asks.

const Craftables := preload("res://scripts/craftables.gd")

const LIFE := 4.5
const PANEL_W := 300.0
const PANEL_H := 84.0

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
	# gradient wash — draw_polygon interpolates per-vertex colours
	draw_polygon(PackedVector2Array([panel.position,
		Vector2(panel.end.x, panel.position.y), panel.end,
		Vector2(panel.position.x, panel.end.y)]),
		PackedColorArray([
			Color(ac.r, ac.g, ac.b, 0.12 * a), Color(ac.r, ac.g, ac.b, 0.12 * a),
			Color(ac.r, ac.g, ac.b, 0.01 * a), Color(ac.r, ac.g, ac.b, 0.01 * a)]))
	draw_rect(panel, Color(ac.r, ac.g, ac.b, 0.7 * a), false, 1.0)
	draw_rect(panel.grow(-3.0), Color(ac.r, ac.g, ac.b, 0.16 * a), false, 1.0)
	# corner ticks — the sci-panel signature
	for c in [panel.position, Vector2(panel.end.x, panel.position.y),
			Vector2(panel.position.x, panel.end.y), panel.end]:
		var dx: float = 8.0 if c.x <= panel.position.x else -8.0
		var dy: float = 8.0 if c.y <= panel.position.y else -8.0
		draw_line(c, c + Vector2(dx, 0), Color(ac.r, ac.g, ac.b, a), 2.0)
		draw_line(c, c + Vector2(0, dy), Color(ac.r, ac.g, ac.b, a), 2.0)

	# item art in a soft glow well
	var tex: Texture2D = it["tex"]
	var box := 46.0
	var cx := panel.position.x + 36.0
	var cy := panel.position.y + PANEL_H * 0.5
	draw_circle(Vector2(cx, cy), 26.0, Color(ac.r, ac.g, ac.b, 0.10 * a))
	var s := box / maxf(tex.get_size().x, tex.get_size().y)
	var dsz := tex.get_size() * s
	draw_texture_rect(tex, Rect2(Vector2(cx, cy) - dsz * 0.5, dsz), false,
		Color(1, 1, 1, a))

	var tx := panel.position.x + 70.0
	var tw := PANEL_W - 82.0
	var shimmer := 0.82 + 0.18 * sin(_t * 6.0)
	draw_string(_font, Vector2(tx, panel.position.y + 26), "RECIPE RECOVERED",
		HORIZONTAL_ALIGNMENT_LEFT, tw, 9, Color(ac.r, ac.g, ac.b, a * shimmer))
	# name shrinks rather than running past the panel — some run 18 characters
	var nm := str(it["name"])
	var ns := 13
	while ns > 9 and _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x > tw:
		ns -= 1
	draw_string(_font, Vector2(tx, panel.position.y + 46), nm,
		HORIZONTAL_ALIGNMENT_LEFT, tw, ns, Color(1, 1, 1, a))
	draw_string(_font, Vector2(tx, panel.position.y + 64),
		"added to the fabricator catalogue",
		HORIZONTAL_ALIGNMENT_LEFT, tw, 8, Color(1, 1, 1, 0.45 * a))
