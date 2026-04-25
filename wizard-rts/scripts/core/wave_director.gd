class_name WaveDirector
extends Node

signal phase_changed(phase: StringName)
signal wave_spawned(wave_index: int, count: int)

@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var enemy_scene: PackedScene = preload("res://scenes/units/vampire_mushroom_thrall.tscn")
@export var enabled: bool = true
@export var scouting_seconds: float = 90.0
@export var buildup_seconds: float = 240.0
@export var first_wave_seconds: float = 75.0
@export var wave_interval_seconds: float = 55.0
@export var base_wave_size: int = 6
@export var wave_size_growth: int = 3
@export var max_active_enemies: int = 90

var map_generator: Node
var phase: StringName = &"scouting"
var elapsed := 0.0
var next_wave_at := 75.0
var wave_index := 0

func _ready() -> void:
	map_generator = get_node_or_null(map_generator_path)
	next_wave_at = first_wave_seconds

func _process(delta: float) -> void:
	if not enabled:
		return
	elapsed += delta
	_update_phase()
	if elapsed >= next_wave_at:
		_spawn_wave()
		next_wave_at += wave_interval_seconds

func _update_phase() -> void:
	var next_phase := phase
	if elapsed >= scouting_seconds + buildup_seconds:
		next_phase = &"offense"
	elif elapsed >= scouting_seconds:
		next_phase = &"buildup"
	if next_phase != phase:
		phase = next_phase
		phase_changed.emit(phase)

func _spawn_wave() -> void:
	if map_generator == null or enemy_scene == null:
		return
	var active := 0
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 2:
			active += 1
	if active >= max_active_enemies:
		return
	wave_index += 1
	var spawn_count: int = mini(base_wave_size + wave_index * wave_size_growth, max_active_enemies - active)
	var spawns: Array = map_generator.get("enemy_spawns")
	if spawns.is_empty():
		return
	var parent := get_parent()
	for i in spawn_count:
		var spawn_cell: Vector2i = spawns[(i * 17 + wave_index * 11) % spawns.size()]
		var enemy := enemy_scene.instantiate()
		parent.add_child(enemy)
		enemy.global_position = map_generator.cell_to_world(map_generator.nearest_walkable_cell(spawn_cell, 10))
		enemy.call_deferred("issue_attack_move_order", _player_target_world())
	wave_spawned.emit(wave_index, spawn_count)

func _player_target_world() -> Vector2:
	var units := get_tree().get_nodes_in_group("units")
	for unit in units:
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1:
			return unit.global_position
	return Vector2.ZERO
