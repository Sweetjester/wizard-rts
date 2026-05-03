extends SceneTree

const MapPlotConfigResource := preload("res://scripts/map/plots/MapPlotConfig.gd")
const PlotGeneratorResource := preload("res://scripts/map/plots/PlotGenerator.gd")

func _initialize() -> void:
	var generator: Node = PlotGeneratorResource.new()
	root.add_child(generator)
	var config: Resource = MapPlotConfigResource.new()
	config.seed = 110142
	config.size = Vector2i(42, 28)
	generator.call("generate", config, Vector2i(3, 5))
	var anchors: Array = generator.call("get_connection_anchors")
	var walkable: Array = generator.call("get_walkable_cells")
	if anchors.size() < config.min_anchor_count:
		push_error("PlotGenerator expected at least %s anchors, got %s" % [config.min_anchor_count, anchors.size()])
	if walkable.size() < config.min_land_tiles:
		push_error("PlotGenerator expected at least %s walkable cells, got %s" % [config.min_land_tiles, walkable.size()])
	print("[PlotGeneratorSmokeTest] anchors=%s walkable=%s bounds=%s" % [anchors.size(), walkable.size(), generator.call("get_local_bounds")])
	quit()
