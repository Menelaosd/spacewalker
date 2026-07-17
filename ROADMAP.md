# Spacewalker — Roadmap

Planned features, not yet built. Specs live here until they land in DEVLOG.

---

## Haven endgame — TWO TRACKS (matter + people)

Replaces the current flag-flip "Haven" win-state (`game_complete && rescued>=5`)
with a two-track capstone: **build the world (GENESIS) + bring the people (STATIONS).**
The full finale reads: rescue 5 crew (characters) → gather the elements (the world)
→ pledge 500 souls (the people) → light Haven. Haven unlocks only when **both** the
Genesis manifest is complete **and** ≥500 survivors are pledged.

---

## Track 1 — QUEST: GENESIS (Reseed Haven)

Gather the building blocks of a living world and feed them to the fabricator.

### The manifest

> **QUEST: GENESIS — Reseed Haven**
> *One dead system, one fabricator, and everything a living world is made of.*
>
> **SEED THE SEAS & SKY**
> - ☐ Oxygen (O) ×800 — the air, and half of all water
> - ☐ Carbon (C) ×500 — the skeleton of every living molecule
> - ☐ Hydrogen (H) ×250 — the other half of the seas — scoop from nebulae
> - ☐ Nitrogen (N) ×50 — the backbone of protein and DNA — scoop from nebulae
>
> **RAISE THE LAND & THE GREEN**
> - ☐ Iron (Fe) ×100 — a molten core, and the iron in blood
> - ☐ Magnesium (Mg) ×100 — the green heart of chlorophyll
> - ☐ Silicon (Si) ×80 — soil, stone, and the first shells
> - ☐ Sulfur (S) ×40 — the cross-links that hold proteins together
>
> **TEMPER THE WORLD** *(scarce — mine, or enrich from surplus)*
> - ☐ Calcium (Ca) ×30 — bone, shell, and coral
> - ☐ Aluminium (Al) ×25 — the crust underfoot
> - ☐ Sodium (Na) ×20 — the salt of the sea, the pulse of a nerve
> - ☐ Nickel (Ni) ×15 — core-metal, catalyst of the first life
>
> **Reward:** the **Haven** ending — *the system breathes again.*

### DESIGN GUARDRAILS — this is a culmination, NOT a grind

The manifest is a spec; the *feel* is the point. Rules, in priority order:

1. **Tune quantities to typical endgame stores.** By the end of the 5-rescue
   campaign the player has already banked most of this passively (O/C/Mg/Si/Fe
   flood in). Genesis should read as *"look what your journey gathered,"* ~90%
   done on arrival — a shortfall is one or two targeted trips, never farming.
2. **Scarce elements (Ca/Al/Na/Ni) come from things you already do** — derelict
   salvage, rescue/quest rewards, trader stock, or **enrichment** (spend surplus
   commons → scarce, via the fabricator). NEVER "mine the same field 40 times."
3. **Pay it off visibly, in stages.** Each stage delivered changes the world
   on-screen: Seas & Sky → water + atmosphere appear; Land & Green → terrain +
   plant life; Temper → fauna/detail. The dopamine is watching a dead world wake,
   not filling a bar.
4. **Layered difficulty.** A "good-enough Haven" (the emotional ending everyone
   gets) completes almost passively; a "perfect Haven" is the optional
   completionist stretch. No one is forced to grind for the base ending.

### Why these elements (real chemistry → collection payoff)
CHNOPS backbone (C,H,N,O,P… P dropped as too rare to mine) + bulk ions + a couple
of structural metals = the minimum to bootstrap life + a biosphere. Rarity in the
game IS real solar abundance (`Elements.TABLE`), so the gradient — hundreds of the
common stuff, tens of the scarce — is physically honest. Finally gives the 83
collectible elements a purpose beyond the dex.

### Dependencies / build notes
- **Enrichment mechanic** (fabricator: N common units → 1 scarce unit) — the thing
  that makes the scarce four achievable without a grind. Build this first.
- Win-condition currently: `game_complete && rescued >= 5` (see title.gd:194).
  Genesis becomes the new gate; keep the existing flag as the trigger to *offer*
  the quest once all 5 crew are aboard.
- Element stores already exist (`GameState.elements`, cap 9999) — the quest just
  reads them. Scarce-source hooks: derelict salvage, trader, contracts.

---

## Track 2 — SPACE STATIONS (the 500 survivors)

Genesis gives Haven a world; the stations give it people — and make the vast,
empty universe feel *inhabited*. The nebulae stop being scenery and become places
where people held on.

### The mechanic
- **Stations = colony POIs**, hand-placed across the regions (landmarks, like
  nebulae — NOT random). Each has a **name, a leader, and a population** (~40–250).
- Fly to a station → **dock (E)** → meet the **leader** (dialog; reuse the rescue /
  `dialog_scene.gd` flow) → solve the colony's crisis (minigame, below) → hand over
  a **transmitter** → that colony is **pledged** (a flag marking them to migrate to
  Haven; NO escort/convoy — the transmitter is the fiction that lets them find it).
- **Transmitter** = a fabricator recipe (costs ore/elements), **one consumed per
  station** — a resource sink and a soft gate.
- **Goal: ≥500 pledged survivors.** Stations total >500 (~10 stations) so reaching
  500 is a **routing CHOICE**, not "visit them all."

### Colony minigame — earn the pledge by solving their crisis
A leader won't hand over lives on a promise. Each station has a **crisis**, and
solving it IS how you earn the transmitter handshake (diegetic, not an arbitrary
gate). Keep them **30–60s, one-and-done per colony, handcrafted, fail-soft** (a wrong
answer costs a retry / a little goodwill, never a hard block). 3–4 "shapes" so ten
colonies don't feel identical:

1. **ELEMENT RIDDLE (signature — the one only this game can make).** The colony's
   greenhouse/reactor/medbay is failing for want of one substance; the leader gives
   *clues, not the answer*; you supply the right element from your stores → system
   relights on-screen → they pledge. e.g. *"the metal at the green heart of every
   leaf, light, burns bright, twelfth in the table"* → **Mg**. Teaches real
   chemistry, makes the 83-element collection matter a THIRD time, infinite
   handcrafted variety, zero new tech (elements + inventory + dialog already exist).
2. **Conduit / power reroute** (engineering colony) — a small node-flow puzzle.
3. **Signal alignment** (relay colony) — match a frequency / align the dish.
4. **EVA repair** (derelict-hab) — a short spacewalk task using the laser/mining verbs.

Build the ELEMENT RIDDLE first — cheapest + most on-brand; the others are variety
seasoning for later.

### Graphics — CAPTAIN IS PROVIDING
- ~3–5 **station exterior** sprites (flight view; varied size/silhouette — outpost →
  hab-ring → spire — so ~10 stations aren't identical). Provide at ~**2× on-screen
  size** so they stay crisp when drawn small (see minification lesson from devices).
- **Leader portraits**, one per station, in the crew ID-card style.
- Optional: radar/star-chart station glyph (can vectorize like `derelict.svg`).
- Interior tiles + colonist NPCs ONLY if we later add walk-inside stations — the
  dialog encounter ships the loop first.

### Build order (dialog-first, depth later)
1. Data + placement — `STATIONS` const (name/pos/pop/leader), `GameState.stations`
   + `survivors_pledged`, saved/loaded (like `seen_regions`).
2. World presence — station sprite in flight + radar/star-chart markers + dock prompt
   (copy the derelict/beacon patterns).
3. Transmitter recipe + dock→leader dialog→(minigame)→pledge flow.
4. Element-riddle minigame (then the other shapes as variety).
5. Haven gate — require Genesis complete AND survivors ≥ 500.
6. Depth pass (later): walk INSIDE a station (reuse `ship_interior` tech) — find the
   leader among a crowd of colonists.

---

## Backlog (discussed, not yet specced)
- **Codex / dex** — catalogue of elements / nebulae / wrecks / crew; reads the
  `seen_regions` + `discovered` backbone already in place.
- **Contract board** — jobs at the bridge comms station (deliver element X,
  salvage wreck Y, scan region Z) for ore/recipes; gives ore an economy sink.
- **Space fauna** — creatures to scan/harvest/avoid on dives (the sea-life analog).
- **Board-a-derelict** — walk inside wrecks to salvage & find crew/logs (reuses
  the ship_interior tech).
- **Crew jobs** — assign rescued crew to stations for passive perks.
