extends SceneTree

# Focused probe for the pack's suggested first test case, fortress_gatehouse_01,
# and its stated expectations A-G. Run before writing assertions so the test
# describes the spec rather than my assumptions about it.

func _initialize() -> void:
	var library := BlockStructureLibrary.load_default()
	var definition := library.get_definition(&"fortress_gatehouse_01")
	var nav := library.navigation_for(&"fortress_gatehouse_01")
	nav.gate_states = {"gate_open": true}

	print("--- link endpoints: are they standable? ---")
	for link in definition.links:
		var from_nav := definition.nav_at(link["from"])
		var to_nav := definition.nav_at(link["to"])
		print("%s  from %s nav=%s  to %s nav=%s" % [
			link["id"], link["from"],
			from_nav.get("region_id", "NONE") if not from_nav.is_empty() else "NONE",
			link["to"],
			to_nav.get("region_id", "NONE") if not to_nav.is_empty() else "NONE"])

	print("\n--- gate passage extent ---")
	var passage := nav.region_cells(&"gate_passage")
	print("cells: ", passage)

	print("\n--- reachability from the gate passage south end, gate OPEN ---")
	var south := Vector3i(4, 0, 0)
	for unit_class in [&"infantry", &"heavy", &"climber", &"flying"]:
		var reached := nav.reachable_from(south, unit_class)
		print("%s: reached %d cells | wall_walk=%s | north end (4,0,5)=%s" % [
			unit_class, reached.size(),
			nav.can_reach_region(south, &"wall_walk", unit_class),
			reached.has(Vector3i(4, 0, 5))])

	print("\n--- gate CLOSED ---")
	nav.gate_states = {"gate_open": false}
	for unit_class in [&"infantry", &"heavy", &"flying"]:
		print("%s: can stand in the passage = %s" % [
			unit_class, nav.can_occupy(Vector3i(4, 0, 2), unit_class)])

	print("\n--- titan_skull_keep_01 climb points (test E) ---")
	var keep_nav := library.navigation_for(&"titan_skull_keep_01")
	var keep := library.get_definition(&"titan_skull_keep_01")
	keep_nav.gate_states = {"gate_open": true}
	for link in keep.links:
		if link["type"] == &"CLIMB_POINT":
			var from_nav := keep.nav_at(link["from"])
			var to_nav := keep.nav_at(link["to"])
			print("%s from %s nav=%s -> to %s nav=%s" % [
				link["id"], link["from"],
				from_nav.get("region_id", "NONE") if not from_nav.is_empty() else "NONE",
				link["to"],
				to_nav.get("region_id", "NONE") if not to_nav.is_empty() else "NONE"])
	quit(0)
