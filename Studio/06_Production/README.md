# Production

Roadmap, decisions log, status tracking — the glue. What's the state of things, what's next, why did we choose what we chose.

**Owner**: Bell (status/tracking, cross-session memory), Andrew (priorities, final call on sequencing).

## The two files that matter most here

- **[Roadmap.md](Roadmap.md)** — everything currently open, prioritized. Start here if you're asking "what's next."
- **[Decisions_Log.md](Decisions_Log.md)** — append-only record of major calls and why they were made. Start here if you're asking "why does it work this way."

## Live status

Bell's dashboard (the web UI) tracks live status/logs/token usage for every Claude/Codex call made on this project, plus a Projects tab showing this project's brief and a power toggle for the local model. That's the moment-to-moment view; this vault is the durable one.

## How this stays current

Whoever lands a significant piece of work should update the Roadmap (move it from open to done, or reprioritize what's left) and add an entry to the Decisions Log if it involved a real choice, not just implementation. Don't let this drift the way some of the older asset-pipeline status docs did — a stale roadmap is worse than no roadmap.
