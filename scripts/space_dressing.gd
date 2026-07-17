class_name SpaceDressing
## Painted light for a _draw()-based space. One shared (off-screen) sun
## direction so everything shades from the same side. All static — scenes
## call these from their _draw(). (Comets/shooting stars are now animated
## sprites drawn by the scenes themselves, not painted here.)

# Where the light comes from (normalized). Upper-right, like the flare art.
const SUN_DIR := Vector2(0.6606, -0.7507)


static func sun_local(ci: CanvasItem) -> Vector2:
	## The sun direction expressed in a canvas item's local space, so
	## rotated nodes (asteroids) still shade toward the real sun.
	return SUN_DIR.rotated(-ci.get_global_transform().get_rotation())
