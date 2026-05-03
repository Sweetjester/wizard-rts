extends Node2D

const MapPlotConfigResource := preload("res://scripts/map/plots/MapPlotConfig.gd")

@onready var generator: Node = $PlotGenerator
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	var config: Resource = MapPlotConfigResource.new()
	config.seed = 110142
	config.size = Vector2i(42, 28)
	config.landmass_radius = 0.76
	config.landmass_roughness = 0.38
	config.cliff_count = 5
	config.bush_density = 0.04
	config.rock_density = 0.02
	config.overhang_density = 0.32
	generator.generate(config, Vector2i.ZERO)
	camera.position = Vector2(config.size * config.tile_size) * 0.5
