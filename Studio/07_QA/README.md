# QA

Two very different things live under this one heading — keep them distinct.

## Automated testing — strong, already exists

~28 headless smoke/stress tests in `scripts/core/*_smoke_test.gd` and `*_stress_test.gd` (`extends SceneTree`, CI-shaped exit codes). Genuinely disciplined coverage for this project's size — map generation, unit/catalog data integrity, specific ability behaviors, combat vertical slices, menu/UI flows, and performance/stress testing all have dedicated tests. Convention: add or run a test when touching a gameplay system. This is an [Engineering](../02_Engineering/README.md) responsibility in practice (Codex writes them as part of implementation work).

## Playtesting — doesn't exist yet

No manual playtesting process, no feedback capture, no balance-testing framework beyond the automated stress tests (which check performance, not fun). This is a real gap once there's enough game to actually play — automated tests can't tell you if the wave pacing feels right or if a unit is boring to use.

**Owner**: unstaffed. Andrew is the only person who can actually playtest right now.
