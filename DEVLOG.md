# Spacewalker — Dev Log

Core updates to the game, newest first. Every meaningful change lands here.
(Format: date · what changed · why it matters.)

---

## 11/07/2026 — v1.0-shape: the dynamic ship (hull build canvas), VHS, cooler fog

**The rooms concept, finally as intended**: the interior is an **8x4 grid
masked to a ship-shaped hull** (bow right, matching the exterior art).
Six core rooms sit amidships as a connected cluster; everything else is
bare hull — dark overlay, visible cyan build grid, structural
cross-braces. **You expand cell by cell**: glowing "+" bays appear on
every bare hull cell adjacent to the built ship; E builds (20 ore,
hologram preview, red when unaffordable). Only adjacent cells can be
built (verified: non-adjacent/outside-hull/occupied all rejected);
expansions persist in saves; walkability is per-cell (crew slides along
unbuilt hull, can't enter it). Hull walls auto-trace the silhouette;
doorway markers appear between adjacent built rooms. Hull shape is one
HULL_MASK string-array in GameState — reshaping the ship is an edit.

Also, per feedback:
- **Nebulas v5**: third noise channel drifts whole regions green/teal
  and blue — purple/pink clouds with cool undercurrents.
- **Vignette removed** (user disliked it).
- **VHS filter** (shaders/vhs.gdshader on screen_fx): chromatic
  aberration, scanlines, static grain, per-line wobble, tape-jitter
  band, rolling luminance — applied under the HUD in all scenes + title,
  so the world wears the tape and the instruments stay crisp.

---

## 11/07/2026 — Nebulas v4: high dynamic range (more dark, more light, wider hues)

Second tuning round on user feedback: hue drift widened to ±0.16 (full
purple↔pink swing), and the density curve split into two branches —
**dark dust** (below threshold: deep tinted near-black fog, denser as
density drops) and **bright fog** (climbs to near-white hot cores).
The result: dramatic voids and burning billows, reference-matched.

---

## 11/07/2026 — Nebulas v3: real smoke (user reference-matched)

The ellipse wisps read as stacked circles — user wanted smoke/fog with
color variance (reference: dense purple billowing clouds). Now done
properly with **fractal noise**: `scripts/nebula_fog.gd` generates a
320px fog texture per nebula (FastNoiseLite fbm 6-octave density,
pow-contrast for billows + dark voids, second noise channel drifting
the hue, luminous pockets where dense, radial falloff). Two layers
drawn counter-drifting = living smoke. Lazily generated, cached per
session. Dive scene reuses the same texture when parked inside.
Also: screen-FX vignette softened to nested triangles (the hard
triangle edge was visible over bright fog), denser star layers,
46 tinted stars per cloud.

---

## 11/07/2026 — v0.9: RCS wing turbines, painterly nebulas, salvage debris, parallax

- **Wing turbines, realistic**: yaw thrusters now sit at the wings'
  trailing edges and fire OUTWARD on the physically-correct side (left
  wing fires to yaw right) — nozzle stub, flickering cyan cone, white
  core, soft glow.
- **Nebulas, painterly**: 16 elongated hue-drifting wisps per cloud at
  random angles, dark dust lanes threading through, a glowing heart,
  and stars tinted by the cloud around them. Landmarks worth flying to.
- **Space trash / salvage**: derelict debris (hull shards, dead solar
  panels, cargo rings, bent struts) spawns deterministically (~30% per
  chunk, none at home), slowly tumbling, glinting in its metal's color.
  Fly over it to salvage: scrap-composition metals (Al/Fe/Ti/Ni/Cu, rare
  Ag, 1% Au) — human-made junk, so NOT solar ratios, deliberately.
  Float-text feedback; counts toward discovery. Session-persistent
  (respawns on scene reload — cheap finds, fine for now).
- **Parallax starfield**: three depth layers in flight AND spacewalk
  scenes — far stars crawl, near stars sweep, near layer gets glint
  crosses. Cheap, convincing 3D depth (star pos + cam * (1 - depth)).

---

## 11/07/2026 — Room building: EMPTY rooms only (clarified design)

What the user actually wanted: build **plain empty rooms** (20 ore) —
ship expansion without purpose yet. Stand at a bay's holo pedestal, a
hologram preview of the room glows over the cell (red-tinted if you
can't afford it), **E constructs**. Built rooms render as fresh space:
unopened crates and a work lamp. Persisted in saves.
The specialized-room engine (greenhouse/refinery/gascollector/workshop
with effects, ROOM_TYPES data, build_room) stays fully prepared but
UNOFFERED — "just prepare the engine for later."

---

## 11/07/2026 — UI kit v4: white-silver "holo-glass" (more white, more energy)

Palette pushed bright: **white-silver rims** (near-white steel gradients),
brighter holo-glass interiors, vivid glossy blues, ice-cyan hairlines at
higher alpha, pure-white text. Energy pass: header underlines and ring-
gauge cores now **white-hot**, meter cells brighter with a white glow on
the head cell, title wordmark glow intensified, white accent rules.
All tuning lives in gen_ui_kit palette consts + UITheme consts.

---

## 11/07/2026 — Buildable rooms deferred + UI kit v3 (rounded, lighter, glossy)

- **Buildable rooms shelved** (user call: "we'll come to that later").
  Interior is a 3x2 grid of the six prefixed rooms; no empty bays.
  The whole build system (`build_room`, ROOM_TYPES buildables, effects,
  hologram menu code) stays dormant and tested — one DEFAULT_ROOMS edit
  re-enables it. Saves ignore stored rooms until then.
- **UI kit v3**: textures re-rendered with **true rounded corners**
  (signed-distance-function rendering with anti-aliased edges) — no more
  hard rectangles anywhere. **Lighter palette** (brighter navy interiors,
  lighter steel rims, punchier blues), stronger gloss bands on buttons,
  brighter hairlines. Theme constants lifted to match; scanlines and
  vignette softened for the lighter look.

---

## 11/07/2026 — v0.8: modular ship (buildable rooms) + big-card inventory

**The ship is a base now.**
- Interior rebuilt as a **4x2 room grid** (`GameState.rooms`, saved).
  Six prefixed rooms + **two EMPTY BAYS** (hazard-taped, holo pedestal).
  Stand at a bay → hologram build menu → press **1-4** to construct:
  - **Greenhouse** (30 ore) — +25 max O2
  - **Refinery** (35 ore) — +50% refined element units on banking
  - **Gas Collector** (30 ore) — 2x nebula scoop rate
  - **Workshop** (35 ore) — +15 laser power
  Each has its own animated furniture (swaying plants, glowing smelter,
  filling gas tanks, sparking bench). Effects verified by test; rooms
  persist in saves. Stations/furniture are all data-driven per cell —
  future room types are one dict entry + one furniture func.
- **Inventory v3**: one big framed screen with a winged INVENTORY
  headline. Elements as **large cards** — symbol + full name + count +
  capacity bar + category strip + on-suit badge — 6 columns,
  **mouse-wheel scrollable** with a scrollbar, hover detail footer.
  EXOSUIT column: character, gear rows, discovery ring gauge.

---

## 11/07/2026 — Integer inventory (0/9999) — goodbye scientific notation

Playtest feedback: fractional amounts ("133m units") were too abstract.
Element amounts are now **plain integers with a 9999 cap**:
- Banking a chunk gives its ore-value in units of its vein element
  (rock +1, crystal +2). No more fractional general-composition traces.
- Nebula scooping ticks **+1 gas every 2.2 s**, the gas sampled at real
  solar ratios (92% of ticks are H — the table lives in the roll).
- The realism guarantee is unchanged: what you FIND follows the solar
  abundances exactly; what you HOLD is now readable ("stored 42 / 9999").
- Save v3; legacy fractional saves floor to integers (traces vanish).

---

## 11/07/2026 — Discovery vs. trace (player-confusion fixes)

Playtest feedback: "why 83/83 collected?" and "I pick Oxygen but don't see
it in elements." Two causes, two fixes:
- Banking adds a microscopic trace of ALL rock elements (real chemistry) —
  which made "collected" hit 83/83 instantly. Now the counter tracks
  **DISCOVERED**: an element counts only when you bank a **vein** of it
  (or scoop it as nebula gas). Traces still accumulate but show dim; the
  hover footer says "DISCOVERED" / "trace only — find its vein" / "not
  yet found". Saves store the discovered list (legacy saves derive it).
- Carried chunks only refine on banking, which was invisible. Element
  slots now show a warm **"+n" badge** for vein chunks on the suit, and
  the header says "DOCK TO REFINE".

---

## 11/07/2026 — v0.7: element veins, thin-modern UI, suit controls settled

- **Element veins — the mind-blower.** Every asteroid rolls a **dominant
  element at real solar abundance** (crystal rocks roll from the
  heavy-enriched table): its ore flecks glow in that element's unique
  color (golden-angle hue by atomic number), the **vein name appears
  while your laser bites** ("Fe — Iron"), laser sparks match the color,
  dropped chunks are tinted, and collecting pops floating **"+1 Silicon"**
  text. Banked chunks refine 55% into the vein + 45% general composition —
  veins are rolled at real abundance, so expected element totals still
  follow the solar table. Finding a **gold vein** is a real cosmic
  lottery win. (No rare loop — rarity is the roll itself.)
- **Suit controls settled (v4, final)**: direct WASD thrust + mouse-facing
  + **SPACE = stabilizer brake** (kills drift — the drift was the "weird").
  Stabilizer puff jets fire all around the suit while braking.
- **UI de-fattened**: kit textures regenerated slim (2px steel edges,
  hairline cyan, translucent interiors, corner accent tabs instead of
  riveted plates); thinner meters and ring gauges.
- **Inventory upgrades**: element symbols in their own hue colors; **hover
  any slot** for a detail footer (name, Z, category, stored units, real
  solar abundance in scientific notation); **Esc closes the inventory**
  without opening the pause menu.

---

## 11/07/2026 — v0.6: "Nemesis" UI kit (metallic frames, ring gauges, glossy buttons)

Full UI kit in the style of the user's reference (Space War Nemesis):
- **Texture generator** `tools/gen_ui_kit.gd` → `assets/ui/`: 9-slice
  metallic frame with riveted corner plates + cyan inner glow, thin steel
  sub-panel, glossy blue button (normal/hover/pressed — hover gets a cyan
  rim), inset meter trough. All gradients/bevels baked, deterministic.
- **Runtime glow components** in `ui_theme.gd`: **segmented cell meters**
  (lit cells + glowing head cell), **ring gauges** (glow arc + hot core +
  head dot + %), **headline plates** with metal side-wings, key chips.
  Theme uses StyleBoxTexture 9-slices for Buttons/PanelContainer.
- Applied game-wide: vitals panel now has an **O2 ring gauge** + segmented
  meters; gear tiles, exosuit rows, inventory panels, title/menu buttons
  all steel-framed; elements panel gets a **collection % ring**.
- **Showcase scene** `scenes/ui_kit_demo.tscn` — the whole kit on one
  sheet (framed list w/ headline, meters, gauges, live buttons, chips),
  like the reference sheet. Run directly to eyeball any component.

---

## 11/07/2026 — Suit controls v3: mouse-flight (+ wing-jet fix, interior pass)

- **Suit controls, third iteration** (tank → twin-stick → **mouse-flight**,
  user picked the proposal): the cursor is the joystick. **W thrusts
  toward the cursor, S retro-burns away, A/D strafe sideways** relative
  to facing — point at a rock, W to approach, S to brake, A/D to orbit
  while mining. Body still faces the mouse; flame opposes actual thrust.
  **The ship keeps tank controls** (W/S thrust, A/D turn).
- **Wing turn-jets** were drawing forward of the wing line after the hull
  flip — moved aft to the actual wingtips (-26, ±66).
- **Interior detail pass**: double-plated hull, deck-plate floor grids,
  lit doorway gaps facing the corridor with cyan doorframe markers,
  corridor ceiling lights with pulsing pools, ambient room light pools,
  Quarters (blanket, locker, sun poster), Bridge (live green/red console
  LEDs, framed star window), Engine Room (hazard-striped reactor ring,
  twitchy wall gauge), Cargo Hold (dashed LOADING ZONE markings),
  Airlock (animated approach chevrons, hatch wheel hub).

---

## 11/07/2026 — Ship flipped + tank controls + save deletion (captain's feedback)

- **Ship orientation corrected**: the tapered spine is the BOW, the broad
  twin-tower end is the STERN (processor now rotates CCW). Turbine logic
  redone: **twin main drives** flame from the stern towers on W, **bow
  retro jets** fire on S, and the **wingtip turbine on the pushing side**
  glows during A/D yaw.
- **New movement model — both vehicles**: W thrust forward, S retro,
  **A/D turn** (ship 2.6 rad/s, suit 3.4 rad/s). Zero-g drift preserved.
  The astronaut's body faces where you steer; the **laser pistol still
  tracks the mouse independently** — you can strafe a rock while mining it.
  Suit gets side-puff jets when turning, layered two-tone flames.
- **Save deletion** on the title screen: ✕ next to each occupied slot,
  two-step confirm (✕ → "SURE?" in red → deleted). `GameState.delete_save()`.

---

## 11/07/2026 — v0.5: UI redesign — "holographic cockpit"

Full visual pass on every UI surface. New design language in
`ui_theme.gd` (everything draws through it — restyle there only):
cut-corner translucent panels with **corner brackets**, skewed
parallelogram buttons with warm hover, teal-info/orange-action accents.

- **Vitals panel** (`vitals_panel.gd`): custom-drawn O2 + LINE meters with
  quarter ticks, glowing fill head, numeric readouts, ore counters, and a
  pulsing red **O2 LOW** warning below 25%.
- **Screen FX** (`screen_fx.gd`): faint scanlines + corner vignette on all
  in-game HUDs — cockpit glass feel, zero per-frame cost.
- **Gear rack**: cut-corner tiles, level pips under each tool, warm flash
  animation on upgrade.
- **Title screen**: layered glow title, twinkling stars, drifting nebula
  haze, the ship gliding through the backdrop, styled slot buttons.
- **Inventory**: sci-panels + brackets, glowing header underlines,
  category accent strip on owned element slots.
- Pause menu: "◈ SYSTEMS PAUSED" header; flight/interior info wrapped in
  themed panels; prompts pulse.
- Verified by screenshot: title, exterior HUD, inventory overlay.

---

## 11/07/2026 — The captain's ship: painted hull art

Replaced the generated pixel capsule with the user's painted ship art
(`tools/ship_source.png`, 1536×1024). New one-shot processor
`tools/process_ship_art.gd`: border flood-fill kills the white background
without touching white hull panels (1.19M px cleared), trims margins
(937×942 content), rotates bow-right, Lanczos-downscales to 300×298
(drawn at 0.5 = ~150 world px, linear filtering — it's painted, not pixel).

**Turbine layout reasoned from the art:** blue dome = cockpit (forward),
long tapered spine = stern with twin cyan exhausts at the tip → main drive
flame there in flight mode; wingtip pods = maneuvering turbines → small
cyan glows when thrusting. Docked scene: tether anchor moved below the new
hull (0,82), beacon on the bow tower, collision capsule enlarged to fit.

---

## 11/07/2026 — v0.4: the real periodic table, NMS-style inventory + exosuit screen, UI theme

**Resources are now the actual universe.**

- **All 83 long-lived elements farmable** (`scripts/elements.gd`) at their
  REAL present-day solar atom-percentages (user-supplied table, IUPAC names).
  Rarity is physics — do NOT rebalance the numbers. No rare-element loop:
  - Banked **rock chunks** refine into the *condensed* elements (gases can't
    be in rock), renormalized — O dominates (oxides), then Si/Mg/Fe. Gold
    arrives in micro-units, uranium in nano-units. Ratios = solar ratios.
  - **Crystal chunks** concentrate heavy elements (Z ≥ 39) tenfold — ratios
    *among* the heavies stay true.
  - **Gases (H, He, N, Ne, Ar, Kr, Xe)** only come from **nebula scooping** —
    fly inside a nebula and the ship collects at real gas ratios (H/He 12.2:1).
    All 83 obtainable, none cheapened.
  - Amounts use engineering notation (2.54µ, 90.0n) via `Elements.fmt()`.
- **Full-screen inventory (I / Tab)** — `scripts/inventory_screen.gd`,
  No Man's Sky flavoured: **EXOSUIT** panel (big pixel astronaut + every gear
  piece with stats and LV badges) and **ELEMENTS** panel (12-column grid of
  all 83 slots, category colours — gas/alkali/precious/rare-earth/actinide…,
  live amounts, X/83 collected counter, legend). Replaces the small manifest.
- **UI theme pass** (`scripts/ui_theme.gd`) — one place for the whole look:
  translucent rounded panels, thin accent borders, warm-orange interactables.
  Applied to HUD vitals panel + bars, title screen, pause menu, overlay.
- Ore-value stays the currency; elements are the collection/crafting layer.
- Verified: composition ratios (Fe/Au, H/He) match the table; save/load v2
  round-trips elements; all scenes clean; overlay verified by screenshot.
  Dev hook: `SW_SHOW_INV=1` opens the overlay at boot for screenshots.

**Design note (engagement direction):** elements are the collection hook;
next: workbench recipes with abundance-proportional costs (bulk Fe/Si vs
trace Au), a contracts board ("deliver 3 units Ti"), and named characters.

---

## 11/07/2026 — v0.3: pixel sprites + a structured map (regions, nebulae, The Belt)

**Graphics step up, and space gets a plan.**

- **Pixel-art sprites** replace the core placeholder shapes: astronaut
  (rotates whole-body toward aim, zero-g style), ship hull (shared by dock
  and flight), iron/crystal ore chunks. Authored in
  `tools/gen_sprites.gd` — ASCII art + shape code, regenerate with
  `godot --headless -s res://tools/gen_sprites.gd`. One palette, one file,
  whole art style tweakable and deterministic. Nearest-neighbor filtering
  project-wide. Asteroids stay procedural polygons (they work).
- **The map plan** (`GameState.region_at()`) — concentric regions with
  distinct character, shared by flight AND dive scenes:
  - **Home Reach** (<30 km): sparse, small practice rock.
  - **The Drift** (30–60 km): baseline.
  - **The Belt** (60–90 km): dense ring — field chance 85%, bigger rocks,
    earth-tinted. A visible band you navigate by.
  - **The Expanse** (90 km+): deliberately VAST — 8% field chance, but
    fields are huge (×1.7) and rich. Emptiness makes finds matter.
  - **4 named nebulae** (Rosefield, Cerulean Shallows, Ember Reach,
    Viridian Veil) at fixed landmark positions — colored dust clouds
    visible from afar, crystal-rich (+18%), tinted rocks.
- **Region name on the flight HUD** ("ROSEFIELD NEBULA · Sector …") and in
  the parked-dive welcome. Dive fields inherit the region: count, rock
  size, palette tint, nebula haze backdrop.
- Verified visually: home dive (new sprites), Rosefield nebula flight
  (magenta dust + tinted rocks), Belt dive (dense crystal-flecked quarry).

**Design note:** diversity is planned, not random — the region table is
hand-authored; only placement-within-plan is procedural. Landmark ideas for
later: derelict stations in The Expanse, region-specific hazards.

---

## 11/07/2026 — v0.2: title screen, save slots, pause menu, longer O2, faint-to-bunk, inventory, bungee tether

**It's not an arcade run anymore — it's a persistent game.**

- **Title screen** (`scenes/title.tscn`) — pick one of **3 save slots**; empty
  slots start a new game, used ones show banked ore + save date and resume
  inside the ship. Now the project's main scene. R-restart removed.
- **Pause menu** (`scripts/menu.gd`, autoload `GameMenu`) — **Esc** pauses the
  tree: Resume / Save game / Save & quit to title. Inactive on the title screen.
- **Save system** in `GameState` — JSON per slot in `user://saves/`
  (gear, levels, oxygen, banked ore, inventory, sector, date). **Auto-saves**
  at safe moments: banking at the dock, entering the ship, parking in flight.
- **Oxygen**: drain 4.0 → **1.5/s** (~67 s base tank, upgrades stretch it);
  the bar now has a **number readout** ("87 / 100"). Hitting zero no longer
  bounces you back — **you faint and wake up in your bunk** in Quarters,
  carried ore gone, with a proper message.
- **Resource types + inventory**: common asteroids drop **Iron ore** (value 1),
  rich cyan ones drop **Crystals** (value 2). **I** toggles the
  **Cargo Manifest** — held / stored per type + banked ore value. Banked ore
  value stays the single upgrade currency.
- **Bungee tether** (user feedback): the lifeline limit is no longer a wall.
  Past rated length there's a ~90 px elastic zone — outward speed bleeds off
  progressively and a pull-back force ramps up until thrusters can't win.
  The rope visibly strains: gold → hot red-orange and thinner as it stretches.
- Verified: headless clean ×4 scenes; save/load round-trip test green; visual
  screenshots of title (slot dates in DD/MM/YYYY), O2 numbers, cargo manifest,
  save-resume into interior; pause menu logic tested headless.

**Design notes:** saves are single-file JSON per slot — fine until mid-run
saves matter (currently the asteroid field regenerates per dive anyway).
Inventory counts are lifetime-gathered; spending ore doesn't reduce them.

---

## 11/07/2026 — Cockpit + flight mode: pilot the ship through infinite space

**Exploration is in — the third pillar of the loop (dive / manage / explore).**

- **Helm station** at the Bridge's pilot chair (`ship_interior.gd`) — press E
  to take the helm.
- **Flight scene** (`scenes/flight.tscn` + `scripts/flight.gd`) — external
  view of the ship; WASD to fly (faster, heavier feel than the suit; ship
  noses toward its velocity). **Infinite space** via deterministic chunks:
  the same coordinates always hold the same starfield and asteroid fields,
  with zero persistence cost — everything regenerates from chunk seeds.
- **Asteroid fields** scatter through space (~55% per 1.6k-px chunk) and get
  **richer with distance from home**: rich-asteroid chance 18% at home,
  capped at 55% far out. Fly near one → "E — Park & spacewalk this field
  (~N% rich)".
- **Parking** sets `GameState.sector`; the dive scene (`main.gd`) now seeds
  its field from it — richer *and denser* (up to +12 asteroids) in remote
  sectors. Dock ring at home (E) returns sector to zero. Q leaves the helm
  back into the interior, holding position.
- **Home compass** — arrow + distance pointing home whenever you're away.
- Validated: headless clean on all scenes; visually verified (screenshots)
  at home, in deep space, and parked at a field with the rich-% prompt.

**Design notes:** flying costs nothing yet (no fuel, no hazards) — deliberate
until exploration feels good. Fields are visual clusters in flight mode; the
actual minable field spawns when you park. Bash mangles `res://` args on
Windows (MSYS path conversion) — launch scenes via PowerShell.

---

## 11/07/2026 — Fix: gear rack was off-screen; moved to bottom-right

The gear panel anchored with `PRESET_MODE_MINSIZE`, which reads the control's
class minimum size — a plain `Control` reports zero, so the panel collapsed
and its tiles drew past the right screen edge. Fixed by overriding
`_get_minimum_size()` in `gear_panel.gd`. Moved the rack from top-right to
**bottom-right** (both scenes) — reads better and matches expectation.
Verified with a live screenshot of the running game.

**Lesson recorded:** headless validation never executes `_draw()`/UI layout —
visual placement needs a real run + screenshot.

---

## 11/07/2026 — Ship interior, upgrade shop, gear icons

**The "restaurant half" of the loop is in.**

- **Ship interior scene** (`scenes/ship_interior.tscn` + `scripts/ship_interior.gd`) —
  dock and press **E** to step inside. Walk (WASD) between six rooms:
  Quarters, Upgrade Bay, Bridge, Engine Room, Cargo Hold, Airlock.
  - **Upgrade Bay**: three consoles — spend banked ore on O2 tank, lifeline
    length, or laser power. Costs scale per level (`base × (level+1)`).
  - **Cargo Hold**: crate stack grows with banked ore.
  - **Airlock**: E to suit up and spacewalk again.
  - Bridge/Quarters/Engine Room are flavour rooms for now (window with stars,
    bunk, pulsing reactor).
- **Interior crew avatar** (`scripts/interior_player.gd`) — top-down walker,
  helmet off, simple bounds clamp (no physics indoors).
- **Gear rack HUD** (`scripts/gear_panel.gd`) — four icon tiles top-right
  (suit / lifeline / O2 / laser) showing live stats; visible both outside
  and inside.
- **Upgrade system in GameState** — `laser_dps` moved from player const into
  `GameState`; new `upgrade_cost()` / `try_upgrade()` and `gear_changed` signal.
  Banked ore is the currency. Levels: `o2_level` / `tether_level` / `laser_level`.
- Exterior HUD now shows an "E — Enter ship" prompt while docked.
- Validated headless (import + 300 frames per scene, zero errors) and the
  upgrade economy functionally tested (costs scale, poor = rejected).

**Design note:** entering/leaving the ship reloads the exterior scene, so the
asteroid field regenerates each spacewalk. Fresh layout per dive — intentional
for now; revisit if persistence feels better.

---

## 11/07/2026 (earlier) — Initial prototype

**Working title "Lifeline", renamed to Spacewalker on request.**
Godot 4.7 standard (GDScript). "Dave the Diver, but in space."

- Zero-g WASD thruster movement with drift damping, mouse aim.
- **Lifeline (tether)** — sags when slack, hard clamp at 600 px with elastic
  tug; faint ring in the world shows max reach.
- **Oxygen** — drains on spacewalks, refills in dock; zero O2 = blackout,
  reeled home, carried ore lost (banked ore safe).
- **Laser pistol** — hold LMB, raycast beam, asteroids flash and shatter into
  ore chunks that magnet to the player.
- **Ship + dock ring** — entering banks carried ore and refills O2.
- 22 procedurally placed asteroids; ~18% are rich (cyan, double ore); some sit
  beyond tether range on purpose (upgrade bait).
- HUD: O2 bar, LINE bar, Ore/Banked counters, fading messages; R restarts.
- All visuals are placeholder `_draw()` shapes resembling the real thing —
  sprite swap later without touching logic.
- `GameState` autoload holds oxygen/cargo/gear stats — future upgrade home.
- Validated against headless Godot 4.7: clean import, 300 frames no errors,
  smoke-tested shatter → pickups, banking, blackout, tether clamp.

---

## Backlog (not yet built)

- Cargo magnet upgrade (radius/pull of ore attraction)
- Suit tiers (the SUIT gear tile is cosmetic `MK I` for now)
- Hazards: drifting debris, solar flares, tether snag
- Persistent asteroid field across dives (currently regenerates)
- Real pixel-art sprites + synth SFX
- GodotSteam (achievements, cloud saves) once there's a Steam App ID
- Steam name check: "Spacewalker" collision — decide before buying the App ID
