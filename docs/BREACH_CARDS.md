# THE BREACH — Card Bible (Inscryption Act 3 reskin)

Balance skeleton = Act 3 (Botopia) EXACT stats/sigils; fiction reskinned so it's not a rip-off.
PLAYER = cyan **intrusion** units (bots/mites/drones/worms/spikes, "penetration"). ENEMY/boss =
red-amber **firewall** units (barriers, sentries, ICE, wardens, daemons). Godot CARDS dict shape:
`"id": [NAME, portrait_key, atk, hp, energy_cost, sigils_array]`.

## Mechanics (confirmed)
- Energy: start max 1, **+1 max per turn (cap 6)**, refills to full each turn, no banking.
- `overcharge` (Battery Bearer): +1 max & refill that cell on play — accelerates the ramp.
- Side deck = **Hollow Shell** (Empty Vessel), 0/2, cost 1. Upgrades stamp one sigil onto it.
- Gems: `gem_ruby/emerald/sapphire` cards emit a board resource for `gem_dependent` cards.
- Collect-as-you-go: no upfront deckbuild (deck-builder is LATER). Win → pick 1-of-3 card reward.
- Bounty meter: consecutive wins raise stars → Bounty-Hunter ambush; a loss resets to waypoint.

## PLAYER pool — intrusion (cyan)  [id | atk/hp/E | sigils | pool | ~Act3]
- power_siphon  0/1/2  [overcharge]      starter  (Energy Bot)
- buckler_mite  1/1/2  [ablative_plating] starter (Shieldbot)
- lance_drone   1/1/3  [targeting_laser]  starter (Sniper Bot)
- fork_turret   2/1/6  [split_bore]       starter (Double Gunner)
- grunt_bot     1/1/3  []                 general (Automaton)
- piston_ram    2/2/6  []                 general (Steambot)
- bulwark_breaker 1/3/5 []                general (Thick Droid)
- skip_worm     2/3/4  [trackrunner*]     general (Curve Hopper)
- screech_mote  2/1/3  [provoke]          general (Alarm Bot)
- spike_mite    1/1/2  [spike_casing*]    general (49er/Amoebot)
- sapper_worm   1/2/3  [meltdown]         general (Explode Bot)
- charge_mite   1/1/2  [overcharge]       general (Explode+Battery)
- swarm_hound   2/2/6  [mite_spawner]     general (Bolthound/Ant)
- prism_ripper  3/1/5  []                 general (Gembound Ripper)
- watcher_seed  0/1/1  [morphogen]        general (Sentry Drone)
- hollow_shell  0/2/1  []                 side    (Empty Vessel)
- prism_shell_r/e/s 0/2/1 [gem_*]         side    (Mox Vessels)
- Shell upgrade variants (0/2/1): shell_leap(grapnel), shell_armor(ablative_plating),
  shell_spikes(spike_casing), shell_battery(overcharge), shell_sentry(autoturret), shell_tribore(tri_bore)

## ENEMY / FIREWALL pool — defensive (red/amber). Cost shown but AI pays no energy.
- barrier_node  0/3  []            filler
- sentry_ice    1/2  [autoturret]  (Sentry)
- packet_daemon 3/2  []            (W07F)
- raptor_proc   2/3  [interpose]   (RAV3N/Guardian)
- heap_giant    2/4  [mite_swarm]  (3LK/Bees Within)
- spike_wall    1/2  [spike_casing]
- trace_hound   1/1  [tracer_dash] (ADD3R/Sprinter)
- null_conduit  0/1  [null_circuit]
- firewall_slab 1/5  [enlarge*]

## BOSS / SPECIAL cards
- freeze_frame  1/1/5 [lane_lock,morphogen]      Lens boss   (Shutterbug)
- index_warden  1/2/0 [free_sac,shield_latch]    Index boss  (Librarian)
- quarantine_file 1/1/2 [dead_byte]              Index boss  (Captive File)
- busted_printer 0/3/3 [gem_guardian]            Nullform    (Busted Printer)
- mox_module    0/3/3 [gem_dependent]            Nullform    (Mox Module)
- kernel_ghost  2/2/3 [imported]                 R00T boss   (imported/Mummy fallback)
- Elite hostage daemons (locked→unlocked, [hostage_file]): daemon_ursa 0/4→4/4 (GR1ZZ),
  daemon_vespa 1/1→2/1+interpose (S0N1A), daemon_quill 2/2→1/2+undying (QU177)

## STARTER DECK (11)
power_siphon×2, buckler_mite×2, lance_drone×2, grunt_bot×2, watcher_seed, sapper_worm, fork_turret

## Enemy decks
- T1 pool: barrier_node, grunt_bot(enemy-tint), sentry_ice, null_conduit
- T2 pool: T1 + spike_wall, trace_hound, packet_daemon
- T3 pool: T2 + raptor_proc, heap_giant, firewall_slab, one daemon_*
- Zone bosses (station 3/6/9/12): Lens(freeze_frame×5 turn2 dump + lane_lock), Index(index_warden +
  file-weight gimmick), Nullform(gem board), R00T(kernel_ghost + imported). Other 8 station-bosses =
  Wardens: a tier pool + one distinct signature card.

## SIGILS (rule | difficulty)
EASY: overcharge, targeting_laser (choose target lane), ablative_plating (block first hit),
  spike_casing (attacker takes 1), grapnel (blocks airborne), airborne (hits scale unless blocked),
  provoke (opposite +1 pow), gem_ruby/emerald/sapphire (emit gem).
MEDIUM: split_bore (bifurcated), tri_bore (trifurcated), autoturret (sentry: dmg on enter-opposite),
  meltdown (detonator: 10 dmg opposite+adjacent on death), morphogen (transform after a turn),
  tracer_dash/trackrunner (sprinter: move a lane end of turn), mite_spawner (pow = friendly mites),
  mite_swarm (spawn mite when struck), free_sac (free 3-fuel sacrifice), hostage_file (locked/unlocked
  forms), dead_byte (can't attack), enlarge* (+1 hp when struck).
HARD (gate to later zones): lane_lock (kill card played in front), interpose (guardian slide-to-block),
  undying (return copy on death), conduit family (null/energy/attack/heal/spawn circuits between a pair),
  gem_dependent / gem_guardian / gem_detonator, latcher family (stamp sigil on death/play), imported.
Ship order: all EASY+MEDIUM first (covers starter + general pools + most Wardens + Lens with a faked
lane_lock). Defer Conduits/Gems/Latchers to zones 3-4.

## Progression (12 stations = 4 zones × 3)
Each station = 3 regular duels → 1 station-boss duel. Win a regular duel → pick-1-of-3 card reward.
Bounty meter across a station → optional Bounty-Hunter 4th duel. Loss → back to station entry (waypoint).
Zone finales (stations 3/6/9/12) use the 4 Uberbot reskins; other 8 use Wardens. Optional Trader node
between stations (swap card / buy Extra Battery / mod a Hollow Shell). Start 11 cards → ~40 by station 12.

## DEFERRED for v1 (exist in Act 3, cut for now): fish set, bone/skeleton set, full ant economy,
ouroboros (undying-scaling), mycobot fusion, imported-card network. Keep stats for parity later.

*(reconstructed) = verify stat/sigil in-game before locking: skip_worm, spike_mite, firewall_slab.*

Source research + full detail: session card-bible agent (Fandom/purefunc/ScreenRant/Prima/GameRant).
