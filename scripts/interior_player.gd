extends Node2D
## Crew avatar for walking around the ship interior (top-down, helmet off —
## you're breathing ship air in here). No physics bodies indoors: we just
## integrate position and clamp to the hull bounds. Placeholder _draw() art.

const SPEED := 205.0

var bounds := Rect2()
var facing := Vector2.DOWN
var _step := 0.0


func _process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += input * SPEED * delta
	if bounds.size != Vector2.ZERO:
		position.x = clampf(position.x, bounds.position.x, bounds.end.x)
		position.y = clampf(position.y, bounds.position.y, bounds.end.y)
	if input.length() > 0.1:
		facing = input.normalized()
		_step += delta * 10.0
	queue_redraw()


func _draw() -> void:
	# soft ground shadow
	draw_circle(Vector2(0, 4), 12.0, Color(0, 0, 0, 0.25))
	# bob while walking
	var bob := sin(_step) * 1.5
	var c := Vector2(0, bob)
	# jumpsuit body
	draw_circle(c, 11.0, Color(0.92, 0.5, 0.18))
	draw_circle(c, 11.0, Color(0, 0, 0, 0.0))
	# head
	draw_circle(c + Vector2(0, -2), 6.5, Color(0.95, 0.82, 0.68))
	# hair/cap toward facing
	draw_circle(c + Vector2(0, -2) + facing * 2.5, 4.0, Color(0.3, 0.22, 0.18))
	# little nav light so you can spot yourself
	draw_circle(c + facing * 9.0, 2.0, Color(0.6, 0.9, 1.0, 0.9))
