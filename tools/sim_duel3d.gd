extends Node3D
## HEADLESS SIM for breach_duel3d.gd — drives the real duel node through its own
## engine functions (no synthetic clicks) so every tier and every boss deck gets
## exercised. Purpose: catch runtime errors and non-terminating duels in the sigil
## paths, especially the HELIOS-side mirrors of necrosis / leech / airborne / drift.
##   <godot> --headless --path . res://tools/sim_duel3d.tscn
## Optional: SW_SIM_TIERS="1,2,3,4,5,6,7"  SW_SIM_RUNS=40

const MAX_TURNS := 60

var _tiers: Array = [1, 2, 3, 4, 5, 6, 7]
var _runs := 20
var _duel                     # untyped: breach_duel3d.gd has no class_name
var _ti := 0
var _run := 0
var _turns := 0
var _acted := false
var _wins := 0
var _losses := 0
var _stuck := 0
var _len_sum := 0
var _wall := 0.0
var _shot_dir := ""
var _shot_t := 0.0


func _ready() -> void:
	var tv := OS.get_environment("SW_SIM_TIERS")
	if tv != "":
		_tiers = []
		for p in tv.split(","):
			_tiers.append(int(p))
	var rv := OS.get_environment("SW_SIM_RUNS")
	if rv != "":
		_runs = int(rv)
	# the duel paces strikes with real-time timers (_strike_t), so a headless sweep runs at
	# wall-clock speed unless we wind the clock forward
	if OS.get_environment("SW_SIM_SHOT") != "":
		# ART CHECK mode: run one duel at real speed, fill the board, and screenshot it —
		# headless skips _draw()/3D entirely, so card portraits can only be verified live.
		_shot_dir = OS.get_environment("SW_SIM_SHOT")
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		_tiers = [int(OS.get_environment("SW_SIM_TIERS")) if OS.get_environment("SW_SIM_TIERS") != "" else 7]
		_runs = 1
		_start()
		return
	Engine.time_scale = 60.0
	Engine.max_fps = 0
	_start()


func _start() -> void:
	if _duel != null:
		_duel.queue_free()
		_duel = null
	if _ti >= _tiers.size():
		_report_tier_done(true)
		return
	_duel = load("res://scripts/breach_duel3d.gd").make(_tiers[_ti])
	add_child(_duel)
	_turns = 0
	_wall = 0.0
	_duel.finished.connect(_on_finished)


func _on_finished(won: bool) -> void:
	if won:
		_wins += 1
	else:
		_losses += 1
	_len_sum += _turns
	_next()


func _next() -> void:
	_run += 1
	if _run >= _runs:
		_report_tier_done(false)
		_run = 0
		_ti += 1
		_wins = 0
		_losses = 0
		_stuck = 0
		_len_sum = 0
	_start()


func _report_tier_done(final: bool) -> void:
	if _ti < _tiers.size():
		var n: int = maxi(1, _wins + _losses)
		print("[SIM] tier %d — %d runs: %d won / %d lost / %d stuck | mean %.1f turns"
			% [_tiers[_ti], _runs, _wins, _losses, _stuck, float(_len_sum) / float(n)])
	if final:
		print("[SIM] done")
		get_tree().quit()


func _process(dt: float) -> void:
	if _duel == null:
		return
	# WATCHDOG: the duel is a real-time state machine (STRIKING and OPP_TURN advance on
	# timers). If it stops handing control back, say WHICH phase it died in rather than
	# hanging the sweep.
	_wall += dt
	if _wall > 90.0:
		print("[SIM] STALL tier=%d run=%d phase=%d turn=%d you=%s opp=%s tip=%d"
			% [_tiers[_ti], _run, _duel.phase, _turns,
				_row(_duel.you), _row(_duel.opp), _duel.tip])
		_stuck += 1
		_bail()
		return
	# only act when it is waiting on the player
	var ph: int = _duel.phase
	if _shot_dir != "":
		# fill both boards with real cards, then hold and shoot — no bell, no strikes
		if _shot_t == 0.0:
			for l in range(5):
				_duel.energy = 9
				var pick := -1
				for i in _duel.hand.size():
					if int(_duel.CARDS[str(_duel.hand[i])][4]) <= _duel.energy:
						pick = i
						break
				if pick < 0 and _duel.deck.size() > 0:
					_duel._draw_card(_duel.deck.pop_back())
					pick = _duel.hand.size() - 1
				if pick >= 0 and _duel.you[l] == null:
					_duel._sel = pick
					_duel._place_selected(l)
			_duel._opp_fill_queue()
			for l in range(5):
				if _duel.opp[l] == null and _duel.queue[l] != null:
					_duel.opp[l] = _duel.queue[l]
					_duel.queue[l] = null
			_duel._opp_fill_queue()
			_duel.phase = 1
			_duel._inspect_id = str(_duel.hand[0]) if _duel.hand.size() > 0 else ""
			_duel._sel = -1
			_duel._sync_board()
		_shot_t += dt
		if _shot_t > 1.6:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_dir + "/duel_t%d.png" % _tiers[_ti])
			print("[SIM] shot -> duel_t%d.png" % _tiers[_ti])
			get_tree().quit()
		return
	if ph == 4:                                  # Phase.OVER — the result screen waits on a click
		if _duel._won:
			_wins += 1
		else:
			_losses += 1
		_bail()
		return
	if ph == 0:                                  # Phase.DRAW
		if _duel.deck.size() > 0:
			_duel._draw_card(_duel.deck.pop_back())
		elif _duel.mites_left > 0:
			_duel.mites_left -= 1
			_duel._draw_card(_duel.SIDE_ID)
		else:
			_stuck += 1
			_bail()
		return
	if ph == 1:                                  # Phase.MAIN
		_turns += 1
		if _turns > MAX_TURNS:
			_stuck += 1
			_bail()
			return
		# greedy: place whatever fits, cheapest first, into any empty lane
		var guard := 0
		while guard < 12:
			guard += 1
			var pick := -1
			var best := 99
			for i in _duel.hand.size():
				var id: String = str(_duel.hand[i])
				var c: int = int(_duel.CARDS[id][4])
				if c <= _duel.energy and c < best:
					best = c
					pick = i
			if pick < 0:
				break
			var lane := -1
			for l in range(5):
				if _duel.you[l] == null:
					lane = l
					break
			if lane < 0:
				break
			_duel._sel = pick
			_duel._place_selected(lane)
		# ring the bell
		_duel._sel = -1
		_duel.phase = 2                          # Phase.STRIKING
		_duel._strike_lane = -1
		_duel._strike_t = 0.01
		return


func _row(r: Array) -> String:
	var out: Array = []
	for x in r:
		out.append("__" if x == null else "%s/%d" % [str(x["id"]).substr(0, 6), int(x["hp"])])
	return "[" + ",".join(out) + "]"


func _bail() -> void:
	if _duel != null and _duel.finished.is_connected(_on_finished):
		_duel.finished.disconnect(_on_finished)
	_len_sum += _turns
	_next()
