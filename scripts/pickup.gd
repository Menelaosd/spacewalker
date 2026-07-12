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
	add_to_group("pickups")   # radar sparks
	_spin = randf_range(-2.0, 2.0)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	# element samples are always collectible, so the magnet always pulls
	if player != null:
		var to_player: Vector2 = player.global_position - global_position
		if to_player.length() < GameState.pickup_reach():   # magnet coil extends this
			drift = drift.lerp(to_player.normalized() * 160.0, 0.1)
	global_position += drift * delta
	drift = drift.lerp(Vector2.ZERO, 0.3 * delta)
	rotation += _spin * delta


static var _full_warn_cd := 0.0


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	# the element sample always goes in the collection; the ore may not fit
	var ore_full := GameState.add_carried(kind, value, element)
	var spark_col: Color = Elements.glow_for(element) if element != "" else Color(1.0, 0.85, 0.4)
	Vfx.sparkle(get_parent(), global_position, spark_col)
	Sfx.play("pickup", -12.0, randf_range(0.9, 1.15))
	if element != "":
		var ft := FLOAT_TEXT.new()
		ft.text = "+%d %s" % [value, Elements.name_of(element)]
		ft.color = Elements.hue_of(element)
		ft.position = position + Vector2(0, -14)
		get_parent().add_child(ft)
	if ore_full and Time.get_ticks_msec() / 1000.0 > _full_warn_cd:
		# samples still bank; only the ORE bag is full — that's the nudge home
		_full_warn_cd = Time.get_ticks_msec() / 1000.0 + 2.5
		GameState.say("Ore bag full (%d/%d) — bank it at the ship." % [
			GameState.carried, GameState.ore_max()])
	queue_free()


const IRON_TEX := preload("res://assets/sprites/iron.png")
const CRYSTAL_TEX := preload("res://assets/sprites/crystal.png")

const CHUNK_PX := 13.0   # small fragment — much smaller than the whole rock


func _draw() -> void:
	# a broken-off chunk is a MINIATURE of the element it came from — same
	# art, same colour as the rock it was cut out of.
	var icon: Texture2D = Elements.icon_for(element) if element != "" else null
	if icon != null:
		var sz := icon.get_size()
		var s := CHUNK_PX / maxf(sz.x, sz.y)
		draw_set_transform(-sz * 0.5 * s, 0.0, Vector2(s, s))
		draw_texture(icon, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# fallback: tinted placeholder chunk in the element's CPK colour
	var col := Elements.cpk_color(element) if element != "" \
		else (Color(0.4, 0.95, 1.0) if rich else Color(1.0, 0.72, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.0, 2.0))
	draw_texture(CRYSTAL_TEX if rich else IRON_TEX, Vector2(-4.0, -4.0),
		Color(col.r * 1.1 + 0.25, col.g * 1.1 + 0.25, col.b * 1.1 + 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
