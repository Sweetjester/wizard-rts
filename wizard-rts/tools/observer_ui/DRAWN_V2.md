# Observer Vault: drawn art and tier hands

## Direction

Read STYLE_BIBLE.md before making more art. Broad forms come before surface
detail. This revision replaces the ornate illustrated-metal UI with quiet,
ink-outlined fantasy trading cards. The supplied Dark Magician reference guides
clear silhouette, strong pose and restrained shading, not its character or logo.
Use blue-gray bodies, charcoal ink, burgundy accents and small cyan focal lights.
Keep generous quiet areas. Do not add photorealistic materials, intricate filigree,
micro-cracks or bloom that obscures the subject.

## Generated source assets

Generated using the built-in image-generation tool and copied without repainting:

| Runtime asset in assets/ui/observer_vault | Original generated source |
| --- | --- |
| library_drawn_v2.png | exec-0ef81200-5530-475d-ba2f-4541e29d2f36.png |
| portraits_drawn_v2.png | exec-84b37b8f-b7b9-496a-94b0-64a2fd2bb7f1.png |
| variants_drawn_v2.png | exec-6247d502-0f48-429f-9c3d-2c44ce66f539.png |

Originals live in the generating user's .codex/generated_images task directory.
Runtime files are committed/project assets and do not depend on that directory.

Prompt brief for the background: a compact drawn wizard library, chunky stone,
simple round vault doorway on the right, books and candle, sparse red growth,
cyan window. Quiet left side for live menu text; no baked labels or UI.

Prompt brief for portraits: consistent hand-inked, cel-painted collectible-card
illustrations; broad silhouettes and restrained shadow planes; muted sage/ochre
circle backgrounds; clear complete subject; no text, borders or photorealism.
The first sheet is exactly three columns by two rows: Kon, Oaven, Mangler;
Stone-Faced Serpent, Spawner, Winged Mangler. The second is three columns by one
row: leaping Oaven Jumper, flying Winged Spawner, small slender Spawner Drone.
Variant silhouettes must visibly differ, not merely reuse the base creature.

These are UI portrait overrides only. Unit sprites, animations, combat, balance,
structure geometry and navigation are unchanged. Enemy records use their existing
catalog portraits until a separate faction-specific drawn art pass is approved.

## Runtime composition

vault_drawn_card.gd draws a fixed 280x410 card with ink borders and pale sage
stock. Portraits sample atlas regions at draw time. All names, tiers, descriptions
and stats are live Godot text, never baked into the image. Long descriptions are
shortened on the card; the complete description remains on its reading page.
Current ATK, HP and ARM occupy the bottom strip. Existing live-stat and research
projection rules remain in vault_records.gd and RosterLedger.

observer_vault.gd presents one tier at a time. Buttons, arrow keys, wheel over the
hand, and horizontal touch swipes switch tiers. Cards are dealt in with a brief
fade and lift, fan by five degrees per offset, and lift/straighten on hover or
keyboard focus. Activating a card opens its reading page. Escape goes back, then
closes the archive. Search is scoped to the active tier.

Tier II and III cards contain no secret portraits, names or stats until their
actual research succeeds. The fog shader is decoration over safe card backs,
not the security boundary. The central seal states the research requirement and
opens Research. Research uses the real economy and existing upgrade functions.
Tier IV follows the existing tower route. Enemy records remain entirely absent
until a qualifying kill; merely seeing an enemy does not reveal its card.

## Verification and maintenance

Run the commands in README.md. verify.gd covers sealed data, tier switching,
research unlocking, card hover and opening, differing live stats, enemy discovery,
menu routes, and rendered 1024x720/desktop layouts. Inspect captures as well as
the explicit failure count. verify_ingame.gd exercises actual Vault selection,
research and input ownership on the playable map; run with OBSERVER_TEST_3D=1
to exercise the 3D map path too.

Check full card boundaries and stat strips at the smallest supported window.
Check that resized/deferred layouts restore card opacity when interrupting an
entrance tween. Never reveal hidden art underneath fog, in a tooltip or search.
Do not regenerate card fonts or values into images. Preserve the original art
files rather than overwriting unrelated gameplay assets.
