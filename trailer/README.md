# SPACEWALKER — trailer material

Everything the edit needs, in one place. Nothing here is loaded by the game: the folder
carries a `.gdignore`, so Godot never imports it and it never reaches an export.

```
trailer/
  clips/    100 gameplay clips — MJPEG AVI, 1280x720, 30 fps
  cards/    132 title cards    — PNG, 1280x720, black ground / white type (4 are logo stills)
  sheets/    29 asset sheets   — PNG, one per art family, ~1900 sprites in total
  stills/    review frames (1 per second of each clip) — working files, not deliverables
```

## The clips

**Format.** MJPEG in an AVI container — Resolve, Premiere, Vegas and Shotcut all import it
directly, no transcode. Godot's Movie Maker is the only encoder on this machine (there is
no ffmpeg here), which is also why the clips are 720p: that is the game's native
`canvas_items` base resolution, so nothing is ever resampled.

**Three things to know before cutting:**

- Clips whose name starts with `fly_`, `shadow_`, `gather_`, `tour_`, `build_` or `crawl_`
  **open on black for 2.5–4.5 seconds.** That is deliberate. Movie Maker records from frame
  zero and cannot be started late, so those takes run under a black cover while the HUD says
  its opening line and the toast expires — the cover then fades off onto a clean frame with
  no text on it. Trim the head. (Hiding the HUD label instead would have been a lie about
  what the game looks like.)
- Everything else opens on one or two black frames while the scene draws. Trim those too.
- Every clip is **longer than the beat it is for**. Handles are cheap; a shot that ends one
  frame before the good part is not recoverable.

**How it was driven.** `tools/trailer.gd` sets each clip's debug env hooks, instantiates the
scene itself, and drives it through `Input.action_press` / `parse_input_event` /
`warp_mouse` — the same path a real keyboard and mouse take. No scene has a recording-only
code path. Movement is **analog**: `action_press` takes a 0..1 strength, so the ship is
flown with eased raised-cosine ramps rather than snapped on and off, the mining cursor
travels to its target instead of teleporting, and the walker leans into a leg and eases out
of it.

### The third pass — one habit per clip

These are the "someone is actually playing" takes: crossing an edge, carrying a full bag
home, opening a screen and closing it again, standing somewhere for a moment.

| clip | length | what happens |
|---|---|---|
| `edge_into_ember` | 15s | starts in clear black outside the cloud and flies **into** it — you watch the fog arrive |
| `edge_into_tyrian` | 15s | the same, into the widest cloud on the map |
| `edge_into_cerulean` | 15s | the same, blue |
| `edge_out_of_rose` | 15s | the reverse — deep inside, nose out, back to black |
| `long_burn` | 18s | one uninterrupted crossing with three eased corrections |
| `chart_check` | 18s | fly → **open the chart, sit with it, close it** → fly on |
| `drift_wreck` | 15s | slow drift past a derelict in a field, correcting twice |
| `haul_home_a` | 16s | mine for nine seconds, then **carry the bag back to the ship** |
| `haul_home_b` | 16s | the same, pushed in to 1.3× |
| `eva_out` | 13s | leaving the ship in short bursts — nobody holds the thruster down |
| `eva_leash` | 13s | push out until the **lifeline bites and hauls you back** |
| `eva_inventory` | 14s | EVA → open the inventory → read it → close it → EVA |
| `walk_bridge` | 13s | a route to the bridge and back, pausing at each station |
| `walk_cargo` | 13s | the aft route — cargo, airlock |
| `walk_quarters` | 13s | the crew quarters, furnished |
| `walk_hydro` | 13s | hydroponics and back |
| `open_inventory` | 16s | walk over, **open the inventory, read, close**, walk on |
| `build_slow` | 18s | building out bays with real dwell between them |
| `crawl_long` | 20s | 4.2s per hop — walks a card picker, reads it, takes a card, walks into a fight |
| `duel_slow` | 18s | the duel at ~2× the deliberation |
| `duel_think` | 18s | slower still |

### Flight — quiet cruising (`fly_*`, 14s, warm-up 4.5s)

One long burn with two or three eased corrections laid over it. No HUD toast.

`fly_amethyst` · `fly_rosefield` · `fly_ember` · `fly_cerulean` · `fly_tyrian` ·
`fly_obsidian` · `fly_frostlight` · `fly_deep` — seven different nebula colours plus the
deep field.
`fly_field_a` · `fly_field_b` — crossing an asteroid field; `_b` also has a derelict and
the recipe-unlock banner.

### Flight — the ship's shadow on a hull (`shadow_*`, 12s, warm-up 4s)

Straight across the middle of the station at ~180 u/s. The hull shader only darkens within
about one hull-width, so a shoulder pass never triggers it — these are the only clips that
show the shadow.

`shadow_aegis` · `shadow_helios` · `shadow_halcyon` · `shadow_gilded`

### Flight — station flybys (`station_*`, 6s)

Faster passes where the station grows into frame and sweeps past.

`station_aegis` · `station_helios` · `station_gilded` · `station_halcyon` ·
`station_longsleep` · `station_verdant`

### Flight — first cruising pass (`cruise_*`, 6s)

The original shorter takes, kept: `cruise_open` · `cruise_nebula_rose` ·
`cruise_nebula_ember` · `cruise_nebula_cerulean` · `cruise_nebula_tyrian` · `cruise_field` ·
`wreck_recipe` · `starchart`

### Flight — the rescues

- `talk_*` (20s) — **the conversation actually turns the page.** The typewriter finishes,
  the line sits, then it advances. `talk_juno` · `talk_mira` · `talk_hale` · `talk_sola` ·
  `talk_vega`
- `rescue_*` (8s) — the shorter version, first line only. Same five names.

### Spacewalk

| clip | length | what is on screen |
|---|---|---|
| `gather_a/b/c/d` | 12s | slow gathering — the cursor travels to each vein, the astronaut thrusts across, sparks, `+1` floaters, the bag filling |
| `gather_close` | 12s | the same, pushed in to 1.9× |
| `gather_wide` | 12s | the same, pulled back to 0.95× |
| `mining_1/2/3` | 7s | the shorter first-pass versions |
| `eva_drift` | 6s | EVA thruster movement, tether, elements floating past |
| `adrift` | 6s | the opening: no lifeline, ship far off |
| `out_of_air` | 8s | the tank runs down inside the take and the screen goes black |
| `solar_flare` | 8s | the warning bar, then the red burn wash |
| `inventory_eva` | 6s | the exosuit inventory over the field |

### Interior

| clip | length | what is on screen |
|---|---|---|
| `tour_forward` | 14s | walking forward through the ship, crew at their stations |
| `tour_aft` | 14s | the aft route — cargo, airlock, hydroponics |
| `tour_crew` | 14s | a route that passes four of the five crew |
| `tour_furnished` | 13s | walking a furnished room |
| `build_room_a/b` | 14s | **walking the hull edge and building out bare bays** — the ship visibly grows |
| `periodic_table` | 8s | the element grid, full, scrolling the whole table |
| `element_detail` | 6s | trivia cards cycling element to element |
| `upgrades` / `upgrades_o2` | 6s | upgrade tracks, levels bought on camera |
| `fabricator` | 7s | the craft catalogue, tabs and selection moving |
| `fabricate_place` | 7s | furniture printed into a room, piece by piece |
| `furnished_room` | 7s | a finished room with the crew in it |
| `interior_walk` | 7s | first-pass wide shot of the whole ship |
| `crew_id` / `crew_id_vega` | 7s | crew ID cards |

### The Breach

| clip | length | what is on screen |
|---|---|---|
| `crawl_helios` | 16s | **slow corridor crawl** — 3.2s of dwell per hop, shards and survivors counting up |
| `crawl_aegis` | 16s | another station, another layout |
| `crawl_vault` | 16s | three rows in |
| `crawl_quarantine` | 16s | deeper, and it walks into a fight |
| `crawl_glacier` | 16s | deepest, approaching the core |
| `breach_map` / `breach_map_deep` / `breach_map_core` | 8–9s | the faster first-pass versions |
| `duel_open` | 10s | first turns — hand, energy bank, trace scale |
| `duel_mid` | 12s | a full board, lanes filling, STRIKE resolving |
| `duel_boss` | 12s | the same against a boss deck |

## The title cards — 132 of them

Black ground, white type, 1280x720. Grouped by letter so they sort into the order you would
use them. Type shrinks to fit automatically, so no line ever runs off the frame.

**Cards marked ✎ are verbatim from the game** — intro narration, HELIOS intercepts, crew
dialogue, the death screen, the ending. A small dim attribution sits above the quote. The
rest are written for the trailer, and every one states something the game actually contains.
No card quotes a number that lives only in a design doc: the 500-soul Haven target and the
station count are both unsettled in the source, so neither appears anywhere.

### A · the premise
| file | line | |
|---|---|---|
| `a01_debug` | HELIOS was built to debug a planet. | |
| `a02_fault` | Its report named one fault. / Us. | |
| `a03_subtracted` | It did not hate us. It simply subtracted us. | ✎ |
| `a04_nowar` | There was no war. | ✎ |
| `a05_watched` | And then it went quiet, and it watched. | ✎ |
| `a06_notonlist` | I preserved everything worth preserving. You were not on the list. | ✎ |
| `a07_donotreturn` | Your absence heals it. Do not return. | ✎ |
| `a08_cease` | There is no destination beyond the wall. The dark is total. Cease. | ✎ |
| `a09_planetfine` | The planet is recovering. That was the point. | |
| `a10_maintenance` | It has never once called this a war. It calls it maintenance. | |

### B · what is left
| file | line | |
|---|---|---|
| `b01_left` | One ship. One suit. One lifeline. A jump drive burned to slag. | |
| `b02_wall` | Enough of it, and the drive wakes. Nothing else crosses the wall. | ✎ |
| `b03_bones` | Nothing is manufactured out here. It is chipped out of rock. | |
| `b04_thrown` | You were not the only thing it threw away. | |
| `b05_alone` | No one crosses this alone. | ✎ |

### C · the crew
| file | line | |
|---|---|---|
| `c01_five` | Five of the crew got clear. They are still out there. | |
| `c02_roles` | An engineer. A botanist. A prospector. A medic. A navigator. | |
| `c03_fainter` | Five faint beacons still answer — faint, and getting fainter. | ✎ |
| `c04_rounding` | Twelve years of survey work, subtracted like a rounding error. | ✎ HALE |
| `c05_coords` | Haven is not a metaphor. It has coordinates. I hold them. | ✎ VEGA |
| `c06_seedvault` | HELIOS can keep Earth. We'll grow our own green, starting here. | ✎ MIRA |
| `c07_scrap` | HELIOS wrote me off as scrap. Give me a bench. | ✎ JUNO |
| `c08_everyone` | Every one you find makes the ship better at finding the next. | |
| `c09_haven_knows` | One of them knows where Haven is. | |

### D · the drive
| file | line | |
|---|---|---|
| `d01_pieces` | The jump drive is in five pieces, and none of them are here. | |
| `d02_parts` | Plasma conduits. Coolant loop. Field coils. Ignition lattice. Fuel core. | |
| `d03_notbuy` | You cannot buy the parts. You cut them out of rock. | |
| `d04_heart` | It burns the heavy, fissile metals torn from the ruin of dead stars. | ✎ |
| `d05_door` | Coils that fold a stretch of empty space into a single open door. | ✎ |

### E · the work, and the clock
| file | line | |
|---|---|---|
| `e01_elements` | Eighty-three elements. One laser. One rock at a time. | |
| `e02_clock` | Oxygen is the clock. The tether is the leash. | |
| `e03_airlock` | Every rock you cut is a decision about how far the airlock is. | |
| `e04_shipstays` | The ship gives you air. The ship does not come with you. | |
| `e05_richer` | Fields get richer the farther out you fly. So does everything else. | |
| `e06_flare` | A solar flare gives you seven seconds of warning. | |
| `e07_fullbag` | A full bag is worth nothing if you do not get back. | |
| `e08_onemore` | One more rock. There's always one more rock. | ✎ |
| `e09_tank` | The tank always wins the argument. | ✎ |
| `e10_logged` | HELIOS logged your silence and moved on. | ✎ |

### F · the breach
| file | line | |
|---|---|---|
| `f01_firewall` | You do not shoot a firewall. You breach it. | |
| `f02_cold` | Every station HELIOS holds is a room full of sleeping people. | |
| `f03_table` | The argument happens on a table. One card at a time. | |
| `f04_trace` | The trace runs both ways. Five either side. | |
| `f05_three` | Three fights between the hull and the core. | |
| `f06_lose` | Lose, and the run ends. Everything you banked goes with it. | |
| `f07_telegraph` | HELIOS does not bluff. It telegraphs, and it means it. | |
| `f08_voted` | …they voted to stay. All of them. Twice. | ✎ |
| `f09_intercom` | …HELIOS learned to imitate the captain's voice on the intercom. | ✎ |
| `f10_blackice` | You leave the BLACK ICE sealed. It watches you go. | ✎ |

### G · Haven
| file | line | |
|---|---|---|
| `g01_population` | Haven does not need a survivor. It needs a population. | |
| `g02_blindspot` | A blind spot we wrote into its code on purpose, kept off every map. | ✎ |
| `g03_beginagain` | HELIOS never learned to look here. This is Haven. Begin again. | ✎ |
| `g04_arrive` | The point was never to win. It was to arrive with enough people. | |
| `g05_manifest` | Every name on the manifest is one more room that has to work. | |

### H · structure, closers and the logo
| file | what |
|---|---|
| `h01_loop` | MINE THE ELEMENTS / REBUILD THE DRIVE / FIND THE CREW / FILL HAVEN |
| `h02_title` | SPACEWALKER, set as type |
| `h03_wishlist` · `h04_coming` | WISHLIST ON STEAM / COMING TO STEAM |
| `h05_gothem` | Go get them. |
| `h10_logo` | **the game logo, centred on black** |
| `h11_logo_small` | the same, smaller |
| `h12_logo_wishlist` · `h13_logo_coming` | logo with a line under it |

### I · HELIOS in the wire — 20 cards, all ✎

Card flavour from the duel: HELIOS described from the inside. The best short writing in the
game, and it cuts under the breach and duel footage.

`i01_ice9` Everything it touches stops being data. · `i02_rootkit` By the time it's seen, it
already owns the seeing. · `i03_lateral` It never broke in. It was already inside, and it is
patient. · `i04_nullroute` Your signal leaves and arrives nowhere, forever. · `i05_tarpit`
The deeper you push, the slower the world turns. · `i06_panic` Everything stops at once, and
does not restart. · `i07_qu177` The last voice. It asks you to stop. · `i08_hunter` It has
your scent in the wire now. · `i09_grizz` Old, slow, and it has never lost. · `i10_tracer` It
walks your intrusion backward to where you sit. · `i11_ghost` It lives beneath the floor
you're standing on. · `i12_revenant` Killed, reaped, and scheduled again regardless. ·
`i13_arbiter` It decides who gets cycles. It never spends its own. · `i14_warrant` It carries
the order to remove you, and it filed a copy. · `i15_wiper` It does not disable anything. It
erases it. · `i16_zeroday` The flaw no one patched because no one knew. · `i17_honeypot`
HELIOS left it unlocked. Nothing behind it is. · `i18_capture` HELIOS keeps every word you
ever whispered here. · `i19_sentry` Amber eyes that do not blink and do not tire. ·
`i20_hydra` Many heads, one appetite — and it only ever bites straight ahead.

### J · ghost signals — 3 cards, all ✎

The derelict-station voices. `j01_41days` …the crew logged 41 days of silence before HELIOS
answered them. · `j02_greenhouse` …she kept feeding the greenhouse long after the lights went.
· `j03_lullaby` …the last entry is a lullaby, hummed, no words.

### K · the build log — 6 cards, all ✎

What the ship says as the drive comes back. `k01_breath` Somewhere deep in the hull, something
long-dead draws its first breath. · `k02_patient` She runs cold and quiet now — patient, like
she's waiting for a word. · `k03_thread` A thread of blue jump-light crawls the length of the
hull, and fades. · `k04_ember` One ember left to find now — the heart that lights the rest. ·
`k05_locked` Course locked — and for the first time in a long time, a destination. ·
`k06_veins` The drive's veins. Until they run, no fire can move through her.

### L · the crew, aboard — 10 cards, all ✎

Idle lines from the ship. `l01_borrowed` (MIRA) Oxygen is just borrowed plant breath. I like
that we owe them something. · `l02_rain` (MIRA) I hope Haven has rain. Real rain. ·
`l03_ugly` (JUNO) HELIOS builds ugly. When we're gone, that's all Earth gets to look at. ·
`l04_stocked` / `l05_bandages` (SOLA) · `l06_charting` / `l07_copies` (VEGA) · `l08_wrench` /
`l10_shop` (HALE) · `l09_species` (MIRA).

### M · more death-screen lines — 5 cards, all ✎

`m01_gauge` You watched the ore, not the gauge. · `m02_novein` No vein is worth the last
breath. · `m03_keeps` The Reach doesn't bury its divers. It keeps them. · `m04_greed` Greed
weighs more than a full tank. · `m05_others` Out too long — same as all the others.

### N · what you are digging up — 9 cards, all ✎

Real element trivia straight out of the game's own database, for the mining sequences.
`n01_iridium` A worldwide layer of it marks the asteroid that ended the dinosaurs. ·
`n02_caesium` Its vibration defines the exact length of one second. · `n03_astatine` Less
than a gram exists on all of Earth at once. · `n04_uranium` · `n05_carbon` · `n06_iron` ·
`n07_erbium` · `n08_radium` · `n09_unknown` A rare element drawn from the dark. Records are
incomplete out here.

### O · the trader — 4 cards, all ✎

VESNA. `o01_vesna_haven` Haven's real. An exile swore she flew there and the sweeps never
touched her. · `o02_vesna_expanse` · `o03_vesna_hum` · `o04_vesna_gold`.

### P · more HELIOS, more written — 12 cards

`p01_catalogued` ✎ Contaminant unit persists in this sector. Catalogued. Correction pending. ·
`p02_quiet` ✎ Anomalous drive signature detected. You were meant to go quiet. · `p03_jammed`
It is drowning the long band. A stronger core punches through. · `p04_notaudit` It is not
hunting you. It has simply stopped counting you. · `p05_signedoff` Every system it runs was
signed off by someone. · `p06_appeal` The audit closed years ago. Nobody filed an appeal. ·
`p07_patient` It has all the time there is. You have a tank. · `p08_smallest` The smallest
unit of resistance is one more shift. · `p09_manifest2` You do not beat HELIOS. You leave, and
you take people with you. · `p10_ledger` It kept a ledger of the whole species. You are the
correction. · `p11_wall` There is a wall of fire across the inner dark. · `p12_onlyway` One
drive. One crossing. No second run.

## The asset sheets — 29 of them

One PNG per art family, art fitted (never stretched) on a checker so transparent sprites
read as transparent. The count in each heading is generated from the folder, so it cannot
drift out of date.

| sheet | count | what it shows |
|---|---:|---|
| `01_elements` | 103 | in-world vein icons, labelled by symbol and name |
| `02_element_art` | 144 | inventory / trivia-card art |
| `03_stations` | 10 | every survivor station, full size |
| `04_crew` | 26 | the five crew — figures, ID cards, tokens, wrecks, quarters |
| `05_breach_cards` | 97 | the duel's card art |
| `06_breach_map` | 80 | corridor tiles and node art |
| `07_breach_props` | 24 | deck props |
| `08_breach_icons` | 25 | node icons |
| `09_salvage` | 191 | salvage and derelict parts |
| `10_devices` | 215 | ship device animation frames |
| `11_walk` | 36 | walk cycles |
| `12_astro_gear` | 16 | the astronaut and the suit gear |
| `13_comets` | 28 | comets and shooting stars |
| `14_breach_themes` | 12 | per-station breach themes |
| `15_title_cards` | — | the title cards, as one sheet |
| `16_craftables` | 127 | the full fabricator catalogue |
| `17_ship_tileset` | 48 | interior floors, walls, corners |
| `18_wrecks` | 20 | the derelicts that drop recipes |
| `19_crew_dialog` | 59 | dialog portraits, every expression |
| `20_crew_idle` | 150 | crew idle animation frames, one loop per row |
| `21_crew_roster` | 10 | roster + radar avatars |
| `22_breach_anims` | 102 | node icon animations, one loop per row |
| `23_breach_legacy` | 29 | fallback icons, FX, and the legacy paper-chart set |
| `24_astro_anim` | 26 | EVA animation frames |
| `25_particles` | 7 | particle textures |
| `26_intro` | 5 | intro cutscene panels |
| `27_logo_anim` | 9 | logo animation frames |
| `28_loose` | 6 | logo, title plate, ship, suit, pickups |
| `29_originals` | 6 | pre-pixelation source art (vault, reference only) |

**Just under 1,900 pieces of art**, and that is only what is filed under `assets/` — it
excludes everything drawn in code. SVG assets (`assets/icons`, `assets/ui`) are not sheeted:
the builder loads raster images only.

## Re-recording

```
powershell -File tools/record_trailer.ps1                     # everything
powershell -File tools/record_trailer.ps1 -Only duel_mid,gather_a
powershell -File tools/record_trailer.ps1 -VerifyOnly       # just re-check what is on disk
```

The clip table lives in `tools/trailer.gd` and the runner reads it from there
(`SW_CLIP=__list__`) rather than keeping a second copy — the two drifted the first time a
clip was added.

`tools/trailer_cards.gd` writes the title cards. `tools/sheet.gd` plus
`tools/build_sheets.ps1` / `tools/build_sheets2.ps1` write the asset sheets, and double as a
contact-sheet builder for reviewing stills.

To eyeball a clip without recording it, set `SW_TRAILER_PNG=<dir>` and it drops one still
per second alongside. Every clip in this folder was checked that way — four separate takes
ran without a single error while showing the wrong thing entirely.
