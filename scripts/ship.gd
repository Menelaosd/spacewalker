extends StaticBody2D
## Home ship. Docking zone refills O2 and banks carried ore.
## The tether (lifeline) anchors at the airlock.

@onready var dock_zone: Area2D = $DockZone

var _beacon_phase := 0.0


func anchor_point() -> Vector2:
	return global_position + Vector2(0, 82)


func _ready() -> void:
	add_to_group("dock_ship")   # the radar's home-square blip
	texture_filter = TEXTURE_FILTER_LINEAR   # painted art, not pixel art
	dock_zone.body_entered.connect(_on_dock_entered)
	dock_zone.body_exited.connect(_on_dock_exited)


func _process(delta: float) -> void:
	_beacon_phase += delta
	queue_redraw()


func _on_dock_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body.in_dock = true
	var banked := GameState.bank_cargo()
	if banked > 0:
		GameState.say("Docked — banked %d ore. O2 refilling." % banked)
		GameState.save_game()
	else:
		GameState.say("Docked — O2 refilling.")


func _on_dock_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body.in_dock = false
	GameState.say("Spacewalk started — watch your O2 and line.")


# ------------------------------------------------------------------
# Placeholder visuals
# ------------------------------------------------------------------
## The captain's ship (tools/ship_source.png -> process_ship_art.gd).
## Drawn at half scale: ~150x149 world px, bow facing right.
const SHIP_TEX := preload("res://assets/sprites/ship_hd.png")
const SHIP_SCALE := 0.5


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_beacon_phase * 2.0)

	# dock zone ring
	draw_arc(Vector2.ZERO, 140.0, 0.0, TAU, 48,
		Color(0.3, 0.8, 1.0, 0.10 + 0.05 * pulse), 2.0)

	# painted hull
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(SHIP_SCALE, SHIP_SCALE))
	draw_texture(SHIP_TEX, -SHIP_TEX.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# tether anchor below the hull
	draw_circle(Vector2(0, 82), 7.0, Color(0.25, 0.28, 0.34))
	draw_circle(Vector2(0, 82), 3.0, Color(1.0, 0.85, 0.3))

	# beacon light on the bow tower
	draw_circle(Vector2(30, -76), 4.0, Color(1.0, 0.3, 0.25, 0.3 + 0.7 * pulse))
