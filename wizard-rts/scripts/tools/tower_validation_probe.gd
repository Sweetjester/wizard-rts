extends SceneTree

# Runs Kon's Observation Tower against the PASS/FAIL cases the spec ships with
# itself, and reports where the authored data and the traversal engine disagree.

const TOWER := &"kons_observation_wizard_tower_01"

func _initialize() -> void:
	var library := BlockStructureLibrary.load_default()
	var definition := library.get_definition(TOWER)
	if definition == null:
		push_error("Tower not found -- run tools/blocks/convert_structures.py")
		quit(1)
		return
	print("dims=%s solid=%d nav=%d links=%d sockets=%d" % [
		definition.dimensions, definition.solid_cells.size(),
		definition.nav_cells.size(), definition.links.size(), definition.sockets.size()])
	print("gate defaults: ", library.gate_defaults_for(TOWER))

	var regions := {}
	for cell in definition.nav_cells:
		var rid = definition.nav_cells[cell].get("region_id", &"?")
		regions[rid] = int(regions.get(rid, 0)) + 1
	print("nav regions: ", regions)

	print("\n--- link endpoints ---")
	for link in definition.links:
		var f := definition.nav_at(link["from"])
		var t := definition.nav_at(link["to"])
		print("  %-22s %-11s %s->%s  from=%s to=%s" % [link["id"], link["type"], link["from"], link["to"],
			f.get("region_id", "NONE") if not f.is_empty() else "NONE",
			t.get("region_id", "NONE") if not t.is_empty() else "NONE"])

	print("\n--- the spec's own validation_tests ---")
	for test in library.validation_tests_for(TOWER):
		var nav := library.navigation_for(TOWER)
		nav.gate_states = library.gate_defaults_for(TOWER).duplicate()
		for key in test.get("state", {}):
			nav.gate_states[key] = bool(test["state"][key])
		var start := Vector3i(int(test["start"][0]), int(test["start"][1]), int(test["start"][2]))
		var goal := Vector3i(int(test["destination"][0]), int(test["destination"][1]), int(test["destination"][2]))
		var unit_class := StringName(test["unit_class"])
		var reached: bool = nav.can_reach(start, goal, unit_class)
		var expected: bool = str(test["expected"]) == "PASS"
		print("  %-24s %-9s %s -> %s  expected=%s actual=%s  %s" % [
			test["id"], unit_class, start, goal, test["expected"],
			"PASS" if reached else "FAIL",
			"ok" if reached == expected else "*** MISMATCH ***"])
	quit(0)
