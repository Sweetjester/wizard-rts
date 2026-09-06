# Mangler Handoff

Implemented in the Godot project, not just a concept sheet. No existing units,
buildings, navigation definitions or research rules were replaced.

## In Game

- Kon's production roster now includes Mangler at tier 2: 145 Bio, 3 population,
  13-second training time. It uses the existing tier research gate and barracks
  production/module flow.
- Base: 320 HP, 5 armor, 30 melee damage, 1.1-second attack interval, 160 movement
  units/second. All balance values are a first playable proposal.
- One momentum stack per 64 simulation units of forward movement; maximum five.
  Each adds 8% movement speed, capped at +40%. Five overhead pips turn coral at
  full charge. The selection panel also reports stacks and speed bonus.
- Stopping, holding, evolution and collisions clear momentum. Idle separation
  and teleports do not generate it. A stalled central-simulation move gets a
  short 0.3-second allowance so skipped simulation frames are not false stops.
- At five stacks, an enemy contact or melee attack adds one 36-damage burst in
  a 100-unit radius. Stacks are consumed before damage dispatch, preventing
  repeated contact explosions. Terrain/friendly contact resets without damage.
- Evolves after 120 XP to Winged Mangler. Uses the shared evolution and upgrade
  reapplication path: 446 HP and 39 attack damage before research, 6 armor.
  Wings do NOT grant permanent flight.
- Select Winged Mangler, choose **Leap Slam**, then click clear ground. Right
  click or Escape cancels targeting. Invalid clicks retain the targeting mode.
- Leap: 384-unit cast range, 112-unit blast radius, 65 damage, 1.5-second enemy
  stun, 14-second cooldown. Timing: 0.3s windup, 0.75s flight, 0.3s recovery.
  The unit cannot perform normal attacks during the leap.
- Leap is deliberately restricted to open ground at the same terrain height,
  not upper building floors. It crosses intervening ground obstructions but
  validates the destination footprint and unit occupancy again on landing.
  A newly obstructed landing returns toward the takeoff point without damage.
  Banish/stun interrupt the leap, retaining its cooldown. Death produces a
  grounded corpse. AOE affects enemy units on the same navigation level only.

## Art and Animation

**Current runtime: eight-direction v2.** See [DIRECTIONAL_V2.md](DIRECTIONAL_V2.md)
for the source paintings, rebuild procedure, frame contract, camera handling,
verification and costs. Both forms now use distinct E/SE/S/SW/W/NW/N/NE pages.
The following v1 description is historical; its atlases and baker are retained
for rollback/reference but are no longer loaded by the Mangler art script.

`assets_game/units/kon/mangler/painted_v1/` contains the original transparent
painted source, portrait, and both runtime atlases. The source uses irregular
pose boundaries; do not replace the authored regions with a uniform grid.
Authored UV outlines exclude neighboring fragments at three atlas corners.

Each runtime atlas is 4608x3456, 12 columns by 9 rows, 384x384 per frame:

| Row | Action |
| --- | --- |
| 0 | Idle breathing |
| 1 | Knuckle run |
| 2 | Windup, punch, recovery |
| 3 | Hurt |
| 4 | Leap crouch |
| 5 | Airborne |
| 6 | Landing compression |
| 7 | Evolution |
| 8 | Death and corpse |

These are 16 painted source poses with timed pose changes and procedural
breathing, bob, lean and squash baked into 216 playback frames. They are NOT
216 independently painted poses, a skeletal 3D model, or an eight-direction
set. The original presentation used two mirrored facings, matching the other
painted units. Base leap rows are unused compatibility rows.

The shared Sprite2D/Sprite3D presentation renders these sheets. The art script
supplies a dynamic foot anchor for the leap arc and owns the momentum pips.
Impact and target indicators work in both 2D and 3D. No custom audio was added.

## Files

- `scripts/units/mangler.gd`: authoritative movement, momentum, combat, leap.
- `scripts/units/mangler_painted_art.gd`: animated presentation and pips.
- `scripts/fx/mangler_impact.gd`: non-damaging visual burst and target rings.
- `scenes/units/mangler.tscn`: unit scene with painted sprite and collision.
- `scripts/core/unit_catalog.gd`: both forms, production and class roster.
- `scripts/core/build_system.gd`: factory mapping.
- `scripts/input/selection_controller.gd`: manual targeting lifecycle.
- `scripts/ui/rts_hud.gd`: production button, Leap Slam and live stats.

## Rebuild and Verification

Run from the Godot project root using Godot 4.6.2:

```text
godot --path . --script tools/mangler/bake_directional.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/mangler/verify_directional.gd
godot --headless --path . --script tools/mangler/verify_mangler.gd
godot --headless --path . --script scripts/core/evolution_stat_integrity_smoke_test.gd
godot --path . --script tools/mangler/preview_directional.gd
godot --path . --script tools/mangler/verify_mangler_ingame.gd
```

Set `ART_SHOT_DIR` to an existing output folder for the two capture scripts.
Baking and screenshots require a graphical renderer, not headless mode.

The focused test covers stack thresholds/caps/resets, friendly and enemy
collisions, one-shot AOE, evolution stats, leap range/occupancy/cooldown,
airborne attack suppression, enemy-only damage/stun, late obstruction,
banish interruption, atlas bounds and painted death spawning.

The live-map test uses the BuildSystem factory, normal pathing to acquire
five stacks, Stop, real selection and manual ground targeting, airborne
rendering, landing/recovery, and saved screenshots. It does not exhaustively
test mass-army performance, every generated terrain layout, or balance.

Existing engine certificate, shader-cache and shutdown resource-leak warnings
are separate from functional test success. Do not treat exit code alone as a
pass: require the printed test PASS/failures=0 marker and inspect script errors.
