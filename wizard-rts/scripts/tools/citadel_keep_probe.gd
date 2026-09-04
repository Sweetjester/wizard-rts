extends SceneTree
const CITADEL := &"kons_arcane_citadel_01"
func _initialize() -> void:
	var library := BlockStructureLibrary.load_default()
	var d := library.get_definition(CITADEL)
	var nav := library.navigation_for(CITADEL)
	for k in library.gate_defaults_for(CITADEL):
		nav.gate_states[k] = true
	# Which levels does keep_upper_nav actually occupy, and which are reachable?
	var levels := {}
	for cell in d.nav_cells:
		if d.nav_cells[cell].get("region_id", &"") == &"keep_upper_nav":
			levels[cell.y] = int(levels.get(cell.y, 0)) + 1
	print("keep_upper_nav levels: ", levels)
	var reached := nav.reachable_from(Vector3i(48, 2, 2), &"infantry")
	for level in levels:
		var count := 0
		for cell in d.nav_cells:
			if cell.y == level and d.nav_cells[cell].get("region_id", &"") == &"keep_upper_nav" and reached.has(cell):
				count += 1
		print("  level %d: %d cells, %d reachable" % [level, levels[level], count])
	print("links touching keep levels:")
	for l in d.links:
		if l["from"].y >= 5 and (l["from"].x > 30 and l["from"].x < 70):
			print("  %-28s %s -> %s" % [l["id"], l["from"], l["to"]])
	quit(0)
