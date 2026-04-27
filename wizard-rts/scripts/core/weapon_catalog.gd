class_name WeaponCatalog
extends RefCounted

const WEAPONS := {
	&"life_wizard": {
		"kind": &"projectile",
		"damage": 13,
		"speed": 680.0,
		"color": Color("#7DDDE8"),
		"casts": 2,
		"lead_target": true,
	},
	&"fire_wizard": {
		"kind": &"projectile",
		"damage": 24,
		"speed": 780.0,
		"color": Color("#E85A5A"),
		"casts": 1,
		"lead_target": true,
	},
	&"evangalion_wizard": {
		"kind": &"projectile",
		"damage": 20,
		"speed": 760.0,
		"color": Color("#7DDDE8"),
		"casts": 1,
		"lead_target": true,
	},
	&"horror": {
		"kind": &"projectile",
		"damage": 10,
		"speed": 720.0,
		"color": Color("#7DDDE8"),
		"casts": 1,
	},
	&"spore_spitter": {
		"kind": &"projectile",
		"damage": 8,
		"speed": 520.0,
		"color": Color("#7BC47F"),
		"casts": 1,
	},
	&"bio_launcher": {
		"kind": &"artillery",
		"damage": 24,
		"speed": 420.0,
		"color": Color("#8B1A1F"),
		"aoe_radius": 92.0,
		"ground_attack": true,
	},
}

static func get_weapon(archetype: StringName) -> Dictionary:
	var weapon: Dictionary = WEAPONS.get(archetype, {}).duplicate(true)
	var unit: Dictionary = UnitCatalog.get_definition(archetype)
	if weapon.is_empty():
		weapon = {
			"kind": &"melee" if int(unit.get("attack_range_cells", 1)) <= 1 else &"projectile",
			"damage": int(unit.get("attack_damage", 1)),
			"speed": float(unit.get("projectile_speed", 620.0)),
			"color": Color("#D6C7AE"),
			"casts": 1,
		}
	else:
		weapon["damage"] = int(unit.get("attack_damage", weapon.get("damage", 1)))
		weapon["speed"] = float(unit.get("projectile_speed", weapon.get("speed", 620.0)))
	return weapon

static func uses_projectile(archetype: StringName) -> bool:
	return get_weapon(archetype).get("kind", &"melee") in [&"projectile", &"artillery"]
