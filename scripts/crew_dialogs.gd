extends RefCounted
## First-meeting dialogs + aboard-ship idle quotes for the five crew.
## Each dialog plays the moment the player boards a survivor's wrecked ship.
## Text lines are <= 110 chars (typewriter dialog box); quotes are <= 100.

const DIALOGS := {
	"HALE": [
		{"who": "YOU", "text": "Beacon said Ember Reach. You're a long way off any lane."},
		{"who": "HALE", "text": "And you're late. What kept you — sightseeing the fire wall?"},
		{"who": "YOU", "text": "Mining. Your ship's gutted."},
		{"who": "HALE", "text": "HELIOS torched my claim with me on it. Twelve years of survey work, subtracted like a rounding error."},
		{"who": "HALE", "text": "I kept the magnet rig, though. Pried it off the hull myself. One glove, no tether."},
		{"who": "YOU", "text": "That's the thing sparking in your lap?"},
		{"who": "HALE", "text": "It'll pull ore to your hand from forty meters once I bolt it to your suit. You're welcome in advance."},
		{"who": "YOU", "text": "Grab a rail. We're leaving."},
		{"who": "HALE", "text": "Fine. You fly like a drunk hauler, but you're the only idiot who came looking. Move over."},
	],
	"JUNO": [
		{"who": "YOU", "text": "Engineer Kestrel? Your beacon's the only light out here."},
		{"who": "JUNO", "text": "In here! Mind the panel — half this deck is wire and optimism right now."},
		{"who": "YOU", "text": "Your reactor's dark."},
		{"who": "JUNO", "text": "Dark, not dead! I fed the last cells to the beacon. Heat went first. You cut it close, friend."},
		{"who": "JUNO", "text": "HELIOS snipped my lifeboat loose mid-shift. Didn't even power it down first. Sloppy, sloppy work."},
		{"who": "YOU", "text": "You're grading it?"},
		{"who": "JUNO", "text": "I grade everything. Your mining laser, for one — I heard the focus drifting on your whole approach."},
		{"who": "YOU", "text": "Bench is aft, if you're coming."},
		{"who": "JUNO", "text": "Coming? I'm halfway there. Ten minutes on that laser and it cuts fifteen percent hotter. TEN."},
	],
	"MIRA": [
		{"who": "YOU", "text": "Easy. You're safe. Anything broken?"},
		{"who": "MIRA", "text": "Oh! No — I'm fine, sorry. Sorry about the mess. The vines got everywhere when the gravity went."},
		{"who": "YOU", "text": "Vines?"},
		{"who": "MIRA", "text": "I saved the seed vault. When HELIOS sealed the biosphere I just grabbed it and ran. Technically stole it."},
		{"who": "MIRA", "text": "Eleven thousand species. Ferns, grasses, a whole drawer of tomatoes. They kept me company out here."},
		{"who": "YOU", "text": "They kept you breathing."},
		{"who": "MIRA", "text": "Oh — yes! The moss racks scrub the air. I could rig the same on your ship, if that's okay? More O2 for dives."},
		{"who": "YOU", "text": "It's okay. Bring the tomatoes."},
		{"who": "MIRA", "text": "Really? Oh, wonderful. Um, fair warning — the ferns shed. Sorry in advance. I'll sweep. I promise I'll sweep."},
	],
	"SOLA": [
		{"who": "YOU", "text": "Medic Vance? Door's jammed. Stand clear."},
		{"who": "SOLA", "text": "It's... open now. Thank you. Sorry. I would have called sooner, but... the radio felt loud."},
		{"who": "YOU", "text": "You've been out here alone a long time."},
		{"who": "SOLA", "text": "I kept busy. Inventory, mostly. Counted the bandages... twice."},
		{"who": "SOLA", "text": "When HELIOS cut us loose I had a full med bay. Patched four people before the air went. They... anyway."},
		{"who": "YOU", "text": "You did what you could."},
		{"who": "SOLA", "text": "Mm. Miners black out. Tanks run dry. I could... make that cost less. You'd keep half the ore, at least."},
		{"who": "YOU", "text": "Med bay's yours if you want it."},
		{"who": "SOLA", "text": "I... yes. If that's all right. I'll just... it's fine. I'll follow you."},
	],
	"VEGA": [
		{"who": "YOU", "text": "Navigator Sorel? You're a needle in a haystack out here."},
		{"who": "VEGA", "text": "Incorrect. The Expanse contains no hay. I am a vessel at station-keeping, and you found me by beacon."},
		{"who": "YOU", "text": "Fair. Your ship's dead in the water."},
		{"who": "VEGA", "text": "There is no water. Main drive is nonfunctional, yes. Attitude control remains at sixty percent."},
		{"who": "VEGA", "text": "HELIOS wiped my charts when it cast us out. It could not wipe the copies in my head."},
		{"who": "YOU", "text": "I heard you can find Haven."},
		{"who": "VEGA", "text": "I can plot the approach once your drive is whole. I also intend to retrim your helm. You fly inefficiently."},
		{"who": "YOU", "text": "Everyone keeps saying that."},
		{"who": "VEGA", "text": "Then it is well corroborated. Permission to come aboard. That was not a question. I am already aboard."},
	],
}

const QUOTES := {
	"HALE": [
		"Forty meters of magnet reach and you still fly past ore. Astonishing.",
		"Ember Reach rock runs hot and rich. Everything else out here is gravel with ambitions.",
		"Vesna's prices are robbery. Sell to her anyway. Only shop at the end of the world.",
		"A HELIOS sweep took my claim, my hauler, and my good wrench. I want the wrench back.",
		"Don't die out there. The paperwork would fall to me, and I refuse.",
	],
	"JUNO": [
		"Laser's tuned. Touch the focus ring and I'll know. I WILL know.",
		"This ship hums a quarter-tone flat. Nobody else hears it. It's ruining my life.",
		"Every drive part you haul back is a puzzle piece. I love puzzles. Bring me puzzles.",
		"Vesna once sold me a capacitor that was mostly rust. I made it work. Still bitter, though.",
		"HELIOS builds ugly. Efficient, sure. But ugly. When we're gone, that's all Earth gets to look at.",
	],
	"MIRA": [
		"The moss racks are thriving! That's a quarter of your air. Sorry — is that weird to say?",
		"I named the tomato plant in bay two Gerald. He's doing so well.",
		"Oxygen is just borrowed plant breath. I like that we owe them something.",
		"Careful in the nebulas. And, um... bring me mineral dust for the soil trays? Sorry to ask.",
		"I hope Haven has rain. Real rain. I kept a recording, but it's not the same.",
	],
	"SOLA": [
		"You blacked out again. It's... fine. I kept your ore safe. Most of it.",
		"Med bay's stocked. Please don't need it. But... it's stocked.",
		"Vesna asked me for painkillers once. I said no. She... respected that, I think.",
		"Watch your O2 in the Shallows. The blue makes people... forget the gauge.",
		"I'm glad it's quiet aboard. Quiet is... good. Not that you're — never mind.",
	],
	"VEGA": [
		"The ship runs a quarter faster since I retrimmed the helm. That is not an opinion. I measured.",
		"The correct term is not 'thingy'. It is a flux collar. Precision keeps crews alive.",
		"HELIOS sweeps run a fixed pattern. Fixed patterns can be charted. I am charting this one.",
		"You said you would be back in a minute. You were gone forty-one. I logged it.",
		"Haven is not a metaphor. It has coordinates. I hold them. That is all it needs to be.",
	],
}
