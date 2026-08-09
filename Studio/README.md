# Wizard-RTS Studio

This is the project's organizational vault — not code, not game assets. It exists so Andrew, Claude, Codex, and Bell all work from the same map of what needs doing and who's doing it, instead of re-deriving it each time.

Open this `Studio/` folder directly as an Obsidian vault if you want the graph/linking view — it's plain markdown, nothing Obsidian-specific required to read or edit it. It lives in the same git repo as the game (`Sweetjester/wizard-rts`), one level above the actual Godot project (`wizard-rts/wizard-rts/`), so it stays in sync the same way everything else does: commit and push. It's deliberately outside the Godot project folder so the engine never scans or imports it.

## Structure

Organized like a small game studio's departments (real-world structure researched, not invented — see each department's README for what it actually covers). At this team size, roles overlap heavily — most departments below are "owned" by more than one of us:

- **[01_Design](01_Design/README.md)** — systems, mechanics, balance, roster
- **[02_Engineering](02_Engineering/README.md)** — gameplay code, performance, tooling
- **[03_Art](03_Art/README.md)** — visual style, asset pipelines
- **[04_Audio](04_Audio/README.md)** — music, sound
- **[05_Narrative](05_Narrative/README.md)** — lore, story, world
- **[06_Production](06_Production/README.md)** — roadmap, decisions log, status
- **[07_QA](07_QA/README.md)** — automated tests, playtesting

## Who does what here

- **Andrew** — creative direction, final calls, taste/feel judgment, priorities.
- **Claude (me)** — design/systems reasoning, architecture, planning, code review, cross-department synthesis. The one who keeps this vault and the game's `PROJECT_BRIEF.md` honest.
- **Codex** — implementation: gameplay code, pipeline tooling, the actual engineering work.
- **Bell** — status tracking, cross-session memory, the interface Andrew actually talks to day-to-day.

## Relationship to the game repo's own docs

The Godot project (`wizard-rts/wizard-rts/`) already has substantial technical documentation living alongside the code it describes (`PROJECT_BRIEF.md`, `PERFORMANCE_CRITIQUE.md`, `COMBAT_SYSTEM_REVIEW.md`, `STYLE_BIBLE.md`, and more). Those stay where they are — Codex's task-loop briefs already reference `PROJECT_BRIEF.md` directly from that folder, and moving them would break that. This vault doesn't duplicate them; each department README links out to the relevant ones instead. Think of this vault as the index and the narrative-of-decisions layer; the technical detail still lives with the code.

**Start here if you're lost**: [06_Production/Roadmap.md](06_Production/Roadmap.md) for what's actually open right now, or [06_Production/Decisions_Log.md](06_Production/Decisions_Log.md) for how we got here.
