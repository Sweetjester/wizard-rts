# Kon Unit Asset Generation Template

This is the working asset contract for Kon's faction. Generate assets to this shape so the game can plug them into unit animation profiles without rework.

## Shared Sprite Rules

- File type: transparent PNG sprite sheets, plus optional JSON metadata.
- Camera: 2D isometric RTS, readable at gameplay zoom, bottom-center foot anchor.
- Directions: 8 directions for release assets.
- Direction row order: `S, SE, E, NE, N, NW, W, SW`.
- Team color: leave one clean accent region that can be tinted red/cyan/green in engine. Do not bake team color into the whole unit.
- Shadow: do not bake heavy ground shadows into the sprite. Use a soft contact shadow only if needed; engine handles primary shadows.
- Effects: keep spell/projectile sprites separate from the body sheet.
- Naming: `assets/units/kon/<unit>/<form>/<action>.png`.
- Metadata: place beside each sheet as `<action>.json`.

## Standard Sheet Metadata

```json
{
  "unit": "terrible_thing",
  "form": "base",
  "action": "move",
  "frame_size": [128, 128],
  "directions": ["S", "SE", "E", "NE", "N", "NW", "W", "SW"],
  "frames_per_direction": 8,
  "fps": 12,
  "anchor": [64, 108],
  "hit_flash_mask": true,
  "team_tint_mask": true
}
```

## Frame Sizes

- Terrible Thing / Gripper: `128x128`.
- Horror / Hunter: `128x128`.
- Apex / Champion: `160x160`.
- Spawner / Winged Spawner: `192x192`.
- Bad Kon Willow: `160x192`.
- Drone: `96x96`.
- Projectiles: `64x64`.
- Small spell impacts: `128x128`.
- Large AOE and transformation effects: `192x192` or `256x256`.

## Required Actions

Every unit form needs:

- `idle`: 6 frames per direction.
- `move`: 8 frames per direction.
- `attack`: 8-12 frames per direction with a clear release frame.
- `hit`: 4 frames per direction.
- `death`: 10-16 frames per direction.
- `evolve`: 16-24 frames, directionless or 8-direction if the silhouette changes heavily.

Ability sheets:

- Terrible Thing: `charge`, `grapple`, `death_explode`.
- Gripper: `charge`, `grapple_aoe`.
- Horror: no active ability, but needs a crisp ranged attack release.
- Hunter: `hunt_attack` with brighter/longer ranged release.
- Apex: `consume_ally`, `heal_pulse`.
- Champion: `consume_ally`, `wounded_frenzy`.
- Spawner: `root_cast`, `rooted_idle`, `artillery_attack`, `uproot_cast`, `summon_drone`, `evolve_wings`.
- Winged Spawner: `takeoff`, `landing`, `move_flying`, `artillery_attack`, `summon_drone`.
- Bad Kon Willow: `attack_dual_cast`, `bio_mend`, `seal_away`, `observer_aura`.

## Unit-Specific Briefs

### Terrible Thing

Small swarm body, dark green flesh, pulsing red weak points, desperate forward posture. It should look disposable and dangerous in groups. Generate 3 body variants for swarm variety.

### Gripper

Evolved Terrible Thing with heavier forelimbs and a grappling silhouette. Defensive, hunched, more plated. It should read as a root/control unit, not just a bigger Terrible Thing.

### Horror

Fast ranged skirmisher. Thin, angular, quick-looking silhouette. Cyan/silver observer traces can appear in the projectile, but the body remains evolution-themed dark green/red.

### Hunter

Sharper evolved Horror. Add a distinct aiming organ or spine that communicates the Hunt burst attack. Hunt attack needs a noticeably longer muzzle/beam windup.

### Apex

Medium-large support predator. It should read as a healer and predator: strong forebody, exposed red biomass, cyan healing motes for Consume Ally.

### Champion

Evolved Apex. Heavy melee front-liner. Add visible armor growths and a low-health frenzy animation hook.

### Spawner

Slow heavy organism. It must clearly root into the ground before firing. The artillery attack needs a readable charge, launch, and recoil.

### Winged Spawner

Airborne evolved Spawner. Keep the same core creature identity, but add wings/float organs. It must have takeoff and landing sheets, even though they are short.

### Bad Kon Willow

Hero wizard with broken staff in two casting channels. Observer abilities use cyan/silver; evolution abilities use dark green/red. His standard attack must show two releases.

## Current Engine Profiles

The active unit framework reads each unit's `animation_profile` from `scripts/core/unit_catalog.gd`. Keep generated actions aligned with those profile names first; extra variations can be added after the baseline set is complete.
