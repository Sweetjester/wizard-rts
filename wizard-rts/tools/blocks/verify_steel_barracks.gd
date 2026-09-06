extends SceneTree
var failures := 0

class FlatTerrain extends Node:
	var MAP_W := 48
	var MAP_H := 48
	func is_walkable_cell(c: Vector2i) -> bool: return c.x>=0 and c.y>=0 and c.x<MAP_W and c.y<MAP_H
	func get_height(_c: Vector2i) -> int: return 2
	func is_cliff_edge_cell(_c: Vector2i) -> bool: return false
	func cell_to_world(c: Vector2i) -> Vector2: return Vector2(c)*64+Vector2.ONE*32
	func world_to_cell(p: Vector2) -> Vector2i: return Vector2i((p/64).floor())

func rotated_anchor(definition: BlockStructureDefinition, value: Array, turns: int, footprint: Vector2i) -> Vector3i:
	var p := definition._turn_cell(Vector3i(value[0],value[1],value[2]),turns)
	match turns:
		1: p.x-=footprint.y-1
		2: p-=Vector3i(footprint.x-1,0,footprint.y-1)
		3: p.z-=footprint.x-1
	return p+Vector3i(8,2,8)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("[SteelBarracks] ",label," ",ok)
	if not ok: failures+=1; push_error(label)

func run() -> void:
	var library := BlockStructureLibrary.load_default()
	var id := &"steel_force_barracks_farm_01"
	var definition := library.get_definition(id)
	check(definition!=null,"Definition compiled")
	if definition==null: quit(1); return
	var lab := library.get_definition(&"kons_splicing_laboratory_01")
	check(definition.dimensions==Vector3i(lab.dimensions.x,lab.dimensions.y,lab.dimensions.z*2),"Exactly two lab footprints")
	var nav := library.navigation_for(id)
	for test in library.validation_tests_for(id):
		nav.gate_states=test.get("state",{})
		var a: Array = test.start
		var b: Array = test.destination
		check(nav.can_reach(Vector3i(a[0],a[1],a[2]),Vector3i(b[0],b[1],b[2]),StringName(test.unit_class))==(test.expected=="PASS"),test.id)
	var before := var_to_bytes([definition.nav_cells,definition.solid_cells,definition.links,definition.gate_cells])
	var terrain := FlatTerrain.new()
	root.add_child(terrain)
	for rotation in 4:
		var world := BlockNavWorld.new(library.unit_classes)
		world.build_from_terrain(terrain)
		world.place_structure(definition,Vector2i(8,8),2,id,rotation)
		for test in library.validation_tests_for(id):
			world.gate_states=library.gate_defaults_for(id).duplicate()
			world.gate_states.merge(test.get("state",{}),true)
			var unit_class := StringName(test.unit_class)
			var footprint := world.rules.footprint_of(unit_class)
			var a := rotated_anchor(definition,test.start,rotation,footprint)
			var b := rotated_anchor(definition,test.destination,rotation,footprint)
			var route := world.find_path(Vector2i(a.x,a.z),a.y,Vector2i(b.x,b.z),b.y,unit_class)
			check((not route.is_empty())==(test.expected=="PASS"),"World route rotation "+str(rotation)+" "+test.id)
		var builder := BlockStructureBuilder.new()
		root.add_child(builder)
		builder.build(definition.rotated(rotation))
		check(builder.has_node("GothicDetails/Roof"),"Bespoke roof rotation "+str(rotation))
		var limit := AABB(Vector3(-.16,-.02,-.16),Vector3(9.32,5.2,14.32) if rotation%2==0 else Vector3(14.32,5.2,9.32))
		bounds(builder.get_node("GothicDetails"),Transform3D.IDENTITY,limit)
		for key in {"steel_farm_open":"FarmGate","steel_muster_open":"MusterGate","steel_service_open":"ServiceGate"}:
			var label: String = {"steel_farm_open":"FarmGate","steel_muster_open":"MusterGate","steel_service_open":"ServiceGate"}[key]
			for opened in [false,true]:
				builder.set_gate_open(StringName(key),opened)
				check(builder.get_node("GothicDetails/"+label).visible!=opened,"Gate "+key+" state "+str(opened))
		builder.set_interior_view(true)
		check(not builder.get_node("GothicDetails/Roof").visible,"Cutaway removes roof")
		builder.set_interior_view(false)
		check(builder.get_node("GothicDetails/Roof").visible,"Cutaway restores roof")
		builder.queue_free()
	check(before==var_to_bytes([definition.nav_cells,definition.solid_cells,definition.links,definition.gate_cells]),"Skin never changes navigation")
	terrain.queue_free()
	for file in ["masonry","slate","timber","details"]:
		var texture: Texture2D = load("res://assets/structures/steel_barracks_hd/"+file+".png")
		check(texture.get_width()>=1200 and texture.get_height()>=1200,"Native source retained: "+file)
		check(texture.get_image().has_mipmaps(),"Mipmaps imported: "+file)
	await process_frame
	print("[SteelBarracks] failures=",failures)
	quit(0 if failures==0 else 1)

func bounds(node: Node3D, parent: Transform3D, limit: AABB) -> void:
	var transform := parent*node.transform
	if node is MeshInstance3D and node.mesh!=null:
		if not limit.encloses(transform*node.mesh.get_aabb()): check(false,"Mesh outside compound: "+str(transform*node.mesh.get_aabb()))
	if node is MultiMeshInstance3D:
		if not limit.encloses(transform*(node.get_meta("authored_bounds") as AABB)): check(false,"Batch outside compound: "+str(transform*(node.get_meta("authored_bounds") as AABB)))
	for child in node.get_children():
		if child is Node3D: bounds(child,transform,limit)
