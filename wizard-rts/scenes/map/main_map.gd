extends Node2D

var zones: Array = []
var economy_zones: Array = []
var spawn_safe_zones: Array = []
var enemy_spawn_zones: Array = []
var high_ground_zones: Array = []

func _ready() -> void:
	call_deferred("_register_zones")

func _register_zones() -> void:
	zones.clear()
	economy_zones.clear()
	spawn_safe_zones.clear()
	enemy_spawn_zones.clear()
	high_ground_zones.clear()

	for zone in get_tree().get_nodes_in_group("zones"):
		var data = zone.get_zone_data()
		zones.append(data)
		match data["type"]:
			1:
				economy_zones.append(data)
			2:
				spawn_safe_zones.append(data)
			6:
				enemy_spawn_zones.append(data)
			3:
				high_ground_zones.append(data)

	print("[MapManager] Zones registered: ", zones.size())
	print("[MapManager] Economy plots: ", economy_zones.size())
	print("[MapManager] High ground zones: ", high_ground_zones.size())

func get_random_spawn_position() -> Vector2:
	if spawn_safe_zones.is_empty():
		push_warning("[MapManager] No spawn safe zones found — defaulting to origin")
		return Vector2.ZERO
	var zone = spawn_safe_zones[randi() % spawn_safe_zones.size()]
	return zone["position"]

func get_economy_plots() -> Array:
	return economy_zones

func get_enemy_spawns() -> Array:
	return enemy_spawn_zones
