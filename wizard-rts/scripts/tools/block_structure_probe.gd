extends SceneTree

# Diagnostic dump for the authored block structures. Not part of the suite --
# this exists to read what the DATA says before assertions are written against
# it, so the tests describe the spec rather than my assumptions about it.

func _initialize() -> void:
	var library := BlockStructureLibrary.load_default()
	print("structures: ", library.structure_ids())
	if not library.schema_problems.is_empty():
		print("\nschema problems reported by the converter:")
		for problem in library.schema_problems:
			print("  - ", problem)

	for structure_id in library.structure_ids():
		var definition := library.get_definition(structure_id)
		var nav := library.navigation_for(structure_id)
		print("\n=== %s (%s) dims=%s" % [structure_id, definition.display_name, definition.dimensions])
		print("  solid=%d nav=%d links=%d sockets=%d" % [
			definition.solid_cells.size(), definition.nav_cells.size(),
			definition.links.size(), definition.sockets.size()])
		var regions := {}
		for cell in definition.nav_cells:
			var region_id = definition.nav_cells[cell].get("region_id", &"?")
			regions[region_id] = int(regions.get(region_id, 0)) + 1
		print("  regions: ", regions)
		for link in definition.links:
			print("    link %s %s %s -> %s allowed=%s" % [
				link["id"], link["type"], link["from"], link["to"], link["allowed"]])
		# Where each class can stand at all, and how far it gets from the
		# structure's lowest, most southerly nav cell.
		nav.gate_states = {"gate_open": true}
		for unit_class in [&"infantry", &"heavy", &"climber", &"siege"]:
			var standable := 0
			for cell in definition.nav_cells:
				if nav.can_occupy(cell, unit_class):
					standable += 1
			print("    %s: can stand in %d cells" % [unit_class, standable])
	quit(0)
