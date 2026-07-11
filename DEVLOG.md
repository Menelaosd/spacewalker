# Spacewalker — Dev Log

Core updates to the game, newest first. Every meaningful change lands here.
(Format: date · what changed · why it matters.)

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
