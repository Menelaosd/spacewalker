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
| WASD | Thrusters (zero-g drift) — or walk, when inside the ship |
| Hold LMB | Laser pistol — mine asteroids |
| E | Enter the ship (while docked) · interact with a station (inside) |
| R | Restart run |

The top-right **gear rack** shows your four tools — suit, lifeline, O2 tank,
laser — with their current stats, so upgrades read back at a glance.

## Loop
1. Leave the ship → oxygen starts draining, lifeline pays out.
2. Laser asteroids → they shatter into ore chunks that magnet to you.
3. Cyan asteroids are rich — double ore value.
4. Return to the dock ring → ore banks, O2 refills.
5. O2 hits zero → blackout: reeled back to the ship, carried ore lost.

Some asteroids sit **beyond** tether range on purpose — tether upgrades reach them.

## Inside the ship
Dock, press **E**, and you step inside — the "restaurant half" of the loop.
Walk (WASD) between six rooms drawn to resemble a real ship:

- **Upgrade Bay** — three consoles. Stand at one, press **E** to spend banked
  ore: O2 tank capacity, lifeline length, or laser power. Costs scale each level.
- **Cargo Hold** — a crate stack that grows with your banked ore.
- **Airlock** — press **E** to suit up and head back out on a spacewalk.
- **Bridge / Quarters / Engine Room** — flavour rooms (forward window, bunk,
  pulsing reactor) waiting to become real systems.

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
