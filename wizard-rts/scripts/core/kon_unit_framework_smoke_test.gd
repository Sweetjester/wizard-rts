extends SceneTree

const REQUIRED_FIELDS := [
	"display_name",
	"max_hp",
	"armor",
	"magic_armor",
	"attack_damage",
	"attack_speed_seconds",
	"attack_type",
	"attack_range_cells",
	"actives",
	"passives",
	"animation_profile",
]

func _init() -> void:
	var ok := true
	for archetype in [&"life_wizard", &"terrible_thing", &"gripper", &"horror", &"hunter", &"apex", &"champion", &"spawner", &"winged_spawner", &"stone_face_serpent"]:
		ok = _check_unit(archetype) and ok
	ok = _check_evolution(&"terrible_thing", &"gripper") and ok
	ok = _check_evolution(&"horror", &"hunter") and ok
	ok = _check_evolution(&"apex", &"champion") and ok
	ok = _check_evolution(&"spawner", &"winged_spawner") and ok
	var barracks := UnitCatalog.get_definition(&"barracks")
	for produced in [&"terrible_thing", &"horror", &"apex", &"spawner", &"stone_face_serpent"]:
		if not barracks.get("production", []).has(produced):
			push_error("Barracks missing production unit %s" % str(produced))
			ok = false
	if not ok:
		quit(1)
		return
	print("[KonUnitFrameworkSmokeTest] Kon unit framework is coherent.")
	quit(0)

func _check_unit(archetype: StringName) -> bool:
	var definition := UnitCatalog.get_definition(archetype)
	if definition.is_empty():
		push_error("Missing unit definition: %s" % str(archetype))
		return false
	var ok := true
	for field in REQUIRED_FIELDS:
		if not definition.has(field):
			push_error("%s missing field %s" % [str(archetype), str(field)])
			ok = false
	var profile: Dictionary = definition.get("animation_profile", {})
	if int(profile.get("directions", 0)) != 8:
		push_error("%s must use 8 animation directions" % str(archetype))
		ok = false
	if profile.get("actions", []).is_empty():
		push_error("%s has no animation actions" % str(archetype))
		ok = false
	return ok

func _check_evolution(from_archetype: StringName, to_archetype: StringName) -> bool:
	var definition := UnitCatalog.get_definition(from_archetype)
	var actual := StringName(definition.get("evolves_to", &""))
	if actual != to_archetype:
		push_error("%s should evolve to %s, got %s" % [str(from_archetype), str(to_archetype), str(actual)])
		return false
	return true
