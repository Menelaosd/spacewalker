# ART DIRECTION — "COLD PROTOCOL" (clinical / cold-horror hacking)

The breach aesthetic: **sterile spaces gone wrong.** Institutional emptiness under bad light.
Dread from restraint, not neon/gore. If a frame looks "cool/colorful," it's wrong.

## Palette (hex)
~85% of every frame is sterile neutrals; ≤15% is ONE accent family.
- Void black: `#05070A`–`#0C1014` (never true 0)
- Gunmetal/brushed steel: `#1B2026`–`#2E353D`
- Institutional grey-blue: `#3A434C`–`#556069`
- Bone/scuffed ceramic white: `#B9BEC2`–`#D6DADB` (never pure white)
- **PLAYER accent — cold clinical cyan-white:** `#7FD4D6`–`#A9E4E1`, emissive `#CFF6F2`. "Yours," surgical, inhuman-clean.
- **THREAT/ICE accent — sickly amber→bilious green:** amber `#C8862B`/`#D89A3A` (active lockout), green `#6E7A2E`–`#93A24B` (corrupted/infected).
- **Panic red — rare, "irreversible":** `#8E1F14`–`#B4342A`. Once per encounter at peak, never decoration.
- AVOID: saturated neon, magenta/purple, rainbow variety, warm cozy tones, pure primaries. Accent saturation ≤55–65%; neutrals ≤12%. Cyan + amber rarely share a frame (= a confrontation).

## Lighting (Godot)
Low-key, high-contrast, single cold source; most of the screen in shadow.
- One dominant cold light per space (color ≈ `#AEC4CC`); fill near-zero; ambient tiny (`#0E141A`, energy 0.15–0.3). Key:fill ≈ 8:1+.
- Tonemap AGX/Filmic, `adjustment_saturation` 0.75–0.85, `adjustment_contrast` ~1.15, brightness <1.
- Fog: `fog_light_color` `#0B1116`, density 0.02–0.05, aerial perspective ~0.3; distance dissolves to black.
- Emission is the ONLY saturated thing and it's dim (`emission_energy` 1–2) — screens, warning strips, tools, ICE tells.
- Bloom kept but barely: `glow_intensity` 0.2–0.35, `glow_bloom` ~0.05, high `glow_hdr_threshold` (~1.1) so ONLY emissives bloom. (NB: current breach bloom is stronger — dial it DOWN toward this for the redesign.)
- CRT/scanline/chromatic only on terminal screens, never full-screen.

## Materials — "cleanliness turned wrong"
Brushed steel (rough 0.35–0.6, metallic 0.9, fingerprint/scratch). Scuffed medical ceramic (matte 0.7–0.85, hairline cracks, yellowed aged white `#C9C6B8`). Frost/condensation rime on edges. Grime accumulates in corners/seams (AO), not random. Blood/rust punctuation only (<5%): old blood brown-black `#3A211C`, rust `#5A3B2A` streaks. Organic corruption = wet shiny bio-film where everything else is matte. Screens: dark degraded glass, dead-pixel columns, burn-in.

## Icons & cards
- **Node icons:** abstract > literal — schematic/blueprint diagnostic symbols, thin 1–2px linework, hairline containment frame (hex/bracket corners), single accent inner glow on near-black. Player nodes cyan-white; hostile/ICE amber/green; dormant grey.
- **Card portraits:** framed like case-files / specimen scans (bracket corners, data-strip header, ID vibe). Exploits (player) = clean surgical schematic, cyan-white key light. ICE (enemy) = silhouette-forward, backlit, half in shadow/fog, amber/green rim, heavy negative space. Dither shading, no smooth gradients.

## REUSABLE PIXELLAB STYLE SUFFIX (append verbatim)
`, clinical cold-horror sci-fi pixel art, sterile desaturated palette of cold gunmetal grey #1B2026 and bone white #B9BEC2, single restrained accent glow, low-key high-contrast lighting, one cold light source, deep black shadows #05070A, subtle emissive rim glow only, faint cold fog, scuffed brushed-steel and aged-ceramic surfaces, controlled grime in seams, ordered dither shading, no neon, no rainbow colors, no saturated bright hues, no cute or arcade style, oppressive quiet dread, muted and restrained, Alien Isolation and Signalis and Dead Space mood`
- Player assets: swap accent → `single restrained cold cyan-white accent glow #7FD4D6`.
- Threat assets: swap accent → `single restrained sickly amber-green warning accent glow #C8862B and #93A24B`.

## UI/typography
Institutional degraded monospace; cyan-white on near-black; thin hairline rules + bracket corners `[ ]` + tick marks; diagnostic-tool feel, not game HUD. Motion slow/mechanical, no bouncy easing, errors flash once coldly (no celebratory juice). Lots of dead space, grid-locked, left-aligned — empty = tense.

Cheat: frame ≈85% neutral / ≤15% one accent · cyan-white = you, amber/green = threat, red = rare/irreversible · emission is the only saturated thing and it's dim · desaturate globally, crush shadows, fog the distance · wrongness = shiny-where-should-be-matte + corner grime + one handprint over a splatter.

Touchstones: Alien: Isolation, Dead Space, Signalis, System Shock (2023), Observation, SOMA, Hacknet/Netrunner terminal UIs.
