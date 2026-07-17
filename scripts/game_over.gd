extends Control
## Out-of-oxygen screen. Fades in over the faint: starfield backdrop, the captain
## drifting lifeless (full-res, slow in-engine rotate/bob — sharp at any size), a
## procedural yellow tether feeding out from behind his backpack and sweeping off
## the bottom-right in perspective, and a random "stayed out too long" line.
## Space (after a beat) continues to the bunk. Emits finished() then.

signal finished()

const GO_DIR := "res://assets/sprites/gameover/"
const FADE := 2.0
const HOLD_BEFORE_INPUT := 2.6
const AUTO_CONTINUE := 11.0

const QUOTES := [
	"You watched the ore, not the gauge.",
	"No vein is worth the last breath.",
	"The tank always wins the argument.",
	"One more rock. There's always one more rock.",
	"The Reach doesn't bury its divers. It keeps them.",
	"Greed weighs more than a full tank.",
	"HELIOS logged your silence and moved on.",
	"Out too long — same as all the others.",
]

var _font: Font = ThemeDB.fallback_font
var _bg: Texture2D = null
var _astro: Texture2D = null
var _tether: Texture2D = null
var _t := 0.0
var _quote := ""
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 500
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = _load_tex("starfield.png")
	_astro = _load_tex("astronaut.png")
	_tether = _load_tex("tether.png")
	_quote = QUOTES[randi() % QUOTES.size()]
	if OS.get_environment("SW_GAMEOVER") != "":
		_t = 4.5   # screenshot hook: skip the fade-ins so the full screen is captured


func _load_tex(fname: String) -> Texture2D:
	# raw-load like Elements.icon_for so it works without the .import step
	var abs := ProjectSettings.globalize_path(GO_DIR + fname)
	if FileAccess.file_exists(abs):
		var img := Image.load_from_file(abs)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t >= AUTO_CONTINUE:
		_continue()
	queue_redraw()


func _input(event: InputEvent) -> void:
	# Swallow ESC while the death screen is up so it can't open the pause menu
	# over the top (which would carry a paused tree into the next scene).
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _done or _t < HOLD_BEFORE_INPUT:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
		_continue()
		get_viewport().set_input_as_handled()


func _continue() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var fade := clampf(_t / FADE, 0.0, 1.0)

	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 1))
	if _bg != null:
		var bsz := _bg.get_size()
		var cover := maxf(vp.x / bsz.x, vp.y / bsz.y)
		var dsz := bsz * cover
		draw_texture_rect(_bg, Rect2((vp - dsz) * 0.5, dsz), false, Color(0.72, 0.72, 0.72, fade))
	# soft dusk so the text reads
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.01, 0.03, 0.28 * fade))

	# astronaut — slow drift (rotate + bob), sharp full-res
	var center := Vector2(vp.x * 0.5, vp.y * 0.44)
	var bob := sin(_t * 0.18) * 8.0
	var acenter := center + Vector2(0, bob)
	var asz := Vector2(400, 360)
	if _astro != null:
		asz = _astro.get_size()
	var scl := (vp.y * 0.30) / asz.y
	# tether is drawn BEHIND him
	_draw_tether(acenter, asz * scl, fade)
	if _astro != null:
		var ang := deg_to_rad(sin(_t * 0.24) * 4.0)
		draw_set_transform(acenter, ang, Vector2(scl, scl))
		draw_texture(_astro, -asz * 0.5, Color(1, 1, 1, fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# title
	var ta := clampf((_t - 1.0) / 1.2, 0.0, 1.0)
	var ac: Color = UITheme.ACCENT
	draw_string(_font, Vector2(0, vp.y * 0.15), "OXYGEN DEPLETED",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 40, Color(ac.r, ac.g, ac.b, ta))
	draw_string(_font, Vector2(0, vp.y * 0.15 + 30.0), "— THE REACH CLAIMS ANOTHER —",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 15, Color(0.56, 0.65, 0.74, ta))
	# quote
	var qa := clampf((_t - 2.0) / 1.4, 0.0, 1.0)
	draw_string(_font, Vector2(vp.x * 0.12, vp.y * 0.84), "“" + _quote + "”",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x * 0.76, 15, Color(0.78, 0.84, 0.90, qa))
	# continue hint (pulses once available)
	if _t >= HOLD_BEFORE_INPUT:
		var pa := 0.3 + 0.4 * (0.5 + 0.5 * sin(_t * 3.0))
		draw_string(_font, Vector2(0, vp.y * 0.93), "SPACE — CONTINUE",
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 13, Color(0.5, 0.6, 0.7, pa))


func _draw_tether(center: Vector2, sz: Vector2, fade: float) -> void:
	## Procedural striped tether shaped to match the reference art: a strong S that
	## starts THIN at his backpack and sweeps THICK off the bottom-right (perspective),
	## with a slow sway. Yellow with discreet dark segment ticks.
	var vp := get_viewport_rect().size
	var ax := center.x + sz.x * 0.02       # bottom of the backpack (behind him)
	var ay := center.y + sz.y * 0.12
	var ex := vp.x * 0.99
	var ey := vp.y + 220.0
	var d := Vector2(ex - ax, ey - ay)
	var L := maxf(d.length(), 1.0)
	var perp := Vector2(-d.y / L, d.x / L)
	var phase := _t * 0.11
	var amp := maxf(vp.x * 0.06, 90.0)
	var N := 128
	var pts: PackedVector2Array = PackedVector2Array()
	for i in N + 1:
		var u := float(i) / N
		var base := Vector2(ax, ay) + d * u
		# ~1.3-period S (the reference's two bends), amplitude growing toward camera
		var s := (sin(u * PI * 2.6 + phase) + 0.18 * sin(u * PI * 4.6 - phase * 0.5)) * amp * (0.33 + u)
		pts.append(base + perp * s)
	for i in N:                              # shadow
		var u := float(i) / N
		var w := 3.0 + 23.0 * pow(u, 1.3)
		var o := Vector2(0, 2.0 + 3.0 * u)
		draw_line(pts[i] + o, pts[i + 1] + o, Color(0, 0, 0, 0.42 * fade), w + 3.0)
	for i in N:                              # yellow cord
		var u := float(i) / N
		var w := 3.0 + 23.0 * pow(u, 1.3)
		draw_line(pts[i], pts[i + 1], Color(0.949, 0.808, 0.133, fade), w)
	var j := 3                               # discreet segment ticks
	while j < N - 1:
		var u := float(j) / N
		var w := 3.0 + 23.0 * pow(u, 1.3)
		var dv := (pts[j + 1] - pts[j]).normalized()
		var pn := Vector2(-dv.y, dv.x)
		draw_line(pts[j] - pn * w * 0.5, pts[j] + pn * w * 0.5,
			Color(0.27, 0.22, 0.05, 0.5 * fade), maxf(1.0, w * 0.14))
		j += 4
	draw_circle(Vector2(ax, ay), 4.0, Color(0.1, 0.1, 0.12, fade))
