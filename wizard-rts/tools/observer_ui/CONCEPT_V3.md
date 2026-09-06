# Concept fidelity and family records

September 6, 2026. This supersedes the V2 portrait and separate-evolution layout.

## Identity rules

- Oaven are NOT ratmen. Their supplied design has a broad, rounded blue
  reptile/insect head, enormous round cyan eyes, tiny nostrils, small dorsal
  spikes, burgundy scarf, charcoal tunic and scaly limbs. No mammalian ears,
  pointed rat muzzle, fur, whiskers or buck teeth. Filename keywords are not
  permission to override what the actual reference depicts.
- Stone-Faced Serpent has a long snake body, irregular teal stone plates,
  a coral/pink slit-pupil eye and dragonfly wings. No limbs or humanoid anatomy.
- Spawner is quadrupedal: four long weight-bearing legs, a cool pale gray/sage
  shell, dark dusty plum underside, cyan eyes and wings. No yellow/brown egg pile.
- Drones are small slender dragonflies, not miniature round Spawners.

## Vault

concept_portraits_v3.png is an equal 3x2 atlas. Top row: Oaven, Oaven Jumper,
Stone-Faced Serpent. Bottom row: Spawner, Winged Spawner, Spawner Drone.
Kon and Mangler retain their previous portraits. All card text and stats remain
live. Tier hands now list base creations only. Select the card to switch between
base/evolved forms; summoned drones are inside the Spawner's record too.
Evolution chains come from UnitCatalog.evolves_to, not duplicated balance data.
Felled records still obey per-archetype kill discovery. Unresearched forms do
not reveal names/art through their form selector.

## In-game art

Oaven uses a newly cleaned, reference-guided parts sheet, rebuilt with the
existing articulated rig at 768px and downsampled to 384px cells. This replaces
the old direct 256px bake. Runtime 2D scale and 3D pixel size compensate by 1.5,
preserving world size and foot position. All 15 actions and both forms remain.
This improves contour clarity and zoom resolution; it does not turn a cutout rig
into independently hand-drawn frames or an eight-direction model.

Spawner uses a palette-corrected source sheet and the existing 16-action rig,
updated from six to four legs. Frames remain 384px, preserving footprint and
animation timing. Cool shell/plum body colours are baked, so both renderers see
the same result. Gameplay stats, summon costs and cooldowns are unchanged.

Drone has its own generated separated body/forewing/hindwing/death-body sheet.
drone_puppet.gd articulates the wings, body lunge, hit recoil and collapsed pose;
bake_drone.gd exports 60 frames, 12 per action: idle, move, attack, hit, death.
spawner_drone_art.gd plays this atlas in the actual summon scene. Map3DView's
existing Sprite3D mirroring shares frames and facing. Painted death runs after
the gameplay object is removed, then cleans up. Drones still summon under the
existing combat-target, Bio-cost, cooldown and cap rules, not as free ambient units.

## Source provenance

Built-in image generation, with the user's actual references attached to prompts:

| Project asset | Generated original |
| --- | --- |
| assets/ui/observer_vault/concept_portraits_v3.png | exec-48c6494d-e149-482d-923e-bcc838b82f23.png |
| assets_game/units/kon/oaven/painted_v3/source_parts.png | exec-0114865a-9bf4-4dd8-90dc-676bebb36c41.png |
| assets_game/units/kon/spawner/painted_v3/source_parts.png | exec-ef93b575-4c56-4a6d-8897-a816c86c8ed2.png |
| assets_game/units/kon/spawner_drone/painted_v1/source_parts.png | exec-ab1e56d7-2029-43ac-9b6a-70046d2e6ca9.png |

Old source/baked assets are retained, not overwritten. New sheets are shared
between units; Oaven's higher resolution increases texture memory. Each Oaven
form is about 101 MiB uncompressed RGBA8 before driver compression, Spawner about
108 MiB, drone about 15 MiB. Mass-army/performance profiling remains separate.

## Rebuild and verification

Use the project Godot version. Import source images first, run bakes with a real
renderer, then import the finished atlases. Existing magenta-key shader removes
the source background during baking; runtime images have transparent alpha.

```text
godot --headless --path . --editor --quit
godot --path . --rendering-method gl_compatibility --script tools/oaven/bake_oaven.gd
godot --path . --rendering-method gl_compatibility --script tools/spawner/bake_spawner.gd
godot --path . --rendering-method gl_compatibility --script tools/spawner/bake_drone.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/oaven/verify_oaven_art.gd
godot --headless --path . --script tools/spawner/verify_spawner.gd
godot --headless --path . --script tools/spawner/verify_drone.gd
godot --headless --path . --script tools/spawner/verify_drone_3d.gd
godot --headless --path . --script tools/observer_ui/verify.gd
```

Require PASS/zero failures, not merely exit code. Tests check 612 nonempty,
unclipped frames, per-action motion for Spawner/drone, combat-created drones,
facing/state changes, death cleanup, 3D frame mirroring and family navigation.
Set ART_SHOT_DIR for rendered captures using verify.gd and
tools/spawner/shot_concept_units.gd. The latter is an isolated visual review with
enlarged and native-size units, not a battlefield screenshot.
