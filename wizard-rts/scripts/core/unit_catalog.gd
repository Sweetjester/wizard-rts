class_name UnitCatalog
extends RefCounted

const DEFINITIONS := {
	&"life_wizard": {
		"display_name": "Bad Kon Willow",
		"max_hp": 220,
		"move_speed_cells": 1,
		"attack_damage": 13,
		"attack_range_cells": 4,
		"attack_cooldown_ticks": 17,
		"projectile_speed": 680.0,
		"dual_cast": true,
		"sight_radius_cells": 9,
		"population": 1,
	},
	&"fire_wizard": {
		"display_name": "Fire Wizard",
		"max_hp": 165,
		"move_speed_cells": 1,
		"attack_damage": 24,
		"attack_range_cells": 5,
		"attack_cooldown_ticks": 18,
		"projectile_speed": 780.0,
		"sight_radius_cells": 9,
		"population": 1,
	},
	&"life_treant": {
		"display_name": "Treant",
		"max_hp": 95,
		"move_speed_cells": 1,
		"attack_damage": 9,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 20,
		"sight_radius_cells": 6,
		"population": 1,
	},
	&"terrible_thing": {
		"display_name": "Terrible Thing",
		"max_hp": 78,
		"move_speed_cells": 1,
		"attack_damage": 9,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 19,
		"sight_radius_cells": 6,
		"population": 1,
		"cost_bio": 45,
		"train_time_seconds": 5.0,
		"evolves_to": &"awful_thing",
		"evolution_xp_required": 90,
	},
	&"awful_thing": {
		"display_name": "Awful Thing",
		"max_hp": 120,
		"move_speed_cells": 1,
		"attack_damage": 15,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 16,
		"sight_radius_cells": 6,
		"population": 1,
		"cost_bio": 0,
	},
	&"horror": {
		"display_name": "Horror",
		"max_hp": 52,
		"move_speed_cells": 1,
		"attack_damage": 10,
		"attack_range_cells": 4,
		"attack_cooldown_ticks": 20,
		"projectile_speed": 720.0,
		"sight_radius_cells": 8,
		"population": 1,
		"cost_bio": 70,
		"train_time_seconds": 7.0,
		"evolution_xp_required": 80,
		"evolution_speed_bonus": 22,
	},
	&"apex": {
		"display_name": "Apex",
		"max_hp": 110,
		"move_speed_cells": 1,
		"attack_damage": 7,
		"attack_range_cells": 3,
		"attack_cooldown_ticks": 22,
		"projectile_speed": 620.0,
		"sight_radius_cells": 8,
		"population": 2,
		"cost_bio": 120,
		"train_time_seconds": 10.0,
		"heal_per_attack": 8,
		"evolves_to": &"apex_predator",
		"evolution_xp_required": 120,
	},
	&"apex_predator": {
		"display_name": "Apex Predator",
		"max_hp": 210,
		"move_speed_cells": 1,
		"attack_damage": 24,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 13,
		"sight_radius_cells": 9,
		"population": 2,
		"cost_bio": 0,
	},
	&"vampire_mushroom_thrall": {
		"display_name": "Vampire Mushroom Thrall",
		"max_hp": 55,
		"move_speed_cells": 1,
		"attack_damage": 7,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 24,
		"sight_radius_cells": 7,
		"population": 1,
	},
	&"wizard_tower": {
		"display_name": "Wizard Tower",
		"max_hp": 700,
		"build_time_seconds": 0.0,
		"auto_evolves": true,
		"evolution_seconds": 90.0,
		"footprint": Vector2i(4, 4),
	},
	&"bio_absorber": {
		"display_name": "Bio Absorber",
		"max_hp": 260,
		"income_per_tick": 12,
		"cost_bio": 100,
		"build_time_seconds": 4.0,
		"auto_evolves": true,
		"evolution_seconds": 75.0,
		"upgrade_choices": [&"heal_aura", &"bio_launcher"],
		"footprint": Vector2i(2, 2),
	},
	&"barracks": {
		"display_name": "Barracks",
		"max_hp": 380,
		"cost_bio": 140,
		"build_time_seconds": 6.0,
		"auto_evolves": true,
		"evolution_seconds": 100.0,
		"footprint": Vector2i(3, 3),
		"production": [&"terrible_thing", &"horror", &"apex"],
	},
	&"terrible_vault": {
		"display_name": "Terrible Vault",
		"max_hp": 320,
		"cost_bio": 160,
		"build_time_seconds": 7.0,
		"auto_evolves": true,
		"evolution_seconds": 120.0,
		"footprint": Vector2i(3, 3),
	},
	&"vinewall": {
		"display_name": "Vinewall",
		"max_hp": 220,
		"starts_at_hp_percent": 0.5,
		"cost_bio": 35,
		"build_time_seconds": 1.2,
		"regeneration_per_second": 2,
		"retaliation_damage": 5,
		"evolution_xp_required": 80,
		"footprint": Vector2i(1, 1),
	},
	&"bio_launcher": {
		"display_name": "Bio Launcher",
		"max_hp": 260,
		"cost_bio": 130,
		"build_time_seconds": 6.0,
		"attack_damage": 18,
		"attack_range_cells": 7,
		"attack_cooldown_ticks": 32,
		"can_uproot": true,
		"evolution_xp_required": 120,
		"footprint": Vector2i(2, 2),
	},
}

static func get_definition(archetype: StringName) -> Dictionary:
	return DEFINITIONS.get(archetype, {}).duplicate(true)

static func max_hp(archetype: StringName) -> int:
	return int(get_definition(archetype).get("max_hp", 40))

static func attack_damage(archetype: StringName) -> int:
	return int(get_definition(archetype).get("attack_damage", 0))

static func attack_range_cells(archetype: StringName) -> int:
	return int(get_definition(archetype).get("attack_range_cells", 0))

static func cost_bio(archetype: StringName) -> int:
	return int(get_definition(archetype).get("cost_bio", 0))

static func train_time(archetype: StringName) -> float:
	return float(get_definition(archetype).get("train_time_seconds", 0.0))
