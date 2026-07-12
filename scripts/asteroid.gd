extends StaticBody2D
## A mineable resource NODE. Not every material is grey rock: the node's
## dominant element decides what it LOOKS like — glowing crystal clusters,
## metal husks, volatile ice, radioactive cores, precious-veined stone —
## each with its own emissive glow. Rich nodes drop double ore.

const PICKUP_SCENE := preload("res://scenes/pickup.tscn")

var radius := 28.0
var health := 100.0
var is_rich := false
var vein := ""          # dominant element, rolled at real solar abundance
var kind := "rock"      # visual archetype derived from the vein

var _poly := PackedVector2Array()
var _craters: Array = []
var _flecks: Array = []
var _shards: Array = []      # crystal blades: [angle, length, width]
var _pockets: Array = []     # radioactive/precious glowing spots
var _base_color := Color(0.42, 0.4, 0.38)
var _ore_color := Color(1.0, 0.72, 0.25)
var _flash := 0.0
var _t := 0.0
var _phase := 0.0
var _hit_local := Vector2.ZERO   # where the laser is biting, local space


func setup(r: float, rich: bool, tint := Color(0.42, 0.4, 0.38)) -> void:
	## Call before add_child(). Tint gives regional rock palettes.
	radius = r
	is_rich = rich
	_base_color = tint


func _ready() -> void:
	add_to_group("asteroids")   # flare shelter checks
	# the universe decides what this rock is mostly made of — crystal
	# formations concentrate the heavy elements
	vein = Elements.sample_crystal_element() if is_rich else Elements.sample_rock_element()
	_ore_color = Elements.hue_of(vein)
	kind = _kind_for()
	if OS.get_environment("SW_KIND") != "":
		kind = OS.get_environment("SW_KIND")   # debug: force a material look
	health = radius * 4.0
	_phase = randf() * TAU
	var shape := CircleShape2D.new()
	shape.radius = radius * 0.9
	$Collision.shape = shape
	_build_shape()
	rotation = randf() * TAU


func _kind_for() -> String:
	## Map the vein element to a look. Rich formations are always crystalline.
	## Rock is the baseline (O/C/S — the common oxide & carbon asteroids);
	## the distinctive looks are reserved for rarer, more characterful veins.
	if is_rich:
		return "crystal"
	match Elements.category(vein):
		"metalloid": return "crystal"     # Si, Ge, B — crystal lattices
		"actinide": return "radioactive"  # Th, U — glowing cores
		"precious": return "precious"     # Au, Ag, Pt — veined stone
		"metal": return "metal"           # Fe, Ni, Ti — dead hull-grey husks
		"alkaline": return "ice"          # Mg, Ca, Sr — pale frozen salts
	return "rock"                         # O, C, S, Na, rare — common stone


func _build_shape() -> void:
	match kind:
		"crystal":
			# a spray of angular blades radiating from the core
			var n := randi_range(5, 8)
			for i in n:
				_shards.append([
					randf() * TAU,
					radius * randf_range(0.75, 1.25),
					radius * randf_range(0.16, 0.30),
				])
		"metal":
			# blocky, angular husk — few vertices, hard corners
			var m := 7
			for i in m:
				var ang := TAU * float(i) / float(m)
				_poly.append(Vector2.from_angle(ang) * radius * randf_range(0.82, 1.08))
			for i in 2:
				_craters.append([Vector2.from_angle(randf() * TAU) * radius * randf_range(0.1, 0.4),
					radius * randf_range(0.14, 0.24)])
		"ice":
			# smooth rounded chunk
			var v := 16
			for i in v:
				var ang := TAU * float(i) / float(v)
				_poly.append(Vector2.from_angle(ang) * radius * randf_range(0.9, 1.06))
		_:
			# rock / radioactive / precious share a lumpy body
			var k := 12
			for i in k:
				var ang := TAU * float(i) / float(k)
				_poly.append(Vector2.from_angle(ang) * radius * randf_range(0.78, 1.12))
			for i in 3:
				_craters.append([Vector2.from_angle(randf() * TAU) * radius * randf_range(0.1, 0.5),
					radius * randf_range(0.12, 0.22)])
			var fleck_count := 8 if is_rich else 5
			for i in fleck_count:
				_flecks.append(Vector2.from_angle(randf() * TAU) * radius * randf_range(0.0, 0.7))
			if kind == "radioactive" or kind == "precious":
				for i in randi_range(3, 5):
					_pockets.append([Vector2.from_angle(randf() * TAU) * radius * randf_range(0.15, 0.6),
						radius * randf_range(0.08, 0.16)])


func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
	queue_redraw()   # gentle glow pulse keeps the field alive


func take_damage(dmg: float, at: Vector2) -> void:
	health -= dmg
	_flash = 1.0
	_hit_local = to_local(at)
	if health <= 0.0:
		_shatter()


func _shatter() -> void:
	var count := maxi(int(radius / 9.0), 2)
	for i in count:
		var p := PICKUP_SCENE.instantiate()
		p.position = position + Vector2.from_angle(randf() * TAU) * radius * 0.4
		p.drift = Vector2.from_angle(randf() * TAU) * randf_range(10.0, 40.0)
		p.kind = "crystal" if is_rich else "iron"
		p.value = GameState.RESOURCE_TYPES[p.kind]["value"]
		p.rich = is_rich
		p.element = vein
		get_parent().add_child(p)
	queue_free()


# ==================================================================
# Drawing
# ==================================================================
func _draw() -> void:
	_draw_glow()
	match kind:
		"crystal": _draw_crystal()
		"metal": _draw_metal()
		"ice": _draw_ice()
		"radioactive": _draw_body(); _draw_pockets(Color(0.5, 1.0, 0.35))
		"precious": _draw_body(); _draw_veins()
		_: _draw_body(); _draw_flecks()
	_draw_bite()


func _draw_glow() -> void:
	## Emissive halo in the ore's colour — every material glows a little,
	## the energetic ones (crystal, radioactive) glow a lot.
	var g := _ore_color
	var strong := kind == "crystal" or kind == "radioactive"
	var pulse := 0.8 + 0.2 * sin(_t * 1.6 + _phase)
	var s := (0.16 if strong else 0.09) * pulse
	draw_circle(Vector2.ZERO, radius * 2.1, Color(g.r, g.g, g.b, s * 0.35))
	draw_circle(Vector2.ZERO, radius * 1.5, Color(g.r, g.g, g.b, s * 0.6))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(g.r, g.g, g.b, s))


func _draw_body() -> void:
	var c := _base_color.lerp(Color.WHITE, _flash * 0.7)
	if kind == "radioactive":
		c = c.darkened(0.35)
	elif kind == "precious":
		c = c.darkened(0.28)
	draw_colored_polygon(_poly, c)
	for cr in _craters:
		draw_circle(cr[0], cr[1], _base_color.darkened(0.25).lerp(Color.WHITE, _flash * 0.5))
	_draw_sunlight()
	_draw_outline()


func _draw_sunlight() -> void:
	var lit := SpaceDressing.sun_local(self)
	draw_circle(lit * radius * 0.32, radius * 0.72, Color(1.0, 0.97, 0.88, 0.10))
	draw_circle(-lit * radius * 0.38, radius * 0.7, Color(0.0, 0.005, 0.02, 0.26))
	var la := lit.angle()
	draw_arc(Vector2.ZERO, radius * 0.94, la - 1.15, la + 1.15, 20,
		Color(1.0, 0.98, 0.92, 0.3), 2.5)


func _draw_outline() -> void:
	var outline := _poly.duplicate()
	outline.append(_poly[0])
	draw_polyline(outline, Color(0, 0, 0, 0.35), 2.0)


func _draw_flecks() -> void:
	for f in _flecks:
		draw_circle(f, 2.5, _ore_color)
		draw_circle(f, 4.5, Color(_ore_color.r, _ore_color.g, _ore_color.b, 0.25))


func _draw_pockets(col: Color) -> void:
	## Glowing pits (radioactive) — pulse independently for a reactive feel.
	for p in _pockets:
		var pu: float = 0.55 + 0.45 * sin(_t * 3.0 + (p[0] as Vector2).x)
		draw_circle(p[0], float(p[1]) * 1.8, Color(col.r, col.g, col.b, 0.18 * pu))
		draw_circle(p[0], float(p[1]), Color(col.r, col.g, col.b, 0.6 + 0.4 * pu))
		draw_circle(p[0], float(p[1]) * 0.5, Color(1, 1, 1, 0.7 * pu))


func _draw_veins() -> void:
	## Bright metallic seams threading dark precious ore, with glints.
	for p in _pockets:
		var a := (p[0] as Vector2).angle()
		var v := Vector2.from_angle(a)
		draw_line(p[0] - v * (p[1] as float) * 2.0, p[0] + v * (p[1] as float) * 2.0,
			_ore_color, 2.0)
		var gl: float = 0.5 + 0.5 * sin(_t * 2.5 + (p[0] as Vector2).y)
		draw_circle(p[0], 1.6, Color(1, 1, 1, gl))


func _draw_crystal() -> void:
	## A cluster of translucent blades — bright edges, glowing core.
	var col := _ore_color
	for s in _shards:
		var a := float(s[0])
		var ln := float(s[1]) * (1.0 + _flash * 0.1)
		var w := float(s[2])
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * w * 0.5
		var tip := dir * ln
		# a blade: two base corners (±side) tapering to the tip
		var blade := PackedVector2Array([side, tip, -side])
		draw_colored_polygon(blade, Color(col.r, col.g, col.b, 0.45))
		draw_polyline(PackedVector2Array([side, tip, -side]),
			Color(col.lightened(0.4).r, col.lightened(0.4).g, col.lightened(0.4).b, 0.9), 1.5)
		draw_line(Vector2.ZERO, tip, Color(1, 1, 1, 0.5 + _flash * 0.5), 1.0)
	# bright molten core
	var cpu := 0.7 + 0.3 * sin(_t * 2.2 + _phase)
	draw_circle(Vector2.ZERO, radius * 0.34, Color(col.r, col.g, col.b, 0.35 * cpu))
	draw_circle(Vector2.ZERO, radius * 0.16, Color(1, 1, 1, 0.85 * cpu))


func _draw_metal() -> void:
	## A dead hull husk — cool grey plating, panel seams, a hard glint.
	var c := Color(0.5, 0.55, 0.62).lerp(_base_color, 0.25).lerp(Color.WHITE, _flash * 0.6)
	draw_colored_polygon(_poly, c)
	# panel seams across the chunk
	for cr in _craters:
		draw_rect(Rect2((cr[0] as Vector2) - Vector2(cr[1], cr[1]) * 0.6,
			Vector2(cr[1], cr[1]) * 1.2), c.darkened(0.35))
	draw_line(_poly[0], _poly[int(_poly.size() / 2.0)], c.darkened(0.4), 1.5)
	_draw_sunlight()
	_draw_outline()
	# metallic glint + faint ore sheen
	draw_circle(SpaceDressing.sun_local(self) * radius * 0.4, radius * 0.14,
		Color(1, 1, 1, 0.5 + _flash * 0.4))
	draw_circle(Vector2(-radius * 0.2, radius * 0.2), 2.0, _ore_color)


func _draw_ice() -> void:
	## A translucent frozen chunk — soft body, inner glow, cracks.
	var col := _ore_color
	var body := Color(col.r * 0.6 + 0.5, col.g * 0.6 + 0.55, col.b * 0.6 + 0.6, 0.7)
	draw_colored_polygon(_poly, body.lerp(Color.WHITE, _flash * 0.5))
	# inner glow core
	var pu := 0.7 + 0.3 * sin(_t * 1.4 + _phase)
	draw_circle(Vector2.ZERO, radius * 0.55, Color(col.r, col.g, col.b, 0.15 * pu))
	draw_circle(Vector2.ZERO, radius * 0.28, Color(1, 1, 1, 0.35 * pu))
	# internal cracks
	for i in 3:
		var a := _phase + float(i) * 2.1
		draw_line(Vector2.from_angle(a) * radius * 0.2, Vector2.from_angle(a) * radius * 0.85,
			Color(1, 1, 1, 0.35), 1.0)
	_draw_outline()
	# frosty rim highlight
	var lit := SpaceDressing.sun_local(self)
	draw_arc(Vector2.ZERO, radius * 0.92, lit.angle() - 1.0, lit.angle() + 1.0, 16,
		Color(0.8, 0.95, 1.0, 0.5), 2.0)


func _draw_bite() -> void:
	# laser bite: molten point, radial sparks, flying embers, heat ring
	if _flash > 0.0:
		var hp := _hit_local
		draw_circle(hp, 6.5,
			Color(_ore_color.r, _ore_color.g, _ore_color.b, 0.45 * _flash))
		draw_circle(hp, 2.6 + randf() * 1.6, Color(1.0, 0.97, 0.85, _flash))
		for i in 6:
			var sa := randf() * TAU
			var sd := Vector2.from_angle(sa)
			draw_line(hp + sd * 2.0, hp + sd * (5.0 + randf() * 9.0),
				Color(1.0, 0.85, 0.4, (0.5 + randf() * 0.5) * _flash), 1.4)
		for i in 4:
			draw_circle(hp + Vector2.from_angle(randf() * TAU) * randf_range(4.0, 17.0),
				1.1 + randf() * 0.8,
				Color(_ore_color.r, _ore_color.g, _ore_color.b, randf_range(0.3, 0.9) * _flash))
		draw_arc(hp, 6.0 + (1.0 - _flash) * 12.0, 0.0, TAU, 18,
			Color(1.0, 0.7, 0.35, 0.4 * _flash), 1.5)
	# assay readout — the vein's name appears while the laser bites
	if _flash > 0.0 and vein != "":
		var up := (Vector2.UP * (radius + 18.0)).rotated(-rotation)
		draw_set_transform(up, -rotation, Vector2.ONE)
		var label := "%s — %s" % [vein, Elements.name_of(vein)]
		draw_string(ThemeDB.fallback_font, Vector2(-70, 4), label,
			HORIZONTAL_ALIGNMENT_CENTER, 140, 13,
			Color(_ore_color.r, _ore_color.g, _ore_color.b, minf(_flash * 2.0, 1.0)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
