extends StaticBody2D
## A mineable resource NODE — a pixel-art chunk of the element it carries,
## drawn from its real game-asset icon (assets/sprites/elements). Static
## (redraws only on the mining flash). The laser's collision surface is fitted
## to the icon so the beam lands ON the art. Once mined, its key is recorded
## so the field stays depleted when you come back.

const PICKUP_SCENE := preload("res://scenes/pickup.tscn")

const ICON_FILL := 0.9    # element icon drawn a touch under its radius
const ICON_MAX := 16.0    # HARD half-size cap → longest axis ≤ 32px. The EVA
                          # astronaut is only ~26px (body radius 13), so the old
                          # 52px cap dwarfed the crew — keep nodes near crew size.

var radius := 28.0
var health := 100.0
var is_rich := false
var vein := ""
var mine_key := ""       # "sx:sy:i" — set by the spawner; marked mined on death

var _icon: Texture2D = null
var _icon_scale := 1.0
var _icon_ofs := Vector2.ZERO    # centres the (possibly off-centre) art bbox
var _bubble_r := 28.0            # radius of the containment bubble/glow
var _ore_color := Color(1.0, 0.72, 0.25)
var _glow_color := Color(1.0, 0.72, 0.25)
var _flash := 0.0
var _hit_local := Vector2.ZERO
var _t := 0.0            # drives the slow idle pulse
var _phase := 0.0        # per-rock offset so they don't breathe in sync


func setup(r: float, rich: bool, _tint := Color(0.42, 0.4, 0.38)) -> void:
	radius = r
	is_rich = rich


func _ready() -> void:
	add_to_group("asteroids")
	# vein is DETERMINISTIC per rock (seeded from its mine_key), so leaving and
	# re-entering a dive site can never re-roll the elements — no reroll exploit.
	# Elements.vein_element is the shared source of truth (same call the cruise
	# preview uses), so the rock's element matches inside and outside.
	vein = Elements.vein_element(mine_key, is_rich)
	_ore_color = Elements.cpk_color(vein)      # chemistry colour — sparks/label
	# the element's OWN colour (sampled from its icon) — the same tint the
	# flight-mode zone rock uses, so inside and outside match exactly
	_glow_color = Elements.glow_for(vein)
	# INSIDE the field you see the element's own pixel-art icon (different art
	# from the flight-mode rock preview, but the SAME element — both derive the
	# vein from the same mine_key seed). Sizing is uniform and hard-capped so a
	# node never dwarfs the crew.
	_icon = Elements.icon_for(vein)
	var draw_half := radius
	if _icon != null:
		var sz := _icon.get_size()
		var target := minf(radius * ICON_FILL, ICON_MAX)
		_icon_scale = (target * 2.0) / maxf(sz.x, sz.y)
		_icon_ofs = -sz * 0.5 * _icon_scale
		draw_half = maxf(sz.x, sz.y) * 0.5 * _icon_scale
	# health tracks the VISIBLE size (draw_half is size-capped), so a rock's
	# mining time always matches how big it looks — no small-looking 160 HP tanks
	health = draw_half * 5.0
	_bubble_r = draw_half * 1.05
	_phase = float(hash(mine_key) % 1000) / 1000.0 * TAU
	var shape := CircleShape2D.new()
	shape.radius = draw_half * 0.95   # hitbox hugs the drawn icon (was 0.82 — a dead outer ring)
	$Collision.shape = shape


func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
	queue_redraw()   # always: the idle pulse needs a steady redraw


func _pulse() -> float:
	## very slight breathing — ±2.5% over ~5s, offset per rock
	return 1.0 + 0.025 * sin(_t * 1.25 + _phase)


func take_damage(dmg: float, at: Vector2) -> void:
	health -= dmg
	_flash = 1.0
	_hit_local = to_local(at)
	if health <= 0.0:
		_shatter()


func _shatter() -> void:
	if mine_key != "":
		GameState.mined[mine_key] = true   # this rock stays gone on revisit
	Vfx.shatter(get_parent(), global_position, _glow_color)
	Sfx.play("shatter", -6.0, randf_range(0.9, 1.15))
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
		var pz := _icon_scale * _pulse()
		draw_set_transform(_icon_ofs * _pulse(), 0.0, Vector2(pz, pz))
		draw_texture(_icon, Vector2.ZERO)
		if _flash > 0.0:
			# whiten toward the hit — a bright "you're cutting it" pulse
			draw_texture(_icon, Vector2.ZERO, Color(1, 1, 1, _flash * 0.7))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_bite()


func _draw_bite() -> void:
	# element name ALWAYS shown: small WHITE text with a sharp black shadow so
	# it reads over any rock colour. No ring, no per-element tint.
	if vein != "":
		var font := ThemeDB.fallback_font
		var label := "%s · %s" % [vein, Elements.name_of(vein)]
		var pos := Vector2(-70, -radius - 12)
		# sharp black outline: draw the string offset in 8 directions behind it
		for o in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1),
				Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(font, pos + o, label, HORIZONTAL_ALIGNMENT_CENTER, 140, 9,
				Color(0, 0, 0, 0.95))
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, 140, 9, Color.WHITE)
	if _flash <= 0.0:
		return
	# molten spark right where the beam meets the rock
	var hp := _hit_local
	draw_circle(hp, 3.0 + _flash * 2.0, Color(1.0, 0.97, 0.85, _flash))
	for i in 5:
		var sd := Vector2.from_angle(randf() * TAU)
		draw_line(hp + sd * 2.0, hp + sd * (5.0 + randf() * 8.0),
			Color(_ore_color.r, _ore_color.g, _ore_color.b, (0.5 + randf() * 0.5) * _flash), 1.4)
