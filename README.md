# SPACEWALKER

Dave the Diver, but in space. You live on a small ship and do spacewalks to
mine asteroids — as long as your oxygen holds and your lifeline (tether) reaches.

**Working title.** Everything visual is placeholder `_draw()` shapes, made to
resemble the real thing so we can swap in sprites later without touching logic.

## Requirements
- Godot **4.7** (standard build, GDScript)

## Run
Open the folder in Godot (Import → select `project.godot`) and press F5.

## Controls
| Input | Action |
|---|---|
| WASD | Thrusters (zero-g drift) · walk (inside) · fly (helm) |
| Hold LMB | Laser pistol — mine asteroids |
| E | Enter the ship (docked) · interact (inside) · park/dock (flight) |
| Q | Leave the helm (flight) |
| I | Cargo manifest (inventory) |
| Esc | Pause menu — save, quit to title |

The game starts on a **title screen with 3 save slots** — resume or start
fresh. Progress **auto-saves** at safe moments (banking, entering the ship,
parking) and manually from the pause menu. Saves live in Godot's user dir.

The bottom-right **gear rack** shows your four tools — suit, lifeline, O2 tank,
laser — with their current stats, so upgrades read back at a glance.

## Loop
1. Leave the ship → oxygen starts draining, lifeline pays out.
2. Laser asteroids → they shatter into resource chunks that magnet to you:
   **rock chunks** from common rocks, **crystal chunks** (double value) from
   cyan ones.
3. The lifeline has stretch — past its rated length it strains like a bungee
   (gold → red) and pulls you back; you can't out-thrust a fully drawn line.
4. Return to the dock ring → cargo banks, O2 refills.
5. O2 hits zero → you faint and wake in your bunk — carried cargo lost.

## The periodic table is the loot table
Banked chunks refine into **real elements at real solar abundances** (83
long-lived elements, IUPAC names, present-day solar atom-%). Rock gives the
condensed elements — mostly O/Si/Mg/Fe, with gold in **micro**-units and
uranium in **nano**-units, exactly as rare as the universe makes them.
Crystals concentrate heavies tenfold (true ratios preserved). Gases — H, He,
Ne & co — can't be mined from rock at all: **fly through a nebula and scoop
them**. Press **I** (or Tab) for the inventory: EXOSUIT panel (character +
gear) and the full element grid, X/83 collected.

Some asteroids sit **beyond** tether range on purpose — tether upgrades reach them.

## Inside the ship
Dock, press **E**, and you step inside — the "restaurant half" of the loop.
Walk (WASD) between six rooms drawn to resemble a real ship:

- **Upgrade Bay** — three consoles. Stand at one, press **E** to spend banked
  ore: O2 tank capacity, lifeline length, or laser power. Costs scale each level.
- **Bridge** — take the helm (pilot chair, **E**) to fly the ship (see below).
- **Cargo Hold** — a crate stack that grows with your banked ore.
- **Airlock** — press **E** to suit up and head back out on a spacewalk.
- **Quarters / Engine Room** — flavour rooms (bunk, pulsing reactor) waiting
  to become real systems.

## Flying the ship
From the Bridge helm you pilot the ship externally through **infinite,
deterministically generated space** (same coordinates = same rocks, always).
Fly near a field and press **E** to park — your next spacewalk happens
there. Dock back at home (E in the home ring) or press **Q** to leave the
helm and walk the ship.

Space has **a plan**, not uniform noise — regions ring the home station,
and the HUD names where you are:

| Region | Where | Character |
|---|---|---|
| Home Reach | < 30 km | sparse, small practice rock |
| The Drift | 30–60 km | baseline fields |
| **The Belt** | 60–90 km | dense ring of big, earth-tinted rock |
| **The Expanse** | 90 km+ | vast and empty — rare, huge, rich fields |
| **Nebulae** ×4 | fixed landmarks | colored dust, crystal-rich, tinted rock |

Where you park changes the dive: asteroid count, size, palette and richness
all come from the region (`GameState.region_at`).

## Art pipeline
Sprites are generated pixel art — authored as ASCII art + shape code in
`tools/gen_sprites.gd`, rebuilt with:
```
godot --headless --path . -s res://tools/gen_sprites.gd
```
One palette drives the whole style. Asteroids remain procedural `_draw()`
polygons on purpose (per-rock variety).

## Structure
```
scenes/    main, player, ship, asteroid, pickup, hud, ship_interior
scripts/   one .gd per scene + game_state.gd (autoload: oxygen/cargo/gear stats)
           + gear_panel.gd (HUD gear icons) + interior_player.gd
```
Gear stats (`max_oxygen`, `tether_length`, `laser_dps`) and the upgrade system
(`upgrade_cost` / `try_upgrade`) live in `GameState`. Banked ore is the currency.

## Git
```
git init
git add .
git commit -m "Initial Spacewalker prototype (Godot 4.7)"
git remote add origin git@github.com:YOURUSER/spacewalker.git
git push -u origin main
```
`.godot/` is ignored; commit the `*.import` files Godot generates next to assets.

## Roadmap ideas
- ~~Ship interior scene (the "restaurant" half of the loop: buy upgrades)~~ ✅ done
- ~~Upgrades: tether length, O2 tank, laser power~~ ✅ done — cargo magnet still open
- Hazards: drifting debris, solar flares, tether snag
- Real pixel-art sprites + Web Audio-style synth SFX
- GodotSteam (achievements, cloud saves) once there's a Steam App ID
