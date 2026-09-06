# Brief: The Observer Vault card gallery

Repo: `C:/Users/AndrewHyslop/Documents/GitHub/wizard-rts/wizard-rts`

Please inspect the existing implementation before changing it, and preserve
unrelated changes in the working tree. Another agent is working in the map,
block-structure and navigation systems concurrently — see BOUNDARIES.

---

## The point

This game deliberately has less UI than an RTS normally would. The intent is
souls-like: fewer menus, fewer overlays, more of the screen given to the world.
That only works if the small amount of interface that *does* exist is worth
looking at.

The Observer Vault is the one place information lives. Kon is an observer — a
wizard who studies what he has made — and the vault is his library. Clicking it
should feel like opening something, not like opening a settings panel.

So: **a gallery of beautifully designed unit cards.** Hearthstone is the
reference for craft and legibility — a framed portrait, stats woven into the
frame rather than listed beside it, a silhouette you could recognise across the
room. It should look designed, not generated.

## Progressive revelation

This is a roguelike; the gallery is a record of what the player has discovered,
not a manual printed before the run.

- **Buildable now** — full card, full stats.
- **Locked by tier** — the card exists but is sealed: obscured art, name
  withheld or partial, and a legible line saying what would open it
  ("Tier 2 Hybrids, researched here"). The player should want it.
- **Enemy units** — no card until the player has *felled one*. First kill
  reveals it permanently for that run. `CombatSystem.unit_killed(unit, killer)`
  already exists and is the hook.
- **Not in this wizard's class roster** — shown, but marked as belonging to
  another wizard. A player should learn the world is bigger than their run.

The reveal should feel like a reward. If a card can animate or turn over the
first time it is unlocked, do it.

## What already exists — use it, do not rebuild it

**`scripts/ui/roster_ledger.gd` (`RosterLedger`) is the data layer.** Call
`RosterLedger.entry_for(archetype, build_system, rts_world)`. It returns, live
from the actual run:

- `base` / `live` stat dictionaries (max_health, attack_damage, range, speed,
  regen, intelligence)
- `changes` — every researched upgrade touching this unit, with a label, its
  numeric effect and a flavour note. This is the roguelike delta: *"Hardened
  Horrors III: +60 max HP, +6 damage"*.
- `lineage` — `{from, to}` evolution chain
- `availability` — `{available, reason}`, already worded for display
- `field` — how many are alive right now
- `tier`, `family`, `blurb`, `display_name`

It is deliberately stateless and derived. Do not cache it into a second copy of
the game state. If you need a figure it does not expose, add it there rather
than reading the catalog separately in the UI.

**Other existing pieces:**

| Thing | Where |
|---|---|
| Vault selection panel (currently opens the old window) | `scripts/ui/rts_hud.gd`, `_rebuild_context_commands`, `terrible_vault` branch |
| Old stat window — still used by the AI testing ground | `rts_hud._open_unit_stat_window` / `_build_unit_stat_window` |
| Portrait paths | `UnitCatalog.card_portrait_path(archetype)` |
| Flavour text | `card_blurb` in `UnitCatalog.DEFINITIONS` |
| Faction/theme tag | `kon_theme` (`observer` / `evolution` / `crossover`) |
| Tier gate | `build_system.unlocked_tier(1)`, `UnitCatalog.tier_of()` |
| Class roster filter | `UnitCatalog.is_unit_allowed_for_class(archetype, class_id)` |
| Run-scoped state | `GameSession` autoload |
| Enemy faction | archetypes prefixed `deom_` |

**Art, honestly:** only 15 archetypes currently declare `card_portrait`. The
card design must degrade gracefully — a card with no portrait should still look
deliberate (a sealed/unillustrated frame), never a broken image or an empty
box. If you generate portrait art for the rest, follow the established painted
style and document provenance the way `tools/kon/art_prompts.md` does.

## What to decide

These are yours to choose; there is no existing answer:

- Card layout, frame art, and how stats sit in it.
- Visual language for tier and for `kon_theme`, so a card reads as *what kind of
  thing it is* before it is read.
- How the gallery is laid out and navigated (grid, shelf, spread) and how it is
  dismissed.
- Whether the delta from `changes` appears on the card face, on a reverse side,
  or on hover. It matters and should be visible somewhere — a card that shows
  only current numbers hides the entire progression.
- Where discovered-enemy state lives and how it survives a scene reload within a
  run.

## Boundaries

- **Do not change** the map generator, block structures, navigation lattice,
  vantage effects, or the loading screen. Another agent owns those.
- `_open_unit_stat_window` is called by `ai_testing_ground_smoke_test.gd` and
  from the Biospawner's "Roster" button. Either keep it working or update both
  callers deliberately.
- Adding a new `class_name` file requires
  `godot --headless --path . --import` before it will resolve; without it you
  get `Could not resolve class "X"` pointing at the *consumer*, not the new file.
- The full suite is `scripts/core/*smoke_test.gd`, currently 61 of 63 passing.
  The two known failures are `kon_unit_framework` (the Oaven `directions: 8 -> 2`
  change) and `tower_modules` (no `module_role` remains in the catalog now that
  both the Biospawner and the Vault are placed buildings). Please do not leave
  new failures behind.
- `scripts/core/roster_ledger_smoke_test.gd` asserts that the ledger's idea of an
  upgrade matches what `BuildSystem` actually does to a spawned unit. If you
  extend `RosterLedger`, extend that test.

## Verification

Please add a smoke test covering the revelation rules specifically — that a
tier-locked unit is sealed and states its unlock condition, that an enemy card
is absent before its first kill and present after, and that a buildable unit
shows its live stats rather than its catalog stats.

Screenshots of the gallery in each state (locked, unlocked, enemy revealed)
would be worth more than a description. `ART_SHOT_DIR` is the convention already
used by the Kon tools.

## One thing to avoid

A previous pass at this produced an accurate, live, well-sourced data panel and
it was the wrong answer — it read as a spreadsheet. The information is not the
hard part; `RosterLedger` already has it. **The craft is the deliverable.**

## The art style, in one paragraph

The game reads as a stylised fantasy RTS — chunky, readable, painted-miniature
forms over realism, per `STYLE_BIBLE.md` — but the cards belong to its *painted*
register rather than its terrain one: the same hand that made Kon's atlas, 2D
and painted with a visible ink outline, gaunt and slightly grim rather than
heroic. The palette is Kon's architecture: weathered blue-teal masonry
(`#33525E`) and pale worn stone (`#6E8C93`), dark timber (`#4A3626`), cold iron
(`#232A31`), slate (`#2B4055`), lit almost entirely by emissive cyan glass
(`#4FE3DC`) and mana crystal (`#2FD3CC`) — a dark teal mass with light coming
*out* of it rather than falling *on* it, which is the single strongest signature
the game has. Against that, burgundy and red are the colour of growth: fungal
shoulder-blooms, creeping vines, the evolution side of the faction. That split is
already a data field — `kon_theme` is `observer` (cyan, glass, lantern-light,
watching eyes) or `evolution` (red, organic, fungal, wet) or `crossover`, and a
card should be legible as one or the other from across the room, before a word of
it is read. Frames should feel like the vault they live in — leaded glass,
verdigris metal, warm lamplight on cold stone, gilt worn thin — and a sealed or
undiscovered card should read as unlit rather than as missing: the same object
with the lamp behind it out.
