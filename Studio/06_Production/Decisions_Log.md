# Decisions Log

Running record of major project decisions — what was decided, when, and why. Append to this; don't rewrite history. If a decision gets reversed later, add a new entry rather than editing the old one.

---

### 2026-08-08 — Rendering: staying 2D

Units render 2D (moving toward sprite sheets per `docs/kon_unit_asset_template.md`), not the 3D GLB pipeline. The project had been quietly funding two incompatible art directions — a fully-built 3D Meshy/Blender pipeline with unsolved animation, versus 2D gameplay that actually ships. Reasoning: the required scale (hundreds of units) is already achievable in 2D; 2D batches far more cheaply than per-unit 3D meshes; AI-assisted dev velocity (Claude/Codex) is materially higher on Godot 2D than on the 3D pipeline's specialized tooling. The 3D work isn't deleted, just deprioritized as a gameplay path — still useful for marketing renders if wanted.

### 2026-08-08 — Engine: staying on Godot

Considered migrating to Spring/Recoil (the engine Beyond All Reason uses) for its proven massive-scale RTS simulation and native lockstep multiplayer. Decided against it: the actual target scale (hundreds, not BAR's thousands) is already within Godot's proven range (see the LOD fix below), an engine migration would discard months of tested Godot systems, and Claude/Codex have vastly more depth on Godot than on Spring's Lua-based tooling — directly serving Andrew's own stated thesis that AI-assisted development is the efficiency lever here.

### 2026-08-09 — Performance: LOD rendering system landed

Fixed and wired up `scripts/units/mass_unit_multimesh_renderer.gd` (previously dead code — inverted visibility bug, never added to the scene). Now a working distance/count-based LOD system. Verified via the project's own stress-test suite at ~3000 units: worst-case frame stall went from 2 FPS to 40 FPS, steady-state hit a flat 60fps (up from 57-58). Gameplay unaffected — hidden units remain fully selectable/targetable. Full detail in `wizard-rts/wizard-rts/PERFORMANCE_CRITIQUE.md`.

### 2026-08-09 — Performance: blob-tier movement centralized

Moved blob-tier swarm movement off each unit's `CharacterBody2D` physics callback once the live unit count reaches swarm scale. Full-detail and selected units still use their normal per-node movement path; hidden multimesh-rendered units disable per-node physics and are advanced by `RTSWorld`'s existing budgeted central movement loop. This keeps gameplay objects selectable/targetable while removing the expensive per-unit physics callback from distant swarm units.

### 2026-08-09 — Performance: flow-field pathfinding for enemy waves

Added flow-field pathfinding scoped specifically to enemy waves converging on the player's base (`wave_director.gd`), not a full pathfinding rewrite. A cached Dijkstra flow field (keyed with the existing `_path_cache_version` invalidation) replaces per-unit A* for that one scenario; units with no valid flow route fall back to individual A*. Player-issued orders, chase-to-attack-range, and arena AI lane orders are untouched — deliberately scoped out, not missed. New telemetry: `flow_field_recomputes`, `units_using_flow_field`. Verified with a new smoke test asserting real behavioral outcomes (measured progress toward target, majority of wave units actually using the field) plus a clean-conditions rerun of the fortress stress test confirming zero effect there (as expected, since that mode doesn't route through wave_director's normal dispatch).

First task delivered through `claude-loop.js` instead of Bell's task-mode loop — Claude planned directly with full context already in hand (no blind planning call), and reviewed the result in-conversation rather than via an automated review pass.

### 2026-08-09 — Performance: SimulationRunner gated, not deleted

`SimulationRunner.auto_start` defaulted to `true` unconditionally, so the 20Hz deterministic lockstep layer ran in every single-player session with nothing consuming its output. Gated it behind an actual-active-multiplayer check instead of removing it — this is groundwork for planned co-op, not dead weight to cut. Found and fixed a real latent bug along the way: Godot always assigns a default `OfflineMultiplayerPeer` even with no networking set up, so the existing `multiplayer_peer != null` check in `command_dispatcher.gd` had silently always evaluated true. Both checks now correctly test for a genuinely active (non-offline) peer.

### 2026-08-09 — TileSet autotiling: investigated, premise found stale, not implemented

Roadmap task 5 claimed the live map's TileSet had zero terrain sets. Investigation found this was already fixed at some earlier point and the documentation just never caught up: `main_map.tscn` uses `tiny_swords_plot_tileset.tres` (4 real terrain sets, working peering bits), and grass/road already paint via real `set_cells_terrain_connect()` autotiling. Also found (and corrected) my own wrong guess about three `set_cell()` call sites at lines 4401/4403/4405 — despite the `terrain_name` parameter name, these are plot/feature overlay painting (walls, economy markers, objectives), not elevation surface painting, and are correctly left as direct paint. The real remaining gap — water is deliberately still atlas-painted pending complete terrain coverage, cliff terrain is defined but unused — needs completed asset-pack/TileSet work plus reconciling with the logical elevation grid. Declined to force a code migration for something that's actually art+code work together; rescoped on the roadmap instead of marking a fake "done."

### Open, not yet decided

- **Wizard death vs. loss condition** — currently the tower absorbs a wizard's killing blow and the wizard respawns; dying doesn't end the game on its own. Andrew flagged this needs clarifying. See [01_Design](../01_Design/README.md).
- **Actual roguelike run structure** — no permadeath/meta-progression/mid-run choices exist. Is "roguelike" meant literally (needs designing) or as a vibe (procedural + build-evolving, already satisfied)?
