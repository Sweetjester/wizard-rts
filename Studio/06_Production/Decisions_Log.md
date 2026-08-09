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

### Open, not yet decided

- **Wizard death vs. loss condition** — currently the tower absorbs a wizard's killing blow and the wizard respawns; dying doesn't end the game on its own. Andrew flagged this needs clarifying. See [01_Design](../01_Design/README.md).
- **Actual roguelike run structure** — no permadeath/meta-progression/mid-run choices exist. Is "roguelike" meant literally (needs designing) or as a vibe (procedural + build-evolving, already satisfied)?
