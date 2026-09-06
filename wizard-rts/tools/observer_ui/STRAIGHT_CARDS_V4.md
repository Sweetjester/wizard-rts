# Observer Vault: Straight Cards V4

## Current Direction

Supersedes the fanned/angled gallery in DRAWN_V2.md. Keep tier browsing, but use
upright, non-overlapping printed cards. The user's reference is the craft and
readability of drawn Yu-Gi-Oh cards, not copied branding or photographic art.

Kon's existing concept-correct portraits remain in use. Steel Force now has
four dedicated card illustrations, not enlarged runtime sprites:

| Atlas cell (row-major) | Unit | Identity |
| --- | --- | --- |
| 0 | Poorper | Round cloth head, golden eyes, ochre scarf, improvised spear |
| 1 | Steel Knight | Closed golden slit visor, heavy plate, sword and shield |
| 2 | Proper Blimp | Silver balloon, wooden gondola, three Poorper crew |
| 3 | Mounted Knight | Armoured bull, horned rider, banner, kindled poleaxe |

Asset: `assets/ui/observer_vault/steel_portraits_drawn_v4.png`.
Native resolution is 1254 x 1254, with four 627 x 627 cells. This is not a 4K
asset. It is displayed at 244 x 244 per portrait. Generation prompt, references,
source image and cell mapping are preserved in `steel_cards_v4_generation.json`.
Import uses lossless compression, no size limit, and explicit linear UI filtering.
Do not use the character animation atlases for these portraits.

## Runtime Contract

- `vault_drawn_card.gd`: fixed 280 x 440 cards; square portrait; live text and
  statistics drawn in Godot. Steel stock is muted gold; Kon stock is sage.
- Rectangular frame insets are integer-aligned and contained within the card.
  Hover/focus changes the edge colour, not position, scale or rotation.
- `observer_vault.gd`: centred rows with 24 px gaps. Cards wrap as available
  width changes. Scroll extent includes every row. The mouse wheel scrolls;
  it does not change tier. Arrow/tier buttons and horizontal touch swipes retain
  tier browsing. Keyboard focus follows the visible scroll area.
- Legacy `hand` and `arrange` names remain for compatibility with existing tests;
  they no longer imply fan transforms. `Card.CARD_SIZE` is the size authority.
- Existing source art is fitted without aspect distortion.
- Names, tiers, stats and frames are never baked into generated art.
- Gallery stats keep ranges across living specimens. The detail card explicitly
  switches to the chosen living specimen or run template, matching its adjacent
  measurements. Buffs and nerfs must not be replaced by catalog defaults.
- Creation evolutions and summoned drones remain inside their family detail,
  not additional creation-gallery cards.

## Revelation And Research

`vault_records.gd` is responsible for withholding data, not just hiding controls.
Unseen enemy Steel units do not appear in Creations or Felled. Once felled, their
Felled record is available; their Creation record stays sealed until its Steel
Conscription rank is unlocked. Sealed records contain no portrait, real name,
description or statistics, and show the appropriate research requirement.

Steel Conscription is independent of hybrid tiers, matching BuildSystem's
existing recruitment rule. A usable Steel recruit must not be hidden beneath
whole-tier hybrid fog. Locked Kon cards remain individually sealed in such a
mixed tier. A fully locked tier retains its fog and research action.

Do not change production, costs, damage, conscription ordering, timed research,
Vault worker bonuses or the unit roster to implement a visual card change.

## Verification

Run from the Godot project root with the Godot executable and isolated test user
data. Set ART_SHOT_DIR to an existing output folder for graphical captures.

```text
--path . --script tools/observer_ui/verify_straight_cards.gd
--path . --headless --script tools/observer_ui/verify.gd
--path . --script tools/observer_ui/verify_ingame.gd
```

For the last test, set OBSERVER_TEST_3D=1. It selects a real placed Vault in the
3D game, exercises real research and input ownership, and captures the mixed
Tier II gallery. Test-only research/discoveries are confined to that test run.

The V4 verifier covers all Steel portrait mappings, unseen/seen/recruited states,
independent research gates, Kon evolutions/summons, selected-unit buffs/nerfs,
zero rotation, integer positions, non-overlapping bounds, contained text,
scrolling without tier changes, and layout at 1440, 1024 and 640 px widths.

Verified on 2026-09-06: all three suites report failures=0. Graphical screenshots
were inspected for full desktop, narrow layout, lower rows, sealed cards, and
Steel detail. Existing Windows certificate, Forward+ shader-cache and integration
shutdown resource warnings remain; they are not claimed fixed by this work.
