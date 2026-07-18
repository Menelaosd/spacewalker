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

	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.01, 0.03, 0.75 * a))

	var card_bottom := vp.y * 0.5
	if _card != null:
		var ts := _card.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			# fit within 62% of the viewport both ways, aspect preserved
			var fit := minf(vp.x * 0.62 / ts.x, vp.y * 0.62 / ts.y)
			# one-shot ease-out scale-in 0.96 -> 1.0 on open only
			var f := clampf(_t / OPEN_TIME, 0.0, 1.0)
			var eased := 1.0 - (1.0 - f) * (1.0 - f)
			var dsz := ts * fit * (0.96 + 0.04 * eased)
			var pos := (vp - dsz) * 0.5
			var r := Rect2(pos, dsz)
			card_bottom = r.end.y

			# faint static accent glow behind the card
			draw_rect(r.grow(28.0), Color(ac.r, ac.g, ac.b, 0.04 * a))
			draw_rect(r.grow(14.0), Color(ac.r, ac.g, ac.b, 0.07 * a))
			draw_rect(r.grow(5.0), Color(ac.r, ac.g, ac.b, 0.10 * a))

			draw_texture_rect(_card, r, false, Color(1, 1, 1, a))

	draw_string(_font, Vector2(0, card_bottom + 24.0),
		"CREW REGISTRY — HELIOS EXILE MANIFEST",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 10,
		Color(UITheme.TEXT_DIM.r, UITheme.TEXT_DIM.g, UITheme.TEXT_DIM.b,
			UITheme.TEXT_DIM.a * a))

	UITheme.draw_hints(self, Vector2(vp.x * 0.5, vp.y - 26.0),
		[["Esc", "close"]], _font, 9)
