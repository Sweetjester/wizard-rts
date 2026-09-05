extends SceneTree

var bounds_failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var library:=BlockStructureLibrary.load_default()
	var tower := library.get_definition(&"kons_observation_wizard_tower_01")
	assert(not tower.runtime_profile and tower.dimensions == Vector3i(18,32,18))
	assert(var_to_bytes(tower.source_data) == var_to_bytes(library.authored_definition(tower.id).source_data))
	var id:=&"kons_splicing_laboratory_01"
	var definition:=library.get_definition(id)
	if definition==null:
		push_error("Laboratory missing from converted structure library")
		quit(1)
		return
	var navigation:=library.navigation_for(id)
	for test in library.validation_tests_for(id):
		navigation.gate_states=test.get("state",{})
		var a: Array=test["start"]
		var b: Array=test["destination"]
		var reached:=navigation.can_reach(Vector3i(a[0],a[1],a[2]),Vector3i(b[0],b[1],b[2]),StringName(test["unit_class"]))
		if reached!=(test["expected"]=="PASS"):
			push_error("Lab route failed: "+test["id"])
			quit(1)
			return
		print("[LabRoute] ",test["id"]," PASS")
	var before:=var_to_bytes([definition.nav_cells,definition.solid_cells,definition.links,definition.gate_cells])
	var builder:=BlockStructureBuilder.new()
	root.add_child(builder)
	builder.build(definition)
	if before!=var_to_bytes([definition.nav_cells,definition.solid_cells,definition.links,definition.gate_cells]):
		push_error("Laboratory skin changed authored gameplay")
		quit(1)
		return
	var visual: Node = builder
	assert(visual.get_node("GothicDetails").has_node("SplicingChamberGlassCanopy"))
	_check_bounds(visual.get_node("GothicDetails"),Transform3D.IDENTITY)
	for key in definition.gate_cells:
		builder.set_gate_open(key,true)
		assert(not builder._gate_meshes[key].visible)
		builder.set_gate_open(key,false)
		assert(builder._gate_meshes[key].visible)
	print("[SplicingLab] PASS: all authored routes, visual integrity, two independent gates")
	builder.queue_free()
	await process_frame
	quit(0 if bounds_failures == 0 else 1)

func _check_bounds(node: Node3D, parent: Transform3D) -> void:
	var transform := parent*node.transform
	if node is MeshInstance3D and node.mesh != null:
		_assert_box(transform*node.mesh.get_aabb())
	if node is MultiMeshInstance3D:
		# Dummy headless rendering does not retain MultiMesh GPU transforms.
		_assert_box(transform*(node.get_meta("authored_bounds") as AABB))
	for child in node.get_children():
		if child is Node3D: _check_bounds(child,transform)

func _assert_box(bounds: AABB) -> void:
	var limit := AABB(Vector3(-0.01,-0.01,-0.01),Vector3(9.02,5.02,7.02))
	if not limit.encloses(bounds):
		bounds_failures += 1
		push_error("Lab mesh exceeds authored 9x5x7 envelope: %s" % bounds)
