# Design

Systems, mechanics, balance, roster, the core loop. The "why" behind what the game does, not the "how" of the code (that's [Engineering](../02_Engineering/README.md)).

**Owner**: Andrew (vision, taste, final call) + Claude (systemic reasoning, balance math, consistency across the roster).

## What's decided

- Genre: roguelike-flavored RTS/hero-unit hybrid, WC3-adjacent. See [Decisions Log](../06_Production/Decisions_Log.md).
- Core loop: drop into a procedural map → explore → establish a base at a strategic location → build/defend against waves → push out and take objectives (strength up / waves down) → beat the boss.
- Loss condition, current implementation: wizard tower destroyed. Wizard death does **not** currently end the game — see Open Questions.

## Reference docs (live with the code)

- `wizard-rts/wizard-rts/PROJECT_BRIEF.md` — full roster, factions, structures, stats table
- `wizard-rts/wizard-rts/COMBAT_SYSTEM_REVIEW.md` — combat mechanics in full technical detail

## Open questions (Andrew's call)

- **Wizard death vs. loss condition**: right now dying damages the tower and respawns the wizard at 40% HP with a stun — it's not an instant loss. You flagged this as "to be clarified." Does the wizard need its own fail state, or is tower-only correct?
- **Actual roguelike run structure**: no permadeath, meta-progression, or mid-run build choices exist yet. Procedural maps + evolution-through-combat give roguelike *texture* but not a roguelike *loop*. Is that gap something to design, or was "roguelike" always meant loosely? (Raised in `PERFORMANCE_CRITIQUE.md`'s genre-fit section.)
- **AI-test army-mix**: the stress-test mode may be spawning KON vs KON instead of KON vs Deom — needs a design call on whether that's intentional (controlled testing) before an engineer "fixes" it.
