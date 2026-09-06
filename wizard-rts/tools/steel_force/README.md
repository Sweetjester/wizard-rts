# Steel Force: First Playable Unit Set

Steel Knight now uses [eight-direction v2](KNIGHT_DIRECTIONAL_V2.md), including
the half-health rider spawned by the Mounted Knight. Its original mirrored
sheet is retained as authoring history, not the live infantry presentation.

Poorper now uses [eight-direction v2](POORPER_DIRECTIONAL_V2.md). The original
two-direction art description below remains historical; Knight and Blimp are
unchanged by the Poorper upgrade.

Tier 3 addition: see [Mounted Knight](MOUNTED_KNIGHT.md) for the eight-direction
armoured bull rider, momentum/12-second flaming axe, half-health dismount,
reproducible art pipeline and tests. It joins the sandbox roster and waves from 7.

September 6, 2026. Three new enemy-faction units using generated painted poses,
offline Godot baking and the existing Sprite2D/Sprite3D presentation. Kon units,
buildings, tech trees and the existing Deom roster are not replaced.

## Units And Provisional Balance

| Unit | Tier | HP / armor | Movement | Attack |
| --- | --- | --- | --- | --- |
| Poorper | 1 | 100 / 2 | 145 simulation units/s | 12 melee, 0.9s interval |
| Steel Knight | 2 | 340 / 10 | 90 simulation units/s | 38 melee, 1.4s interval |
| Proper Blimp | 2 | 280 / 4 | 110 simulation units/s airborne | 10 projectile damage, 44-unit splash, 2.5s interval, 384 range |

IDs: poorper, steel_knight, proper_blimp. These numbers are initial tuning, not
user-approved balance. Knights remain ground infantry; they have no added magic
ability despite the sword's glowing appearance. No automatic evolution chain
was invented for this faction.

## Try Them

From the Godot project root, with the local Godot executable:

```text
godot --path . --script tools/steel_force/play_steel.gd
```

This opens a fresh normal map with the Steel Force wave option. The existing
grace period and wave schedule remain: Poorpers first, Knights from wave 2,
crewed blimps from wave 4. Steel units are also registered with the existing
testing ground unit browser/spawn factory. They are not added to Kon's barracks
roster.

**Since 2026-09-06 the Steel Force is the game's default enemy faction**
(`WaveDirector.enemy_faction`, at Andrew's request). Waves, the build sandbox's
target dummy, the Kon vertical slice's outpost defenders and the Arcane
Citadel's garrison all field it. The Deom Legion is untouched and still
spawnable by archetype -- set `enemy_faction` back to `deom` to restore it
everywhere at once.

Two things follow from the switch and are worth knowing before balancing:

- The Steel Force has **no ranged infantry**. The Proper Blimp is its only
  ranged unit and it flies. Anywhere the Deom Legion held a position with
  Crosshirrans -- the citadel gate, the keep, the outposts -- now holds it with
  Steel Knights instead: much tougher, no ability to shoot down off a wall.
- The build sandbox has a spawn button per unit, built from
  `WaveDirector.enemy_roster()`, so it follows the faction rather than naming
  units of its own.

Player-owned test blimps expose Land, Take Off, Board Poorpers and Unload Poorpers
in the existing selection panel, with a crew count. Move near friendly Poorpers,
land on clear terrain, board, take off, move, land and unload. Crew loading is
proximity-based, not drag-and-drop seat assignment.

## Transport Contract

- Capacity is exactly three same-owner Poorpers, not Knights or other units.
- Boarding requires landed, living, unstunned carrier and nearby living,
  unstunned, unbanished Poorper on the same authored level (130-unit proximity).
- Passengers remain the same objects with HP/owner intact and still count as
  units for population accounting. They lose selection/collision and use the
  shared non-interactable visibility/query exclusion while aboard.
- Passengers cannot move, attack or grant independent vision. This uses the
  existing kon_banished exclusion metadata without starting a banishment timer;
  unit.embarked records the distinct transport state. Status time progression
  while aboard follows that exclusion, rather than a new transport-status model.
- The blimp can move empty, but cannot fire without crew. It cannot fire while
  landed. Crew does not multiply damage; no separate gunner simulation was added.
- Land validates clear, level terrain under the footprint. Landed movement is
  disabled. Visual altitude eases to the new stance; the gameplay stance changes
  immediately, rather than a separately cancellable landing cast.
- Unload searches sixteen nearby positions, validates terrain, same ground
  elevation and unit spacing. Blocked passengers stay aboard. Partial unload is
  allowed; they are never deleted because an exit is blocked.
- No disembarking onto upper building floors, no permanent ground driving, and
  no teleport rescue. Carrier destruction kills its passengers. This last rule
  is an explicit initial design choice, suitable for later balance review.
- Crew presence is rendered by separate portrait markers in both presentations.
  The ship source contains empty seats, so an empty ship does not retain painted
  phantom crew. Markers are a first pass, not individually animated seated rigs.

Enemy wave blimps spawn with three real Poorpers. Existing enemy attack-move AI
flies and fires them; autonomous tactical landing/drop selection is NOT included.
Manual transport controls work on player-owned testing-ground instances.

## Art Contract

Assets: assets_game/units/steel_force/painted_v1/.

The source sheets were generated from the three user-provided references using
the built-in image generator. Poorper and Knight each use eight full-body key
poses; blimp uses four. Poorper/Knight required a follow-up background edit to
flat magenta. The keyed sources are preserved, and the existing offline chroma
shader creates transparent runtime images. Source region maps and corner masks
are authored in steel_puppet.gd, not inferred from an equal grid.

Faction identity: stitched dark helmet, mustard wraps, worn silver plate,
amber eyes and lamps, bold ink contours. No Kon cyan reskin was substituted.

Each runtime atlas is 4608x2304, 384px cells, twelve columns and six rows:
idle, move, attack, hit, death, landed/ready. Three sheets contain 216 baked
frames total, from twenty source poses. These are pose-based animations with
procedural bob/lean/compression, not 216 independent paintings, skeletal 3D
characters or eight-direction art. Facing is mirrored left/right.

All use foot-anchor metadata; scale differs by unit. Runtime loads shared baked
textures, not the original source sheets. Each atlas is about 40.5 MiB RGBA8
before mipmaps/driver compression. No custom audio was added. Blimp projectiles
use the existing shared projectile implementation, not a new ballistic-arc engine.

The unit art observes gameplay attack timestamps. Existing immediate melee
damage remains authoritative; this first pose-based presentation is not a new
delayed-contact combat system. Future polish can author anticipation synced to
a dedicated windup event, rather than changing damage timing inside art code.

## Files

- scripts/units/steel_force_unit.gd: shared ground infantry and transport exclusion.
- scripts/units/proper_blimp.gd: flight/landing, crew, unload, artillery gating.
- scripts/units/steel_force_art.gd: shared atlas playback and foot alignment.
- scenes/units/poorper.tscn, steel_knight.tscn, proper_blimp.tscn: live scenes.
- scripts/core/unit_catalog.gd: faction entries and provisional stats.
- scripts/core/weapon_catalog.gd: weak artillery projectile definition.
- scripts/core/build_system.gd: scene factory registration only, no Kon training unlock.
- scripts/core/wave_director.gd: optional Steel wave composition and crew spawning.
- scripts/ui/rts_hud.gd: testing-ground eligibility and transport actions/count.
- tools/steel_force/steel_puppet.gd, bake_steel.gd: offline source assembly/baking.

## Rebuild And Verify

```text
godot --path . --rendering-method gl_compatibility --script tools/steel_force/bake_steel.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/steel_force/verify_steel.gd
godot --headless --path . --script scripts/core/deom_legion_smoke_test.gd
godot --path . --script tools/steel_force/shot_steel.gd
godot --path . --script tools/steel_force/verify_steel_ingame.gd
```

Set ART_SHOT_DIR to an existing output directory for captures. Baker and graphical
review need a real renderer. Require fresh PASS/failures=0 markers and inspect
script errors, not exit status alone.

Focused tests exercise roles/melee, crewed projectile hits, empty-gun rejection,
capacity, duplicate boarding, invalid passengers, collision/selection exclusion,
airborne/blocked unloading, ground landing, object restoration/spacing and carrier
death cleanup. Atlas tests check dimensions, transparent background and all rows.
Live-map tests exercise the wave selection option, real unit scenes, landing,
boarding three units, travel, unload and a 3D screenshot.

These tests do not certify mass-army performance, multiplayer/save migration,
all terrain seeds, all HUD mouse interactions or tactical drop AI. Existing
Godot certificate/shader cache and shutdown resource warnings remain separate.
