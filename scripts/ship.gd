extends StaticBody2D
## Home ship. Docking zone refills O2 and banks carried ore.
## The tether (lifeline) anchors at the airlock.

@onready var dock_zone: Area2D = $DockZone

var _beacon_phase := 0.0


func anchor_point() -> Vector2:
	return global_position + Vector2(0, 48)


func _ready() -> void:
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
const SHIP_TEX := preload("res://assets/sprites/ship.png")


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_beacon_phase * 2.0)

	# dock zone ring
	draw_arc(Vector2.ZERO, 140.0, 0.0, TAU, 48,
		Color(0.3, 0.8, 1.0, 0.10 + 0.05 * pulse), 2.0)

	# pixel hull (tools/gen_sprites.gd), 2x scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.0, 2.0))
	draw_texture(SHIP_TEX, Vector2(-32.0, -16.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# tether anchor below the airlock
	draw_circle(Vector2(0, 48), 7.0, Color(0.25, 0.28, 0.34))
	draw_circle(Vector2(0, 48), 3.0, Color(1.0, 0.85, 0.3))

	# beacon light
	draw_circle(Vector2(0, -36), 4.0, Color(1.0, 0.3, 0.25, 0.3 + 0.7 * pulse))
