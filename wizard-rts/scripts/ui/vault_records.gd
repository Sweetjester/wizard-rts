extends RefCounted

static func entries(section: String, build: Node, world: Node, session: Node) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var roster: Array = UnitCatalog.CLASS_UNIT_ROSTERS.get(str(session.wizard_class_id), [])
	var ids: Array = roster.duplicate()
	if section == "Felled":
		ids = session.felled_specimens.keys()
	else:
		ids.push_front(&"life_wizard" if session.wizard_class_id == "bad_kon_willow" else (&"fire_wizard" if session.wizard_class_id == "hellfire_baby" else &"evangalion_wizard"))
	for id in ids:
		if section != "Felled" and parent_of(StringName(id)) != &"":
			continue
		var record := record_for(StringName(id), section, build, world, session)
		if not record.is_empty():
			records.append(record)
	return records

static func parent_of(id: StringName) -> StringName:
	# Summons live with their creator, just as evolutions live with their base form.
	if id == &"spawner_drone": return &"spawner"
	for candidate in UnitCatalog.DEFINITIONS:
		if StringName(UnitCatalog.DEFINITIONS[candidate].get("evolves_to", &"")) == id:
			return StringName(candidate)
	return &""

static func family_ids(id: StringName) -> Array[StringName]:
	var root := id
	var visited: Array[StringName] = []
	while parent_of(root) != &"" and not visited.has(root):
		visited.append(root)
		root = parent_of(root)
	var result: Array[StringName] = []
	var current := root
	while current != &"" and not result.has(current):
		result.append(current)
		current = StringName(UnitCatalog.get_definition(current).get("evolves_to", &""))
	if root == &"spawner": result.append(&"spawner_drone")
	return result

static func record_for(id: StringName, section: String, build: Node, world: Node, session: Node) -> Dictionary:
	var enemy := section == "Felled"
	if enemy and not session.felled_specimens.has(id):
		return {}
	var tier := UnitCatalog.tier_of(id)
	var living: Array[WeakRef] = []
	if not enemy and is_instance_valid(world):
		for unit in world.all_units():
			if unit is RTSUnit and is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.is_alive() and unit.owner_player_id == 1 and unit.unit_archetype == id:
				living.append(weakref(unit))
	var unlocked := int(build.unlocked_tier(1)) if is_instance_valid(build) else 1
	if not enemy and tier > unlocked and (tier <= 3 or living.is_empty()):
		# No portrait, name, blurb, lineage or stats ever reach the sealed view.
		return {"id": id, "sealed": true, "tier": tier, "name": "Sealed specimen",
			"requirement": "Research Tier %d Hybrids\nin the Vault" % tier if tier <= 3 else "Unleash at the\nObservation Tower"}
	var ledger := RosterLedger.entry_for(id, null if enemy else build, null if enemy else world)
	var d := UnitCatalog.get_definition(id)
	var r := {"id": id, "sealed": false, "tier": tier, "name": str(d.get("display_name", id)),
		"portrait": UnitCatalog.card_portrait_path(id), "ledger": ledger, "enemy": enemy,
		"role": str(d.get("role", "")), "blurb": str(d.get("card_blurb", "")),
		"stats": ledger.get("live", {}).duplicate(), "base": ledger.get("base", {}),
		"template_stats": ledger.get("live", {}).duplicate(), "stat_labels": {},
		"changes": ledger.get("changes", []).duplicate(), "instances": []}
	if enemy:
		r["changes"] = [{"label": "Field record", "effect": "%d felled this run. Catalog baseline; enemy variants may differ." % int(session.felled_specimens[id])}]
	else:
		r["instances"] = living
	if not r.instances.is_empty():
		for key in ["max_health", "attack_damage", "armor"]:
			var values: Array[float] = []
			for ref in r.instances:
				values.append(float(specimen_stats(ref).get(key, 0)))
			var low: float = values.min()
			var high: float = values.max()
			r.stats[key] = low
			r.stat_labels[key] = str(int(low)) if low == high else "%d-%d" % [low, high]
	return r

static func specimen_stats(ref: WeakRef) -> Dictionary:
	var unit = ref.get_ref()
	if not is_instance_valid(unit) or not unit.is_alive():
		return {}
	return {"max_health": unit.max_health, "health": unit.health, "attack_damage": unit.attack_damage,
		"armor": unit.armor, "magic_armor": unit.magic_armor,
		"attack_range_cells": unit.attack_range / 64.0, "attack_speed_seconds": unit._current_attack_cooldown(),
		"move_speed": unit._current_move_speed(), "intelligence": unit.intelligence}
