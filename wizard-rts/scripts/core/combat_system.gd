class_name CombatSystem
extends Node

signal unit_killed(unit: Node2D, killer: Node2D)

@export var tick_interval: float = 0.2
@export var spatial_bucket_size: float = 384.0
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var max_units_per_tick: int = 180

var _elapsed := 0.0
var _spatial := RTSSpatialIndex.new()
var rts_world: RTSWorld
var _unit_cursor := 0

func _ready() -> void:
	_spatial.bucket_size = spatial_bucket_size
	rts_world = get_node_or_null(rts_world_path)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < tick_interval:
		return
	var step := _elapsed
	_elapsed = 0.0
	_tick_combat(step)

func _tick_combat(delta: float) -> void:
	var units: Array[Node2D] = []
	if rts_world != null:
		rts_world.rebuild_spatial()
		units = rts_world.all_units()
	else:
		for unit in get_tree().get_nodes_in_group("units"):
			if unit is Node2D:
				units.append(unit)
		_spatial.rebuild(units)
	if units.is_empty():
		return
	var budget: int = mini(units.size(), max_units_per_tick)
	var scaled_delta := delta * (float(units.size()) / float(maxi(1, budget)))
	for offset in budget:
		var unit: Node2D = units[posmod(_unit_cursor + offset, units.size())]
		if not is_instance_valid(unit) or not unit.has_method("rts_combat_tick"):
			continue
		var range_px: float = max(float(unit.get("attack_range")) * 1.5, 256.0)
		var candidate_limit := _candidate_limit_for_count(units.size())
		var nearby := rts_world.query_units(unit.global_position, range_px, -1, candidate_limit) if rts_world != null else _spatial.query_radius(unit.global_position, range_px)
		unit.rts_combat_tick(scaled_delta, nearby)
	_unit_cursor = posmod(_unit_cursor + budget, units.size())

func _candidate_limit_for_count(unit_count: int) -> int:
	if unit_count >= 900:
		return 36
	if unit_count >= 600:
		return 48
	if unit_count >= 300:
		return 72
	return -1
