extends SceneTree
## Functional gauntlet for the v1.7 audit fixes + core loop sanity.
## Run: godot --headless --path . -s tools/test_audit_v17.gd

var fails := 0


func ok(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		fails += 1


func _init() -> void:
	await process_frame   # autoloads exist after the first frame
	var gs = root.get_node("/root/GameState")

	# --- SOLA blackout: ore, veins and chunk tallies all halve together ---
	gs.new_game(2)
	gs.rescued["SOLA"] = true
	gs.carried = 10
	gs.carried_veins = {"Fe": 8, "Si": 2}
	gs.carried_items = {"iron": 9, "crystal": 1}
	var lost = gs.lose_carried()
	ok(lost == 5 and gs.carried == 5, "SOLA blackout keeps half the ore (lost %d, kept %d)" % [lost, gs.carried])
	var vein_total := 0
	for s in gs.carried_veins:
		vein_total += int(gs.carried_veins[s])
	ok(vein_total <= gs.carried, "veins shed with the ore (veins %d <= carried %d)" % [vein_total, gs.carried])
	var item_total := int(gs.carried_items["iron"]) + int(gs.carried_items["crystal"])
	ok(item_total <= 5, "chunk tallies shed too (%d)" % item_total)

	# --- without SOLA: everything drops ---
	gs.rescued.erase("SOLA")
	gs.carried = 7
	gs.carried_veins = {"Mg": 7}
	gs.lose_carried()
	ok(gs.carried == 0 and gs.carried_veins.is_empty(), "no-SOLA blackout drops all")

	# --- session flags never leak across load/new ---
	gs.adrift = true
	gs.pending_shift = true
	gs.wake_on_bunk = true
	gs.flare_phase = "burn"
	gs.last_lost = 9
	gs.save_game()
	ok(gs.load_game(2), "reload slot 2")
	ok(not gs.adrift and not gs.pending_shift and not gs.wake_on_bunk \
		and gs.flare_phase == "" and gs.last_lost == 0,
		"session flags reset on load")
	gs.adrift = true
	gs.pending_shift = true
	gs.new_game(2)
	ok(not gs.adrift and not gs.pending_shift, "session flags reset on new game")

	# --- rescue pacing gates still intact ---
	ok(not gs.rescue_available(), "no rescue before drive part 1")
	gs.quest_stage = 1
	ok(gs.rescue_available(), "JUNO's beacon after part 1")
	gs.sector = gs.rescue_beacon()
	ok(gs.at_rescue_site(), "parking at the beacon counts as the site")
	var r = gs.do_rescue()
	ok(str(r["name"]) == "JUNO" and gs.rescued_count() == 1, "JUNO comes aboard")
	ok(not gs.rescue_available(), "MIRA gated behind part 2")
	gs.quest_stage = 5
	for n in ["MIRA", "HALE", "SOLA", "VEGA"]:
		gs.sector = gs.rescue_beacon()
		ok(gs.at_rescue_site(), "beacon reachable for " + n)
		gs.do_rescue()
	ok(gs.rescued_count() == 5, "all five found")

	# --- beacons live in their advertised regions ---
	gs.rescued = {}
	var want := ["The Belt", "Viridian Veil", "Ember Reach", "Cerulean Shallows", "The Expanse"]
	for i in 5:
		var region = gs.region_at(gs.rescue_beacon())["name"]
		ok(str(region) == want[i], "beacon %d sits in %s" % [i, want[i]])
		gs.rescued[gs.RESCUES[i]["name"]] = true

	# --- economy: trader still 2x, contracts persist ---
	gs.new_game(2)
	gs.shift = 3
	gs.roll_contracts()
	var c0 = gs.contracts.duplicate(true)
	gs.roll_contracts()
	ok(gs.contracts.size() == 3 and str(gs.contracts[0]) == str(c0[0]),
		"contracts persist across rolls")
	gs.roll_trader()
	var t0: Dictionary = gs.trader_stock[0]
	ok(int(t0["price"]) == gs.price_of(str(t0["sym"])) * 2, "Vesna still charges 2x")

	# --- all 13 sounds synthesized, loops looped ---
	var sfx = root.get_node("/root/Sfx")
	var names := ["laser", "thrust", "klaxon", "pickup", "bank", "upgrade",
		"deny", "thud", "clack", "o2low", "hiss", "step", "radio"]
	var built := true
	for n in names:
		if not sfx._s.has(n):
			built = false
			print("  missing sound: " + n)
	ok(built, "all 13 sounds synthesized")
	ok(sfx._s["laser"].loop_mode == AudioStreamWAV.LOOP_FORWARD \
		and sfx._s["thrust"].loop_mode == AudioStreamWAV.LOOP_FORWARD \
		and sfx._s["klaxon"].loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"loops loop")

	gs.delete_save(2)
	print("---- %s ----" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
