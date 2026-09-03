class_name MassUnitMultimeshRenderer
extends MultiMeshInstance2D

@export var max_instances: int = 5000
@export var refresh_interval: float = 0.1
@export var closest_full_detail_count: int = 220
@export var camera_view_margin: float = 640.0
@export var always_full_detail_radius: float = 0.0
@export var central_movement_min_units: int = 160

var update_elapsed := 0.0
var _full_detail_ids: Dictionary = {}
var _blob_ids: Dictionary = {}
var _rts_world: RTSWorld

func _ready() -> void:
	_rts_world = get_node_or_null(NodePath("../RTSWorld"))
	z_index = 3000
	z_as_relative = false
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mesh_batch := MultiMesh.new()
	mesh_batch.transform_format = MultiMesh.TRANSFORM_2D
	mesh_batch.use_colors = true
	mesh_batch.mesh = quad
	mesh_batch.instance_count = max_instances
	mesh_batch.visible_instance_count = 0
	multimesh = mesh_batch

func _process(delta: float) -> void:
	update_elapsed += delta
	if update_elapsed < refresh_interval:
		return
	update_elapsed = 0.0
	_refresh_instances()

func _exit_tree() -> void:
	for unit in RTSUnit.get_registered_units_snapshot():
		if is_instance_valid(unit):
			unit.visible = true
			if unit.has_method("set_central_mass_movement_active"):
				unit.call("set_central_mass_movement_active", false)

func _refresh_instances() -> void:
	if multimesh == null:
		return
	# The 3D view renders units itself. Leaving this running would toggle unit
	# visibility back on and paint 2D blobs over the 3D world.
	if _rts_world != null and is_instance_valid(_rts_world) and _rts_world.presentation_3d:
		return
	if multimesh.instance_count != max_instances:
		multimesh.instance_count = max_instances
		multimesh.visible_instance_count = 0
	_full_detail_ids.clear()
	_blob_ids.clear()

	var units := RTSUnit.get_registered_units_snapshot()
	var camera := get_viewport().get_camera_2d()
	var camera_position := camera.global_position if camera != null else global_position
	var full_detail_ids := _choose_full_detail_units(units, camera, camera_position)
	var centralize_blob_movement := units.size() >= central_movement_min_units

	var index := 0
	for unit in units:
		if not is_instance_valid(unit):
			continue
		var unit_id := unit.get_instance_id()
		if full_detail_ids.has(unit_id) or index >= max_instances:
			unit.visible = true
			if unit.has_method("set_central_mass_movement_active"):
				unit.call("set_central_mass_movement_active", false)
			_full_detail_ids[unit_id] = true
			continue
		unit.visible = false
		if unit.has_method("set_central_mass_movement_active"):
			unit.call("set_central_mass_movement_active", centralize_blob_movement)
		var archetype := StringName(unit.get("unit_archetype"))
		var size := _size_for(archetype)
		var transform := Transform2D()
		transform.x = Vector2(size.x, 0.0)
		transform.y = Vector2(0.0, size.y)
		transform.origin = to_local(unit.global_position)
		multimesh.set_instance_transform_2d(index, transform)
		multimesh.set_instance_color(index, _owner_color(int(unit.get("owner_player_id")), archetype))
		_blob_ids[unit_id] = true
		index += 1
	multimesh.visible_instance_count = index

func _choose_full_detail_units(units: Array[Node2D], camera: Camera2D, camera_position: Vector2) -> Dictionary:
	var result: Dictionary = {}
	var view_rect := _camera_view_rect(camera)
	var closest: Array[Dictionary] = []
	# Selected units normally get full detail wherever they are. That stops
	# being affordable once "selected" can mean the entire army: honour it for
	# a hand-managed squad, and fall back to the ordinary distance/view rules
	# for a bulk selection. Evaluated once per refresh, not once per unit.
	var honour_selection := _rts_world == null or not is_instance_valid(_rts_world) \
		or _rts_world.selected_unit_count <= RTSWorld.BULK_SELECTION_THRESHOLD
	for unit in units:
		if not is_instance_valid(unit):
			continue
		var unit_id := unit.get_instance_id()
		if honour_selection and bool(unit.get("selected")):
			result[unit_id] = true
			continue
		var distance_sq := camera_position.distance_squared_to(unit.global_position)
		if view_rect.has_point(unit.global_position):
			result[unit_id] = true
		elif always_full_detail_radius > 0.0 and distance_sq <= always_full_detail_radius * always_full_detail_radius:
			result[unit_id] = true
		closest.append({"id": unit_id, "distance_sq": distance_sq})
	closest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance_sq"]) < float(b["distance_sq"])
	)
	var closest_count := mini(maxi(0, closest_full_detail_count), closest.size())
	for i in closest_count:
		result[int(closest[i]["id"])] = true
	return result

func _camera_view_rect(camera: Camera2D) -> Rect2:
	if camera == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var viewport_size := get_viewport_rect().size / camera.zoom
	var top_left := camera.global_position - viewport_size * 0.5
	return Rect2(top_left, viewport_size).grow(camera_view_margin)

func get_full_detail_count() -> int:
	return _full_detail_ids.size()

func get_blob_count() -> int:
	return _blob_ids.size()

func is_unit_full_detail(unit: Node2D) -> bool:
	return unit != null and _full_detail_ids.has(unit.get_instance_id())

func is_unit_blob_rendered(unit: Node2D) -> bool:
	return unit != null and _blob_ids.has(unit.get_instance_id())

func _size_for(archetype: StringName) -> Vector2:
	match archetype:
		&"apex":
			return Vector2(26.0, 20.0)
		&"spawner", &"winged_spawner":
			return Vector2(30.0, 24.0)
		&"horror", &"spawner_drone":
			return Vector2(16.0, 14.0)
		_:
			return Vector2(18.0, 16.0)

func _owner_color(owner: int, archetype: StringName) -> Color:
	var alpha := 0.92
	var tint := Color(0.15, 0.55, 0.28, alpha)
	match owner:
		2:
			tint = Color(0.75, 0.16, 0.13, alpha)
		3:
			tint = Color(0.12, 0.68, 0.78, alpha)
		4:
			tint = Color(0.88, 0.68, 0.25, alpha)
	if archetype in [&"spawner", &"winged_spawner"]:
		tint = tint.lightened(0.15)
	elif archetype == &"horror":
		tint = tint.darkened(0.18)
	elif archetype == &"apex":
		tint = tint.lightened(0.08)
	return tint
