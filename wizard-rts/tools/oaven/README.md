# Oaven Art

## Current: Eight-Direction V4

Both Oaven and Jumper now use eight separately illustrated direction pages,
with all 15 animation rows preserved. See [DIRECTIONAL_V4.md](DIRECTIONAL_V4.md)
for production, prompts, runtime contracts, costs, rebuild and verification.
The standard `verify_oaven_art.gd` entry point runs the current v4 verifier.

```text
godot --path . --rendering-method gl_compatibility --script tools/oaven/bake_directional.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/oaven/verify_oaven_art.gd
godot --path . --rendering-method gl_compatibility --script tools/oaven/preview_directional.gd
godot --path . --rendering-method gl_compatibility --script tools/oaven/verify_directional_ingame.gd
```

Set `ART_SHOT_DIR` to an existing writable folder for both rendered review scripts.
The original art and tools remain available for reference/rollback, but the
runtime Oaven script no longer loads the old mirrored atlases.

## Historical: Painted V2

The following notes describe the older asset set, not current runtime assets.

Installed in the existing Oaven scene, without changing combat stats, pathing or
ability rules. The original procedural drawing remains the stress-mode fallback.

## Asset contract

- Two transparent 3072 x 3840 atlases: base Oaven and winged Jumper.
- 256 x 256 cells, 12 columns, 15 action rows; 360 baked frames total.
- One authored three-quarter view, mirrored left/right. Not eight unique views.
- Foot anchor (128,210). Sprite scale 0.598 in 2D; pixel size 0.01014 in 3D.
- Rows: idle, move, attack_spear, attack_blowpipe, hit, death, taunt,
  swap_weapon, charge, takeoff, flying, landing, evolve, idle_blowpipe,
  move_blowpipe.
- Cutout animation, not individually painted frame-by-frame animation.
- The attack clock drives the contact pose. Death is an independent visual
  with no unit registration: 1 second collapse, 1.2 seconds hold, 0.7 seconds fade.

## Rebuild and verify

From the Godot project directory:

```powershell
godot --path . --rendering-method gl_compatibility --script tools/oaven/bake_oaven.gd
godot --headless --path . --editor --import
godot --headless --path . --script tools/oaven/verify_oaven_art.gd
godot --headless --path . --script scripts/core/oaven_unit_smoke_test.gd
godot --headless --path . --script scripts/core/kon_faction_mechanics_smoke_test.gd
```

The baker requires a real graphics renderer; the verifier can run headless.
The verifier checks all frame bounds plus state selection, evolution, facing,
damage reaction and independent corpse playback. It writes preview.png.

Animated review (eight simultaneous action views):

```powershell
godot --path . --rendering-method gl_compatibility --script tools/oaven/preview_oaven.gd
```

Add `-- --capture` to save animation_review.png and exit automatically.

## Artwork provenance and remaining polish

The source part atlas was generated with the built-in image generator using the
user's supplied Oaven concept. A second edit replaced the generator's baked
checkerboard with magenta. The native Godot baker removes that key and animates
the painted parts. Source rectangles and joints are explicit in oaven_puppet.gd.
No image generator or chroma shader is needed at runtime.

This is an initial usable replacement. Additional rear/side artwork, dedicated
blowpipe hand-to-mouth poses and stronger secondary motion would be the next
art pass. The existing unit-card portrait is not replaced by this animation pack.
