extends SceneTree

const MONOLITH_TEST_SCENE := preload("res://scenes/map/monolith_structure_test.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for footprint in [12, 16, 20]:
		var scene := MONOLITH_TEST_SCENE.instantiate()
		scene.set("monolith_footprint_size", footprint)
		root.add_child(scene)
		await process_frame
		await process_frame
		var structures: Array = scene.get("_content_structures")
		if structures.is_empty():
			push_error("No monolith structure generated for footprint %s" % footprint)
			quit(1)
			return
		var structure: Dictionary = structures[0]
		var validation: Dictionary = structure.get("validation", {})
		if not bool(validation.get("passed", false)):
			push_error("Monolith validation failed for footprint %s: %s" % [footprint, validation])
			quit(1)
			return
		if structure.get("footprint_size", Vector2i.ZERO) != Vector2i(footprint, footprint):
			push_error("Monolith footprint mismatch expected %s got %s" % [footprint, structure.get("footprint_size", Vector2i.ZERO)])
			quit(1)
			return
		var probe_cell: Vector2i = scene.get("_unit_cell")
		if not scene.call("_is_walkable_cell", probe_cell):
			push_error("Probe spawned on invalid cell for footprint %s: %s" % [footprint, probe_cell])
			quit(1)
			return
		var entrances: Array = structure.get("entrance_cells", [])
		if entrances.is_empty():
			push_error("Monolith has no entrance for footprint %s" % footprint)
			quit(1)
			return
		scene.call("_issue_probe_move", entrances[0])
		var path: Array = scene.get("_unit_path")
		if path.is_empty() and probe_cell != entrances[0]:
			push_error("Probe cannot path to entrance for footprint %s" % footprint)
			quit(1)
			return
		scene.call("_toggle_structure_cutaway_mode")
		await process_frame
		var rendered_floor_cells := int(scene.get("_rendered_floor_cell_count"))
		if rendered_floor_cells <= 0:
			push_error("Cutaway rendered no floor cells for footprint %s" % footprint)
			quit(1)
			return
		scene.call("_set_floor_focus", 1)
		await process_frame
		if int(scene.get("_rendered_floor_cell_count")) <= 0:
			push_error("Floor 1 rendered no cells for footprint %s" % footprint)
			quit(1)
			return
		print("[MonolithScaleSmokeTest] footprint=", footprint,
			" walkable_counts=", validation.get("walkable_counts", []),
			" stairs=", validation.get("stair_count", 0),
			" probe_cell=", probe_cell,
			" entrance_path=", path.size(),
			" cutaway_cells=", rendered_floor_cells)
		scene.queue_free()
		await process_frame
	quit(0)
