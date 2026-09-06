# Painted Unit Production Procedure

## 1. Inspect Before Editing

Read the selected unit scene, gameplay script, art script, UnitCatalog entry,
factory/training path, selection/HUD code and closest focused/live tests. Identify
central simulation entry points as well as normal _process/_physics_process.
Record existing stats, class, footprint, evolution chain and resource costs.
For an art-only task these are invariants, not opportunities to rebalance.

Search by actual archetype ID. Trace a unit from production to its live 3D
billboard. Confirm whether stress-mode fallback art is deliberate. Preserve it
unless replacement of that performance mode was requested.

## 2. Choose The Right Existing Puppet

Articulated cutout (Oaven/Spawner): detached painted limbs, head, torso, wings
and equipment move around explicit joints. Use when repeated limbs, breathing,
wing beats or articulated gait are the central need. Author attachment points,
draw order, local offsets, rotation limits and overlap padding.

Painted key poses (Mangler/Kon): several complete silhouettes switch on a
timeline, with restrained bob, squash and lean between them. Use for readable
windup/contact/recovery poses without pretending it is a full skeletal rig.

Segmented hybrid (Serpent): painted sections are repeated/articulated per
evolution stage; wall tiles are a separate runtime asset. Visual tail geometry
is not automatically collision geometry.

Do not force all units into one technique or create a generalized rig framework
for one task. Copy the nearest behavior and change only required ownership.

## 3. Plan Source Art And Clips

Define before generation: forms, facing policy, actions, contact moments, frame
size, atlas rows/columns, foot anchor, maximum silhouette and FX envelope.
Idle/move loop; attacks and death do not. Separate ability windup, active and
recovery when gameplay has those phases. Include hurt and an actual final corpse.

Prompt scaffold:

"Production source for [unit] using the attached approved reference. Dark
hand-painted miniature aesthetic, bold inked contours, [specific materials],
[distinctive silhouette]. Consistent three-quarter view and scale. Produce
[explicit detached parts OR named full-body poses]. Entire silhouettes visible,
generous isolated margins, true transparent background, no labels, scenery,
ground plane or baked contact shadow. Preserve anatomy across every pose."

Use the available image-generation tool for source imagery. Archive the exact
prompt, input reference and unmodified result. Availability is a prerequisite;
do not silently substitute programmer-drawn placeholder art and call it final.

## 4. Author And Bake

Inspect dimensions and alpha, map source rectangles individually, and use masks
for genuine interleaving when necessary. Never assume a generated sheet is a
perfect grid. The Mangler REGIONS and UV outlines are a concrete example.

Render the puppet into a transparent Godot SubViewport, sample deterministic
action phases and assemble the runtime Image atlas. Existing bakers use twelve
samples per action. That is a convention, not a requirement to waste frames.
Loop phases typically use frame/count; one-shots include their final pose using
frame/(count-1). Keep the endpoint behavior intentional.

Anchor all frames consistently. Size to the largest required silhouette, then
verify empty borders. Spawner renders oversized before downsampling; preserve
this only if appropriate to the target quality and budget. Reimport generated
files before runtime verification. Baking needs a real graphics renderer.

Do not call interpolated or transformed frames separately painted artwork.
Keep source art and tools offline; runtime loads the final shared atlases.

## 5. Integrate Presentation And Gameplay

Use the scene's established ArtSprite and shared Sprite3D bridge. Record hframes,
vframes, action order, playback durations, 2D scale, pixel size and foot metadata.
Mangler's contract uses 384px frames, 12 columns, 9 rows and foot_anchor_y=330;
Oaven uses a different anchor. Never copy these numbers without measuring.

Derive visual state from authoritative gameplay. Define state priority explicitly
so a hit reaction cannot hide a critical landing or a dead unit resume running.
Use existing event callbacks/timestamps for actual attacks, summons and casts.
For a new ability, specify target validation, team policy, cooldown/resource
charge point, interruptions, elevation policy and landing revalidation first.

Damage, poison, evolution, collision, fog vision and navigation belong to the
simulation. FX scripts never apply a second copy of damage. Successful impact
drives presentation, not the other way around. Keep leap height visual unless
the mechanic explicitly changes traversability; wings do not imply flight.

Spawn death as a visual-only object after the unit is removed. It must not
remain in units/targetable groups or grant vision, and must clean up its 2D/3D
presentation. Check fog and banishment visibility for auxiliary pips and FX.

## 6. Verify And Deliver

Focused tests must check atlas dimensions/bounds, states/facing, form changes,
event synchronization, corpse cleanup and all new mechanic edge cases. Exercise
central simulation paths; directly calling the ability alone is insufficient.

For mechanics: test repeat activation, death/stun/banish interruption, invalid
targets, resources, friendly/enemy cases, wrong floor and late obstruction where
applicable. Reapply shared upgrades through the established evolution system;
run evolution_stat_integrity_smoke_test.gd when changing forms or stats.

Live test: instantiate through BuildSystem, train/select/order with normal
systems, acquire the state through actual movement/combat, exercise targeting
and capture both ordinary and evolved presentation. Review at gameplay scale.

Representative commands from project root (resolve local Godot executable):

```text
godot --path . --script tools/mangler/bake_mangler.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/mangler/verify_mangler.gd
godot --headless --path . --script scripts/core/evolution_stat_integrity_smoke_test.gd
godot --path . --script tools/mangler/shot_mangler.gd
godot --path . --script tools/mangler/verify_mangler_ingame.gd
```

Adapt these to the new unit; do not report Mangler tests as new-unit coverage.
Set ART_SHOT_DIR to an existing output directory. Require exit status, explicit
PASS marker and inspected logs. Document skipped tests and scope limits.
