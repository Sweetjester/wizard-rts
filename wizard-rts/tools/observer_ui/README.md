# Observer interface implementation

Implemented 2026-09-06. These are working Godot controls, not flattened UI mockups.

Current concept-faithful art and family records: see [Concept V3](CONCEPT_V3.md).
Previous tier-hand layout: see [Drawn V2](DRAWN_V2.md). The original
ornate raster assets below are retained as provenance, not used by the new UI.

## Experience

- The main menu opens against a painted gothic library. Existing character,
  map, audio, display, editor and new-game routes are preserved. New-game
  submission is guarded against double activation.
- Select one completed, living, player-owned Observer Vault to open its archive.
  The contextual Open the Vault action reopens it after dismissal.
- Creations, Felled and Research are separate shelves. Search filters visible
  record names, never secret names. Cards open a reading view. Escape returns
  to the shelf, then closes the archive. Close always dismisses it.
- The expedition continues while reading. This is not a pause menu. Mouse input,
  army hotkeys and camera panning/zoom do not pass through the archive.
- Losing the Vault closes the archive. Closing or removing the overlay releases
  its viewport input-ownership marker.
- Kon's normal battlefield HUD retains resources, immediate commands and
  feedback, but removes the detailed stat readout and generic roster browser.
  The command dock is smaller and disappears when nothing is selected.
  The AI testing ground retains its full debug statistics browser.

## Revelation rules

`vault_records.gd` is the presentation boundary. Sealed dictionaries contain
only an internal key, tier, generic title and requirement. Portrait paths,
stats, descriptions and future evolution names do not reach the sealed card.
Tier II/III reference real research. Tier IV references the tower's Unleash
route. Tiers II and III stay sealed until researched, even for granted units.
A living Tier IV specimen may be inspected after the tower's evolution route.

Enemy cards are absent until a player-owned source kills that archetype.
`RTSUnit._die()` records the confirmed death after its duplicate-death guard.
It does not rely on the old, declared-but-unemitted CombatSystem signal.
Friendly deaths, other-owner kills, unknown sources and ordinary despawning
do not award discoveries. GameSession keeps archetype kill counts for the
current expedition. Scene reloads retain them; start_new_game/use_default_game
clear them. This is not cross-session save-game persistence.

Felled cards explicitly report an archetype baseline, not an invented copy of
the enemy's most recent transient modifiers. A delayed damage source that has
already been freed cannot currently receive kill credit; the combat system's
weak source references do not retain an owner identifier. Do not silently count
environmental deaths to work around that limitation.

## Statistics contract

Use RosterLedger for the projected run template and named research effects.
It now includes physical/magic armour, fractional cell reach, cooldown fallback,
and the existing UnitCatalog first-evolution multipliers.

The gallery reads living RTSUnit instances through weak references. Attack,
maximum health and armour are actual field values when specimens exist. If
those specimens differ, the medallion shows a min-max range rather than a fake
average. With no specimen in the field, it shows the derived run template.

The reading view lets the player choose the run template or a particular living
specimen. Live cooldown and movement measurements use the unit's current getter
methods. Changes from base are signed and coloured. Existing named research is
listed separately; other live differences are honestly described as individual
evolution/active stat changes, without inventing a source label.

The existing ledger still mirrors several BuildSystem research formulas. When
adding new run-wide effects, update that projection and its comparison test,
or replace both with one shared pure stat resolver. Do not instantiate hidden
units just to calculate UI stats: readiness registers units into the world.
Instance measurements alone cannot predict future units that do not yet exist.

## Code map

- scripts/ui/observer_menu_skin.gd: main-menu visual styling and size adaptation.
- scripts/ui/observer_theme.gd: shared colours, control theme, display font.
- scripts/ui/observer_vault.gd: gallery, reading page, research, modal lifetime.
- scripts/ui/vault_drawn_card.gd: current drawn card rendering and hand animation.
- scripts/ui/vault_fog.gdshader: gentle moving mist across sealed tier hands.
- scripts/ui/vault_card.gd: legacy ornate renderer, no longer instantiated.
- scripts/ui/vault_records.gd: sealed/revealed records and living measurements.
- scripts/ui/roster_ledger.gd: original run-stat ledger, extended in place.
- scripts/ui/rts_hud.gd: real Vault selection integration and quieter HUD.
- scripts/core/game_session.gd: run-scoped discovery counts.
- scripts/units/rts_unit.gd: confirmed-death discovery hook.
- CameraController and Map3DView: small archive-input guards only. No navigation,
  structure generation, terrain, unit balance or loading-screen redesign.

## Original art and layout (superseded by Drawn V2)

Three original raster assets were generated with the built-in image tool, then
copied into assets/ui/observer_vault. Source originals remain under Codex's
generated_images directory. No external API key or paid CLI was used.

1. library_menu.png: source exec-95109a16-38bf-4a53-9ee9-26d8391fafd2.png.
   Prompt direction: landscape gothic observation library; circular open vault,
   books, cyan oculus, red vines, brass astrolabe; quiet dark left third for live
   menu typography; hand-painted stone/wood with ink contours; no baked text.
2. card_frame.png: source exec-1120c38d-54d3-427c-b46b-2737a797bb04.png.
   Prompt direction: straight-on carved stone/black iron collectible-card frame,
   red thorns, cyan eye seal, empty portrait aperture, blank nameplate and three
   recessed stat medallions; all lettering/numbers supplied by Godot.
3. sealed_folio.png: source exec-35806d9c-780a-472f-a951-e36563127cdb.png.
   Prompt direction: closed oxblood leather folio, burgundy ribbons, red wax eye
   seal, brass clasps, subtle cyan light through cracks; no creature or lettering.

Existing catalog portraits are reused rather than replacing unit assets.
Transparent padding is removed at draw time using cached alpha bounds; source
images are not rewritten. Missing portraits use an intentional archive sigil.
Cards stay 264x410 layout units and the grid reflows with available width.
The detail page stacks on narrow windows and scrolls independently of its header.
Display typography uses platform serif fonts with fallback; no licensed system
font binaries are redistributed. The normal control font remains Godot's.

## Verification

Run from the project root with the game's Godot executable:

```text
godot --headless --path . --editor --quit
godot --headless --path . --script tools/observer_ui/verify.gd
godot --headless --path . --script tools/observer_ui/verify_ingame.gd
godot --headless --path . --script tools/observer_ui/verify_menu_start.gd
godot --headless --path . --script scripts/core/roster_ledger_smoke_test.gd
godot --headless --path . --script scripts/core/audio_menu_smoke_test.gd
godot --headless --path . --script scripts/core/display_menu_smoke_test.gd
```

For real rendered captures set ART_SHOT_DIR to an existing absolute output
directory and run verify.gd without --headless (Compatibility renderer is fine).
It captures the menu, character/maps/settings, sealed/unsealed/felled shelves,
research and detail views, plus a 1024x720 gallery. Require explicit
`[ObserverUI] failures=0` and `[ObserverIntegration] failures=0`; an exit code
alone does not prove GDScript assertions or deferred callbacks succeeded.

The integration test creates a real Vault in the map, exercises selection,
research and Escape through the viewport, and checks that pause was not opened
and the camera input marker was cleared. The record test exercises a real
damage/death path and differing living buffs/nerfs. Existing certificate-store
and renderer shutdown resource warnings occur in this environment separately
from these functional checks. Full unrelated game suite was not run.
