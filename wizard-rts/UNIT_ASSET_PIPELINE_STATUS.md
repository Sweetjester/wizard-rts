# Wizard RTS Unit Asset Pipeline Status

Last updated: 2026-05-31

## Current Pipeline

The current automated unit pipeline lives in `tools/unit_pipeline/`.

Flow:

1. Unit YAML spec, for example `units/specs/oaven_spear.yaml`
2. Local concept art from `art/concepts/...`
3. Meshy Image-to-3D via `tools/unit_pipeline/create_unit.py`
4. Raw model saved to `art/generated_models/<unit_id>/`
5. Blender normalization via `tools/unit_pipeline/blender_process_unit.py`
6. Processed GLB saved to `art/processed_models/<unit_id>/<unit_id>.glb`
7. Godot generated scene/data via `tools/unit_pipeline/godot_create_unit_scene.gd`
8. Generated output in `game/units/generated/<unit_id>/`

The Oaven Spear has also been manually bridged into the playable 2D RTS runtime through `scenes/units/oaven_spear.tscn` and `scripts/units/oaven_spear.gd`.

## What Works

- Meshy can produce usable rough 3D volume from concept art.
- Blender can normalize scale, orientation, names, GLB export, and placeholder root actions.
- Godot scene generation creates predictable nodes:
  - `UnitRoot`
  - `ModelRoot`
  - `AnimationPlayer`
  - `SelectionCircle`
  - `HealthBarAnchor`
  - `ShadowBlob`
  - `VFXRoot`
  - `ProjectileSpawn`
  - `MeleeHitMarker`
- The pipeline is good enough for fast playable placeholder iteration.

## Current Problems

- No real reusable rig library yet.
- Placeholder animations are only root motion/action placeholders, not authored creature motion.
- Meshy preserves too much noisy source texture detail.
- Imported material style is not consistent enough.
- Current output can look glossy, noisy, or generically AI-generated.
- The generated model can include concept-sheet props or presentation bases that should be cleaned up manually or through stronger source image conditioning.
- Style was previously described too broadly as `painterly_npr`; that was not enough to force the Darkest-Dungeon-like read.

## New Art Target

The new target is a Darkest-Dungeon-2-inspired dark painterly RTS style:

- heavy inked silhouettes
- matte surfaces
- dark value structure
- warm/cool painterly contrast
- strong readable shape language
- controlled cyan KON emissive accents
- no photorealism
- no glossy PBR look
- no tiny noisy texture detail

The target is not to copy Darkest Dungeon 2 assets directly. It is to adopt the same readability language: strong outlines, dark masses, painterly material blocks, and tactical readability.

## Pipeline Amendment

Added style profile support:

- `tools/unit_pipeline/style_profiles/darkest_dungeon_2_like_kon.json`

Updated Oaven spec:

- `units/specs/oaven_spear.yaml`

Updated Blender processing:

- discards imported AI materials when the style profile requests it
- remaps meshes into a fixed KON material palette
- applies dark matte body, blood-red cloth, dark weapon, cyan wing/crystal/emissive materials
- disables PBR texture generation from Meshy by default
- applies flat shading and weighted normals
- removes loose geometry and merges close vertices
- decimates topology to reduce noisy shape density while preserving silhouette
- can create an inverted black outline proxy shell

## Current Style Profile

`darkest_dungeon_2_like_kon.json` defines:

- Meshy concept-art guidance
- positive/negative prompt language for upstream concept generation
- Blender mesh cleanup settings
- material palette
- material assignment keyword rules
- Godot expectations

## How To Run

Dry run:

```powershell
python tools\unit_pipeline\create_unit.py units\specs\oaven_spear.yaml --dry-run
```

Reuse the current Meshy model and restyle through Blender/Godot:

```powershell
python tools\unit_pipeline\create_unit.py units\specs\oaven_spear.yaml --skip-meshy --force
```

Generate from scratch through Meshy:

```powershell
python tools\unit_pipeline\create_unit.py units\specs\oaven_spear.yaml --force
```

## Important Next Step

The best way to get closer to the middle reference is to feed Meshy a cleaner source concept:

- orthographic or three-quarter unit sheet
- no UI frame
- no large presentation base
- no extra unrelated background
- clear separate front silhouette
- same dark painterly style
- large readable weapon and faction props

The current third screenshot is a good proof that the pipeline works technically, but it is importing too much presentation/noise. The new style profile will make it darker and more coherent, but the input concept still matters a lot.

## Animation Status

Animations are not solved yet.

Current state:

- Blender creates placeholder actions: `idle`, `move`, `attack`, `death`
- They are not creature-specific
- There is no reusable skeleton archetype library yet

Recommended next milestone:

1. Create reusable rig archetypes:
   - humanoid
   - small creature
   - flying insect
   - serpent
   - quadruped
2. Add an auto-rig or rig-retarget stage.
3. Replace placeholder root actions with reusable animation clips.

## Short Assessment

The pipeline is in a good prototype state:

- good at producing first-pass generated assets
- weak at enforcing art style without a style profile
- weak at animation
- ready for a restyle pass using Blender material remapping and better concept conditioning
