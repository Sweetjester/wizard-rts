# Design

Systems, mechanics, balance, roster, the core loop. The "why" behind what the game does, not the "how" of the code (that's [Engineering](../02_Engineering/README.md)).

**Owner**: Andrew (vision, taste, final call) + Claude (systemic reasoning, balance math, consistency across the roster).

## Master reference

**[MASTER_DESIGN_DOC.md](MASTER_DESIGN_DOC.md)** — the full design vision (last updated 2026-08-19), meant to be read by any agent (human or AI) before touching game systems. Covers core loop, wizard/tower, base placement, economy, classes, roguelike upgrades, procedural map generation, roads/terrain, enemy pressure, day/night, weather, bosses, design priorities/non-goals, and — as of this update — the artwork generation pipeline's actual status. This is the target design — where it gets ahead of what's actually built, that gap is tracked work, not a doc conflict. Section 33 ("Agent Development Guidelines") and Section 36 ("Short Version for Agents") are written specifically for agents picking up this project cold.

**Artwork pipeline flagged as needing a rebuild** (MASTER_DESIGN_DOC.md §37): two disconnected generation pipelines exist (a 3D/Meshy path that was feeding a non-shipping preview scene, and a 2D/PixelLab path that's actually shipped real assets but has a habit of sitting unreviewed for months). Animation is the biggest gap — only one unit has ever made it from any pipeline into real 2D gameplay animation; everything else is placeholder motion. Don't generate more static art volume before that's addressed.

## What's decided

- Genre: roguelike-flavored RTS/hero-unit hybrid, WC3-adjacent. See [Decisions Log](../06_Production/Decisions_Log.md).
- Core loop: drop into a procedural map → explore → establish a base at a strategic location → build/defend against waves → push out and take objectives (strength up / waves down) → beat the boss.
- Loss condition, **design target** (MASTER_DESIGN_DOC.md §9): both wizard death and wizard tower destruction end the run. **Current implementation** still differs — dying damages the tower and respawns the wizard at 40% HP with a stun, not an instant loss — bringing the code in line with this is open engineering work, not an open design question anymore.
- Roguelike run structure, **design target** (MASTER_DESIGN_DOC.md §8, §17-18): class selection, procedural map, randomized objective, map-discovered upgrades researched back at the tower. Procedural maps + evolution-through-combat currently give roguelike *texture*; building the actual run structure (upgrade discovery/research loop, per-run objective selection) is the gap to close — see Non-Goals (§31) for what to leave until the core loop is fun first.

## Reference docs (live with the code)

- `wizard-rts/wizard-rts/PROJECT_BRIEF.md` — current implementation status: full roster, factions, structures, stats table
- `wizard-rts/wizard-rts/COMBAT_SYSTEM_REVIEW.md` — combat mechanics in full technical detail

## Open questions (Andrew's call)

- **AI-test army-mix**: the stress-test mode may be spawning KON vs KON instead of KON vs Deom — needs a design call on whether that's intentional (controlled testing) before an engineer "fixes" it.
