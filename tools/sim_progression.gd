extends Node3D
## RUN-PROGRESSION SIM for THE BREACH.
##
## tools/sim_duel3d.gd answers "is tier N winnable in isolation". That is not the question a
## player asks. This answers the real one: playing the tiers a run actually presents, IN
## ORDER, carrying the same deck forward and drafting a card after each win — how far does a
## run get, and where does it die?
##
## It deliberately does NOT instantiate the map. Driving the real 3D map headlessly runs at
## ~0.1 fps (the scene is built for a camera, not a batch job), which makes a statistically
## useful sample impossible. The map's economy is therefore MODELLED here — that is a real
## limitation and results should be read as duel-chain balance, not full-run balance.
##
##   <godot> --headless --path . res://tools/sim_progression.tscn
## Optional: SW_PROG_RUNS=60  SW_PROG_DRAFT=1|0 (draft a card after each win; default 1)

# The tier a run meets at each battle node, in order. Rows 1-2 are FIREWALL (t1), the
# middle is SENTINEL (t2) and BOUNTY escalating with streak, the finale is the CORE boss.
# The REAL ladder. ROW_PLAN is access/gain/util/BATTLE/gain/util/BATTLE/gain/util/CORE —
# a run fights exactly THREE times, not eight. Row 3 is forced to FIREWALL (tier 1) by the
# 'r < 5' rule in _build_map_nodes; row 6 rolls firewall/sentinel/bounty; the core is now
# the tier-5 SOLAR WARDEN boss.
const LADDER := [1, 2, 5]
var _ladder: Array = LADDER.duplicate()

var _runs := 60
var _draft := true
var _run := 0
var _rung := 0
var _duel
var _turns := 0
var _wall := 0.0
var _deaths := {}          # rung index -> how many runs died there
var _cleared := 0
var _duels := 0
var _wins := 0


func _ready() -> void:
	var r := OS.get_environment("SW_PROG_RUNS")
	if r != "":
		_runs = int(r)
	if OS.get_environment("SW_PROG_DRAFT") == "0":
		_draft = false
	var lz := OS.get_environment("SW_PROG_LADDER")
	if lz != "":
		_ladder = []
		for x in lz.split(","):
			_ladder.append(int(x))
	Engine.time_scale = 60.0
	Engine.max_fps = 0
	_begin_run()


func _begin_run() -> void:
	var D = load("res://scripts/breach_duel3d.gd")
	D.run_deck = []
	D.atk_boost = {}
	D.graft = {}
	D.fragile = []
	_rung = 0
	_next_duel()


func _next_duel() -> void:
	if _duel != null:
		_duel.queue_free()
		_duel = null
	if _run >= _runs:
		_report()
		return
	if _rung >= _ladder.size():
		_cleared += 1
		_run += 1
		_begin_run()
		return
	_duel = load("res://scripts/breach_duel3d.gd").make(_ladder[_rung])
	add_child(_duel)
	_turns = 0
	_wall = 0.0


func _resolve(won: bool) -> void:
	_duels += 1
	var D = load("res://scripts/breach_duel3d.gd")
	if won:
		_wins += 1
		# the map hands you a card after a won node; model the draft so the deck grows
		# the way a real run's does
		if _draft:
			if D.run_deck.is_empty():
				D.run_deck = D.PLAYER_DECK.duplicate()
			var pool: Array = []
			for id in D.CARDS:
				if int(D.CARDS[id][4]) >= 1:      # cost >= 1 == player-obtainable
					pool.append(id)
			if not pool.is_empty():
				D.run_deck.append(pool[randi() % pool.size()])
		_rung += 1
	else:
		_deaths[_rung] = int(_deaths.get(_rung, 0)) + 1
		_run += 1
		_begin_run()
		return
	_next_duel()


func _process(dt: float) -> void:
	if _duel == null:
		return
	_wall += dt
	if _wall > 120.0:
		_resolve(false)          # count a hung duel as a loss rather than stalling the sweep
		return
	var ph: int = _duel.phase
	if ph == 4:
		_resolve(_duel._won)
		return
	if ph == 0:
		if _duel.deck.size() > 0:
			_duel._draw_card(_duel.deck.pop_back())
		elif _duel.mites_left > 0:
			_duel.mites_left -= 1
			_duel._draw_card(_duel.SIDE_ID)
		else:
			_resolve(false)
		return
	if ph == 1:
		_turns += 1
		if _turns > 60:
			_resolve(false)
			return
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
		_duel._sel = -1
		_duel.phase = 2
		_duel._strike_lane = -1
		_duel._strike_t = 0.01


func _report() -> void:
	print("[PROG] %d runs, ladder %s, draft=%s" % [_runs, str(_ladder), str(_draft)])
	print("[PROG] runs that reached the CORE and won it: %d (%.0f%%)"
		% [_cleared, 100.0 * float(_cleared) / float(maxi(_runs, 1))])
	print("[PROG] duels %d, won %d (%.0f%%)"
		% [_duels, _wins, 100.0 * float(_wins) / float(maxi(_duels, 1))])
	var surv := _runs
	for i in _ladder.size():
		var d: int = int(_deaths.get(i, 0))
		print("[PROG]   rung %d (tier %d): reached by %d, died %d  -> %.0f%% clear"
			% [i, _ladder[i], surv, d, 100.0 * float(surv - d) / float(maxi(surv, 1))])
		surv -= d
	get_tree().quit()
