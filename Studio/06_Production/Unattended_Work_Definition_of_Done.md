# Definition of Done — unattended / passively-supervised work

This applies specifically to work run with **less active supervision** than Andrew-and-Claude-in-conversation: Bell's task-mode loop dispatching to Codex, batch generation cycles (`run_kon_pixellab_cycles.ps1`-style), scheduled/cron agents, or any run where nobody is watching each step happen. Supervised work (a human or Claude actively in the loop, reviewing as it goes) doesn't need this — the existing fast direct-to-`main` flow is fine there.

It exists because this project already has one full session's worth of evidence for what goes wrong without it: 100+ assets built against a scene the real game never loads, undetected for weeks; 137 assets style-reviewed only in isolation and never checked in the running game; a fully-generated art batch left sitting unreviewed for four months; two pipelines silently overwriting each other's territory, twice. None of that required bad judgment on any single step — it required nobody checking the *actual result* against *the thing that ships*, at each handoff.

## Before starting: the scope check

A task is a reasonable candidate for unattended execution if it's one of:

- More variants of an already-established category, from an existing spec template
- A poll/submit cycle against an already-configured job queue
- Running the existing smoke-test suite and reporting pass/fail
- Vault/doc truing-up against recent commits

It is **not** a candidate — route to Andrew or a Claude-in-conversation session instead — if it touches an open Design question (see `Studio/01_Design/README.md`), changes which scene/file/system is treated as authoritative, requires a style or feel judgment call (QA's own README: playtesting is unstaffed, Andrew-only), or would spend past a small pre-agreed API-credit budget.

## Before marking done: the evidence check

**Code/logic changes** — the relevant smoke test(s) under `scripts/core/*_smoke_test.gd` / `*_stress_test.gd` must actually run and pass (CI-shaped exit codes — this is already automatable, not new infrastructure). A task that touches a gameplay system and adds no test, or whose test wasn't actually invoked, is not done, per the existing convention in `Studio/07_QA/README.md`.

**Art/rendering changes** — evidence must come from the scene that actually ships (`scripts/map/main_map.tscn` for the live game — see `PROJECT_BRIEF.md`'s repo-layout-gotcha and boot-flow sections before assuming which scene that is), not an isolated render or a preview/showcase scene. Minimum bar: a screenshot or engine-log count from that real scene. Also confirm no files landed outside the task's declared folder ownership — the 3D (`tools/prop_pipeline/`) and 2D (`assets_game/props/*`) pipelines write into overlapping folder names and have already caused real bugs this way twice.

**Every task, regardless of type** — `Studio/06_Production/Roadmap.md` and `Decisions_Log.md` get updated *in the same task*, not as a follow-up. A stale roadmap actively misleads the next session (human or AI) into re-deriving or contradicting settled work — see the 2026-08-19 entries in the Decisions Log for exactly how much can drift in one week without this.

## Git safety for unattended runs

Work in a disposable worktree/branch, run the evidence check there, and only fast-forward into `main` once it passes. (There's already a stray, unmerged `worktree-agent-...` branch in the repo from what looks like a prior dropped attempt at this exact pattern — check what it contains before reusing or deleting it.) This is insurance specifically for the less-supervised case; it is not meant to slow down normal human-and-Claude work, which keeps landing on `main` directly.

## See also

- `Studio/01_Design/MASTER_DESIGN_DOC.md` §37 — the artwork pipeline gap this doc's art-evidence rule exists to prevent recurring
- `Studio/07_QA/README.md` — the smoke-test convention this doc's code-evidence rule builds on, not replaces
