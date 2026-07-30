extends Node
## How much CHOICE does a run actually get? Counts, per generated map, how often you stand
## on a node with only one way forward — the state that makes a column feel like a trap.
func _ready() -> void:
	var one := 0
	var multi := 0
	var total_links := 0
	var nodes_with_links := 0
	var maps := 40
	for n in maps:
		var map: Node = load("res://scenes/breach.tscn").instantiate()
		add_child(map)
		await get_tree().process_frame
		var nodes: Array = map.get("nodes")
		for nd in nodes:
			var l: int = (nd["links"] as Array).size()
			if l == 0:
				continue
			nodes_with_links += 1
			total_links += l
			if l == 1:
				one += 1
			else:
				multi += 1
		map.queue_free()
		await get_tree().process_frame
	print("[LINKS] %d maps | nodes with a way forward: %d" % [maps, nodes_with_links])
	print("[LINKS]   only ONE option: %d (%.0f%%)   two or more: %d (%.0f%%)"
		% [one, 100.0 * one / float(nodes_with_links), multi, 100.0 * multi / float(nodes_with_links)])
	print("[LINKS]   mean links per node: %.2f" % (float(total_links) / float(nodes_with_links)))
	get_tree().quit()
