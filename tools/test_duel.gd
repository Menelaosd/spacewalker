extends Node
## Headless logic test for breach_duel3d.gd (the Act-3 energy duel) — drives the
## state machine directly, no clicks, no rendering.
## Run: godot --headless --path . res://tools/test_duel.tscn

var fails := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  PASS  ", what)
	else:
		fails += 1
		print("  FAIL  ", what)


func _count(arr: Array) -> int:
	var n := 0
	for x in arr:
		if x != null:
			n += 1
	return n


func _ready() -> void:
	var duel = load("res://scripts/breach_duel3d.gd").make(1)
	add_child(duel)

	print("-- setup --")
	_check(duel.hand.size() == 4, "opening hand is 3 deck cards + 1 scrap mite")
	_check(duel.phase == duel.Phase.MAIN, "turn 1 skips the draw (hand just dealt)")
	_check(duel.energy == 1 and duel.energy_max == 1, "turn 1 energy is 1/1")
	_check(_count(duel.queue) == 1, "HELIOS telegraphs 1 unit (tier 1)")
	_check(duel.LANES == 5, "Act 3 board is 5 lanes")

	print("-- energy costs --")
	duel.hand = ["scrap_mite", "power_siphon", "buckler_mite", "prism_ripper"]
	duel._sel = 0
	duel._place_selected(0)
	_check(duel.you[0] != null and duel.you[0]["id"] == "scrap_mite", "vessel placed lane 0")
	_check(duel.energy == 0, "vessel cost 1 energy (Act 3 rule: not free)")
	_check(not duel._can_afford("prism_ripper"), "5-cost ripper unaffordable at 0 energy")

	print("-- battery bearer --")
	duel.energy = 2
	duel.energy_max = 2
	duel._sel = 0   # conduit
	duel._place_selected(1)
	_check(duel.energy_max == 3, "battery bearer grew max energy to 3")
	_check(duel.energy == 1, "+1 current, then 2 cost deducted (resolves before cost)")

	print("-- nano armor --")
	duel.energy = 3
	duel._sel = 0   # shieldbot
	duel._place_selected(2)
	_check(bool(duel.you[2].get("armor", false)), "shieldbot deployed with armor up")
	var died: bool = duel._hit_unit(duel.you[2], 5, 2, 2)
	_check(not died and int(duel.you[2]["hp"]) == 1, "armor ate the first hit fully")
	died = duel._hit_unit(duel.you[2], 1, 2, 2)
	_check(died, "second hit lands — armor is single-use")
	duel.you[2] = null

	print("-- strike pass --")
	duel.you[3] = {"id": "prism_ripper", "hp": 2, "armor": false}
	var tip0: int = duel.tip
	var opp_front0: int = _count(duel.opp)
	duel.phase = duel.Phase.STRIKING
	duel._strike_lane = -1
	for _i in duel.LANES + 1:
		duel._advance_strike()
		if duel.phase != duel.Phase.STRIKING:
			break
	# lanes 0 (mite, 0 atk), 1 (conduit, 0 atk), 3 (ripper 3 atk) — only lanes with
	# no blocker send damage to the trace
	_check(duel.tip >= tip0 + 3 - opp_front0 * 3, "unblocked attacks tipped the trace")
	_check(duel.phase == duel.Phase.OPP_TURN, "strike hands over to HELIOS")

	print("-- HELIOS turn (queue advances FIRST, then strikes, then telegraphs) --")
	for _i in duel.LANES + 8:
		duel._advance_opp()
		if duel.phase != duel.Phase.OPP_TURN:
			break
	_check(_count(duel.opp) >= 1, "queued unit advanced to the front line")
	_check(_count(duel.queue) == 1, "a new unit was telegraphed into the queue")
	_check(duel.phase == duel.Phase.DRAW, "back to player DRAW")
	_check(duel.energy == duel.energy_max and duel.energy_max == 4,
		"turn start: max +1 (3->4) and full refill")

	print("-- overkill spill --")
	duel.you[4] = {"id": "prism_ripper", "hp": 2, "armor": false}      # 3 atk
	duel.opp[4] = {"id": "sentry_ice", "hp": 1, "armor": false}      # dies, 2 excess
	duel.queue[4] = {"id": "packet_daemon", "hp": 2, "armor": false}    # eats the spill
	var tip1: int = duel.tip
	duel.phase = duel.Phase.STRIKING
	duel._strike_lane = 3
	duel._advance_strike()
	_check(duel.opp[4] == null, "front blocker killed")
	_check(duel.queue[4] == null, "overkill spilled into the queued unit")
	_check(duel.tip == tip1, "no overkill ever leaks to the scale")

	print("-- win / lose --")
	duel.tip = duel.WIN_TIP
	duel._check_over()
	_check(duel.phase == duel.Phase.OVER and duel._won, "tip +5 = node cracked")
	var duel2 = load("res://scripts/breach_duel3d.gd").make(3)
	add_child(duel2)
	duel2.tip = -duel2.WIN_TIP
	duel2._check_over()
	_check(duel2.phase == duel2.Phase.OVER and not duel2._won, "tip -5 = ejected")
	_check(_count(duel2.queue) == 2, "tier 3 telegraphs 2 units per turn")

	print("RESULT: %s (%d fails)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
