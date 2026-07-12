extends Node
## One-shot particle bursts, tinted to the element. Autoload: call from anywhere
## with a PERSISTENT parent (e.g. the mined rock's get_parent(), not the rock —
## it's about to free). Textures are Kenney's CC0 Particle Pack (512px each, so
## scale values are small) and drawn ADDITIVELY so they read as glowing sparks.

const T_SPARK := preload("res://assets/particles/spark_05.png")
const T_SPARK2 := preload("res://assets/particles/spark_04.png")
const T_STAR := preload("res://assets/particles/star_06.png")
const T_GLOW := preload("res://assets/particles/light_02.png")
const T_CIRCLE := preload("res://assets/particles/circle_05.png")
const T_FLARE := preload("res://assets/particles/flare_01.png")
const T_MAGIC := preload("res://assets/particles/magic_05.png")

var _add: CanvasItemMaterial


func _ready() -> void:
	_add = CanvasItemMaterial.new()
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # glowy sparks, not flat sprites


func _fade_ramp(c: Color, hot := true) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var lead := c.lerp(Color.WHITE, 0.6) if hot else c
	g.colors = PackedColorArray([
		Color(lead.r, lead.g, lead.b, 1.0),
		Color(c.r, c.g, c.b, 0.85),
		Color(c.r, c.g, c.b, 0.0)])
	return g


func _weld_ramp() -> Gradient:
	## white-hot -> yellow -> orange-red dying ember, like real weld spatter
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 1.0, 0.97, 1.0),
		Color(1.0, 0.88, 0.45, 1.0),
		Color(1.0, 0.55, 0.15, 0.8),
		Color(0.7, 0.2, 0.05, 0.0)])
	return g


func _emit(parent: Node, pos: Vector2, tex: Texture2D, amount: int, life: float,
		vmin: float, vmax: float, smin: float, smax: float, col: Color,
		hot := true, z := 30, dir := Vector2.ZERO, spread := 180.0,
		ramp: Gradient = null) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := CPUParticles2D.new()
	p.texture = tex
	p.material = _add
	p.amount = amount
	p.lifetime = life
	p.lifetime_randomness = 0.5
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	p.direction = dir if dir != Vector2.ZERO else Vector2.RIGHT
	p.spread = spread                      # 180 = full circle, less = a fan
	p.gravity = Vector2.ZERO               # space — no fall
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.damping_min = 40.0
	p.damping_max = 120.0                   # sparks decelerate fast, stay tight
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.color_ramp = ramp if ramp != null else _fade_ramp(col, hot)
	p.z_index = z
	parent.add_child(p)
	p.global_position = pos
	get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)


func spark_hit(parent: Node, pos: Vector2, col: Color, beam_dir := Vector2.ZERO) -> void:
	## WELDING spatter at the cut: white-hot pinpricks spraying back off the
	## surface in a fan, dying through yellow to orange ember. A faint tint of
	## the element's colour lingers so you still read what you're cutting.
	var back := -beam_dir if beam_dir != Vector2.ZERO else Vector2.ZERO
	# hot spatter fan — many tiny fast glints, short-lived, weld-coloured
	_emit(parent, pos, T_STAR, 9, 0.34, 120.0, 320.0, 0.008, 0.018,
		Color.WHITE, true, 31, back, 55.0, _weld_ramp())
	# a couple of slower fat sparks that arc a little further
	_emit(parent, pos, T_SPARK2, 3, 0.5, 60.0, 150.0, 0.012, 0.022,
		Color.WHITE, true, 31, back, 80.0, _weld_ramp())
	# tiny white-hot core flash at the contact point
	_emit(parent, pos, T_GLOW, 1, 0.12, 0.0, 0.0, 0.030, 0.045,
		Color(1.0, 0.98, 0.9), true, 32)
	# element-tinted afterglow, very subtle
	_emit(parent, pos, T_CIRCLE, 1, 0.3, 5.0, 20.0, 0.03, 0.05,
		Color(col.r, col.g, col.b, 0.35), false)


func shatter(parent: Node, pos: Vector2, col: Color) -> void:
	## the money shot when an element breaks apart — small, punchy, glowing
	_emit(parent, pos, T_FLARE, 1, 0.24, 0.0, 0.0, 0.14, 0.22, col, true, 31)    # flash
	_emit(parent, pos, T_STAR, 14, 0.5, 60.0, 210.0, 0.022, 0.045, col)          # shards
	_emit(parent, pos, T_MAGIC, 10, 0.65, 30.0, 120.0, 0.018, 0.035, col)        # embers
	_emit(parent, pos, T_CIRCLE, 5, 0.8, 12.0, 55.0, 0.07, 0.13,
		Color(col.r, col.g, col.b, 0.6), false)                                  # glow puff


func sparkle(parent: Node, pos: Vector2, col: Color) -> void:
	## collecting a chunk — a bright little pop
	_emit(parent, pos, T_STAR, 7, 0.5, 25.0, 95.0, 0.02, 0.04, col)
	_emit(parent, pos, T_GLOW, 1, 0.32, 0.0, 0.0, 0.05, 0.08, col, true, 31)


func flash(parent: Node, pos: Vector2, col: Color, scale := 1.0) -> void:
	## a quick radial glow — installs, jumps, discoveries
	_emit(parent, pos, T_FLARE, 1, 0.4, 0.0, 0.0, scale * 0.16, scale * 0.26, col, true, 31)
	_emit(parent, pos, T_MAGIC, 9, 0.55, 35.0, 110.0, 0.025, 0.045, col)
