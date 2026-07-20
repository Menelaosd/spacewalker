# Spacewalker — Dev Log

Core updates to the game, newest first. Every meaningful change lands here.
(Format: date · what changed · why it matters.)

---

## 20/07/2026 — v1.90: grid board, floating cards, animated STRIKE button (breach only)

Duel-board polish from live captain feedback:

- **Fixed transparent-sort glitch.** Slot planes were blending over the cards. Cards now use
  alpha-scissor (`ALPHA_CUT_DISCARD` on every sprite + Label3D → depth-writing); slot pads are
  opaque. Nothing draws over a card anymore. Ghost/queue cards dim by RGB, never alpha.
- **Real grid board.** New PixelLab `duel/slot_cell.png` (thin-bezel glowing card-bay) tiled
  5×3 edge-to-edge (rows evened to 1.7 pitch, `CELL_W/CELL_H`) — reads as a proper socket grid.
- **Floating cards + shadows.** Every card (yours AND HELIOS's) hovers `FLOAT_Y` above the slab
  and casts a strong radial drop-shadow (per-unit mesh, fades on death), plus a discreet idle
  up/down bob (paused while a card is tweening).
- **Animated STRIKE button.** New PixelLab red-arcade-dome button with a 6-frame press
  animation (`animate-with-text-v3`) — plays the frames + a physical sink/elastic rebound +
  flash on click. Replaces the old bell sprite.

Card roster is still the Act-3-curve PLACEHOLDER; real card designs pending captain's pick.

## 21/07/2026 — v1.94: v2 node icons + thin path line + colored node lights (breach only)

Captain feedback on the dark map: disliked the flat mono icons, path line too fat, stage too
monochromatic.
- **v2 node icons** regenerated (`hd/icon_*.png`): detailed dark engraved-metal casings, each
  with its own accent glow (cyan access/vault, orange firewall, red sentinel, teal pod, amber
  cache, violet ghost, red-orange core) but one cohesive family — not flat monochrome.
- **Path line thinned** in `breach_map3d.gd` (0.16 → 0.07 wide).
- **Colored node lights:** `TYPE_COLOR` per node type now drives each token's OmniLight, so the
  corridor has pools of amber/teal/violet/red instead of one flat blue — kills the monochromatic
  feel and lets the complex cube machinery read under the coloured light.

## 21/07/2026 — v1.93: dark corridor-lit map + complex cubes + mono icons (breach only)

Captain art direction on the cube map: "so dark it hides the map edges, corridor illuminated by
lights, more complex cube art, icons monochromatic + one style."
- **Lighting rebuilt for darkness:** removed the global/directional key light and the warm rim;
  ambient dropped to ~0.08 + thick black fog. Only per-path-cell blue OmniLights + the emissive
  blue path-line illuminate the corridor, so the cube field falls to black at the edges.
- **Complex cube art:** regenerated `map3d/cube_top.png` + `cube_side.png` as dense detailed
  machinery (greebles, pipes, panels) instead of plain plating; distinct `path_floor.png`.
- **Monochromatic icon set:** regenerated all 8 `hd/icon_*.png` in a single steel-cyan hue,
  uniform engraved style — one cohesive family, no per-node colors.

## 21/07/2026 — v1.92: real card roster + sigil engine start + cube-field map (breach only)

- **Full reskinned Act 3 roster is IN** (`breach_duel3d.gd`). Replaced the placeholder cards with
  the `docs/BREACH_CARDS.md` set: player intrusion units (Power Siphon, Buckler Mite, Lance Drone,
  Fork Turret, Grunt Bot, Sapper Worm, Watcher Seed, Hollow Shell side-deck…) + HELIOS firewall
  units (Barrier Node, Sentry ICE, Packet Daemon, Raptor Proc, Heap Giant, Spike Wall, Firewall
  Slab…) + boss cards (Freeze-Frame, Index Warden, Kernel Ghost, Ursa/Vespa/Quill daemons). Real
  Act 3 stats. **11-card starter deck**, T1/T2/T3 firewall pools. Sigil field is now an Array.
- **Sigil engine started** — working: `overcharge` (Battery Bearer), `ablative_plating` (Nano
  Armor), `spike_casing` (struck attacker takes 1), `provoke` (card opposite strikes +1). Others
  stored + labelled, effects land in later passes. Headless test rewritten to new ids: **27 PASS**.
- **35 card portraits generated** (PixelLab) into `duel/` — cyan intrusion bots vs red/amber
  firewall units.
- **Duel-through-map bug fixed** — the 3D map geometry was rendering behind the duel; the map
  world + HUD now hide while a duel is on screen and restore after.
- **Map redesigned to a cube field** — whole area is solid raised blocks; the walkable path is
  carved in as a recessed channel with a **glowing blue line** down the middle (per captain).
  New materials: cube top / cube side / recessed path floor; cool-blue ambient + warm core-end
  rim + fog. New textures + a moodier consistent icon set generating (agent) to swap in.

## 21/07/2026 — v1.91: 3D corridor map + duel polish + card bible (breach only)

- **THE MAP is now 3D** (`scripts/breach_map3d.gd`, new `Node3D` scene) — same angled
  perspective as the duel. Nodes are round tokens (icon on a `token_base` disc) with
  drop-shadows; grid-square corridors (Manhattan bends) link them over the void; the astronaut
  marker walks the corridors node-to-node up to the HELIOS core. Battle nodes open the duel;
  camera follows the marker. New art: `map3d/floor_top.png`, `floor_wall.png`, `token_base.png`.
  Replaces the 2D chart; `flight.gd` + `breach.tscn` repointed to `breach_map3d.gd`.
- **Duel:** grid tile swapped to the chosen machined-titanium plate (batch-2 #03, picked from
  20 in-engine candidates); floating-card drop-shadow strengthened + a docked "card plate" now
  sits under each floating card so it reads as lifting off.
- **CARD BIBLE written** → `docs/BREACH_CARDS.md`. A researched, cross-checked reskin of ALL
  Inscryption Act 3 cards (player intrusion + enemy firewall + boss/Uberbot cards) keeping real
  Act 3 stats/sigils: full CARDS table, 11-card starter deck, T1/T2/T3 + 4 boss decks, every
  sigil with rule + difficulty, and the 12-station (4 zones × 3, 3 duels→boss) collect-as-you-go
  progression. This is the blueprint for the card build. Deck-builder is deliberately LATER.

### v1.90c follow-up (same day)
- **Grid tile restored** to the bright cyan L-corner-bracket design the captain liked (the
  de-glow/muted attempts were rejected). Regenerated from the original prompt (exact file was
  overwritten); `slot_cell.png`. Nothing else changed — thick slab, button, cards all kept.

### v1.90b follow-up (same day)
- **Restored the loved tile.** Reverted the bolted-panel misstep — `slot_cell.png` is the
  corner-bracket design again, just muted (dim steel-cyan brackets, no neon glow).
- **Thick platform back & prominent.** Slabs are now 1.4 tall (was 0.55), reach forward past
  the front row so the thick lip faces the camera; hall floor dropped to y=-1.55; camera tilted
  to show the raised platform + side pedestal.
- **Button remade complete.** Octagonal armored sci-fi console module with a cyan-lit core and
  large margin so it never crops (`strike_btn.png`; `strike_btn_alt.png` = hazard-slam spare).

### v1.90a follow-up (same day)
- **Redesigned grid tile.** Generated 3 fresh candidates, kept/refined the flat one:
  `duel/slot_cell.png` is now a dark plate with clean cyan L-corner brackets (not the old
  chunky frame). Reads as a proper grid.
- **No card clipping.** Cards shrunk (`CARD_W 1.7→1.5`) and rows spread (`ROW_Z` 2.35 pitch,
  `CELL_H 2.3`), camera pulled back — floating cards no longer overlap the neighbouring row.
- **Button redone.** Dropped the cropped PixelLab frame-swap; new clean padded
  `duel/strike_btn.png` + a code-driven squash / hard-sink / elastic-rebound / flash press.

---

## 20/07/2026 — v1.89: proper path-map + floating duel cards (breach only)

Captain rejected v1.88's map ("terrible", "repeated texture", "stupid spread graphics") and
flagged the duel's slot overlays drawing over cards. Fixes:

- **Real map paths.** New PixelLab graphic `hd/path_seg.png` (glowing cyan conduit) is tiled
  along every node link — solid trail, not dotted ink: dim locked, bright pulsing on the live
  branch, cyan on walked edges. New `hd/node_pad.png` / `node_pad_boss.png` socket platforms
  sit under every node icon. This is the "proper map" — a lit conduit trail from ACCESS PORT
  up to the core.
- **Removed the clutter.** Deleted the scattered props and shadow-blotch systems entirely
  (`_scatter_props`/`_scatter_blotches` gone). Background is now a calm, darkened tile with a
  vignette on the flanks so the central path column is the focus.
- **Floating duel cards.** Cards now hover `FLOAT_Y` above the slab and cast a soft radial
  drop-shadow onto it (per-unit shadow mesh, dimmer for queued cards, fades out on death) —
  the slot pads sit below, so nothing draws over a card anymore.

---

## 20/07/2026 — v1.88: thick 3D platform + map de-wallpapering + cost badges (breach only)

Captain's polish round on v1.87:

- **Cost badges.** The duel's energy costs were tiny pips — now an unmissable top-left badge
  on every hand card (battery icon + big number, cyan = payable, red = not this turn), a
  bigger energy cell bank with "+1 max each turn, refills full" hint, and selecting a card
  burns the cells it will drain amber.
- **Thick dueling platform.** The board is a real armored slab (BoxMesh body + top plane)
  with new PixelLab textures: `duel/platform_top.png` (gunmetal panels, cyan trim) and
  `duel/platform_side.png` (plated side wall with a glowing light strip). Bell + draw piles
  sit on a matching side pedestal; the hall floor is sunk 0.55 under the platforms.
- **Map repetition killed.** The chart tile no longer reads as wallpaper: every cell draws
  with a deterministic 0/90/180/270 rotation, random mirror, and ±22% brightness from its
  map coordinates (one tile = 16 looks), tiles render 1.3x bigger, prop count up to 20-29,
  and 7 soft shadow pools + 4 faint amber/cyan glows break the macro pattern.

---

## 20/07/2026 — Breach map art library (assets only, PixelLab bulk pass)

Generated the pixel-art library for randomized Inscryption-style breach maps —
no code changes, assets only.

- **12 themed floor tiles** (`assets/sprites/breach/themes/`, 256×256, one per
  rescue-station id): seamless-ish tileable, deliberately near-black so glowing
  map icons render on top. 7 re-rolled once with a stronger "flat overhead,
  edge-to-edge, no walls" prompt after first pass returned isometric scenes.
- **24 scatter props** (`assets/sprites/breach/props/`, 64×64 base; drone wreck /
  skeleton / fountain 80×80, server rack 64×96): vents, pipes, crates, barrels,
  terminals, skeleton, candles, vines, ice, gold ornament, etc. — dark palette,
  cyan/amber glow accents, transparent background.
- Known weak spots to maybe re-touch later: halcyon (faint ring motif),
  verdant_halo (vine strips hug the edges), verdant_bloom / vespers / glacier
  (subtle frame rim); prop_bed and prop_gold are upright, not toppled.

## 20/07/2026 — v1.87: THE DUEL in 3D + Act-3 energy system + HD art (breach only)

Same-day hot redesign of v1.86, driven by captain feedback ("not smoothly playable",
"no indicator of the cards required", "3D duel", "Act 3 cards", "badass graphics").
Built with 7 parallel agents (2 researchers, 3 PixelLab passes, UX audit, autoplay QA).

- **THE DUEL is now a real 3D table** (`scripts/breach_duel3d.gd`, code-built Node3D):
  angled camera, moody cyan/amber omni-lights, deck-plated table, machine-hall backdrop
  with a distant red eye. Cards are physical layered stacks (HD frame + portrait sprites,
  Label3D stats) that drop in, glide out of the queue, lunge on attack, flash on damage,
  and collapse on death (tweens). 2D HUD overlay: hand fan, energy bank, trace-scale,
  toasts, phase chip. Input: ray-picked board + screen-space hand. Chart stays 2D.
- **Act 3 (Botopia) combat, researched & exact:** 5 lanes; ENERGY replaces blood/bones —
  max starts 1, +1 per turn to cap 6, full refill (verified: turn 1 = 1/1); Empty-Vessel
  analog (scrap mite) costs 1⚡ and is 0/2, side pile of 10; mandatory draw, turn 1 skips;
  queue advances BEFORE HELIOS strikes; overkill spills into the queued unit, never the
  scale; scale tips at ±5. Two Act 3 sigils in: BATTERY BEARER (+1 max & current, resolves
  before cost) and NANO ARMOR (negates first damage). PLACEHOLDER deck on Act 3's real
  cost curve — card designs still to come (captain's call).
- **UX pass (audit + autoplay QA):** cost pips top-left (never occluded), hand no longer
  overlaps, energy cell bank + ENERGY n/n, unaffordable cards dim with red deficit pips,
  playable cards pulse, placement lanes glow, row labels, dead-click deny + pile flash,
  phase chip (DRAW amber / PLAY cyan / HELIOS red), attacker cursors both sides, floating
  damage numbers, scale needle tween + center-fill, OVER-screen click lockout, hover
  lift/pointer cursor. Autoplay QA confirmed 59/59 clicks land and both outcomes complete.
- **HD "badass" art pass** (`assets/sprites/breach/hd/`, PixelLab, highly-detailed):
  128px chart icons + 192px monstrous HELIOS core, seamless dark map tile, ornate card
  frame/back, atmospheric duel backdrop. Chart loads hd/ first, falls back to scifi/.
- **Random maps groundwork:** breach picks `themes/<station_id>.png` tile per station and
  scatters 14–22 props (`props/prop_*.png`) between rows and in the margins per roll —
  12 themed tiles + 24 props generating in the background, code already integrated.
- **Fixed:** dict-keyed 3D node lookup broke on hp mutation (Godot hashes dict keys by
  content — now uid-keyed); headless test never actually ran (typed-var parse error +
  hang) — rewritten for the energy engine: **27/27 PASS** (`tools/test_duel.tscn`).
  Removed `scripts/breach_duel.gd` (2D duel superseded).

---

## 20/07/2026 — v1.86: THE BREACH — Inscryption-style intrusion chart (breach only)

The HELIOS breach got its keeper structure. The old demo (Slay-the-Spire columns + the disliked
Deus-Ex trace-race) is gone; in its place, a map that works exactly like **Inscryption Act 1**:

- **The chart.** A vertical hand-drawn paper map, taller than the screen, that scrolls as the
  pewter astronaut marker hops node to node (forward only, hop-arc animation, mouse-wheel peek).
- **Inscryption generation rules** (researched): rows are *category-typed* — repeating
  gain → utility → battle triads from the ACCESS PORT up to the HELIOS CORE boss on top. A row
  with 2-3 nodes offers different *variants of the same category* (cache vs vault, pod vs ghost,
  firewall vs sentinel) — the choice is which flavour, like Inscryption's card/event/battle rows.
  Dotted ink paths branch AND merge; every node is guaranteed reachable; cleared nodes get a
  red-ink X.
- **PixelLab art** (`assets/sprites/breach/`): seamless parchment tile, 8 hand-drawn-ink node
  icons (airlock, burning wall, skull drone, cryo pod, data crate, radio ghost, vault door, and
  a glaring mechanical-sun boss core), plus the astronaut game-piece marker.
- **Minigame slot.** Battle nodes open a parchment challenge card — `[ MINIGAME SLOT ]`,
  click-to-win placeholder. The future node-challenge drops into `_arrive()`/`_finish_node()`
  with no map changes. (Trace-race deleted with the demo files.)
- **Testing wiring:** approaching ANY of the 12 stations in flight now opens the breach
  (`_check_station_breach()` in flight.gd — arms in open space so returning from a breach
  doesn't insta-retrigger). ESC or freeing the core returns to the helm at the same spot.
  Nothing else touched — breach only.

New: `scenes/breach.tscn`, `scripts/breach.gd`. Removed: `scenes/demo_breach.tscn`,
`scripts/demo_breach.gd`. Verified via real-window screenshots: map, challenge card, and the
full flight→approach→breach handoff (SW_STATIONS=1 SW_THRUST=1; SW_BREACH_CH=1 for the card).

---

## 19/07/2026 — v1.85: atomic save (no more crash-wiped slots)

A full-game bug scan (per-file review + adversarial verify) flagged `save_game()` as a data-loss
risk: it opened the real slot file with `FileAccess.WRITE` (truncate-in-place), so the slot sat
empty/half-written for the whole serialize+write — and `save_game()` fires **every frame** while
cruising scrap (`_collect_trash`/`_collect_wrecks`). A crash or kill mid-write left a truncated
file that parsed as `{}` → the entire save read as lost.

- **Atomic write.** `save_game()` now serializes to `slot_N.json.tmp`, flushes/closes it, then
  `DirAccess.rename_absolute()`-swaps it over the real slot. The real file is only ever the
  previous complete save or the new complete save — never a partial one.
- **Recovery fallback.** `slot_data()` now reads the real slot first and falls back to the `.tmp`
  if the real file is missing/unreadable — covers a crash inside the tiny remove→rename window.
- **Verified headless on Windows:** `rename_absolute` overwrites an existing destination (err=0,
  content swapped, temp cleaned) and lone-`.tmp` recovery both PASS.

The other scan findings (audio/rock-art/comet/station art vanishing in a *packed export* build) are
real but **deferred to Steam-build day** — they only manifest in an exported `.pck`, and the game
has never been exported yet. Parked, not forgotten.

---

## 19/07/2026 — v1.84: bug-scan fixes (starchart crash, double-shatter, dead flash)

A whole-game GDScript bug scan (per-file review + adversarial verify) was cut short by an org
spend limit — only ~14 of 58 agents ran, so most of the big files are still unscanned (re-run
pending). Of the findings that landed before the cutoff, three were hand-verified as real and fixed:

- **`starchart.gd` per-frame crash.** The "YOU" heading chevron read `flight.heading` guarded
  only by `flight != null`. In Godot 4 a *freed* node isn't null, so a stale `flight` ref threw
  "previously freed instance" every frame the chart was open. Now guarded with
  `is_instance_valid(flight)` — matching `_ship_pos()` right above it, which already did this.
- **`asteroid.gd` double-shatter.** `take_damage()` called `_shatter()` on `health <= 0` with no
  already-dead guard. `queue_free()` is deferred, so a second hit the same frame (any multi-hit /
  AoE beam) would shatter twice → duplicate pickups, double SFX, double `GameState.mined` write.
  Added an early-out when already dead.
- **`fabricator_modal.gd` dead confirm-flash.** `_flash` was declared, zeroed, decayed and drawn,
  but never set positive — so the warm border pulse on a successful print never fired (its sibling
  `upgrade_modal.gd` sets `_flash = 1.0`). Restored the one missing assignment in `_confirm()`.

The `demo_breach.gd` softlock/false-win findings were ignored on purpose — that puzzle is being
dropped (rogue logic kept for later, per the breach decision).

---

## 19/07/2026 — v1.83: station ambience + idle float

- **Stations — REAL GPU lighting** (not opacity blobs). Each station is now a `Sprite2D` on
  its own light layer (`light_mask 2`), drawn a touch DARK (`self_modulate ~0.46`), then lit by
  **two coloured `PointLight2D`s (ADD blend, `range_item_cull_mask 2`)** from opposite sides —
  so parts of the hull sit in shadow and parts glow in colour. Colours vary per station (warm/
  cool palette). The lights **breathe** (energy pulse) and the whole node **floats + slowly
  rotates**, each on its own phase, updated in `_update_stations`. Name plates tint to match.
- **Ship idle float — only while SPACEWALKING** (not at the helm). In the EVA scene the ship
  (`ship.gd`) gently bobs/drifts around its spawn point — hull, dock zone and tether hardpoint
  move together so nothing mismatches. The cruise helm sits steady.
- **Spacewalk ONLY from a gathering zone — both paths.** (1) Helm E works only near an asteroid
  field. (2) The interior airlock hatch now checks `GameState.at_field` (flight keeps it fresh
  from `_near_field`) and only opens to EVA when the ship is parked at a field; otherwise it
  denies. No more spacewalking while cruising open space or sitting by a station.

---

## 18/07/2026 — v1.82: station navigation + camera/player-blur polish

- **Star chart:** the 12 stations now render as bright pulsing cyan diamond landmarks with
  labels (bumped up from tiny 5px ticks so they're findable at full-galaxy zoom). The "YOU"
  marker is now a chevron that **points along the ship's heading** (`flight.heading`) so you
  can see where you're pointed.
- **Flight radar:** stations show as cyan diamonds — a rim bearing when out of range (steer
  toward them) and a ringed blip when in range.
- **Stations now RENDER in the world** (the missing piece — before, only markers existed and
  flying to one showed empty space). `flight.gd::_draw_stations()` draws each at ~4× the ship
  with a name plate, culled to view. And per captain, all 12 are **clustered in a grid north of
  home** (`Stations.CLUSTER`) so you can fly up and inspect them side by side; `SW_STATIONS=1`
  parks you there. (Scattering them as individual breach targets is a later roadmap step.)
- **Player sprite blur:** downscaled the 80×121 walk frames to 90px tall (like the device/crew
  frames) so the character's helmet stays crisp when stopped.
- **Camera:** disabled `position_smoothing` on the interior Crew camera — it was trailing and
  easing to a stop, which read as dizzy/shaky once sprites pixel-snap; now it follows 1:1.

---

## 18/07/2026 — v1.81: fixed in-game animation blur (render, not frames) + stations on the map

**The blur was a RENDER-SCALE bug, not the frames** (proof: same frames are crisp in the
NEAREST test room but blurry minified in ship_interior). `ship_interior` drew with
`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`, and the device/crew frames were full-res (device up to
209px drawn ~52px; crew 152×268 drawn ~40px — a 4–6× minify) → the filter sampled a blurry
mip. Fixes:
- **Downscaled every animation frame to ~2× its display size** (203 device + 150 crew frames;
  originals backed up to `scratchpad/frame_backup/`) so they render ~1:1 instead of minifying.
- **Switched the filter to `NEAREST_WITH_MIPMAPS`** — crisp pixels (no linear smear) while
  keeping mipmaps for anti-shimmer on camera drift.
- **Light unsharp (0.5) on all 365 frames** to counter box-downscale softness.
This also fixes the crew idle/breathe blur, which was the same root cause.

**Floor-tile shimmer follow-up:** switching to NEAREST made the repeating floor tiles shimmer
on camera drift (they were smooth under the old LINEAR filter). Fix without touching any art:
a new `_deck` layer (`show_behind_parent`, `LINEAR_WITH_MIPMAPS_ANISOTROPIC`) now draws the
tiled floor + hull backdrop behind everything, so the floor keeps smooth mip-filtering while the
sprites/crew on self/_overlay stay crisp NEAREST. Pure filter-layering — no textures or layout
changed.

**Object shake-on-stop follow-up:** NEAREST + the camera's `position_smoothing` (player.tscn)
meant that as the camera eased to a stop at sub-pixel positions, sprites snapped between pixels
= a small jitter. Enabled `rendering/2d/snap/snap_2d_transforms_to_pixel=true` so sprites land
on whole pixels (camera stays smooth, jitter gone).

**Stations on the map:** new `scripts/stations.gd` — the 12 finals as a data ARRAY, each placed
as a giant landmark (≥4× ship, `SCALE_MULT 4.2`) just outside a themed nebula, resolved against
GameState's nebula layout. `starchart.gd` now draws all 12 as labelled cyan diamond markers and
extends the chart extent to fit them. Gameplay wiring (visit / breach) is still TODO — this makes
them real map landmarks so they aren't unused assets.

---

## 18/07/2026 — v1.80: 12 final endgame stations (generate-image-v2, native transparent)

Solved the station background problem for good. `create-image-pixflux` baked opaque
backgrounds (the trap that ate hull art on the old set). **`generate-image-v2`** (PixelLab Pro
flagship) with `no_background:true` yields NATIVE transparency — far higher detail AND clean
separation, no post-removal. A 24-agent workflow authored 24 detailed top-down station designs;
generated all 24; captain picked **12 finals**, now in `assets/sprites/stations_v2/` (imported):
bastion_command_citadel, bulwark_arsenal_depot, cryo_sleeper_vault_hexpod, gilded_wake_derelict_liner,
glacier_still_ice_harvester, halcyon_ring_habitat, helios_bloom_solar_array, tanker_cluster_fuel_depot,
vantage_quarantine_biolab, verdant_bloom_spa_resort, verdant_halo_hydroponics_ring,
vespers_reliquary_cloister. Picked via a scrollable numbered gallery scene
(`scenes/stations_gallery.tscn`). Art-only for now (breach/Haven endgame); old station sets retired.

---

## 18/07/2026 — v1.79: removed the debris hazard from spacewalk

Captain flagged the "brown ball with a tail" drifting through the spacewalk as ugly. It was
the `_debris` hazard in `main.gd` — a tumbling rock (brown ball + darker centre + orange
motion streak) that flew at the player and, on contact, knocked them and vented O2 ("Debris
strike!"). Removed the WHOLE mechanic, not just the art: state vars, region-timer init, the
`_update_debris` spawn/move/collision, and the draw block. Comets and shooting stars (the
sprite-based ones in `flight.gd`) are untouched — those stay.

---

## 18/07/2026 — v1.78: regenerated 20 device animations via PixelLab + external-API config

Player caught what the earlier audit missed: ~21 device idles had a "whole-object heartbeat"
(the housing scaling/pulsing frame-to-frame) plus soft/mushy frames. A 12-agent deep
diagnosis confirmed it per-device and wrote a precise motion brief for each.

- **Regenerated 18 devices** via PixelLab `animate-with-text-v3`, each anchored on its CRISP
  static sprite as the first frame + its motion brief ("housing perfectly still, ONLY <x>
  animates"): algae_tank, alien_plant, arcade_cabinet, bar_counter, body_scanner, conveyor,
  culture_cylinder, dance_pad, fan_unit, fireplace, jukebox, laser_cutter, planetarium,
  reactor, smelter, specimen_tank, stasis_tube, uv_light. Result: housings dead-still and
  crisp, motion confined to screens/glows/flames/bubbles. Verified: 0 canvas distortion,
  housings sharp in the frame-average overlay.
- **reactor_core, holo_chess, stove → reverted to static.** holo_chess kept colour-cycling
  its board and stove kept drawing a phantom cross/X across the burners even under strict
  "constant colour, almost-still" briefs — a steady sprite reads better than fighting the model.
- **Removed the fabricator "print-in" materialize reveal** — placed pieces just appear now
  (the sparkle VFX stays as feedback).

**External APIs:** keys now persist in `config/external_apis.conf` (GITIGNORED — verified,
never committed); `docs/EXTERNAL_APIS.md` documents the PixelLab endpoints we use + the
"potentials" (rotations, tilesets, inpaint, map-objects, fonts). PixelLab is Tier 3.

---

## 18/07/2026 — v1.77: device-anim smoothness audit + all-craftables test room

**60-agent animation audit** (38 device inspectors comparing each anim's frames to its
crisp static sprite → 4 adversarial verifiers on the flagged ones). Verdict: 34/38 clean.
Two confirmed real, both PixelLab-motion blur that needs frame REGENERATION (blocked until
the PixelLab key is restored to `scratchpad/.pixellab_key`):
- **planetarium** — frame 3 dissolves into a mushy blob (constellation lines gone, base
  plate warps); a one-frame pop in the loop.
- **server_rack** — the multi-colour status LEDs are smeared into a uniform blue glow
  across all frames (loses the device's whole character).
Programmatic pre-scan confirmed geometry is fine on all 38 (canvas 1:1, content aligned,
0 aspect distortion) — the only defects are perceptual frame-content softness.

**Test room** (`scenes/test_room.tscn` + `scripts/test_room.gd`, DELETABLE): an in-engine
showroom of ALL 126 craftables grouped by category, each drawn at its true `dims_of` display
size with the animated 32 looping on the exact in-game timing (`DEV_ANIM_FPS` + per-device
hash rate/phase). Scroll wheel/arrows/PgUp-Dn, Home/End, Esc. For eyeballing every fabricated
object in one place. `SW_SHOT` env screenshots it.

---

## 18/07/2026 — v1.76: asset audit fixes — park-seed bug, palette + broken-art cleanup

Follow-up fixes from the deep asset scan (13 verified-real findings):

**Park-lands-in-different-field (the "Selenium looks different inside vs outside" bug):**
- `flight.gd`'s keep-position-live line was overwriting the parked field's seed centre
  during the 0.45 s fade-to-black, so you dropped into a field seeded from a slightly
  different coord than the preview — different rocks/elements/colours. Guarded it behind
  `if not Transition.is_busy():` so the parked seed freezes once a scene-leave starts.
  Preview field == dive field again.

**Broken element rock-art (dive presentation):**
- 4 bad variants (`el_metal_orange_7` baked watermark, `el_metal_palegold_8` /
  `el_metal_red_7` wrong art, `el_liquid_silver_2` cube-morph) overwritten with a good
  sibling from the same colour family — art fixed with no blank-rock holes (the loader
  picks by `hash % 12`, so a deleted variant would render null).

**Palette + reverted anims:**
- `fuel_tank` recoloured purple → gunmetal steel (cyan fluid icon preserved);
  `sofa` recoloured purple → deep navy-slate to match the interior.
- `surgery_light` anim reverted to static (frames had recoloured the steel arm blue);
  `ore_refinery` station art restored (bg-removal had mangled it).

---

## 18/07/2026 — v1.75: 60-agent whole-game audit — bug/economy/graphics/completion fixes

Ran a 60-agent audit (45 scanners across every script + cross-cutting concerns → dedupe
→ 15 adversarial verifiers). 62 findings; the meaningful ones are fixed. Highlights:

**Save/load data loss (was: strictly worse than not saving):**
- `save_game`/`load_game` now persist the live haul (`carried`/`carried_veins`/
  `carried_items`) — a mid-dive save/quit no longer wipes your walk's ore + veins while
  the rocks stay `mined`, and SOLA's "keep half on blackout" perk survives a save+quit.
- Flight `sector` is synced to the live ship position every frame, so a mid-flight
  save/quit no longer rewinds you to a stale sector.
- `load_game` reads robust: guarded contracts/trader_stock/sector (no crash on a
  truncated save), a `SAVE_VERSION` guard, and NEW-GAME no longer writes to disk until
  chargen confirms (backing out of an overwrite keeps the old save intact).

**Pause / input (was: die inside a menu):**
- New ref-counted pause coordinator in GameState (`push_pause`/`pop_pause`/`clear_pauses`).
  The inventory now pauses the game (no more moving/firing/losing O2 behind it); the star
  chart and pause menu no longer clobber each other's pause (no live sim under a PAUSED
  screen). Inventory + star chart run `PROCESS_MODE_ALWAYS`.

**Ending / graphics:**
- The going-home finale now freezes the crew, locks input, and HIDES the HUD, so the
  fade + HAVEN credits render clean (no panels on top, no E re-triggering the timer).
- Expansion holograms dedupe per cell (a bay bordering two rooms no longer double-draws).
- Quest-log panel raised 206→234 so 3-element drive parts + a live beacon fit inside it.
- Enabled mipmaps on walk / ship / wreck / comet / trash sprites (killed the shimmer).

**Shipping hygiene / crashes:** SW_RICH / SW_WALK / SW_GAMEOVER debug hooks gated behind
`OS.is_debug_build()`; `do_rescue()`, the drive-station label, and dialog art loads
guarded against crashes; helm-fade freezes the suit so a burn can't kill the run
mid-transition; duplicate stat-room build refused before charging.

**Polish:** asteroid hitbox hugs the icon (was an 18% dead ring) and health tracks visible
size; `_sample` gas fallback no longer returns iron; radar home-blip/edge-overflow;
mouse-wheel no longer skips the intro or closes the ID card; bare-modifier taps ignored;
thrust SFX cuts on dialog; deep-space parallax de-inverted; transition tween tracked;
VFX cleanup timer pauses with the tree; dead code trimmed.

Left for the captain's call (balance/design, not silently changed): the `battery_bank`
(Lithium) and `med_bed` (Silver) starter recipes need materials unobtainable until
mid/late game; ore-bag cap vs total sinks reads grindy; nebula texture gen has a
first-sight frame hitch (needs a threaded/`set_data` rewrite).

## 18/07/2026 — v1.74: inter-room walls & doors + full-room buildable plot + GPU ambient

Follow-up to the 40-agent asset audit ("everything unified"). Three interior changes:

- **Inter-room bulkhead walls** (`ship_interior.gd _draw_doorway` / `_draw_walls`) — the
  passage between two built rooms used to be a bare absence (floor continued). It's now a
  **thin metallic bulkhead with a plain open passage** in the middle (no door — the
  captain's call). The wall art is a **PixelLab-generated painted-metal tile** (`assets/
  props/idwall.png`, "paneled_0": recessed steel panels + cyan trim), chosen over 4 other
  generated styles + a hand-drawn fallback by a **4-agent judge panel** (3× first place)
  for best cohesion with the hull/prop kit. `_wall_tex` holds it; `SW_WALLSTYLE=drawn` or
  a PNG path overrides for comparison; `_draw_wall_run` tiles the art (or draws the vector
  fallback). Walls are **solid** — `_build_obstacles` adds collision segments flanking the
  central gap, so you can't cross except through the opening — and drawn inside the
  **depth passes** (`_draw_walls(behind)`), so the crew and props sit correctly in front
  of / behind them (an E–W wall splits at its own y line; a thin N–S wall stays behind).
- **Full-room buildable plot** (`_draw_expansions` → new `_draw_buildable_plot` +
  `_dashed_rect`) — the "expand here" marker was a small hovered olive/X placeholder tile
  (the single worst asset the audit flagged). Replaced with an **in-fiction holographic
  plot covering the WHOLE cell**: ghosted floor wash, dashed cyan construction border,
  corner ticks, a `+` and an "N ORE" cost chip. When you can't afford it the plot turns
  **red with an X drawn corner-to-corner across the entire room** (the captain's ask) and
  the placeholder `cell_ok/cell_no` sprites are deleted.
- **GPU ambient / atmosphere shader** (`assets/shaders/ambient.gdshader`) — one
  full-screen `ColorRect` canvas_item shader on a layer below the HUD: an analytic
  `smoothstep` vignette + drifting 4-octave FBM haze + hash dither, all computed on the
  GPU with **no gradient textures**, so it never bands into the "glitchy circles" the old
  free-standing light pools made. Carries a faint cool tint that doubles as a unifying
  grade over the mixed-source art. The prop `PointLight2D` glows (which light the crew)
  are untouched. `SW_SHOT=<path>` debug hook added to grab the real framebuffer (captures
  2D lights + shader, which PrintWindow drops).

## 18/07/2026 — v1.73: UI de-fat + real 3D keycaps + glass-dome radar

Addressed "the UI feels too big and zoomed out" (32-agent inspect → shrink → redesign →
re-inspect pass, verified on all 6 screens).

- **De-fatted the HUD.** The flight status bar, interior banked-ore chip, crew roster and
  hint bar were rendering at full 1.0 scale, skipping the 0.60 HUD shrink the gear rack &
  quest log already get — so they read oversized. All now go through `UITheme.shrink()`
  and dropped font sizes (10-11px). Quest log and radar re-tucked so nothing overflows.
- **Every key is a real keycap.** `UITheme.draw_key` rewritten from a flat chip to a
  raised 3D physical keycap (StyleBoxFlat: rounded corners, accent bottom-border for
  depth, drop shadow, top sheen highlight, squarer aspect via `KEY_H_PAD`). Applied
  everywhere a key is shown (hint bar, key prompts, rename).
- **Glass-dome radar** (`radar_panel.gd`) — bigger (`RADAR_SCALE` 0.85→0.92, R=78) with a
  radial `GradientTexture2D` glass sheen over a dark disc, cardinal ticks instead of a
  crosshair, sparse dim scanlines, a single sweep leading-edge + wake, a bright rim, and
  nebula rim-markers de-cluttered to the nearest 5. The specular "curved white line" the
  captain disliked was removed.

## 17/07/2026 — v1.72: animated comet & shooting-star sprites

Replaced the procedural `SpaceDressing.draw_comet` painting with the PixelLab sprite
animations. Comets = 3 looks (rcomet_a, rcomet_b, comet_big); shooting star = comet_star
(the "cratered" one). Each is a 7-frame loop, loaded mipmapped, pointed along its
velocity (head leads), drawn SMALL (comet ≤64px / star ≤52px) and fast, and rendered
BELOW the whole foreground so they drift behind the asteroids and ship. Cruise
(`flight.gd`) and the dive scene (`main.gd` shooting stars) both use them. `draw_comet`
removed from `space_dressing.gd` (now dead). Only the 4 chosen sprite sets are installed.

## 17/07/2026 — v1.71: smaller trash + suck-in pickup + colour-salted fields

- **Trash is smaller** — `TRASH_DRAW_MAX` 72→52px.
- **Salvage gets sucked into the ship** — collecting a trash piece now hands its sprite
  to a short suck-in animation (`_absorbing`): it flies toward the hull, accelerating
  (ease-in), shrinking and fading over `TRASH_ABSORB_TIME` (0.45s). Purely visual — the
  materials are still granted the instant you're in range.
- **Fields get a pop of colour** — a new single source of truth `Elements.vein_element(key,
  rich)` (called by BOTH the cruise preview and the dive, so they always agree) salts ~8%
  of rocks with a colourful rare element from `COLOUR_SALT` (greens/pinks/violets/golds).
  Averages ~1-2 per field, decided by a seeded RNG (uniform, no clustering). The pool
  deliberately EXCLUDES every economy/progression element (Fe/Si/Mg/Al/Ni/Ti/Cu, Ag/Pt/Au,
  U/Th), so it can never trivialise the drive-build or trade — it's just visual variety.

## 17/07/2026 — v1.70: per-element rock tint + 10-agent gameplay-audit fixes

**Cruise rocks are the generated painted rocks, grouped into COLOUR FAMILIES by what
each element's icon looks like — shown AS-IS, never tinted.** New `scripts/rock_family.gd`
(`RockFamily`): `family_for(sym)` classifies an element by its icon glow (`glow_for`) into
one of 10 colour families (red/orange/gold/green/cyan/steel/purple/pink/dark/silver);
each family maps to the painted art combo(s) of that colour; `rock_art` picks a stable
per-rock random variant from the family's pool. `flight.gd _draw_fields` draws it untinted.
So gold element → gold rocks, uranium → green, oxygen → cyan, carbon → dark, most metals →
steel-blue. This replaces the earlier ElementKinds chemistry grouping (dropped — made
oxygen a green nonmetal rock) AND the brief tinted-grayscale experiment (dropped — the
painted rocks are beautiful as-is). Removed all unused asteroid art: `element_kinds.gd`,
the plain `neutral_*/core_*` blobs, and the baked `rockd_*` set.

**Bug fixes from the 10-agent audit:**
- `Transition.to_scene` had no re-entrancy guard — mashing a key during the 0.45s fade
  double-fired scene changes. Added a `_busy` latch + swallow keys/clicks mid-swap.
- Pause menu (`menu.gd`) now ignores ESC while a transition is in flight (was freezing
  into a half-loaded scene). Game-over screen swallows ESC so pause can't open over it.
- Blackout/faint path now `save_game()`s — mined rocks no longer respawn if you quit
  after fainting.
- Haven ending latched so the title swap fires exactly once.
- Refinery bonus was `ceil` (+100% on odd/small amounts); now `floor` — honest +50%.
- Platinum guaranteed at the Ignition Lattice quest part (rep 6): it's the only lattice
  metal with no rock/wreck source, so the quest can't wall behind trader RNG (mirrors
  the existing U/Th guarantee).

## 16/07/2026 — v1.69: out-of-oxygen game-over screen

New cinematic screen on running out of O2 (`scripts/game_over.gd`). Triggered in
`player.gd:_black_out()`: fades in over the faint, holds on a quote, SPACE (or
auto after 11s) continues to the bunk wake — same lose-cargo/wake mechanic, now
with a screen.

- Full-res captain (assets/sprites/gameover/astronaut.png, chroma-keyed) drifting
  via slow in-engine rotate+bob — sharp at any size (PixelLab frame-anim was capped
  at 256px and looked soft; a rigid drift reads better for an unconscious body).
- Hand-authored striped TETHER art (gameover/tether.png, keyed) attached at his
  backpack, swaying ±2.5°, sweeping off the bottom-right in perspective.
- Starfield bg (gameover/starfield.png), title + "THE REACH CLAIMS ANOTHER" +
  a random line from an 8-quote pool, staged fade-ins.
- Mounted on a CanvasLayer (screen space) so it isn't dragged by the EVA camera.
  Debug: `SW_GAMEOVER=1` pops it on the spacewalk scene for screenshots. Assets
  load via Image.load_from_file (no .import dependency).

## 16/07/2026 — v1.68: element art system — KIND→colour asteroids (PixelLab)

Replaced the procedural/icon asteroid look with a generated art set organised by
PHYSICAL KIND (shape) then COLOUR (element), 8 variations each. Verified in-game
in BOTH the cruising and spacewalk views — same rock reads identically in each.

- TAXONOMY (scripts/element_kinds.gd, new `ElementKinds`): 4 kinds → 11 colour
  combos → 8 variations. `combo_of(sym)` is a pure function of `Elements.category`
  + two liquid overrides (Hg→liquid_silver, Br→liquid_amber). Kinds: metal
  (grey/gold/orange/palegold/red), crystal (purple/green/pink), liquid
  (silver/amber), gas (cyan). Presentation ONLY — the drop economy
  (*_fractions/sample_*) is untouched.
- DETERMINISTIC art: `rock_art(sym, key)` picks `el_<combo>_<hash("art:"+key)%8>.png`
  (88 sprites in assets/sprites/element_art/, loaded from raw PNG like icon_for so
  it needs no .import). Because a rock's flight `key` and dive `mine_key` are the
  same "sx:sy:idx" string, a rock looks identical previewed while cruising and
  mined while spacewalking.
- WIRED: asteroid.gd:57 (dive node `_icon`), flight.gd `_field_in_chunk` (forwards
  `sym`) + `_draw_fields` (cruising preview) — both now draw `ElementKinds.rock_art`
  with the OLD grey-body+tinted-core kept as an automatic fallback. Downstream
  scale/offset/collision refit from the texture size, so no other changes needed.
  Left untouched (per call-site audit): all small UI icons (dex/fabricator/upgrade),
  spark/label/radar chemistry colours, pickup mini-icon.
- KNOWN design call: Oxygen (gas category, but MINED as rock and very common)
  renders as a cyan gas-CLOUD among the solid rocks. Reads fine but is a stylistic
  choice — option to add a cyan "ice-rock" variant for O/F/Cl if clouds feel off.

## 16/07/2026 — v1.67: UI slim pass + radar resize + 2-agent audit fixes

- UI SLIM (ui_theme.gd, global): Label font 13→11, Button 14→12, panel content
  margins 12/18→8/12, corner CUT 18→14, UI_SCALE 0.70→0.60 — slims every corner
  HUD panel (banked-ore, vitals, gear cards) at once. Keycaps de-chunked: draw_key
  padding size+9→size+6, width tw+12→tw+8.
- TITLE MENU (title.gd): shrunk — ITEM_W 340→280, ITEM_H 50→38, gap 12→9, label
  17→12, icon 16→13, panel padding tightened (was "way too big").
- RADAR pulled off the global scale onto its OWN `RADAR_SCALE` 0.85 (bigger than the
  old 0.70); quest/objectives panel re-spaced (offset 150→188) to clear it, in both
  flight.gd (helm) and hud.gd (spacewalk).
- ZONE ELEMENTS (asteroid.gd): ICON_MAX 26→16 (52px→32px) so mining nodes sit near
  the ~26px EVA astronaut, not dwarfing it.
- AUDIT FIXES (2 read-only agents — flow+functionality clean, views found 1 regression):
  * title slot labels were clipping after the menu narrowed — label font 13→12 +
	ITEM_W 280 so "SLOT 1 — NAME · DRIVE n/5" fits without cutting the tail.
  * STAR CHART now pauses the sim while open (process_mode ALWAYS + get_tree().paused)
	— the ship no longer flies / docks under the open map.
  Agents confirmed no crashes, soft-locks, save-corruption (incl. seen_regions round-
  trip), input-eating, or determinism breaks.

## 15/07/2026 — v1.66: star chart + radar crew/derelict markers ("bigger" pack, slice 1)

First slice of the "feel bigger" work — a knowledge backbone + its flagship view.

- KNOWLEDGE BACKBONE (game_state.gd): new `seen_regions` dict; `note_ship_at(p)`
  reveals any nebula within 1.75x its radius as the ship flies (called each frame
  in flight._process). Saved/loaded and reset in new_game. All future "bigger"
  views (codex, contracts) read this.
- STAR CHART (scripts/starchart.gd, toggle M in flight): full-screen overlay
  drawing the whole universe to scale — home + concentric region rings (Reach/
  Drift/Belt), every deterministic nebula named + colour-coded once seen, faint "?"
  contacts for the undiscovered ones (so the scale reads as vast), the live ship
  marker and the current distress beacon. Pure vector _draw, no art assets. `SW_CHART`
  env opens it pre-seeded for screenshots. Added to keymap flight hints.
- RADAR crew portraits (radar_panel.gd): the in-range distress beacon now shows the
  target crew member's roster face (assets/sprites/crew/roster/<name>_face.png) in a
  gold ring instead of a plain gold dot.
- RADAR derelict ships: derelicts (flight._wreck_in_chunk, previously not on the
  scope) now show as a small, faint, ship-shaped marker (new assets/ui/derelict.svg),
  rotated to the hull, rare ones slightly larger.
- DROPPED from the pack per captain: ambient life (distant ships / comm chatter).
- ZONE ELEMENT SIZE: mining-field element nodes were still dwarfing the crew —
  asteroid.gd `ICON_MAX` cut 26→16 (longest axis 52px→32px), so nodes sit near the
  ~26px EVA astronaut and well under the ship. One constant if further tuning wanted.

## 15/07/2026 — v1.65: bug-audit fixes (3-agent whole-game pass)

Fixes from a read-only functional/logical audit of the whole codebase. Worst first:

- DIVE-FIELD DETERMINISM (game_state.gd): `dive_field()` drew each rock's radius from
  the live `tether_length` (a mutable upgrade). That feeds overlap-rejection, which
  decides which rocks keep an `idx` — so upgrading the tether silently reshuffled every
  field and desynced saved mined-state (mild ore/element dup + rocks reappearing). Now
  a fixed `DIVE_FIELD_MAX_RADIUS` (920) — the field stays put; the tether grows REACH.
- WALK-FRAME CRASH GUARDS (interior_player.gd): a missing/mis-named walk direction
  (0 step frames, or a null `<dir>_idle.png`) caused modulo-by-zero / null-texture
  crashes while walking. Now: idle falls back to frame 0, WALK never empties, and
  `_phase`/`_frame`/`_process`/`_draw` guard empty sets. Latent today but sits right
  where the PixelLab walk art is churning.
- HELM-FADE RACE (main.gd): pressing E during the 0.6s take-the-helm fade wasn't gated
  by `_leaving`, so it raced a second scene change and dumped you in the wrong scene.
  E now checks `not _leaving` like F does.
- BUILD-ONCE ROOMS (game_state.gd): greenhouse/workshop granted their flat stat bonus
  on EVERY build (unbounded stacking if that UI is ever wired up). Guarded to first-build.
- CREW GESTURES (ship_interior.gd): gesture picker could replay the resting/base pose;
  now only fires when a real gesture group exists and never picks group 0.
- NPC FRAME ORDER (ship_interior.gd): idle/breathe frame sets sorted as strings ("_10"
  before "_2"); now numeric via `_trail_idx` (matters once a set hits ≥10 frames).
- `_feet_frac` (ship_interior.gd): decompress a VRAM-compressed frame before `get_used_rect()`.
- Minor: room-name label now uses the feet cell (matches the rename target); chargen
  accepts numpad Enter; upgrade modal guards `GEAR_ICON[kind]`; SW_WRECK debug idx clamped.
- DEFERRED (documented, not fixed): furniture doorway keep-out and station line-of-sight
  are recoverable/rare and risk over-blocking valid actions — flagged for a focused pass.

## 15/07/2026 — v1.64: living ship — animated device props + bigger trash

The interior devices are now alive, and space trash reads at a proper size.

- ANIMATED DEVICE PROPS: 20 ship devices now play subtle seamless PixelLab loops
  in place of their static sprites — engine (reactor core breath, battery charge
  bars, generator flicker, coolant shimmer), bridge (console data-flicker, radar
  blips, monitor scanlines, holo-table projection), medbay (ECG waveform, sample-
  fridge frost), cargo (fabricator build-beam, server-rack LEDs), and fabricator-
  built fixtures (tesla-coil arcs, surgery light, grow-rack, hydroponic tray,
  seedling table, terrarium, aquarium fish, fountain). Each is a 6-frame loop at
  the source sprite's exact size; the botany/water set was motion-masked so only
  the water/lights move and housings stay rock-solid (no boil, no drift — motion-
  sickness rule). Loops live in `assets/sprites/device_anim/<id>_0..5.png`.
- PLAYBACK (ship_interior.gd): a non-destructive layer loads any `device_anim/<id>`
  frame set once in `_ready` and draws it in `_prop()` (room props + stations) and
  `_draw_furniture()` (placed craft, keyed by craft id). Playback is tuned for calm,
  smooth motion: base ~2fps, each device gets its own speed multiplier (0.8-1.2×)
  AND start phase, both hash-derived, so no two ever step in unison (the first cut
  shared one `int(clock*fps)` → everything flipped together, read as fast + synced).
  Single crisp frame per draw — a crossfade tween was tried but a half-opaque N+1
  frame ghosts badly when the ship scrolls, so it was dropped (these are already
  GPU-composited; the fix was technique, not hardware). If no frames exist for an id
  it draws the static sprite exactly as before — verified boot-clean with folder empty. A `DEV_ANIM_ALIAS` maps the
  4 room-prop keys whose kit name differs from the craft stem (ecg→ecg_monitor,
  hydro_tray→hydroponic_tray, seedling→seedling_table, terrarium→terrarium_dome).
- TRASH: `TRASH_DRAW_MAX` 42 → 72 so debris reads at roughly half the ship rather
  than a distant speck.
- CRISPNESS FIX (all fabricated items, not just animated ones): every craft texture
  (127 files) had `mipmaps/generate=false` while every prop had `=true` — so the
  scene's `LINEAR_WITH_MIPMAPS` filter had no mip chain to sample and fabricated
  items shimmered / mushed when drawn small (worst on thin lines: screens, grids,
  consoles). Enabled mipmaps on all 127 craft + the 120 device_anim frames to match
  the props → clean minification, no shimmer, across the whole catalogue.
- Additionally, the 20 animated device sprites are high-res (e.g. console 407px,
  radar 266px) but draw at 28-76px in-room (~4-7× minification). Their loop frames
  were area-downscaled to ~2.2× the on-screen size so thin-line detail is baked at
  display density (crisp base level) instead of being mip-blurred away. Native
  frames backed up outside the repo.

## 15/07/2026 — v1.63: flight smoothness — GPU-batched sky + movement fixes

Fixed fast-travel stutter, the ship "kick-back", and the screen-darkening in
space. All in flight.gd.

- MOVEMENT: `_process` now clamps `delta` (≤0.05s). A frame hitch used to spike
  delta, and the damp lerp `vel.lerp(0, 1-exp(-DAMP*delta))` then zeroed velocity
  in one frame — the felt "kick-back" / lurch. Clamping keeps motion (and
  turning) smooth through stutters; physics feel unchanged at normal frame rates.
- GPU-BATCHED BACKGROUND (the "feels like no GPU" fix): the starfield, deep-space
  specks and nebula fog were CPU immediate-mode (~9000 draw_circle/draw_texture
  calls/frame). Now: each parallax STAR layer + the deep specks = one
  MultiMeshInstance2D (thousands of stars in ONE draw call each, rolling chunk
  window, per-frame cost = one node position set/layer); NEBULAE = Sprite2D nodes
  (lazy-built). ~9000 draw calls → ~7. Generation is byte-identical (same seeded
  chunks) so the sky is unchanged; near-layer glint crosses kept as a tiny
  immediate overlay. Fast travel is now flat-cost/smooth.
- Cache caps raised (stars 3k→12k, field/trash/wreck/deep 512→2048) so the full
  cache-clears that caused the worst stalls are rare.
- NEBULA FOG lightened (0.6 / 0.38) so flying through a cloud tints gently rather
  than darkening the whole screen.
- JEWEL STARS: a rare saturated tint on stars (per-layer ~1.5-6%, absent on faint
  deep dust; gold/coral/ice-blue/magenta/teal palette, slightly bigger/brighter),
  hash-rolled so the neutral field stays byte-identical — occasional colour, not
  a rainbow.

## 15/07/2026 — v1.62: real breathing loops + interior light cleanup

- CREW BREATHING: replaced the code "breathing" (a chest-band width-scale that
  read as an ugly enlarge effect and was barely visible) with real PixelLab
  breathing animations — a subtle 6-frame chest-rise LOOP per crew (30 frames),
  head HARD-LOCKED (fixed head composited over every frame so face/goggles/
  glasses/visor are pixel-identical and only the chest/torso moves — the raw
  text-to-animate output otherwise turned heads / opened mouths / dropped VEGA's
  visor). Seamless palindrome loops. ship_interior.gd rest state now plays the
  `<name>_breathe_*` loop continuously (NPC_BREATHE_FPS 3.5) until the next
  random gesture; falls back to a static frame if absent. All the NPC_BREATH
  band-scale code was removed.
- Gesture cadence made more frequent (first 1.5-8s, rest 4.5-10s between
  gestures), still independent per-NPC so they never sync.
- INTERIOR LIGHTS: removed the free-standing ROOM_AMBIENT colour pools — they
  rendered as ugly soft "opacity circles" in the middle of every room. Room
  colour now comes only from glows on actual lit props (reactor, monitors, etc.).

## 15/07/2026 — v1.61: crew gesture variety + polish fixes (multi-agent)

- CREW IDLE POOL: each of the 5 crew got 3 NEW personality idle gestures via
  PixelLab (15 total, 90 frames) — JUNO tool-inspect/brow-wipe/wrist-check, MIRA
  plant-examine/glasses/stretch, HALE arm-cross/knuckle-crack/glance, SOLA
  hand-wring/datapad/neck-touch, VEGA scan/posture/console-nod. All curated as
  out-and-back palindromes so they start AND end on the neutral rest frame
  (clean blend), feet-anchored + size-matched to each crew's existing idle set.
  ship_interior.gd now loads a POOL per crew (globs <name>_idle*_<n>) and plays
  a RANDOM one, once, slowly (3fps), then rests.
- GESTURE TIMING FIX: crew were triggering in unison — each NPC now owns a
  `.randomize()`-seeded RNG with a wide first-trigger window (3-25s) and
  infrequent rest (12-30s), so they're provably independent/staggered. Subtle
  chest-breath at rest retained.
- QUARTERS: removed the tool desks (workbench + toolboard) — didn't belong in a
  crew berth; layout rebalanced (rug/bunks/wardrobe/chairs/nightstands/plants).
- HALE renders larger (NPC_SCALE 1.15, scaled about the feet so he stays
  grounded) — he's a big man.
- NEBULA: killed the concentric-ring artifact — two causes fixed: nebula_fog.gd
  radial falloff made noise-ragged (dissolves into wisps, no circular edge), and
  the two hard-edged "heart" discs replaced with soft gradient glow. Reads as an
  organic cloud with a gentle core.
- SPACE TRASH: bigger (TRASH_DRAW_MAX 28→42) and the faint glow disc behind each
  piece removed.
- CREW ROSTER: made smaller (circle diameter 44→30, tighter gaps/ring/caption).
- HUD gear rack now uses the same painted gear icons as the inventory.

## 15/07/2026 — v1.60: big art/animation/UI pass (PixelLab + real assets, multi-agent)

A large session-long polish pass. Grouped by area:

- REAL SPACE TRASH: the 4 placeholder code-drawn scrap shapes replaced by ~191
  cropped sprites (from the captain's green-screen sheets, tools/crop_trash_a/b.gd
  + full-component re-crop to kill half-crops). flight.gd loads assets/sprites/
  trash/*.png dynamically and draws each at a 28px cap (~1/5 of the ship) with a
  static random tilt (no nausea spin). Salvage economy (metals/units/taken)
  untouched — sprite is a hash-derived per-piece index, no RNG-stream change.
- INTERIOR WALK: back/up direction rebuilt so it's a complete, natural rear
  walk (skeleton-driven PixelLab candidate won a 4-method tournament; head/visor
  locked; arms alternate contralaterally, subtle from behind as a rear view must
  be — both hands, no running pose). front/left/right unchanged.
- CREW ABOARD: all 5 rescued crew now show animated PixelLab idles (personality-
  driven: SOLA shy fidget, MIRA tablet, VEGA at-attention, HALE arms-crossed,
  JUNO tinkering). Rendering overhauled in ship_interior.gd: removed the
  left/right facing-flip (no popping), slowed to rest+breathe with a one-shot
  gesture every 7-15s (staggered), feet planted via real feet-line detection
  (fixed floating), added ground shadows. JUNO + MIRA face left (NPC_FACE_LEFT).
- CREW ROSTER HUD: new scripts/crew_roster.gd — 5 circular crew portraits top-
  right, full-color if rescued / dark if not ("CREW n/5"). Wired into _build_hud.
- QUARTERS: now a 2-cell open room (cells 0+1), furnished like a berth — 3 double
  beds along the top, round rug centrepiece (FLAT_PROPS: non-blocking floor
  decal), wardrobe/chairs/nightstands/workbench/toolboard/plants. Left locker
  removed. Walk lanes + doorways kept clear.
- AMBIENT LIGHTS: room-differentiated colour washes (engine warm orange, medbay
  rose, quarters amber, bridge cyan, botany green+magenta, airlock hazard-amber),
  brightened via _add_light e_scale; calm breathe/sway only, no bulk motion.
- SPACEWALK ANIMATIONS: the 8 static astro states now play PixelLab loops — idle
  float (slow ~2.5fps, serene), thrust, mining-aim (muzzle preserved at a5 tip),
  tether-reach (rebuilt clean, no baked cable). Brake/debris/blackout stay static.
- GEAR ICONS: painted icon set (helmet/lifeline/o2/laser) cut from a green-screen
  sheet into assets/sprites/gear/, used in BOTH the inventory exosuit rows and
  the bottom-right HUD gear rack (was minimal cyan SVGs).
- INVENTORY: white pixel suit replaced with a keyed-transparent neon chibi suit
  (assets/sprites/suit_wireframe.png), drawn premium (glow disc + brackets);
  fonts tightened; bottom-left discovery gauge overflow fixed (pinned inside the
  panel); hover detail text shrunk 11→8.
- ASSET AUDIT (read-only): full image sweep — essentially clean; only trivially
  unused dev artifacts (props/s4_12.png, root zoom_parts.png) flagged, none
  deleted pending the captain's call.

## 14/07/2026 — v1.59: interior walk cycle SOLVED via PixelLab (real per-frame motion)

- The long-running walk failure is fixed. Root cause finally named: ChatGPT
  sprite sheets are N independent DRAWINGS, not an animation — legs don't carry
  through frame to frame, so no curation/rigging could make them read as a walk
  (frames/3/4/5/6 + the rig experiment all died on this). Switched tools to
  PixelLab (pixellab.ai), which animates from a single reference image with real
  frame-to-frame continuity AND preserves our exact astronaut.
- Pipeline (agent-run, REST API `POST /animate-with-text-v3`, async job + poll):
  fed each direction's clean idle still (front/back/right/left_idle.png) with
  action "walking …", frame_count 8, no_background. 8 walk frames per direction,
  native 80×121 canvas, feet-anchored + horizontally centred (verified ±2px), no
  size drift. ~10 generations spent (plan has thousands).
- VISOR FLICKER hard-locked: PixelLab animated the visor's specular glint, which
  flickered. Fixed by COMPOSITING a fixed head+visor region over every frame
  (6px feathered neck seam) so the dome is pixel-identical across all 8 frames —
  only torso/legs move. Sides lock from a profile walk frame (PixelLab rotates
  the head to true profile; the 3/4 idle would mismatch); front/back lock from
  the idle. Verified dead-still in-game.
- interior_player.gd UNCHANGED — the existing 8-frame HOLD8 easing + distance-
  locked CYCLE_PX path already handled it. Files: right/left/front/back_0..7.png
  (32 new), idles untouched. In-game QA (SW_WALK bursts) PASS all four directions.

## 14/07/2026 — v1.58: SMALLER scavenge zones + a VAST universe

Two coupled world-scale changes (game_state.gd + flight.gd), per the captain:
the asteroid circles were too big and too close, and the crew-rescue missions
sat almost on top of each other.

- SCAVENGE ZONE SHRINK (game_state.gd `dive_field`): the asteroid circle you
  see while flying / mine on spacewalk is now ~52% of its old radius (~948 →
  ~488px). Done by scaling ONLY the emitted rock position (`pos * 0.5`) — the
  seed (`hash(Vector2i)`), the per-rock vein seed, the RNG call order, the
  overlap check, rock count, rock RADIUS (mining HP/yield), and every element
  sample are byte-for-byte unchanged. The captain's "don't lose that seed
  model" and the standing element-abundance rule are both fully preserved;
  only the geometry tightened. Flight preview and the real dive shrink together
  (shared generator).
- ZONE SPACING (flight.gd): FIELD_CHUNK 1600 → 3600 (~5× sparser by area since
  one field spawns per chunk), so zones read as clearly separated with open
  space between them. `_chunk_seed` untouched — repositioned, not rerolled.
  PARK_REACH 140 → 80 to hug the now-smaller circles.
- VAST UNIVERSE (game_state.gd): all mission/region distances ×2.2 (rescue
  beacons 7400→16280 and 11500→25300, and every NEBULAE `dist`; region bands
  ×2.2 to match), so the five crew are far apart. Region names/order and the
  load-bearing first nine nebulae are unchanged; nebula radii ×1.3 so bigger
  regions don't look like pinpricks. Added 5 new nebulae (indices 19-23) to
  keep the enlarged sky populated.
- RICH, NOT EMPTY (flight.gd): to fill the vaster space without new art or
  shaders — a deepest micro-dust star layer plus a `_draw_deep_space` far
  parallax pass of distant rock specks, cached per chunk. All static in world
  space, parallax-scrolled by real ship motion only — no wobble/rotation/pulse
  (motion-sickness safe). MAX_SPEED 720 → 1152 (×1.6) so crossing the bigger
  universe stays epic, not a slog. NOTE: the first cut of the haze faked a
  radial gradient with stacked low-alpha discs, which banded into visible
  concentric circles — removed per the captain; the real NEBULAE are a separate
  system and untouched. The park-range ring (`_draw_fields` draw_arc) was also
  softened to a faint 1px hint (alpha 0.25→0.08) since the captain dislikes bold
  drawn circles — the "E · Park" prompt still carries the affordance.
- Verified in-game: the zone is a contained cluster (was edge-to-edge), zones
  are spaced, and the deep-space haze/dust reads richer. Both files boot clean.

## 14/07/2026 — v1.57: walk cycle rebuilt from a UNIFORM per-direction sheet (frames6/10)

- The rig experiment (v1.56) was scrapped — leg-swap compositing on a fixed
  torso read badly. Replaced with a clean generated sheet: frames6 sheet 10,
  the one sheet drawn per-direction with a consistent 4×5 layout (RIGHT / LEFT
  / FRONT / BACK rows; col 0 = idle, cols 1-4 = the walk). Single source =
  zero style drift, which is what the captain asked for ("for uniformality").
- Two-agent pipeline: (1) extraction+curation graded all 20 figures, ordered
  each direction gait-correct (front reordered [1,2,4,3] so the two
  opposite-foot steps land on opposite cycle phases instead of stuttering),
  and extracted feet-anchored on an 80×121 common canvas with helmet-width +
  row-height normalisation — heights locked, zero frame-to-frame jitter. (2)
  in-game QA burst-captured all four directions in the live game, confirmed
  the legs alternate and stay grounded, and fixed cadence.
- interior_player.gd: CYCLE_PX 72 → 120. At 72 the cadence was ~267
  footfalls/min (a frantic scurry — the "super fast" the captain flagged); 120
  lands ~160/min, a brisk natural walk, for the least foot-slide that still
  reads as walking. (Some slide is inherent: the drawn stride is ~16 world
  px/cycle, far shorter than any playable speed — the universal top-down chibi
  compromise.) HOLD4 easing, 1px bob, and SPEED 160 left as-is — all sound.
- Honest limit: in the side views the far leg is largely hidden behind the
  bulky suit, so the near leg visually dominates — inherent to the art, not
  fixable in code. Reads as a walk; flagged for the captain's call.
- tools/extract_walk_frames6.gd + tools/montage_rig6.gd are the frames6
  pipeline (verification montages per direction, 3× zoom).

## 14/07/2026 — v1.56: RIGGED 8-frame side walks — one fixed body, real leg cycle (SUPERSEDED by v1.57)

- The AI sheets' side walks kept failing because every frame redrew the whole
  astronaut — helmet/torso jittered between frames and only 4 distinct leg
  poses existed. New approach (tools/rig_walk.gd): sprite-rig surgery. ONE
  fixed upper body (cut from the idle above the hip line, y=93 of 124) is
  composited over EIGHT leg blocks — the 4 sheet strides + the idle's
  feet-together as the passing pose + horizontal MIRRORS of the stride legs
  for the opposite step. Result: contact→down→passing→up × both legs, zero
  style drift, heights untouched (feet stay on the canvas bottom, hip line
  fixed, torso pixel-identical in all 8 frames).
- Both side rows rigged (right_0..7, left_0..7); front/back keep their good
  4-frame sets — interior_player.gd handles mixed cycle lengths per direction.
- Walk clock made cycle-aware: CYCLE_PX (72px ground per FULL cycle) replaces
  the per-beat stride, so 8-frame rows walk at the same ground rate as 4-frame
  rows — more frames just subdivide the same stride, no leg-churn speedup.
- Easing extended with researched gait weights (a background agent digested
  Richard Williams / SLYNYRD / finalbossblues): HOLD8 = [1.30, 1.10, .85,
  .75]×2 normalised — real walks spend ~60% of the cycle in stance, and the
  "up" pose is shortest because the body FALLS fast into the next contact.
  Bob toned down 1.6→1.0px per the same research (~2.5% of body height; more
  reads as a bouncing balloon on a helmet-heavy chibi).

## 14/07/2026 — v1.55: walk BOB + EASING — the two missing animation laws

- Researched proper walk-cycle craft (SLYNYRD pixelblog 50, sprite animation
  guides): a walking body sits LOWEST at contact and rises through passing
  (vertical bob), and contact frames HOLD longer than passing frames
  (easing). Our cycle had neither — flat glide + metronome timing reads
  robotic no matter which frames play.
- interior_player.gd: stride bob (±1.6px, sine phased so dips centre on the
  contact holds; the shadow stays put, grounding the feet) + 30/20 easing on
  the 4-frame cycle (contacts hold 30% of the cycle each, passes 20%). Both
  driven by the distance-locked phase — no time wobble, no screen motion.
- Pipeline stands ready for 6-8 frame rows (dynamic frame counts) if the
  captain generates from a proper pose template.

## 14/07/2026 — v1.54: walk frames HAND-PICKED across all ten frames5 sheets

- Per the captain's order ("YOU pick the frames"), every direction row of all
  10 frames5 sheets was reviewed personally at zoom (tools/compare_sheets.gd
  stacks one direction's row from every sheet into a strip). Verdict: SHEET 10
  wins all four directions — the only sheet drawn per-direction ("SIDE VIEW
  RIGHT/LEFT", "FRONT VIEW", "BACK VIEW"), upright, clean, visibly alternating
  legs everywhere; single-sheet source = perfect style consistency. (Agent's
  sheet-4 pick had weaker front/back rows.)
- Sides play in sheet order; front/back use the smoothest-loop order
  [0,3,1,2]; the optimizer confirms all four final orders are the smoothest
  cycles. left walk frame 0 was ~8% oversized (helmet detector mis-measure) —
  hand REFIT (0.944) brings it to size. Typewriter fix rode along: Space
  during the reveal now always completes the wrapped text first (the reveal
  counter was off by one char per wrapped line, so a first press could skip).
- Dialog windows opened live for the captain per character (SW_DIALOG runs).

## 14/07/2026 — v1.53: walk SKATING fixed — distance-driven stepping

- The walk cycle was clocked by TIME (fixed cycles/s), so at 205 px/s the
  body glided ~137px per cycle while the drawn stride covers ~40px — the feet
  slid 3x their stride across the deck. Classic skating; no frame set can fix
  a clock mismatch. The cycle now advances per PIXEL OF GROUND ACTUALLY
  COVERED (STRIDE_PX 18/beat, measured from real position delta — blocked by
  a wall = no travel = no stepping), phase-locking feet to the floor at any
  speed. SPEED trimmed 205 → 160 so the matched cadence reads as a brisk
  walk, not a sprint. Footstep sfx unchanged (2 per cycle).

## 14/07/2026 — v1.52: per-line dialog EXPRESSIONS in the first-meeting scenes

- **Both figures now act the conversation.** Every line in
  `crew_dialogs.gd` carries `"expr"` (the crew member's pose/expression) and
  `"pexpr"` (the captain's body language — he's a back view, so he gestures:
  talk/ask/shrug/point/wave/offer/think/wait/neutral). Worried lines look
  worried, jokes grin, orders point: HALE rants about HELIOS, VEGA touches
  her chest at "copies in my head", MIRA does her apologetic wave, JUNO goes
  arms-wide for "TEN minutes".
- **59 green-screen renders conditioned** by `tools/prep_dialog_figures.gd`
  into `assets/sprites/crew/dialog/<name>_<expr>.png` (9 captain poses + 10
  each for the five crew; 9 near-duplicate captain takes skipped). Chroma key
  needed a delta term (`g - max(r,b) > 0.30`, measured: bg ~0.9, MIRA's sage
  suit <= 0.20) or it ate her outfit; despill pulls green down to `max(r,b)`
  on the 2px halo rim plus any strong remnant — no green fringe on the dark
  interiors.
- **No size/position snap between lines**: per set, every pose is scaled so
  the crown-to-feet height matches the neutral one (the planned head-WIDTH
  match broke on chin-touch poses — a hand merged with the face run and shrank
  SOLA 20%), then bottom-aligned feet-centred on ONE shared canvas. The scene
  draws all expressions of a character through the NEUTRAL texture's content
  box, so the body stays dead still and swaps are hard cuts — no motion.
- `dialog_scene.gd` preloads the referenced expressions in `start()` (instant
  swaps, no disk hitch), keeps the old speaker-dim + fade behaviour, and falls
  back to the static `<name>_figure.png` (with the old FLIP mirroring) if an
  expression png is missing — never crashes. The conditioned crew art all
  faces screen-LEFT toward the captain, so the dialog/ path never flips.
- New debug hook: `SW_DIALOG_LINE=N` (with `SW_DIALOG=<NAME>`) opens the
  meeting at line N for screenshot verification.
- Verified in-game: JUNO/MIRA/HALE/VEGA screenshots incl. mid-conversation
  lines — expressions match the text, speaker brightens, no fringe, sizes
  match the old figures.

## 14/07/2026 — v1.51: interior walk cycle rebuilt from the frames5 art drop

- **All 20 walk/idle frames replaced** (`assets/sprites/walk/`) from the
  captain's frames5 batch — 10 candidate green-screen sheets, all the same
  4-rows × (4 walk + 1 still) layout. Every sheet was inspected; **sheet (4)**
  won on the usual weak spots: front/back rows show clearly alternating boot
  soles (no near-duplicate shuffle frames) and the figure size is uniform
  across all 20 poses.
- **Playback order derived, not guessed**: `tools/analyze_walk.gd` pairwise
  pixel-diff BEST LOOP + a gait probe (lowest-foot centroid / leg spread per
  frame) + tracking both legs across frames. Final KEEP orders — right
  `[0,3,1,2]` (contact → wide push-off → trail lift → low swing), left
  `[0,1,2,3]` (sheet order already is the cycle; optimizer cost 0.493, the
  smoothest row of the set), front `[0,3,1,2]` (L-step → R-knee-lift →
  R-step → L-gather; lowest-foot x alternates −11/+11 px), back `[0,3,1,2]`
  (R toe-off → plant → L toe-off → L swing — sole flashes alternate sides).
- **Normalisation unchanged and verified**: helmet width 68 (67–69 across
  sides/back, 71–72 front where the helmet rim reads wider), row-median
  height 120 (frame heights 115–122), one common 79×122 feet-anchored canvas
  — no size snap between directions or idle/walk. Baked green-screen feet
  shadows keyed out as before (game draws its own).
- `tools/extract_walk_frames.gd` retargeted to the frames5 sheet (same
  pipeline, SRC + KEEP only). `interior_player.gd` untouched — it auto-detects
  the same 4-frame + idle files.
- Verified: montage contact sheet + in-game screenshots of all four walk
  directions (SW_WALK harness) — clean edges, no green fringe, correct scale.

## 14/07/2026 — v1.50: full UI typography & layout pass (every surface screenshot-audited)

- **Every UI surface captured from the real game and audited** — title (+
  save-slot menu), spacewalk HUD, flight HUD, ship interior, fabricator,
  upgrade modal, crew ID card, inventory (+ element trivia card), recipe
  banner, rename toast, pause menu, chargen.
- **Toast messages fixed on all three HUDs** (spacewalk / flight / interior):
  they were default-16px Labels anchored CENTER_BOTTOM while still empty, so
  set text grew RIGHT of center — "Docked — O2 refilling." rendered off-center
  and overlapped the F TAKE THE HELM prompt (spacewalk had it at 80px from the
  bottom, straight through the prompt at 96). All three now sit in one shared
  toast band 150px up (clear of dock/helm/interact prompts and gear cards),
  grow BOTH ways from the center anchor so they stay dead-centered, and
  inherit the new 13px Label size.
- **Theme-level typography normalisation** (`UITheme.make_theme`): default
  Label 13px, Button 14px — the captain found the stock 16px too big
  everywhere it appeared (interior BANKED ORE plate, flight nav bar, pause
  menu buttons, chargen buttons). Panels wrap tighter automatically.
- **Flight nav bar tidied**: "Banked ore: 0" → "BANKED ORE   0" at 11px dim
  (matches the interior plate's wording and role), sector line down to 13px.
- **Pause menu**: title 17 → 15px over the now-14px buttons.
- **Inventory trivia card**: the hovered element card's bright white border
  was shining through the translucent detail panel (read as a stray empty box
  next to the element name) — hover highlight is suppressed while the card
  is up.
- New debug hook `SW_PAUSE=1` (menu.gd) opens the pause menu at boot for
  screenshots, same pattern as the other SW_ hooks.
- Nothing moved or animated: static sizes/positions only. Dialog UI
  (dialog_scene/crew_dialogs) untouched.

## 14/07/2026 — v1.49: doorways that look like doorways + interior beauty pass

- **The "ugly-ass room connectors" are dead — the passage is now an
  ABSENCE, not an object.** Third redesign: the gold reticle sprite (v1)
  and the recessed slide-track/parked-leaves/teal-light fixture (v2) both
  read as clutter stuck on the border, so the connector no longer draws
  anything in the gap at all. The deck simply continues through the open
  edge; the only marking is a pair of tiny flush jamb caps (6x8 px, 1px
  trim accent) where a flanking wall meets the opening — the wall trim
  just terminates cleanly. Caps are skipped at fully open corners (all
  four cells built) so nothing ever floats on bare floor. A "threshold
  seam" variant (2-3px dark joint across the gap) was screenshot-compared
  at full-deck zoom and cut: the floor plating's own panel seams already
  swallow it, so the seamless variant draws the eye less. Zero motion,
  zero light strips, zero amber.
- **Wall-aware floor shading:** the old per-cell top shadow drew on every
  cell, walling off open passages. Shade now hugs only sides that ARE
  walls (north deepest, sides/south lighter), plus soft pooled shadow in
  corners where two walls meet — rooms sit IN the hull instead of floating.
- **Floor de-tiling:** each 2x2 floor quarter drifts a hair in brightness
  (deterministic hash, ±0.045) so big decks stop reading as one flat sheet.
- No gameplay changes: walkability, stations, furniture, collision and the
  depth passes are untouched.

## 14/07/2026 — v1.48: two new core rooms + walkable airlock hatch

- **MEDICAL BAY** (cell 2, beside Quarters): THREE med beds along the back
  wall at the fabricator's exact print size (dims_of box-fits med_bed to
  33x52 — the first pass drew them at raw width 50 and they towered), the
  cryo sample fridge in the corner, vitals monitor at the foot end. SOLA
  the Medic now lives here.
- **HYDROPONICS** (cell 18, beside Cargo): grow rack, hydroponic tray and
  seedling table against the back wall, terrarium dome + potted plant up
  front. MIRA the Botanist moved in. (Captain vetoed "Botany" as the label.)
- Both furnished from the CRAFT art the fabricator already prints (same
  widths as Craftables.WIDTHS, so fixed and printed twins match), with the
  usual depth rules — collision on the base, walk-behind draw on the feet
  line — and glow accents on the powered pieces. Old saves pick both rooms
  up automatically (loader always starts from DEFAULT_ROOMS).
- **The airlock HATCH is now flush floor plating** — no collision, always
  drawn UNDER the crew, walk right over it (it's a hatch, not a crate).
  Suit-up interaction unchanged.
- **Interior walk FINAL: frames4.** The captain's fourth sheet finally
  contained a real cycle per direction — 2 opposite-leg contacts + 2 pass
  poses + a still. Cycles run the classic contact → pass → opposite contact
  → pass; hand-read leg orders confirmed by the smoothest-loop optimizer
  (it beat the hand pick on the back row and was adopted there). Chroma-key
  threshold lowered so the sheet's baked feet shadows key out (the game
  draws its own). 4-beat at 6 fps, sizes uniform after the usual 2-pass
  normalisation.

## 14/07/2026 — v1.47: top-edge flicker KILLED (exclusive fullscreen) + dialog framing

- **The flickering line at the top of the screen — root-caused and fixed.**
  Frame-diffing live captures showed exactly rows 0-1 alternating between
  rgb(36,36,36) — the Windows 11 dark-mode window-chrome colour — and black.
  Godot's regular fullscreen (mode 3) keeps a 1px window border by design and
  Win11's DWM keeps repainting it. Switched to EXCLUSIVE fullscreen (mode 4):
  no border, no chrome, window is exactly 2560x1440 now. Also set stretch
  aspect to "expand" (no letterbox strips on odd-sized windows).
- **Dialog figures sunk further** (captain 20% / crew 13% below the bottom
  edge — the captain takes extra sink so his HEAD levels with the crew's) —
  waist-up framing, nobody floats, ratios read right per the captain.

## 14/07/2026 — v1.46: dialog scenes — aboard THEIR ship

- **Each first-meeting dialog now plays inside that crew member's own ship**
  (captain's INSIDE art → crew/<name>_inside.png): JUNO's engineering bay,
  MIRA's greenhouse, HALE's rugged cockpit, SOLA's medbay, VEGA's navigation
  deck. Drawn OPAQUE cover-fit and pulled darker (0.5 tint + dusk pass) so the
  figures and text stay the read — no space, no radar, no HUD bleeding through.
- **All other HUD hidden while the dialog is up** (radar/quest log/labels/
  banner) — also kills the flicker that was showing at the top of the screen.
- **Layout polish per the captain:** compact dialog box (21% height, was 34%),
  crew drawn smaller than the captain (0.84 vs 0.92 — they stand a step back)
  and both figures sunk below the bottom edge so nobody hovers; a speaker TAIL
  triangle on the box's top edge points at whoever is talking (left = you,
  right = them), jumping per line — static, no motion.

## 14/07/2026 — v1.45: interior walk regenerated from the frames2 sheet

- The captain regenerated the walk sheet (game-assets/spacewalker/frames2) with
  a proper structure: 4 walk poses + a still per direction. Extractor updated
  for the new layout (each row carries its own idle; the bottom stills row is
  redundant and skipped). Same 2-pass normalisation (helmet width + per-row
  median height): sizes came out dead-even (helmet 65-70, heights 116-123).
  Same label inversion as frames1 — the "DOWN" row is the back view, "UP" the
  visor; mapped by pixels.
- **Cut to the classic 4-beat (captain: 4 frames per row played back weird):**
  only the TWO clean opposite-leg contact poses per direction survive (right
  0+1, left 0+1, front 0+1, back 0+2 — back f1 was an odd wide stance, f3
  near-duped f2); the player interleaves the idle as the passing frame —
  step A → stand → step B → stand. 12 frames total, 10 fps.

## 14/07/2026 — v1.44: dialog figures — one size, all facing the player

- **Proportions fixed:** dialog figures were scaled by their CANVAS height, but
  each figure PNG pads its canvas differently — JUNO rendered visibly smaller
  than SOLA/MIRA. Both the captain and the crew now scale by their opaque
  CONTENT box (computed once, cached) and bottom-anchor on the art's real feet,
  so all five stand the same height. The captain matches the crew height
  exactly (was 0.96 vs 0.92 — read too big) and sinks 5% below the screen
  bottom, so he reads slightly nearer the camera without towering.
- **Facing fixed:** zoomed head-checks on all five — JUNO and VEGA gazed
  screen-right (away from the captain); both joined HALE and MIRA in the FLIP
  list. SOLA is frontal and stays unmirrored. The flip now mirrors around the
  CONTENT span, so flipped art anchors at the same right edge as unflipped.
- Screenshot-verified all 5 first-meeting dialogs (SW_DIALOG hook).

## 14/07/2026 — v1.43: CRT/scanline overlay removed

- Cut the CRT/VHS post-effect entirely — autoload, `crt_overlay.gd`, and
  `crt.gdshader` deleted (and the `SW_NO_CRT` escape hatch with them). The
  game now renders clean; the art reads sharper without the scanline veil.

## 13/07/2026 — v1.42: real interior walk animation + asset purge

- **Interior astronaut replaced wholesale** with the captain's new frame sheet
  (`tools/extract_walk_frames.gd` → assets/sprites/walk): 7 painted walk frames
  per direction (right / left / front / back) + a dedicated idle still each.
  Every frame extracted onto ONE common canvas, feet bottom-aligned and centred,
  so the cycle never jitters. NOTE the sheet's UP/DOWN row labels were
  camera-inverted for a top-down game — mapped by pixels, not labels (visor rows
  = walking down-screen, backpack rows = walking up-screen).
- `interior_player.gd` rewritten on the new set: 11 fps cycles, real left
  frames (no more mirrored right — the backpack stays on the correct side),
  idle chest-breathing kept, footstep sfx timed to footfalls. `SW_WALK` env
  hook (right/left/up/down) for screenshot verification.
- **Frame normalisation + dedup (14/07):** the AI sheet's figures drifted in
  size (back views ~10% taller, front idle bigger than its walks) and padded
  rows with near-repeat poses. Fixed in the extractor with a 2-pass normalise —
  per-frame HELMET-width equalisation (the helmet is the same size in every
  pose, so it's the true scale anchor), then per-direction median-height
  equalisation (kills the size snap on turns, keeps natural stride bob) — and
  pairwise-diff dedup (verified via `tools/analyze_walk.gd` similarity matrix).
  Frame sets now load dynamically per direction, footsteps follow the real
  cycle length.
- **Side cycles cut to the captain's 4 picks:** the sheet's side rows drew the
  same raised-leg moment three ways, which played back as hopping on one foot.
  Right/left now run a clean 4-beat — stand → knee up → stride → recover (no
  kick-behind pose at all); front/back keep their 5 distinct frames. 10 fps.
  NB the left row's kick poses sit at DIFFERENT indices than the right row's
  (left 3+4 vs right 3/4/5) — left picks are [0,2,5,6], right [0,1,2,6].
- **142 unused assets deleted** (verified by diffing every file on disk against
  all literal + dynamic `res://` references, incl. `%s`/`%d` patterns): 56
  colored category asteroids (superseded by neutral+core layers; metal_/
  nonmetal_ kept as regeneration sources), the old avatar frames (s10_01..12,
  synthesized s10_front_a/b — s10_00 kept as crew fallback), ~60 never-placed
  prop cutouts, crew _profile/_ship art (superseded by _figure/_id/_wreck),
  placeholder ship.png, generated ui/ kit, 2 icons, 5 fire particles. Obsolete
  `tools/gen_walk_frames.gd` removed. All scenes boot + reimport clean after.

## 13/07/2026 — v1.41: cut the "home" concept + helm-transition polish

- **Removed the HOME concept entirely** — a fixed station at world-origin never
  made sense when your ship *is* your home (board it with Q anywhere, park any
  field with E). Gone: the "Home X.X km" status readout, the gold compass arrow
  under the ship, the in-world mini station, the radar's home marker, and the
  redundant "Dock at home" action. The origin chunk no longer stays artificially
  clear, so fields/scrap spawn there like anywhere else (no dead start zone).
- **Renamed the innermost region** "Home Reach" → "The Reach" (flows with The
  Drift / The Belt / The Expanse). The spacewalk radar still shows your parked
  ship as a square blip — that's your ride home, kept.
- **Helm-transition fix:** taking the helm mid-mining used to let you watch the
  elements pop out during the fade. Now the field (rocks + pickups) is hidden
  the instant you press F, before the black rolls in — a clean cut.

## 13/07/2026 — v1.40: spacewalk element labels (drop ring, white name always)

- **No ring:** removed the colour circle around spacewalk elements entirely —
  the icon stands on its own now.
- **No per-element text tint:** the element name is no longer coloured by its
  chemistry/category — one consistent readable style.
- **Name ALWAYS on, white + sharp black outline:** every element node now shows
  `<symbol> · <name>` (e.g. "O · Oxygen", "Si · Silicon") permanently — not just
  while mining — in small white text (size 9) with an 8-way black shadow so it
  reads crisply over any rock. Flight-mode zone colours (core tint) are untouched.

## 13/07/2026 — v1.39: spacewalk & flight polish (5 captain asks) + fixes

- **Ship shadow on asteroids (flight):** a rock the hull passes over gets
  darkened (sprite redrawn black, alpha by overlap) — the hull draws on top,
  so it reads as a shadow peeking from under the ship. Asteroid-only.
- **Reach zone (spacewalk):** two discreet gold rings, both centred on the
  ship (the zone centre) — no web, no off-centre arc. Just enough to read range.
- **Astronaut animation:** removed the thin-profile flip (the "coin-flip");
  clean instant facing now, plus a smooth idle CROSSFADE between the two float
  frames (sine-blended, per the game-juice sine-animation idea), a gentle
  drift-lean, and an idle bob. NOTE: genuinely new painted frames still need
  art — this is the most that the existing 8 frames + procedural motion can do.
- **"F — Take the helm":** fly straight to the outer view from a spacewalk with
  a 0.6s fade, no trip inside. Prompt on any real spacewalk.
- **Tether:** subtle thin dashed line over a solid under-line (discreet, opens
  slightly as it stretches). Bungee give cut 90→46px — a slight elastic nudge
  at the end of the line, not a bounce.
- **Element size — hard fix:** spacewalk asteroids keep their element icons
  (distinct art from the outside rocks, by design) but are now sized purely
  from radius with a hard cap (ICON_MAX 30 → longest ≤60px), so a node is never
  huge regardless of region or the icon's own canvas.
- **Full zone SEED SYSTEM — one field, two views, per-element colour:**
  `GameState.dive_field` is the single generator (one seed per zone). Flight
  draws rocks at their REAL positions (no compression) — a rock's spot outside
  is exactly where it sits inside. Mining flags `GameState.mined[key]`, checked
  LIVE at draw so a mined rock vanishes from the outside view too. Graphics
  differ by design (element pixel-icon inside, neutral tinted rock outside) but
  the COLOUR is ONE map covering ALL elements: `Elements.asteroid_color` (the
  element's own icon colour via `glow_for`, with a value floor so dark elements
  like Carbon still read). Outside rock = GRAY body + only the CORE gem tinted
  by that colour (16 body/core layer pairs from `tools/gen_rock_layers.gd`);
  inside = element icon + a thin ring in the same colour, so oxygen reads cyan
  both sides, sulphur yellow, etc — every element distinct, no C/S both green.
- **Spacewalk element look:** thin (1px) crisp ring inset just inside the
  element (not wrapping it); icons hard-capped small (ICON_MAX 26 → ≤52px) so a
  node never dwarfs the crew; slight idle pulse.
- Also: CRT overlay warning fixed (sizes from anchors).

## 13/07/2026 — v1.38: asteroid ZONE art — rocks preview their contents

- The mining zones you see in flight were plain gray code circles. Now they
  use the captain's asteroid sheet (`tools/extract_asteroids.gd` → 72 rocks,
  9 element categories × 8 shape variants). Each rock in a zone is assigned a
  DETERMINISTIC vein element (rich rocks skew to crystal fractions), and the
  sprite is picked by that element's CATEGORY — so the core colour previews
  the contents: cyan gas, orange alkali, gold precious, steel metal, yellow
  alkaline, violet metalloid, green nonmetal, magenta rare, red actinide.
  A field's colour mix tells you what's inside before you park.
- Extraction: global border flood-fill on a GREEN-DOMINANCE test (not just
  bg-distance), so the bright green halos around each rock are removed while
  enclosed cores — including the green nonmetal row — survive because gray
  rock walls them off from the flood. Region tint washes the body slightly.
- Debug: SW_FIELD=1 jumps the ship to the nearest zone for screenshots.

## 13/07/2026 — v1.37: CRT actually renders + real VHS, wreck loot rework

- **The CRT overlay never rendered.** Same 0×0-Control family as the
  unclickable modals: the ColorRect got its anchors preset BEFORE entering
  the tree and stayed sizeless — the shader pass drew nothing, ever since
  v1.25 shipped. Now the preset is applied after add_child, the size is
  pinned explicitly, and viewport resizes re-fit it. (PrintWindow screenshots
  can't capture the screen-texture pass, which is how it hid from every
  verification shot — the captain caught it live.)
- **Stronger scanlines + real VHS** (captain: "stronger, and vhs"): scan
  strength 0.07 → 0.18, plus RGB phosphor mask triads, VHS chroma bleed
  (color smears sideways, luma stays sharp), edge color fringe 0.9, static
  tape grain. Every term is a pure function of pixel position — zero motion,
  as always. Techniques are the classic public-domain CRT recipes; the
  implementation is ours (no third-party license).
- **Wreck loot rework (captain's design):** only rare hulls always carry a
  blueprint; common hulls have a 55% chance (deterministic per wreck — no
  reroll by reloading). Recipe-less hulls pay out extra scrap + an extra
  tech find ("data banks fried — but the cargo hold was intact"). And the
  tech elements (Li / Nd / P) are now SALVAGE-EXCLUSIVE — pulled back out of
  Vesna's tiers; wreck-hunting is their only source (gases still scoop).

## 13/07/2026 — v1.36: the captain in dialogs, crew art aboard, print-in FX, size pass 2

- **The PILOT is in the conversation.** The captain's new back-view figure
  (conditioned by tools/prep_player.gd — border flood key, crop, feather) now
  stands on the LEFT of every meeting, gesturing toward the survivor; the
  ACTIVE speaker draws bright while the listener dims. HALE and MIRA's art
  faced away from the conversation — mirrored via transform (`FLIP` const;
  negative-size rects don't reposition in Godot, learned the hard way).
- **Crew art aboard the ship**: rescued crewmates now render with their OWN
  `_token` sprites (crew-scale ~40px, name overhead, walk-flip kept) instead
  of the generic tinted kit astronaut. Their wrecked ship at the rescue site
  shrank 240 → 160px — their craft, not a mothership.
- **Fabricator PRINT-IN effect** (captain's ask): a placed object materializes
  BOTTOM-UP over 0.9s — only the printed portion exists, glowing fab-blue and
  cooling to true color, with a bright print line at the build edge. And
  printing no longer bounces back to the catalogue: you STAY in placement to
  print more; Esc returns to the modal. The whole grid (all 4 rows × 6 slots)
  stays visible while building, targeted row brightest.
- **Size pass 2 (captain's live feedback):** composite-set art (café table
  with its chairs, dining table, booths, poker/foosball) got bigger widths so
  the table itself reads right. Collision is now a BASE box (bottom ~55% of
  the sprite) — deep enough to stop walking through, shallow enough that two
  water coolers no longer wall off a corridor. **Anti-overlap rule:** a tall
  piece (>38px) refuses column-overlapping neighbors one depth-row away —
  no more tables jammed halfway inside beds; placement-only (saves load
  relaxed so nobody's rooms get purged). Same-cell pieces draw sorted by
  depth row. All rules sim-verified (FITS3 PASS).
- **Multi-keycap prompts**: KeyPrompt now renders every `KEY  text` segment
  (split on ·) as a real keycap — "E Talk · I check ID" shows two keycaps
  (the I was plain text before, captain caught it).

## 13/07/2026 — v1.35: CREW MEETINGS — board their wreck, talk, check IDs

The rescue moment is now a scene, not a pickup (captain's spec):
- **You find their BROKEN SHIP, not a beacon.** The rescue site in flight mode
  renders the character's own wrecked hull (crew `_wreck` art, strobe still
  blinking, "HALE'S SHIP — NO POWER"). `E` boards it.
- **First-meeting dialog** (`scripts/dialog_scene.gd` + `scripts/crew_dialogs.gd`):
  full-screen conversation — the character's large figure on the RIGHT, waist-up
  above the dialog panel, typewriter text, Space/click advances, Esc skips.
  9 exchanges per character, written in-voice (HALE insults you mid-rescue,
  JUNO is already fixing things, MIRA apologizes about her ferns, SOLA trails
  off, VEGA is perfectly literal) — one HELIOS reference each, no pep talks.
- **Fade to black → aboard.** The dialog ends under a solid-black fade, the
  rescue applies (perk + save), and you fade into the ship interior where they
  now stand at their spot.
- **Talk to them aboard**: walking up to a rescued crewmate offers
  `E Talk · I check ID`. E says a random personality quote (5 per character);
  I opens the **CREW ID modal** (`scripts/id_modal.gd`) — their actual ID card
  art, "CREW REGISTRY — HELIOS EXILE MANIFEST". The old spacewalk drifting-
  survivor pickup is retired (spacewalking the site points you to the helm).
- Debug: SW_DIALOG=<NAME> (flight) opens the meeting, SW_ID=<NAME> (interior)
  opens the ID. All five characters' dialog data + all 30 crew assets verified
  by sim. The captain's new player-back figure will slot into the dialog's
  left side when it lands in the assets folder.

## 13/07/2026 — v1.34: furniture scale normalized + 4-row placement grid

Captain's audit after live play: "the bed and the sink are extremely huge…
I can go far behind the objects."
- **Root cause:** furniture drew at slot-span width with height from source
  aspect — portrait art (top-down beds) blew up to ~90px against a 34px crew,
  while 1-slot items shrank to ~20px. **Fix:** every craftable now has a
  hand-tuned display width (`Craftables.WIDTHS`, same scale as the core
  rooms' ROOM_PROPS — kit nightstand 34, bunk 62) plus a universal 52px
  height cap (box-fit). Slots are now only the placement footprint.
- **Walking behind objects:** collision was a thin 14px strip at the base
  line, so the crew could slide in behind a bed and vanish. Furniture now
  gets the SAME deep collision box as the fixed props (full sprite box,
  ~12% shrink).
- **Placement grid 2 → 4 depth rows** (floor lines at 58/86/114/142 px),
  so player rooms can stagger furniture organically like the core rooms.
  Placement overlay redrawn: faint floor lines, slots only on the targeted
  row. Old saves' row 0/1 furniture stays valid (rows shift up slightly).
- "R rename" under the room name is now a real keycap (KeyPrompt gained a
  from_top anchor), replacing the plain-text suffix.

## 13/07/2026 — v1.33: full-project audit — recipe economy, recycle, input fixes

Three parallel audits (crafting/save logic, UI/input, gameplay/assets) swept the
whole project after the crafting drop. Verified clean: save round-trips, wreck
re-salvage/reroll exploits, placement boundary math, crew-freeze pairs, pause
interplay, all 147 asset preloads. What they caught got fixed:

- **THE BIG ONE — 39 recipes were mathematically uncraftable.** Costs used
  honest chemistry, but the sources didn't exist: raw solar ratios put Xe at
  1 unit per ~6.5 BILLION nebula scoops (~4 million hours), Kr ~500k hours,
  and Li/Nd/P/W had no source below the rep-12 trader wildcard — including six
  STARTER recipes (battery bank's lithium, tool wall's tungsten…). Fixes, with
  the sacred 83-element abundance TABLE untouched:
  - **Gas scooping drop-table compression** (4th root, same philosophy as the
	crystal 10× heavy-boost): H/He still dominate (~86% of scoops), but now
	N ≈ 0.7 min/unit, Ne ≈ 0.6, Ar ≈ 1.7, and even Kr/Xe land in 11-18 min of
	patient scooping instead of never.
  - **Wreck TECH SALVAGE**: every stripped hull now also yields 1-2 units from
	what ships are MADE of — Li batteries, Nd motor magnets, W tooling, P food
	stores, Ne signage, Ar welding gas (doubled on rare hulls). This is the
	primary faucet for the strays.
  - **Trader tiers**: P joins rep-3 stock; Li and Nd join rep-6.
- **Recycling was dead code** — `remove_furniture()` existed but nothing called
  it. Now: in placement mode, hovering a printed piece glows warm and
  RIGHT-CLICK un-prints it with a full material refund (hint line updates).
- **Wall pieces enforced**: `back: true` items (tool wall, wall shelf, star
  chart, banner) now refuse the front row and their ghost snaps to the back
  wall — previously the flag was decorative and a shelf could float mid-room.
- **Input hardening**: the inventory can no longer open OVER the fabricator
  modal/placement/rename box (host-scene veto), station/rename keys are dead
  under the open inventory, ONE Esc now cancels the rename box even while the
  LineEdit has focus, stale hover no longer carries across fabricator tab
  switches, and printing by mouse needs a DOUBLE-click (single click only
  selects — no more surprise prints after a tab switch).
- SW_RICH now also applies to brand-new games (was: only boot + load); trash
  pickups commit to the save immediately, matching wreck salvage.
- Housekeeping: orphan `.uid` files of deleted temp tools removed. Known lows,
  deliberately left: chargen ignores numpad-Enter, pause menu is mouse-first
  (no initial button focus), SW_RICH writes 4000s into any slot you save on
  (documented; it's a dev cheat).

## 13/07/2026 — v1.32: FIX — mouse clicks were dead in modals + 126 craftables

- **THE BUG (captain report: "can't click tabs or objects"):** every code-built
  full-screen Control used `set_anchors_preset(PRESET_FULL_RECT)` — which
  preserves the control's CURRENT rect via offsets. Added before the parent laid
  out, that rect was 0×0 and stayed 0×0 forever. `_draw()` is unclipped, so the
  modals RENDERED full-screen while being invisible to mouse hit-testing —
  `_gui_input` never fired. The fabricator modal was unclickable; the upgrade
  modal had the same latent bug since it shipped. Proven with an injected Win32
  click + console print (`size=(0,0)`), fixed with
  `set_anchors_and_offsets_preset` and swept across ALL scripts (10 files).
  Verified end-to-end: injected click on GALLEY/LOUNGE switches tabs on screen.
- **Catalogue grown 108 → 126** (wave 3, contact-sheet-verified picks): padded
  bench, side table, wall shelf, luggage · brew urn, stand mixer, rice cooker,
  serving cart · lab console, vitals monitor, culture cylinder, herb cabinet ·
  gear press, lathe, gantry crane, fuel canister · star chart, ship banner.
  Tabs now 24/24/24/24/30 — LOUNGE's 5 rows still fit the 720p panel.
- **Hover feedback** on tabs and cards so the mouse path is obvious; grid is
  6 columns.
- **SW_RICH=1 (TESTING ONLY):** 4000 of every element + 4000 banked ore, also
  re-applied after loading a save. One env var, three code spots, each marked
  `TESTING ONLY — DELETE BEFORE SHIPPING`; grep SW_RICH to strip for release.
  Note: saving while rich writes the 4000s into that save slot — use a
  throwaway slot.
- Starter recipes also seed in GameState._ready, so debug scene launches and
  every legacy path start with the 26 essentials instead of a locked catalogue.

## 12/07/2026 — v1.31: CRAFTING — fabricator, room furniture, derelict wrecks

- **The fabricator.** A 3D-printer station (craft-sheet art, its graphic is
  never itself craftable) now hums in the Cargo Hold. `E` opens a catalogue
  modal: 5 category tabs (QUARTERS / GALLEY / SCIENCE / ENGINEERING / LOUNGE),
  a 6-column card grid, hover + click everywhere (tabs, cards, print button;
  click the backdrop to close), keyboard too (1-5 tabs, arrows browse, E print).
  Locked items show ghosted with "no recipe yet" — you can always see what's
  left to find.
- **108 craftables, curated from the captain's craft sheets** (extracted by the
  new `tools/extract_craft.gd`: strict-distance chroma key so plant foliage
  survives, connected components, contact-sheet verification of every pick).
  Costs are real chemistry in mined/scooped/traded elements: Nd magnets in the
  body scanner and laser cutter, Ne in the jukebox, Ar in the plasma fireplace,
  Li in battery banks, W crucibles in the smelter, Au on the gold bust, N+P
  fertilizer under everything green, U in the reactor core. 26 starter recipes;
  the other 82 are lost blueprints.
- **Placement: rooms YOU built only** (same rule as renaming — core rooms keep
  their fixed stations). Each built room becomes a 6×2 floor grid; the chosen
  object follows the mouse, snaps to slots, green/red ghost, click/E prints
  (elements are spent at that moment, modal reopens for the next print).
  Furniture draws through the same feet-line depth passes as the fixed props
  (front row covers the crew, rugs lie flat under everything) and lands in the
  collision map, so you walk around your sofa, not through it. Placed pieces
  persist in the save (validated on load — corrupt/overlapping entries are
  dropped) and can be recycled for a full refund.
- **Derelict wrecks (salvage-sheet art, 20 hulls).** Rare whole ships now
  drift in flight mode — freighters, gunships, and rarer medical ships and
  dead stations (dome, torus, C-ring) with a warm gold salvage ring. Fly close
  to strip one: a multi-metal scrap haul (doubled on rare hulls) plus the real
  prize — a lost recipe, revealed by a "RECIPE RECOVERED" banner with the item's
  art. Rare hulls draw from the fancy end of the catalogue. Wreck state lives in
  `salvage_taken`, so a stripped hull stays stripped.
- Save format v6 (`recipes`, `furniture`); starter recipes seed on every path
  into the game, including legacy saves. Debug hooks: `SW_FAB=1` (catalogue),
  `SW_FAB=<id>` (placement in hand), `SW_FURN=1` (pre-furnished room),
  `SW_WRECK=1` (derelict + banner). Round-trip sim passed: costs deduct,
  overlap/out-of-bounds/locked refused, refunds exact, unlocks unique,
  corrupted saves sanitized.

## 12/07/2026 — v1.30: FIX — dive-site elements re-rolled on every visit (exploit)

- **The bug:** the field LAYOUT was deterministic per sector (seeded rng +
  `GameState.mined` keeps mined rocks gone), but each rock's ELEMENT was picked
  in `asteroid._ready()` with the global RNG — so leaving and re-entering a dive
  site re-rolled every remaining rock's vein. Exploit: hop in/out until gold or
  uranium spawns next to you.
- **The fix:** veins are now deterministic per rock. `Elements._sample` (and the
  three `sample_*_element` wrappers) accept an optional pre-drawn `roll`;
  asteroid seeds it from `hash("vein:" + mine_key)`. Same rock, same element,
  forever. Wreck salvage / gas scooping keep true randomness (param defaults).
  The abundance TABLE is untouched — same drop odds, just fixed per rock.
- **Proven** by headless sim: identical veins across two simulated visits with
  the global RNG scrambled between them; healthy variety across rocks (PASS).
- Known lesser quirk (bounded, not loopable): upgrading the TETHER changes the
  layout range, which can remap rock indices once per upgrade level (max 5 per
  playthrough, costs resources). Not the reported exploit; left as-is for now.

## 12/07/2026 — v1.29: mining reads as WELDING

- **Laser cut = weld spatter** (captain's call). `Vfx.spark_hit` reworked: a
  white-hot core flash at the contact point, a tight fan of tiny fast pinpricks
  spraying BACK off the surface (player passes the beam direction), dying
  through white → yellow → orange-red ember (`_weld_ramp`), plus a very subtle
  element-tinted afterglow so you still read what you're cutting. Throttle
  tightened to ~25 bursts/s for a continuous crackle. `_emit` gained optional
  direction / spread / custom-ramp args (default behaviour unchanged).
  Verified on-screen — reads as welding at gameplay zoom.

## 12/07/2026 — v1.28: VFX/sound corrections (captain feedback)

- **Sound pulled back out** — the Kenney audio felt wrong; `sfx.gd` is a no-op
  stub again (API intact, call sites resolve, nothing plays) and `assets/audio/`
  is deleted. We'll do sound properly later.
- **Particles retuned** — the real problem was scale: the textures are 512px, so
  CPUParticles2D was drawing 90–230px flat blobs. Now sized to ~10–30px, drawn
  ADDITIVELY (glowing, not flat), with round star/glow textures so they radiate
  cleanly in any direction (CPUParticles2D can't orient to velocity). Shatter =
  flare flash + star shards + glow puff; sparkle = gold star glints. Verified.
- **Flight thrusters reverted** to the clean procedural nozzle flames (the flame
  sprite looked stretched). Ship stays at the smaller SHIP_SCALE 0.46.

## 12/07/2026 — v1.27: launch-prep audit + smaller ship w/ flame thrusters

- **Pre-launch audit** (3 parallel passes: assets, new-code logic, gameplay/save).
  Result: no broken asset refs, no gameplay/economy/save regressions, win path
  still reachable. Fixes applied:
  - **Sound bug (HIGH):** `sfx.gd` set `loop=true` on a shared cached OGG
	(`forceField_003` = both the klaxon loop AND the "upgrade" one-shot), so
	every upgrade/craft/install cue droned forever on a pool voice. Fixed —
	loop players now `duplicate()` the stream, leaving the pooled copy un-looped.
  - Vfx now receives `global_position` (was local) from asteroid/pickup —
	correct even if the world node ever gets a transform.
  - Rename hint now checks the same (feet) cell `_open_rename` edits — no more
	disagreement near a cell boundary.
  - Core rooms always show their fixed name (a legacy save can't pin a stuck
	custom name on them anymore).
  - Inventory name-plate: dropped the dead ~2% "capacity" sliver (cap is 9999);
	now a faint full-width element tint = "you're holding some".
- **Asset cleanup:** removed 7 unused particle textures + never-referenced prop
  sheets s1/s9 (34 files, ~1.9 MB). Kept crew sprites (dialog feature pending)
  and `ship_hd.png` (still the flight/dock hull). Note for export: `tools/` +
  `tools/ship_source.png` will bundle unless excluded by an export filter.
- **Flight ship smaller** (`SHIP_SCALE` 0.6 → 0.46). Its thruster block already
  scales with SHIP_SCALE, so nozzle placement is preserved automatically. The
  twin **main drives now fire Kenney flame sprites** (`flame_06`) from the rear
  nozzles, aimed aft and flickering with throttle; the reverse/turn RCS stay as
  the cold-gas blue procedural jets.

## 12/07/2026 — v1.26: sound & particle VFX (Kenney CC0)

- **Sound is back** — `scripts/sfx.gd` restored from stub, now backed by Kenney's
  CC0 "Sci-Fi Sounds" (public domain, no attribution). 17 curated oggs in
  `assets/audio/`. A 10-player round-robin pool handles one-shots (bank, clack,
  deny, hiss, o2low, pickup, radio, shatter ×5 variants, step, thud, upgrade);
  three dedicated looping players hold the mining/thrust/klaxon beds.
  Every existing `Sfx.play/laser_on/thrust_on/klaxon_on` call site now sounds —
  no call sites changed.
- **Mining laser = a subtle arc-weld** — `Sfx._make_weld()` synthesizes the beam
  loop from scratch (low mains buzz + flickering crackle band, crossfaded for a
  seamless loop). No sample, no license, tuned quiet (-18 dB).
- **Particle VFX** — Kenney's CC0 Particle Pack (curated set in
  `assets/particles/`) drives a new `Vfx` autoload (`scripts/vfx.gd`) of one-shot
  CPUParticles2D bursts, tinted to each element's real art colour:
  - `spark_hit` — sparks flying off the laser cut (throttled ~20/s in player.gd)
  - `shatter` — the money shot when a rock breaks: flare flash + shard spray +
	embers + glow puff (asteroid.gd `_shatter`)
  - `sparkle` — bright pop when you collect a chunk (pickup.gd)
  - `flash` — reusable radial burst for installs / jumps / discoveries
  All space-correct (zero gravity), auto-freed after their lifetime.
- Both packs are CC0 (LICENSE files kept alongside the assets). Assets imported;
  scenes parse and run clean.

## 12/07/2026 — v1.25: intro art, keycaps, scanlines, rename gate, smaller UI

- **Intro crawl now has cinematic backdrops.** Five captain-provided renders
  (`assets/sprites/intro/intro_1..5.png`) map to the five pages (mercy · the
  verdict · the sealing · rebuild · the beacons). `intro.gd` draws each cover-fit
  with a slow Ken-Burns drift and a per-page fade-in, a navy scrim + text shadow
  for legibility; the old starfield/ship sprite are gone.
- **Every key prompt is now a keyboard KEYCAP.** New `UITheme.draw_key` /
  `draw_hints`, a reusable `HintBar` (bottom control strip) and `KeyPrompt`
  (in-world "press KEY" prompt that renders a leading key token as a cap).
  Converted: the three context hint bars, the intro hints, the upgrade-modal
  button + footer, the inventory footers, and all in-world prompts (dock / enter
  ship / expand / station actions — reworded to lead with their key).
- **New `Keymap` registry (scripts/keymap.gd)** — single source of truth for
  every binding (physical key + placeholder controller glyph + context). Hint
  bars read from it, so prompts can't drift from the real controls. This is where
  gamepad support maps in later.
- **Rooms: only ones you built are renameable.** `GameState.can_rename_room()`
  gates the six core rooms (DEFAULT_ROOMS) out; the "R rename" hint only shows,
  and R only opens the box, for expanded rooms.
- **Subtle CRT scanlines** (`assets/shaders/crt.gdshader` + `CRTOverlay`
  autoload) — one full-screen GPU pass, STATIC (no warp/motion, motion-sickness
  safe). Scanlines only per captain (vignette / aberration / grain uniforms are
  present but default 0). Toggle off with SW_NO_CRT.
- **Smaller UI text** — inventory headers, symbols, discovery gauge and footers
  reduced; hint bars now compact keycaps. (Runs at the vsync 60 fps cap; the CRT
  is effectively free.)

- **Audited all 103 element icons against the 9 source sheets — no atomic-number
  offset existed** (every icon sits under its correct label, including the
  irregular last sheet where Lawrencium's centre falls in column 2's strip).
- **Real bug #1 — green chroma-key ate green-COLOURED elements.** The old
  `_is_green` removed any green-dominant pixel, gutting Cl(17), Tc(43), Nd(60),
  Dy(66), Po(84), Ra(88) and degrading F(9), Ac(89), Pa(91) and quest-critical
  U(92). Replaced with the border flood-fill keyer from `prep_crew.gd`: only the
  flat screen-green connected to the cell edge is removed, so each element's own
  green (a different hue/brightness) survives. All ten restored, verified over
  magenta with clean edges.
- **Real bug #2 — horizontal neighbour bleed.** The full column-width crop
  dragged in a neighbour's art when it crossed the column line (e.g. z102
  Nobelium carried a purple Mendelevium fragment). Added `_keep_central`: after
  keying, keep only the horizontal blob covering the cell centre. z102 and
  friends now show a single element.
- Full 103-icon contact-sheet sweep: every icon complete, correctly keyed, and
  matching its label.

## 12/07/2026 — v1.24: icon crop/overflow fix + inventory names + UI sweep

- **Icons were cropped when they overflowed their grid column.** On the
  irregular last sheet Lawrencium (103) sits between columns 2–3, so the rigid
  column-strip crop sliced its right half off into a phantom "z104" and threw
  it away; other off-grid icons risked the same. Rewrote the extractor's crop:
  find the densest content column inside the cell (the icon core) and GROW left
  and right across the full sheet width, stopping at the green gap to the
  neighbours. Captures each icon whole, with no neighbour bleed. Re-verified all
  103 over magenta — z101/102/103 now complete (Lawrencium keeps its full aura,
  Nobelium has no purple Mendelevium bleed). Replaced the earlier `_keep_central`
  band-aid, and the content test now treats green-coloured elements as content
  (not background) so their blobs detect cleanly too.
- **Inventory element names were truncated** ("Protactiniu", "Mendeleviu") —
  the name sat in a ~50px slot beside the symbol. Redesigned the card: icon
  top-aligned, and a full-width bottom name-plate (which doubles as the capacity
  bar) so every name renders whole and centred. Verified Molybdenum, Phosphorus,
  Praseodymium, Technetium etc. all fit.
- **Inventory footer overlapped the last card row** — re-anchored it just below
  the grid instead of at the panel's bottom edge.
- **UI overflow sweep** (screenshotted the real game window — fixed the shoot
  helper to target the "Spacewalker" window, not a stray Project Manager):
  inventory, element trivia card, flight HUD (status/radar/quest log), spacewalk
  HUD (vitals/ore-bag/gear), upgrade modal, rename box and ship interior all
  render clean. Widened Vesna's trader panel (188→224) as a precaution so long
  element names can't collide with the price column.

## 12/07/2026 — v1.22: crew art conditioned & catalogued

- **All five rescuable crew now have engine-ready art** at
  `res://assets/sprites/crew/<name>_<type>.png` (30 files: profile, ship,
  wreck, token, id, figure × HALE/JUNO/MIRA/SOLA/VEGA).
- **New tool `tools/prep_crew.gd`.** Green-keys the four transparent-bg types
  via BORDER flood-fill (so it never eats MIRA's greenhouse windows, her green
  suit, or SOLA's medic cross — only bg green touching the frame edge goes),
  plus a tight pure-green pass for enclosed pockets between limbs, de-spill and
  alpha-feathered fringe. Profiles (painted bg) copy through untouched. CREW
  IDs get their own black-key: border flood-fill knocks out the near-black
  background with a luminance alpha-ramp (silver frame halts it, notched
  corners go transparent, photo/text preserved, no dark halo). Each type is
  autocropped then padded to one shared canvas across all five, so they drop in
  at identical proportions/anchors. Verified over grey, magenta and
  checkerboard — no green fringe and no leftover black survive.
- Character bible (look, ID data, personalities) recorded to memory for the
  upcoming dialog/rescue work. Dialog portraits (`_figure`) anchor bottom-right,
  dialog box over the lower half. No gameplay wiring yet — assets only.

## 12/07/2026 — v1.21: intro crawl rewrite

- **Opening narrative polish (scripts/intro.gd).** Tightened the five-page
  intro on captain feedback, keeping the concept and the "It simply
  subtracted us" beat intact:
  - Page 2 no longer names or ages the pilot (you survived — you didn't die,
	so the crawl shouldn't eulogise you). It now opens on *what you were
	doing* and *why you were off-world*: "working the ore rigs… high orbit,
	months from the nearest dirt" — which is also why HELIOS's purge missed
	you. Removed the now-unused `pilot_name()`/age lookup.
  - Page 4's rally-cry ending ("Gather enough, and the drive will carry you
	past the wall") replaced with flat, grim statement of fact: "Enough of
	it, and the drive wakes. Nothing else crosses the wall."
  - Page 5: Haven is now a *deliberate* blind spot — "a blind spot we wrote
	into its code on purpose… in case we ever had to hide from it" — so it
	reads as humanity's hedged bet against its own creation, paying off the
	"They called it mercy" opening. Dropped the on-the-nose "Go and find
	them" command; ends on the theme line "No one crosses this alone."

## 12/07/2026 — v1.20: economy de-RNG, quest prose, rename discoverable

- **Trader economy fix (game_state.roll_trader).** U and Th are the ONLY
  source of the two fissiles the final drive part needs. They're now
  GUARANTEED in Vesna's stock every shift once rep ≥ 10 (until you own each),
  so completion can't stall on trader RNG (validated: 20/20 shifts, stock
  still capped at the 3 buy-slots). New "master broker" at rep ≥ 12: her pool
  opens to ALL 83 abundance elements, so the rare ones become buyable — the
  collection endgame no longer depends on a lucky crystal roll (validated:
  83/83 offered within 300 shifts).
- **Main-quest prose.** Each drive part gained a `flavor` line ("The drive's
  veins. Until they run, no fire can move through her.") shown in the quest
  log under the part name, and the install `log` lines were rewritten with
  more warmth and weight.
- **Room rename discoverable + clearer.** The bare text field is now a titled
  RENAME ROOM panel (pre-filled name, Enter/Esc hints), and the top room label
  shows "R  rename" whenever you're standing in a built room.

Estimates (model, not playtested): a normal main-story completion is ~8–12 h,
about half of it the reputation/trade endgame for the precious + fissile
metals. Full 103-element collection is 100% achievable (nothing is
uncollectible now) but a long completionist grind — the 20 wreck-only
synthetics (~6% drop) are the main time sink.

## 12/07/2026 — v1.19: full 103-element set, trivia cards, tighter UI

- **All 103 elements, collectible.** The inventory now shows the complete
  periodic run 1–103 (`Elements.full_table()` + `NONABUNDANT` for the 20 with
  no natural abundance). Every card shows its atomic number, so the ordering
  is obvious and there are no gaps. The 83 real-abundance elements are
  craftable as before; the 20 synthetics are a "find them all" side-hunt —
  collectible only, dropped rarely (6%) from wreck salvage (reactor-core
  leftovers), never used in crafting/quest/gear. Discovery gauge is now X/103.
- **Click-for-trivia (`element_facts.gd` + inventory detail card).** Clicking
  any element opens a styled card: big icon over a tinted disc, symbol/name,
  identity line (Z · category/synthetic · abundance), and a real one-line fact
  for all 103 elements. Accent matches the element's art colour (`glow_for`).
- **Elements sourcing** made robust: `icon_for_z()`, symbol lookup now covers
  all 103 so name/hue work for synthetics; `is_craftable()`/`synthetic_symbols()`.
- **Smaller UI (round 2).** `UI_SCALE` 0.82→0.70; upgrade modal and inventory
  trimmed further with smaller fonts; inventory scrollbar moved into a gutter
  right of the grid (was overlapping the last column); quest-log offsets retuned.
- **Gear tile "SUIT" → "BAG"** so the ore-bag upgrade reads clearly.
- **Element sizing in space:** intact node bigger (`ICON_FILL` 1.45→1.6, spawn
  radius 17–34) and broken fragments much smaller (`CHUNK_PX` 22→13) — a clear
  whole-rock → small-pieces contrast.
- **Audit (headless):** all 103 have a real source; win path still completes;
  no synthetic gates progress; every required element is craftable + farmable.

Note: the game has no hard-coded calendar year (only the pilot's chosen age).
The crew-card DOBs (2149–2159) fit a setting around ~2185 (Hale ~36 veteran,
others 25–29). Canonical year + full crew profiles pending the captain's design.

## 12/07/2026 — v1.18: ore/element split, gear modal, analytical quest log

A progression + UI pass. **Ore and elements are now two different things.**

- **Economy split (game_state.gd, pickup.gd, vitals_panel.gd).** Breaking a
  rock drops TWO things: an ELEMENT sample of its vein (your collection —
  UNLIMITED on the suit) and bulk ORE (the currency). The ORE BAG is capped
  (`ore_max()` = 25 + 15/suit level) and is now the return-home tension:
  when it's full you go bank, but samples keep flowing. `add_carried()`
  returns whether ore overflowed; the magnet always pulls (samples always
  collectible). Vitals shows a dedicated ORE BAG meter + bag glyph and a
  separate SAMPLES count.
- **Gear upgrades reworked (game_state.gd).** Each gear upgrades 5× (was
  uncapped). Every level costs sensible ELEMENTS that fit the gear —
  O2←O/N/He + structure, Laser←Si/Cu/Ag/Au/Pt, Line←Al/Ti/C, Ore Bag←
  Fe/Al/Ti/Ni — plus escalating ore. Late tiers need precious metals and
  tungsten (trader/wrecks), so it's steep but not grindable from plain rock.
  `GEAR_REQ` table + `upgrade_req/can_upgrade/gear_maxed`.
- **Upgrade modal (upgrade_modal.gd).** Pressing E at a gear station opens a
  styled modal: gear icon, level pips (n › n+1), the stat it buys, and each
  requirement as an element ICON with have/need + ✔/✘ (green/red rows), the
  ore row, and an INSTALL button that lights only when affordable. Freezes
  the crew while open; Esc/click-out closes.
- **Quest log redesigned (quest_log.gd).** Analytical now: overall campaign
  %, JUMP DRIVE part X/5 with a per-material breakdown (colour dot · symbol ·
  mini progress bar · have/need) and a completion bar, then FIND THE
  SCATTERED with filled survivor pips and the next beacon.
- **Rooms.** Rename any room — press R inside it, type a name (saved per
  cell, `room_names` + `rename_room()`). And expansion is reachable from
  EVERY built-room edge that faces bare hull (was one prompt per bare cell,
  which left some corners unreachable) — a `+` bay now sits inside each
  bordering room.

Verified: headless logic test (ore caps @25 while samples hit 40; laser L1
spends Si8/Cu6/ore15 → 70→95; caps at Lv5; rename + revert). Screenshots of
the modal, the new vitals, the quest log and the interior all render clean.

- **Smaller UI (all parts).** `UITheme.UI_SCALE` (0.82) + `UITheme.shrink()`
  scales each corner-anchored HUD panel about its screen-edge corner (stays
  flush): vitals, radar, quest log, gear rack — in the EVA, flight and
  interior HUDs. Overlay panels trimmed by constant (upgrade modal 560→470,
  inventory 1180×664→1010×576 with tighter cards; names no longer truncate).
- **Completability audit (headless sim).** Drove the whole win path in code:
  install all 5 drive parts, rescue one survivor after each (JUNO→VEGA), reach
  `game_complete` + 5/5 rescued = "set course". Confirmed every required
  element has a farmable source (rock/crystal mining, wreck salvage, Vesna's
  tiers, or H/He gas-scooping), rep 10 is reachable via contracts, and the
  trader stocks U/Th at rep 10. **Caught + fixed a real blocker:** the O2-tank
  upgrade required Nitrogen, which only scoops at ~0.006% — effectively
  unobtainable, making O2 Lv2+ impossible. Swapped N → Helium (7.5% of scoops,
  actually farmable). All checks now pass.

## 12/07/2026 — v1.17: real pixel-art element sprites

Replaced the procedurally-drawn molecules with the artist's dedicated
pixel-art element icons (game-assets/spacewalker/elements — nine
green-screened 4-column sheets, 103 icons, atomic number == label).

- **Extraction (tools/extract_elements.gd).** Per column strip we find
  the vertical content "blobs" and keep the tall icon, dropping the short
  text label beneath it — so NO text ends up in output. Each icon is
  green-keyed with de-spill and cropped tight, saved as
  assets/sprites/elements/z<atomic number>.png. Verified all 103 on a
  contact sheet: clean crops, no text bleed.
- **elements.gd** — `icon_for(sym)` lazily loads z<Z>.png as an
  ImageTexture and caches it (works in editor/export/headless alike).
- **In space (asteroid.gd)** — a mineable node now draws its element's
  real icon, fitted to the node diameter; the laser collision surface is
  sized to the art so the beam lands ON the chunk. Mining flash whitens
  the icon and throws sparks in the element's colour at the exact hit
  point. Fallback ore blob if an icon is ever missing.
- **Broken chunks (pickup.gd)** — a shattered piece is now a MINIATURE
  of the same element icon, so debris matches the rock it came from in
  both shape and colour.
- **Inventory (inventory_screen.gd)** — every element card shows its
  icon on the left (full colour when discovered, dimmed until then).
- **Size tuning (12/07)** — the icons filled the full 2×radius diameter
  (the old molecules only used the centre ~40%), so they looked huge.
  Dropped to `ICON_FILL` 1.45×radius, tied the laser collision to the
  ACTUAL drawn half-size (×0.9) so the beam still lands on the art, and
  trimmed spawn radii (14–30) + spacing so the field stays full. Now the
  chunks read as collectibles, in proportion to the astronaut.
- **Soft glow (12/07)** — each unbroken sample gets a gentle diffuse aura
  (7 faint layered circles → smooth radial falloff, NO glass rim/specular
  — an earlier glassy-bubble version was rejected as too hard). The glow
  colour comes from `Elements.glow_for(sym)` (average of the icon's own
  pixels, lifted in saturation/value) so the halo MATCHES the art — the
  blue oxygen bubble glows blue, not CPK-red. Static (redraws only on the
  mining flash), so no per-frame cost.

Why it matters: elements finally read as distinct, hand-made things —
gases glow, metals gleam, gold glints — instead of near-identical
procedural blobs, and the whole loop (see it in space → cut it → catch
the chunk → find it in the inventory) shows one consistent picture.

## 12/07/2026 — v1.16: intro rewritten as real storytelling

Reworked the intro (intro.gd) from a declarative pep-talk into quiet,
grounded sci-fi prose over the same scenario: (1) Earth dying, given to
HELIOS as "mercy"; (2) the AI's arithmetic finding humanity the one
variable it couldn't fit — "it did not hate us, it simply subtracted
us"; (3) the bloodless expulsion — biosphere sealed, arks taken, wall
of fire raised, then silence and watching; (4) what's left and WHY you
mine — the drive rebuilt only "from the bones of the sky", iron/silicon/
heavy+fissile metals chipped fragment by fragment, until it can carry
you past the wall; (5) Haven, the blind spot, and the five faint
beacons — "no one crosses this dark alone." Ending line matched:
"HELIOS never learned to look here. This is Haven. Begin again."

- **Materials → small pixel-art molecules in real CPK colours.**
  asteroid.gd draws chunky beveled pixel atoms joined by bonds; the
  colour is now the element's actual CPK/Jmol colour (added to elements.gd
  as `CPK` + `cpk_color()` — the source palette: O red, C grey, S yellow,
  Fe orange, Au gold…), not the golden-angle hue. Smaller overall. Pickups
  and radar asteroid blips use the same CPK colours so everything matches.
- **Fields stay depleted.** main.gd now spawns each dive site
  deterministically (RNG seeded by the sector), so revisiting shows the
  SAME field; each rock carries a `mine_key`, and shattering it records the
  key in `GameState.mined` (saved/loaded like salvage) — mined rocks never
  respawn when you come back.

**Performance.** The "busier space" pass had made things janky:
- flight.gd's starfield allocated a fresh RandomNumberGenerator PER CHUNK
  PER FRAME (GC-stutter). Now cached per (chunk, layer) in `_star_cache`
  and only generated once; densities trimmed back to sane.
- asteroid nodes were redrawing EVERY frame for a glow pulse — now fully
  static (redraw only on the mining flash).
- dive starfield counts trimmed. Ship shadow removed (also a per-frame
  full-hull redraw).

**Materials → molecular.** asteroid.gd now draws each node as a
ball-and-stick MOLECULAR cluster: solid shaded atoms in the element's
colour joined by bonds, the arrangement fixed by the element (diatomic
/ triangle / bent / tetrahedral / ring / chain). NOTE: stylised, not
chemically accurate — a real Bohr atomic model (per-element electron
shells) is the legit option if wanted.

**Circle cleanup.** Removed the ore-pickup glow circle; the radar's
nebula blobs are now clamped so they never spill past the disc edge.

- **Materials went minimal.** Dropped the busy faceted solids for a single
  clean silhouette per element (shape still fixed by atomic number: hexagon
  / diamond / crystal / rounded stone / octagon / shard), flat-filled in the
  element's colour with ONE soft light hint (a smaller inner copy pulled
  toward the light) and a thin outline. Faint shape-glow kept; no facets.
- **Chest-only breathing.** The interior idle breathing no longer scales
  the whole body. The sprite is drawn as three horizontal slices and only
  the middle (chest) slice puffs a hair wider — head and legs hold still.

## 12/07/2026 — v1.12: no more transparent circles + quest log

- **Killed the transparent circles.** Material glow (asteroid.gd) no
  longer draws concentric circles — it now fills the node's own SILHOUETTE
  (its outline, enlarged in two faint layers) so the glow hugs the shape.
  Dropped the circular specular glint and rich-core circles too. The dive
  background haze (main.gd) now uses the fractal NebulaFog texture instead
  of soft circles.
- **Quest log under the radar.** New scripts/quest_log.gd — a compact
  sci-fi objectives panel wired into the spacewalk and flight HUDs just
  below the radar. Reads live from GameState: "Rebuild the jump drive"
  (current part + element/ore progress) and "Find the scattered n/5"
  (next survivor + region, or which drive part the signal still needs),
  flipping to ✔ lines as each completes.

- **10 more nebulae** (9 → 19) appended to GameState.NEBULAE with varied
  palettes/sizes/distances. The first nine stay fixed (rescue regions
  1/2/3 depend on their indices); new ones append at 9+ and don't collide
  with any beacon (gauntlet beacon-region checks still pass).
- **Denser starfields.** flight.gd gains a far dust layer and ~1.5× counts
  (4 parallax layers now); the dive starfield counts bumped ~1.5×.
- **More traffic.** Comets/shooting stars fire far more often (flight
  1.8–4.5 s shooting; dive streaks 2.5–7 s).
- **Dive background haze.** main.gd now paints faint distant colour from
  the nearest nebulae behind the dive, so the mining scene never reads as
  empty black.

**Materials are now per-ELEMENT, not per-category.** asteroid.gd rebuilt
again: each element gets a faceted low-poly SOLID whose FORM is fixed by
its atomic number (golden-ratio hash → gem / octahedron / iso-cube /
hex-prism / crystal-cluster / boulder) and whose COLOUR is the element's
own hue. Facets are lit by a fake key light (counter-rotated per node so
lighting stays world-consistent) for a real 3D read; each node still
varies in size/spin so a field of one element isn't clones. Rich veins
carry a bright breathing core; every node keeps its glow halo. (Chose
faceted 2D over literal 3D meshes — ~40 live nodes make per-node 3D
SubViewports too costly; the faceted look reads as 3D at no cost.)

**All sound removed.** scripts/sfx.gd is now a silent stub that keeps the
Sfx API so every call site still resolves — nothing synthesized, nothing
plays. Restore from git history to bring audio back.

**Idle breathing.** The crew avatar inside the ship gently rises/falls
and its chest expands when standing still (interior_player.gd).

**Ship casts a shadow.** In flight, a soft black silhouette of the hull
is drawn just off the ship (offset away from the light) over the fields
and wrecks it passes — a real sense of the ship floating above the field.

## 12/07/2026 — v1.9: HELIOS story rework + material variety

**Darker story — HELIOS.** Rewrote the premise: Earth's systems were
handed to a governing AI, HELIOS, which classified humanity as the
contaminant and EXPELLED everyone into the void — sealed the biosphere,
seized the arks, and still runs purge-sweeps (the old "solar flares",
now reframed everywhere: intro, HUD banner, dive warnings). HELIOS
broadcasts bleed through the static between shifts (cold catalogue
lines). The five specialists are KEPT exactly (names/roles/regions/
perks) — now fellow exiles, their rescue lines recontextualised.
Haven = the one dead zone HELIOS can't sweep; VEGA knows the way.
Touched: intro.gd (5 pages), game_state.gd (RESCUES lines, HAVEN
premise, begin_shift HELIOS intercepts), main.gd + hud.gd (sweep
warnings), ship_interior.gd (ending).

**Materials don't all look like asteroids.** asteroid.gd rebuilt: the
node's dominant element picks a visual archetype, each with an emissive
glow halo in its ore colour —
- crystal: translucent blade cluster + glowing core (rich / metalloids)
- metal: cool grey hull-husk, panel seams, hard glint (Fe/Ni/Ti…)
- ice: pale translucent chunk, inner glow, cracks (alkaline Mg/Ca/Sr)
- radioactive: dark rock, pulsing green pits (Th/U)
- precious: dark stone with bright metallic veins + glints (Au/Ag/Pt)
- rock: the common oxide/carbon stone (O/C/S/Na…), now with a glow too
Gentle glow pulse; nodes now redraw per frame.

**Audit fixes (same pass).** Caught a material-mapping error — O and C
are the most abundant veins and both fell into "ice", so nearly every
node would have rendered as translucent ice; rock is now the baseline,
ice reserved for the alkaline group, so the field reads as mostly stone
with occasional ice/metal/crystal (verified in-scene). Swept for stale
old-story text: no player-facing leftovers; fixed two stale comments
and one intro line ("inner black" → "the dark", since sweeps reach all
dive regions). Re-ran the functional gauntlet: 26/26 PASS.

## 12/07/2026 — v1.8.1: turbines, ship size, tether, menu flow, crashes

- **Turning jets** moved back to the aft trailing-wing position (fire
  outward + aft) — read better there than at the forward wing tips.
- **Ship smaller** in flight and on the spacewalk (SHIP_SCALE 0.72→0.6).
  Dock-ship tether hardpoint, beacon and collision capsule refit.
- **Tether attachment fixed.** The lifeline clips to the **port-belly
  airlock hatch** (pixel-picked hull plating, not the belly turbine it
  used to sit on), and its sag scales with the span
  (`slack · clamp(dist·0.28, 0, 60)`) instead of a flat 60px — a short
  line near the ship no longer droops into a loop below the astronaut.
- **Menu flow.** NEW GAME lists only FREE slots ("SLOT n — NEW GAME");
  occupied slots are hidden (falls back to overwrite entries only if
  every slot is full, so you're never stranded). CONTINUE lists only
  real saves (name · DRIVE d/5), never empty slots or a new-game entry.
  The menu builder is stored as a Callable so overwrite-confirm relabels
  live (`_refresh()`); slot column widened so labels don't clip.
- **Thrusters mapped to ship2's 6 real nozzles** (user-marked). Full
  pixel inspection: two aft mains (flame −82/±10), two bow pods
  (37.5/±52), and — the ones I'd missed — two small SIDE turbines on
  the aft hull sides (top −48/−34, bottom −50/+36). Now: W = aft mains
  fire aft; S (reverse) = both BOW pods fire forward (bells at x37.5,
  not the old 33 that read "off"); A/D (turn) = the aft SIDE turbine on
  one side fires aft-and-outward. Every flame sits on a real bell.
- **Crash fix (chargen).** Same class as the title crash: `chargen.gd`
  called `set_input_as_handled()` after `_confirm()` had changed the
  scene (null viewport). Reordered. Audited all `set_input_as_handled`
  sites — title/intro already correct, inventory_screen doesn't change
  scene; chargen was the last one.

---

## 12/07/2026 — v1.8: concept title screen, ship2, laser & turbine fixes

**New title screen — the concept.** Rebuilt scripts/title.gd around the
user's mockup: the painted intro2 scene as the backdrop
(assets/sprites/title_bg.png, astronaut tethered to the ship over a
burning Earth), the SPACEWALKER banner up top, a bracketed sci-fi
border frame with hazard ticks, and VERSION bottom-left. The menu is
now **fully data-driven** — a menu is an Array of
`{label, icon, action:Callable, enabled, danger}` dicts, rendered as
notched command buttons with procedural vector icons (play / continue
/ settings / quit / plus / back / slot). Menus nest via a stack:
NEW GAME and CONTINUE open a slot sub-menu (new-mode arms an overwrite
confirm; load-mode lists only real saves), SETTINGS opens a placeholder
sub-menu to grow into, Esc walks back. Keyboard (↑/↓ + Enter/Esc) and
mouse both drive it. To add a command later, append one dict — that's
the whole change.

**ship2** (game-assets/spacewalker/new/ship2.png) replaces the hull,
340×240. Turbines re-mapped to its pixel-detected nozzles: twin mains
astern at flame-space y −8/+11, forward wing-tip pods at (32, ±51) for
reverse, outer wing-tip puffs for yaw. Dock-ship anchor/beacon and the
collision capsule (62r × 120h) refit to the new silhouette.

**Astronaut laser muzzle fixed** (again, properly). Pixel-detected the
gun tip in a5.png — the barrel sits at the sprite's right edge up near
the shoulder (x 0.48·w, y −0.305·h), not the −0.185·h the old code
guessed. The beam and raycast now leave the barrel instead of firing
from below the hand.

**Title polish + fullscreen.** Removed the tagline under the banner.
Game now launches fullscreen (project.godot display/window/size/mode=3,
stretch canvas_items + aspect keep — scales the 1280×720 canvas to the
monitor, no distortion). Version moved further into the frame. The
left-side darkening is now a single vertex-colour gradient (draw_polygon)
instead of 60 stacked alpha rects — the old stack left faint vertical
seam lines across the backdrop.

## 11/07/2026 — v1.7: full logic audit, sound design v2, new hull + logo

**Full-game logic audit.** Read every gameplay script end to end and
fixed what fell out:
- **SOLA element dupe** — her "keep half your ore" blackout perk kept
  the FULL element-vein tally while halving the ore value, so banking
  after a blackout refined more element units than the ore you held.
  Veins and chunk counts now shed the same half.
- **Wasted canisters** — the emergency O2 auto-discharge kept firing
  during the blackout animation (tank pinned at zero), burning crafted
  canisters on a walk that was already over. Oxygen logic now stops
  the moment you faint; the laser also can't keep mining while limp.
- **Session-flag leaks** — `pending_shift`, `wake_on_bunk`, `adrift`,
  `flare_phase` and `last_lost` survived across load/new-game: an
  abandoned run could tick a shift, spawn you in the bunk, or re-play
  the adrift opening on a completely different save. Both load paths
  now reset all session flags.
- Title footer version unstuck (was frozen at v1.1).

**Sound design v2 — everything rebuilt.** The old set (square-wave
klaxon/deny, raw noise, hard-gated envelopes) sounded harsh. New rules:
no square waves anywhere; every one-shot opens with a 6-10ms attack
(no clicks) and dies on an exponential bell tail; all noise runs
through a heavy one-pole lowpass. Pickup is a glass plink, bank a
two-note marimba, upgrade a four-note bell arpeggio, deny two polite
low taps, the klaxon a mellow rise-and-fall whoop, thrust a dark
55Hz rumble (crossfaded loop, no seam), laser a warm 110Hz power hum.
Loop volumes dropped 4dB across the board.

**New hull + new logo** (game-assets/spacewalker/new, processed by
tools/process_new_art.gd). Ship keyed, bow-rotated, 340×211; engine
effects remapped to her real hardware — twin big orange mains astern
(±17), front wing turbines at (37, ±46) firing forward for reverse,
and axial aft-facing wing pods at (-49, ±31) burning differentially
to yaw. New armored SPACEWALKER banner logo flood-keyed off pure
black (tight 0.09 threshold so its own dark plates survive).

**Ship bigger + aft flames fixed.** Hull scale 0.5→0.72 everywhere
(flight/dock/title/intro proportional). The twin main flames were
spread ±17 but the real nozzles sit ~17px apart total (pixel-detected
at y −8/+9 in flame-space, centred just below the spine) — fixed, so
the burn lands on the nozzles. Flame block now drawn at SHIP_SCALE*2
so every effect tracks the hull at any scale; dock ship anchor/beacon/
tether and hull collision capsule scaled to match.

**Verified:** 26/26 functional gauntlet (tools/test_audit_v17.gd —
SOLA halving, flag resets, rescue gating, beacon regions, economy,
all 13 sounds), all six scenes headless-clean, title + flight
screenshot-verified with the new art.

**Story rework — THE SCATTERED SIX.** The flare hit MID-JUMP: the
transport shattered and six lifeboats spun into the dark. You're one.
The other five — JUNO the Engineer, MIRA the Botanist, HALE the
Prospector, SOLA the Medic, VEGA the Navigator — are alive, beacons
singing across the sector. The campaign braids building with
searching: each survivor's signal only resolves after the next drive
part is installed (VEGA needs the whole drive), so the questline runs
part 1 → JUNO (Belt) → part 2 → MIRA (Viridian) → ... → VEGA
(Expanse) → jump. Each rescue: gold distress beacon in flight (drawn
in-world + gold radar pointer + HUD bearing), park, spacewalk to the
drifting tinted-suit survivor (guidance chevrons), reach them → radio
line, perk, aboard. Rescued crew LIVE IN THE SHIP — tinted mini-
astronauts bobbing in their rooms. Perks: +15 laser / +25 O2 / +40%
pickup reach / blackouts keep half your ore / +25% ship speed. The
ending is GATED on all five — "nobody gets left behind" — and the
intro, radio hints, title slots (CREW n/6) and finale all tell it.

**Sound.** scripts/sfx.gd autoload synthesizes all 13 effects at boot
(sine/square/noise — zero audio assets): laser hum loop, thruster
rumble loop, flare klaxon loop, ore pickup blip, bank chime, upgrade
arpeggio, deny buzz, debris/blackout thud, tether clack, O2-low beeps,
canister hiss, interior footsteps, radio blips. Wired everywhere:
mining, thrust (suit + ship), docking, contracts, trader, crafting,
upgrades, expansion, flares, debris, rescues, radio chatter, steps.

**Ship3.** The captain's new hull (tools/process_ship3.gd: keyed,
bow-rotated, 340px). Flames mapped to her real nozzles: twin orange
mains astern, FRONT wing turbines fire forward when reversing,
trailing-edge wing turbines fire outward when turning. Tether anchor
and beacon repositioned.

**Also:** spacewalk laser now raycasts AND draws from the pistol's
actual muzzle (+muzzle flash); tether clips to the backpack; suit jets
exit the backpack's bottom; interior side-margins tightened (no more
slipping along prop flanks); top-wall margin deepened (no more heads
on the window glass). 19/19 gauntlet on the questline + sfx.

---

## 11/07/2026 — v1.5.2: REAL lights + depth-line fix

- **Real 2D lighting**: a CanvasModulate dims the deck and every
  glowing prop carries an animated PointLight2D (shared radial
  gradient texture) — the light now genuinely falls on the crew and
  neighbouring props as you walk through it. Energy and position dance
  with the same two-frequency sway/flicker as the painted halos;
  lights rebuild when the ship expands; the quarters window spills
  starlight.
- **Depth-line fix** (captain: "accessing from the front puts me
  behind"): the depth split line now matches the COLLISION bottom
  (sprite base minus the obstacle shrink minus the foot box) — where
  you can stand and where you sort are the same line, so facing a
  console never hides you behind it.

---

## 11/07/2026 — v1.5.1: depth sorting, dancing lights, real shadow

- **Depth sorting**: the interior renders in two passes around the
  crew's feet line — props whose base is above it draw behind the crew,
  props whose base is below it draw on a new overlay Node2D IN FRONT of
  the crew. Walk behind a console and it now covers you. All kit
  helpers route through a `_ci` canvas pointer; station info panels and
  the ending sequence moved to the overlay (the ending used to fade
  UNDER the crew — bonus fix).
- **Dancing ambient lights**: glow halos now breathe on two frequencies,
  sway a few px around their prop, cast a counter-swaying elliptical
  pool on the deck, and suffer a rare electrical flicker. Every lit
  prop dances slightly out of phase (position-seeded).
- **Crew shadow**: soft two-layer ellipse hugging the feet (the old one
  was a faint circle floating mid-body).

---

## 11/07/2026 — v1.5: roomy ship — bigger cells, hard collision, ambient light

- **Cells enlarged 130x110 → 190x160** (ORIGIN recentered): furniture
  and stations re-spread with real distance between them, everything
  reachable with clean walking lanes. Station props scaled up (helm 84,
  reactor 76...), interact radius 60 → 72, doorway bars widened. The
  camera already follows the crew, so the bigger ship pans naturally.
- **Collision is feet-based everywhere now**: cell membership, wall
  margins AND furniture all test the foot point (with a 12x6 foot box
  so corners can't be clipped diagonally) — walking down from behind
  no longer overlaps walls or props.
- **Crew shrunk 44 → 36 px** per the captain — better proportion to
  the rooms and props.
- **Ambient light halos**: every lit prop (screens, consoles, helm,
  reactor, batteries, tank, window, medkit, hatch, pedestals...) casts
  a soft breathing glow pool in front of it — three-pass radial halos
  with a slow pulse, color-matched per prop (GLOWS table).

---

## 11/07/2026 — v1.4.8: interior collision — no more walking through walls

- **Wall margin**: any cell side without a built neighbour is plated —
  the crew stays 12px off it. Doorways between built rooms stay open
  automatically (no wall = no margin).
- **Furniture is solid**: every ROOM_PROPS piece and every station prop
  (helm, reactor, workbench, consoles, pedestals, lockers, hatch...)
  registers a collision rect (slightly shrunk from its sprite).
  Collision tests the FEET point, so the head can still pass behind
  tall props — classic top-down depth.
- Wake-in-bunk spawns beside the (now solid) bunk; a spawn-unstick
  scan nudges the crew to the nearest open spot if a save ever loads
  inside furniture. Obstacles rebuild whenever the ship expands.

---

## 11/07/2026 — v1.4.7: seamless wall tiling (middle-slice)

v1.4.6 tiled the FULL wall piece, so its baked end-caps repeated every
segment — Γ-shapes stacked down every wall (captain's catch). Walls
now tile only the art's clean middle band (28%-72% source region via
draw_texture_rect_region) at natural scale: segments join invisibly,
the trim runs continuous, light strips repeat naturally, and the real
run ends are dressed by junction pieces as before.

---

## 11/07/2026 — v1.4.6: walls tiled, not stretched

Long wall runs were stretching one piece up to 4x — panel lines
smeared into fake "double walls". Runs now TILE: the piece repeats at
near-natural proportions (half a cell per segment, remainder spread
evenly), so plate detail keeps its scale and the joints read as
riveted modular panels. Elbow extensions still apply to the end
segments.

---

## 11/07/2026 — v1.4.5: FOUND the corner brackets + walk scale fix

- The captain said "FIND corners" — and they were there all along:
  sheet 4's four thin L-connectors (s4_00/01/03/04) are corner
  BRACKETS in all four orientations. They now bolt over every inner
  elbow, centered on the true wall-centerline crossing — riveted
  structural joints from the kit itself, on top of the butted wall
  runs. Verified at 4x zoom: hull steps and room junctions read as
  deliberate construction now.
- **Walk size-change fixed**: frames were each normalized to their own
  height, so the taller synthesized stride frames (and the kit's
  naturally-varying frame heights) made the body grow/shrink while
  walking. ONE scale for all frames now (from the idle frame), head-
  anchored so stride extension goes downward only.

---

## 11/07/2026 — v1.4.4: junctions verified at 4x zoom; real stride frames

The captain was right and the fix had to be verified with magnified
crops, not full-view screenshots:

- **T-pieces were mis-centered** (bar hanging off the wall into space)
  — the bar now aligns to the through-wall's exact centerline via the
  piece's own geometry (bar center is 10px off piece center) plus the
  wall's ±3px trim offset. All four orientations corrected.
- **Inner elbows: caps abolished.** The code-drawn caps floated with
  gaps on both sides. Now the two incident wall RUNS extend through
  the joint to exactly the crossing wall's far face (8 or 14px by
  trim side) and overlap — the corner is made purely of kit wall art
  butting together. Verified at 4x zoom on the hull steps and room
  junctions.
- **Front-walk frames v2**: the first synthesis cut the sprite at 60%
  (through the torso — transparent band artifact). Now the split is
  at the hip (66%), the planted leg draws twice (rest + shifted) so
  the overlap bridges the joint, and the lifted leg rises 7px and
  BLENDS over the torso. 13px stride at source = ~4px in game =
  visible steps. Shaky sway removed entirely.

---

## 11/07/2026 — v1.4.3: junction alignment + synthesized front-walk frames

- **The "still weird" junctions were an alignment bug**: walls run 3px
  off the grid line (toward the void) but T-pieces and elbow caps were
  centered ON the line — everything floated slightly. T-pieces now
  nudge 3px toward their trim side; elbow caps center on the actual
  wall centerline and copy the wall art's look (dark plate, 6px silver
  trim on void faces, dark seams on floor faces). Audited sheet 3's
  four unmapped corners (s3_04-07): all top-lit variants — the kit
  truly has no bottom-lit corners or inner elbows; flips + the styled
  cap remain the right call unless the captain generates those pieces.
- **Front-walk frames synthesized from the kit itself**
  (tools/gen_walk_frames.gd): paper-doll split at the hip — planted
  leg shifts down, lifted leg up, two frames with opposite legs.
  Crew now has a real 4-beat front walk (stride A, idle, stride B,
  idle); sway reduced to a hint.

---

## 11/07/2026 — v1.4.2: edge-graph walls, T/X junctions, inner elbows, mipmaps

- **Walls rebuilt as an edge graph** (captain circled the weird joints):
  every wall edge knows which side the floor is on; straight walls draw
  as ONE merged run per stretch (mid-run seams gone), and every grid
  point gets classified — L-corner (kit piece, 4 orientations), T
  (re-extracted kit piece, sheet 3 recut at tighter merge padding —
  16 props now), X-cross, or **inner elbow**. The kit's L-pieces
  geometrically can't do concave corners (trim is always opposite the
  arms), so inner elbows get a palette-matched plate cap with trim on
  the two void-facing sides.
- **Crew walk**: front/back walks (single-frame in the kit) now sell
  their steps with a waddle sway + stronger bob on top of the mirror
  alternation.
- **"Weird pixelation" diagnosed**: hi-res props drawn at ~1/3 size
  with plain linear filtering alias/shimmer, on top of the project's
  1280x720 canvas_items stretch + nearest default filter. Fixed the
  real half: mipmaps enabled on all 150 prop/astro textures and the
  interior + crew + props now sample LINEAR_WITH_MIPMAPS.

---

## 11/07/2026 — v1.4.1: corner caps, VHS removed, crew walk fixed

- **Wall corners done right**: the wall pass now computes each cell's
  outside edges first, draws all straights, then caps every convex
  corner with the kit's L-pieces (s3_02/s3_03, mirrored vertically for
  bottom corners) — no more raw seams where walls met.
- **VHS effect fully removed** per the captain (it also made people
  dizzy in its wobbly form): screen_fx.gd and vhs.gdshader deleted,
  all six scenes cleaned of the overlay.
- **Interior crew fixed**: side frames face RIGHT in the art — the
  flip was mirrored (walking right showed left). Walk cycle upgraded
  to a proper 4-beat (stride A → stand → stride B → stand); front and
  back walks mirror on alternate steps to fake strides.

---

## 11/07/2026 — v1.4: THE INTERIOR — built from the captain's prop kit

The 10 green-screen ChatGPT sheets in game-assets became a real ship:

- **Extraction pipeline** (tools/extract_props.gd): chroma-keys the
  green, de-spills edges, finds each sprite as a connected component
  (merging nearby parts so crate stacks/dashed frames stay whole) —
  136 props cut into assets/props/ as sN_XX.png in reading order.
  tools/make_contact.gd builds indexed contact sheets for mapping.
- **Interior rebuilt on the kit** (ship_interior.gd): per-room floor
  tiles (rust engine deck, purple quarters, hazard airlock, grate
  cargo, braced upgrade bay, vented bridge) drawn 2x2 per cell;
  plated wall sprites along every hull boundary AND around built
  rooms (trim always faces the void); doorway threshold bars between
  connected rooms; a glass viewport on the quarters' hull wall.
- **Real furniture**: bunk/locker/nightstand/medkit in quarters;
  batteries, coolant tank, cables and generator around the reactor
  (the drive console IS the kit reactor now, warming up per quest
  part); pegboard workbench + tinted upgrade pedestals + suit locker
  in the bay; helm-with-chair, comms monitors, radar display and
  holo-table on the bridge; crate stacks, hazard crate, barrel and
  toolbox in the hold; hatch wheel, gas cylinders and suit wardrobe
  in the airlock.
- **Build markers from the kit**: teal dashed cell = buildable,
  orange X = can't afford, drawn over the target bay.
- **Crew sprite**: the interior avatar is the kit's mini-astronaut —
  front/side/back walk frames with stride alternation and bob
  (interior_player.gd rewritten).
- Deleted the duplicate 08_14 batch from game-assets (byte-identical).

---

## 11/07/2026 — v1.3.2: the VHS filter actually renders now

The tape effect had been silently OFF since it shipped: the shader
compiled fine, but the ColorRect it lives on used FULL_RECT anchors
under a CanvasLayer-parented Control — those anchors never resolve
there, so the filter rendered into a 0x0 rect in every scene.
screen_fx.gd now sizes itself to the viewport by hand (and tracks
window resizes). Tuned to minor: aberration 1.1px, scanlines 0.06,
grain 0.022. Visible in all six scenes; the world gets the tape look,
the HUD stays crisp (it draws above the filter).

---

## 11/07/2026 — v1.3.1: astronaut polish pass (captain's five fixes)

- **One uniform scale for all frames** — process_astronaut.gd now derives
  a single factor from a1's content height, so horizontal poses (a3) no
  longer inflate; body size is identical across all 8 frames.
- **Smaller astronaut** — ~38 world px (was 56); collision 17 → 13.
- **Jet stream from the backpack** — flames anchor to the pose-aware
  backpack point, not the body center.
- **Laser fixed** — the aim pose (a5) rotates with the shot (mirrors
  vertically when firing left), and the beam leaves the art's actual
  muzzle. `_suit_state()` computes ONE shared Transform2D used by the
  suit, the tether clip and the muzzle so nothing drifts apart.
- **Tether always attached** — the line ends at the belt clip,
  transformed with the current pose (incl. blackout tumble).
- **Laser bite effect on rocks** — molten point + white-hot core,
  radial sparks, flying embers in the vein's color, and an expanding
  heat ring that cools with the flash.
- Debug hook: SW_LASER=1 forces the beam for screenshots.

---

## 11/07/2026 — v1.3: painted astronaut, helm radar, nine nebulas

- **Painted astronaut in the game** — the captain's 8 ChatGPT frames
  (game-assets/spacewalker/a1-a8) processed by tools/process_astronaut.gd
  (trim + Lanczos to 112px, real alpha) into assets/sprites/astro/.
  player.gd got a frame state machine: idle drift A/B alternation,
  thrust (flips toward the burn), brake star-pose, mining aim (pistol
  lives in the art now — code draws only the beam), reach-for-the-line
  during the adrift opening, debris-hit recoil (main.gd calls
  hit_flash()), and a limp 1.1s tumble on blackout before the bunk.
  Upright + horizontal flip toward the action, light velocity lean.
  Collision radius 14 → 17 for the bigger figure.
- **Helm radar** — the holographic scanner now rides the flight HUD
  too (radar_panel.gd gained modes): asteroid FIELDS as rings tinted
  gold→cyan by richness, salvage wrecks as metal-hue sparks, home
  square, and nebulas — soft tinted blobs in range, colored rim ticks
  pointing the way when beyond. Range 36 km.
- **Nine nebulas, sized and colored individually** — the four
  originals joined by Amethyst Deep (violet giant, 3400), Carmine
  Hollow (small crimson), Gilded Drift (gold), Ghostlight Shoal (pale
  ice wisp, 1200), Tyrian Abyss (magenta monster, 3800, deep in the
  Expanse). Per-nebula radius everywhere (region logic, fog draw
  scale, hearts, tinted star counts, radar); NebulaFog generates each
  cloud's smoke from its own color automatically.

---

## 11/07/2026 — v1.2: LOGIC AUDIT — 10 fixes from a full-game examination

Systematic audit of every gameplay script + genre-loop comparison
(Dave the Diver / Dome Keeper). All fixes verified by a 22-check gauntlet:

- **Adrift trap fixed**: boarding the ship by ANY door clears `adrift`
  (blackout-while-adrift or dock-without-attach no longer flings you
  back into space on your next exit). Blackout message is honest when
  you had no line ("the suit's auto-return...").
- **Shift rhythm has a cost now**: `pending_shift` flag — a shift only
  ticks after real work (left the dock ring / flew >600px / blacked
  out). Loading a save or lapping the airlock no longer advances time
  or rerolls the boards. First boards fill after your first real walk.
- **Arbitrage exploit killed**: Vesna sells at 2x market rate (she buys
  low, sells high); contract rewards (~1x + 8-14) can no longer be
  farmed by buying from her — verified unprofitable for all 15 pool
  elements at max reward roll.
- **Trader stock is finite**: 1-3 units per offer per shift, SOLD OUT
  state in the comms panel, qty in the save.
- **Contracts persist** until delivered — rolls only fill empty board
  slots (no more banking toward a request that vanishes).
- **Salvage stays looted**: taken-wreck keys live in GameState + the
  save; the chunk-cache reset no longer respawns collected trash.
- **Invisible endgame wall signposted**: quest parts 4/5 now carry
  source hints (precious metals = wrecks + rep 6 trader; fissiles =
  rep 10 trader) shown on a failed install; new Vesna radio line says
  gold never rides in rock. (Abundances untouched, as decreed.)
- **The suit finally does something: cargo capacity.** carry_max = 25
  + 15/level (Dome Keeper-style trip tension). Full suit stops
  magnetizing and collecting ("Cargo full — bank at the ship"), vitals
  show ORE n/cap, gear tile shows MK level + capacity, new suit
  upgrade station in the Upgrade Bay (base 12 ore).
- **Esc on the intro** no longer leaks to the pause menu
  (set_input_as_handled).
- **Save discipline**: gear upgrades and trader purchases save
  immediately (no more Alt-F4 rollback).

---

## 11/07/2026 — v1.1.1: sky cleanup — suns/planets removed, starfields densified

Per the captain: no suns, no planets — just more stars.

- Removed the drawn sun and all procedural planets from dive + flight
  (SpaceDressing slimmed to SUN_DIR/sun_local + comets; the directional
  rim lighting on asteroids stays — the sun is off-screen now).
- Dive starfield rebuilt: four parallax layers (new ultra-far dust
  layer), 3500 stars total with view culling (the old counts only put
  ~30 on screen because the pattern square is 5200px wide).
- Flight star chunks doubled (62/38/20 per layer per chunk); title 280
  stars, intro 220.

---

## 11/07/2026 — v1.1: HAVEN — story fix, crew record, painted logo, living sky, radar, adrift opening

The story now makes sense, the sky is alive, and the game knows your name:

- **Story rework — find a NEW home**: Earth is a cinder; there was never
  a home to "go back" to. The arks that escaped are raising a colony at
  Proxima called **HAVEN** — a home you've never seen. Quest renamed
  (final log: "Course locked: HAVEN"), drive prompt says "SET COURSE FOR
  HAVEN", ending headline is now **HAVEN** ("Welcome to your new home,
  <name>"), title badge "✦ HAVEN". Intro rewritten around the idea.
- **Crew record (character creation)**: new game → EMERGENCY CREW RECORD
  scene (chargen.tscn) — name/callsign, gender (F/M/OTHER), age. Stored
  in `GameState.pilot`, saved per slot (save v4→pilot key, legacy saves
  default to WALKER/27). The intro addresses you by name and age, Vesna
  greets you on the radio, the ending and the adrift opening use it,
  title slots show the pilot's name.
- **Adrift opening**: after the intro you spawn ~900px from the ship
  with **no lifeline** (LINE 0%, no tether physics, no line drawn).
  Pulsing chevrons walk from you toward the hull; within 150px the line
  clips on ("CLACK. Lifeline secured."). `player.attached` flag;
  SW_ADRIFT=1 debug hook.
- **Holographic radar** (top-right of the spacewalk HUD, radar_panel.gd):
  sweeping cyan holo disc with scanlines + flicker; asteroid blips in
  their **vein element's color** (diamonds = rich), loose pickups as
  sparks, blips flare as the sweep passes, ship square clamps to the rim
  when out of range (adrift guidance), tether-reach ring in world scale,
  region name caption. Pickups/ship got groups ("pickups"/"dock_ship").
- **Living sky + painted light** (space_dressing.gd): one shared
  `SUN_DIR` lights the whole game — a layered-glow **sun** with cross
  flare pinned deep in the sky (dive + flight), procedural **distant
  planets** (rocky/gas-banded/ice, terminator shadow, day-side rim,
  atmosphere glow, some ringed) — deterministic per chunk in flight
  (PLANET_CHUNK 4800, depth 0.12) and per sector in the dive; asteroids
  now **rim-lit toward the sun** (sheen + night-side shadow + lit edge
  arc); flight field rocks re-shaded to match; **comets** with tapering
  ice tails and **shooting stars** in both dive and flight.
- **Painted logo** on the title screen: user's logo.png, background
  killed via border flood-fill keying (tools/process_logo_art.gd —
  survives the logo's own grays, keeps glow fringes), drawn with cyan
  under-glow + the signal-glitch effect. Title footer bumped to v1.1.
- Tested: 14-check gauntlet (pilot round-trip, legacy saves, HAVEN
  strings, Vesna personalization, planet determinism) all PASS; all 6
  scenes headless-clean **with stderr captured** (lesson: `2>$null` was
  hiding parse errors — new class_name needs `--import` to register);
  visual verification screenshots of chargen, adrift dive, flight, title.

---

## 11/07/2026 — v1.0: PURPOSE — quest, contracts, Vesna, hazards, crafting, intro

The engagement package, fully braided (55/55 functional tests green):

- **THE LONG WAY HOME** (story quest): rebuild the jump drive from real
  elements — 5 parts from Plasma Conduits (Fe+Si) to the **Fuel Core
  (Uranium + Thorium)**, installed at the Engine Room drive console
  (progress in the prompt; the assembly visually fills per part).
  Completion → ending sequence → title slot shows "✦ HOME".
- **Contracts board** (Cargo Hold): 3 rotating element requests per
  shift; deliver for ore + **reputation**. Board shows live progress.
- **Vesna's market** (Bridge comms): buy elements with ore, keys 1-3.
  **Prices scale with real abundance** (Fe 3 ore · Au 54 · U 75) and
  **reputation unlocks rarer stock** (rep 3/6/10 tiers up to U/Th).
  Radio flavor lines on some shifts.
- **Hazards**: **solar flares** (7s warning klaxon + banner → 6s burn
  draining O2 unless sheltered within 130px of a rock or docked; more
  frequent in Ember Reach/Expanse; SW_FORCE_FLARE debug hook) and
  **debris strikes** (fast tumbling rocks with trails, knockback + O2
  vent on hit, dense in The Belt).
- **Workbench crafting** (Upgrade Bay, keys 1-4): O2 Canister (4 O +
  2 Fe — the oxygen element finally feeds the suit; auto-fires below
  15% O2, max 3), Magnet Coil (+60% pickup reach), Gold Lens (+20
  laser), Tether Dampener (+60 stretch). Permanent mods persist.
- **Shift rhythm**: every return to the ship ticks a shift — contracts
  and market refresh, Vesna may radio in.
- **Intro cinematic** on new game: 4-page typewriter — the evacuation,
  the flare, the stranding, GO HOME. Space advances, Esc skips.
- Save v4 (quest/rep/shift/canisters/crafted/contracts/stock); title
  slots show drive progress ("DRIVE 2/5").
- Tested like hell: 55-check gauntlet (quest chain, price ladder,
  contract determinism+delivery, trader tiers+purchases, all recipes,
  caps, shift ticks, full save/load roundtrip) + all 5 scenes runtime
  clean + visual checks (intro, flare burn, new stations).

---

## 11/07/2026 — UI kit v5: RETROFUTURISM (user reference-matched, all vector)

Full restyle to the user's cyan-on-black tactical HUD reference:
- **All vector now** — the baked-texture panels are gone. `ui_theme.gd`
  draws angular panels (big 45° slant + notches) with **solid accent
  wedges**, doubled top edges, tick marks and underlines; slim notched
  sub-panels; **triangle-zigzag segment meters** (the reference loader);
  ring gauges with tick rings; slanted **tech banners** with striped
  caps; **hazard-stripe WARNING banners**; animated **chevron flows**;
  bracket-cornered key chips. Buttons/panels via skewed StyleBoxFlat
  parallelograms with cyan borders + glow-shadow on hover.
- **Hand-written SVG icon set** (`assets/icons/`, 10 icons: helmet,
  line, tank, laser, ore, warning, radiation, lock, skull, chevron) —
  white strokes tinted at draw time via `UITheme.draw_icon`. Used in
  the gear rack, inventory gear rows, title hazard strip.
- **Title**: glitching wordmark (periodic cyan/red offset flashes),
  chevron flows framing the slots, bracket-framed hazard icon strip,
  "SYSTEMS ONLINE" footer.
- Palette: cyan #4ADEFF on near-black teal; hazard amber reserved for
  warnings. Everything restyles from UITheme consts + helpers only.

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
