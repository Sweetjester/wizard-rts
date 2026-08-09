extends SceneTree

const CLOSE_COUNT := 6
const FAR_COUNT := 12
const LOD_FRAMES := 24

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 4:
		await process_frame
		await physics_frame

	var map: Node = scene.get_node("MapGenerator")
	var wizard: Node2D = scene.get_node("Wizard")
	var camera: Camera2D = scene.get_node("Camera2D")
	var renderer: Node = scene.get_node("MassUnitMultimeshRenderer")
	var selection_controller: Node = scene.get_node("SelectionController")
	if map == null or wizard == null or camera == null or renderer == null:
		_fail("Mass LOD smoke test missing main-map dependencies")
		return

	camera.global_position = wizard.global_position
	camera.zoom = Vector2.ONE
	renderer.set("closest_full_detail_count", 4)
	renderer.set("camera_view_margin", 0.0)
	renderer.set("always_full_detail_radius", 0.0)
	renderer.set("refresh_interval", 0.01)
	renderer.set("central_movement_min_units", 10)

	var treant_scene: PackedScene = load("res://scenes/units/treant.tscn")
	var spawned: Array[Node2D] = []
	var close_units: Array[Node2D] = []
	var far_units: Array[Node2D] = []
	var origin: Vector2i = map.world_to_cell(wizard.global_position)

	for i in CLOSE_COUNT:
		var cell: Vector2i = map.nearest_walkable_cell(origin + Vector2i(i % 3, i / 3), 12)
		var unit := _spawn_treant(treant_scene, scene, map.cell_to_world(cell), 1)
		close_units.append(unit)
		spawned.append(unit)

	for i in FAR_COUNT:
		var far_offset := Vector2i(28 + (i % 4) * 2, 20 + (i / 4) * 2)
		var cell: Vector2i = map.nearest_walkable_cell(origin + far_offset, 24)
		var owner := 2 if i == 0 else 1
		var unit := _spawn_treant(treant_scene, scene, map.cell_to_world(cell), owner)
		far_units.append(unit)
		spawned.append(unit)

	for _frame in LOD_FRAMES:
		await process_frame
		await physics_frame

	var close_full := 0
	var close_blob := 0
	var far_full := 0
	var far_blob := 0
	for unit in close_units:
		if not is_instance_valid(unit):
			_fail("Close unit became invalid during LOD test")
			return
		if unit.visible and bool(renderer.call("is_unit_full_detail", unit)):
			close_full += 1
		if bool(renderer.call("is_unit_blob_rendered", unit)):
			close_blob += 1
	for unit in far_units:
		if not is_instance_valid(unit):
			_fail("Far unit became invalid during LOD test")
			return
		if unit.visible and bool(renderer.call("is_unit_full_detail", unit)):
			far_full += 1
		if not unit.visible and bool(renderer.call("is_unit_blob_rendered", unit)):
			far_blob += 1

	if close_full != close_units.size():
		_fail("Expected all close units to remain full-detail; got %s/%s" % [close_full, close_units.size()])
		return
	if close_blob != 0:
		_fail("Close units were double-counted in the multimesh")
		return
	if far_blob == 0:
		_fail("Expected at least one distant unit to become blob-tier")
		return
	var multimesh: MultiMesh = renderer.get("multimesh")
	if multimesh.visible_instance_count < far_blob:
		_fail("Multimesh visible_instance_count does not include blob-tier units")
		return
	if close_full + far_full + far_blob != spawned.size():
		_fail("LOD accounting mismatch full=%s blobs=%s spawned=%s" % [close_full + far_full, far_blob, spawned.size()])
		return

	var attacker := close_units[0]
	var hidden_enemy := far_units[0]
	if hidden_enemy.visible or not bool(renderer.call("is_unit_blob_rendered", hidden_enemy)):
		_fail("Expected test enemy to be hidden and blob-rendered")
		return
	if not bool(hidden_enemy.call("uses_central_mass_movement")):
		_fail("Hidden blob-tier enemy did not opt into central mass movement")
		return
	if hidden_enemy.is_physics_processing():
		_fail("Hidden blob-tier enemy still has per-node physics processing enabled")
		return
	var mover := far_units[1]
	var mover_start := mover.global_position
	mover.call("issue_move_order", mover_start + Vector2(320.0, 0.0))
	for _frame in 18:
		await process_frame
		await physics_frame
	if mover.global_position.distance_squared_to(mover_start) < 16.0:
		_fail("Central mass movement did not advance a hidden blob-tier unit")
		return
	if selection_controller == null:
		_fail("Missing SelectionController for hidden target order test")
		return
	var selected_units: Array[Node] = [attacker]
	selection_controller.set("selected_units", selected_units)
	var accepted := bool(selection_controller.call("_try_order_attack_target", hidden_enemy.global_position))
	if not accepted:
		_fail("SelectionController rejected attack-target order against hidden blob-tier enemy")
		return
	if attacker.get("attack_target") != hidden_enemy:
		_fail("Attack-target order did not register hidden blob-tier enemy")
		return

	print("[MassUnitLodSmokeTest] close_full=", close_full, " far_full=", far_full, " far_blob=", far_blob, " multimesh_visible=", multimesh.visible_instance_count)
	quit(0)

func _spawn_treant(treant_scene: PackedScene, parent: Node, position: Vector2, owner: int) -> Node2D:
	var treant := treant_scene.instantiate()
	treant.set("owner_player_id", owner)
	parent.add_child(treant)
	treant.global_position = position
	return treant as Node2D

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
