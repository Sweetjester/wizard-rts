extends SceneTree
const TOWER := &"kons_observation_wizard_tower_01"
func _initialize() -> void:
	var library := BlockStructureLibrary.load_default()
	var definition := library.get_definition(TOWER)
	var nav := library.navigation_for(TOWER)
	nav.gate_states = {"main_gate_open": true}
	var start := Vector3i(8, 0, 0)
	print("reachability for infantry from ", start, " with the gate OPEN:")
	var regions: Array = []
	for cell in definition.nav_cells:
		var rid = definition.nav_cells[cell].get("region_id", &"?")
		if not regions.has(rid):
			regions.append(rid)
	regions.sort()
	for rid in regions:
		print("  %-18s %s" % [rid, "reachable" if nav.can_reach_region(start, rid, &"infantry") else "UNREACHABLE"])
	print("\nheavy: can it stand in gate_entry (8,1,3)? ", nav.can_occupy(Vector3i(8, 1, 3), &"heavy"))
	print("heavy: gate_entry allowed list = ", definition.nav_at(Vector3i(8, 1, 3)).get("allowed"))
	quit(0)
