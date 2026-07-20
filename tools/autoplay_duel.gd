extends Control
## QA AUTOPLAY HARNESS for breach_duel.gd — synthesizes real InputEventMouseButton
## clicks through duel._gui_input and screenshots after every action.
## Run windowed:  <godot> --path . res://tools/autoplay_duel.tscn

const SHOT_DIR := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/cf45e486-8764-4be3-bb51-d6dafa43276d/scratchpad/frames"
const MAX_ACTIONS := 45
const MAX_SECONDS := 90.0
const TICK := 0.5

var duel   # untyped on purpose: breach_duel.gd has no class_name; dynamic access
var actions := 0
var elapsed := 0.0
var accum := 0.0
var busy := false
var done := false
var over_clicked := false
var last_phase := -1
var same_phase_waits := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	duel = load("res://scripts/breach_duel.gd").make(1)
	add_child(duel)
	duel.finished.connect(func(won: bool) -> void:
		print("[AUTO] SIGNAL finished(won=%s) received" % won))
	print("[AUTO] duel started, tier=%d, phase=%s, hand=%s" % [duel.tier, _pn(duel.phase), str(duel.hand)])

func _process(delta: float) -> void:
	if done:
		return
	elapsed += delta
	if elapsed > MAX_SECONDS:
		print("[AUTO] TIME CAP %.0fs hit after %d actions — phase=%s tip=%d" % [MAX_SECONDS, actions, _pn(duel.phase), duel.tip])
		_finish()
		return
	accum += delta
	if accum >= TICK and not busy:
		accum = 0.0
		_run_tick()

func _run_tick() -> void:
	busy = true
	await _do_tick()
	busy = false

func _do_tick() -> void:
	if done:
		return
	if actions >= MAX_ACTIONS:
		print("[AUTO] ACTION CAP %d hit — phase=%s tip=%d" % [MAX_ACTIONS, _pn(duel.phase), duel.tip])
		_finish()
		return
	var P: Dictionary = duel.Phase
	var ph: int = duel.phase
	# stuck watchdog: count consecutive waits in the same actionless phase
	if ph == P.STRIKING or ph == P.OPP_TURN:
		if ph == last_phase:
			same_phase_waits += 1
		else:
			same_phase_waits = 0
		last_phase = ph
		print("[AUTO] ... waiting (%s, tip=%+d)" % [_pn(ph), duel.tip])
		if same_phase_waits > 20:
			print("[AUTO] STUCK: phase %s never advanced after %d waits" % [_pn(ph), same_phase_waits])
			_finish()
		return
	last_phase = ph
	same_phase_waits = 0

	if ph == P.OVER:
		if not over_clicked:
			over_clicked = true
			print("[AUTO] DUEL OVER — won=%s tip=%+d actions=%d elapsed=%.1fs" % [duel._won, duel.tip, actions, elapsed])
			await _click(get_viewport_rect().size * 0.5, "click on OVER screen (emits finished)")
			_finish()
		return

	if ph == P.DRAW:
		# if we hold no playable-for-free card, grab a mite (blood fodder / blocker)
		var have_free := false
		for id in duel.hand:
			if int(duel.CARDS[id][4]) == 0 and int(duel.CARDS[id][5]) <= duel.scrap:
				have_free = true
		if duel.mites_left > 0 and (not have_free or duel.deck.size() == 0):
			await _click(duel._mite_rect().get_center(), "DRAW scrap mite")
		elif duel.deck.size() > 0:
			await _click(duel._deck_rect().get_center(), "DRAW from deck")
		else:
			print("[AUTO] STUCK: DRAW phase, deck and mites both empty")
			_finish()
		return

	if ph == P.SACRIFICE:
		# prefer sacrificing units that are NOT blocking an enemy, weakest first
		var best := -1
		var best_key := 999
		for l in duel.LANES:
			if duel.you[l] != null and not duel._marked.has(l):
				var facing := 0 if (duel.opp[l] == null and duel.queue[l] == null) else 10
				var atk := int(duel.CARDS[duel.you[l]["id"]][2])
				if facing + atk < best_key:
					best_key = facing + atk
					best = l
		if best >= 0:
			await _click(duel._slot_rect(2, best).get_center(), "SACRIFICE mark lane %d" % best)
			return
		print("[AUTO] STUCK: SACRIFICE, no unmarked friendly units")
		_finish()
		return

	if ph == P.MAIN:
		if duel._sel >= 0:
			# prefer blocking a lane with an enemy in front row, then queue, then leftmost
			var pick := -1
			for l in duel.LANES:
				if duel.you[l] == null and duel.opp[l] != null:
					pick = l
					break
			if pick < 0:
				for l in duel.LANES:
					if duel.you[l] == null and duel.queue[l] != null:
						pick = l
						break
			if pick < 0:
				for l in duel.LANES:
					if duel.you[l] == null:
						pick = l
						break
			if pick >= 0:
				await _click(duel._slot_rect(2, pick).get_center(), "PLACE selected card in lane %d" % pick)
				return
			await _click(duel._bell_rect().get_center(), "BELL (card selected but no empty lane)")
			return
		var units := 0
		var empty := 0
		for u in duel.you:
			if u == null:
				empty += 1
			else:
				units += 1
		# pass 1: free / scrap cards
		for i in duel.hand.size():
			var c: Array = duel.CARDS[duel.hand[i]]
			if int(c[4]) == 0 and int(c[5]) <= duel.scrap and empty > 0:
				await _click(duel._hand_rect(i).get_center(), "SELECT hand[%d] %s (blood 0, scrap %d)" % [i, c[0], c[5]])
				return
		# pass 2: blood cards whenever we can pay
		for i in duel.hand.size():
			var c: Array = duel.CARDS[duel.hand[i]]
			var blood := int(c[4])
			if blood > 0 and units >= blood:
				await _click(duel._hand_rect(i).get_center(), "SELECT hand[%d] %s (blood %d)" % [i, c[0], blood])
				return
		await _click(duel._bell_rect().get_center(), "RING STRIKE BELL")
		return

	print("[AUTO] unknown phase %s" % _pn(ph))

func _click(pos: Vector2, label: String) -> void:
	actions += 1
	var before := _snap()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	duel._gui_input(ev)
	await RenderingServer.frame_post_draw
	var after := _snap()
	var dead := before.hash() == after.hash()
	print("[AUTO] #%02d %s @(%d,%d) | %s -> %s | tip=%+d scrap=%d hand=%d deck=%d mites=%d | \"%s\"%s"
		% [actions, label, int(pos.x), int(pos.y), _pn(before["phase"]), _pn(after["phase"]),
		after["tip"], after["scrap"], (after["hand"] as Array).size(), after["deck"], after["mites"],
		after["msg"], "  ** DEAD CLICK — no state change **" if dead else ""])
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/frame_%02d.png" % [SHOT_DIR, actions])

func _snap() -> Dictionary:
	var rows := []
	for arr in [duel.you, duel.opp, duel.queue]:
		var row := []
		for u in arr:
			row.append(null if u == null else [u["id"], u["hp"]])
		rows.append(row)
	return {
		"phase": duel.phase, "msg": duel._msg, "tip": duel.tip, "scrap": duel.scrap,
		"hand": duel.hand.duplicate(), "deck": duel.deck.size(), "mites": duel.mites_left,
		"sel": duel._sel, "marked": duel._marked.duplicate(),
		"you": rows[0], "opp": rows[1], "queue": rows[2],
	}

func _pn(p: int) -> String:
	for k in duel.Phase:
		if int(duel.Phase[k]) == p:
			return str(k)
	return str(p)

func _finish() -> void:
	if done:
		return
	done = true
	print("[AUTO] === RUN COMPLETE: %d actions, %.1fs, final phase=%s, tip=%+d, won=%s ==="
		% [actions, elapsed, _pn(duel.phase), duel.tip, duel._won])
	get_tree().quit()
