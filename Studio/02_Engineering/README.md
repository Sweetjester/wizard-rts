# Engineering

Gameplay code, performance, tooling, testing infrastructure. The "how."

**Owner**: Codex (implementation) + Claude (planning, architecture, code review). Runs through the task loop — see Bell's dashboard for live status/logs of every Claude/Codex call made against this project.

## What's decided

- **Engine: staying on Godot 4.6**, not migrating to Spring/Recoil. See [Decisions Log](../06_Production/Decisions_Log.md) for the reasoning.
- **Rendering: 2D**, not 3D. Units, map, pathing all stay 2D; the 3D asset pipeline is deprioritized as a gameplay path.
- Performance target (hundreds of units) is proven achievable in the current architecture — see the LOD rendering fix below.

## Recently landed

- **LOD rendering system** (2026-08-09): fixed and wired up the previously-dead `mass_unit_multimesh_renderer.gd`. Worst-case frame stall went from 2 FPS to 40 FPS at ~3000 units in stress testing. Details in `PERFORMANCE_CRITIQUE.md`.

## Reference docs (live with the code)

- `wizard-rts/wizard-rts/PROJECT_BRIEF.md` — architecture overview, key files, working agreements for AI collaborators
- `wizard-rts/wizard-rts/PERFORMANCE_CRITIQUE.md` — measured stress-test numbers, prioritized performance fixes
- `wizard-rts/wizard-rts/TILESET_RUNTIME_DECISION_REPORT.md` — terrain TileSet migration plan (specified, not executed)

## Open engineering items

See [Roadmap](../06_Production/Roadmap.md) for the prioritized list — TileSet autotiling is currently broken, `CharacterBody2D` physics cost for swarm units, flow-field pathfinding, and the dormant `SimulationState` lockstep layer are the big ones.

## Testing

~28 automated headless smoke/stress tests in `scripts/core/*_smoke_test.gd` — genuinely strong coverage for this project's size. Convention: add or run a smoke test whenever touching a gameplay system. See [07_QA](../07_QA/README.md) for the split between this (automated) and actual playtesting (currently nonexistent).
