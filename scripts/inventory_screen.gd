extends Control
## Full-screen inventory (I / Tab, Esc closes) — one big framed screen:
## EXOSUIT column (character, gear, discovery gauge) and a scrollable
## grid of LARGE element cards — symbol, full name, count, capacity bar,
## category strip, on-suit badge. Mouse wheel scrolls, hover for details.

const FACTS_DB := preload("res://scripts/element_facts.gd")
const SUIT_TEX := preload("res://assets/sprites/astronaut.png")
const ICON_HELMET := preload("res://assets/icons/helmet.svg")
const ICON_LINE := preload("res://assets/icons/line.svg")
const ICON_TANK := preload("res://assets/icons/tank.svg")
const ICON_LASER := preload("res://assets/icons/laser.svg")

const PANEL_W := 920.0
const PANEL_H := 512.0
const LEFT_W := 208.0
const COLS := 6
const CARD_W := 100.0
const CARD_H := 44.0
const CARD_GAP := 5.0
const VISIBLE_ROWS := 8

var _font: Font = ThemeDB.fallback_font
var _sorted: Array = []
var _grid_origin := Vector2.ZERO
var _scroll := 0
var _hover := -1
var _detail := -1
var _collectible_total := 0

## The host scene can veto opening (e.g. ship_interior while a modal, the
## rename box or fabricator placement is up) — the inventory is a full-screen
## layer and must never stack over those.
var can_open: Callable = func() -> bool: return true


func _ready() -> void:
	visible = OS.get_environment("SW_SHOW_INV") != ""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	resized.connect(queue_redraw)
	GameState.inventory_changed.connect(queue_redraw)
	GameState.cargo_changed.connect(func(_c, _b): queue_redraw())
	GameState.gear_changed.connect(queue_redraw)
	_sorted = Elements.full_table()   # all 103, atomic-number order
	for e in _sorted:
		if e[4]:
			_collectible_total += 1   # the 83 real-abundance elements
	# debug: SW_DETAIL=Fe opens that element's trivia card at boot
	var dbg := OS.get_environment("SW_DETAIL")
	if dbg != "":
		for i in _sorted.size():
			if _sorted[i][0] == dbg:
				_detail = i
				break


func _max_scroll() -> int:
	return maxi(int(ceilf(float(_sorted.size()) / COLS)) - VISIBLE_ROWS, 0)


func _process(_delta: float) -> void:
	if not visible:
		return
	var rel := get_global_mouse_position() - _grid_origin
	var idx := -1
	if rel.x >= 0.0 and rel.y >= 0.0:
		var col := int(rel.x / (CARD_W + CARD_GAP))
		var row := int(rel.y / (CARD_H + CARD_GAP)) + _scroll
		if col < COLS and row - _scroll < VISIBLE_ROWS \
				and fmod(rel.x, CARD_W + CARD_GAP) <= CARD_W \
				and fmod(rel.y, CARD_H + CARD_GAP) <= CARD_H:
			var i := row * COLS + col
			if i < _sorted.size():
				idx = i
	if idx != _hover:
		_hover = idx
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_I, KEY_TAB]:
			if not visible and not can_open.call():
				return   # a modal/placement owns the screen — don't stack
			visible = not visible
			if not visible:
				_detail = -1
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and visible:
			if _detail >= 0:
				_detail = -1          # close the trivia card first
			else:
				visible = false
			get_viewport().set_input_as_handled()
			queue_redraw()
	elif visible and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _detail >= 0:
				_detail = -1          # click anywhere dismisses the trivia card
			elif _hover >= 0:
				_detail = _hover      # open trivia for the hovered element
			get_viewport().set_input_as_handled()
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = mini(_scroll + 1, _max_scroll())
			get_viewport().set_input_as_handled()
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = maxi(_scroll - 1, 0)
			get_viewport().set_input_as_handled()
			queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.02, 0.05, 0.75), true)
	var panel := Rect2((vp.x - PANEL_W) * 0.5, (vp.y - PANEL_H) * 0.5, PANEL_W, PANEL_H)
	UITheme.draw_sci_panel(self, panel)
	UITheme.draw_headline(self, Rect2(panel.position.x + PANEL_W * 0.5 - 130,
		panel.position.y - 14, 260, 30), "INVENTORY", _font, 13)
	_draw_suit_column(Rect2(panel.position + Vector2(20, 28), Vector2(LEFT_W, PANEL_H - 48)))
	_draw_elements_area(Rect2(panel.position + Vector2(LEFT_W + 40, 28),
		Vector2(PANEL_W - LEFT_W - 60, PANEL_H - 48)))
	if _detail >= 0 and _detail < _sorted.size():
		_draw_detail(vp, _sorted[_detail])


func _draw_detail(vp: Vector2, e: Array) -> void:
	## A beautiful trivia card for the clicked element — icon, identity, and
	## a real-world fact. Dims the inventory behind it.
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.02, 0.05, 0.55))
	var craftable: bool = e[4]
	var sym: String = e[0]
	var acc: Color = Elements.glow_for(sym)   # match the element's real art colour
	var pw := 500.0
	var ph := 260.0
	var p := Rect2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5, pw, ph)
	UITheme.draw_sci_panel(self, p, acc)

	# big icon on the left, over a soft tinted disc
	var icx := p.position.x + 92.0
	var icy := p.position.y + ph * 0.44
	draw_circle(Vector2(icx, icy), 66.0, Color(acc.r, acc.g, acc.b, 0.10))
	var icon := Elements.icon_for_z(e[2])
	if icon != null:
		var isz := icon.get_size()
		var s := 116.0 / maxf(isz.x, isz.y)
		var dsz := isz * s
		draw_texture_rect(icon, Rect2(Vector2(icx - dsz.x * 0.5, icy - dsz.y * 0.5), dsz), false)

	var tx := p.position.x + 176.0
	var ty := p.position.y + 40.0
	# symbol + name
	draw_string(_font, Vector2(tx, ty), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, acc)
	draw_string(_font, Vector2(tx + 74, ty), str(e[1]),
		HORIZONTAL_ALIGNMENT_LEFT, pw - 250, 18, UITheme.TEXT)
	# identity line
	var ident := "Atomic no. %d   ·   %s" % [e[2],
		"SYNTHETIC · collection only" if not craftable else Elements.category(sym).to_upper()]
	if craftable:
		ident += "   ·   abundance %s%%" % String.num_scientific(e[3])
	draw_string(_font, Vector2(tx, ty + 22), ident,
		HORIZONTAL_ALIGNMENT_LEFT, pw - 184, 10,
		Color(0.85, 0.45, 0.85) if not craftable else UITheme.TEXT_DIM)
	draw_line(Vector2(tx, ty + 32), Vector2(p.end.x - 24, ty + 32),
		Color(acc.r, acc.g, acc.b, 0.3), 1.0)
	# the trivia, wrapped
	draw_multiline_string(_font, Vector2(tx, ty + 56), FACTS_DB.fact(sym),
		HORIZONTAL_ALIGNMENT_LEFT, pw - 200, 14, -1, UITheme.TEXT)
	# footer
	var status := ""
	if craftable:
		status = "STORED %d   ·   %s" % [int(GameState.elements.get(sym, 0)),
			"DISCOVERED" if GameState.discovered.has(sym) else "NOT YET FOUND"]
	else:
		status = "FOUND — reactor salvage" if GameState.discovered.has(sym) else "NOT YET FOUND — salvage old wrecks"
	draw_string(_font, Vector2(tx, p.end.y - 34), status,
		HORIZONTAL_ALIGNMENT_LEFT, pw - 200, 11, Color(acc.r, acc.g, acc.b, 0.8))
	UITheme.draw_hints(self, Vector2(p.position.x + pw * 0.5, p.end.y - 11),
		[["Esc", "close"]], _font, 9)


# ------------------------------------------------------------------
# EXOSUIT column
# ------------------------------------------------------------------
func _draw_suit_column(rect: Rect2) -> void:
	UITheme.draw_header(self, rect.position + Vector2(0, 18), "EXOSUIT", _font,
		13, UITheme.ACCENT, rect.size.x)
	var cx := rect.position.x + rect.size.x * 0.5
	draw_texture_rect(SUIT_TEX, Rect2(cx - 52, rect.position.y + 44, 104, 104), false)

	var rows := [
		["SUIT", "Mk I pressure suit", "—", ICON_HELMET],
		["LIFELINE", "%dm rated reach" % int(GameState.tether_length),
			"LV %d" % (GameState.tether_level + 1), ICON_LINE],
		["O2 TANK", "%d capacity" % int(GameState.max_oxygen),
			"LV %d" % (GameState.o2_level + 1), ICON_TANK],
		["LASER", "%d output" % int(GameState.laser_dps),
			"LV %d" % (GameState.laser_level + 1), ICON_LASER],
	]
	var y := rect.position.y + 168.0
	for row in rows:
		var slot_rect := Rect2(rect.position.x, y, rect.size.x, 54)
		UITheme.draw_sub_panel(self, slot_rect)
		UITheme.draw_icon(self, row[3], slot_rect.position + Vector2(26, 27), 24.0)
		draw_string(_font, slot_rect.position + Vector2(52, 23), row[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT)
		draw_string(_font, slot_rect.position + Vector2(52, 40), row[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)
		draw_string(_font, slot_rect.position + Vector2(0, 33), row[2],
			HORIZONTAL_ALIGNMENT_RIGHT, slot_rect.size.x - 12, 12, UITheme.ACCENT_WARM)
		y += 60.0

	# discovery gauge
	var owned := GameState.discovered.size()
	UITheme.draw_ring_gauge(self, Vector2(cx - 54, y + 54), 30.0,
		float(owned) / float(maxi(_sorted.size(), 1)), UITheme.ACCENT, _font)
	draw_string(_font, Vector2(cx - 14, y + 46), "%d / %d" % [owned, _sorted.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT)
	draw_string(_font, Vector2(cx - 14, y + 62), "ELEMENTS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)
	draw_string(_font, Vector2(cx - 14, y + 74), "DISCOVERED",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)


# ------------------------------------------------------------------
# ELEMENTS — large cards, scrollable
# ------------------------------------------------------------------
func _draw_elements_area(rect: Rect2) -> void:
	var samples := 0
	for s in GameState.carried_veins:
		samples += int(GameState.carried_veins[s])
	var held_note := ""
	if samples > 0:
		held_note = "   ·   %d SAMPLES ON SUIT — DOCK TO REFINE" % samples
	UITheme.draw_header(self, rect.position + Vector2(0, 18), "ELEMENTS", _font,
		13, UITheme.ACCENT, rect.size.x)
	draw_string(_font, rect.position + Vector2(0, 42),
		"REAL SOLAR ABUNDANCE%s" % held_note,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)

	_grid_origin = rect.position + Vector2(0, 54)
	var first := _scroll * COLS
	for i in range(first, mini(first + VISIBLE_ROWS * COLS, _sorted.size())):
		var e: Array = _sorted[i]
		var col := i % COLS
		var row := int(float(i) / COLS) - _scroll
		var p := _grid_origin + Vector2(col * (CARD_W + CARD_GAP), row * (CARD_H + CARD_GAP))
		_draw_card(e, Rect2(p, Vector2(CARD_W, CARD_H)), i == _hover)

	# scrollbar — in the gutter just RIGHT of the last card column
	var track := Rect2(_grid_origin.x + COLS * (CARD_W + CARD_GAP) + 6.0, _grid_origin.y,
		4.0, VISIBLE_ROWS * (CARD_H + CARD_GAP) - CARD_GAP)
	draw_rect(track, Color(1, 1, 1, 0.06))
	var total_rows := ceilf(float(_sorted.size()) / COLS)
	var thumb_h := track.size.y * VISIBLE_ROWS / total_rows
	var thumb_y := track.position.y + (track.size.y - thumb_h) * \
		(float(_scroll) / maxf(float(_max_scroll()), 1.0))
	draw_rect(Rect2(track.position.x, thumb_y, 4.0, thumb_h),
		Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.5))

	# detail footer — anchored just below the grid (not the panel edge) so it
	# never crowds the last card row
	var fy := _grid_origin.y + VISIBLE_ROWS * (CARD_H + CARD_GAP) - CARD_GAP + 8.0
	if _hover >= 0:
		var he: Array = _sorted[_hover]
		if not he[4]:
			# synthetic — collectible for the set, but no natural abundance
			var syn_have := GameState.discovered.has(he[0])
			draw_circle(Vector2(rect.position.x + 8, fy + 6), 5.0, Color(0.85, 0.4, 0.85))
			draw_string(_font, Vector2(rect.position.x + 20, fy + 11),
				"%s — %s   ·   Z %d   ·   SYNTHETIC — salvaged from old reactor cores, collection only (not craftable)   ·   %s   ·   click for trivia" % [
					he[0], he[1], he[2], "FOUND" if syn_have else "NOT YET FOUND"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.7, 0.86))
		else:
			var hcol: Color = Elements.hue_of(he[0])
			draw_circle(Vector2(rect.position.x + 8, fy + 6), 5.0, hcol)
			var status := "DISCOVERED" if GameState.discovered.has(he[0]) else "NOT YET FOUND"
			draw_string(_font, Vector2(rect.position.x + 20, fy + 11),
				"%s — %s   ·   Z %d   ·   %s   ·   stored %d / %d   ·   abundance %s%%   ·   %s   ·   click for trivia" % [
					he[0], he[1], he[2], Elements.category(he[0]).to_upper(),
					int(GameState.elements.get(he[0], 0)), GameState.ELEMENT_CAP,
					String.num_scientific(he[3]), status],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.TEXT)
	else:
		var gx := rect.position.x + 8.0
		draw_string(_font, Vector2(gx, fy + 13), "hover a card for details",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.3))
		gx += _font.get_string_size("hover a card for details",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 18.0
		UITheme.draw_hints_at(self, Vector2(gx, fy), [["Wheel", "scroll"], ["Esc", "close"]],
			_font, 10, Color(1, 1, 1, 0.4))


func _draw_card(e: Array, r: Rect2, hovered: bool) -> void:
	var sym: String = e[0]
	var z: int = e[2]
	var craftable: bool = e[4]        # 83 abundance elements; else synthetic
	var amount: int = int(GameState.elements.get(sym, 0))
	var have: bool = GameState.discovered.has(sym)
	var ecol: Color = Elements.hue_of(sym)
	# synthetics are collection-only — a distinct magenta accent
	var strip: Color = Color(0.85, 0.35, 0.85) if not craftable else Elements.color_of(sym)

	var bg := Color(0.0, 0.0, 0.0, 0.35)
	var border := Color(1, 1, 1, 0.08)
	if have:
		bg = Color(ecol.r, ecol.g, ecol.b, 0.10)
		border = Color(ecol.r, ecol.g, ecol.b, 0.5)
	if hovered:
		bg = Color(ecol.r, ecol.g, ecol.b, 0.20)
		border = Color(1, 1, 1, 0.9)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.draw(get_canvas_item(), r)

	# accent strip down the left edge (magenta = synthetic/collection-only)
	draw_rect(Rect2(r.position + Vector2(1, 6), Vector2(3, r.size.y - 12)),
		Color(strip.r, strip.g, strip.b, 0.9 if have else 0.25))

	# element icon — full colour when discovered, dim until then. Top-aligned so
	# the bottom name-plate never covers it.
	var icon: Texture2D = Elements.icon_for_z(z)
	var text_x := 8.0
	if icon != null:
		var box := 28.0
		var isz := icon.get_size()
		var s := box / maxf(isz.x, isz.y)
		var draw_sz := isz * s
		var ipos := r.position + Vector2(5.0 + (box - draw_sz.x) * 0.5,
			3.0 + (box - draw_sz.y) * 0.5)
		draw_texture_rect(icon, Rect2(ipos, draw_sz), false,
			Color(1, 1, 1, 1) if have else Color(0.5, 0.5, 0.55, 0.28))
		text_x = 40.0

	# atomic number top-right — makes the periodic ordering obvious
	draw_string(_font, r.position + Vector2(0, 12), str(z),
		HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 9,
		Color(0.55, 0.9, 1.0, 0.55 if have else 0.28))
	# symbol + count, kept in the upper band clear of the name-plate
	var sym_col := ecol if have else Color(1, 1, 1, 0.25)
	draw_string(_font, r.position + Vector2(text_x, 21), sym,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, sym_col)
	if amount > 0:
		draw_string(_font, r.position + Vector2(0, 20), "×%d" % amount,
			HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 11, UITheme.TEXT)
	elif have and not craftable:
		draw_string(_font, r.position + Vector2(0, 20), "SYN",
			HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 8, Color(0.85, 0.4, 0.85, 0.7))

	# bottom name-plate — a dark strip that doubles as the capacity bar, so the
	# WHOLE element name always fits (centred across the full card width)
	var plate := Rect2(r.position + Vector2(2, r.size.y - 13), Vector2(r.size.x - 4, 12))
	draw_rect(plate, Color(0, 0, 0, 0.5))
	if amount > 0:
		# faint element tint across the plate = "you're holding some" (the ×N
		# count carries the number; a fill bar would be meaningless vs the huge cap)
		draw_rect(plate, Color(ecol.r, ecol.g, ecol.b, 0.18))
	draw_string(_font, r.position + Vector2(0, r.size.y - 4), str(e[1]),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9,
		UITheme.TEXT if have else Color(1, 1, 1, 0.30))

	# on-suit badge — kept in the upper band, clear of the name-plate
	var held: int = GameState.carried_veins.get(sym, 0)
	if held > 0:
		draw_string(_font, r.position + Vector2(0, 30), "+%d" % held,
			HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10, 10, UITheme.ACCENT_WARM)
		draw_rect(r, Color(UITheme.ACCENT_WARM.r, UITheme.ACCENT_WARM.g,
			UITheme.ACCENT_WARM.b, 0.5), false, 1.0)


# gear icons are SVG assets (assets/icons/), tinted via UITheme.draw_icon