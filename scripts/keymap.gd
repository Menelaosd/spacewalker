## Single source of truth for every player control in Spacewalker.
## Preloaded (not class_name) so standalone runs never miss it.
##
## Two jobs:
##   1. HINTS drives the on-screen keycap prompt bars (UITheme.draw_hints), so
##      the hints can never drift out of sync with the real bindings.
##   2. ACTIONS is the full binding table — one row per action, with the physical
##      key(s) and a placeholder controller glyph. When we add gamepad support,
##      map here and nowhere else.
##
## Contexts: "interior" (walking the ship), "flight" (piloting), "spacewalk"
## (EVA / mining). Modal prompts (inventory, upgrade, rename, comms, intro) are
## listed too so nothing is missed.

# action id -> {keys, label, controller, context, note}
const ACTIONS := {
	# movement
	"walk":       {"keys": "WASD",  "label": "walk",      "controller": "L-stick", "ctx": "interior"},
	"thrust":     {"keys": "W/S",   "label": "thrust",    "controller": "L-stick Y", "ctx": "flight"},
	"turn":       {"keys": "A/D",   "label": "turn",      "controller": "L-stick X", "ctx": "flight"},
	"eva_move":   {"keys": "WASD",  "label": "thrust",    "controller": "L-stick", "ctx": "spacewalk"},
	"stabilize":  {"keys": "Space", "label": "stabilize", "controller": "A",       "ctx": "spacewalk"},
	# actions
	"mine":       {"keys": "LMB",   "label": "mine",      "controller": "RT",      "ctx": "spacewalk"},
	"interact":   {"keys": "E",     "label": "interact",  "controller": "A",       "ctx": "interior"},
	"dock":       {"keys": "E",     "label": "dock",      "controller": "A",       "ctx": "flight"},
	"enter_ship": {"keys": "E",     "label": "enter ship","controller": "A",       "ctx": "spacewalk"},
	"expand":     {"keys": "E",     "label": "expand",    "controller": "A",       "ctx": "interior"},
	"leave_helm": {"keys": "Q",     "label": "leave",     "controller": "B",       "ctx": "flight"},
	"rename":     {"keys": "R",     "label": "rename",    "controller": "Y",       "ctx": "interior"},
	"inventory":  {"keys": "I",     "label": "inventory", "controller": "Select",  "ctx": "any"},
	"menu":       {"keys": "Esc",   "label": "menu",      "controller": "Start",   "ctx": "any"},
	# modal / menu keys
	"buy_1_3":    {"keys": "1-3",   "label": "buy",       "controller": "D-pad",   "ctx": "comms"},
	"confirm":    {"keys": "Enter", "label": "save",      "controller": "A",       "ctx": "rename"},
	"cancel":     {"keys": "Esc",   "label": "cancel",    "controller": "B",       "ctx": "modal"},
	"close":      {"keys": "Esc",   "label": "close",     "controller": "B",       "ctx": "modal"},
	"scroll":     {"keys": "Wheel", "label": "scroll",    "controller": "RS",      "ctx": "inventory"},
	"advance":    {"keys": "Space", "label": "continue",  "controller": "A",       "ctx": "intro"},
	"skip":       {"keys": "Esc",   "label": "skip",      "controller": "B",       "ctx": "intro"},
}

# ready-made keycap rows for UITheme.draw_hints — [[keys, label], ...]
const HINTS := {
	"interior":  [["WASD", "walk"], ["E", "interact"], ["R", "rename"], ["I", "inventory"], ["Esc", "menu"]],
	"flight":    [["W/S", "thrust"], ["A/D", "turn"], ["E", "dock"], ["Q", "leave"], ["Esc", "menu"]],
	"spacewalk": [["WASD", "thrust"], ["Space", "stabilize"], ["LMB", "mine"], ["I", "inventory"], ["Esc", "menu"]],
}


static func hint(ctx: String) -> Array:
	return HINTS.get(ctx, [])
