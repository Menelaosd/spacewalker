extends Node
## Standalone visual test for the CREW ROSTER HUD.
##
## Launch:  godot --path . tools/test_roster.tscn
## Forces JUNO + MIRA as rescued so we can see COLOUR vs DARK side by side,
## draws a dark interior-like backdrop, and mirrors the interior HUD wiring:
##   CanvasLayer -> full-rect Control -> crew_roster (anchored top-right).

const CREW_ROSTER := preload("res://scripts/crew_roster.gd")


func _ready() -> void:
	# windowed so PrintWindow can grab a normal window rect
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(900, 560)

	# force a partial rescue state for the test
	GameState.rescued = {"JUNO": true, "MIRA": true}

	# dark backdrop standing in for the ship interior
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.16)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var roster := CREW_ROSTER.new()
	root.add_child(roster)
