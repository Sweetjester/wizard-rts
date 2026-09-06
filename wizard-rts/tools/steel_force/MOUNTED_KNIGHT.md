# Mounted Knight: Steel Force Tier 3

Implemented September 6, 2026. This adds a new mounted archetype; it does not
replace the existing Tier 2 Steel Knight or invent a Steel Force evolution tree.
The user described the charge reference as Kon's "wrangler"; the implemented
Mangler is the momentum reference in this project.

## Visual Contract

Scale correction (2026-09-06): `mounted_knight_art.gd` applies a shared
`VISUAL_SCALE = 1.65` to the original 2D sprite scale and 3D billboard pixel size.
The rider now matches the foot Knight's proportions instead of fitting both bull
and rider into an infantry-sized silhouette. The foot anchor stays at source
pixel 218. Corpse rendering inherits the enlarged visual size; gameplay collision,
movement, damage, health and the dismounted Tier 2 Knight remain unchanged.
`tools/steel_force/verify_mounted_scale.gd` renders six side-by-side comparisons
and checks scale, anchoring, corpse inheritance and stats. The existing
`verify_mounted_ingame.gd` also passes after this correction, including eight
camera-relative directions and dismounting.

- An armoured bull, not a horse: broad bovine muzzle, nose ring, large outward
  horns, round shoulder plates, heavy hooves and a squat, powerful chest.
- Horned-helmet knight with a long crescent axe, tattered ivory cape/pennant,
  chipped gray/ivory armour, old brass fittings and dark drawn outlines.
- Amber/orange weapon fire belongs to the Steel Force. Do not recolour this
  asset cyan or replace the illustrated surfaces with shiny PBR materials.
- Eight authored directional pages: E, SE, S, SW, W, NW, N, NE. No horizontal
  mirroring. Rear views show cape and saddle; front views show muzzle and horns.
- Death art contains the fallen mount only. The living rider becomes a separate
  Tier 2 unit immediately, so the corpse must not contain a second dead rider.
- ArtSprite opts into `preserve_painted_palette`: the 3D renderer preserves its
  painted colours rather than multiplying enemy red across ivory armour. This
  is opt-in; existing units retain their current tint behavior. Ownership and
  selection remain in existing rings/health bars.

## Gameplay And Provisional Balance

| Setting | Initial value |
| --- | --- |
| Archetype / scene | mounted_knight / scenes/units/mounted_knight.tscn |
| Tier / faction | 3 / steel_force |
| HP / physical armour / magic armour | 620 / 14 / 2 |
| Base melee damage / cooldown / reach | 54 / 1.25 seconds / 1.2 cells |
| Base speed | 3.2 cells/second (204.8 simulation units/second) |
| Momentum | 1 stack per 64 units of forward commanded travel, maximum 5 |
| Speed per stack | +8%; maximum +40% |
| Ignited damage | x1.5 current damage; baseline 81 before armour |
| Flame duration | 12 simulation seconds |
| Population / placeholder bio cost / train time | 5 / 300 / 26 seconds |

All non-user-specified numbers are initial tuning, not a claim of balanced play.
The catalog owns them. The new scene is available from the test spawn factory
and Steel Force sandbox roster, and appears in normal Steel Force waves from
wave 7 (every ninth composition slot). It is NOT a Kon barracks recruit.

### Momentum And Flame Rules

`scripts/units/mounted_knight.gd` extends RTSUnit, preserving the project's combat,
pathing, ownership, stun, banishment, upgrade and death hooks. It uses the narrow
distance-based charge approach already used by Mangler; it does not inherit the
Mangler's leap, evolution or impact AoE.

Only forward progress on an active path earns charge. Negative distances, idle
separation and implausible teleports do not. Stops, hold orders, attacks, same-
level unit collisions and blocked movement clear momentum. Stun/banishment
cannot accumulate it. Terrain-ignoring units are excluded from ground contact.
Central mass movement uses the existing blocked-motion grace of 0.3 seconds.

Crossing from below 5 stacks to 5 starts flame only when not already burning.
The active 12-second buff is NOT refreshed by holding 5 stacks or recharging
during its lifetime. Stopping or colliding clears speed stacks but does NOT
extinguish the axe. After expiry, a fresh below-5-to-5 crossing is required.
This edge-trigger rule prevents indefinitely refreshing the buff every tick.

Damage is multiplied at the authoritative attack event, exactly once, without
overwriting `attack_damage`. Existing incoming damage multipliers still compose.
`current_attack_damage_for_display()` lets live Vault specimen stats include the
buff. Enemy field records remain catalog baselines under the existing Vault
design; the new unit is not revealed there until felled by the player.

### Dismount Rules

On mounted death, instantiate the existing `steel_knight.tscn` once. Preserve
owner, world position, authored navigation level and arena leash. Continue a
valid attack target, or the previous destination as attack-move. Transfer the
current selection to the rider for a player-selectable mount.

Apply applicable player research before setting the rider to ceiling(max HP/2),
minimum 1. The unmodified enemy rider therefore has 170/340 HP, not half of the
mounted unit's 620 HP. It is a fresh Tier 2 unit, not a copy of mount-only charge,
flame, damage, statuses or evolution data. Its ordinary death cannot dismount
again. The mount still executes the base death hooks once, including discovery
and corpse creation. The returned knight uses its existing two-facing T2 art;
the eight-direction artwork in this task belongs to the mounted form.

A one-shot `dismounted_spawn` metadata guard skips the Steel Knight's deferred
ground-spawn snap. Without it, a rider dismounting on an upper floor can be
teleported to the ground. Mounted Knights map to the authored `heavy` block-nav
class; riders return to existing `infantry`. This uses existing heavy rules
(2x2 clearances, ramps rather than infantry stairs/ladders), not a replacement
for the game's general terrain/flow-field collision system.

## Reproducible Art Pipeline

Runtime/source directory:
`assets_game/units/steel_force/mounted_knight/directional_v1/`

1. Read `tools/asset_production/STYLE_AND_QUALITY.md` and inspect the user concept.
2. Generate raster pose sheets with the built-in image generator, with the
   concept and accepted directional art as visual references. Exact accepted
   prompts and source assignments are in `mounted_prompts.json` beside this file.
3. Request a fixed 5-column x 2-row sheet on flat magenta, entire subject inside
   each cell, no captions/grid. Judge actual visible heading, not just its label.
   Repeated headings and missing axes were rejected in the initial attempts.
4. Keep accepted full-resolution source PNGs in `sources/`, including concept.png.
   Source sheets have different canvas sizes; do not assume every source is square.
5. `mounted_puppet.gd` finds connected non-magenta silhouettes, groups their bounds
   into the ten slots, and draws through the existing Oaven chroma-key shader.
   This removes magenta instead of shipping a fake checkerboard background.
6. One shared scale per direction fits the largest pose in a 256px runtime cell;
   all poses share a bottom-centre foot anchor at (128,218). Do not independently
   resize each pose, which makes galloping look like a growing/shrinking unit.
7. `bake_mounted.gd` renders at 512px and downsamples to 256px using Lanczos.
   It combines source poses with breathing, bob, compression, cloth displacement,
   directional attack motion, hit recoil and corpse settling. Combat events
   remain in simulation code, never in generated image content.
8. Import pages, then run `configure_mounted_imports.gd` and reimport. The eight
   runtime atlases use high-quality GPU compression with alpha-border fixing.
   Source artwork is retained for reproducibility, not loaded by runtime actors.
9. Run headless contract tests, graphical contact sheets and the real-map test.
   Inspect normal, flaming, moving and dead states. Hash variation proves frames
   differ, not that an animation is artistically correct; visual review is required.

### Source Slots And Runtime Rows

Source top row: idle, gallop A, gallop B, normal attack, dead bull without rider.
Source bottom row: flaming idle, flaming gallop A, flaming gallop B, flaming
attack, hit recoil. Some generated recoil poses dropped the axe, so slot 9 is
deliberately unused: both hit reactions deform the correct idle pose instead.

| Runtime row | Action | Frames |
| --- | --- | --- |
| 0 | Idle | 8 |
| 1 | Gallop | 8 |
| 2 | Momentum gallop | 8 |
| 3 | Attack and recovery | 8 |
| 4 | Ignition | 8 |
| 5 | Burning idle | 8 |
| 6 | Burning gallop | 8 |
| 7 | Burning attack | 8 |
| 8 | Hit | 8 |
| 9 | Fallen mount settling | 8 |
| 10 | Burning hit | 8 |

Eight pages, each 2048x2816, with 8 columns x 11 rows of 256px cells. Total:
**704 runtime frames derived from 72 used source poses** (80 generated accepted
source slots). These are NOT 704 individually illustrated animation drawings.
The normal/flaming attack starts on contact because RTSUnit applies damage on
that event; the later frames recover. Death starts with the mount-only pose to
avoid visually duplicating the living rider.

`mounted_knight_art.gd` uses shared `eight_direction_facing.gd`, remembers idle
heading, prioritizes living attack targets, and resolves camera-relative heading
before Map3DView copies the texture/frame. Pages are cached/shared, not loaded
per unit. At BC7/BPTC one page is approximately 5.5 MiB, all eight approximately
44 MiB, excluding import/source files and small portrait overhead. Confirm the
actual target platform's compressed format when making export budgets.

## Commands And Validation

Run from the Godot project directory; replace `godot` with the installed console
executable. Baking and graphical checks need a renderer, not `--headless`.
Set `ART_SHOT_DIR` to an existing absolute output folder for captures.

```text
godot --path . --rendering-method gl_compatibility --script tools/steel_force/bake_mounted.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/steel_force/configure_mounted_imports.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/steel_force/verify_mounted.gd
godot --path . --rendering-method gl_compatibility --script tools/steel_force/preview_mounted.gd
godot --path . --rendering-method gl_compatibility --script tools/steel_force/verify_mounted_ingame.gd
godot --headless --path . --script tools/steel_force/verify_steel.gd
godot --headless --path . --script scripts/core/steel_force_sandbox_smoke_test.gd
```

For a partial bake append `-- e se`, for example. Reimport after rebaking.

The mounted contract suite checks all 704 frames for nonblank/unclipped output,
motion per action, distinct direction pages, compression, stack thresholds,
damage composition, expiry/non-refresh, stop/collision/stun/banish behavior,
animation selection, facing memory, elevated dismount, selection transfer,
one-rider-only death and half HP after upgrades.

The in-game test uses the actual generated terrain, BuildSystem, WaveDirector,
BlockNavBridge, SelectionController, GameSession and Map3DView. It earns ignition
through real movement, checks eight camera yaws and foot anchoring, then kills
enemy/friendly mounts and checks riders, discovery and 3D corpses. It captures
1600x1000 and 1024x720 views. The contact sheet captures seven actions at three
phases each for visual comparison. Existing Steel Force tests protect transports
and roster-driven sandbox spawning.

### Verification Recorded On September 6, 2026

- `verify_mounted.gd`: exit 0, `failures=0`; all 704 cells checked.
- `preview_mounted.gd`: completed all seven action captures at three phases;
  idle, gallop, burning attack and mount-only corpse sheets visually inspected.
- `verify_mounted_ingame.gd`: exit 0, final PASS; real movement reached ignition
  after approximately 1.5 seconds on the flat test route. Desktop and small
  captures were inspected. The test caught and corrected enemy colour tinting;
  its friendly-selection fixture was also corrected to respect enemy selection
  restrictions. This is not a claim that hostile units are player-controllable.
- `verify_steel.gd`: exit 0, `failures=0`.
- `steel_force_sandbox_smoke_test.gd`: exit 0, roster/spawn-button checks passed.
- `block_nav_world_smoke_test.gd`: exit 0, authored elevation/link rules passed.
- `vault_research_smoke_test.gd`: exit 0, existing research lifecycle checks passed.
- `git diff --check`: clean at completion.

The successful runs still emitted the environment's root-certificate warning
and/or engine shutdown resource/RID leak reports, also seen in the pre-existing
Steel Force tests. No script errors occurred in the final mounted contract or
in-game run. Shutdown cleanup and fleet-scale profiling are not certified here.

## Limits And Future Work

- This is pose-based illustrated sprite animation, not a skinned 3D cavalry rig
  or a fully hand-drawn multi-frame walk cycle. Fine pose-to-pose anatomy varies.
- Eight headings support yaw changes; the artwork still has one authored camera
  pitch. Arbitrary top-down/low-angle pitch cannot gain missing 3D information.
- Corpse pages capture the direction at death and do not change under later yaw.
- Fire is painted into the animation, not a dynamic light cast onto nearby
  buildings. No fire DoT, charge splash, trample or knockback was added.
- Existing Tier 2 rider artwork was reused, not silently upgraded to eight views.
- Balance, very large cavalry swarm performance and non-Windows export rendering
  require playtesting. Existing editor/headless shutdown resource warnings should
  be distinguished from script failures; do not claim zero engine warnings.
