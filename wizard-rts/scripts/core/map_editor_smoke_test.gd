extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/map/map_editor.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	if scene.get_node_or_null("Water") == null:
		push_error("Map editor should create a Water TileMapLayer")
		quit(1)
		return
	if scene.get_node_or_null("Ground") == null:
		push_error("Map editor should create a Ground TileMapLayer")
		quit(1)
		return
	if scene.get_node_or_null("BrushPreview") == null:
		push_error("Map editor should create a live BrushPreview TileMapLayer")
		quit(1)
		return
	if scene.get_node_or_null("Camera2D") == null:
		push_error("Map editor should create a camera")
		quit(1)
		return
	var brushes: Array = scene.get("_brushes")
	if brushes.size() < 100:
		push_error("Map editor should scan the asset library into the brush palette")
		quit(1)
		return
	var water_layer := scene.get_node("Water") as TileMapLayer
	if water_layer.get_used_cells().is_empty():
		push_error("Map editor should fill the water base on boot")
		quit(1)
		return
	scene.call("create_content_plot", "medium")
	await process_frame
	var ground_layer := scene.get_node("Ground") as TileMapLayer
	if ground_layer.get_used_cells().size() < 100:
		push_error("Medium content plot should create at least 100 editable ground cells")
		quit(1)
		return
	var bounds_layer := scene.get_node_or_null("ContentPlotBounds") as TileMapLayer
	if bounds_layer == null or bounds_layer.get_used_cells().is_empty():
		push_error("Content plot mode should draw visible bounds")
		quit(1)
		return
	scene.call("_save_content_plot")
	await process_frame
	scene.call("_load_content_plot")
	await process_frame
	if ground_layer.get_used_cells().size() < 100:
		push_error("Content plot save/load should preserve the medium plot cells")
		quit(1)
		return
	print("[MapEditorSmokeTest] water_cells=", water_layer.get_used_cells().size(), " medium_plot_cells=", ground_layer.get_used_cells().size(), " brushes=", brushes.size())
	quit(0)
