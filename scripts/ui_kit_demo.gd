extends Control
## UI KIT showcase — every component of the "Nemesis kit" on one sheet.
## Dev scene: run it directly (F6 on scenes/ui_kit_demo.tscn).

var _font: Font = ThemeDB.fallback_font
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.make_theme()
	# real buttons, to prove hover/press states live
	var box := VBoxContainer.new()
	box.position = Vector2(700, 120)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	for label in ["SINGLE PLAYER", "MULTIPLAYER", "OPTIONS", "QUIT GAME"]:
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(220, 46)
		box.add_child(b)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.045, 0.085), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 120:
		draw_circle(Vector2(rng.randf_range(0, vp.x), rng.randf_range(0, vp.y)),
			rng.randf_range(0.5, 1.8), Color(1, 1, 1, rng.randf_range(0.1, 0.5)))

	draw_string(_font, Vector2(40, 50), "SPACEWALKER · RETROFUTURISM KIT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UITheme.TEXT)
	draw_line(Vector2(40, 62), Vector2(460, 62),
		Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.6), 1.5)
	UITheme.draw_chevrons(self, Vector2(490, 44), 4, 14.0, UITheme.ACCENT, _t)

	# warning banner + hazard icon chips
	UITheme.draw_warning_banner(self, Rect2(700, 540, 330, 26), "WARNING", _font)
	var icons := [preload("res://assets/icons/warning.svg"),
		preload("res://assets/icons/radiation.svg"),
		preload("res://assets/icons/lock.svg"),
		preload("res://assets/icons/skull.svg")]
	for i in icons.size():
		var r := Rect2(700 + i * 50.0, 580.0, 34, 34)
		draw_rect(r, Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.06))
		UITheme.draw_brackets(self, r, UITheme.ACCENT, 7.0, 2.0)
		UITheme.draw_icon(self, icons[i], r.get_center(), 20.0)

	# --- main framed panel with headline + list rows ---
	var panel := Rect2(40, 100, 380, 300)
	UITheme.draw_sci_panel(self, panel)
	UITheme.draw_headline(self, Rect2(panel.position.x + 40, panel.position.y - 14,
		panel.size.x - 80, 30), "HALL OF FAME", _font)
	for i in 5:
		var row := Rect2(panel.position.x + 26, panel.position.y + 40 + i * 48, 328, 40)
		UITheme.draw_sub_panel(self, row)
		draw_string(_font, row.position + Vector2(14, 25), "%d   MATT" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT)
		draw_string(_font, row.position + Vector2(0, 25), "123939",
			HORIZONTAL_ALIGNMENT_CENTER, row.size.x, 13, UITheme.TEXT_DIM)
		draw_string(_font, row.position + Vector2(0, 25), "EASY   ",
			HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 14, 13,
			Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.8))

	# --- meters column ---
	draw_string(_font, Vector2(470, 120), "METERS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT_DIM)
	var fills := [[0.9, Color(0.35, 0.8, 1.0)], [0.6, Color(0.45, 0.9, 0.4)],
		[0.35, Color(1.0, 0.85, 0.3)], [0.12, UITheme.DANGER]]
	for i in fills.size():
		UITheme.draw_meter(self, Rect2(470, 134 + i * 30, 180, 18),
			fills[i][0], fills[i][1])

	# --- ring gauges ---
	draw_string(_font, Vector2(470, 300), "GAUGES",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT_DIM)
	var pulse := 0.72 + 0.25 * sin(_t * 0.9)
	UITheme.draw_ring_gauge(self, Vector2(505, 350), 28.0, 0.97,
		Color(0.35, 0.8, 1.0), _font)
	UITheme.draw_ring_gauge(self, Vector2(585, 350), 28.0, pulse,
		Color(0.85, 0.4, 0.9), _font)
	UITheme.draw_ring_gauge(self, Vector2(505, 430), 28.0, 0.45,
		Color(0.95, 0.85, 0.3), _font)
	UITheme.draw_ring_gauge(self, Vector2(585, 430), 28.0, 0.12,
		UITheme.DANGER, _font)

	# --- buttons label (real buttons are Controls, right side) ---
	draw_string(_font, Vector2(700, 108), "BUTTONS (live states — hover me)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT_DIM)

	# --- sub-panel + key chips + headline ---
	draw_string(_font, Vector2(700, 380), "MISC",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT_DIM)
	var mp := Rect2(700, 394, 300, 120)
	UITheme.draw_sub_panel(self, mp)
	UITheme.draw_key_chip(self, mp.position + Vector2(30, 30), "E", _font)
	draw_string(_font, mp.position + Vector2(50, 35), "INTERACT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT)
	UITheme.draw_key_chip(self, mp.position + Vector2(30, 70), "I", _font,
		UITheme.ACCENT_WARM)
	draw_string(_font, mp.position + Vector2(50, 75), "INVENTORY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT)
	UITheme.draw_headline(self, Rect2(mp.position.x + 150, mp.position.y + 40,
		130, 28), "HEADLINE", _font, 13)

	# --- vitals panel, the real in-game widget, embedded ---
	draw_string(_font, Vector2(40, 448), "IN-GAME VITALS WIDGET",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT_DIM)