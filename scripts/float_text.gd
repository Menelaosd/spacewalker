extends Node2D
## Tiny rising, fading text — "+1 Silicon" when you grab a chunk.

var text := ""
var color := Color.WHITE
var _life := 1.1


func _process(delta: float) -> void:
	position.y -= 26.0 * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := clampf(_life / 0.6, 0.0, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(-60, -1), text,
		HORIZONTAL_ALIGNMENT_CENTER, 120, 13,
		Color(0, 0, 0, a * 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(-60, -2), text,
		HORIZONTAL_ALIGNMENT_CENTER, 120, 13,
		Color(color.r, color.g, color.b, a))
