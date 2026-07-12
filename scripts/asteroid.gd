extends StaticBody2D
## A mineable resource NODE — a pixel-art chunk of the element it carries,
## drawn from its real game-asset icon (assets/sprites/elements). Static
## (redraws only on the mining flash). The laser's collision surface is fitted
## to the icon so the beam lands ON the art. Once mined, its key is recorded
## so the field stays depleted when you come back.

const PICKUP_SCENE := preload("res://scenes/pickup.tscn")

var radius := 28.0
var health := 100.0
var is_rich := false
var vein := ""
var mine_key := ""       # "sx:sy:i" — set by the spawner; marked mined on death

var _icon: Texture2D = null
var _icon_scale := 1.0
var _icon_ofs := Vector2.ZERO    # centres the (possibly off-centre) art bbox
var _ore_color := Color(1.0, 0.72, 0.25)
var _flash := 0.0
var _hit_local := Vector2.ZERO


func setup(r: float, rich: bool, _tint := Color(0.42, 0.4, 0.38)) -> void:
	radius = r
	is_rich = rich


func _ready() -> void:
	add_to_group("asteroids")
	vein = Elements.sample_crystal_element() if is_rich else Elements.sample_rock_element()
	_ore_color = Elements.cpk_color(vein)   # the real chemistry colour
	health = radius * 4.0
	_icon = Elements.icon_for(vein)
	# fit the art inside the node's diameter and remember its centre offset
	if _icon != null:
		var sz := _icon.get_size()
		_icon_scale = (radius * 2.0) / maxf(sz.x, sz.y)
		_icon_ofs = -sz * 0.5 * _icon_scale
	var shape := CircleShape2D.new()
	# collide at ~90% of the drawn art so the beam visibly touches the chunk
	shape.radius = radius * 0.9
	$Collision.shape = shape


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		queue_redraw()


func take_damage(dmg: float, at: Vector2) -> void:
	health -= dmg
	_flash = 1.0
	_hit_local = to_local(at)
	if health <= 0.0:
		_shatter()


func _shatter() -> void:
	if mine_key != "":
		GameState.mined[mine_key] = true   # this rock stays gone on revisit
	var count := maxi(int(radius / 9.0), 2)
	for i in count:
		var p := PICKUP_SCENE.instantiate()
		p.position = position + Vector2.from_angle(randf() * TAU) * radius * 0.4
		p.drift = Vector2.from_angle(randf() * TAU) * randf_range(10.0, 40.0)
		p.kind = "crystal" if is_rich else "iron"
		p.value = GameState.RESOURCE_TYPES[p.kind]["value"]
		p.rich = is_rich
		p.element = vein          # chunks carry the vein — same art, same colour
		get_parent().add_child(p)
	queue_free()


# ==================================================================
# Drawing — the element's pixel-art icon
# ==================================================================
func _draw() -> void:
	if _icon == null:
		# fallback: a plain ore blob in the element's colour
		draw_circle(Vector2.ZERO, radius, _ore_color.darkened(0.3))
		draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.4,
			_ore_color.lerp(Color.WHITE, 0.4))
	else:
		draw_set_transform(_icon_ofs, 0.0, Vector2(_icon_scale, _icon_scale))
		draw_texture(_icon, Vector2.ZERO)
		if _flash > 0.0:
			# whiten toward the hit — a bright "you're cutting it" pulse
			draw_texture(_icon, Vector2.ZERO, Color(1, 1, 1, _flash * 0.7))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_bite()


func _draw_bite() -> void:
	if _flash <= 0.0:
		return
	# molten spark right where the beam meets the rock
	var hp := _hit_local
	draw_circle(hp, 3.0 + _flash * 2.0, Color(1.0, 0.97, 0.85, _flash))
	for i in 5:
		var sd := Vector2.from_angle(randf() * TAU)
		draw_line(hp + sd * 2.0, hp + sd * (5.0 + randf() * 8.0),
			Color(_ore_color.r, _ore_color.g, _ore_color.b, (0.5 + randf() * 0.5) * _flash), 1.4)
	# element name tag while it's being cut
	if vein != "":
		draw_string(ThemeDB.fallback_font, Vector2(-70, -radius - 12),
			"%s — %s" % [vein, Elements.name_of(vein)],
			HORIZONTAL_ALIGNMENT_CENTER, 140, 13,
			Color(_ore_color.r, _ore_color.g, _ore_color.b, minf(_flash * 2.0, 1.0)))
