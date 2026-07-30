extends CanvasLayer
## REUSABLE CARD PICKER — a modal overlay that shows REAL CARD FACES and lets the
## player click one. Built for the breach map's sigil nodes (VAULT / RECYCLER /
## SPLICER / MERGE / OVERCLOCK), which used to ask for a pick with a text list.
##
## Visual language is deliberately IDENTICAL to the duel's hand HUD
## (breach_duel3d.gd::_hud_card): same card_frame texture, same portrait inset
## (13%/9% .. 74%/56%), same name at 78% / sigil at 85% / power+hp at 94%, same
## top-left cost disc and top-right attack-direction glyph, same colours.
##
## USAGE
##     var p = load("res://scripts/breach_card_picker.gd").make(
##             ["power_overload", "chain_reaper", "sentinel_ghost"],
##             "OVERCLOCK RIG — pick a card to push past red", "costs 12 shards")
##     p.chosen.connect(_on_picked)          # func _on_picked(index: int)
##     p.cancelled.connect(_on_cancel)       # func _on_cancel()
##     add_child(p)                          # add LAST so it gets input first
## It frees itself as soon as it emits, so a caller can hold a plain reference and
## test `is_instance_valid()` to know whether a pick is still pending.
##
## Self-contained: no edits to breach_map3d.gd / breach_duel3d.gd are required, and
## the card tables are read out of the duel script's constant map at runtime, so
## there is exactly one roster in the project.

signal chosen(index: int)
signal cancelled()
var _info := -1                   # card index whose rules panel is open (right-click)
var _sig_rules := {}
var _lore := {}

const DUEL_PATH := "res://scripts/breach_duel3d.gd"
# hd/ first (the good art), then duel/ (where every u_*.png portrait lives), then scifi/
const ART_DIRS := ["res://assets/sprites/breach/hd/", "res://assets/sprites/breach/duel/",
	"res://assets/sprites/breach/scifi/"]
const ASPECT := 96.0 / 128.0     # same card proportions as the duel hand
const MAX_COLS := 6              # 2-6 cards sit in one row; more wraps into rows

const CYAN := Color(0.45, 0.9, 1.0)
const AMBER := Color(1.0, 0.72, 0.25)
const RED := Color(1.0, 0.35, 0.28)

# ---- public, set before add_child() (or via make()) -------------------------
var card_ids: Array = []          # ids from breach_duel3d.gd CARDS (duplicates OK)
var title := "CHOOSE A CARD"
var cost_note := ""               # e.g. "costs 12 shards" — drawn under the row
var allow_cancel := true          # false = mandatory pick (ESC is swallowed)
var power_bonus := {}             # id -> +power, e.g. pass breach_duel3d's atk_boost
var extra_sigils := {}            # id -> Array of grafted sigils, e.g. its graft
var start_hover := 0              # which card is highlighted before the mouse moves

# ---- internals -------------------------------------------------------------
var _panel: Control
var _font: Font = ThemeDB.fallback_font
var _tex := {}
var _cards := {}                  # CARDS pulled from the duel script
var _sig_short := {}              # SIGIL_SHORT pulled from the duel script
var _hover := 0
var _done := false


static func make(ids: Array, title_txt: String, note: String = "") -> Node:
	var p: CanvasLayer = load("res://scripts/breach_card_picker.gd").new()
	p.card_ids = ids.duplicate()
	p.title = title_txt
	p.cost_note = note
	return p


func _ready() -> void:
	layer = 20                       # the map HUD lives on 1, its post overlay on 0
	_read_card_tables()
	_tex["card_frame"] = _load_art("card_frame")
	for id in card_ids:
		var pn := _portrait_of(str(id))
		if pn != "" and not _tex.has(pn):
			_tex[pn] = _load_art(pn)
	_hover = clampi(start_hover, -1, card_ids.size() - 1)
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP     # modal: eats map clicks
	add_child(_panel)
	_panel.draw.connect(_on_draw)
	_panel.gui_input.connect(_on_gui_input)
	_panel.resized.connect(_panel.queue_redraw)


func _read_card_tables() -> void:
	## constants live in the duel script — read them without instancing a whole duel.
	var duel: Script = load(DUEL_PATH) as Script
	if duel == null:
		return
	var cm: Dictionary = duel.get_script_constant_map()
	_cards = cm.get("CARDS", {})
	_sig_short = cm.get("SIGIL_SHORT", {})
	_sig_rules = cm.get("SIGIL_RULES", {})   # plain-English rule per sigil, for right-click
	_lore = cm.get("LORE", {})


func _load_art(art_name: String) -> Texture2D:
	for dir in ART_DIRS:
		var p := ProjectSettings.globalize_path(str(dir) + art_name + ".png")
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			if img != null:
				return ImageTexture.create_from_image(img)
	return null


# ==================================================================
# Card data helpers (degrade gracefully on unknown ids)
# ==================================================================
func _row_of(id: String) -> Array:
	return _cards.get(id, []) as Array


func _portrait_of(id: String) -> String:
	var c := _row_of(id)
	return str(c[1]) if c.size() > 1 else ""


func _name_of(id: String) -> String:
	var c := _row_of(id)
	return str(c[0]) if c.size() > 0 else id.to_upper().replace("_", " ")


func _atk_of(id: String) -> int:
	var c := _row_of(id)
	var base := int(c[2]) if c.size() > 2 else 0
	return base + int(power_bonus.get(id, 0))


func _hp_of(id: String) -> int:
	var c := _row_of(id)
	return int(c[3]) if c.size() > 3 else 0


func _cost_of(id: String) -> int:
	var c := _row_of(id)
	return int(c[4]) if c.size() > 4 else 0


func _sigils_of(id: String) -> Array:
	var c := _row_of(id)
	var out: Array = (c[5] as Array).duplicate() if c.size() > 5 else []
	for sg in (extra_sigils.get(id, []) as Array):
		if not sg in out:
			out.append(sg)
	return out


func _sig_label(sigs: Array) -> String:
	## same one-word convention as the duel's _sig_label()
	if sigs.is_empty():
		return ""
	return str(_sig_short.get(sigs[0], str(sigs[0]).to_upper()))


func _sig_word(sg) -> String:
	return str(_sig_short.get(sg, str(sg).to_upper().replace("_", " ")))


# ==================================================================
# Layout — every size is derived from the viewport, nothing hardcoded
# ==================================================================
func _vp() -> Vector2:
	if _panel != null:
		return _panel.get_viewport_rect().size
	return Vector2(1280, 720)


func _s() -> float:
	var vp := _vp()
	return minf(vp.x / 1280.0, vp.y / 720.0)


func _fs(px: int) -> int:
	## Routed through the game-wide type scale. The old body floored at 11, which quietly
	## made every "small" label in the breach a whole rung bigger than the rest of the game
	## (_s() is always 1.0 under canvas_items stretch, so the floor was the only thing it did).
	return UITheme.fs(px, _s())


func _fit(txt: String, max_w: float, want_px: int, floor_px: int = 8) -> int:
	## Shrink a label until it actually FITS its box. Sizing text off the card height
	## alone let long names ("OVERCLOCK DAEMON") run straight over the stat row when the
	## cards got small — always measure the string, never assume.
	var px: int = maxi(want_px, floor_px)
	while px > floor_px and _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
		px -= 1
	return px


func _wrap(txt: String, max_w: float, px: int) -> Array:
	## Word-wrap measured with the real font metrics, returning the LINES. A plain
	## width/box ratio UNDER-counts real wrapping, and every caller below fed that estimate
	## to draw_multiline_string as its max_lines — where an under-count silently truncates
	## the tail instead of drawing it.
	var out: Array = []
	var line := ""
	for word in txt.split(" ", false):
		var cand: String = word if line == "" else line + " " + word
		if line == "" or _font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= max_w:
			line = cand
		else:
			out.append(line)
			line = word
	if line != "":
		out.append(line)
	return out


func _grid() -> Dictionary:
	var vp := _vp()
	var s := _s()
	var n: int = maxi(card_ids.size(), 1)
	var cols: int = mini(n, MAX_COLS)
	var rows: int = int(ceil(float(n) / float(cols)))
	var gx := 20.0 * s
	var gy := 18.0 * s if rows == 1 else 44.0 * s           # extra room for row-2 index keys
	var sig_h := 52.0 * s                                   # room for 2 sigil words per card
	var top := 100.0 * s                                    # title band + the [n] key row
	var bot := 52.0 * s                                     # hint band
	if cost_note != "":
		# reserve the note's REAL wrapped height (same 0.66 box as _on_draw) so a long
		# rig explanation pushes the cards up instead of landing on top of them
		bot += _font.get_multiline_string_size(cost_note, HORIZONTAL_ALIGNMENT_CENTER,
			vp.x * 0.66, _fs(11)).y + 16.0 * s
	var avail_w := vp.x * 0.92
	var avail_h := maxf(vp.y - top - bot, 120.0 * s)
	var cw := (avail_w - gx * (cols - 1)) / float(cols)
	var ch := cw / ASPECT
	var row_h := avail_h / float(rows) - gy
	if ch + sig_h > row_h:
		ch = maxf(row_h - sig_h, 72.0 * s)
	# never let a 2-3 card row balloon to fill the screen
	ch = minf(ch, vp.y * (0.46 if rows == 1 else 0.31))
	cw = ch * ASPECT
	var pitch := ch + sig_h + gy
	var y0 := top + maxf((avail_h - (pitch * rows - gy)) * 0.5, 0.0)
	return {"cols": cols, "rows": rows, "cw": cw, "ch": ch, "gx": gx,
		"pitch": pitch, "y0": y0, "sig_h": sig_h, "s": s, "vp": vp}


func _base_rect(i: int, g: Dictionary) -> Rect2:
	var cols: int = g["cols"]
	var row: int = i / cols
	var col: int = i % cols
	var in_row: int = mini(cols, card_ids.size() - row * cols)
	var cw: float = g["cw"]
	var gx: float = g["gx"]
	var w := in_row * cw + (in_row - 1) * gx
	var x0: float = ((g["vp"] as Vector2).x - w) * 0.5
	return Rect2(Vector2(x0 + col * (cw + gx), float(g["y0"]) + row * float(g["pitch"])),
		Vector2(cw, float(g["ch"])))


func _card_rect(i: int, g: Dictionary) -> Rect2:
	var r := _base_rect(i, g)
	if i == _hover:
		r.position.y -= 14.0 * float(g["s"])     # the hovered card lifts out of the row
	return r


func _hit(m: Vector2) -> int:
	var g := _grid()
	for i in card_ids.size():
		if _card_rect(i, g).grow(4.0 * float(g["s"])).has_point(m):
			return i
	return -1


# ==================================================================
# Drawing
# ==================================================================
func _on_draw() -> void:
	var g := _grid()
	var vp: Vector2 = g["vp"]
	var s: float = g["s"]
	# backdrop: a vertical gradient rather than a flat wash — a touch of hull navy up top,
	# near-black at the floor, so the card row reads as lit from above. Blacks stay black.
	var top_c := Color(0.016, 0.030, 0.052, 0.84)
	var bot_c := Color(0.003, 0.007, 0.016, 0.93)
	_panel.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vp.x, 0.0), Vector2(vp.x, vp.y),
		Vector2(0.0, vp.y)]), PackedColorArray([top_c, top_c, bot_c, bot_c]))
	# hairline frame + corner ticks: an edge for the modal without a bright panel
	var ins := Rect2(Vector2(11.0 * s, 11.0 * s), vp - Vector2(22.0 * s, 22.0 * s))
	_panel.draw_rect(ins, Color(CYAN.r, CYAN.g, CYAN.b, 0.09), false, 1.0)
	var tick := 28.0 * s
	var tcol := Color(CYAN.r, CYAN.g, CYAN.b, 0.30)
	for cn in [[ins.position, 1.0, 1.0], [Vector2(ins.end.x, ins.position.y), -1.0, 1.0],
		[Vector2(ins.position.x, ins.end.y), 1.0, -1.0], [ins.end, -1.0, -1.0]]:
		var cp: Vector2 = cn[0]
		_panel.draw_line(cp, cp + Vector2(tick * float(cn[1]), 0.0), tcol, 1.0)
		_panel.draw_line(cp, cp + Vector2(0.0, tick * float(cn[2])), tcol, 1.0)
	# title band — shrink-to-fit, because a rig title is a whole clause
	var ttl := title.to_upper()
	_panel.draw_string(_font, Vector2(0, 40.0 * s), ttl,
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, _fit(ttl, vp.x * 0.86, _fs(16)), CYAN)
	# the rule under the title fades out at both ends instead of stopping dead
	var ly := 54.0 * s
	var hw := 230.0 * s
	var mid := Color(CYAN.r, CYAN.g, CYAN.b, 0.42)
	var off := Color(CYAN.r, CYAN.g, CYAN.b, 0.0)
	_panel.draw_polygon(PackedVector2Array([Vector2(vp.x * 0.5 - hw, ly),
		Vector2(vp.x * 0.5, ly - 1.0), Vector2(vp.x * 0.5 + hw, ly), Vector2(vp.x * 0.5, ly + 1.0)]),
		PackedColorArray([off, mid, off, mid]))
	# cards: unhovered first so the lifted one overlaps its neighbours
	for i in card_ids.size():
		if i != _hover:
			_draw_card(i, g)
	if _hover >= 0 and _hover < card_ids.size():
		_draw_card(_hover, g)
	# note + hint
	var fy := vp.y - 20.0 * s
	var hps := _fs(9)
	if cost_note != "":
		# a rig's note is a whole sentence. Measure the WRAPPED block (never a line-count
		# guess), shrink it until it fits two lines, then sit it on the hint row. max_lines
		# is unlimited so an unexpected third line still draws instead of clipping.
		var nw := vp.x * 0.66
		var nps := _fs(11)
		var nsz := _font.get_multiline_string_size(cost_note, HORIZONTAL_ALIGNMENT_CENTER, nw, nps)
		while nps > 8 and nsz.y > float(nps) * 2.7:
			nps -= 1
			nsz = _font.get_multiline_string_size(cost_note, HORIZONTAL_ALIGNMENT_CENTER, nw, nps)
		var nb := fy - float(hps) - 14.0 * s          # bottom edge of the note block
		_panel.draw_multiline_string(_font, Vector2((vp.x - nw) * 0.5, nb - nsz.y + float(nps)),
			cost_note, HORIZONTAL_ALIGNMENT_CENTER, nw, nps, -1, AMBER)
	if allow_cancel:
		# explicit SKIP button — walking away shouldn't require guessing that ESC works.
		# Deliberately quiet: it must never compete with the cards for the eye.
		var sr := _skip_rect()
		var s_hot: bool = sr.has_point(_panel.get_local_mouse_position())
		_panel.draw_polygon(PackedVector2Array([sr.position, Vector2(sr.end.x, sr.position.y),
			sr.end, Vector2(sr.position.x, sr.end.y)]),
			PackedColorArray([Color(0.05, 0.08, 0.12, 0.90), Color(0.05, 0.08, 0.12, 0.90),
			Color(0.02, 0.03, 0.05, 0.90), Color(0.02, 0.03, 0.05, 0.90)]))
		_panel.draw_rect(sr, Color(AMBER.r, AMBER.g, AMBER.b, 0.85) if s_hot
			else Color(CYAN.r, CYAN.g, CYAN.b, 0.26), false, 1.0)
		_panel.draw_string(_font, sr.position + Vector2(0, sr.size.y * 0.66), "SKIP",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, _fs(11),
			AMBER if s_hot else Color(0.56, 0.65, 0.76))
	if _info >= 0 and _info < card_ids.size():
		_draw_info(_info)
	var hint := "click a card   ·   1-%d picks   ·   right-click reads a card" % mini(card_ids.size(), 9)
	if allow_cancel:
		hint += "   ·   ESC or SKIP walks away"
	_panel.draw_string(_font, Vector2(0, fy), hint, HORIZONTAL_ALIGNMENT_CENTER, vp.x, hps,
		Color(CYAN.r, CYAN.g, CYAN.b, 0.40))


func _draw_card(i: int, g: Dictionary) -> void:
	var s: float = g["s"]
	var base := _base_rect(i, g)
	var r := _card_rect(i, g)
	var id := str(card_ids[i])
	var sigs := _sigils_of(id)
	var hot: bool = i == _hover
	var dim: bool = _hover >= 0 and not hot
	# drop shadow so a lifted card reads as lifted
	if hot:
		_panel.draw_rect(Rect2(r.position + Vector2(0, 8.0 * s), r.size), Color(0, 0, 0, 0.45))
	_panel.draw_rect(r, Color(0.03, 0.045, 0.07))
	# portrait (same inset as the duel hand card)
	var prect := Rect2(r.position + r.size * Vector2(0.13, 0.09), r.size * Vector2(0.74, 0.56))
	var port: Texture2D = _tex.get(_portrait_of(id))
	var lit := Color(1.25, 1.25, 1.25) if hot else Color(1, 1, 1)
	if port != null:
		_panel.draw_texture_rect(port, prect, false, lit)
	else:
		_panel.draw_rect(prect, Color(0.07, 0.11, 0.16))
		_panel.draw_rect(prect, Color(CYAN.r, CYAN.g, CYAN.b, 0.22), false, 1.0)
		_panel.draw_string(_font, prect.position + Vector2(0, prect.size.y * 0.66), "?",
			HORIZONTAL_ALIGNMENT_CENTER, prect.size.x, _fs(int(prect.size.y * 0.42 / s)),
			Color(0.38, 0.52, 0.68))
	# frame
	var frame: Texture2D = _tex.get("card_frame")
	if frame != null:
		_panel.draw_texture_rect(frame, r, false, Color(1.4, 1.4, 1.4) if hot else Color(1, 1, 1))
	else:
		_panel.draw_rect(r, CYAN if hot else Color(CYAN.r, CYAN.g, CYAN.b, 0.45), false, 2.0)
	# name / in-frame sigil / stats — same placement as _hud_card(); the sigil word is a
	# touch smaller than the duel's 0.07 because these cards are drawn much larger.
	# Card-face type does NOT go through _fs() — same reason breach_duel3d keeps a separate
	# _card_fs(). _fs() floors at the game-wide legibility minimum, and that floor is TALLER
	# than the 0.087·h step from the name down to the sigil word once a 12-14 card offer
	# (CODE SPLICER hands the picker every sigil-bearing card in the deck, unsliced) drops
	# the cards to ~85 px. Name, sigil word and the stat digits then all landed in the same
	# band. Size off the CARD, floor at 5, then shrink to fit the width as before; at the
	# 3-6 card sizes this returns exactly what _fs() returned, so nothing approved moves.
	var nm := _name_of(id)
	var inner := r.size.x * 0.74            # frame art eats the outer margins
	_panel.draw_string(_font, r.position + Vector2(0, r.size.y * 0.755), nm,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, _fit(nm, inner, maxi(int(r.size.y * 0.045), 5), 5),
		Color(0.88, 0.94, 1.0) if hot else Color(0.72, 0.82, 0.94))
	if not sigs.is_empty():
		var sl := _sig_label(sigs)
		_outlined(r.position + Vector2(0, r.size.y * 0.842), sl, r.size.x,
			_fit(sl, inner, maxi(int(r.size.y * 0.037), 5), 5), Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	var fs := _fit("00", r.size.x * 0.15, _fs(int(r.size.y * 0.085 / s)))
	var atk := _atk_of(id)
	_stat(r.position + Vector2(r.size.x * 0.08, r.size.y * 0.94), str(atk),
		AMBER if int(power_bonus.get(id, 0)) == 0 else Color(1.0, 0.9, 0.45), fs)
	_stat(r.position + Vector2(r.size.x * 0.76, r.size.y * 0.94), str(_hp_of(id)), CYAN, fs)
	# energy cost disc, top-left
	var cost := _cost_of(id)
	if cost > 0:
		var cc := r.position + Vector2(r.size.x * 0.15, r.size.y * 0.10)
		var rad := r.size.y * 0.058
		var acc := Color(0.5, 0.82, 1.0)
		_panel.draw_circle(cc, rad, Color(0.02, 0.05, 0.09, 0.9))
		_panel.draw_arc(cc, rad, 0.0, TAU, 20, acc, 1.5)
		var cps := _fit(str(cost), rad * 1.5, _fs(int(rad * 1.15 / s)))
		_panel.draw_string(_font, cc + Vector2(-rad * 0.42, rad * 0.44), str(cost),
			HORIZONTAL_ALIGNMENT_LEFT, -1, cps, acc)
	# attack-direction glyph, top-right
	if atk > 0:
		_dir_glyph(r.position + Vector2(r.size.x * 0.85, r.size.y * 0.10), r.size.y * 0.05, sigs)
	if dim:
		_panel.draw_rect(r, Color(0.0, 0.02, 0.05, 0.34))
	# ---- selection chrome -------------------------------------------------
	# the frames are art, so the selected state is a halo AROUND the card plus a lit key
	# chip — nothing is drawn over the frame itself
	if hot:
		for k2 in 5:
			# thin rings with a squared falloff read as a glow; fat overlapping rings
			# just read as a grey slab around the card
			_panel.draw_rect(r.grow((3.0 + float(k2) * 4.5) * s),
				Color(CYAN.r, CYAN.g, CYAN.b, 0.20 * pow(1.0 - float(k2) / 5.0, 2.0)),
				false, maxf(2.5 * s, 1.5))
		_panel.draw_rect(r.grow(3.0 * s), CYAN, false, maxf(2.0 * s, 1.5))
	else:
		_panel.draw_rect(r.grow(2.0 * s), Color(CYAN.r, CYAN.g, CYAN.b, 0.13), false, 1.0)
	# index key, pinned above the resting slot so it never moves
	if i < 9:
		var kfs := _fs(11)
		var ky := base.position.y - 20.0 * s
		if hot:
			var kw := float(kfs) * 3.2
			var chip := Rect2(base.position.x + (base.size.x - kw) * 0.5, ky - float(kfs) * 0.98,
				kw, float(kfs) * 1.42)
			_panel.draw_rect(chip, Color(0.04, 0.09, 0.15, 0.95))
			_panel.draw_rect(chip, Color(CYAN.r, CYAN.g, CYAN.b, 0.75), false, 1.0)
		_panel.draw_string(_font, Vector2(base.position.x, ky), "[ %d ]" % (i + 1),
			HORIZONTAL_ALIGNMENT_CENTER, base.size.x, kfs,
			CYAN if hot else Color(0.42, 0.54, 0.66))
	# ---- sigils in words, under the card ----------------------------------
	var wy := base.end.y + 16.0 * s
	if sigs.is_empty():
		_panel.draw_string(_font, Vector2(base.position.x, wy), "— no sigil —",
			HORIZONTAL_ALIGNMENT_CENTER, base.size.x,
			_fit("— no sigil —", base.size.x, _fs(11), 7), Color(0.34, 0.42, 0.52))
	else:
		for k in sigs.size():
			var wcol := AMBER if hot else Color(AMBER.r, AMBER.g, AMBER.b, 0.58)
			# CONFIRMED CLIP (screenshot at 14 cards): these are the words you read the offer
			# by, and draw_string HARD-CLIPS at its width rather than overflowing it — the
			# words were being cut to "OVERCL" / "DETONA" / "INTERCE" / "OVERFL" with nothing
			# on screen to say they had been. Measure against the card's own width.
			var wd := _sig_word(sigs[k])
			_panel.draw_string(_font, Vector2(base.position.x, wy + k * 15.0 * s), wd,
				HORIZONTAL_ALIGNMENT_CENTER, base.size.x, _fit(wd, base.size.x, _fs(11), 7), wcol)


func _stat(pos: Vector2, txt: String, col: Color, fs: int) -> void:
	_panel.draw_string(_font, pos + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(0, 0, 0, 0.7))
	_panel.draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# --- attack-direction glyph (same shapes as the duel's baked _arrow_tex) -----
func _arrow_kind(sigs: Array) -> String:
	if "split_bore" in sigs:
		return "fork"
	if "targeting_laser" in sigs:
		return "target"
	if "chain_load" in sigs:
		return "chain"
	return "straight"


func _mk_arrow(cx: float, cy: float, scale: float, ang: float) -> PackedVector2Array:
	var base := [Vector2(0, -1.0), Vector2(-0.68, -0.05), Vector2(-0.26, -0.05),
		Vector2(-0.26, 0.9), Vector2(0.26, 0.9), Vector2(0.26, -0.05), Vector2(0.68, -0.05)]
	var ca := cos(ang)
	var sa := sin(ang)
	var pts := PackedVector2Array()
	for b in base:
		var v: Vector2 = b * scale
		pts.append(Vector2(cx + v.x * ca - v.y * sa, cy + v.x * sa + v.y * ca))
	return pts


func _dir_glyph(ctr: Vector2, sz: float, sigs: Array) -> void:
	## the duel bakes this into a 64px texture; here we stroke it straight onto the
	## HUD (same 64-unit geometry, mapped into a box of side sz*3.4 around ctr).
	var d := sz * 3.4
	var c := 32.0
	var h := 25.6
	var polys: Array = []
	match _arrow_kind(sigs):
		"fork":
			polys = [_mk_arrow(c - h * 0.42, c + h * 0.1, h * 0.8, -0.6),
				_mk_arrow(c + h * 0.42, c + h * 0.1, h * 0.8, 0.6)]
		"chain":
			polys = [_mk_arrow(c - h * 0.85, c, h * 0.62, 0.0),
				_mk_arrow(c, c, h * 0.62, 0.0), _mk_arrow(c + h * 0.85, c, h * 0.62, 0.0)]
		"target":
			polys = [_mk_arrow(c, c + h * 0.28, h * 0.82, 0.0)]
			var circ := PackedVector2Array()
			for i in 18:
				var a := TAU * i / 18.0
				circ.append(Vector2(c + cos(a) * h * 0.32, c - h * 0.92 + sin(a) * h * 0.32))
			polys.append(circ)
		_:
			polys = [_mk_arrow(c, c, h, 0.0)]
	var k := d / 64.0
	for poly in polys:
		var pts := PackedVector2Array()
		for p in poly:
			pts.append(ctr + (Vector2(p) - Vector2(c, c)) * k)
		var closed := pts.duplicate()
		closed.append(pts[0])
		_panel.draw_polyline(closed, Color(0, 0, 0, 0.9), maxf(2.4 * k, 1.0))
		_panel.draw_colored_polygon(pts, Color(1, 1, 1, 1))


# ==================================================================
# Input — mouse through the modal Control, keys through _input
# ==================================================================
func _on_gui_input(e: InputEvent) -> void:
	if _done:
		return
	if e is InputEventMouseMotion:
		var h := _hit(e.position)
		if h >= 0 and h != _hover:
			_hover = h
			_panel.queue_redraw()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if _skip_rect().has_point(e.position):
				_cancel()                     # the explicit SKIP button
			else:
				var h := _hit(e.position)
				if h >= 0:
					_pick(h)
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			# right-click INSPECTS instead of closing — the captain wants to read a card
			# without losing the offer
			var h2 := _hit(e.position)
			_info = -1 if (h2 < 0 or h2 == _info) else h2
			_panel.queue_redraw()
		_panel.accept_event()


func _outlined(pos: Vector2, txt: String, w: float, px: int, col: Color, align: int) -> void:
	## white-on-black-stroke: sigil words must stay readable over any portrait art
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			_panel.draw_string(_font, pos + Vector2(dx, dy), txt, align, w, px, Color(0, 0, 0, 0.95))
	_panel.draw_string(_font, pos, txt, align, w, px, col)


func _draw_info(i: int) -> void:
	## right-click rules card: name, stats, each sigil + its rule wrapped, lore. Sized to
	## its content and parked beside the card so the offer stays visible.
	var id: String = str(card_ids[i])
	var g := _grid()
	var r := _card_rect(i, g)
	var s := _s()
	var vp := _vp()
	var sigs := _sigils_of(id)
	var w := minf(vp.x * 0.28, 400.0 * s)
	var pad := 15.0 * s
	var tps := _fs(13)
	var bps := _fs(11)
	# measure first: the panel is as tall as its wrapped content, never a fixed rect.
	# "d" is a rule, drawn not written — it separates the header from the sigil rules.
	var lines: Array = []
	lines.append(["t", _name_of(id)])
	lines.append(["s", "%d POWER   ·   %d HP   ·   %d ENERGY" % [_atk_of(id), _hp_of(id), _cost_of(id)]])
	for sg in sigs:
		lines.append(["d", ""])
		lines.append(["g", str(_sig_short.get(sg, str(sg))).to_upper()])
		lines.append(["b", str(_sig_rules.get(sg, "—"))])
	if _lore.has(_name_of(id)):
		lines.append(["d", ""])
		lines.append(["l", str(_lore[_name_of(id)])])
	var inner := w - pad * 2.0
	var h := pad
	for ln in lines:
		h += _info_h(str(ln[0]), str(ln[1]), inner, tps, bps, s)
	h += pad
	var px0: float = clampf(r.end.x + 14.0 * s, 0.0, vp.x - w - 8.0)
	if r.end.x + 14.0 * s + w > vp.x:
		px0 = maxf(r.position.x - w - 14.0 * s, 8.0)
	var box := Rect2(px0, clampf(r.position.y, 8.0, maxf(vp.y - h - 8.0, 8.0)), w, h)
	_panel.draw_polygon(PackedVector2Array([box.position, Vector2(box.end.x, box.position.y),
		box.end, Vector2(box.position.x, box.end.y)]),
		PackedColorArray([Color(0.030, 0.055, 0.090, 0.97), Color(0.030, 0.055, 0.090, 0.97),
		Color(0.008, 0.016, 0.028, 0.97), Color(0.008, 0.016, 0.028, 0.97)]))
	_panel.draw_rect(box, Color(CYAN.r, CYAN.g, CYAN.b, 0.42), false, 1.0)
	var y := box.position.y + pad
	for ln in lines:
		var kind: String = str(ln[0])
		var txt: String = str(ln[1])
		var px: int = tps if kind == "t" else bps
		var step := _info_h(kind, txt, inner, tps, bps, s)
		if kind == "d":
			_panel.draw_line(Vector2(box.position.x + pad, y + step * 0.5),
				Vector2(box.end.x - pad, y + step * 0.5), Color(CYAN.r, CYAN.g, CYAN.b, 0.16), 1.0)
			y += step
			continue
		var col := CYAN
		if kind == "s":
			col = Color(0.78, 0.86, 0.96)
		elif kind == "g":
			col = Color(1, 1, 1)
		elif kind == "b":
			col = Color(0.72, 0.80, 0.90)
		elif kind == "l":
			col = Color(0.50, 0.58, 0.70)
		var asc := _font.get_ascent(px)
		if kind == "g":
			_outlined(Vector2(box.position.x + pad, y + asc), txt, inner, px, col,
				HORIZONTAL_ALIGNMENT_LEFT)
		else:
			_panel.draw_multiline_string(_font, Vector2(box.position.x + pad, y + asc), txt,
				HORIZONTAL_ALIGNMENT_LEFT, inner, px, -1, col)
		y += step


func _info_h(kind: String, txt: String, inner: float, tps: int, bps: int, s: float) -> float:
	## one place decides a row's height, so the measured box and the drawn rows can never
	## disagree — that mismatch is what made the old panel look crumbled
	if kind == "d":
		return 13.0 * s
	var px: int = tps if kind == "t" else bps
	# get_multiline_string_size wraps at exactly the width draw_multiline_string will use,
	# so the measured height IS the drawn height — no guessing at line counts
	return _font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, inner, px).y \
		+ (9.0 * s if kind == "t" else 5.0 * s)


func _skip_rect() -> Rect2:
	var vp := _vp()
	var s := _s()
	var w := 108.0 * s
	var h := 27.0 * s
	return Rect2(vp.x - w - 24.0 * s, vp.y - h - 20.0 * s, w, h)


func _input(e: InputEvent) -> void:
	## _input runs before GUI focus, and the picker is meant to be the LAST child of
	## its parent, so it sees keys first; everything it uses is marked handled.
	if _done or _panel == null:
		return
	if not (e is InputEventKey) or not e.pressed or e.is_echo():
		return
	var ek := e as InputEventKey
	# the breach map reads physical_keycode; honour whichever one carries a digit so a
	# non-US layout can still press 1-6
	var k: int = ek.keycode
	if not _is_useful(k) and _is_useful(ek.physical_keycode):
		k = ek.physical_keycode
	var handled := true
	if k == KEY_ESCAPE:
		_cancel()                     # swallowed anyway when allow_cancel is false
	elif k >= KEY_1 and k <= KEY_9:
		_pick_key(k - KEY_1)
	elif k >= KEY_KP_1 and k <= KEY_KP_9:
		_pick_key(k - KEY_KP_1)
	elif k == KEY_LEFT or k == KEY_UP:
		_move_hover(-1)
	elif k == KEY_RIGHT or k == KEY_DOWN:
		_move_hover(1)
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		if _hover >= 0 and _hover < card_ids.size():
			_pick(_hover)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _is_useful(k: int) -> bool:
	return k == KEY_ESCAPE or (k >= KEY_1 and k <= KEY_9) or (k >= KEY_KP_1 and k <= KEY_KP_9) \
		or k == KEY_LEFT or k == KEY_RIGHT or k == KEY_UP or k == KEY_DOWN \
		or k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE


func _pick_key(idx: int) -> void:
	if idx >= 0 and idx < card_ids.size():
		_pick(idx)


func _move_hover(d: int) -> void:
	if card_ids.is_empty():
		return
	_hover = posmod(_hover + d, card_ids.size())
	_panel.queue_redraw()


func _pick(i: int) -> void:
	if _done:
		return
	_done = true
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chosen.emit(i)
	queue_free()


func _cancel() -> void:
	if _done or not allow_cancel:
		return
	_done = true
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cancelled.emit()
	queue_free()
