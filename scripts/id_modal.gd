extends Control
## Crew ID card viewer — centered card art over a dim backdrop with a faint
## static accent glow. One-shot fade + tiny scale-in on open (eased, not
## looping — the captain gets motion-sick). Esc / E / any click closes.

signal closed()

const OPEN_TIME := 0.25
const CLOSE_TIME := 0.15

var _font: Font = ThemeDB.fallback_font
var _card: Texture2D = null
var _t := 0.0
var _closing := false
var _close_t := 0.0


func _ready() -> void:
	# anchors AND offsets — anchors alone leave the control 0x0 (unclickable)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	visible = false


func open(char_name: String) -> void:
	_card = load("res://assets/sprites/crew/" + char_name.to_lower() + "_id.png")
	_t = 0.0
	_closing = false
	_close_t = 0.0
	visible = true
	queue_redraw()


func _close() -> void:
	if _closing:
		return
	_closing = true
	_close_t = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _closing:
		_close_t += delta
		if _close_t >= CLOSE_TIME:
			_closing = false
			visible = false
			closed.emit()
			return
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo \
				and event.physical_keycode in [KEY_ESCAPE, KEY_E]:
			_close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		# a CLICK closes the card — but a scroll-wheel tick is not a click
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_close()
		accept_event()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var ac := UITheme.ACCENT

	var a := clampf(_t / OPEN_TIME, 0.0, 1.0)
	if _closing:
		a = 1.0 - clampf(_close_t / CLOSE_TIME, 0.0, 1.0)

	# graded backdrop — darkest at the edges, a shade open behind the card
	var d0 := Color(0.0, 0.008, 0.022, 0.88 * a)
	var d1 := Color(0.0, 0.018, 0.045, 0.66 * a)
	draw_polygon(PackedVector2Array([Vector2(0.0, 0.0), Vector2(vp.x, 0.0),
		Vector2(vp.x, vp.y * 0.5), Vector2(0.0, vp.y * 0.5)]),
		PackedColorArray([d0, d0, d1, d1]))
	draw_polygon(PackedVector2Array([Vector2(0.0, vp.y * 0.5), Vector2(vp.x, vp.y * 0.5),
		Vector2(vp.x, vp.y), Vector2(0.0, vp.y)]),
		PackedColorArray([d1, d1, d0, d0]))

	var card_bottom := vp.y * 0.5
	if _card != null:
		var ts := _card.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			# fit within 56% of the viewport both ways, aspect preserved
			var fit := minf(vp.x * 0.56 / ts.x, vp.y * 0.56 / ts.y)
			# one-shot ease-out scale-in 0.96 -> 1.0 on open only
			var f := clampf(_t / OPEN_TIME, 0.0, 1.0)
			var eased := 1.0 - (1.0 - f) * (1.0 - f)
			var dsz := ts * fit * (0.96 + 0.04 * eased)
			var pos := (vp - dsz) * 0.5
			var r := Rect2(pos, dsz)
			card_bottom = r.end.y

			# soft graded halo — hairline rings falling off from the card edge,
			# so the card sits in light instead of a hard boxy glow
			for i in 14:
				var g := 1.0 - float(i) / 14.0
				draw_rect(r.grow(2.0 + float(i) * 2.0),
					Color(ac.r, ac.g, ac.b, 0.09 * g * g * a), false, 2.0)

			draw_texture_rect(_card, r, false, Color(1, 1, 1, a))
			# hairline border — the card's own edge, one pixel of accent
			draw_rect(r.grow(0.5), Color(ac.r, ac.g, ac.b, 0.55 * a), false, 1.0)

	draw_string(_font, Vector2(0, card_bottom + 21.0),
		"CREW REGISTRY — HELIOS EXILE MANIFEST",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 9,
		Color(UITheme.TEXT_DIM.r, UITheme.TEXT_DIM.g, UITheme.TEXT_DIM.b,
			UITheme.TEXT_DIM.a * a))

	UITheme.draw_hints(self, Vector2(vp.x * 0.5, vp.y - 26.0),
		[["Esc", "close"]], _font, 9)
