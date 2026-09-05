extends SceneTree

var failures := 0
var limit: AABB

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	var library := BlockStructureLibrary.load_default()
	var id := &"kons_observer_vault_01"
	var definition := library.get_definition(id)
	check(definition.dimensions == Vector3i(9,5,7), "Vault dimensions")
	check(library.get_definition(&"kons_splicing_laboratory_01").dimensions == definition.dimensions, "Lab size match")
	check(library.get_definition(&"kons_observation_wizard_tower_01").dimensions == Vector3i(18,32,18), "Tower preserved")
	var navigation := library.navigation_for(id)
	for test in library.validation_tests_for(id):
		navigation.gate_states = test.get("state", {})
		var a: Array = test["start"]
		var b: Array = test["destination"]
		var reached := navigation.can_reach(Vector3i(a[0],a[1],a[2]),Vector3i(b[0],b[1],b[2]),StringName(test["unit_class"]))
		check(reached == (test["expected"] == "PASS"), "Route: " + test["id"])
		print("[VaultRoute] ", test["id"], " reached=", reached)
	var before := var_to_bytes([definition.nav_cells,definition.solid_cells,definition.links,definition.gate_cells])
	for rotation in 4:
		var builder := BlockStructureBuilder.new()
		root.add_child(builder)
		builder.build(definition.rotated(rotation))
		limit = AABB(Vector3.ONE * -0.02, Vector3(9.04,5.04,7.04) if rotation%2 == 0 else Vector3(7.04,5.04,9.04))
		for opened in [true,false]:
			builder.set_gate_open(&"vault_entry_open", opened)
			var door := builder.get_node("GothicDetails/VaultGate") as Node3D
			check(door.visible and is_equal_approx(door.rotation.y, PI*0.5 if opened else 0.0), "Door state")
			_check_bounds(builder.get_node("GothicDetails"),Transform3D.IDENTITY)
		builder.set_gate_open(&"vault_service_open", false)
		check(builder.get_node("GothicDetails/ServiceGate").visible, "Service closed")
		builder.set_gate_open(&"vault_service_open", true)
		check(not builder.get_node("GothicDetails/ServiceGate").visible, "Service open")
		builder.queue_free()
	check(before == var_to_bytes([definition.nav_cells,definition.solid_cells,definition.links,definition.gate_cells]), "Visuals changed gameplay data")
	await process_frame
	var economy := EconomyManager.new()
	economy.name = "EconomyManager"
	root.add_child(economy)
	economy.set_process(false)
	var system := BuildSystem.new()
	root.add_child(system)
	system.set_process(false)
	check(not system.research_upgrade(1,&"tier_two_hybrids"), "Research requires vault")
	system.structures.append({"player_id":1,"archetype":&"terrible_vault","complete":false})
	check(not system.research_upgrade(1,&"tier_two_hybrids"), "Research requires completion")
	system.structures[0]["complete"] = true
	check(not system.research_upgrade(1,&"tier_three_hybrids"), "Tier prerequisite")
	var bio := int(economy.get_resources(1).get(&"bio",0))
	check(system.research_upgrade(1,&"tier_two_hybrids"), "Vault enables research")
	check(int(economy.get_resources(1).get(&"bio",0)) == bio-200, "Research charges Bio")
	check(not system.research_upgrade(1,&"tier_two_hybrids"), "No duplicate unlock")
	check(system.research_upgrade(1,&"tier_three_hybrids"), "Tier 3 research")
	system.queue_free()
	economy.queue_free()
	await process_frame
	print("[ObserverVault] ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)

func _check_bounds(node: Node3D, parent: Transform3D) -> void:
	var transform := parent * node.transform
	if node is MeshInstance3D and node.mesh != null:
		check(limit.encloses(transform * node.mesh.get_aabb()), "Mesh out of bounds: " + str(transform * node.mesh.get_aabb()))
	if node is MultiMeshInstance3D:
		check(limit.encloses(transform * (node.get_meta("authored_bounds") as AABB)), "Batch out of bounds: " + str(transform * (node.get_meta("authored_bounds") as AABB)))
	for child in node.get_children():
		if child is Node3D: _check_bounds(child,transform)
