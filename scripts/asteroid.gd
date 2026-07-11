extends StaticBody2D
## Mineable asteroid. Procedurally drawn placeholder rock with ore flecks.
## Rich (cyan) asteroids drop double-value ore.

const PICKUP_SCENE := preload("res://scenes/pickup.tscn")

var radius := 28.0
var health := 100.0
var is_rich := false

var _poly := PackedVector2Array()
var _craters: Array = []
var _flecks: Array = []
var _base_color := Color(0.42, 0.4, 0.38)
var _ore_color := Color(1.0, 0.72, 0.25)
var _flash := 0.0


func setup(r: float, rich: bool) -> void:
	## Call before add_child().
	radius = r
	is_rich = rich
	if rich:
		_ore_color = Color(0.4, 0.95, 1.0)


func _ready() -> void:
	health = radius * 4.0
	var shape := CircleShape2D.new()
	shape.radius = radius * 0.9
	$Collision.shape = shape

	var n := 12
	for i in n:
		var ang := TAU * float(i) / float(n)
		_poly.append(Vector2.from_angle(ang) * radius * randf_range(0.78, 1.12))
	for i in 3:
		_craters.append([
			Vector2.from_angle(randf() * TAU) * radius * randf_range(0.1, 0.5),
			radius * randf_range(0.12, 0.22),
		])
	var fleck_count := 8 if is_rich else 5
	for i in fleck_count:
		_flecks.append(Vector2.from_angle(randf() * TAU) * radius * randf_range(0.0, 0.7))
	rotation = randf() * TAU


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		queue_redraw()


func take_damage(dmg: float, _at: Vector2) -> void:
	health -= dmg
	_flash = 1.0
	queue_redraw()
	if health <= 0.0:
		_shatter()


func _shatter() -> void:
	var count := maxi(int(radius / 9.0), 2)
	for i in count:
		var p := PICKUP_SCENE.instantiate()
		p.position = position + Vector2.from_angle(randf() * TAU) * radius * 0.4
		p.drift = Vector2.from_angle(randf() * TAU) * randf_range(10.0, 40.0)
		p.value = 2 if is_rich else 1
		p.rich = is_rich
		get_parent().add_child(p)
	queue_free()


func _draw() -> void:
	var c := _base_color.lerp(Color.WHITE, _flash * 0.7)
	draw_colored_polygon(_poly, c)
	for cr in _craters:
		draw_circle(cr[0], cr[1], _base_color.darkened(0.25).lerp(Color.WHITE, _flash * 0.5))
	for f in _flecks:
		draw_circle(f, 2.5, _ore_color)
	var outline := _poly.duplicate()
	outline.append(_poly[0])
	draw_polyline(outline, Color(0, 0, 0, 0.35), 2.0)
