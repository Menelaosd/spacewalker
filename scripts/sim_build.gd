extends Node
## DELETABLE SIM — exercises the whole build/placement pipeline headless and
## prints a report, then quits. Run: godot --headless res://scenes/sim_build.tscn

const Craftables := preload("res://scripts/craftables.gd")
const Elements := preload("res://scripts/elements.gd")

func _ready() -> void:
	GameState.new_game(0)
	GameState.banked = 999999
	for e in Elements.TABLE:
		GameState.elements[e[0]] = 9999
	for id in Craftables.ITEMS:
		GameState.recipes_unlocked[id] = true

	# ---- BUILD: expand every reachable bare in-hull cell ----
	var built := 0
	var guard := 0
	while guard < 60:
		guard += 1
		var progressed := false
		for cell in GameState.SHIP_COLS * GameState.SHIP_ROWS:
			if not GameState.cell_in_hull(cell) or GameState.rooms.has(cell):
				continue
			var adj := false
			for n in GameState.cell_neighbors(cell):
				if GameState.rooms.has(n):
					adj = true
					break
			if adj and GameState.build_room(cell, "room"):
				built += 1
				progressed = true
		if not progressed:
			break
	var bare := 0
	for cell in GameState.SHIP_COLS * GameState.SHIP_ROWS:
		if GameState.cell_in_hull(cell) and not GameState.rooms.has(cell):
			bare += 1
	print("=== BUILD SIM ===")
	print("rooms built: %d | total rooms: %d | bare in-hull cells remaining: %d | banked: %d"
		% [built, GameState.rooms.size(), bare, GameState.banked])

	# ---- PLACEMENT: adjacency stress test (the bug the fix targeted) ----
	var room_cell := -1
	for cell in GameState.rooms:
		if GameState.can_furnish_room(cell):
			room_cell = cell
			break
	if room_cell < 0:
		print("no furnishable room to test placement")
		get_tree().quit()
		return
	var big := ""
	var small := ""
	for id in Craftables.ITEMS:
		var it: Dictionary = Craftables.ITEMS[id]
		if it.get("flat", false):
			continue
		if int(it.get("size", 1)) == 2 and big == "":
			big = id
		if int(it.get("size", 1)) == 1 and small == "":
			small = id
	print("\n=== PLACEMENT SIM (cell %d) ===" % room_cell)
	print("big(size2)=%s  small(size1)=%s" % [big, small])
	print("place %s at back-row (0,0): %s" % [big, GameState.place_furniture(room_cell, big, 0, 0)])
	print("fit map for %s across the grid (Y=fits, .=blocked):" % small)
	var total_fit := 0
	for r in GameState.FURN_ROWS:
		var line := "  row %d: " % r
		for c in GameState.FURN_COLS:
			var ok := GameState.furniture_fits(room_cell, small, c, r, false)
			if ok:
				total_fit += 1
			line += "Y " if ok else ". "
		print(line)
	# under the big piece at cols 0-1: (0,1)/(1,1) BELOW and (0..1, same-row occupied)
	print("below the big piece (0,1) fits: %s  |  beside it (2,0) fits: %s"
		% [GameState.furniture_fits(room_cell, small, 0, 1, false),
		   GameState.furniture_fits(room_cell, small, 2, 0, false)])
	print("total open small-slots in the room: %d / %d" % [total_fit, GameState.FURN_COLS * GameState.FURN_ROWS])

	# ---- fill the room to confirm no false blocks ----
	var fills := 0
	for r in GameState.FURN_ROWS:
		for c in GameState.FURN_COLS:
			if GameState.place_furniture(room_cell, small, c, r):
				fills += 1
	print("greedily placed %d more %s pieces without a false block" % [fills, small])
	print("=== SIM DONE ===")
	get_tree().quit()
