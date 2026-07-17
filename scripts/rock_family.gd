class_name RockFamily
## Groups elements into COLOUR FAMILIES by the colour their icon LOOKS like, then
## serves one of the (beautiful, generated) painted rocks from that family as the
## cruise preview. PRESENTATION ONLY — the drop economy is untouched.
##
## This is NOT chemistry grouping: gold's icon is gold → gold family; uranium's icon
## is green → green family; oxygen's is cyan → cyan family. The painted rocks are
## shown AS-IS (never tinted) — a rock's family is fixed, and which of the family's
## variants shows is a stable per-rock random pick.

const ART_DIR := "res://assets/sprites/element_art/"
const VARIANTS := 12

# colour family -> the painted art combo(s) that represent that colour. A family can
# pool more than one combo (e.g. two yellows / two oranges) for extra variety.
const FAMILY_COMBOS := {
	"red": ["metal_red"],
	"orange": ["metal_orange", "liquid_amber"],
	"gold": ["metal_gold", "metal_palegold"],
	"green": ["crystal_green"],
	"cyan": ["gas_cyan"],
	"steel": ["metal_grey"],
	"purple": ["crystal_purple"],
	"pink": ["crystal_pink"],
	"dark": ["carbon_dark"],
	"silver": ["liquid_silver"],
}

# element-specific overrides where the icon average lies about the look. Carbon is
# graphite/coal (dark) even though its lifted glow reads mid-grey.
const OVERRIDE := {"C": "dark"}

static var _cache := {}   # "<combo>_<v>" -> Texture2D (or null miss)


static func family_for(sym: String) -> String:
	## Which colour family an element belongs to, from the colour its icon looks like.
	if OVERRIDE.has(sym):
		return OVERRIDE[sym]
	var c := Elements.glow_for(sym)   # raw icon glow (hue/sat/value as it looks)
	var h := c.h
	var s := c.s
	var v := c.v
	if v < 0.34:
		return "dark"
	if s < 0.20:
		return "silver" if v > 0.60 else "dark"
	if h < 0.045 or h >= 0.95:
		return "red"
	if h < 0.09:
		return "orange"
	if h < 0.18:
		return "gold"
	if h < 0.45:
		return "green"
	if h < 0.54:
		return "cyan"
	# blue / indigo / violet / magenta (h 0.54–0.95). A washed or true-blue icon
	# reads as steel-grey rock; only a VIVID violet/magenta earns the crystal rocks.
	if s < 0.38 or h < 0.69:
		return "steel"
	if h < 0.84:
		return "purple"
	return "pink"


static func rock_art(sym: String, key: String) -> Texture2D:
	## A painted rock from the element's colour family, chosen by the rock's stable
	## key (same rock → same art every flight). Loaded from the raw PNG so it works in
	## editor/export/headless without the .import step.
	var combos: Array = FAMILY_COMBOS[family_for(sym)]
	var pool: int = combos.size() * VARIANTS
	var idx: int = abs(hash("art:" + key)) % pool
	var combo: String = combos[idx / VARIANTS]
	var variant: int = idx % VARIANTS
	var cache_key := combo + "_" + str(variant)
	if _cache.has(cache_key):
		return _cache[cache_key]
	var tex: Texture2D = null
	var abs_path := ProjectSettings.globalize_path(ART_DIR + "el_" + cache_key + ".png")
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	_cache[cache_key] = tex
	return tex
