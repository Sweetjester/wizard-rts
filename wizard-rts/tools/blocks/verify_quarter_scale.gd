extends SceneTree

const IDS := [&"kons_arcane_citadel_01", &"kons_splicing_laboratory_01"]
const SIZES := [Vector3i(24,12,24), Vector3i(9,5,7)]
var failures := 0
var checks := 0

class FlatTerrain extends Node:
	var MAP_W := 48
	var MAP_H := 48
	func is_walkable_cell(c: Vector2i) -> bool: return c.x>=0 and c.y>=0 and c.x<MAP_W and c.y<MAP_H
	func get_height(_c: Vector2i) -> int: return 2
	func is_cliff_edge_cell(_c: Vector2i) -> bool: return false
	func cell_to_world(c: Vector2i) -> Vector2: return Vector2(c)*64.0+Vector2.ONE*32.0
	func world_to_cell(p: Vector2) -> Vector2i: return Vector2i((p/64.0).floor())

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func cell(value: Array) -> Vector3i: return Vector3i(value[0],value[1],value[2])

func anchor(definition: BlockStructureDefinition, p: Vector3i, turns: int, footprint: Vector2i) -> Vector3i:
	var result := definition._turn_cell(p, turns)
	match turns:
		1: result.x -= footprint.y-1
		2:
			result.x -= footprint.x-1
			result.z -= footprint.y-1
		3: result.z -= footprint.x-1
	return result

func _run() -> void:
	var library := BlockStructureLibrary.load_default()
	var terrain := FlatTerrain.new()
	root.add_child(terrain)
	for index in IDS.size():
		var id: StringName = IDS[index]
		var definition := library.get_definition(id)
		check(definition.dimensions == SIZES[index], "%s runtime dimensions" % id)
		check(definition.runtime_profile, "%s must use explicit runtime profile" % id)
		check(library.authored_definition(id).dimensions != definition.dimensions, "%s master was preserved" % id)
		for p in definition.nav_cells:
			var gated: bool = definition.nav_at(p).get("type", &"") == &"GATE"
			check(not definition.is_solid(p) or gated, "%s nav inside solid at %s" % [id,p])
			check(definition.is_solid(p-Vector3i.UP), "%s unsupported floor at %s" % [id,p])
		for link in definition.links:
			check(definition.nav_cells.has(link.from) and definition.nav_cells.has(link.to), "%s dangling link %s" % [id,link.id])
		for turns in 4:
			var world := BlockNavWorld.new(library.unit_classes)
			world.build_from_terrain(terrain)
			world.place_structure(definition,Vector2i(8,8),2,id,turns)
			for test in library.validation_tests_for(id):
				world.gate_states = library.gate_defaults_for(id).duplicate()
				world.gate_states.merge(test.get("state", {}), true)
				var unit_class := StringName(test.unit_class)
				var footprint := world.rules.footprint_of(unit_class)
				var a := anchor(definition,cell(test.start),turns,footprint)+Vector3i(8,2,8)
				var b := anchor(definition,cell(test.destination),turns,footprint)+Vector3i(8,2,8)
				var path := world.find_path(Vector2i(a.x,a.z),a.y,Vector2i(b.x,b.z),b.y,unit_class)
				check((not path.is_empty()) == (test.expected == "PASS"), "%s/%s rotation %d world route" % [id,test.id,turns])
			# Each road must connect to the real terrain, not only another local node.
			var rotated := definition.rotated(turns)
			for key in definition.gate_cells: world.gate_states[str(key)] = true
			for socket in rotated.sockets:
				if not str(socket.type).begins_with("ROAD") and not str(socket.type).begins_with("PATH"): continue
				var inside: Vector3i = socket.position+Vector3i(8,2,8)
				var outside: Vector2i = Vector2i(inside.x,inside.z)+world.SOCKET_FACING[socket.facing]
				check(not world.find_path(outside,2,Vector2i(inside.x,inside.z),inside.y,&"infantry").is_empty(), "%s rotated road %s" % [id,socket.id])
		var before := var_to_bytes([definition.solid_cells,definition.nav_cells,definition.links,definition.gate_cells])
		var builder := BlockStructureBuilder.new()
		root.add_child(builder)
		builder.build(definition)
		check(before == var_to_bytes([definition.solid_cells,definition.nav_cells,definition.links,definition.gate_cells]), "%s art mutated gameplay" % id)
		var visual := builder.get_node_or_null("PaintedQuarterScale")
		if id == &"kons_splicing_laboratory_01":
			check(visual == null and builder.get_node("GothicDetails").scale == Vector3.ONE, "lab uses bespoke unscaled geometry")
		else:
			check(visual != null and visual.scale.is_equal_approx(Vector3.ONE*0.25), "%s visual scale applied exactly once" % id)
		var gate_owner: BlockStructureBuilder = visual if visual != null else builder
		for key in definition.gate_cells:
			builder.set_gate_open(key,true)
			check(not gate_owner._gate_meshes[key].visible, "%s open gate art" % id)
			builder.set_gate_open(key,false)
			check(gate_owner._gate_meshes[key].visible, "%s closed gate art" % id)
		builder.queue_free()
		await process_frame
		print("[QuarterScale] checked ",id)
	terrain.queue_free()
	await process_frame
	print("[QuarterScale] %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
