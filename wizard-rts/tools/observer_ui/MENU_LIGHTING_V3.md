# Observer Menu and Lighting Pass

## Direction

Follow `STYLE_BIBLE.md`: drawn shapes, painted materials, readable silhouettes,
warm light against cool ambient fill, and restrained magic accents. The menu
reuses `assets/ui/observer_vault/library_drawn_v2.png`. No new generated bitmap
is claimed in this pass. Preserve its quiet left wall for navigation and its
round window, candle and vault door as the illustration's focal points.

`library_backdrop.gd` and `library_light.gdshader` add gentle cyan window light,
warm candle variation and a faint diagonal light shaft. Relighting affects the
painting, not interface text. Hidden backgrounds stop updating. Avoid covering
this illustration with particle fog, floating blobs or dense ornament.

## Interface

- Main menu: serif title, left-aligned commands and generous negative space.
- Wizard selection: complete portraits rather than cropped heads; long lore
  scrolls within each existing character card.
- Map selection: compact map rows; clicking a map still launches it immediately.
  The redundant disabled Start Run control remains in code but is hidden.
- Pause: themed Audio, Display, Key Binds and Expedition tabs, with one clear
  return command. Restart and quit actions require confirmation.
- Escape during key rebinding cancels rebinding without dismissing pause.
- HUD: shared typography/materials, wrapping resource/tool rows, a Menu command,
  and no permanent keyboard-shortcut instruction line. Existing minimal-HUD
  rules and context-dependent command visibility remain in place.
- Vault: shared illustrated relighting; existing tier, discovery, family and
  research behaviour is retained. This pass does not redesign its card logic.

The common visual tokens live in `scripts/ui/observer_theme.gd`. Use those
tokens rather than introducing a second palette for another submenu.

## 3D Default and Lighting

Both `GameSession.render_3d` and the default argument of `start_new_game` are
true. The menu's 3D world checkbox starts checked. Explicit false still starts
2D; this is a presentation default, not a change to simulation generation.

`scripts/map/observer_lighting.gd` owns the new in-game accent light and effect
settings. The world has a warm directional key, brighter cool ambient fill,
lighter atmospheric fog, and restrained bloom. One small unshadowed light
follows the local living, revealed hero: cyan for Kon, warm for the others.
It is hidden for a dead or banished hero and never tracks an unseen enemy.
Fog-of-war rules are unchanged. This is not a full terrain/material overhaul.

Atmospheric lighting is persisted by DisplayManager and exposed in both
Display menus. Turning it off stops illustrated relighting, bloom and the
hero accent light. Performance mode also disables these effects and sun
shadows. Keep ordinary scene illumination available in either mode.

## Terrain Bootstrap Fixes

The embedded renderer's terrain originally used a zero-centred coordinate
system while live units, structures and picking used a positive cell origin.
Only the embedded visual root is translated by half the map dimensions;
standalone preview coordinates and simulation positions are unchanged.

Two startup render requests could also resume after map generation and leave
overlapping terrain. `render_live_map` now rejects superseded waiting requests
and retires old geometry after the wait. Do not move that cleanup back ahead
of the await without preserving the single-root guarantee.

## Verification

Run from the Godot project directory with a writable Godot user-data folder:

```powershell
godot --path . --script tools/observer_ui/verify_menu_overhaul.gd
godot --headless --path . --script scripts/core/display_menu_smoke_test.gd
godot --headless --path . --script scripts/core/audio_menu_smoke_test.gd
$env:OBSERVER_TEST_3D='1'
godot --path . --script tools/observer_ui/verify_ingame.gd
```

Set `ART_SHOT_DIR` to an existing output directory to retain screenshots.
The overhaul test renders 1920x1080 and 1280x720 menus, launches an actual 3D
game, checks shared terrain/unit coordinates, checks a single terrain tree,
opens the vault, exercises all pause tabs, cancels a key rebind, resumes, and
checks the performance fallback. It verifies explicit 2D remains available.
Its image checks reject blank output; also inspect screenshots for clipping,
text overlap and artwork framing. A nonblank test is not visual approval.

The vault regression now waits through the existing timed-research path,
instead of assuming research unlocks instantly. Production research rules
were not changed for the test.

Validated on Godot 4.6.2 / Forward+ on Windows at 720p and 1080p. Audio,
display and in-game vault smoke checks passed. The test environment reports
shader-cache/certificate-store warnings and existing shutdown resource-leak
messages; do not describe these runs as warning-free. Performance mode is
functionally checked, not a hardware performance benchmark.

## Scope Guardrails

Do not change unit balance, research costs, faction progression, map logic,
or navigation to make a menu screenshot work. Screenshots may use isolated
test fixtures, but gameplay changes need their own request and tests.
Keep concurrent unrelated unit, building and faction edits intact.
