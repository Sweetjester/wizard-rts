extends SceneTree
const CITADEL := &"kons_arcane_citadel_01"
func _initialize() -> void:
	var library := BlockStructureLibrary.load_default()
	var d := library.get_definition(CITADEL)
	if d == null:
		push_error("citadel missing")
		quit(1)
		return
	var nav := library.navigation_for(CITADEL)
	nav.gate_states = library.gate_defaults_for(CITADEL).duplicate()
	print("dims=%s solid=%d nav=%d links=%d sockets=%d gates=%s" % [
		d.dimensions, d.solid_cells.size(), d.nav_cells.size(), d.links.size(), d.sockets.size(), nav.gate_states])
	var regions := {}
	for cell in d.nav_cells:
		var rid = d.nav_cells[cell].get("region_id", &"?")
		regions[rid] = int(regions.get(rid, 0)) + 1
	print("\nnav regions:")
	var keys: Array = regions.keys()
	keys.sort()
	for k in keys:
		print("  %-32s %d cells" % [k, regions[k]])
	print("\nlinks:")
	for l in d.links:
		print("  %-34s %-11s %s -> %s  allowed=%s" % [l["id"], l["type"], l["from"], l["to"], l["allowed"]])
	print("\nreachability for infantry from the main road, gates OPEN:")
	for key in nav.gate_states:
		nav.gate_states[key] = true
	var start := Vector3i(48, 2, 2)
	print("  start standable: ", nav.can_occupy(start, &"infantry"))
	for k in keys:
		print("  %-32s %s" % [k, "reachable" if nav.can_reach_region(start, k, &"infantry") else "UNREACHABLE"])
	quit(0)
