extends SceneTree

const MAP_3D_PROTOTYPE := preload("res://scenes/map/map_3d_prototype.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := MAP_3D_PROTOTYPE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var start: Vector2i = scene.get("_unit_cell")
	if not scene.call("_is_walkable_cell", start):
		push_error("3D probe unit did not spawn on a walkable cell: %s" % start)
		quit(1)
		return
	scene.call("_update_probe_screen_marker")
	scene.call("_set_probe_selected", false)
	var marker: Control = scene.get("_probe_screen_marker")
	var marker_center := marker.position + marker.size * 0.5
	scene.set("_drag_selecting", true)
	scene.set("_drag_start", marker_center - Vector2(40.0, 32.0))
	scene.set("_drag_current", marker_center + Vector2(40.0, 32.0))
	scene.call("_end_drag_select", marker_center + Vector2(40.0, 32.0))
	if not bool(scene.get("_unit_selected")):
		push_error("3D probe drag selection did not select the probe")
		quit(1)
		return

	var target := _find_probe_target(scene, start)
	if target == Vector2i(-1, -1):
		push_error("Could not find a reachable 3D probe target")
		quit(1)
		return

	scene.call("_issue_probe_move", target)
	var path: Array = scene.get("_unit_path")
	if path.is_empty():
		push_error("3D probe move did not produce a path from %s to %s" % [start, target])
		quit(1)
		return

	print("[Map3DProbeSmokeTest] start=", start, " target=", target, " path=", path.size())
	quit(0)


func _find_probe_target(scene: Node, start: Vector2i) -> Vector2i:
	var generator: Node = scene.get("_map_generator")
	if generator == null:
		return Vector2i(-1, -1)
	for offset in [Vector2i(18, 0), Vector2i(0, 18), Vector2i(-18, 0), Vector2i(0, -18), Vector2i(18, 18), Vector2i(-18, 18)]:
		var candidate: Vector2i = generator.call("nearest_walkable_cell", start + offset, 12)
		if not scene.call("_is_walkable_cell", candidate):
			continue
		var path: Array = generator.call("find_path_cells", start, candidate)
		if not path.is_empty():
			return candidate
	return Vector2i(-1, -1)
