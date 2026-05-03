class_name MapPlotConfig
extends Resource

@export var seed: int = 110142
@export var size: Vector2i = Vector2i(42, 28)

@export_range(0.35, 0.95, 0.01) var landmass_radius: float = 0.76
@export_range(0.0, 1.0, 0.01) var landmass_roughness: float = 0.38
@export_range(0, 8, 1) var smoothing_passes: int = 4
@export var min_land_tiles: int = 180

@export var cliff_count: int = 5
@export var cliff_min_size: int = 8
@export var cliff_max_size: int = 34
@export var cliff_edge_clearance: int = 2

@export_range(0.0, 0.25, 0.005) var bush_density: float = 0.04
@export_range(0.0, 0.20, 0.005) var rock_density: float = 0.02
@export_range(0.0, 0.20, 0.005) var water_rock_density: float = 0.012
@export_range(0.0, 1.0, 0.01) var overhang_density: float = 0.32

@export var min_anchor_count: int = 2
@export var max_anchor_count: int = 4
@export var anchor_spacing: int = 8

@export var tile_size: Vector2i = Vector2i(64, 64)
@export var world_offset: Vector2i = Vector2i.ZERO

