extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var first := await _build_summary("vampire-test-seed")
	var second := await _build_summary("vampire-test-seed")
	var different := await _build_summary("different-vampire-seed")

	if first["signature"] != second["signature"]:
		push_error("Same seed produced different map signatures")
		quit(1)
		return
	if first["signature"] == different["signature"]:
		push_error("Different seeds produced identical map signatures")
		quit(1)
		return
	if int(first["base_plots"]) != 3 or int(first["plots"]) < 8:
		push_error("Expected Vampire Mushroom Forest to create base plots and authored content plots")
		quit(1)
		return
	if int(first["economy_spaces"]) != 6:
		push_error("Expected exactly six economy spaces across the three base plots")
		quit(1)
		return
	if not bool(first["hollow_plots_valid"]):
		push_error("Expected tower and outpost to be 10x10 hollow blocked structures with entrances")
		quit(1)
		return
	if int(first["lakes"]) < 2:
		push_error("Expected map generation to create multiple readable lakes")
		quit(1)
		return
	if int(first["ramp_cells"]) < 60:
		push_error("Expected ramps to be large enough to read clearly")
		quit(1)
		return
	if int(first["landmarks"]) < 12:
		push_error("Expected large-map landmarks with giant mushroom silhouettes")
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
	await process_frame
	await process_frame

	var summary: Dictionary = map.get_map_summary()
	var hollow_plots_valid := _validate_hollow_plot(map, "abandoned_wizard_tower") and _validate_hollow_plot(map, "bandit_outpost")
	var layout: Dictionary = summary["layout"]
	var plot_signature := _plot_signature(summary.get("plot_layout", []))
	var ramp_cells := _ramp_cell_count(layout.get("ramps", []))
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
		"lakes": layout.get("lakes", []).size(),
		"landmarks": layout.get("landmarks", []).size(),
		"ramp_cells": ramp_cells,
		"hollow_plots_valid": hollow_plots_valid,
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

func _validate_hollow_plot(map: Node, plot_id: String) -> bool:
	for plot in map.get_plots():
		if String(plot.get("id", "")) != plot_id:
			continue
		var rect: Rect2i = plot["rect"]
		if rect.size != Vector2i(10, 10):
			return false
		var entrance_x := rect.position.x + rect.size.x / 2
		var entrance_y := rect.end.y - 1
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var cell := Vector2i(x, y)
				var is_edge := cell.x == rect.position.x or cell.y == rect.position.y or cell.x == rect.end.x - 1 or cell.y == rect.end.y - 1
				var is_entrance: bool = y == entrance_y and abs(x - entrance_x) <= 1
				if is_edge and not is_entrance and map.is_walkable_cell(cell):
					return false
				if (not is_edge or is_entrance) and not map.is_walkable_cell(cell):
					return false
		return true
	return false
