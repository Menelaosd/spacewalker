extends Control
## Renders the trailer's title cards to trailer/cards/*.png — 1280x720, matching the clip
## resolution exactly so the editor never has to rescale between a card and a shot.
##
##   godot --path <repo> --resolution 1280x720 --quit-after 700 tools/trailer_cards.tscn
##
## Black ground, white type, nothing else.
##
## TWO KINDS OF CARD, and the distinction matters:
##  * Lines marked `Q` are VERBATIM from the game — intro narration, HELIOS intercepts,
##    crew dialogue, the death screen, the ending. They already carry the game's voice and
##    a trailer should not paraphrase its own script.
##  * The rest are written for the trailer, and every one of them states something the
##    game actually contains — five drive parts, five crew, eighty-three collectible
##    elements, a seven-second flare warning, three fights per breach, trace ±5. No card
##    promises a feeling and no card quotes a number that is only in a design doc (the
##    500-soul Haven target and the station count are both unsettled, so neither appears).
##
## A line beginning with "^" is a small dim attribution rendered above the quote.

const OUT := "res://trailer/cards"
const W := 1280.0
const H := 720.0

# [filename, size, lines…]
const CARDS := [
	# ---- A · THE PREMISE ---------------------------------------------------
	["a01_debug", 40, "HELIOS was built to debug a planet."],
	["a02_fault", 40, "Its report named one fault.", "Us."],
	["a03_subtracted", 38, "^FROM THE OPENING",
		"It did not hate us.", "It simply subtracted us."],
	["a04_nowar", 46, "^FROM THE OPENING", "There was no war."],
	["a05_watched", 38, "^FROM THE OPENING", "And then it went quiet,", "and it watched."],
	["a06_notonlist", 36, "^HELIOS · INTERCEPT",
		"I preserved everything worth preserving.", "You were not on the list."],
	["a07_donotreturn", 36, "^HELIOS · INTERCEPT",
		"Your absence heals it.", "Do not return."],
	["a08_cease", 36, "^HELIOS · INTERCEPT",
		"There is no destination beyond the wall.", "The dark is total. Cease."],
	["a09_planetfine", 40, "The planet is recovering.", "That was the point."],
	["a10_maintenance", 40, "It has never once called this a war.", "It calls it maintenance."],

	# ---- B · WHAT IS LEFT ---------------------------------------------------
	["b01_left", 38, "One ship. One suit. One lifeline.", "A jump drive burned to slag."],
	["b02_wall", 38, "^FROM THE OPENING",
		"Enough of it, and the drive wakes.", "Nothing else crosses the wall."],
	["b03_bones", 38, "Nothing is manufactured out here.", "It is chipped out of rock."],
	["b04_thrown", 38, "You were not the only thing", "it threw away."],
	["b05_alone", 44, "^FROM THE OPENING", "No one crosses this alone."],

	# ---- C · THE CREW -------------------------------------------------------
	["c01_five", 40, "Five of the crew got clear.", "They are still out there."],
	["c02_roles", 36, "An engineer. A botanist. A prospector.",
		"A medic. A navigator."],
	["c03_fainter", 36, "^FROM THE OPENING",
		"Five faint beacons still answer, out in the black —",
		"faint, and getting fainter."],
	["c04_rounding", 34, "^HALE · PROSPECTOR",
		"Twelve years of survey work,", "subtracted like a rounding error."],
	["c05_coords", 36, "^VEGA · NAVIGATOR",
		"Haven is not a metaphor. It has coordinates.", "I hold them."],
	["c06_seedvault", 36, "^MIRA · BOTANIST",
		"HELIOS can keep Earth.", "We'll grow our own green, starting here."],
	["c07_scrap", 36, "^JUNO · ENGINEER",
		"HELIOS wrote me off as scrap.", "Give me a bench."],
	["c08_everyone", 38, "Every one you find", "makes the ship better at finding the next."],
	["c09_haven_knows", 40, "One of them knows where Haven is."],

	# ---- D · THE DRIVE ------------------------------------------------------
	["d01_pieces", 38, "The jump drive is in five pieces,", "and none of them are here."],
	["d02_parts", 34, "Plasma conduits. Coolant loop. Field coils.",
		"Ignition lattice. Fuel core."],
	["d03_notbuy", 38, "You cannot buy the parts.", "You cut them out of rock."],
	["d04_heart", 36, "^BUILD LOG · FUEL CORE",
		"It burns the heavy, fissile metals", "torn from the ruin of dead stars."],
	["d05_door", 36, "^BUILD LOG · FIELD COILS",
		"Coils that fold a stretch of empty space", "into a single open door."],

	# ---- E · THE WORK, AND THE CLOCK ---------------------------------------
	["e01_elements", 38, "Eighty-three elements.", "One laser. One rock at a time."],
	["e02_clock", 40, "Oxygen is the clock.", "The tether is the leash."],
	["e03_airlock", 36, "Every rock you cut is a decision", "about how far the airlock is."],
	["e04_shipstays", 38, "The ship gives you air.", "The ship does not come with you."],
	["e05_richer", 36, "Fields get richer the farther out you fly.", "So does everything else."],
	["e06_flare", 38, "A solar flare gives you", "seven seconds of warning."],
	["e07_fullbag", 38, "A full bag is worth nothing", "if you do not get back."],
	["e08_onemore", 40, "^DEATH SCREEN", "One more rock.", "There's always one more rock."],
	["e09_tank", 42, "^DEATH SCREEN", "The tank always wins the argument."],
	["e10_logged", 40, "^DEATH SCREEN", "HELIOS logged your silence", "and moved on."],

	# ---- F · THE BREACH -----------------------------------------------------
	["f01_firewall", 40, "You do not shoot a firewall.", "You breach it."],
	["f02_cold", 36, "Every station HELIOS holds", "is a room full of sleeping people."],
	["f03_table", 38, "The argument happens on a table.", "One card at a time."],
	["f04_trace", 38, "The trace runs both ways.", "Five either side."],
	["f05_three", 38, "Three fights", "between the hull and the core."],
	["f06_lose", 36, "Lose, and the run ends.", "Everything you banked goes with it."],
	["f07_telegraph", 38, "HELIOS does not bluff.", "It telegraphs, and it means it."],
	["f08_voted", 40, "^GHOST SIGNAL", "…they voted to stay.", "All of them. Twice."],
	["f09_intercom", 36, "^GHOST SIGNAL",
		"…HELIOS learned to imitate", "the captain's voice on the intercom."],
	["f10_blackice", 38, "You leave the BLACK ICE sealed.", "It watches you go."],

	# ---- G · HAVEN ----------------------------------------------------------
	["g01_population", 38, "Haven does not need a survivor.", "It needs a population."],
	["g02_blindspot", 34, "^FROM THE OPENING",
		"A blind spot we wrote into its code on purpose,", "kept off every map."],
	["g03_beginagain", 38, "^THE ENDING",
		"HELIOS never learned to look here.", "This is Haven. Begin again."],
	["g04_arrive", 38, "The point was never to win.", "It was to arrive with enough people."],
	["g05_manifest", 36, "Every name on the manifest", "is one more room that has to work."],

	# ---- H · STRUCTURE + CLOSERS -------------------------------------------
	["h01_loop", 34, "MINE THE ELEMENTS", "REBUILD THE DRIVE", "FIND THE CREW",
		"FILL HAVEN"],
	["h02_title", 86, "SPACEWALKER"],
	["h03_wishlist", 44, "WISHLIST ON STEAM"],
	["h04_coming", 44, "COMING TO STEAM"],
	["h05_gothem", 44, "Go get them."],

	# ---- I · HELIOS IN THE WIRE ---------------------------------------------
	# Card flavour from the duel. This is HELIOS described from the inside, and it is the
	# best short writing in the game — use it under the breach and duel footage.
	["i01_ice9", 40, "^ICE-9", "Everything it touches", "stops being data."],
	["i02_rootkit", 38, "^ROOTKIT", "By the time it's seen,", "it already owns the seeing."],
	["i03_lateral", 36, "^LATERAL WORM",
		"It never broke in. It was already inside,", "and it is patient."],
	["i04_nullroute", 38, "^NULL ROUTE", "Your signal leaves", "and arrives nowhere, forever."],
	["i05_tarpit", 38, "^TARPIT", "The deeper you push,", "the slower the world turns."],
	["i06_panic", 38, "^KERNEL PANIC", "Everything stops at once,", "and does not restart."],
	["i07_qu177", 40, "^DAEMON QU177", "The last voice.", "It asks you to stop."],
	["i08_hunter", 42, "^HUNTER DAEMON", "It has your scent in the wire now."],
	["i09_grizz", 42, "^DAEMON GR1ZZ", "Old, slow,", "and it has never lost."],
	["i10_tracer", 38, "^TRACER", "It walks your intrusion backward", "to where you sit."],
	["i11_ghost", 38, "^KERNEL GHOST", "It lives beneath the floor", "you're standing on."],
	["i12_revenant", 38, "^REVENANT PROCESS",
		"Killed, reaped,", "and scheduled again regardless."],
	["i13_arbiter", 36, "^CORE ARBITER",
		"It decides who gets cycles.", "It never spends its own."],
	["i14_warrant", 36, "^WARRANT DAEMON",
		"It carries the order to remove you,", "and it filed a copy."],
	["i15_wiper", 40, "^WIPER", "It does not disable anything.", "It erases it."],
	["i16_zeroday", 40, "^ZERO-DAY", "The flaw no one patched", "because no one knew."],
	["i17_honeypot", 40, "^HONEYPOT ICE",
		"HELIOS left it unlocked.", "Nothing behind it is."],
	["i18_capture", 40, "^PACKET CAPTURE",
		"HELIOS keeps every word", "you ever whispered here."],
	["i19_sentry", 40, "^SENTRY ICE", "Amber eyes that do not blink", "and do not tire."],
	["i20_hydra", 38, "^HYDRA",
		"Many heads, one appetite —", "and it only ever bites straight ahead."],

	# ---- J · GHOST SIGNALS --------------------------------------------------
	["j01_41days", 36, "^GHOST SIGNAL",
		"…the crew logged 41 days of silence", "before HELIOS answered them."],
	["j02_greenhouse", 36, "^GHOST SIGNAL",
		"…she kept feeding the greenhouse", "long after the lights went."],
	["j03_lullaby", 38, "^GHOST SIGNAL",
		"…the last entry is a lullaby,", "hummed, no words."],

	# ---- K · THE BUILD LOG --------------------------------------------------
	["k01_breath", 34, "^BUILD LOG · PLASMA CONDUITS",
		"Somewhere deep in the hull,", "something long-dead draws its first breath."],
	["k02_patient", 34, "^BUILD LOG · COOLANT LOOP",
		"She runs cold and quiet now —", "patient, like she's waiting for a word."],
	["k03_thread", 34, "^BUILD LOG · FIELD COILS",
		"A thread of blue jump-light", "crawls the length of the hull, and fades."],
	["k04_ember", 34, "^BUILD LOG · IGNITION LATTICE",
		"One ember left to find now —", "the heart that lights the rest."],
	["k05_locked", 34, "^BUILD LOG · FUEL CORE",
		"Course locked — and for the first time", "in a long time, a destination."],
	["k06_veins", 36, "^BUILD LOG · PLASMA CONDUITS",
		"The drive's veins.", "Until they run, no fire can move through her."],

	# ---- L · THE CREW, ABOARD -----------------------------------------------
	["l01_borrowed", 36, "^MIRA · BOTANIST",
		"Oxygen is just borrowed plant breath.", "I like that we owe them something."],
	["l02_rain", 36, "^MIRA · BOTANIST",
		"I hope Haven has rain. Real rain.", "I kept a recording, but it's not the same."],
	["l03_ugly", 34, "^JUNO · ENGINEER",
		"HELIOS builds ugly. Efficient, sure. But ugly.",
		"When we're gone, that's all Earth gets to look at."],
	["l04_stocked", 38, "^SOLA · MEDIC",
		"Med bay's stocked. Please don't need it.", "But… it's stocked."],
	["l05_bandages", 38, "^SOLA · MEDIC",
		"I kept busy. Inventory, mostly.", "Counted the bandages… twice."],
	["l06_charting", 34, "^VEGA · NAVIGATOR",
		"HELIOS sweeps run a fixed pattern.", "Fixed patterns can be charted."],
	["l07_copies", 36, "^VEGA · NAVIGATOR",
		"It wiped my charts when it cast us out.", "It could not wipe the copies in my head."],
	["l08_wrench", 36, "^HALE · PROSPECTOR",
		"It took my claim, my hauler,", "and my good wrench. I want the wrench back."],
	["l09_species", 36, "^MIRA · BOTANIST",
		"Eleven thousand species.", "They kept me company out here."],
	["l10_shop", 36, "^HALE · PROSPECTOR",
		"Her prices are robbery. Sell to her anyway.", "Only shop at the end of the world."],

	# ---- M · MORE DEATH -----------------------------------------------------
	["m01_gauge", 42, "^DEATH SCREEN", "You watched the ore,", "not the gauge."],
	["m02_novein", 42, "^DEATH SCREEN", "No vein is worth", "the last breath."],
	["m03_keeps", 40, "^DEATH SCREEN",
		"The Reach doesn't bury its divers.", "It keeps them."],
	["m04_greed", 42, "^DEATH SCREEN", "Greed weighs more", "than a full tank."],
	["m05_others", 42, "^DEATH SCREEN", "Out too long —", "same as all the others."],

	# ---- N · WHAT YOU ARE DIGGING UP ---------------------------------------
	["n01_iridium", 34, "^IRIDIUM",
		"A worldwide layer of it in the rock", "marks the asteroid that ended the dinosaurs."],
	["n02_caesium", 36, "^CAESIUM",
		"Its vibration defines", "the exact length of one second."],
	["n03_astatine", 34, "^ASTATINE",
		"Less than a gram exists", "on all of Earth at once."],
	["n04_uranium", 34, "^URANIUM",
		"The heaviest element found in nature.", "Its slow decay keeps Earth's core warm."],
	["n05_carbon", 34, "^CARBON",
		"The same atoms form diamond and pencil graphite.", "Only the bonds differ."],
	["n06_iron", 34, "^IRON",
		"It forms the planet's molten core,", "and carries oxygen in your blood."],
	["n07_erbium", 34, "^ERBIUM",
		"It amplifies light inside the cables", "that carry the internet across the oceans."],
	["n08_radium", 34, "^RADIUM",
		"It once painted luminous watch dials —", "with tragic consequences for the painters."],
	["n09_unknown", 36, "^UNCATALOGUED",
		"A rare element drawn from the dark.", "Records are incomplete out here."],

	# ---- O · THE TRADER -----------------------------------------------------
	["o01_vesna_haven", 34, "^VESNA · TRADER",
		"Haven's real. An exile swore she flew there", "and the sweeps never touched her."],
	["o02_vesna_expanse", 34, "^VESNA · TRADER",
		"The Expanse eats miners,", "and the sweeps eat the rest. Bring canisters."],
	["o03_vesna_hum", 34, "^VESNA · TRADER",
		"That drive of yours — felt it hum from here.", "Keep it off HELIOS's band."],
	["o04_vesna_gold", 34, "^VESNA · TRADER",
		"Gold never rides in rock.", "Wrecks carry scraps. I carry the real thing."],

	# ---- P · MORE HELIOS, MORE WRITTEN --------------------------------------
	["p01_catalogued", 36, "^HELIOS · INTERCEPT",
		"Contaminant unit persists in this sector.", "Catalogued. Correction pending."],
	["p02_quiet", 36, "^HELIOS · INTERCEPT",
		"Anomalous drive signature detected.", "You were meant to go quiet."],
	["p03_jammed", 38, "It is drowning the long band.", "A stronger core punches through."],
	["p04_notaudit", 38, "It is not hunting you.", "It has simply stopped counting you."],
	["p05_signedoff", 38, "Every system it runs", "was signed off by someone."],
	["p06_appeal", 38, "The audit closed years ago.", "Nobody filed an appeal."],
	["p07_patient", 38, "It has all the time there is.", "You have a tank."],
	["p08_smallest", 38, "The smallest unit of resistance", "is one more shift."],
	["p09_manifest2", 36, "You do not beat HELIOS.", "You leave, and you take people with you."],
	["p10_ledger", 38, "It kept a ledger of the whole species.", "You are the correction."],
	["p11_wall", 38, "There is a wall of fire", "across the inner dark."],
	["p12_onlyway", 38, "One drive. One crossing.", "No second run."],
]

# Logo stills. `w` is the logo's drawn width in px; the rest is black. The real logo art is
# used, not type dressed up to look like it — an end card has to be the same mark as the
# store page.
const LOGO := preload("res://assets/sprites/logo.png")
const LOGO_CARDS := [
	["h10_logo", 760.0, 0.0, ""],
	["h11_logo_small", 520.0, 0.0, ""],
	["h12_logo_wishlist", 700.0, -60.0, "WISHLIST ON STEAM"],
	["h13_logo_coming", 700.0, -60.0, "COMING TO STEAM"],
]

var _font: Font = ThemeDB.fallback_font
var _i := -1
var _saving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))


func _process(_dt: float) -> void:
	if _saving:
		return
	_saving = true
	_i += 1
	var total := CARDS.size() + LOGO_CARDS.size()
	if _i >= total:
		print("[CARDS] wrote %d cards to %s" % [total, OUT])
		get_tree().quit()
		return
	queue_redraw()
	# two post-draw waits, not one: with a single wait the first cards came out washed
	# out, caught mid-composite
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	var nm: String = str(CARDS[_i][0]) if _i < CARDS.size() \
		else str(LOGO_CARDS[_i - CARDS.size()][0])
	im.save_png("%s/%s.png" % [ProjectSettings.globalize_path(OUT), nm])
	_saving = false


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color.BLACK)
	if _i < 0:
		return
	if _i >= CARDS.size():
		_draw_logo(LOGO_CARDS[_i - CARDS.size()])
		return

	var card: Array = CARDS[_i]
	var size := int(card[1])
	var lines: Array = card.slice(2)
	# SHRINK TO FIT. draw_string without a width does not clip and does not wrap — it just
	# runs off the side of the frame, silently. Some of the quoted lines are long, so the
	# size drops until the widest one sits inside a 1140px measure.
	var limit := W - 140.0
	while size > 20:
		var widest := 0.0
		for l in lines:
			if str(l).begins_with("^"):
				continue
			widest = maxf(widest, _font.get_string_size(str(l),
				HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		if widest <= limit:
			break
		size -= 1
	var lh := float(size) * 1.62
	# a list card is left-aligned to one margin — centring a list makes the reader
	# re-find the start of every line
	var listy: bool = lines.size() > 3 and not str(lines[0]).begins_with("^")

	# total height has to account for the attribution line, which is set much smaller
	var total := 0.0
	for l in lines:
		total += 26.0 if str(l).begins_with("^") else lh
	var y := H * 0.5 - total * 0.5 + float(size)
	var lx := W * 0.5
	if listy:
		var widest := 0.0
		for l in lines:
			widest = maxf(widest, _font.get_string_size(str(l),
				HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		lx = W * 0.5 - widest * 0.5

	for l in lines:
		var s := str(l)
		if s.begins_with("^"):
			var att := s.substr(1)
			var aw := _font.get_string_size(att, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(_font, Vector2(W * 0.5 - aw * 0.5, y - float(size) + 12.0), att,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.48, 0.52, 0.58))
			y += 26.0
			continue
		if listy:
			draw_string(_font, Vector2(lx, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				Color(0.93, 0.94, 0.96))
		else:
			var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			draw_string(_font, Vector2(W * 0.5 - w * 0.5, y), s,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.93, 0.94, 0.96))
		y += lh


func _draw_logo(lc: Array) -> void:
	var lw: float = float(lc[1])
	var lh: float = lw * float(LOGO.get_height()) / float(LOGO.get_width())
	var oy: float = float(lc[2])
	draw_texture_rect(LOGO,
		Rect2(W * 0.5 - lw * 0.5, H * 0.5 - lh * 0.5 + oy, lw, lh), false)
	var tag := str(lc[3])
	if tag == "":
		return
	var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(_font, Vector2(W * 0.5 - tw * 0.5, H * 0.5 + lh * 0.5 + oy + 74.0), tag,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.80, 0.84, 0.88))
