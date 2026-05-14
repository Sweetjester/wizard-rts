class_name AssetPackConfig
extends Resource

const LOW_GROUND := &"LOW_GROUND"
const HIGH_GROUND := &"HIGH_GROUND"
const ROAD := &"ROAD"
const RAMP := &"RAMP"
const WATER := &"WATER"
const CLIFF_EDGE := &"CLIFF_EDGE"
const FOREST_BLOCKER := &"FOREST_BLOCKER"
const ROCK_BLOCKER := &"ROCK_BLOCKER"
const BASE_PLOT_MARKER := &"BASE_PLOT_MARKER"
const CONTENT_PLOT_MARKER := &"CONTENT_PLOT_MARKER"
const TREE := &"TREE"
const ROCK := &"ROCK"
const RUIN := &"RUIN"
const DECOR := &"DECOR"

@export var pack_id := ""
@export var display_name := ""
@export var tile_size := Vector2i(64, 64)
@export var pixel_art := true
@export_file("*.tres") var runtime_tileset_path := ""
@export var supported_visual_tags: Array[StringName] = []
@export var terrain_mappings: Dictionary = {}
@export var prop_mappings: Dictionary = {}
@export var unit_mappings: Dictionary = {}
@export var building_mappings: Dictionary = {}


func has_visual_tag(tag: StringName) -> bool:
	return supported_visual_tags.has(tag) \
		or terrain_mappings.has(tag) \
		or prop_mappings.has(tag) \
		or unit_mappings.has(tag) \
		or building_mappings.has(tag)


func resolve_mapping(tag: StringName) -> Dictionary:
	if terrain_mappings.has(tag):
		return terrain_mappings[tag]
	if prop_mappings.has(tag):
		return prop_mappings[tag]
	if unit_mappings.has(tag):
		return unit_mappings[tag]
	if building_mappings.has(tag):
		return building_mappings[tag]
	return {}


static func required_runtime_tags() -> Array[StringName]:
	return [
		LOW_GROUND,
		HIGH_GROUND,
		ROAD,
		RAMP,
		WATER,
		CLIFF_EDGE,
		FOREST_BLOCKER,
		ROCK_BLOCKER,
		BASE_PLOT_MARKER,
		CONTENT_PLOT_MARKER,
	]


static func prop_category_tags() -> Array[StringName]:
	return [
		TREE,
		ROCK,
		RUIN,
		DECOR,
	]
