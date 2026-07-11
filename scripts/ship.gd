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
func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_beacon_phase * 2.0)

	# dock zone ring
	draw_arc(Vector2.ZERO, 140.0, 0.0, TAU, 48,
		Color(0.3, 0.8, 1.0, 0.10 + 0.05 * pulse), 2.0)

	# hull (horizontal capsule)
	var hull := Color(0.55, 0.58, 0.66)
	draw_rect(Rect2(-40, -28, 80, 56), hull)
	draw_circle(Vector2(-40, 0), 28.0, hull)
	draw_circle(Vector2(40, 0), 28.0, hull)

	# stripe
	draw_rect(Rect2(-40, -4, 80, 8), Color(0.9, 0.45, 0.15))

	# cockpit window
	draw_circle(Vector2(42, -6), 12.0, Color(0.15, 0.3, 0.45))
	draw_circle(Vector2(45, -9), 3.5, Color(0.6, 0.85, 1.0))

	# engine block
	draw_rect(Rect2(-78, -12, 14, 24), Color(0.35, 0.38, 0.45))

	# airlock + tether anchor
	draw_rect(Rect2(-10, 26, 20, 16), Color(0.4, 0.42, 0.5))
	draw_circle(Vector2(0, 48), 7.0, Color(0.25, 0.28, 0.34))
	draw_circle(Vector2(0, 48), 3.0, Color(1.0, 0.85, 0.3))

	# beacon light
	draw_circle(Vector2(0, -34), 4.0, Color(1.0, 0.3, 0.25, 0.3 + 0.7 * pulse))
