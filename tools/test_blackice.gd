extends Node
## Unit test for the BLACK ICE opt-in fight: arrive -> choice modal -> duel -> reward.
## Drives the real map's own functions, no frames or animation needed.
##   <godot> --headless --path . res://tools/test_blackice.tscn

func _ready() -> void:
	var map: Node = load("res://scenes/breach.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	var nodes: Array = map.get("nodes")
	# find a util node we can retype, and force it to BLACK ICE at a shallow and a deep row
	for want_deep in [false, true]:
		var idx := -1
		for i in nodes.size():
			var r: int = int(nodes[i]["row"])
			if (r >= 8) == want_deep and r > 0 and int(map.TYPES[str(nodes[i]["type"])][2]) == 0:
				idx = i
				break
		if idx < 0:
			print("[ICE] no %s candidate row — skipped" % ("deep" if want_deep else "shallow"))
			continue
		nodes[idx]["type"] = "blackice"
		var row: int = int(nodes[idx]["row"])

		# --- path 1: DECLINE ---
		map.set("_ice_fought", false)
		map.call("_arrive", idx)
		var ch: Dictionary = map.get("_choice")
		print("[ICE] row %d  modal offered=%s opts=%d" % [row, str(not ch.is_empty()), (ch["opts"] as Array).size() if not ch.is_empty() else 0])
		map.call("_choose", 1)
		print("[ICE]   declined -> duel=%s state=%s ice_fought=%s"
			% [str(map.get("_duel") != null), str(nodes[idx].get("state")), str(map.get("_ice_fought"))])

		# --- path 2: ACCEPT ---
		nodes[idx]["state"] = "reach"
		map.call("_arrive", idx)
		map.call("_choose", 0)
		var d = map.get("_duel")
		print("[ICE]   accepted -> duel=%s tier=%s (want %d) ice_fought=%s"
			% [str(d != null), str(d.tier if d != null else -1), 6 if row >= 8 else 4,
				str(map.get("_ice_fought"))])
		# --- reward on a win ---
		var sh0: int = int(map.get("shards"))
		var deck0: int = (map.DUEL.run_deck as Array).size()
		if d != null:
			map.call("_on_duel_finished", true)
		var picker = null
		for c in map.get_children():
			if c.has_signal("chosen"):
				picker = c
		print("[ICE]   won -> shards %d->%d, picker=%s" % [sh0, int(map.get("shards")), str(picker != null)])
		if picker != null:
			picker.chosen.emit(0)
			await get_tree().process_frame
			var deck1: int = (map.DUEL.run_deck as Array).size()
			var welded := 0
			for k in (map.DUEL.atk_boost as Dictionary):
				welded += int(map.DUEL.atk_boost[k])
			print("[ICE]   salvage -> deck %d->%d, welded power total=%d" % [deck0, deck1, welded])
	print("[ICE] done")
	get_tree().quit()
