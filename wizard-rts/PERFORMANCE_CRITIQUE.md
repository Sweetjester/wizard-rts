# Performance & Genre-Fit Critique

Written 2026-08-08 against the goal: "support hundreds of units with fast-paced roguelike gameplay." Grounded in the project's own test suite and telemetry, not just code reading — see Method below.

## Method

Ran the repo's existing headless test/telemetry infrastructure directly (Godot 4.6.2, `--headless`):
- `scripts/core/unit_performance_smoke_test.gd` — 180 units, 180 physics frames.
- `scripts/core/fortress_ai_arena_stress_test.gd` — ramps to ~3000 units via `WaveDirector.queue_ai_test_until`, exports full telemetry via `TelemetryLogger`.

**Important caveat that shapes every number below: both runs are `--headless` — zero rendering.** They measure simulation (movement, combat resolution, pathing, mass-collision separation) only. Real in-game FPS with hundreds of units actually drawn on screen will be worse, not better, than these numbers — rendering is pure additional cost on top.

## Verdict

The simulation/backend engineering is genuinely strong and already proven at real scale — this isn't a guess, it's measured. The rendering path is the actual unaddressed risk, and there's direct evidence the team already knew it and didn't finish the fix. The "roguelike" half of the brief doesn't show up in the code at all yet — that's a design gap, not a performance one.

## What's measured and solid

- **180 units**: 180 physics frames in 2811ms ≈ 64 FPS-equivalent, headless. Comfortable.
- **~3035 units** (adaptive-throttled AI-test mode, steady state): **57-58 FPS**, `process_ms` ~41-47ms, `combat_tick_ms` 6-9ms, `combat_avg_candidates` ~4.3 (spatial bucketing keeping neighbor lists small — this part of the architecture is doing exactly its job). Static memory ~115MB at 3000 units — memory is not a concern.
- The adaptive spawn-throttling system in `wave_director.gd` (tiers at 600/900/1200/1600/2200 units, soft cap 3200) is real, working engineering, not aspirational — it's the reason steady-state at 3000 units holds ~58fps instead of collapsing.

## What's measured and concerning

- **`lowest_fps_observed: 2.0`** during the 3000-unit ramp-up. Somewhere in that run — almost certainly a mass-spawn burst or wave transition before throttling caught up — the simulation dropped to 2 FPS. That's a near-freeze, not a slowdown, and it happened with **no rendering running at all**.
- **`highest_process_ms_observed: 85.4ms`** — a single-frame spike alone blew ~5x the 16.67ms budget for 60fps.
- **Combat ticking alone costs up to ~9ms/frame at 3000 units** — over half the entire 60fps frame budget, before movement, pathing, or a single pixel gets drawn.
- **The batched-rendering fix already exists and isn't used.** `scripts/units/mass_unit_multimesh_renderer.gd` is a real `MultiMeshInstance2D`-based renderer sitting in the repo — and nothing else in the codebase references it. Live units render via hand-rolled per-unit `_draw()` calls (`RTSUnit` and subclasses), which is CPU-side immediate-mode drawing — one of the more expensive ways to render hundreds of independently-moving sprites in Godot. Someone already identified this and built the fix; it was never wired in.
- **`CharacterBody2D` per unit.** Every unit pays Godot's physics-engine movement cost (`move_and_slide`) rather than a lighter manual-integration approach. The existing `mass_collision_calls`/`mass_collision_neighbors` telemetry fields suggest the team already knows separation/collision among hundreds of physics bodies is a cost center worth tracking.
- **`SimulationState`/`SimulationRunner`** run a full parallel deterministic 20Hz lockstep simulation alongside real gameplay, for multiplayer/replay that isn't wired up as authoritative yet (per the main brief). Right now that's pure overhead bought for zero player-facing benefit.

## Prioritized recommendations

1. **Wire in `mass_unit_multimesh_renderer.gd` for swarm-tier units** (terrible_thing, oaven_spear, horror, etc. — the units that actually show up in the hundreds). Keep hand-drawn `_draw()` for the wizard hero and boss where individual detail matters. This is the highest-leverage, lowest-risk fix available — the code already exists, it just needs to be the thing that actually runs.
2. **Investigate the 2 FPS floor specifically**, not just steady-state average. Averages hide the spike that actually breaks "fast-paced" — a 2 FPS stall during a wave transition is a worse player experience than a sustained 50fps. Profile spawn bursts directly.
3. **Move swarm-unit movement off `CharacterBody2D` physics** toward manual position integration + the existing spatial-bucket system for separation, reserving real physics bodies for units where precise collision actually matters (hero, boss, maybe elites). This is the biggest architectural lever left and the most disruptive to change — worth doing once, deliberately, not incrementally.
4. **Consider flow-field pathfinding for grouped movement** (wave-vs-wave, attack-move orders affecting dozens of units at once) instead of per-unit A* + cache. Standard technique for RTS-at-scale; the current path-cache (768 entries) helps for repeated identical queries but degrades as target diversity grows with unit count.
5. **Disable `SimulationState`/`SimulationRunner` while inactive**, or gate them behind an explicit multiplayer/replay mode, rather than always running a parallel simulation nothing currently consumes.

## The "roguelike" half — a design gap, not a performance one

Nothing found in the codebase or docs describes an actual roguelike **run structure**: no permadeath, no between-run meta-progression, no procedural build-defining choices offered mid-run (relic/upgrade picks, etc.), no run timer or scoring. What exists that *is* roguelike-flavored:
- Procedural, seeded maps (different every game).
- Evolution-through-combat-XP (units snowball in power through play, which has real roguelike-build-crafting texture).
- A boss arrival at 240s is already fairly arcadey/tight pacing for an RTS — that part isn't fighting the "fast-paced" goal.

What's currently in tension with "fast-paced": production queues, placement previews, footprint validation, drag-wall placement, a tech tree gated behind a building — these are deliberate, careful base-builder mechanics, not low-friction roguelike decision-making. None of this is wrong for the game as designed, but if "fast-paced roguelike" is a literal target rather than a vibe descriptor, the actual roguelike loop (runs, permadeath, escalating-then-resetting difficulty, meta-progression) doesn't exist yet and would need to be designed, not just optimized toward.

**Worth asking directly**: is "roguelike" here shorthand for "procedural and build-evolving," or does it mean an actual run-based structure? Those imply very different scopes of work, and only one of them is a performance question.
