extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var first := await _build_summary("frontier-test-seed")
	var second := await _build_summary("frontier-test-seed")
	var different := await _build_summary("different-frontier-seed")

	if first["signature"] != second["signature"]:
		push_error("Same seed produced different map signatures")
		quit(1)
		return
	if first["signature"] == different["signature"]:
		push_error("Different seeds produced identical map signatures")
		quit(1)
		return
	if int(first["base_plots"]) < 4 or int(first["plots"]) < 9:
		push_error("Expected Seeded Grid Frontier to create base plots and busy authored content coverage")
		quit(1)
		return
	if int(first["economy_spaces"]) < 8:
		push_error("Expected archetyped base plots to provide varied resource nodes")
		quit(1)
		return
	if not bool(first["base_archetypes_valid"]):
		push_error("Expected Seeded Grid Frontier base plots to include valid fortress, holdfast, and expansion archetypes")
		quit(1)
		return
	if not bool(first["road_spans_map"]):
		push_error("Expected Seeded Grid Frontier roads to span the map")
		quit(1)
		return
	if int(first["ramp_cells"]) < 16:
		push_error("Expected at least one readable 2x2 ramp per base")
		quit(1)
		return

	print("[MapSeedSmokeTest] deterministic seed=", first["seed"],
		" plots=", first["plots"],
		" economy_spaces=", first["economy_spaces"])
	quit(0)

func _build_summary(seed_text: String) -> Dictionary:
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	var map: Node = scene.get_node("MapGenerator")
	map.set("map_seed_text", seed_text)
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
	await process_frame

	var summary: Dictionary = map.get_map_summary()
	var layout: Dictionary = summary["layout"]
	var plot_signature := _plot_signature(summary.get("plot_layout", []))
	var ramp_cells := _ramp_cell_count(layout.get("ramps", []))
	var base_archetypes_valid := _validate_base_archetypes(map)
	var road_spans_map := _road_network_spans_map(map)
	var signature := "%s|%s|%s|%s|%s|%s|%s|%s" % [
		summary["seed"],
		layout["high_ground"],
		layout["mid_ground"],
		layout.get("lakes", []),
		layout["ramp"],
		layout.get("ramps", []),
		plot_signature,
		summary["economy_spaces"],
	]

	scene.queue_free()
	await process_frame
	return {
		"seed": summary["seed"],
		"plots": summary["plots"],
		"base_plots": summary["base_plots"],
		"economy_spaces": summary["economy_spaces"],
		"ramp_cells": ramp_cells,
		"base_archetypes_valid": base_archetypes_valid,
		"road_spans_map": road_spans_map,
		"signature": signature,
	}

func _plot_signature(plot_layout: Array) -> String:
	var parts: Array[String] = []
	for plot in plot_layout:
		var plot_data: Dictionary = plot
		parts.append("%s:%s:%s" % [
			plot_data.get("id", ""),
			plot_data.get("rect", Rect2i()),
			plot_data.get("economy_spaces", []),
		])
	return ";".join(parts)

func _ramp_cell_count(ramp_layout: Array) -> int:
	var total := 0
	for ramp in ramp_layout:
		var rect: Rect2i = ramp
		total += rect.size.x * rect.size.y
	return total

func _validate_base_archetypes(map: Node) -> bool:
	var seen := {}
	for plot in map.get_base_plots():
		var archetype := str(plot.get("base_archetype", ""))
		seen[archetype] = true
		var rect: Rect2i = plot.get("rect", Rect2i())
		var size_class := str(plot.get("plot_size_class", ""))
		var resources := int(plot.get("resource_node_count", 0))
		var target_ramps := int(plot.get("target_ramp_count", 0))
		if size_class == "" or resources <= 0 or target_ramps <= 0:
			return false
		match archetype:
			"FORTRESS_BASE":
				if rect.size.x > 13 or resources != 1:
					return false
			"HOLDFAST_BASE":
				if rect.size.x < 14 or rect.size.x > 16 or resources != 2:
					return false
			"EXPANSION_BASE":
				if rect.size.x < 18 or resources != 3:
					return false
			_:
				return false
	return seen.has("FORTRESS_BASE") and seen.has("HOLDFAST_BASE") and seen.has("EXPANSION_BASE")

func _road_network_spans_map(map: Node) -> bool:
	var feature_grid: Array = map.get("feature_grid")
	var starts: Array[Vector2i] = []
	for y in range(4, 92):
		if _is_road_feature(feature_grid[4][y]):
			starts.append(Vector2i(4, y))
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
		if cell.x >= 91:
			touches_east = true
		if cell.y <= 4:
			touches_north = true
		if cell.y >= 91:
			touches_south = true
	return touches_east and touches_north and touches_south

func _is_road_feature(feature: Variant) -> bool:
	var text := str(feature)
	return text == "path" or text == "ramp"
