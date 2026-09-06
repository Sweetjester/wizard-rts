class_name UnitCatalog
extends RefCounted

const DEFINITIONS := {
	&"mounted_knight": {
		"display_name":"Mounted Knight", "faction":&"steel_force", "unit_family":&"mounted_knight", "tier":3,
		"intelligence":3,"aggro_range_cells":6,"max_hp":620,"armor":14,"magic_armor":2,
		"attack_damage":54,"attack_range_cells":1.2,"attack_speed_seconds":1.25,"attack_type":&"melee",
		"move_speed_cells":3.2,"sight_radius_cells":7,"population":5,"cost_bio":300,"train_time_seconds":26.0,
		"momentum_max_stacks":5,"momentum_distance_per_stack":64.0,"momentum_speed_per_stack":0.08,
		"flame_duration_seconds":12.0,"flame_damage_multiplier":1.5,
		"card_portrait":"res://assets_game/units/steel_force/mounted_knight/directional_v1/portrait.png",
		"card_blurb":"An armoured bull carries a relentless rider. Five running stacks kindle the axe; even a fallen mount cannot end the advance.",
		"role":"Fast heavy melee. Each cell run adds a momentum stack and 8% speed (max 5). Five stacks ignite the axe: +50% damage for 12 seconds. Stops/collisions reset momentum, not fire. Slain mounts leave a half-health Steel Knight.",
		"passives":["Momentum","Kindled Axe: 12 seconds","Unseated: half-health Tier 2 Knight"],"actives":[],
	},
	&"poorper": {
		"display_name":"Poorper", "faction":&"steel_force", "unit_family":&"poorper", "tier":1,
		"intelligence":3,"aggro_range_cells":5,"max_hp":100,"armor":2,"magic_armor":0,
		"attack_damage":12,"attack_range_cells":1,"attack_speed_seconds":0.9,"attack_type":&"melee",
		"move_speed_cells":2,"sight_radius_cells":6,"population":1,"cost_bio":40,"train_time_seconds":5.0,
		"card_portrait":"res://assets_game/units/steel_force/painted_v1/poorper_portrait.png",
		"role":"Steel Force basic melee infantry. Can crew a landed Proper Blimp.","actives":[],
	},
	&"steel_knight": {
		"display_name":"Steel Knight", "faction":&"steel_force", "unit_family":&"steel_knight", "tier":2,
		"intelligence":3,"aggro_range_cells":5,"max_hp":340,"armor":10,"magic_armor":2,
		"attack_damage":38,"attack_range_cells":1,"attack_speed_seconds":1.4,"attack_type":&"melee",
		"move_speed_cells":1,"sight_radius_cells":6,"population":3,"cost_bio":140,"train_time_seconds":14.0,
		"card_portrait":"res://assets_game/units/steel_force/painted_v1/steel_knight_portrait.png",
		"role":"Slow, heavily armoured Steel Force melee infantry.","actives":[],
	},
	&"proper_blimp": {
		"display_name":"Proper Blimp", "faction":&"steel_force", "unit_family":&"proper_blimp", "tier":2,
		"intelligence":3,"aggro_range_cells":7,"max_hp":280,"armor":4,"magic_armor":0,
		"attack_damage":10,"attack_range_cells":6,"attack_speed_seconds":2.5,"attack_type":&"ranged_splash",
		"attack_splash_radius_cells":0.7,"projectile_speed":320,"ignores_terrain":true,
		"move_speed_cells":2,"sight_radius_cells":8,"population":3,"cost_bio":180,"train_time_seconds":18.0,
		"transport_capacity":3,"card_portrait":"res://assets_game/units/steel_force/painted_v1/proper_blimp_portrait.png",
		"role":"Flying weak artillery. Land to board or unload up to three allied Poorpers. Requires crew to fire.",
		"actives":["Land","Take Off","Board Poorpers","Unload Poorpers"],
	},
	&"life_wizard": {
		"intelligence": 3,
		"aggro_range_cells": 5,
		"display_name": "Bad Kon Willow",
		"unit_family": &"kon",
		"form": &"hero",
		"tier": 0,
		"kon_theme": &"observer",
		"card_portrait": "res://assets/ui/unit_cards/life_wizard_card.png",
		"card_blurb": "Hero. An observer who sampled the forbidden against his kin's wishes and splices them into controllable hybrids, while keeping his observer magics.",
		"max_hp": 260,
		"armor": 2,
		"magic_armor": 4,
		"move_speed_cells": 1,
		"attack_damage": 16,
		"attack_range_cells": 4,
		"attack_cooldown_ticks": 17,
		"attack_speed_seconds": 0.85,
		"attack_type": &"ranged_single",
		"attack_splash_radius_cells": 0.0,
		"projectile_speed": 680.0,
		"dual_cast": true,
		"sight_radius_cells": 9,
		"population": 1,
		"builder_unit": true,
		"role": "Life wizard. Broken Staff strikes twice. Banishes all units in a circle; Biostorm harms friend and foe. Observation projects sight and tower-top summons.",
		"passives": ["Builder unit", "Broken Staff", "Observer"],
		"actives": ["Bio Mend", "Seal Away", "Observation Aura", "Biostorm"],
		"activated_abilities": [&"bio_mend", &"seal_away", &"observer_aura", &"biostorm"],
		"passive_abilities": [&"builder_unit", &"dual_cast_staff"],
		"animation_profile": {
			"frame_size": Vector2i(384, 384),
			"directions": 2,
			"actions": [&"idle", &"move", &"attack_dual_cast", &"bio_mend", &"seal_away", &"observer_aura", &"biostorm", &"hit", &"death"],
		},
	},
	&"fire_wizard": {
		"intelligence": 3,
		"aggro_range_cells": 5,
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
	&"evangalion_wizard": {
		"intelligence": 3,
		"aggro_range_cells": 5,
		"display_name": "Evangalion",
		"max_hp": 190,
		"move_speed_cells": 1,
		"attack_damage": 20,
		"attack_range_cells": 5,
		"attack_cooldown_ticks": 18,
		"projectile_speed": 760.0,
		"sight_radius_cells": 10,
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
		"intelligence": 3,
		"aggro_range_cells": 5,
		"display_name": "Terrible Thing",
		"unit_family": &"terrible_thing",
		"form": &"base",
		"max_hp": 64,
		"armor": 0,
		"magic_armor": 0,
		"move_speed_cells": 1,
		"attack_damage": 8,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 16,
		"attack_speed_seconds": 0.8,
		"attack_type": &"melee",
		"attack_splash_radius_cells": 0.0,
		"sight_radius_cells": 6,
		"population": 1,
		"cost_bio": 28,
		"train_time_seconds": 3.8,
		"evolves_to": &"gripper",
		"evolution_xp_required": 90,
		"role": "Cheap swarm unit. Charges and grapples, but is weak alone and detonates when killed by allied friendly fire.",
		"passives": ["Sacrificial explosion", "Pack grappler"],
		"actives": ["Charge", "Grapple"],
		"activated_abilities": [&"charge", &"grapple"],
		"passive_abilities": [&"sacrificial_explosion", &"pack_grappler"],
		"grapple_power": 1,
		"grapple_seconds": 2.4,
		"grapple_cooldown_seconds": 4.0,
		"charge_speed_multiplier": 1.55,
		"death_explosion_damage": 18,
		"death_explosion_radius": 92.0,
		"friendly_fire_explodes": true,
		"animation_profile": {
			"frame_size": Vector2i(128, 128),
			"directions": 8,
			"actions": [&"idle", &"move", &"attack_melee", &"charge", &"grapple", &"evolve", &"death_explode"],
		},
	},
	&"gripper": {
		"intelligence": 3,
		"aggro_range_cells": 5,
		"display_name": "Gripper",
		"unit_family": &"terrible_thing",
		"form": &"evolved",
		"max_hp": 132,
		"armor": 4,
		"magic_armor": 2,
		"move_speed_cells": 1,
		"attack_damage": 14,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 16,
		"attack_speed_seconds": 0.8,
		"attack_type": &"melee",
		"attack_splash_radius_cells": 0.0,
		"sight_radius_cells": 6,
		"population": 1,
		"cost_bio": 0,
		"role": "Evolved Terrible Thing. Tougher, no longer detonates to allied fire, and its grapple roots nearby enemies.",
		"passives": ["Pack grappler", "Area root grapple"],
		"actives": ["Charge", "Grapple"],
		"activated_abilities": [&"charge", &"grapple"],
		"passive_abilities": [&"pack_grappler", &"area_root_grapple"],
		"grapple_power": 2,
		"grapple_seconds": 2.0,
		"grapple_cooldown_seconds": 3.6,
		"grapple_aoe_radius": 96.0,
		"charge_speed_multiplier": 1.45,
		"friendly_fire_explodes": false,
		"animation_profile": {
			"frame_size": Vector2i(128, 128),
			"directions": 8,
			"actions": [&"idle", &"move", &"attack_melee", &"charge", &"grapple_aoe", &"death"],
		},
	},
	&"awful_thing": {
		"display_name": "Awful Thing (Deprecated)",
		"max_hp": 132,
		"armor": 4,
		"magic_armor": 2,
		"move_speed_cells": 1,
		"attack_damage": 14,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 16,
		"attack_speed_seconds": 0.8,
		"attack_type": &"melee",
		"sight_radius_cells": 6,
		"population": 1,
		"cost_bio": 0,
		"role": "Compatibility alias for Gripper. New content should use gripper.",
		"passives": ["Pack grappler", "Area root grapple"],
		"actives": ["Charge", "Grapple"],
		"grapple_power": 2,
		"grapple_seconds": 2.0,
		"grapple_cooldown_seconds": 3.6,
		"grapple_aoe_radius": 96.0,
		"charge_speed_multiplier": 1.45,
		"friendly_fire_explodes": false,
	},
	&"horror": {
		"intelligence": 3,
		"aggro_range_cells": 6,
		"display_name": "Horror",
		"unit_family": &"horror",
		"form": &"base",
		"max_hp": 72,
		"armor": 1,
		"magic_armor": 1,
		"move_speed_cells": 1,
		"attack_damage": 10,
		"attack_range_cells": 4,
		"attack_cooldown_ticks": 20,
		"attack_speed_seconds": 1.0,
		"attack_type": &"ranged_single",
		"attack_splash_radius_cells": 0.0,
		"projectile_speed": 720.0,
		"sight_radius_cells": 8,
		"population": 1,
		"cost_bio": 65,
		"train_time_seconds": 7.0,
		"evolves_to": &"hunter",
		"evolution_xp_required": 80,
		"evolution_speed_bonus": 22,
		"role": "Fast ranged skirmisher. Evolution pushes it toward speed and kiting.",
		"passives": ["Evolution speed gain"],
		"actives": [],
		"activated_abilities": [],
		"passive_abilities": [&"evolution_speed_gain"],
		"animation_profile": {
			"frame_size": Vector2i(128, 128),
			"directions": 8,
			"actions": [&"idle", &"move", &"attack_ranged", &"evolve", &"death"],
		},
	},
	&"hunter": {
		"intelligence": 3,
		"aggro_range_cells": 6,
		"display_name": "Hunter",
		"unit_family": &"horror",
		"form": &"evolved",
		"max_hp": 108,
		"armor": 2,
		"magic_armor": 2,
		"move_speed_cells": 1,
		"attack_damage": 16,
		"attack_range_cells": 4,
		"attack_cooldown_ticks": 18,
		"attack_speed_seconds": 0.9,
		"attack_type": &"ranged_single",
		"attack_splash_radius_cells": 0.0,
		"projectile_speed": 780.0,
		"sight_radius_cells": 9,
		"population": 1,
		"cost_bio": 0,
		"role": "Evolved Horror. Builds Hunt charges for burst attacks with double range and double damage.",
		"passives": ["Hunt charge"],
		"actives": [],
		"activated_abilities": [],
		"passive_abilities": [&"hunt"],
		"hunt_charge_seconds": 10.0,
		"hunt_max_charges": 1,
		"hunt_range_multiplier": 2.0,
		"hunt_damage_multiplier": 2.0,
		"animation_profile": {
			"frame_size": Vector2i(128, 128),
			"directions": 8,
			"actions": [&"idle", &"move", &"attack_ranged", &"hunt_attack", &"death"],
		},
	},
	&"apex": {
		"intelligence": 2,
		"aggro_range_cells": 6,
		"display_name": "Apex",
		"unit_family": &"apex",
		"form": &"base",
		"max_hp": 150,
		"armor": 3,
		"magic_armor": 2,
		"move_speed_cells": 1,
		"attack_damage": 17,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 22,
		"attack_speed_seconds": 1.1,
		"attack_type": &"melee",
		"attack_splash_radius_cells": 0.0,
		"sight_radius_cells": 8,
		"population": 2,
		"cost_bio": 110,
		"train_time_seconds": 10.0,
		"heal_per_attack": 8,
		"evolves_to": &"champion",
		"evolution_xp_required": 120,
		"role": "Support predator. Heals in combat and can eat allied units for evolution.",
		"passives": ["Combat healing", "Carrion evolution"],
		"actives": ["Eat ally"],
		"activated_abilities": [&"consume_ally"],
		"passive_abilities": [],
		"animation_profile": {
			"frame_size": Vector2i(160, 160),
			"directions": 8,
			"actions": [&"idle", &"move", &"attack_melee", &"consume_ally", &"heal_pulse", &"evolve", &"death"],
		},
	},
	&"champion": {
		"intelligence": 2,
		"aggro_range_cells": 6,
		"display_name": "Champion",
		"unit_family": &"apex",
		"form": &"evolved",
		"max_hp": 260,
		"armor": 6,
		"magic_armor": 4,
		"move_speed_cells": 1,
		"attack_damage": 30,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 13,
		"attack_speed_seconds": 0.65,
		"attack_type": &"melee",
		"attack_splash_radius_cells": 0.0,
		"sight_radius_cells": 9,
		"population": 2,
		"cost_bio": 0,
		"role": "Evolved Apex. Gains attack speed and armor as health falls; Consume Ally heals instead of granting XP.",
		"passives": ["Combat healing", "Wounded champion"],
		"actives": ["Eat ally"],
		"activated_abilities": [&"consume_ally"],
		"passive_abilities": [&"wounded_champion"],
		"low_health_attack_speed_bonus": 0.35,
		"low_health_armor_bonus": 4,
		"consume_ally_heals": true,
		"animation_profile": {
			"frame_size": Vector2i(160, 160),
			"directions": 8,
			"actions": [&"idle", &"move", &"attack_melee", &"consume_ally", &"wounded_frenzy", &"death"],
		},
	},
	&"apex_predator": {
		"display_name": "Apex Predator (Deprecated)",
		"max_hp": 260,
		"armor": 6,
		"magic_armor": 4,
		"move_speed_cells": 1,
		"attack_damage": 30,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 13,
		"attack_speed_seconds": 0.65,
		"attack_type": &"melee",
		"sight_radius_cells": 9,
		"population": 2,
		"cost_bio": 0,
		"role": "Compatibility alias for Champion. New content should use champion.",
		"passives": ["Combat healing", "Wounded champion"],
		"actives": ["Eat ally"],
	},
	&"spawner": {
		"intelligence": 2,
		"aggro_range_cells": 9,
		"display_name": "Spawner",
		"unit_family": &"spawner",
		"form": &"base",
		"tier": 3,
		"kon_theme": &"evolution",
		"card_portrait": "res://assets_game/units/kon/spawner/painted_v2/portrait.png",
		"card_blurb": "Tier 3. Kon's most capable obedient creation, unleashed only through great effort. Costs Bio every time it summons a drone or fires its cannon.",
		"max_hp": 360,
		"armor": 5,
		"magic_armor": 3,
		"move_speed_cells": 1,
		"attack_damage": 38,
		"attack_range_cells": 8,
		"attack_cooldown_ticks": 48,
		"attack_speed_seconds": 2.4,
		"attack_type": &"ranged_aoe",
		"attack_splash_radius_cells": 1.8,
		"projectile_speed": 460.0,
		"sight_radius_cells": 9,
		"population": 4,
		"cost_bio": 210,
		"train_time_seconds": 18.0,
		"role": "Slow siege organism. Maintains drones, roots to fire a long-range AoE cannon.",
		"passives": ["Drone brood cap 2", "Rooted artillery"],
		"actives": ["Summon drone", "Root", "Uproot"],
		"activated_abilities": [&"summon_drone", &"root", &"uproot"],
		"passive_abilities": [&"spawn_drones"],
		"drone_archetype": &"spawner_drone",
		"drone_cap": 2,
		"drone_summon_cost_bio": 12,
		"drone_summon_cooldown_seconds": 8.0,
		"shot_cost_bio": 4,
		"aoe_radius": 116.0,
		"requires_root_to_fire": true,
		"root_cast_seconds": 2.0,
		"uproot_cast_seconds": 2.0,
		"evolution_xp_required": 180,
		"evolves_to": &"winged_spawner",
		"animation_profile": {
			"frame_size": Vector2i(384, 384),
			"directions": 2,
			"actions": [&"idle", &"move", &"root_cast", &"rooted_idle", &"artillery_attack", &"uproot_cast", &"summon_drone", &"evolve_wings", &"death"],
		},
	},
	&"winged_spawner": {
		"intelligence": 2,
		"aggro_range_cells": 10,
		"display_name": "Winged Spawner",
		"unit_family": &"spawner",
		"form": &"evolved",
		"tier": 3,
		"kon_theme": &"evolution",
		"card_portrait": "res://assets_game/units/kon/spawner/painted_v2/portrait.png",
		"card_blurb": "Evolved Spawner. Flies while moving and no longer roots to fire, but range and damage are halved while it is on the move.",
		"max_hp": 430,
		"armor": 5,
		"magic_armor": 5,
		"move_speed_cells": 1,
		"attack_damage": 44,
		"attack_range_cells": 8,
		"attack_cooldown_ticks": 42,
		"attack_speed_seconds": 2.1,
		"attack_type": &"ranged_aoe",
		"attack_splash_radius_cells": 1.9,
		"projectile_speed": 500.0,
		"sight_radius_cells": 10,
		"population": 4,
		"cost_bio": 0,
		"role": "Evolved flying Spawner. Mobile artillery that no longer roots to fire.",
		"passives": ["Flying artillery", "Drone brood cap 2"],
		"actives": ["Summon drone"],
		"activated_abilities": [&"summon_drone"],
		"passive_abilities": [&"spawn_drones", &"flying", &"moving_attack_penalty"],
		"drone_archetype": &"spawner_drone",
		"drone_cap": 2,
		"drone_summon_cost_bio": 10,
		"drone_summon_cooldown_seconds": 7.0,
		"shot_cost_bio": 3,
		"aoe_radius": 124.0,
		"ignores_terrain": true,
		"evolution_speed_bonus": 45,
		"takeoff_seconds": 0.5,
		"landing_seconds": 0.5,
		"moving_attack_range_multiplier": 0.5,
		"moving_attack_damage_multiplier": 0.5,
		"animation_profile": {
			"frame_size": Vector2i(384, 384),
			"directions": 2,
			"actions": [&"idle_flying", &"move_flying", &"takeoff", &"landing", &"artillery_attack", &"summon_drone", &"death"],
		},
	},
	&"mangler": {
		"display_name": "Mangler",
		"unit_family": &"mangler", "form": &"base", "tier": 2,
		"kon_theme": &"evolution", "intelligence": 3, "aggro_range_cells": 6,
		"card_portrait": "res://assets_game/units/kon/mangler/painted_v1/portrait.png",
		"card_blurb": "A knuckle-running assault hybrid. Five momentum stacks build across five cells of continuous running; the next enemy impact bursts in an area.",
		"max_hp": 320, "armor": 5, "magic_armor": 2,
		"move_speed_cells": 2.5, "attack_damage": 30, "attack_range_cells": 0.9,
		"attack_cooldown_ticks": 22, "attack_speed_seconds": 1.1, "attack_type": &"melee",
		"sight_radius_cells": 7, "population": 3, "cost_bio": 145, "train_time_seconds": 13.0,
		"role": "Melee assault. Gains 8% speed per momentum stack, up to 40%; a full charge adds 36 area damage. Stops and collisions reset momentum.",
		"passives": ["Momentum (5 stacks)", "Full-charge impact"], "actives": [],
		"evolution_xp_required": 120, "evolves_to": &"winged_mangler",
		"animation_profile": {"frame_size": Vector2i(384,384), "directions": 2, "actions": [&"idle", &"run", &"attack", &"hit", &"evolve", &"death"]},
	},
	&"winged_mangler": {
		"display_name": "Winged Mangler",
		"unit_family": &"mangler", "form": &"evolved", "tier": 2,
		"kon_theme": &"evolution", "intelligence": 3, "aggro_range_cells": 6,
		"card_portrait": "res://assets_game/units/kon/mangler/painted_v1/portrait.png",
		"card_blurb": "The assault hybrid sprouts dragonfly wings. Remains ground-based, but can leap to clear ground and slam nearby enemies.",
		"max_hp": 360, "armor": 6, "magic_armor": 3,
		"move_speed_cells": 2.5, "attack_damage": 34, "attack_range_cells": 0.9,
		"attack_cooldown_ticks": 22, "attack_speed_seconds": 1.1, "attack_type": &"melee",
		"sight_radius_cells": 8, "population": 3, "cost_bio": 0,
		"role": "Ground assault with manual Leap Slam: 6-cell range, 65 area damage, 1.5s enemy stun, 14s cooldown. Keeps Momentum.",
		"passives": ["Momentum (5 stacks)", "Full-charge impact"], "actives": ["Leap Slam"],
		"activated_abilities": [&"mangler_leap"],
		"animation_profile": {"frame_size": Vector2i(384,384), "directions": 2, "actions": [&"idle", &"run", &"attack", &"hit", &"windup", &"leap", &"land", &"evolve", &"death"]},
	},
	&"stone_face_serpent": {
		"intelligence": 2,
		"aggro_range_cells": 7,
		"display_name": "Stone-Faced Serpent",
		"unit_family": &"stone_face_serpent",
		"form": &"growth",
		"tier": 2,
		"kon_theme": &"evolution",
		"card_portrait": "res://assets_game/units/kon/serpent/painted_v2/portrait.png",
		"card_blurb": "Tier 2. A stronger species spliced with the forbidden. Grows up to five times, and can harden its whole length into a portable wall -- losing its attack, gaining HP by level.",
		"max_hp": 240,
		"armor": 5,
		"magic_armor": 3,
		"move_speed_cells": 1,
		"attack_damage": 24,
		"attack_range_cells": 2,
		"attack_cooldown_ticks": 26,
		"attack_speed_seconds": 1.3,
		"attack_type": &"melee",
		"attack_splash_radius_cells": 0.0,
		"sight_radius_cells": 8,
		"population": 3,
		"cost_bio": 165,
		"train_time_seconds": 14.0,
		"role": "Hybrid stone serpent. Grows through evolution and can turn its length into an impassible stone wall.",
		"passives": ["Poison sting", "Coil strike", "Multi-growth evolution"],
		"actives": ["Stone Form"],
		"activated_abilities": [&"stone_form"],
		"passive_abilities": [&"poison_sting", &"coil_strike"],
		"unit_type_tags": [&"evolution"],
		"evolution_xp_required": 45,
		"max_evolution_level": 6,
		"stone_form_base_length": 3,
		"stone_form_hp_multiplier": 2.0,
		"stone_form_growth_hp_multiplier": 0.2,
		"stone_form_armor_bonus": 8,
		"stone_form_growth_armor_bonus": 3,
		"stone_form_placement_range_cells": 8,
		"stone_form_cast_seconds": 2.0,
		"stone_form_cooldown_seconds": 10.0,
		"growth_hp_bonus": 58,
		"growth_damage_bonus": 5,
		"growth_range_cells_bonus": -0.25,
		"growth_size_bonus": 3.0,
		"poison_damage_per_second": 5.0,
		"poison_duration_seconds": 4.0,
		"animation_profile": {
			"frame_size": Vector2i(192, 192),
			"directions": 8,
			"actions": [&"idle", &"move", &"attack_melee", &"poison_sting", &"stone_cast", &"stone_idle", &"revert_stone", &"evolve_growth", &"death"],
		},
	},
	&"oaven_spear": {
		"intelligence": 3,
		"garrison_work": 1.0,
		"aggro_range_cells": 6,
		"display_name": "Oaven",
		"unit_family": &"oaven",
		"form": &"base",
		"tier": 1,
		"kon_theme": &"evolution",
		"card_portrait": "res://assets/ui/unit_cards/oaven_spear_card.png",
		"card_blurb": "Hybrids of a particularly intelligent species and the forbidden. Subservient to Kon, and available to him from the first minute of a run.",
		"max_hp": 58,
		"armor": 1,
		"magic_armor": 1,
		"move_speed_cells": 1,
		"attack_damage": 7,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 15,
		"attack_speed_seconds": 0.75,
		"attack_type": &"melee",
		"attack_splash_radius_cells": 0.0,
		"sight_radius_cells": 7,
		"population": 1,
		"cost_bio": 32,
		"train_time_seconds": 4.0,
		"evolves_to": &"oaven_jumper",
		"evolution_xp_required": 95,
		"role": "Cheap swarm spear-carrier. Taunts nearby enemies and cripples moving targets that try to pull away.",
		"passives": ["Crippling spear"],
		"actives": ["Taunt", "Charge"],
		"activated_abilities": [&"taunt", &"charge"],
		"passive_abilities": [&"crippling_spear"],
		"charge_speed_multiplier": 1.42,
		"taunt_radius": 168.0,
		"taunt_seconds": 3.0,
		"taunt_damage_reduction": 0.12,
		"cripple_seconds": 1.35,
		"cripple_bonus_damage": 5,
		"cripple_cooldown_seconds": 3.2,
		"cripple_requires_moving_target": true,
		"weapon_modes": {
			&"spear": {
				"display_name": "Spear",
				"attack_damage": 7,
				"attack_range_cells": 1,
				"attack_speed_seconds": 0.75,
				"attack_type": &"melee",
			},
			&"blowpipe": {
				"display_name": "Blowpipe",
				"attack_damage": 5,
				"attack_range_cells": 5,
				"attack_speed_seconds": 1.05,
				"attack_type": &"ranged_single",
				"projectile_speed": 660.0,
			},
			# Brought out only from a structure's upper floors, and swapped away
			# again on the way down -- see VantageEffects. An Oaven holding a
			# wall-walk braces a heavier pipe it cannot skirmish with: half again
			# the reach and nearly double the damage, at two thirds the rate of
			# fire and a slower dart.
			&"heavy_blowpipe": {
				"display_name": "Heavy Blowpipe",
				"attack_damage": 9,
				"attack_range_cells": 8,
				"attack_speed_seconds": 1.6,
				"attack_type": &"ranged_single",
				"projectile_speed": 520.0,
			},
		},
		"vantage_weapon_mode": &"heavy_blowpipe",
		"default_weapon_mode": &"spear",
		"weapon_swap_seconds": 0.6,
		"animation_profile": {
			"frame_size": Vector2i(256, 256),
			"directions": 2,
			"actions": [&"idle", &"move", &"attack_spear", &"attack_blowpipe", &"swap_weapon", &"taunt", &"charge", &"evolve", &"death"],
		},
	},
	&"oaven_jumper": {
		"intelligence": 3,
		"garrison_work": 1.0,
		"aggro_range_cells": 6,
		"display_name": "Oaven Jumper",
		"unit_family": &"oaven",
		"form": &"evolved",
		"tier": 1,
		"kon_theme": &"evolution",
		"card_portrait": "res://assets/ui/unit_cards/oaven_spear_card.png",
		"card_blurb": "Evolved Oaven. Keeps both weapons, gains real defensive stats, and can hold itself airborne for a few seconds -- a Charge from up there lands on the enemy and slows them.",
		"max_hp": 118,
		"armor": 4,
		"magic_armor": 3,
		"move_speed_cells": 1,
		"attack_damage": 12,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 15,
		"attack_speed_seconds": 0.75,
		"attack_type": &"melee",
		"attack_splash_radius_cells": 0.0,
		"sight_radius_cells": 8,
		"population": 1,
		"cost_bio": 0,
		"role": "Evolved Oaven. Tougher, can briefly fly, and Charge while airborne lands with a stunning impact.",
		"passives": ["Crippling spear", "Aerial landing stun"],
		"actives": ["Taunt", "Flight", "Charge"],
		"activated_abilities": [&"taunt", &"flight", &"charge"],
		"passive_abilities": [&"crippling_spear", &"aerial_landing_stun"],
		"charge_speed_multiplier": 1.55,
		"taunt_radius": 184.0,
		"taunt_seconds": 3.5,
		"taunt_damage_reduction": 0.16,
		"cripple_seconds": 1.6,
		"cripple_bonus_damage": 7,
		"cripple_cooldown_seconds": 2.7,
		"cripple_requires_moving_target": false,
		"weapon_modes": {
			&"spear": {
				"display_name": "Spear",
				"attack_damage": 12,
				"attack_range_cells": 1,
				"attack_speed_seconds": 0.75,
				"attack_type": &"melee",
			},
			&"blowpipe": {
				"display_name": "Blowpipe",
				"attack_damage": 9,
				"attack_range_cells": 6,
				"attack_speed_seconds": 1.0,
				"attack_type": &"ranged_single",
				"projectile_speed": 700.0,
			},
		},
		"default_weapon_mode": &"spear",
		"weapon_swap_seconds": 0.5,
		"temporary_flight_seconds": 4.2,
		"temporary_flight_speed_multiplier": 1.32,
		"jumper_landing_radius": 92.0,
		"jumper_landing_stun_seconds": 1.25,
		"jumper_landing_damage": 14,
		"animation_profile": {
			"frame_size": Vector2i(256, 256),
			"directions": 2,
			"actions": [&"idle", &"move", &"attack_spear", &"attack_blowpipe", &"swap_weapon", &"taunt", &"takeoff", &"flying", &"landing_stun", &"death"],
		},
	},
	&"spawner_drone": {
		"intelligence": 1,
		"aggro_range_cells": 7,
		"display_name": "Spawner Drone",
		"tier": 3,
		"kon_theme": &"evolution",
		"card_portrait": "res://assets/ui/unit_cards/spawner_card.png",
		"card_blurb": "Summoned, short-lived flying support. Bound to its Spawner's brood cap of two.",
		"max_hp": 34,
		"move_speed_cells": 1,
		"attack_damage": 5,
		"attack_range_cells": 3,
		"attack_cooldown_ticks": 17,
		"projectile_speed": 690.0,
		"sight_radius_cells": 7,
		"population": 0,
		"cost_bio": 0,
		"role": "Short-lived flying support drone from a Spawner.",
		"passives": ["Flying support", "Bound to Spawner brood"],
		"actives": [],
		"ignores_terrain": true,
		"lifetime_seconds": 45.0,
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
	&"bloodcap_runner": {
		"display_name": "Bloodcap Runner",
		"max_hp": 38,
		"move_speed_cells": 1,
		"attack_damage": 5,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 16,
		"sight_radius_cells": 8,
		"population": 1,
	},
	&"spore_spitter": {
		"display_name": "Spore Spitter",
		"max_hp": 44,
		"move_speed_cells": 1,
		"attack_damage": 8,
		"attack_range_cells": 4,
		"attack_cooldown_ticks": 28,
		"projectile_speed": 520.0,
		"sight_radius_cells": 8,
		"population": 1,
	},
	&"bloodcap_brute": {
		"display_name": "Bloodcap Brute",
		"max_hp": 145,
		"move_speed_cells": 1,
		"attack_damage": 17,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 34,
		"sight_radius_cells": 7,
		"population": 2,
	},
	&"mycelium_boss": {
		"display_name": "Mycelium Matriarch",
		"max_hp": 3000,
		"move_speed_cells": 1,
		"attack_damage": 95,
		"attack_range_cells": 3,
		"attack_cooldown_ticks": 14,
		"sight_radius_cells": 10,
		"population": 6,
		"ignores_terrain": true,
	},
	&"enemy_outpost": {
		"sight_radius_cells": 9,
		"display_name": "Enemy Outpost",
		"max_hp": 720,
		"armor": 2,
		"magic_armor": 1,
		"attack_damage": 0,
		"attack_range_cells": 0,
		"footprint": Vector2i(4, 4),
		"role": "Vertical-slice objective structure. Destroying required outposts unlocks the boss gate.",
	},
	&"deom_scout": {
		"display_name": "Deom Scout",
		"faction": &"deom_legion",
		"unit_family": &"deom",
		"tier": 0,
		"max_hp": 34,
		"armor": 0,
		"magic_armor": 0,
		"move_speed_cells": 1,
		"attack_damage": 5,
		"attack_range_cells": 4,
		"attack_cooldown_ticks": 18,
		"attack_speed_seconds": 0.9,
		"attack_type": &"ranged_single",
		"attack_splash_radius_cells": 0.0,
		"projectile_speed": 760.0,
		"sight_radius_cells": 9,
		"population": 1,
		"role": "Tier 0 Deom probe. Weak but fast, useful for scouting and early harassment.",
		"passives": ["Fast scout"],
		"actives": [],
		"animation_profile": {"frame_size": Vector2i(96, 96), "directions": 8, "actions": [&"idle", &"move", &"attack_ranged", &"death"]},
	},
	&"deom_blade": {
		"display_name": "Deom Blade",
		"faction": &"deom_legion",
		"unit_family": &"deom",
		"tier": 1,
		"max_hp": 76,
		"armor": 1,
		"magic_armor": 0,
		"move_speed_cells": 1,
		"attack_damage": 12,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 19,
		"attack_speed_seconds": 0.95,
		"attack_type": &"melee",
		"attack_splash_radius_cells": 0.0,
		"sight_radius_cells": 7,
		"population": 1,
		"role": "Tier 1 Deom melee body. A disposable blade carrier with decent front-line output.",
		"passives": [],
		"actives": [],
		"animation_profile": {"frame_size": Vector2i(112, 112), "directions": 8, "actions": [&"idle", &"move", &"attack_melee", &"death"]},
	},
	&"deom_crosshirran": {
		"display_name": "Crosshirran",
		"faction": &"deom_legion",
		"unit_family": &"deom",
		"tier": 1,
		"max_hp": 58,
		"armor": 0,
		"magic_armor": 1,
		"move_speed_cells": 1,
		"attack_damage": 10,
		"attack_range_cells": 5,
		"attack_cooldown_ticks": 24,
		"attack_speed_seconds": 1.2,
		"attack_type": &"ranged_single",
		"attack_splash_radius_cells": 0.0,
		"projectile_speed": 700.0,
		"sight_radius_cells": 8,
		"population": 1,
		"role": "Tier 1 Deom ranged line unit. Slower than the scout but much steadier in formation fights.",
		"passives": [],
		"actives": [],
		"animation_profile": {"frame_size": Vector2i(112, 112), "directions": 8, "actions": [&"idle", &"move", &"attack_ranged", &"death"]},
	},
	&"deom_hammer": {
		"display_name": "Deom Hammer",
		"faction": &"deom_legion",
		"unit_family": &"deom",
		"tier": 2,
		"max_hp": 185,
		"armor": 6,
		"magic_armor": 2,
		"move_speed_cells": 1,
		"attack_damage": 28,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 34,
		"attack_speed_seconds": 1.7,
		"attack_type": &"melee",
		"attack_splash_radius_cells": 0.0,
		"sight_radius_cells": 7,
		"population": 3,
		"role": "Tier 2 armoured melee unit. Slow, hard to dislodge, and built to anchor a Deom push.",
		"passives": ["Armoured"],
		"actives": [],
		"animation_profile": {"frame_size": Vector2i(144, 144), "directions": 8, "actions": [&"idle", &"move", &"attack_melee", &"death"]},
	},
	&"deom_glaive": {
		"display_name": "Deom Glaive",
		"faction": &"deom_legion",
		"unit_family": &"deom",
		"tier": 2,
		"max_hp": 96,
		"armor": 2,
		"magic_armor": 2,
		"move_speed_cells": 1,
		"attack_damage": 16,
		"attack_range_cells": 5,
		"attack_cooldown_ticks": 18,
		"attack_speed_seconds": 0.9,
		"attack_type": &"ranged_single",
		"attack_splash_radius_cells": 0.0,
		"projectile_speed": 830.0,
		"sight_radius_cells": 9,
		"population": 2,
		"role": "Tier 2 fast ranged unit. The Deom Legion's mobile skirmish pressure.",
		"passives": ["Fast skirmisher"],
		"actives": [],
		"animation_profile": {"frame_size": Vector2i(128, 128), "directions": 8, "actions": [&"idle", &"move", &"attack_ranged", &"death"]},
	},
	&"deom_odden": {
		"display_name": "Odden",
		"faction": &"deom_legion",
		"unit_family": &"deom",
		"tier": 3,
		"max_hp": 340,
		"armor": 4,
		"magic_armor": 5,
		"move_speed_cells": 1,
		"attack_damage": 22,
		"attack_range_cells": 7,
		"attack_cooldown_ticks": 32,
		"attack_speed_seconds": 1.6,
		"attack_type": &"ranged_single",
		"attack_splash_radius_cells": 0.0,
		"projectile_speed": 620.0,
		"sight_radius_cells": 11,
		"population": 5,
		"ignores_terrain": true,
		"transport_capacity": 6,
		"role": "Tier 3 slow flying ranged transport. A blimp-like Deom carrier for future drop behaviours.",
		"passives": ["Flying", "Transport capacity 6"],
		"actives": [],
		"animation_profile": {"frame_size": Vector2i(192, 160), "directions": 8, "actions": [&"idle_flying", &"move_flying", &"attack_ranged", &"transport_idle", &"death"]},
	},
	&"the_forbidden": {
		"intelligence": 1,
		"aggro_range_cells": 14,
		"display_name": "The Forbidden",
		"unit_family": &"forbidden",
		"form": &"unleashed",
		"tier": 4,
		"kon_theme": &"evolution",
		"card_portrait": "res://assets/ui/unit_cards/stone_face_serpent_card.png",
		"card_blurb": "Tier 4. The species the observers sealed away, too horrific and terrible to be allowed to exist. Only in great peril would Kon consider unleashing it. It will NOT obey him, and turns its wrath on all.",
		"max_hp": 1400,
		"armor": 8,
		"magic_armor": 8,
		"move_speed_cells": 1,
		"attack_damage": 85,
		"attack_range_cells": 2,
		"attack_cooldown_ticks": 24,
		"attack_speed_seconds": 1.2,
		"attack_type": &"melee",
		"attack_splash_radius_cells": 1.6,
		"sight_radius_cells": 12,
		"population": 0,
		"cost_bio": 900,
		"train_time_seconds": 0.0,
		"role": "Uncontrollable siege horror. Hostile to every player including the one who unleashed it.",
		"passives": ["Unleashed -- obeys nobody", "Hostile to all", "Cleaving strikes", "Decays over time"],
		"actives": [],
		"passive_abilities": [&"uncontrollable", &"hostile_to_all"],
		"uncontrollable": true,
		"hostile_to_all": true,
		"lifetime_seconds": 120.0,
		"unleash_cost_bio": 900,
		"animation_profile": {
			"frame_size": Vector2i(256, 256),
			"directions": 8,
			"actions": [&"idle", &"move", &"attack_cleave", &"unleash", &"death"],
		},
	},
	&"wizard_tower": {
		"sight_radius_cells": 12,
		"display_name": "Observation Tower",
		"kon_theme": &"observer",
		"card_blurb": "HQ. A tower under a glass dome. Kon can garrison inside to build his base from cover and project his observer auras while he micros.",
		"max_hp": 700,
		"build_time_seconds": 0.0,
		"auto_evolves": true,
		"evolution_seconds": 90.0,
		"garrison_capacity": 1,
		"garrison_build_radius_cells": 14,
		"garrison_aura_radius": 620.0,
		"garrison_aura_damage_bonus": 0.12,
		"garrison_aura_armor_bonus": 1,
		# Fallback matches the compact runtime plan; BuildSystem reads the plan.
		"footprint": Vector2i(18, 18),
		"block_structure": &"kons_observation_wizard_tower_01",
		"cost_bio": 260,
		# Megastructure (master doc section 39). Production and research are built
		# INSIDE it as modules; economy and walls stay on the ground, because their
		# position on the map is part of the decision, and moving them inside would
		# delete the base-placement choice section 12 depends on.
		"module_slots": 3,
		# Shell and core sum to the old 700 max_hp, so this changes how the tower
		# dies without rebalancing how much damage it takes.
		"components": [
			{"id": &"shell", "hp": 250, "region": Rect2i(0, 0, 3, 3)},
			{"id": &"core", "hp": 450, "critical": true, "region": Rect2i(1, 1, 1, 1)},
		],
	},
	&"bio_absorber": {
		"sight_radius_cells": 7,
		"display_name": "Bio Absorber",
		"kon_theme": &"evolution",
		"card_blurb": "Economy. A large sentient drill that tunnels in and absorbs the Bio of the area. Passively mends nearby units and buildings, so a harder base site with more eco slots pays twice.",
		"max_hp": 260,
		"income_per_tick": 16,
		"cost_bio": 90,
		"build_time_seconds": 4.0,
		"auto_evolves": true,
		"evolution_seconds": 75.0,
		"upgrade_choices": [&"heal_aura", &"bio_launcher"],
		"heal_aura_radius": 460.0,
		"heal_per_second": 2.0,
		"upgraded_heal_aura_radius": 720.0,
		"upgraded_heal_per_second": 6.0,
		"footprint": Vector2i(2, 2),
	},
	&"barracks": {
		"sight_radius_cells": 7,
		"display_name": "Biospawner",
		"kon_theme": &"crossover",
		"card_blurb": "Production. A horrible living lab of biomass -- a normal lab overrun and controlled by evolution. The only Kon building where the observer and evolution themes cross over. Upgrades itself for free over time once built.",
		"max_hp": 380,
		"cost_bio": 120,
		"build_time_seconds": 6.0,
		"auto_evolves": true,
		"evolution_seconds": 100.0,
		# Placed on the ground again, and no longer a 3x3 sprite.
		#
		# It was briefly a tower module on the theory that where a barracks sits
		# was never a decision. It is one now: the Splicing Laboratory is a
		# walkable block structure with a muster hall, aisles and upper
		# galleries, and buildings placed next to each other are meant to read as
		# a town rather than as icons on grass. So position matters again.
		#
		# The footprint matches the authored structure exactly. If they disagree
		# the building's 2D blockers and its 3D geometry describe different
		# buildings, which is the kind of mismatch nobody sees until a unit walks
		# through a wall.
		"footprint": Vector2i(9, 7),
		"block_structure": &"kons_splicing_laboratory_01",
		# Kon's own creations only. The Steel Force is not spliced here -- it
		# musters at its own Musterhouse, which is a different building with a
		# barracks hall, bunks and a farm to feed them.
		"production": [&"terrible_thing", &"oaven_spear", &"horror", &"apex", &"spawner", &"stone_face_serpent", &"mangler"],
	},
	&"steel_musterhouse": {
		"sight_radius_cells": 7,
		"display_name": "Steel Force Musterhouse",
		"kon_theme": &"crossover",
		"card_blurb": "Production. A Steel Force muster hall and its croft, raised on Kon's ground. Conscripts are quartered, fed and armed here rather than grown -- the one building in Kon's town that was not made out of something.",
		"max_hp": 420,
		"cost_bio": 200,
		"build_time_seconds": 9.0,
		# Matches the authored structure exactly (9 x 5 x 14, so 9 by 14 on the
		# ground). A footprint that disagreed with the geometry would give the
		# building 2D blockers and 3D walls in different places.
		"footprint": Vector2i(9, 14),
		"block_structure": &"steel_force_barracks_farm_01",
		# From the structure's own production_integration contract: recruits
		# appear at the muster anchor inside the hall and walk out through the
		# muster door, rather than materialising on the grass outside.
		"muster_anchor": Vector3i(4, 1, 10),
		"production": [&"poorper", &"steel_knight", &"proper_blimp", &"mounted_knight"],
	},
	&"terrible_vault": {
		"sight_radius_cells": 7,
		"display_name": "Observer Vault",
		"kon_theme": &"observer",
		"card_blurb": "Research. Kon's walk-in vault and library: a sealed archive, reading hall and upper gallery. Studies observer magics and unlocks heavier hybrids.",
		"max_hp": 320,
		"cost_bio": 140,
		"build_time_seconds": 7.0,
		"auto_evolves": true,
		"evolution_seconds": 120.0,
		"footprint": Vector2i(9, 7),
		"block_structure": &"kons_observer_vault_01",
	},
	&"vinewall": {
		"sight_radius_cells": 4,
		"display_name": "Vinewall",
		"kon_theme": &"evolution",
		"card_blurb": "Wall. Retaliates and regenerates. Starts at half HP and gets tougher the more it fights and survives.",
		"max_hp": 220,
		"starts_at_hp_percent": 0.5,
		"cost_bio": 35,
		"build_time_seconds": 1.2,
		"regeneration_per_second": 5,
		"retaliation_damage": 8,
		"evolution_xp_required": 80,
		"footprint": Vector2i(1, 1),
	},
	&"bio_launcher": {
		"sight_radius_cells": 10,
		"display_name": "Bio Launcher",
		"kon_theme": &"evolution",
		"card_blurb": "Static long-ranged AoE defence. Can uproot, move and root again. Costs Bio per shot, fires automatically by default, and can be told to attack the ground manually.",
		"max_hp": 260,
		"cost_bio": 130,
		"build_time_seconds": 6.0,
		"attack_damage": 24,
		"attack_range_cells": 9,
		"attack_cooldown_ticks": 40,
		"shot_cost_bio": 3,
		"aoe_radius": 92.0,
		"can_uproot": true,
		"can_attack_ground": true,
		"manual_shot_cost_multiplier": 1.0,
		"evolution_xp_required": 120,
		"footprint": Vector2i(2, 2),
	},
}

# Bad Kon Willow's roster is now exactly the KoN faction doc's: Oaven (T1),
# Stone-Faced Serpent (T2), Spawner (T3), The Forbidden (T4), plus evolved forms.
# Serpent and Spawner stay on the other two classes as well rather than being
# stripped from them -- per-class exclusivity (design doc s16) is a later balance
# pass to be made once Evangalion and Hellfire Baby have roster docs of their own.
const CLASS_UNIT_ROSTERS := {
	"bad_kon_willow": [
		&"oaven_spear", &"oaven_jumper",
		&"mangler", &"winged_mangler",
		&"stone_face_serpent",
		&"spawner", &"winged_spawner", &"spawner_drone",
		&"the_forbidden",
		# Not spliced -- conscripted. Kon can field the Steel Force only after
		# studying it (BuildSystem.RECRUITMENT_ORDER), so these being on the
		# roster means "he could learn to", not "he can".
		&"poorper", &"steel_knight", &"proper_blimp", &"mounted_knight",
	],
	"hellfire_baby": [&"terrible_thing", &"gripper", &"spawner", &"winged_spawner", &"spawner_drone"],
	"evangalion": [&"horror", &"hunter", &"stone_face_serpent"],
}

# Which tier gate each production unit sits behind. Tier 1 is available from the
# first minute; tier 2 and 3 are unlocked through Observer Vault research or map
# discoveries (BuildSystem.unlocked_tier); tier 4 is not trained at all, it is
# unleashed as a one-off from the Observation Tower.
const TIER_1 := 1
const MAX_TRAINABLE_TIER := 3

# --- Evolution growth ------------------------------------------------------
# RTSUnit._evolve() does not just swap to the evolved archetype -- it then
# applies these multipliers ON TOP of that archetype's catalog stats. They live
# here rather than in rts_unit.gd so the unit card can show what a player will
# actually field. Before 2026-08-31 the card read the raw catalog entry and
# understated every evolved form by ~24% HP and ~15% damage.
const EVOLUTION_HP_BASE_MULTIPLIER := 1.18
const EVOLUTION_HP_LEVEL_MULTIPLIER := 0.03
const EVOLUTION_DAMAGE_MULTIPLIER := 1.15
# The level an evolved form is at the moment it is first reached (units start at
# evolution_level 1 and _evolve() increments before applying the multiplier).
const FIRST_EVOLVED_LEVEL := 2

static func evolution_hp_multiplier(level: int) -> float:
	return EVOLUTION_HP_BASE_MULTIPLIER + float(level) * EVOLUTION_HP_LEVEL_MULTIPLIER

# The evolution chain a unit belongs to (horror -> hunter are both &"horror").
# Falls back to the archetype so units without a declared family still match
# themselves.
# --- Intelligence and aggro range (Master Design Doc section 38) ------------
# Intelligence is how far a unit obeys the player at all:
#   1  Feral   -- set behaviour only. Player orders are refused outright.
#   2  Leashed -- takes move orders, but only while no enemy is inside its aggro
#                 range. The moment something comes into range it drops the
#                 order and reverts to its set behaviour.
#   3  Bound   -- fully micromanageable. Every order, any time.
# It is a runtime stat, not a constant: Observer Vault research raises it, and
# RTSUnit re-reads it, so a unit's obedience can improve over a run.
const INTELLIGENCE_FERAL := 1
const INTELLIGENCE_LEASHED := 2
const INTELLIGENCE_BOUND := 3
const DEFAULT_INTELLIGENCE := INTELLIGENCE_BOUND

# TEMPORARILY OFF while the buildings, pathing and the Steel Force are being
# tested. A mechanic whose whole job is to refuse orders makes every other bug
# ambiguous: a unit that will not walk somewhere might be a broken lattice, or
# might be a Feral unit doing exactly what it was told to do.
#
# The switch lives HERE, on the one function every consumer reads, rather than
# in each of them. With it false every unit is Bound, so accepts_player_order()
# always says yes, _update_autonomy_override() returns early, and the Observer
# Command research finds nothing left to raise -- the mechanic disables itself
# by arithmetic instead of by a flag threaded through six files. The UI hides
# its readouts off the same constant. Set it back to true to restore section 38.
const INTELLIGENCE_ENABLED := false

# How much work a unit does for a building it is stationed inside, per unit.
#
# Authored on the archetype rather than listed in the effect script, because
# "an Oaven can crew a building" is a fact about Oavens: the roster doc has them
# as the faction's hands, they are the tier-1 unit you always have, and giving
# an idle one a job is the point. Anything without this key contributes nothing,
# so a Horror parked in the lab is just a Horror standing in a lab.
static func garrison_work_of(archetype: StringName) -> float:
	return float(DEFINITIONS.get(archetype, {}).get("garrison_work", 0.0))

static func intelligence_of(archetype: StringName) -> int:
	if not INTELLIGENCE_ENABLED:
		return INTELLIGENCE_BOUND
	return int(DEFINITIONS.get(archetype, {}).get("intelligence", DEFAULT_INTELLIGENCE))

# The authored value, ignoring the off switch. Only the smoke test and anything
# restoring the mechanic should need this; gameplay reads intelligence_of().
static func authored_intelligence_of(archetype: StringName) -> int:
	return int(DEFINITIONS.get(archetype, {}).get("intelligence", DEFAULT_INTELLIGENCE))

static func intelligence_label(level: int) -> String:
	match level:
		INTELLIGENCE_FERAL:
			return "Feral"
		INTELLIGENCE_LEASHED:
			return "Leashed"
		INTELLIGENCE_BOUND:
			return "Bound"
	return "Unknown"

static func intelligence_description(level: int, aggro_cells: int) -> String:
	match level:
		INTELLIGENCE_FERAL:
			return "Ignores orders entirely. Fights its own way."
		INTELLIGENCE_LEASHED:
			return "Takes move orders only while no enemy is within %s cells. Engages on its own after that." % aggro_cells
		INTELLIGENCE_BOUND:
			return "Obeys every order, at any time."
	return ""

# How close an enemy must be before the unit engages on its own. Defaults to a
# little beyond its own reach so a melee unit does not stand still while
# something hits it from just outside contact. Authored per unit where the
# design wants a deliberately short leash or a long watch.
static func aggro_range_cells(archetype: StringName) -> int:
	var definition: Dictionary = DEFINITIONS.get(archetype, {})
	if definition.has("aggro_range_cells"):
		return int(definition["aggro_range_cells"])
	return maxi(4, int(round(float(definition.get("attack_range_cells", 1)) * 1.5)))

static func family_of(archetype: StringName) -> StringName:
	return StringName(DEFINITIONS.get(archetype, {}).get("unit_family", archetype))

static func is_evolved_form(archetype: StringName) -> bool:
	return StringName(DEFINITIONS.get(archetype, {}).get("form", &"")) == &"evolved"

# Max HP as actually fielded. For an evolved form that is the catalog value with
# the first-evolution growth multiplier applied; for everything else it is the
# catalog value unchanged.
static func fielded_max_hp(archetype: StringName) -> int:
	var base := max_hp(archetype)
	if not is_evolved_form(archetype):
		return base
	return int(float(base) * evolution_hp_multiplier(FIRST_EVOLVED_LEVEL))

static func fielded_attack_damage(archetype: StringName) -> int:
	var base := attack_damage(archetype)
	if not is_evolved_form(archetype):
		return base
	return int(float(base) * EVOLUTION_DAMAGE_MULTIPLIER)

# Bio refunded when a unit is salvaged. Single source for both the live
# RTSUnit.salvage_value() and the unit card, which used to read a "bio_value"
# catalog key that does not exist on any archetype and therefore always
# displayed 0.
static func salvage_value_for(archetype: StringName, unit_max_health: int = -1) -> int:
	var health_basis := unit_max_health if unit_max_health >= 0 else fielded_max_hp(archetype)
	return int(float(cost_bio(archetype)) * 0.6) + int(float(health_basis) * 0.12)

# Which faction a unit belongs to. Kon's own creations declare none, so anything
# that DOES name one is foreign -- something recruited rather than spliced, and
# gated by its own research instead of by Kon's hybrid tiers.
# A unit you actually field: one that can be trained, and that fights for you.
#
# This is what separates a roster from a list of archetypes. It excludes the
# EVOLVED forms (oaven_jumper, winged_mangler, winged_spawner have no train time
# -- they are what a unit becomes, and in a fight they appear by evolving, which
# is the behaviour worth watching rather than one to fake by spawning them), the
# summoned ones (spawner_drone comes out of a Spawner), and The Forbidden, which
# is uncontrollable and attacks everyone -- dropping that into a measured fight
# would make the measurement about it.
static func is_fieldable_unit(archetype: StringName) -> bool:
	var definition: Dictionary = DEFINITIONS.get(archetype, {})
	if definition.is_empty():
		return false
	if bool(definition.get("uncontrollable", false)):
		return false
	return float(definition.get("train_time_seconds", 0.0)) > 0.0

# Every unit a wizard class can field, in tier order.
static func fieldable_units_for_class(wizard_class_id: String) -> Array[StringName]:
	var roster: Array[StringName] = []
	for archetype in CLASS_UNIT_ROSTERS.get(wizard_class_id, []):
		if is_fieldable_unit(archetype) and not is_foreign_recruit(archetype):
			roster.append(archetype)
	roster.sort_custom(func(a: StringName, b: StringName) -> bool:
		return tier_of(a) < tier_of(b))
	return roster

# Every unit a faction fields, in tier order.
static func fieldable_units_for_faction(faction: StringName) -> Array[StringName]:
	var roster: Array[StringName] = []
	for archetype in DEFINITIONS:
		if faction_of(archetype) == faction and is_fieldable_unit(archetype):
			roster.append(StringName(archetype))
	roster.sort_custom(func(a: StringName, b: StringName) -> bool:
		return tier_of(a) < tier_of(b))
	return roster

static func faction_of(archetype: StringName) -> StringName:
	return StringName(DEFINITIONS.get(archetype, {}).get("faction", &""))

static func is_foreign_recruit(archetype: StringName) -> bool:
	var faction := faction_of(archetype)
	return faction != &"" and faction != &"kon"

static func tier_of(archetype: StringName) -> int:
	return int(DEFINITIONS.get(archetype, {}).get("tier", TIER_1))

static func kon_theme(archetype: StringName) -> StringName:
	return StringName(DEFINITIONS.get(archetype, {}).get("kon_theme", &"evolution"))

static func card_portrait_path(archetype: StringName) -> String:
	return str(DEFINITIONS.get(archetype, {}).get("card_portrait", ""))

static func is_uncontrollable(archetype: StringName) -> bool:
	return bool(DEFINITIONS.get(archetype, {}).get("uncontrollable", false))

static func weapon_modes(archetype: StringName) -> Dictionary:
	return DEFINITIONS.get(archetype, {}).get("weapon_modes", {})

static func is_unit_allowed_for_class(archetype: StringName, wizard_class_id: String) -> bool:
	var roster: Array = CLASS_UNIT_ROSTERS.get(wizard_class_id, [])
	return roster.is_empty() or roster.has(archetype)

static func get_definition(archetype: StringName) -> Dictionary:
	return DEFINITIONS.get(archetype, {})

static func max_hp(archetype: StringName) -> int:
	return int(DEFINITIONS.get(archetype, {}).get("max_hp", 40))

static func attack_damage(archetype: StringName) -> int:
	return int(DEFINITIONS.get(archetype, {}).get("attack_damage", 0))

static func attack_range_cells(archetype: StringName) -> int:
	return int(DEFINITIONS.get(archetype, {}).get("attack_range_cells", 0))

static func cost_bio(archetype: StringName) -> int:
	return int(DEFINITIONS.get(archetype, {}).get("cost_bio", 0))

static func train_time(archetype: StringName) -> float:
	return float(DEFINITIONS.get(archetype, {}).get("train_time_seconds", 0.0))
