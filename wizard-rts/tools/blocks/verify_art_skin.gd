extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var library := BlockStructureLibrary.load_default()
	for id: StringName in [&"kons_arcane_citadel_01", &"kons_observation_wizard_tower_01"]:
		# This regression protects the full-size design masters and their skins.
		# Runtime compact skins have their own quarter-scale acceptance suite.
		var definition := library.authored_definition(id)
		assert(definition != null)
		if id == &"kons_arcane_citadel_01":
			var leaves: Array = definition.gate_cells[&"main_south_gate_open"]
			assert(leaves.has(Vector3i(44,2,3)) and leaves.has(Vector3i(44,2,15)),"Shared gate key lost a leaf")
		var before := var_to_bytes([definition.solid_cells, definition.nav_cells, definition.links, definition.gate_cells, definition.open_cells])
		var builder := BlockStructureBuilder.new()
		root.add_child(builder)
		builder.build(definition)
		assert(before == var_to_bytes([definition.solid_cells, definition.nav_cells, definition.links, definition.gate_cells, definition.open_cells]), "Art modified authored data")
		assert(builder.get_node("ArchitecturalSkin").multimesh.instance_count > 0)
		assert(builder.get_node("WindowFrames").multimesh.instance_count > 0)
		var gothic := builder.get_node("GothicDetails")
		assert(gothic.get_node("BurgundyLeaves").multimesh.instance_count > 0)
		assert(gothic.get_node("CarvedArches").multimesh.instance_count > 0)
		assert(gothic.has_node("ObservationDome"))
		var first_vine_transform: Transform3D = gothic.get_node("VineStems").multimesh.get_instance_transform(0)
		var repeated := BlockGothicDetails.new().build(definition)
		assert(repeated.get_node("VineStems").multimesh.get_instance_transform(0).is_equal_approx(first_vine_transform),"Vines changed between rebuilds")
		repeated.free()
		for key in definition.gate_cells:
			builder.set_gate_open(key, true)
			assert(not builder.get_node("Gate_%s" % key).visible)
			builder.set_gate_open(key, false)
			assert(builder.get_node("Gate_%s" % key).visible)
		builder.set_blocks_visible(false)
		assert(not builder.get_node("ArchitecturalSkin").visible)
		assert(not builder.get_node("WindowFrames").visible)
		assert(not gothic.visible)
		print("[ArtSkin] %s: authored data identical; gate visibility and dressing visibility pass" % id)
		builder.free()
	quit()
