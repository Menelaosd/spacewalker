class_name Elements
## The periodic table as the resource system. Abundances are REAL present-day
## solar atom-percentages (83 long-lived elements, IUPAC names) — rarity in
## the game is rarity in the universe. Do not "balance" these numbers.
## [symbol, name, atomic number, atom %]

const TABLE := [
	["H", "Hydrogen", 1, 92.33],
	["He", "Helium", 2, 7.574],
	["Li", "Lithium", 3, 8.420e-10],
	["Be", "Beryllium", 4, 2.215e-09],
	["B", "Boron", 5, 4.627e-08],
	["C", "Carbon", 6, 2.663e-02],
	["N", "Nitrogen", 7, 6.242e-03],
	["O", "Oxygen", 8, 4.522e-02],
	["F", "Fluorine", 9, 2.319e-06],
	["Ne", "Neon", 10, 1.060e-02],
	["Na", "Sodium", 11, 1.532e-04],
	["Mg", "Magnesium", 12, 3.276e-03],
	["Al", "Aluminium", 13, 2.485e-04],
	["Si", "Silicon", 14, 2.988e-03],
	["P", "Phosphorus", 15, 2.373e-05],
	["S", "Sulfur", 16, 1.217e-03],
	["Cl", "Chlorine", 17, 1.885e-05],
	["Ar", "Argon", 18, 2.215e-04],
	["K", "Potassium", 19, 1.085e-05],
	["Ca", "Calcium", 20, 1.842e-04],
	["Sc", "Scandium", 21, 1.274e-07],
	["Ti", "Titanium", 22, 8.616e-06],
	["V", "Vanadium", 23, 7.334e-07],
	["Cr", "Chromium", 24, 3.849e-05],
	["Mn", "Manganese", 25, 2.428e-05],
	["Fe", "Iron", 26, 2.663e-03],
	["Co", "Cobalt", 27, 8.041e-06],
	["Ni", "Nickel", 28, 1.463e-04],
	["Cu", "Copper", 29, 1.397e-06],
	["Zn", "Zinc", 30, 3.352e-06],
	["Ga", "Gallium", 31, 9.668e-08],
	["Ge", "Germanium", 32, 3.849e-07],
	["As", "Arsenic", 33, 1.842e-08],
	["Se", "Selenium", 34, 2.020e-07],
	["Br", "Bromine", 35, 3.201e-08],
	["Kr", "Krypton", 36, 1.217e-07],
	["Rb", "Rubidium", 37, 1.929e-08],
	["Sr", "Strontium", 38, 6.242e-08],
	["Y", "Yttrium", 39, 1.497e-08],
	["Zr", "Zirconium", 40, 3.592e-08],
	["Nb", "Niobium", 41, 2.725e-09],
	["Mo", "Molybdenum", 42, 7.004e-09],
	["Ru", "Ruthenium", 44, 5.192e-09],
	["Rh", "Rhodium", 45, 5.563e-10],
	["Pd", "Palladium", 46, 3.430e-09],
	["Ag", "Silver", 47, 8.420e-10],
	["Cd", "Cadmium", 48, 4.735e-09],
	["In", "Indium", 49, 5.825e-10],
	["Sn", "Tin", 50, 9.668e-09],
	["Sb", "Antimony", 51, 9.448e-10],
	["Te", "Tellurium", 52, 1.397e-08],
	["I", "Iodine", 53, 3.276e-09],
	["Xe", "Xenon", 54, 1.532e-08],
	["Cs", "Caesium", 55, 1.110e-09],
	["Ba", "Barium", 56, 1.719e-08],
	["La", "Lanthanum", 57, 1.189e-09],
	["Ce", "Cerium", 58, 3.510e-09],
	["Pr", "Praseodymium", 59, 5.192e-10],
	["Nd", "Neodymium", 60, 2.428e-09],
	["Sm", "Samarium", 62, 8.229e-10],
	["Eu", "Europium", 63, 3.057e-10],
	["Gd", "Gadolinium", 64, 1.110e-09],
	["Tb", "Terbium", 65, 1.885e-10],
	["Dy", "Dysprosium", 66, 1.162e-09],
	["Ho", "Holmium", 67, 2.788e-10],
	["Er", "Erbium", 68, 7.858e-10],
	["Tm", "Thulium", 69, 1.189e-10],
	["Yb", "Ytterbium", 70, 6.536e-10],
	["Lu", "Lutetium", 71, 1.162e-10],
	["Hf", "Hafnium", 72, 6.536e-10],
	["Ta", "Tantalum", 73, 6.536e-11],
	["W", "Tungsten", 74, 5.693e-10],
	["Re", "Rhenium", 75, 1.680e-10],
	["Os", "Osmium", 76, 2.067e-09],
	["Ir", "Iridium", 77, 1.929e-09],
	["Pt", "Platinum", 78, 3.761e-09],
	["Au", "Gold", 79, 7.505e-10],
	["Hg", "Mercury", 80, 1.366e-09],
	["Tl", "Thallium", 81, 7.679e-10],
	["Pb", "Lead", 82, 8.229e-09],
	["Bi", "Bismuth", 83, 4.124e-10],
	["Th", "Thorium", 90, 9.893e-11],
	["U", "Uranium", 92, 2.663e-11],
]

## Elements that stay gaseous and never condense into asteroid rock —
## these are scooped from nebulae instead of mined.
const GASES := ["H", "He", "N", "Ne", "Ar", "Kr", "Xe"]

const CATEGORY_COLORS := {
	"gas":       Color(0.45, 0.85, 1.0),
	"alkali":    Color(1.0, 0.62, 0.3),
	"alkaline":  Color(0.95, 0.8, 0.35),
	"metal":     Color(0.65, 0.72, 0.85),
	"precious":  Color(1.0, 0.84, 0.35),
	"metalloid": Color(0.75, 0.6, 0.95),
	"nonmetal":  Color(0.5, 0.9, 0.55),
	"rare":      Color(0.95, 0.5, 0.8),
	"actinide":  Color(1.0, 0.42, 0.38),
}

const CATEGORIES := {
	"gas": ["H", "He", "N", "O", "F", "Ne", "Cl", "Ar", "Kr", "Xe"],
	"alkali": ["Li", "Na", "K", "Rb", "Cs"],
	"alkaline": ["Be", "Mg", "Ca", "Sr", "Ba"],
	"precious": ["Ru", "Rh", "Pd", "Ag", "Os", "Ir", "Pt", "Au"],
	"metalloid": ["B", "Si", "Ge", "As", "Sb", "Te"],
	"nonmetal": ["C", "P", "S", "Se", "Br", "I"],
	"rare": ["La", "Ce", "Pr", "Nd", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu"],
	"actinide": ["Th", "U"],
}

static var _by_symbol := {}
static var _rock := {}
static var _crystal := {}
static var _gas := {}


static func _lookup() -> Dictionary:
	if _by_symbol.is_empty():
		for e in TABLE:
			_by_symbol[e[0]] = e
	return _by_symbol


static func name_of(sym: String) -> String:
	return _lookup()[sym][1]


static func z_of(sym: String) -> int:
	return _lookup()[sym][2]


static func category(sym: String) -> String:
	for cat in CATEGORIES:
		if sym in CATEGORIES[cat]:
			return cat
	return "metal"


static func color_of(sym: String) -> Color:
	return CATEGORY_COLORS[category(sym)]


static func _normalized(weight_fn: Callable) -> Dictionary:
	var out := {}
	var total := 0.0
	for e in TABLE:
		var w: float = weight_fn.call(e)
		if w > 0.0:
			out[e[0]] = w
			total += w
	for sym in out:
		out[sym] = out[sym] / total
	return out


static func rock_fractions() -> Dictionary:
	## Asteroid rock = the condensed elements, real relative abundances.
	## (O dominates as oxides, then Si/Mg/Fe — like actual rock.)
	if _rock.is_empty():
		_rock = _normalized(func(e): return 0.0 if e[0] in GASES else float(e[3]))
	return _rock


static func crystal_fractions() -> Dictionary:
	## Rich crystal formations concentrate heavy elements (Z >= 39) tenfold —
	## ratios AMONG the heavies stay true, so no rare-element loop.
	if _crystal.is_empty():
		_crystal = _normalized(func(e):
			if e[0] in GASES:
				return 0.0
			return float(e[3]) * (10.0 if int(e[2]) >= 39 else 1.0))
	return _crystal


static func gas_fractions() -> Dictionary:
	## What a nebula scoop collects — the gases, real ratios (mostly H, He).
	if _gas.is_empty():
		_gas = _normalized(func(e): return float(e[3]) if e[0] in GASES else 0.0)
	return _gas


static func add_units(target: Dictionary, fractions: Dictionary, units: float) -> void:
	for sym in fractions:
		target[sym] = target.get(sym, 0.0) + fractions[sym] * units


static func fmt(x: float) -> String:
	## 3-significant-figure engineering format: 1.23k, 45.6m, 789n ...
	if x <= 0.0:
		return "—"
	const STEPS := [
		[1e9, "G"], [1e6, "M"], [1e3, "k"], [1.0, ""],
		[1e-3, "m"], [1e-6, "µ"], [1e-9, "n"], [1e-12, "p"], [1e-15, "f"],
	]
	for s in STEPS:
		if x >= s[0]:
			var v: float = x / s[0]
			if v >= 100.0:
				return "%.0f%s" % [v, s[1]]
			elif v >= 10.0:
				return "%.1f%s" % [v, s[1]]
			return "%.2f%s" % [v, s[1]]
	return "<1f"
