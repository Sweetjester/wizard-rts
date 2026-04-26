#!/usr/bin/env python3
"""Create the Kon 1.0 PixelLab manifest.

This is intentionally generated from compact data so we can scale the library
without hand-maintaining a huge JSON document.
"""

from __future__ import annotations

import json
from pathlib import Path


OUT = Path("tools/pixellab_kon_1_0_manifest.json")

STYLE = {
    "base_prompt": (
        "production-ready isometric pixel art for a rogue-like multiplayer RTS, "
        "matte finish, clean readable silhouette at StarCraft 2 camera distance, "
        "transparent background where appropriate, no UI, no text, no watermark. "
        "Kon faction has two linked themes: Observer theme is cyan glow, silver, "
        "glass, bone-white glyphs and controlled observation equipment; Evolution "
        "theme is dark moss green biomass, wet bark, roots, pulsing blood-red sacs, "
        "vampire mushroom growths. Keep consistent camera angle and footprint for "
        "sprite sheets and RTS buildings."
    ),
    "negative_prompt": (
        "photorealistic, blurry, painterly smear, text, logo, watermark, messy crop, "
        "cut off silhouette, inconsistent camera angle, plastic shine, modern guns, "
        "large UI panels, random sci-fi metal unless specifically described"
    ),
}


def asset(asset_id: str, description: str, **kwargs: object) -> dict[str, object]:
    data: dict[str, object] = {"id": asset_id, "description": description}
    data.update(kwargs)
    return data


def manifest() -> dict[str, object]:
    return {
        "project": "wizard-rts-kon-1-0",
        "style": STYLE,
        "output_root": "assets/generated/pixellab/kon_1_0",
        "batches": [
            character_batch(),
            building_batch(),
            building_level_batch(),
            unit_sheet_batch(),
            combat_fx_batch(),
            spell_fx_batch(),
            projectile_batch(),
            emote_batch(),
            icon_batch(),
        ],
    }


def character_batch() -> dict[str, object]:
    return {
        "id": "01_character_8dir_master_models",
        "type": "character_8dir",
        "enabled": False,
        "size": 96,
        "view": "low top-down",
        "isometric": True,
        "outline": "thin readable dark outline",
        "shading": "soft matte pixel shading",
        "detail": "high",
        "animations": [
            {"name": "idle", "template_animation_id": "breathing-idle", "frame_count": 8},
            {"name": "walk", "template_animation_id": "crouched-walking", "frame_count": 8},
            {"name": "melee_attack", "action_description": "forceful melee attack with claws, staff, roots, or body lunge", "frame_count": 8},
            {"name": "ranged_attack", "action_description": "ranged spore or broken staff attack with clear recoil and muzzle/spore flash", "frame_count": 8},
            {"name": "cast", "action_description": "spell cast animation, readable windup and release, observer cyan or evolution red green depending on unit", "frame_count": 8},
            {"name": "evolve", "action_description": "unit mutates and hardens with pulsing biomass, red sacs, cyan sparks", "frame_count": 8},
            {"name": "death", "action_description": "collapse into roots, spores, and dissolving biomass", "frame_count": 8},
        ],
        "assets": [
            asset("bad_kon_willow_observer", "Bad Kon Willow, miserable hooded life wizard, broken staff split into two casting foci, cyan glowing eyes and hand, observer cult robes, silver glyph tags, small red mushrooms growing through cloak", variants=6),
            asset("terrible_thing_base", "Terrible Thing base form, cheap hunched biomass unit, mixed melee claws and short ranged spit sac, roots, bone hooks, vampire mushroom caps, readable as basic swarm unit", variants=8),
            asset("terrible_thing_tank_evolved", "Terrible Thing evolved frontline tank dedication, armored bark plates, swollen red sacs, broad stance, shield-like fungal growths, still recognizably evolved from base form", variants=6),
            asset("terrible_thing_ranged_evolved", "Terrible Thing evolved backline ranged dedication, long spore barrel organ, thinner legs, cyan spore vents, roots stabilizing like a living tripod", variants=6),
            asset("horror_fast_ranged", "Horror, fast ranged vampire mushroom predator, lean sinewy root legs, spore launcher organ, cyan vents, red fungal eyes, speed-focused silhouette", variants=8),
            asset("apex_healer_form", "Apex healer form, medium-large support horror, maw and tendrils that consume allied biomass, bone crown, healing sacs, ominous but not fully monstrous yet", variants=8),
            asset("apex_predator_evolved", "Apex evolved predator form, very powerful melee monster, massive tendril maw, bone crown, dark green hide, pulsing red evolution sacs, elite readable silhouette", variants=6),
        ],
    }


def building_batch() -> dict[str, object]:
    buildings = [
        ("observation_tower_hq", 192, 224, "The Observation Tower HQ, large observer cult tower with glass dome roof, cyan telescope lenses, silver/bone supports, Kon can garrison inside to observe and build his base, 4x4 RTS footprint"),
        ("bio_absorber_sentient_drill", 160, 160, "Bio Absorber economy building, large sentient organic drill tunneling into the ground, dark green biomass, pulsing red sacs, cyan healing vents, 2x2 footprint"),
        ("barracks_overrun_lab", 192, 160, "Barracks, a horrible living lab of biomass where observer architecture is overrun by evolution, broken glass, silver lab frame, red roots and growth sacs, 3x3 footprint"),
        ("terrible_vault_armory", 176, 160, "Terrible Vault armory, sealed observer research vault for upgrading units, cyan containment cracks, silver glyph locks, dark vines forcing it open, 3x3 footprint"),
        ("vinewall_segment", 96, 128, "Vinewall single grid segment, regenerating retaliating thorn wall, starts wounded at half health, dark bark, red sacs, teeth-like thorns, 1x1 footprint"),
        ("bio_launcher_rooted", 160, 160, "Bio Launcher rooted long range defense, static organic artillery plant, bone barrel, red sacs, green roots anchored into ground, clear attack direction, 2x2 footprint"),
        ("bio_launcher_uprooted", 160, 160, "Bio Launcher uprooted mobile mode, same living artillery walking on roots with barrel lowered, readable moveable defense, 2x2 footprint"),
    ]
    return {
        "id": "02_building_static_variants",
        "type": "map_object",
        "enabled": False,
        "view": "low top-down",
        "outline": "single color outline",
        "shading": "medium shading",
        "detail": "high detail",
        "no_background": True,
        "assets": [asset(name, desc, width=w, height=h, variants=10) for name, w, h, desc in buildings],
    }


def building_level_batch() -> dict[str, object]:
    entries = []
    for name, base in [
        ("observation_tower", "observer tower HQ glass dome cyan/silver"),
        ("bio_absorber", "sentient biomass drill economy building"),
        ("barracks", "observer lab overrun by evolution biomass"),
        ("terrible_vault", "sealed observer vault and armory"),
        ("vinewall", "regenerating retaliating thorn vine wall"),
        ("bio_launcher", "rooted organic artillery defense"),
    ]:
        for level in range(1, 5):
            entries.append(asset(
                f"{name}_level_{level}",
                f"{base}, evolution level {level}, same footprint and camera angle, show clear upgrade progression without changing unit identity",
                width=512,
                height=160,
                variants=4,
            ))
    return {
        "id": "03_building_level_and_idle_sheets",
        "type": "image",
        "enabled": False,
        "endpoint": "generate-image-v2",
        "no_background": True,
        "assets": entries,
    }


def unit_sheet_batch() -> dict[str, object]:
    units = [
        "bad_kon_willow",
        "terrible_thing_base",
        "terrible_thing_tank_evolved",
        "terrible_thing_ranged_evolved",
        "horror_fast_ranged",
        "apex_healer_form",
        "apex_predator_evolved",
    ]
    actions = [
        ("idle_8dir_sheet", "one idle frame per direction, 8 directions, evenly spaced"),
        ("walk_8dir_sheet", "8 direction walk animation strip, readable foot/root motion"),
        ("melee_attack_8dir_sheet", "8 direction melee attack animation strip, strong anticipation and impact"),
        ("ranged_attack_8dir_sheet", "8 direction ranged attack animation strip, spore/staff recoil and launch flash"),
        ("death_sheet", "death animation strip, collapse into spores and roots"),
        ("evolution_sheet", "evolution transformation strip, biomass hardens and grows"),
    ]
    entries = []
    for unit in units:
        for action_id, desc in actions:
            entries.append(asset(
                f"{unit}_{action_id}",
                f"{unit.replace('_', ' ')} {desc}, transparent background, animation-ready sprite sheet, consistent cell size, no text",
                width=768,
                height=128,
                variants=4,
            ))
    return {
        "id": "04_unit_animation_sheet_variants",
        "type": "image",
        "enabled": True,
        "endpoint": "generate-image-v2",
        "no_background": True,
        "assets": entries,
    }


def combat_fx_batch() -> dict[str, object]:
    fx = [
        ("terrible_thing_claw_slash", "bone-white and red fungal melee slash, root tendril arc"),
        ("terrible_thing_spit_attack", "small dark green biomass spit with pulsing red core"),
        ("horror_spore_burst", "fast cyan spore burst with red fungal fragments"),
        ("horror_speed_evolution_trail", "speed evolution afterimage trail, cyan vents and red spores"),
        ("apex_eat_ally", "Apex consuming allied unit, biomass spiral pulled into tendril maw"),
        ("apex_heal_pulse", "Apex healing pulse, dark green ring and cyan spores"),
        ("apex_predator_maw_strike", "massive melee maw strike with red tendrils and bone shards"),
        ("bio_launcher_impact_aoe", "large biomass artillery impact, red sacs bursting, cyan sparks"),
        ("vinewall_retaliate_lash", "thorn vinewall retaliating lash, red thorns and green motion arc"),
        ("evolution_level_up", "unit evolution level up burst, dark green roots and pulsing red sacs"),
    ]
    return {
        "id": "05_combat_fx_animation_sheets",
        "type": "image",
        "enabled": True,
        "endpoint": "generate-image-v2",
        "no_background": True,
        "assets": [
            asset(name, f"horizontal 8 frame sprite sheet of {desc}, transparent background, evenly spaced frames", width=512, height=96, variants=6)
            for name, desc in fx
        ],
    }


def spell_fx_batch() -> dict[str, object]:
    spells = [
        ("bio_mend_select_cursor", "Bio Mend targeting cursor, evolution theme, green/red biomass healing symbol"),
        ("bio_mend_cast_sheet", "Bio Mend cast animation, evolution theme, green spores and pulsing red organic warmth"),
        ("bio_mend_impact_sheet", "Bio Mend impact on unit/building, roots knit wounds, soft cyan-green spores"),
        ("seal_away_select_cursor", "Seal Away targeting cursor, observer theme, cyan silver containment reticle"),
        ("seal_away_cast_sheet", "Seal Away cast animation, observer theme, cyan glyphs and silver locking rings"),
        ("seal_away_enemy_stun_sheet", "Seal Away enemy stun, cyan glass prison/glyph cage closes around target"),
        ("seal_away_salvage_sheet", "Seal Away allied salvage, biomass converts back into resource particles inside observer glyph circle"),
        ("kon_dual_auto_attack_sheet", "Kon dual auto attack, broken staff halves fire two linked cyan bolts with dark red evolution sparks"),
    ]
    return {
        "id": "06_kon_spell_fx_library",
        "type": "image",
        "enabled": True,
        "endpoint": "generate-image-v2",
        "no_background": True,
        "assets": [
            asset(name, f"horizontal 8 frame sprite sheet of {desc}, transparent background, no text", width=512, height=96, variants=8)
            for name, desc in spells
        ],
    }


def projectile_batch() -> dict[str, object]:
    projectiles = [
        ("kon_dual_staff_bolt", "two linked cyan observer bolts from broken staff with faint silver glyph trail"),
        ("terrible_thing_biomass_spit", "small dark green biomass glob with red pulsing core"),
        ("horror_spore_projectile", "fast cyan spore projectile, thin comet trail, red fungal seed center"),
        ("apex_heal_projectile", "soft cyan-green healing mote with root spiral"),
        ("bio_launcher_artillery_glob", "large arcing dark biomass artillery glob, red sacs and cyan sparks"),
        ("seal_away_glyph_projectile", "observer cyan silver glyph shard traveling to target"),
    ]
    return {
        "id": "07_projectile_variants",
        "type": "image",
        "enabled": True,
        "endpoint": "generate-image-v2",
        "no_background": True,
        "assets": [
            asset(name, f"single RTS projectile sprite, {desc}, transparent background, readable at 32 to 96 px", width=96, height=96, variants=10)
            for name, desc in projectiles
        ],
    }


def emote_batch() -> dict[str, object]:
    emotes = [
        ("kon_acknowledge", "Kon acknowledging command with miserable contempt"),
        ("kon_annoyed", "Kon annoyed and judging the player"),
        ("kon_unleash_horrors", "Kon gleefully unleashing evolution horrors"),
        ("kon_observing", "Kon quietly observing through cyan lens"),
        ("kon_injured", "Kon wounded but unsympathetic"),
        ("kon_victory", "Kon after defeating the boss, cold triumph"),
        ("kon_defeat", "Kon realizing the seal failed"),
        ("kon_research_complete", "Kon pleased by terrible vault research"),
    ]
    return {
        "id": "08_kon_portraits_and_emotes",
        "type": "image",
        "enabled": True,
        "endpoint": "generate-image-v2",
        "no_background": True,
        "assets": [
            asset(name, f"character portrait/emote bust for UI, {desc}, hood, cyan eyes, red mushrooms, clean cropped readable face", width=256, height=256, variants=8)
            for name, desc in emotes
        ],
    }


def icon_batch() -> dict[str, object]:
    icons = [
        ("icon_bio_resource", "Bio resource icon, red green biomass drop"),
        ("icon_evolution_xp", "Evolution experience icon, red sac growing roots"),
        ("icon_observer_theme", "Observer tech icon, cyan glass lens silver frame"),
        ("icon_bio_mend", "Bio Mend ability icon, green healing spores"),
        ("icon_seal_away", "Seal Away ability icon, cyan silver glyph prison"),
        ("icon_heal_aura_upgrade", "Bio Absorber heal aura upgrade icon"),
        ("icon_bio_launcher_upgrade", "Bio Absorber bio launcher upgrade icon"),
        ("icon_thorned_vines", "Vinewall upgrade icon, thorns and red sacs"),
        ("icon_accelerated_evolution", "Accelerated evolution upgrade icon"),
        ("icon_hardened_horrors", "Hardened horror armor upgrade icon"),
        ("icon_launcher_bile", "Bio launcher bile upgrade icon"),
        ("icon_attack_ground", "Bio launcher attack ground command icon"),
    ]
    return {
        "id": "09_ui_icons",
        "type": "image",
        "enabled": True,
        "endpoint": "generate-image-v2",
        "no_background": True,
        "assets": [
            asset(name, f"64x64 RTS command icon, {desc}, Kon faction palette, high contrast, no text", width=64, height=64, variants=8)
            for name, desc in icons
        ],
    }


def main() -> int:
    OUT.write_text(json.dumps(manifest(), indent=2), encoding="utf-8")
    print(OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
