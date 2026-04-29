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
var _last_tick_units := 0
var _last_tick_budget := 0
var _last_tick_candidate_queries := 0
var _last_tick_candidate_total := 0
var _last_tick_ms := 0.0

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
	var started := Time.get_ticks_usec()
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
		_last_tick_units = 0
		_last_tick_budget = 0
		_last_tick_candidate_queries = 0
		_last_tick_candidate_total = 0
		_last_tick_ms = float(Time.get_ticks_usec() - started) / 1000.0
		return
	var budget: int = mini(units.size(), _budget_for_count(units.size()))
	var scaled_delta := delta * (float(units.size()) / float(maxi(1, budget)))
	var candidate_queries := 0
	var candidate_total := 0
	for offset in budget:
		var unit: Node2D = units[posmod(_unit_cursor + offset, units.size())]
		if not is_instance_valid(unit) or not unit.has_method("rts_combat_tick"):
			continue
		var range_px: float = max(float(unit.get("attack_range")) * 1.5, 256.0)
		var candidate_limit := _candidate_limit_for_count(units.size())
		var nearby: Array[Node2D] = []
		var needs_query := true
		if unit.has_method("needs_combat_query"):
			needs_query = bool(unit.call("needs_combat_query"))
		if needs_query:
			nearby = rts_world.query_enemy_attackables(unit.global_position, range_px, int(unit.get("owner_player_id")), candidate_limit) if rts_world != null and rts_world.has_method("query_enemy_attackables") else _spatial.query_radius(unit.global_position, range_px)
			candidate_queries += 1
			candidate_total += nearby.size()
		unit.rts_combat_tick(scaled_delta, nearby)
	_unit_cursor = posmod(_unit_cursor + budget, units.size())
	_last_tick_units = units.size()
	_last_tick_budget = budget
	_last_tick_candidate_queries = candidate_queries
	_last_tick_candidate_total = candidate_total
	_last_tick_ms = float(Time.get_ticks_usec() - started) / 1000.0

func _candidate_limit_for_count(unit_count: int) -> int:
	if unit_count >= 2400:
		return 6
	if unit_count >= 1600:
		return 6
	if unit_count >= 900:
		return 8
	if unit_count >= 600:
		return 6
	if unit_count >= 300:
		return 6
	if unit_count >= 120:
		return 8
	return 16

func _budget_for_count(unit_count: int) -> int:
	var base_budget := max_units_per_tick
	if unit_count >= 2400:
		base_budget = mini(base_budget, 10)
	elif unit_count >= 1600:
		base_budget = mini(base_budget, 14)
	elif unit_count >= 1200:
		base_budget = mini(base_budget, 18)
	elif unit_count >= 900:
		base_budget = mini(base_budget, 24)
	elif unit_count >= 600:
		base_budget = mini(base_budget, 28)
	elif unit_count >= 300:
		base_budget = mini(base_budget, 32)
	elif unit_count >= 120:
		base_budget = mini(base_budget, 48)
	return maxi(1, base_budget)

func get_combat_telemetry() -> Dictionary:
	return {
		"combat_tick_units": _last_tick_units,
		"combat_tick_budget": _last_tick_budget,
		"combat_candidate_queries": _last_tick_candidate_queries,
		"combat_candidate_total": _last_tick_candidate_total,
		"combat_avg_candidates": float(_last_tick_candidate_total) / float(maxi(1, _last_tick_candidate_queries)),
		"combat_tick_ms": _last_tick_ms,
	}
