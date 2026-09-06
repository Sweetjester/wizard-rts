# Shared Art Direction And Quality Gates

## Visual Identity

The user's target: a sinister fantasy board-game miniature sculpted from wood,
clay and stone, then painted by hand. Dark illustrated surfaces, bold inked
contours, deliberately uneven edges and readable material changes. Translate
the supplied reference; do not merely tint generic geometry blue.

- Stone/chitin: blue-grey and muted teal, pale chipped edges, dark joints.
- Structure: charcoal iron, weathered wood, layered slabs and supports.
- Living accents: burgundy/red vines, membranes, fungi and cloth.
- Magic: concentrated cyan eyes, windows, glass and seals; dark framing keeps
  the light readable. Do not turn entire surfaces into flat emissive rectangles.
- Contrast: quiet broad forms, medium structural detail, sparse fine marks.
  Preserve light/dark separation at the actual RTS camera distance.
- Windows have frames, depth, divisions and nearby light response. Emission
  alone is not light spill; use existing lights or deliberate painted response.
- Give each asset identifying shapes: vault door/books, lab vats/crest,
  observatory dome, Mangler knuckles, Spawner brood abdomen.

These are art choices, not mandatory literal RGB values or an instruction to
make every creature share identical anatomy. Sample the approved project art.

## Source Art Must Be Usable

For units request isolated full silhouettes or detached parts, a consistent
three-quarter camera and light direction, generous spacing, no typography,
no scenery and true transparency. Inspect the actual alpha channel. A painted
checkerboard is not transparency. If keying is necessary, use a uniform color
absent from the character and test edge fringing against both dark and light.

For textures request flat production surfaces, not a perspective scene with
ambient scenery baked in. Label quadrant/UV layout in the task data, not on the
painted texture. Test tiling only where repetition is required. Reserve margins
between atlas regions to avoid filtering bleed. Keep emissive masks separate
when the established material path supports them.

Generated artwork often has inconsistent pose boundaries, fused anatomy,
clipped wings or baked backgrounds. Fix the source or authored region map;
do not hide these defects with aggressive cropping or giant bloom.

## Required Visual Review

Capture the ACTUAL Godot output, using a graphical renderer:

1. Neutral close view: silhouette, materials, transparency and clipping.
2. Normal gameplay camera: compare next to a familiar unit/building at the
   same zoom and lighting, not two independently resized screenshots.
3. Animated unit review: idle, movement, attack contact/recovery, hit, death,
   evolution and every ability state. Include both facings and largest form.
4. Building views: front three-quarter, opposite side, interior, gates open
   and closed; show a real unit using the entrance and elevated route.
5. Crowded/terrain view: check identification, fog visibility, overlap and
   unexpected emissive washout. Report performance scope actually exercised.

Contact sheets cannot prove temporal smoothness. Review playback or a sequence
at several points through each action. Nonblank pixel checks cannot prove that
the correct asset, readable animation or valid route was rendered.

## Reject Before Handoff

- Clipped weapon, wings, tail, feet, corpse or VFX at any playback frame.
- Checkerboard/magenta remnants, halos or neighboring atlas fragments.
- Sliding/floating ground anchor during idle; unjustified size changes across poses.
- Attack VFX firing with no successful gameplay event, or duplicate damage from art.
- A doorway shown open while navigation treats it as closed, or vice versa.
- Decorative geometry crossing a walkable aisle, stairs or required headroom.
- Unreadable ability state, unexplained silhouette changes, excessive cyan glare.
- A screenshot from a standalone mockup presented as proof of real-map integration.
- Passing full-size master tests used to certify a different compact runtime plan.

## Review Rubric

Score each 0 (fails), 1 (needs work), 2 (matches approved baseline): silhouette,
faction materials, visual hierarchy, animation/architecture clarity, gameplay
camera readability, clean integration. Provide one piece of evidence per score.
Any 0 blocks REVIEW_READY. A 1 requires an explicit remaining-polish note.
This rubric is a proposed repeatability tool, not a claim of objective aesthetic
measurement. User approval is still required for final art acceptance.

## Honest Limits And Budgets

Report source-pose count separately from baked frame count. Say mirrored
facings, not eight directions. Say cutout or pose-based, not skeletal animation.
Do not promise concept-art equivalence at every camera distance.

Estimate texture memory as width * height * 4 bytes for uncompressed RGBA8,
then account for mipmaps (approximately another third), forms and driver format.
Mangler's two 4608x3456 sheets are about 121.5 MiB combined before mipmaps;
Spawner's 4608x6144 sheet is about 108 MiB. These are costs, not ideal targets.
Choose the smallest frames that retain approved gameplay readability. Share
textures between instances; never load or crop the source sheet per live unit.
