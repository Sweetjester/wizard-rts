class_name EconomyManager
extends Node

signal resources_changed(player_id: int, resources: Dictionary)
signal economy_building_registered(player_id: int, plot_id: String, cell: Vector2i)

@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var starting_bio: int = 1000
@export var income_interval: float = 1.0
@export var fallback_absorber_income: int = 12

var map_generator: Node
var resources: Dictionary = {}
var economy_buildings: Array[Dictionary] = []
var _elapsed := 0.0

func _ready() -> void:
	map_generator = get_node_or_null(map_generator_path)
	_ensure_player(1)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < income_interval:
		return
	_elapsed = 0.0
	_apply_income()

func can_afford(player_id: int, costs: Dictionary) -> bool:
	_ensure_player(player_id)
	for resource_name in costs.keys():
		if int(resources[player_id].get(resource_name, 0)) < int(costs[resource_name]):
			return false
	return true

func spend(player_id: int, costs: Dictionary) -> bool:
	if not can_afford(player_id, costs):
		return false
	for resource_name in costs.keys():
		resources[player_id][resource_name] = int(resources[player_id].get(resource_name, 0)) - int(costs[resource_name])
	resources_changed.emit(player_id, resources[player_id].duplicate())
	return true

func add_resource(player_id: int, resource_name: StringName, amount: int) -> void:
	_ensure_player(player_id)
	resources[player_id][resource_name] = int(resources[player_id].get(resource_name, 0)) + amount
	resources_changed.emit(player_id, resources[player_id].duplicate())

func register_economy_building(player_id: int, plot_id: String, cell: Vector2i, archetype: StringName = &"bio_absorber") -> bool:
	if not _is_valid_economy_cell(cell):
		return false
	for building in economy_buildings:
		if building["cell"] == cell:
			return false
	economy_buildings.append({
		"player_id": player_id,
		"plot_id": plot_id,
		"cell": cell,
		"archetype": archetype,
	})
	economy_building_registered.emit(player_id, plot_id, cell)
	return true

func get_resources(player_id: int = 1) -> Dictionary:
	_ensure_player(player_id)
	return resources[player_id].duplicate()

func _apply_income() -> void:
	var income_by_player: Dictionary = {}
	for building in economy_buildings:
		var player_id := int(building["player_id"])
		var definition := UnitCatalog.get_definition(building.get("archetype", &"bio_absorber"))
		var income := int(definition.get("income_per_tick", fallback_absorber_income))
		income_by_player[player_id] = int(income_by_player.get(player_id, 0)) + income
	for player_id in income_by_player.keys():
		add_resource(int(player_id), &"bio", int(income_by_player[player_id]))

func _is_valid_economy_cell(cell: Vector2i) -> bool:
	if map_generator == null or not map_generator.has_method("get_economy_zones"):
		return false
	for zone in map_generator.get_economy_zones():
		for economy_cell in zone.get("economy_spaces", []):
			if economy_cell == cell:
				return true
	return false

func _ensure_player(player_id: int) -> void:
	if resources.has(player_id):
		return
	resources[player_id] = {
		&"bio": starting_bio,
		&"essence": 0,
	}
