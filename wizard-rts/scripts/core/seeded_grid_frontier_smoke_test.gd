extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "frontier-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var map: Node = scene.get_node("MapGenerator")
	if str(map.get("map_type_id")) != "seeded_grid_frontier":
		push_error("Expected seeded_grid_frontier, got %s" % map.get("map_type_id"))
		quit(1)
		return
	if int(map.get_base_plots().size()) < 4:
		push_error("Seeded grid frontier should create at least four base plots")
		quit(1)
		return
	if int(map.get_plots().size()) < 9:
		push_error("Seeded grid frontier should create busy content coverage")
		quit(1)
		return
	var ramps: Array = map.get_map_summary().get("layout", {}).get("ramps", [])
	if ramps.size() < 4:
		push_error("Seeded grid frontier should create one ramp per base")
		quit(1)
		return

	var base_plots: Array = map.get_base_plots()
	var first_base: Dictionary = base_plots[0]
	var first_anchor: Vector2i = first_base.get("anchor", Vector2i.ZERO)
	for plot in map.get_plots():
		var anchor: Vector2i = plot.get("anchor", Vector2i.ZERO)
		var path: Array = map.find_path_cells(first_anchor, anchor)
		if path.is_empty() and first_anchor != anchor:
			push_error("No connected path from starter base to plot %s" % str(plot.get("id", "")))
			quit(1)
			return
		var road_anchor: Vector2i = plot.get("road_anchor", anchor)
		if not _has_path_cell_near(map, road_anchor, 1):
			push_error("Plot %s does not have a 3-wide road mouth near %s" % [str(plot.get("id", "")), road_anchor])
			quit(1)
			return
		if str(plot.get("kind", "")) != "base" and not _content_entrance_has_road_approach(map, plot):
			push_error("Content plot %s does not have a 3-wide road approach outside its gate" % str(plot.get("id", "")))
			quit(1)
			return

	var road_cells: Dictionary = map.get("road_cells")
	for road_cell in road_cells.keys():
		if not map.is_walkable_cell(road_cell):
			push_error("Road cell became unwalkable after terrain stamping: %s" % road_cell)
			quit(1)
			return

	var build_system: Node = scene.get_node("BuildSystem")
	var placement_cell: Vector2i = first_base.get("rect", Rect2i()).position + Vector2i(1, 1)
	if not build_system.call("try_place_structure", 1, &"barracks", placement_cell):
		push_error("Expected square-grid building placement to work on seeded frontier")
		quit(1)
		return
	if map.is_walkable_cell(placement_cell):
		push_error("Placed building did not block seeded frontier grid cells")
		quit(1)
		return
	print("[SeededGridFrontierSmokeTest] seed=", map.get_seed_value(), " plots=", map.get_plots().size(), " ramps=", ramps.size())
	quit(0)

func _has_path_cell_near(map: Node, center: Vector2i, radius: int) -> bool:
	var feature_grid: Array = map.get("feature_grid")
	var path_cells := 0
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var cell := Vector2i(x, y)
			if not map.is_in_bounds(cell):
				continue
			if str(feature_grid[x][y]) == "path" or str(feature_grid[x][y]) == "ramp":
				path_cells += 1
	return path_cells >= 3

func _content_entrance_has_road_approach(map: Node, plot: Dictionary) -> bool:
	var feature_grid: Array = map.get("feature_grid")
	var rect: Rect2i = plot.get("rect", Rect2i())
	var entrance := Vector2i(rect.position.x + rect.size.x / 2, rect.end.y)
	for x in range(entrance.x - 1, entrance.x + 2):
		if not map.is_in_bounds(Vector2i(x, entrance.y)):
			continue
		if str(feature_grid[x][entrance.y]) != "path":
			return false
	return true
