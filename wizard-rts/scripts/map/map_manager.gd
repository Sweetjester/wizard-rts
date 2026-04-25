class_name MapManager
extends Node2D

var zones: Array = []
var economy_zones: Array = []
var spawn_safe_zones: Array = []
var enemy_spawn_zones: Array = []
var high_ground_zones: Array = []
var generated_plots: Array = []
var generated_base_plots: Array = []
@export var selection_seed: int = 20260425
@export var map_generator_path: NodePath = NodePath("MapGenerator")
var _rng := DeterministicRng.new()

func _ready() -> void:
	_rng = DeterministicRng.new(selection_seed)
	call_deferred("_register_zones")

func _register_zones() -> void:
	zones.clear()
	economy_zones.clear()
	spawn_safe_zones.clear()
	enemy_spawn_zones.clear()
	high_ground_zones.clear()
	generated_plots.clear()
	generated_base_plots.clear()

	for zone in get_tree().get_nodes_in_group("zones"):
		var data = zone.get_zone_data()
		zones.append(data)
		match data["type"]:
			ZoneType.Type.ECONOMY_PLOT:
				economy_zones.append(data)
			ZoneType.Type.SPAWN_SAFE:
				spawn_safe_zones.append(data)
			ZoneType.Type.ENEMY_SPAWN:
				enemy_spawn_zones.append(data)
			ZoneType.Type.HIGH_GROUND:
				high_ground_zones.append(data)

	var map_generator = get_node_or_null(map_generator_path)
	if map_generator != null and map_generator.has_method("get_plots"):
		generated_plots = map_generator.get_plots()
		generated_base_plots = map_generator.get_base_plots()
		economy_zones.append_array(map_generator.get_economy_zones())
		for plot in generated_base_plots:
			spawn_safe_zones.append({
				"type": ZoneType.Type.SPAWN_SAFE,
				"plot_id": plot["id"],
				"plot_name": plot["name"],
				"position": map_generator.cell_to_world(plot["anchor"]),
				"difficulty": plot["difficulty"],
			})

	print("[MapManager] Zones registered: ", zones.size())
	print("[MapManager] Economy plots: ", economy_zones.size())
	print("[MapManager] High ground zones: ", high_ground_zones.size())
	print("[MapManager] Generated plots: ", generated_plots.size())

func get_random_spawn_position() -> Vector2:
	if spawn_safe_zones.is_empty():
		push_warning("[MapManager] No spawn safe zones found — defaulting to origin")
		return Vector2.ZERO
	var zone = spawn_safe_zones[_rng.range_int(0, spawn_safe_zones.size() - 1)]
	return zone["position"]

func get_economy_plots() -> Array:
	return economy_zones

func get_enemy_spawns() -> Array:
	return enemy_spawn_zones

func get_generated_plots() -> Array:
	return generated_plots

func get_generated_base_plots() -> Array:
	return generated_base_plots
