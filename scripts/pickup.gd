extends Area2D
## Ore chunk dropped by shattered asteroids.
## Drifts slowly, magnets toward the player when close.

const FLOAT_TEXT := preload("res://scripts/float_text.gd")

var value := 1
var rich := false
var kind := "iron"
var element := ""        # the vein it came from — colors and labels it
var drift := Vector2.ZERO

var _spin := 0.0


func _ready() -> void:
	_spin = randf_range(-2.0, 2.0)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var to_player: Vector2 = player.global_position - global_position
		if to_player.length() < 130.0:
			drift = drift.lerp(to_player.normalized() * 160.0, 0.1)
	global_position += drift * delta
	drift = drift.lerp(Vector2.ZERO, 0.3 * delta)
	rotation += _spin * delta


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameState.add_carried(kind, value, element)
		if element != "":
			var ft := FLOAT_TEXT.new()
			ft.text = "+%d %s" % [value, Elements.name_of(element)]
			ft.color = Elements.hue_of(element)
			ft.position = position + Vector2(0, -14)
			get_parent().add_child(ft)
		queue_free()


const IRON_TEX := preload("res://assets/sprites/iron.png")
const CRYSTAL_TEX := preload("res://assets/sprites/crystal.png")


func _draw() -> void:
	# glow and tint in the vein element's own color
	var col := Elements.hue_of(element) if element != "" \
		else (Color(0.4, 0.95, 1.0) if rich else Color(1.0, 0.72, 0.25))
	draw_circle(Vector2.ZERO, 9.0, Color(col.r, col.g, col.b, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.0, 2.0))
	draw_texture(CRYSTAL_TEX if rich else IRON_TEX, Vector2(-4.0, -4.0),
		Color(col.r * 1.1 + 0.25, col.g * 1.1 + 0.25, col.b * 1.1 + 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
