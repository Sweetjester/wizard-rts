extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "frontier-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	# Map generation is spread across frames now, so the scene is not playable
	# the instant it is added. Waits for the generator to say it is finished
	# rather than for a fixed frame count -- a count that happened to be long
	# enough on a 96x96 map is not a guarantee, it is a coincidence.
	for _gen_wait in 400:
		var _gen := scene.get_node_or_null("MapGenerator")
		if _gen == null or bool(_gen.get("generation_complete")):
			break
		await process_frame
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
	var blank_counts := {"small": 0, "medium": 0, "large": 0}
	var expected_blank_counts := {"small": 4, "medium": 4, "large": 1}
	var blank_sizes := {"small": Vector2i(5, 5), "medium": Vector2i(10, 10), "large": Vector2i(14, 14)}
	var ramps: Array = map.get_map_summary().get("layout", {}).get("ramps", [])
	for plot in map.get_plots():
		if str(plot.get("kind", "")) != "content_blank":
			continue
		var content_size := str(plot.get("content_size", ""))
		if blank_counts.has(content_size):
			blank_counts[content_size] = int(blank_counts[content_size]) + 1
		var expected_size: Vector2i = blank_sizes.get(content_size, Vector2i.ZERO)
		var rect: Rect2i = plot.get("rect", Rect2i())
		if expected_size != Vector2i.ZERO and rect.size != expected_size:
			push_error("Blank %s plot should be %s, got %s" % [content_size, expected_size, rect])
			quit(1)
			return
		if content_size == "large" and rect.position.x <= 8 and rect.position.y <= 8:
			push_error("Large content plot should not be forced into the top-left corner: %s" % rect)
			quit(1)
			return
		for base_plot in map.get_base_plots():
			var base_rect: Rect2i = base_plot.get("rect", Rect2i())
			if rect.intersects(base_rect):
				push_error("Content plot %s overlaps base plot %s" % [plot.get("id", ""), base_plot.get("id", "")])
				quit(1)
				return
		for ramp in ramps:
			var ramp_rect: Rect2i = ramp
			if rect.intersects(ramp_rect):
				push_error("Content plot %s overlaps ramp %s" % [plot.get("id", ""), ramp_rect])
				quit(1)
				return
	for content_size in blank_counts.keys():
		if int(blank_counts[content_size]) != int(expected_blank_counts[content_size]):
			push_error("Expected %s %s blank content plots, got %s" % [expected_blank_counts[content_size], content_size, blank_counts[content_size]])
			quit(1)
			return
	if ramps.size() < 4:
		push_error("Seeded grid frontier should create one ramp per base")
		quit(1)
		return

	var base_plots: Array = map.get_base_plots()
	var first_base: Dictionary = base_plots[0]
	var first_anchor: Vector2i = first_base.get("anchor", Vector2i.ZERO)
	for base_plot in base_plots:
		if str(base_plot.get("base_archetype", "")) == "":
			push_error("Seeded grid frontier base plot is missing an archetype: %s" % str(base_plot.get("id", "")))
			quit(1)
			return
	if not _road_network_spans_map(map):
		push_error("Seeded grid frontier should have connected road arteries spanning west/east and north/south")
		quit(1)
		return
	for plot in map.get_plots():
		var anchor: Vector2i = plot.get("anchor", Vector2i.ZERO)
		# A plot occupied by a block structure is walked into through its own
		# authored entrance, on the lattice -- so its CENTRE is solid keep, and
		# demanding a flat 2D path to it asserts the opposite of what the design
		# wants. The road still has to arrive at its door, which is checked just
		# below, and citadel_placement_smoke_test walks the inside properly.
		if str(plot.get("block_structure", "")) != "":
			var approach: Vector2i = plot.get("road_anchor", anchor)
			if map.find_path_cells(first_anchor, approach).is_empty() and first_anchor != approach:
				push_error("No connected path from starter base to the approach of plot %s at %s"
					% [str(plot.get("id", "")), approach])
				quit(1)
				return
			continue
		var path: Array = map.find_path_cells(first_anchor, anchor)
		if path.is_empty() and first_anchor != anchor:
			push_error("No connected path from starter base to plot %s" % str(plot.get("id", "")))
			quit(1)
			return
		var road_anchor: Vector2i = plot.get("road_anchor", anchor)
		var road_radius := 2 if str(plot.get("kind", "")) == "content_blank" else 1
		if not _has_path_cell_near(map, road_anchor, road_radius):
			push_error("Plot %s does not have a 3-wide road mouth near %s" % [str(plot.get("id", "")), road_anchor])
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
	# A building occupies ground -- but not necessarily the cell it was placed
	# from. The Biospawner is an enterable Splicing Laboratory now: its walls
	# block and its doorway, aisles and courtyard deliberately do not, so its
	# origin corner is as likely to be floor as wall. Asserting that one specific
	# cell went solid was testing a 3x3 sprite that no longer exists.
	var footprint: Vector2i = build_system.call("rotated_footprint", &"barracks", 0)
	var blocked_cells := 0
	for dx in footprint.x:
		for dy in footprint.y:
			if not map.is_walkable_cell(placement_cell + Vector2i(dx, dy)):
				blocked_cells += 1
	if blocked_cells <= 0:
		push_error("Placed building blocked none of its %s footprint on the seeded frontier" % [footprint])
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

func _road_network_spans_map(map: Node) -> bool:
	var feature_grid: Array = map.get("feature_grid")
	var starts: Array[Vector2i] = []
	# Sized off the map rather than hardcoded to the 96x96 the frontier used to
	# be. It is 160x160 now, so 4..92 sampled only the western quarter and
	# "spans the map" was being asked of a strip.
	var width := int(map.MAP_W)
	var height := int(map.MAP_H)
	var margin := 4
	var far_x := width - margin - 1
	var far_y := height - margin - 1
	for y in range(margin, height - margin):
		if _is_road_feature(feature_grid[margin][y]):
			starts.append(Vector2i(margin, y))
	if starts.is_empty():
		return false
	var reached := {}
	var queue: Array[Vector2i] = starts.duplicate()
	for start in starts:
		reached[start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + offset
			if not map.is_in_bounds(next) or reached.has(next):
				continue
			if not _is_road_feature(feature_grid[next.x][next.y]):
				continue
			reached[next] = true
			queue.append(next)
	var touches_east := false
	var touches_north := false
	var touches_south := false
	for cell in reached.keys():
		if cell.x >= far_x:
			touches_east = true
		if cell.y <= margin:
			touches_north = true
		if cell.y >= far_y:
			touches_south = true
	return touches_east and touches_north and touches_south

func _is_road_feature(feature: Variant) -> bool:
	var text := str(feature)
	return text == "path" or text == "ramp"
