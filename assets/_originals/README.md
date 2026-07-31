# Original ship art — DO NOT DELETE

Pre-pixelation masters for the six ships. The v0.233 pass rewrote the live files in place at
x3 (player hull) / x7 (crew wrecks); that conversion is **lossy and one-way**, so these are the
only way back short of git history.

- `ship_hd.png` — the player's hull (340x240)
- `{juno,hale,mira,sola,vega}_wreck.png` — the rescuable crew's wrecks (1236x1002)

The `.gdignore` beside this file keeps Godot from importing them, so they cost nothing at
runtime and never reach an export. To restore one, copy it back over the live path and re-import.
