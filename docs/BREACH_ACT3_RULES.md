# Breach Duel — Inscryption Act 3 Rules + Design Report

(Auto-generated from an 18-agent research/design workflow, 22/07/2026.)

# SPACEWALKER — BREACH DUEL FINAL REPORT (Act 3 / P03 model)

Source of record: `C:/Users/menel/OneDrive/Έγγραφα/games/spacewalker-godot47/scripts/breach_duel3d.gd`
Icon assets: `C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/cf45e486-8764-4be3-bb51-d6dafa43276d/scratchpad/`

---

## 1 — CANONICAL ACT 3 RULESET (precise)

**Energy model** `[high]`
- Sole resource is Energy — no blood/bones. Turn 1 = max 1; +1 max at the start of each of your turns; hard cap 6 (ramp 1→2→3→4→5→6 over turns 1–6).
- Full refill to current max each turn; unspent energy does NOT carry over.
- Card cost range 0–6; cost-6 cards effectively unplayable before turn 6.
- **Battery Bearer** sigil is the one card-based ramp: on play, +1 current AND +1 max (still capped at 6).

**Turn / combat flow** `[high]`
1. Start of turn: refill + max +1 (cap 6); draw 1 (main deck OR one Empty Vessel from side deck).
2. Play phase: spend energy, place into empty lanes, use activated sigils.
3. Ring the Bell → attack phase.
4. Cards attack left→right, one at a time, each hitting the space directly opposite. Occupied → defender loses Health = attacker Power. Empty → hits the Scale directly (1 Power = 1 tick).
5. P03 plays and attacks the same way. Repeat until Scale ±5.

**Win condition — the Scale** `[high]`
- Tug-of-war net damage differential; win at +5, lose at −5; only the difference matters. Same threshold across all three acts.
- **FLAG:** the "deal 12 direct damage in 6 turns or explode" rule is ONLY for special bomb battles (red danger icon), NOT the general rule. Default is Scale ±5.

**Overkill** `[med]`
- Card-vs-card excess passes to the card directly behind the killed defender; if none, lost (no scale spillover) unless a piercing/multi-strike sigil routes it.
- Scale overkill (past the +5 needed) converts to Robobucks. (Facet 4's denial is the outlier; majority confirm.)

**Board** `[med — CONTESTED]`
- Report 5 lanes (citation weight: Prima, PC Invasion, game-news24, Fandom), but **verify-in-game before hardcoding** — Facets 5 & 7 flag "5" as a possible propagated wiki error vs Acts 1–2's 4 lanes. Head-to-head rows; Hammer item destroys your own board cards.

**Currency — Robobucks** `[high value / low prices]`
- Earned via overkill; spent on packs/sigils/items; dropped on death, recoverable at death spot.
- Well-attested: Buy Extra Card = 8 (show 3, pick 1); Card Recycle payout = 4 base +3/non-default sigil (max 16). Max 4 sigils per card.
- **FLAG (unresolved):** Add-a-sigil = 15 (Facet 6) vs 10 +5 per subsequent (Facet 8) — treat as version-dependent. Nano Armor ~26 `[low, single source]`.

**Card stat/cost norms** `[med]`
- ~1 stat point per energy at low cost; efficiency deliberately DROPS at high cost — premium cost buys sigils, not stats. Common bodies 1–3 energy; premium 5–6; 4-cost sparse; 0-cost ≈ Empty Vessel / Sapphire-gemified only.
- Canonical starter lines: Energy Bot 0/1 c2 (Battery Bearer), Shieldbot 1/1 c2 (Nano Armor), Sniper Bot 1/1 c3 (Sniper), Double Gunner 2/1 c6 (Bifurcated Strike). Empty Vessel 0/2 c1.

**Sigils (key set)** `[high unless noted]`
- Strike/targeting: Sniper (owner chooses target space — Act 3's free-target sigil, NOT "Marksman"); Double Strike (opposite ×2); Bifurcated Strike (both diagonals, 2 hits); Trifurcated Strike (left+opposite+right, 3 hits). Stacks: Bi+Double=4, Tri+Double=6.
- Damage/retaliation: Sharp Quills (1 back per hit); Sentry (1 dmg to enemy entering opposite space); Detonator/Explode (on death, 10 dmg to opposite+left+right incl. friendlies; not on sacrifice, yes on hammer; blocked by Nano Armor); Energy Gun (pay 1 energy → 1 dmg opposite).
- Defensive: Nano Armor/DeathShield (first damage instance fully prevented, absorbs Deathtouch); Made of Stone (immune instant-death/poison, not ordinary dmg); Overclocked (+1 Power but permadeath).
- Conduits (circuit = 2 conduit cards, same row, different lanes; powers spaces between; breaks if either dies; chains): Attack Conduit (+1 Power to circuit — **FLAG:** "+2" is a wiki artifact, that +2 belongs to Buff-When-Powered); Energy Conduit (energy never depletes); Gem/Spawn/Healing/Null conduits; Battery Bearer.
- Powered (active only in circuit): Buff When Powered (+2 Pwr), Trifurcated When Powered, Gift When Powered.
- Latch: Bomb Latch → Detonator; Brittle Latch → Brittle. Misc: Transformer, Airborne, Mighty Leap, Waterborne.

**Gems/Mox** `[high]` — Empty Vessels auto-upgrade into Mox Vessels; effect needs a matching gem in play on your side: Emerald → +2 HP, Ruby → +1 Pwr, Sapphire → −1 energy cost. Same colour doesn't stack; different colours do. Gembound bearer dies if no Mox on your side.

**Deckbuilding** `[high]` — Starting deck exactly 4 cards (1 each of the four starters), no alterations. No max deck size / no duplicate limit. Side deck = unlimited Empty Vessels (0/2, c1, can't be sacrificed), 1 per turn, progressive upgrades apply to ALL at once. NO deck-totem mechanic in Act 3. Hammer = in-battle self-destruct, distinct from Card Recycle.

**Enemies** `[med]` — P03 = narrator, not a mid-boss. Beat 4 Uberbots (Photographer/NE, Archivist/SE, Painter/SW, G0lly/NW) → scripted P03 finale. Bounty Hunters = dynamic difficulty (win streak → Power = rand[6,10] × bounty level, uncapped; resets only on defeat). Secret boss Mycologists → Mycobot.

**Cross-cutting:** Kaycee's Mod has NO energy cards (Act-1 only); for a repeatable energy roguelike reference the community mod P03KayceeMod. Verify in-game before hardcoding: lane count, disputed shop prices, unstarred card stat lines.

---

## 2 — BALANCE ANALYSIS

**How canon balances itself**
- Energy is the master clock: one scarce non-storable resource ramping 1→6 forces a guaranteed early/mid/late arc, makes every turn a spend-it-all budget puzzle (Battery Bearer the sole ramp lever), and stays symmetric since P03 rides the same curve.
- Value-per-cost is curved, not linear: ~1 stat/energy low, efficiency DROPS as cost rises — high cost buys effects, not bulk. This is the anti-power-creep rule that keeps cheap bodies relevant.
- The Scale (±5 net) keeps games short, swingy, fair: chip and one big empty-lane hit share the same axis; overkill into the Scale funds Robobucks instead of being wasted. Determinism (left→right, opposite lane), walls that truly wall (overkill spills behind, not to Scale), and dynamic Bounty scaling keep it honest.

**Our duel (`breach_duel3d.gd`) vs canon**

*Matches (good):* Scale ±5 (`WIN_TIP=5`); 5 lanes (`LANES=5`); energy model (`_turn_start` L1337 — start 1, +1/turn, full refill, no carryover); Battery Bearer (`overcharge` L1064 — +1 max & +1 current before cost, capped); left→right opposite resolution with overkill spill to the queued unit (`_resolve_hit` L1166); queue-advance-then-strike order (`_advance_opp`).

*Defensible deviations:* Energy cap 5 not 6 (`MAX_ENERGY=5`), player costs top out at 4 — curve compressed by one (finisher ~turn 4). AI pays no energy (all enemy cards cost 0, L69) — throttled only by `per_turn` queue fill; biggest structural departure. Static 3-tier `OPP_DECKS` instead of Bounty scaling. Bespoke `overflow` sigil routing excess to the trace.

*Balance risks (flagged):*
1. Player top-end cards break the value-per-cost curve — they get stats AND sigils: `power_overload` 4/2 c3 + overcharge (2.0 stat/energy + ramp sigil, most undercosted); `buffer_overflow` 5/1 c4 + pierce; `sentinel_ghost` 2/5 c4 + sniper; `thermite_charge` 3/2 c3, `chain_reaper`/`hydra_swarm` 3/3 c4. All 1.5–2.0 efficiency where canon wants it to drop.
2. Starter deck ships all six bombs; the `(11)` comment is stale — `PLAYER_DECK` (L88) actually holds 17 cards, so bomb-heavy opening hands are common.
3. AI can't credibly reach −5: enemy cards mostly 0–3 power, placed into random lanes (`_opp_fill_queue` L1371, no targeting), no ramp/finisher, while the player has unlimited scrap-mite chump blockers (L991).
4. Ramp-stacking (three `overcharge` cards) can push `energy_max` to 5 ahead of the clock, landing cost-4 bombs turn 3.
5. Sniper + overflow + empty-lane trace is a one-sided snowball the AI can't punish.
6. Minor: turn 1 skips the draw (canon draws turn 1); many header-listed sigils are labelled but unimplemented.

*Bottom line:* the engine is a faithful, slightly-compressed Act-3 model; the risk is entirely on the card table. Expect the duel to skew easy/one-sided until the six strong cards are pulled toward canon efficiency (drop stats, keep the sigil) or the AI gets a real trace-pressure threat. Fix the stale `(11)` comment.

---

## 3 — NORMAL GAMEPLAY FLOW (typical Act-3 match)

- **Turn 1 (E 1/1):** Nothing in the starter four is affordable. Pull a free Empty Vessel (0/2, c1) as a wall opposite P03. Ring — no offense. P03 chips your Vessel or taps the Scale. Scale ≈ 0 to −1. Being slightly behind is correct.
- **Turn 2 (E 2/2):** Play Energy Bot (c2). Its Battery Bearer fires on play (+1 current, +1 max) — you're now at max 3, a full turn ahead of the ramp. Place it in a safe lane; a 0/1 dies to a breeze and it's your ramp engine. Scale −1 to −2: behind on board, ahead on tempo — a winning position that doesn't look like one.
- **Turn 3 (E 3–4):** Stop stalling — play Sniper Bot (c3). Sniper lets you choose its target every turn, ignoring "opposite"; funnel its 1 onto the Scale through a gap, or pick off a threat. Board now three deep; bleed stops. Scale −2 → −1.
- **Turn 4 (E 4–5):** Play Shieldbot (c2). Nano Armor eats the first hit of anything; drop it opposite P03's scariest attacker. Often a second play too (another Vessel). Your filled row means P03's damage now hits your bodies, not the Scale, while Sniper Bot keeps taking the optimal hit. Scale back to ~0, maybe +1.
- **Turn 5 (E 5–6):** Real money. Board stable, trades even, Sniper + open-lane hits tick toward +5. Overkill on the Scale converts to Robobucks — over-hitting is income. Scale +2 to +3.
- **Turn 6+ (E 6/6):** Double Gunner (c6, 2/1, Bifurcated Strike) finally online — the closer you held all game. Place it where both opposite diagonals are empty → two 2-Power hits straight to the Scale = 4 Scale damage in one attack, tipping +2/+3 past +5, match ends instantly. If diagonals are occupied, Sniper clears one first or Double Gunner trades while Sniper delivers the final tick.

*Shape of a normal win:* survive the poor turn-1 economy, ramp one card ahead with Battery Bearer, trade so P03's attacks hit your cards instead of the Scale, and let Sniper Bot + a turn-6 Double Gunner do the Scale-tipping. The Scale climbs slowly for four turns, then falls over fast on the last two. You rarely out-body P03 (he out-draws you) — you out-trade him.

---

## 4 — ICON SETS (by category)

Base dir: `.../cf45e486-8764-4be3-bb51-d6dafa43276d/scratchpad/`
**Failures: none.** All 40 files verified as valid PNGs. Two strike icons (05 javelin dart, 09 vertical bolt-arrow) and the matching two arrow icons were regenerated once and re-verified. PixelLab enforces a concurrent-job cap (1), so batch fan-out serialized via retry — relevant for future generation.

**A. STRIKE / EXECUTE keys (`ic_strike_01..10`, 64×64, cyan+amber-red)**
- 01 `ic_strike_01.png` — hexagonal EXECUTE actuator button
- 02 `ic_strike_02.png` — downward cyan lightning bolt, red glow
- 03 `ic_strike_03.png` — red alert circular warning strike control
- 04 `ic_strike_04.png` — armored fist slamming down
- 05 `ic_strike_05.png` — tapered javelin dart, up *(regenerated)*
- 06 `ic_strike_06.png` — commit/seal glyph, red core
- 07 `ic_strike_07.png` — curved fang/spike, red tip
- 08 `ic_strike_08.png` — diagonal blade slash, amber trail
- 09 `ic_strike_09.png` — GO dial rotary knob *(now vertical bolt, regenerated)*
- 10 `ic_strike_10.png` — targeting reticle + execute crosshair

**B. DIRECTIONAL ARROWS (`ic_arrow_01..10`, 64×64, cyan, no-background)**
Generator: `.../scratchpad/gen_arrows.mjs` (concurrency pool 2 + 429 retry)
- 01 solid up chevron/arrow · 02 filled triangle marker · 03 neon hollow outline · 04 double-chevron · 05 tapered dart *(regen)* · 06 arrow + reticle · 07 pointer + halo beam · 08 classic shaft + head · 09 lightning-bolt arrow *(regen, now vertical)* · 10 chunky blocky wide arrow
- Files: `ic_arrow_01.png` … `ic_arrow_10.png`

**C. BATTERY PAIRS (`ic_batt_01..10` × empty/full = 20 files)**
- 01 vertical cell · 02 horizontal bar · 03 hexagon · 04 orb · 05 capsule · 06 diamond · 07 chip · 08 vial · 09 plus-cell · 10 segmented rod
- Files: `ic_batt_0N_empty.png` + `ic_batt_0N_full.png` for N=01..10

---

## 5 — GAUGE DESIGN CATALOG (Scale ±5 HUD, 10 concepts)

Shared drivers: `tip` (discrete lit state), `_tip_anim` (smooth position, `norm=clampf(_tip_anim/WIN_TIP,-1,1)`), `_t` (idle shimmer / near-lock strobe at `abs(_tip_anim)>=4`), `ncol = CYAN if _tip_anim>0 else RED`, `s`/`_fs()` scaling. Studied at `_hud_scale` L1634.

1. **Trace Dial** — decryption needle across a 156° arc, one tick locking per trace point (current baseline).
2. **Intrusion Column** — vertical glass standpipe: cyan floods up to CRACK, red drains down to EJECT.
3. **Two-Runner Race** — two processes sprint from opposite ends toward a central contested node.
4. **Lock Pips** — 11 diamond sockets, each fills solid as the trace crosses it, center neutral.
5. **Signal Trace** — oscilloscope baseline that spikes toward your side per tick (live waveform).
6. **Trace Core** — monolithic bracketed countdown number ringed by a thin depletion arc; brutalist.
7. **Orbital Lock** — a marker orbits a node, climbing to the cyan pole (CRACK) or sinking to red (EJECT).
8. **Split Membrane** — one bar with a movable seam; cyan pushes right, red pushes left, seam = value.
9. **Ascent Ladder** — 11-rung ladder, a lit shuttle climbs to CRACK / falls to EJECT.
10. **Pressure Valve** — half-round boiler gauge with red danger + cyan overpressure zones; needle in red = being ejected.

**Recommendation: #8 Split Membrane.** It reads a signed tug-of-war most intuitively (one bar, one seam, territory ownership obvious at a glance), animates smoothly from `_tip_anim`, floats an exact `%+d`, and needs the least screen space. #4 Lock Pips is the best runner-up if you want discrete-lock clarity over a continuous seam; #10 Pressure Valve is the most thematic if you want drama over readability.

---

## 6 — ENERGY DESIGN CATALOG (energy HUD, 10 concepts)

Shared state: cells `[0..MAX_ENERGY)`; `< energy` = filled cyan; `[energy_max..MAX_ENERGY)` = ghost; `[energy-sel_cost, energy)` = amber spend-preview; last filled cell pulses `0.5+0.5*sin(_t*3)`. All reuse existing members/constants; no new state. Studied at strip L1596–1631.

1. **Segmented Strip** — five flat bars, spend eats from the right in amber (current baseline, refined).
2. **Orb Row** — glowing capacitor orbs; charged bloom, spend-preview flips to a hollow amber ring.
3. **Vertical Cells** — stacked plates filling bottom-up like a loaded battery rack; hugs a screen edge.
4. **Single Battery Bar** — one continuous cyan bar in a bracket + nub; amber overlay = drain slice.
5. **Radial Ring** — small arc gauge sweeping per pip (matches the nearby TRACE LOCK dial language).
6. **Dot Matrix** — compact grid of tiny pips, one lit column; old-avionics charge readout.
7. **Filling Vial** — rounded reactor flask with liquid line + bubble; fluid level = energy.
8. **Hex Cells** — honeycomb capacitor cells; charged fill solid, preview outlines amber.
9. **Numeric + Mini-Bar** — big cyan number hero + hairline underbar + "−cost" tag; most discreet.
10. **Ammo Clip** — magazine of side-view rounds; spend chambers the top rounds amber, reads as a resource you fire.

**Recommendation: #10 Ammo Clip** (with #2 Orb Row as the safe alternative). Ammo Clip keeps discrete-pip clarity — critical for a 5-cost curve where exact count matters — while looking distinctly different from the current strip and reinforcing "energy = ammunition you fire." #2 Orbs give the same discrete clarity with a softer sci-fi look and the simplest draw code. Avoid #4/#7 for the primary readout: continuous fills animate smoothly but read energy as a ratio, blurring the exact pip count the curve depends on. Use #9 only if you need the HUD truly out of the way.

---

# APPENDIX A — Full reconciled ruleset

# Inscryption Act 3 (Botopia / P03) — Canonical Ruleset

Reconciled from 9 research facets. `[C:high/med/low]` = confidence. **FLAG** marks resolved contradictions.

## 1. ENERGY MODEL `[C:high — unanimous]`
- Resource is **Energy** only. No blood/bones sacrifice.
- **Turn 1: max 1 energy.** Max **+1 at the start of each of your turns**, hard **cap 6** (ramp 1→2→3→4→5→6 over turns 1–6).
- **Full refill to current max each turn.** Unspent energy does NOT carry over.
- **Card cost range 0–6.** Cost-6 cards effectively unplayable before turn 6.
- **Battery Bearer** sigil: on play, **+1 current AND +1 max** (still capped at 6) — the one card-based ramp exception.

## 2. TURN / COMBAT FLOW `[C:high]`
1. Start of turn: energy refills + max +1 (cap 6); **draw 1** (from main deck OR pull one Empty Vessel from side deck).
2. Play phase: spend energy, place cards into empty lanes, use activated sigils.
3. **Ring the Bell** → attack phase.
4. Cards attack **left→right, one at a time**, each hitting the **space directly opposite**.
   - Opposite occupied: defender loses Health = attacker Power.
   - Opposite empty: hits the **Scale** directly (1 Power = 1 tick).
5. Opponent (P03) plays and attacks the same way. Repeat until Scale ±5.

## 3. WIN CONDITION — The Scale `[C:high]`
- Tug-of-war **net damage differential**. Win at **+5** in your favor; lose at −5. Only the difference matters. Same threshold across all three acts.
- **Special bomb battles only** (red danger icon): "deal 12 direct damage in 6 turns or explode." **FLAG:** several guides mis-state this as the general rule — it is NOT. Default is Scale ±5.

## 4. OVERKILL `[C:med]`
**FLAG (Facet 1/5/8 vs Facet 4):** Resolution —
- **Card-vs-card excess:** passes to the card **directly behind** the killed defender; if none, **lost** (no scale spillover) unless a piercing/multi-strike sigil routes it.
- **Scale overkill** (damage past the +5 needed to win) → converts to **Robobucks** (Act 3 currency). Majority of sources confirm Robobucks; Facet 4's denial is the outlier.

## 5. BOARD `[C:med — CONTESTED]`
**FLAG — lane count 5 vs 4:** 6 of 9 facets say **5 lanes** (Prima, PC Invasion, game-news24, Fandom Act III snippet). Facets 5 & 7 flag "5" as a possibly propagated wiki error since Acts 1–2 use 4.
- **Resolution:** report **5 lanes** as the sourced/wiki-backed value (weight of citations), but treat as **verify-in-game** before hardcoding grid. Confidence medium.
- Head-to-head rows; **Hammer** item available to destroy your own board cards.

## 6. CURRENCY — Robobucks `[C:high value, low prices]`
- Earned via overkill (§4). Spent on card packs, sigils, items. Dropped on death, **recoverable** at death spot.
- **Prices FLAG (Facet 6 vs Facet 8, both thin):**
  - Add a sigil: **15** (Facet 6) vs **10 +5 per subsequent** (Facet 8) — unresolved, treat as version-dependent.
  - Well-attested: **Buy Extra Card = 8** (show 3, pick 1); **Card Recycle payout = 4 base +3 per non-default sigil** (max 16).
  - Nano Armor (all units): ~26 `[C:low, single source]`.
- Max **4 sigils per card**.

## 7. CARD STAT / COST NORMS `[C:med]`
- Low-cost vanilla ≈ **1 stat point per energy**, efficiency deliberately DROPS at high cost; premium cost buys **sigils, not stats**.
- Common bodies: 1–3 energy. Premium: 5–6 energy. 4-energy sparse. 0-cost ≈ Empty Vessel + Sapphire-gemified only.

| Card | Pwr | HP | Energy | Sigil | Conf |
|---|---|---|---|---|---|
| Empty Vessel | 0 | **2** | **1** | side-deck base *(FLAG: 0/1 & cost-0 variants rejected; purefunc = 0/2 cost 1)* | high |
| Sentry Drone | 0 | 1 | 1 | Sentry | high |
| Energy Bot | 0 | 1 | 2 | Battery Bearer (starter) | med |
| Shieldbot | 1 | 1 | 2 | Nano Armor (starter) | high |
| Sniper Bot | 1 | 1 | 3 | Sniper (starter) | med |
| Automaton | 1 | 1 | 3 | vanilla; P03-only | med |
| Insectodrone | 1 | 1 | 3 | Airborne | med |
| Fishbot | 1 | 3 | 3 | on death spawns fish | high |
| Explode Bot | ~0–1 | 1 | ~1 | Detonator (10 dmg) | low stats |
| Qu177 | 2 | 2 | 5 | transforms → Sharp Quills | high |
| Double Gunner | 2 | 1 | 6 | Bifurcated Strike (starter) | high |
| Swapbot | ? | 2 | 6 | Swapper | low |
| Ourobot | 1→ | 1→ | ? | returns +1/+1 permanently | high mechanic |
| Mycobot | var | var | +2 | keeps final stats (secret-boss reward) | high mechanic |

Provisional (Fandom card pages blocked): Alarm Bot, Swapbot, Explode Bot, Lonely Wizbot exact lines — verify.

## 8. SIGIL CATALOGUE `[C:high unless noted]`

**Targeting / strike**
- **Sniper** — owner chooses target space each turn (Act 3's free-target sigil; NOT "Marksman").
- **Double Strike** — hits opposite space twice.
- **Bifurcated Strike** — skips opposite, hits both diagonal spaces (2 hits). With Sniper: choose 2 targets (may repeat).
- **Trifurcated Strike** — hits left + opposite + right (3 hits). With Sniper: choose 3. Stacks with Double (Bi+Double=4 hits, Tri+Double=6).

**Damage / retaliation**
- **Sharp Quills** — struck bearer deals 1 back per hit received.
- **Sentry** — deals 1 damage to any enemy played/moved into the opposite space.
- **Detonator** ("Explode") — on death, **10 damage** to opposite + left + right neighbors (incl. friendlies). Not on sacrifice; yes on hammer. Blocked by Nano Armor.
- **Energy Gun** — activated: pay 1 energy → 1 damage to opposite card.

**Defensive**
- **Nano Armor** (DeathShield) — first instance of damage fully prevented (one-time shield, all types). Absorbs Deathtouch.
- **Made of Stone** — immune to instant-death & poison/stinky; not ordinary damage.
- **Overclocked** — **+1 Power but permadeath** (permanently removed from deck if it dies).

**Energy / conduit** (circuit = **2 conduit cards, same row, different lanes**; powers spaces **between**; breaks if either dies; conduits chain)
- **Attack Conduit** — others in circuit **+1 Power**. *(FLAG: "Buff Conduit +2" is a wiki artifact — the +2 belongs to the powered sigil below.)* Also on the **Conduit Tower** terrain endpoint.
- **Energy Conduit** — owner's energy **never depletes** while active (no max increase).
- **Gems/Gem Spawn Conduit** — spawns random Gem (Mox) Vessels on empty circuit spaces at end of turn.
- **Spawn Conduit** — spawns L33pB0ts on empty circuit spaces (persist after conduit dies).
- **Healing Conduit** — heals circuit creatures end of turn.
- **Null Conduit** — completes circuit, no effect (endpoint only).
- **Battery Bearer** — see §1.

**Powered sigils** (active only inside a circuit)
- **Buff When Powered** — +2 Power while powered.
- **Trifurcated When Powered** — triple-strike while powered.
- **Gift When Powered** — random card to hand when it dies while powered.

**Latch** (bearer death grants a sigil to a chosen creature)
- **Bomb Latch** → grants Detonator. **Brittle Latch** → grants Brittle.

**Misc**
- **Transformer** — start of turn, swaps to/from Beast-mode stat/sigil profile.
- Standard carry-overs: Airborne (hits scale over blockers), Mighty Leap (blocks Airborne), Waterborne.

## 9. GEMS / MOX (Gaudy Gem Land unlock) `[C:high]`
- Empty Vessels auto-upgrade into **Mox/Gem Vessels**. Effect requires matching gem **in play on your side**:
  - **Emerald (Green) → +2 Health**
  - **Ruby (Orange) → +1 Power**
  - **Sapphire (Blue) → −1 Energy cost**
- Same colour doesn't stack; different colours stack on one card.
- **Gem Dependant (Gembound)** — bearer dies if no Mox on your side (checked at start of turn, end of turn, and on play).

## 10. DECKBUILDING & ACQUISITION `[C:high]`
- **Starting deck: exactly 4 cards, 1 each — Energy Bot, Shieldbot, Sniper Bot, Double Gunner.** No alterations.
- **No max deck size, no duplicate limit.**
- **Side deck = Empty Vessels** (0/2, cost 1, cannot be sacrificed; only >1-HP side-deck card). Unlimited pool, 1 per turn. Progressive upgrades apply to ALL at once:
  - After Uberbot 1: pick Mighty Leap / Nano Armor / Sharp Quills.
  - After 2: Battery Bearer. After 3: Sentry. After 4: Trifurcated Strike.
  - After Mox attachment: → Mox Vessels. NW corner: → Conduits.
- **Acquisition (Robobucks):** Buy Extra Card (8, pick 1 of 3); Card Exchange (swap 1-for-1); Card Recycle (4 +3/sigil, max 16); Add Sigil (~15/10 — see §6); Overclock; Gemify.
- **Build-a-Card (SP economy):** recycle for SP (base 1 +1/added sigil +1 if gemified, max 6), then spend (+1 free start; energy 0–6 → +1 SP each; Health 1 SP/pt range 1–9; Power 2 SP/pt range 0–9; sigils cost power-level, max 4, negatives refund: Annoying +1, Brittle +2).
- **NO deck totem mechanic in Act 3** (Act-1 only). "Totem" here = optional factory puzzle, not deck buff.
- **Hammer** = in-battle self-destruct tool, distinct from Card Recycle.

## 11. ENEMIES / DIFFICULTY (context) `[C:med]`
- **P03 = act narrator, not a mid-boss.** Beat 4 **Uberbots** (one per corner region: Photographer/NE, Archivist/SE, Painter/SW, G0lly/NW), then scripted P03 finale.
- **Bounty Hunters** = scaling difficulty engine: win streak → wanted stars (cap 3 visual, level rises uncapped). **Power = rand[6,10] × bounty level**; HP/sigils scale. Resets only on defeat.
- Secret boss: **Mycologists** (fusion gimmick) → reward Mycobot.

## Cross-cutting notes
- **Kaycee's Mod (official) has NO energy cards** — it's Act-1 only. Energy = Act-3 story mode exclusive. For a repeatable energy roguelike, reference the community mod **P03KayceeMod** (open source, GitHub/Thunderstore).
- All Fandom pages returned HTTP 402/403 to direct fetch across every facet; content came via search snippets + purefunc mirror + independent guides. **Verify in-game before hardcoding:** lane count (§5), disputed shop prices (§6), unstarred card stat lines (§7).

# APPENDIX B — Gauge designs (raw)

Read complete. Current version is a radial decryption dial (`_hud_scale`, line 1634). Available palette: `CYAN Color(0.45,0.9,1.0)`, `AMBER Color(1.0,0.72,0.25)`, `RED Color(1.0,0.35,0.28)`, `PANEL Color(0.05,0.07,0.1)`, `EDGE Color(0.3,0.55,0.7,0.5)`. `WIN_TIP=5`, drivers `tip:int`, `_tip_anim:float`, `_t:float`, scale `s`, font `_fs(px)`.

---

**1. TRACE DIAL (baseline / radial dial)**
Pitch: Decryption needle swings across a 156° arc, one tick locking per trace point.
```
   HELIOS \ | / YOU
      \  \ | /  /
   ·····[ +2 ]·····
       TRACE LOCK 5
```
Draw: `draw_arc(C,R,up-span,up+span,...)` base track + two faction half-arcs at 0.18 alpha; filled sweep `draw_arc(C,R,up,a)` where `a = up + (_tip_anim/5)*span`; 10 radial `draw_line` ticks lit by `tip`; needle via `draw_colored_polygon`; `draw_string("%+d"%tip)` core. Anim: needle rides `_tip_anim`; `if abs(_tip_anim)>=4` a `sin(_t*10)` halo `draw_arc` flares.

**2. INTRUSION COLUMN (vertical thermometer)**
Pitch: A cold glass standpipe — cyan floods up from center toward CRACK, red drains down toward EJECT.
```
 CRACK ▔  +5
      │▓│
      │▓│  ← fill top = _tip_anim
      │█│  center
      │ │
 EJECT ▁  -5
```
Draw: outer `draw_rect(bar,false,2*s)` glass; midline `draw_line`. Fill `draw_rect(Rect2(x, midY - _tip_anim*unit, w, _tip_anim*unit))` in CYAN when positive, mirror downward in RED when negative (`unit = barH/10`). 5 gradations per side as thin `draw_line`s. Anim: a `sin(_t*6)` meniscus highlight line at the fill edge; edge `draw_rect` glow brightens as `abs(_tip_anim)`→5.

**3. TWO-RUNNER RACE (dual advancing race-bars)**
Pitch: Two processes sprint from opposite ends toward a central node; whoever reaches it wins.
```
YOU  ▓▓▓▓▓▓░░░░░░ ◇ ░░░RED  HELIOS
      →→→→→        ←
```
Draw: horizontal track `draw_rect`. Cyan bar from left: length `= (5+_tip_anim)/10 * W`. Red bar from right: length `= (5-_tip_anim)/10 * W`. Center `draw_circle` node = the contested socket; recolor `ncol`. Gap between the two heads shows who's ahead. Anim: leading bar head gets a `draw_rect` scan-flicker `0.4+0.3*sin(_t*8)`; on `tip` change the head overshoots via `_tip_anim` lag then settles.

**4. LOCK PIPS (segmented pips)**
Pitch: Eleven diamond sockets; each fills solid as the trace crosses it, center is neutral.
```
 R R R R R ◇ · · · · ·   → tip=0
 R R R R R ◆ Y Y · · ·   → tip=+2
```
Draw: 11 diamonds via `draw_colored_polygon` (4-pt) spaced along x. Center index neutral. For k in 1..5: right pip filled if `tip>=k` (CYAN), left if `tip<=-k` (RED); unlit = `draw_colored_polygon` at 0.15 alpha + `draw_line` outline. Anim: the newest-lit pip pops — scale its polygon by `1+0.3*(1-frac)` off `_tip_anim` fractional part; imminent-lock pip strobes `sin(_t*12)`.

**5. SIGNAL TRACE (EKG line)**
Pitch: An oscilloscope baseline that spikes toward your side on every trace tick — a live intrusion waveform.
```
 ────╱╲────╱▔▔╲──── +2 baseline lifted
     scope grid, sweep dot →
```
Draw: grid via faint `draw_line` lattice; baseline `y = midY - _tip_anim*unit`. Build a `PackedVector2Array` of the last N samples and connect with `draw_line` segments (ncol). A leading `draw_circle` sweep dot at `x = W*fmod(_t*0.3,1)`. Anim: each `tip` change injects a spike sample; the whole trace lerps its baseline via `_tip_anim`; near ±4 the line jitters with `sin(_t*20)` noise amplitude.

**6. TRACE CORE (big numeric core)**
Pitch: A monolithic countdown number in a bracketed frame, ringed by a thin depletion arc — brutalist and legible.
```
   ┌──────────┐
   │   +2     │  ← _fs(64)
   └──────────┘
   ▁▁▂▂▃▃  distance to lock
```
Draw: `draw_rect` panel (PANEL) + `draw_rect(false)` EDGE frame; corner ticks via 8 short `draw_line`s. Giant `draw_string("%+d"%tip, _fs(64), ncol)`. Below, a thin `draw_arc` or `draw_rect` progress showing `abs(_tip_anim)/5`. Anim: number `modulate`/color pulses `ncol*(0.8+0.2*sin(_t*4))`; on change, a quick `draw_rect` flash frame; at ±4 frame border blinks red/cyan `sin(_t*10)`.

**7. ORBITAL LOCK (orbital ring)**
Pitch: A marker orbits a central node; it climbs toward the cyan pole to CRACK, sinks to the red pole to EJECT.
```
        · Y ·      +5 pole (top)
      ·   ●   ·    ← orbiting marker
        · R ·      -5 pole (bottom)
```
Draw: full `draw_arc(C,R,0,TAU)` faint ring; top semicircle tinted CYAN, bottom RED (two `draw_arc` halves). Marker angle `θ = -PI/2 - (_tip_anim/5)*PI/2` → `draw_circle(C+Vector2(cos θ,sin θ)*R, r, ncol)`. 5 tick nubs per hemisphere. Anim: a trailing comet — 3-4 fading `draw_circle`s behind the marker along recent `_tip_anim`; ring thickness/alpha swells near lock; slow `_t` shimmer on the idle ring.

**8. SPLIT MEMBRANE (split-fill)**
Pitch: One horizontal bar with a movable seam — cyan territory pushes right, red pushes left; the seam is the trace value.
```
 ▓▓▓▓▓▓▓▓▓│░░░░░░░   seam at +2
 CYAN owns │ RED owns
```
Draw: full-width `draw_rect` base. Cyan `draw_rect` from left to `seamX = W*(5+_tip_anim)/10`; red `draw_rect` from seamX to right. Seam `draw_line` bright `ncol`, 3*s wide. 11 `draw_line` gradation notches on top edge; `draw_string("%+d")` floating above the seam, x-tracked. Anim: seam has a `sin(_t*6)` bloom; on `tip` change the seam slides via `_tip_anim` with a brief overshoot ripple (extra alpha `draw_rect` sweep).

**9. ASCENT LADDER (ladder)**
Pitch: An 11-rung vertical ladder; a lit shuttle climbs toward CRACK at top, falls toward EJECT at bottom.
```
 ═ CRACK  +5
 ─
 ─
 ▓ ← shuttle rung (current)
 ─
 ─
 ═ EJECT  -5
```
Draw: two vertical `draw_line` rails; 11 rung `draw_line`s. Passed rungs colored by side (CYAN above center up to `tip`, RED below down to `tip`); unreached rungs dim. Shuttle = filled `draw_rect` at `y = midY - _tip_anim*rungGap`. End rungs thicker (═). Anim: shuttle glides on `_tip_anim`; the target-adjacent rung pulses `sin(_t*8)`; on lock approach the top/bottom rung strobes.

**10. PRESSURE VALVE (pressure gauge)**
Pitch: A半-round boiler gauge with a red danger zone and a cyan overpressure zone — the needle in the red means you're being ejected.
```
    EJECT ╱ ‾ ╲ CRACK
     RED /  ↑  \ CYAN
        ╰──[+2]──╯
```
Draw: bottom-anchored 180° `draw_arc` bezel (thick, EDGE); colored zone bands — RED arc on left third, CYAN on right third, neutral middle (three `draw_arc`s). Needle `draw_colored_polygon` from hub, angle `= PI + (_tip_anim/5+1)*PI/2` (maps -5..+5 across the semicircle). Hub `draw_circle`; boxed `%+d` readout at base via `draw_rect`+`draw_string`. Anim: needle judders with `sin(_t*30)*small` when `abs(_tip_anim)>=4` (over-pressure shake); danger band brightens `0.2+0.3*sin(_t*10)` when needle enters it; faint glass-glare `draw_line` sweep across the bezel driven by `_t`.

---
All ten reuse the same drivers: `tip` for discrete lit/locked state, `_tip_anim` for smooth needle/fill/seam position (`norm = clampf(_tip_anim/WIN_TIP,-1,1)`), `_t` for idle shimmer and near-lock strobe (`abs(_tip_anim)>=4`), `ncol = CYAN if _tip_anim>0 else RED`, and `s`/`_fs()` for scaling. Source studied: `C:/Users/menel/OneDrive/Έγγραφα/games/spacewalker-godot47/scripts/breach_duel3d.gd` (`_hud_scale` at line 1634). No files edited.

# APPENDIX C — Energy designs (raw)

All state confirmed from `scripts/breach_duel3d.gd`: `energy` (current int), `energy_max` (this-turn cap), `MAX_ENERGY=5` (absolute cap), `sel_cost` (selected card cost via `CARDS[hand[_sel]][4]`), `_t` (time), `CYAN=Color(0.45,0.9,1.0)`, `AMBER=Color(1.0,0.72,0.25)`. Helpers: `_hud` (CanvasItem), `_font`, `_fs(px)`, scale `s`. Current impl is the segmented strip (lines 1596-1631).

Below are 10 distinct concepts. All assume the same convention: cells `[0..MAX_ENERGY)`; index `< energy` = filled cyan; `[energy_max..MAX_ENERGY)` = faint "locked/unavailable" ghost; the range `[energy-sel_cost, energy)` recolors AMBER to preview spend; last filled cell pulses via `0.5+0.5*sin(_t*3.0)`.

---

**1. SEGMENTED STRIP** (current baseline, refined)
Pitch: Five flat bars in a row — the readable default; spend eats from the right in amber.
```
ENERGY
[██][██][██][▓▓][··]   3/4
        ^amber-preview ^ghost
```
Key draws:
- `for i in MAX_ENERGY:` rect `Rect2(p+Vector2(i*pitch,0), Vector2(seg_w,seg_h))`
- `i>=energy_max` → `draw_rect(r, Color(CYAN,0.07), false, 1.0)` (ghost outline)
- `spending := sel_cost>0 and i>=energy-sel_cost and i<energy` → base `AMBER` else `CYAN`
- filled: `draw_rect(r, Color(base,0.85))` + top highlight `draw_line`
- last cell pulse `a = 0.55+0.35*pulse`
- `draw_string(_font, ..., "%d/%d"%[energy,energy_max], _fs(13), ncol)`

---

**2. ORB ROW**
Pitch: A row of glowing capacitor orbs; charged ones bloom, spend-preview orbs flip to a hollow amber ring.
```
ENERGY
 ●  ●  ●  ◎  ○    3/4
              amber◎  ghost○
```
Key draws:
- `for i in MAX_ENERGY:` `c := p + Vector2(i*pitch, 0)`; `rad := 6.0*s`
- filled `i<energy`: `draw_circle(c, rad, Color(CYAN,0.9))` + bloom `draw_arc(c, rad+2*s, 0, TAU, 20, Color(CYAN,0.25), 2.0)`
- spend-preview: `draw_arc(c, rad, 0, TAU, 20, AMBER, 2.0*s)` (hollow amber)
- unavailable `i>=energy_max`: `draw_arc(c, rad, 0, TAU, 16, Color(CYAN,0.12), 1.0)`
- last orb pulse: modulate radius `rad*(0.9+0.15*pulse)`

---

**3. VERTICAL CELLS**
Pitch: A stacked column of thin plates, fills bottom-up like a rack of loaded batteries — hugs a screen edge.
```
[··]  ghost (i=4)
[▓▓]  amber preview
[██]
[██]
[██]  ENERGY 3/4
```
Key draws:
- iterate top→bottom: `y := p.y - i*pitch` so index 0 sits at bottom
- `r := Rect2(Vector2(p.x, y), Vector2(cell_w, cell_h))`
- same fill/ghost/amber logic as #1 but vertical
- side rail: `draw_line(Vector2(p.x-3*s, top), Vector2(p.x-3*s, bottom), Color(CYAN,0.18),1.0)`
- label rotated or placed below via `draw_string` `"%d/%d"`

---

**4. SINGLE BATTERY BAR**
Pitch: One continuous cyan bar in a bracket with a nub terminal; amber overlay shows the slice a card will drain.
```
ENERGY
┤██████████▓▓▓░░░░├▮   3/4
 fill        spend ghost
```
Key draws:
- outer frame `draw_rect(Rect2(p, Vector2(bar_w, bar_h)), Color(CYAN,0.25), false, 1.0)` + terminal nub `draw_rect` at right
- fill width `fw := bar_w * energy/float(MAX_ENERGY)`: `draw_rect(Rect2(p, Vector2(fw, bar_h)), Color(CYAN,0.8))`
- cap ticks: `for i in range(1,MAX_ENERGY): draw_line(x-tick)` faint dividers
- spend overlay: `sx := bar_w*(energy-sel_cost)/MAX_ENERGY`; `draw_rect(Rect2(p+Vector2(sx,0), Vector2(fw-sx, bar_h)), Color(AMBER,0.7))`
- `energy_max` cap marker: vertical amber-less line at `bar_w*energy_max/MAX_ENERGY`

---

**5. RADIAL RING** (matches the TRACE LOCK dial language nearby)
Pitch: A small arc gauge that sweeps clockwise per energy pip; the preview backs the needle off in amber.
```
      ___
    /  •  \      3/4  in center
   |   3   |
    \_____/
   ticks = 5
```
Key draws:
- `C := p; R := 22.0*s; up := -PI/2; span := deg_to_rad(140)`
- base track `draw_arc(C, R, up-span, up+span, 48, Color(CYAN,0.15), 5.0*s)`
- filled sweep to `a := (up-span) + (energy/float(MAX_ENERGY))*(2*span)`: `draw_arc(C,R,up-span,a,48,CYAN,5.0*s)`
- spend preview arc from spent-angle→a in `AMBER`
- 5 tick lines `for k in range(1,6)` like `_hud_scale`
- center `draw_string(_font, C+off, "%d/%d", _fs(15), CYAN)`

---

**6. DOT MATRIX**
Pitch: A compact grid of tiny pips (rows = MAX_ENERGY, one lit column) reading like a charge readout on old avionics.
```
ENERGY
· · · · ·
● ● ● ◦ ·
● ● ● ◦ ·   3/4
● ● ● ◦ ·
```
Key draws:
- `rows := 3` (visual thickness), `for i in MAX_ENERGY: for row in rows:` `c := p + Vector2(i*dpitch, row*dpitch)`
- lit `i<energy`: `draw_rect(Rect2(c, Vector2(2*s,2*s)), Color(CYAN,0.85))`
- spend `i>=energy-sel_cost and i<energy`: `AMBER`
- ghost `i>=energy_max`: `Color(CYAN,0.1)`
- pulse alpha on column `energy-1`

---

**7. FILLING VIAL**
Pitch: A rounded flask/reactor cell with a liquid line and a bubble; the fluid level is energy, amber marks what a play consumes.
```
 ╭──╮
 │▒▒│  ghost gap
 │██│  ← level
 │██│ °   ENERGY 3/4
 ╰──╯
```
Key draws:
- flask outline: `draw_arc` for rounded top + `draw_line`s for sides, or `draw_rect(..., false)`
- fluid `lvl := body_h * energy/float(MAX_ENERGY)`: `draw_rect(Rect2(p+Vector2(0,body_h-lvl), Vector2(body_w, lvl)), Color(CYAN,0.6))`
- meniscus highlight: `draw_line` across top of fluid `Color(CYAN,0.9)`
- spend band in `AMBER` between old/new level
- bubble: `draw_circle(p + Vector2(w*0.5, body_h - lvl*fmod(_t,1.0)), 1.5*s, Color(CYAN,0.4))`
- `energy_max` cap: dashed line at its level

---

**8. HEX CELLS**
Pitch: Honeycomb capacitor cells — a techy hex row where each charged cell fills solid and preview cells outline amber.
```
ENERGY
 ⬡ ⬡ ⬡ ⬢ ⬡     3/4
 fill    amber ghost
```
Key draws:
- `for i in MAX_ENERGY:` build hex `PackedVector2Array` of 6 verts around `c := p+Vector2(i*hpitch,0)`, `for k in 6: c + Vector2(cos(k*PI/3), sin(k*PI/3))*hr`
- filled `i<energy`: `draw_colored_polygon(hex, Color(CYAN,0.8))`
- spend: `draw_colored_polygon(hex, Color(AMBER,0.8))`
- empty/ghost: `draw_polyline(hex+first, Color(CYAN,0.2 or 0.1), 1.0)` (close loop)
- pulse last filled hex alpha

---

**9. NUMERIC + MINI-BAR**
Pitch: Big cyan number is the hero; a hairline underbar and a small "−cost" tag give the preview without clutter — most discreet.
```
   3/4  −2
   ▁▁▁▁▁▁▓▓
```
Key draws:
- `draw_string(_font, p, "%d/%d"%[energy,energy_max], _fs(22), CYAN)` (hero)
- if `sel_cost>0`: `draw_string(_font, p+Vector2(tag_x,0), "−%d"%sel_cost, _fs(13), AMBER)`
- hairline bar under text width `bw`: fill `draw_line(p_bar, p_bar+Vector2(bw*energy/MAX_ENERGY,0), Color(CYAN,0.7), 2.0*s)`
- spend segment of that line in `AMBER`
- ghost remainder `Color(CYAN,0.12)`; `energy_max` tick as a 1px cyan notch

---

**10. AMMO CLIP**
Pitch: A magazine of stacked "rounds" viewed from the side — spend chambers the top rounds amber, reads instantly as a resource you fire.
```
ENERGY
╞═════╡
│▐▌▐▌▐▌│  each round = 1 energy
│▐▌▐▌▓▌│  amber = will fire
╞═════╡  3/4
```
Key draws:
- clip frame: two `draw_line` rails + top/bottom brackets `Color(CYAN,0.3)`
- `for i in MAX_ENERGY:` round as short thick capsule `draw_line(a, b, col, 4.0*s)` with rounded caps, stacked at `p+Vector2(i*rpitch,0)`
- loaded `i<energy`: `Color(CYAN,0.85)`
- to-fire `i>=energy-sel_cost and i<energy`: `AMBER`
- ghost `i>=energy_max`: `Color(CYAN,0.1)`
- feed-lip highlight on the next round (`energy-1`) pulsing with `pulse`
- `draw_string` `"%d/%d"` at clip base

---

Notes for whichever you pick: all ten reuse the exact existing state and color constants, need no new members, and keep the "no backing box / cold cyan" rule. #4 and #7 (single continuous fill) are the smoothest to animate but read energy as a ratio, not discrete pips — slightly worse for a 5-cost curve where exact count matters. #2 (orbs), #8 (hex), #10 (ammo-clip) keep discrete-pip clarity while looking less like the current strip. #9 is the smallest footprint if you want it truly out of the way.