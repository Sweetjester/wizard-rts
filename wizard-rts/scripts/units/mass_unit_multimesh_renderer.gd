class_name MassUnitMultimeshRenderer
extends MultiMeshInstance2D

const MAX_INSTANCES := 5000

var update_elapsed := 0.0

func _ready() -> void:
	z_index = 3000
	z_as_relative = false
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mesh_batch := MultiMesh.new()
	mesh_batch.transform_format = MultiMesh.TRANSFORM_2D
	mesh_batch.use_colors = true
	mesh_batch.mesh = quad
	mesh_batch.instance_count = MAX_INSTANCES
	mesh_batch.visible_instance_count = 0
	multimesh = mesh_batch

func _process(delta: float) -> void:
	update_elapsed += delta
	if update_elapsed < 0.1:
		return
	update_elapsed = 0.0
	_refresh_instances()

func _refresh_instances() -> void:
	if multimesh == null:
		return
	var index := 0
	for unit in RTSUnit.get_registered_units_snapshot():
		if index >= MAX_INSTANCES:
			break
		if not is_instance_valid(unit) or unit.visible:
			continue
		var archetype := StringName(unit.get("unit_archetype"))
		var size := _size_for(archetype)
		var transform := Transform2D()
		transform.x = Vector2(size.x, 0.0)
		transform.y = Vector2(0.0, size.y)
		transform.origin = to_local(unit.global_position)
		multimesh.set_instance_transform_2d(index, transform)
		multimesh.set_instance_color(index, _owner_color(int(unit.get("owner_player_id")), archetype))
		index += 1
	multimesh.visible_instance_count = index

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
