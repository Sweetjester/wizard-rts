class_name CombatSystem
extends Node

signal unit_killed(unit: Node2D, killer: Node2D)

@export var tick_interval: float = 0.2
@export var spatial_bucket_size: float = 384.0
@export var rts_world_path: NodePath = NodePath("../RTSWorld")

var _elapsed := 0.0
var _spatial := RTSSpatialIndex.new()
var rts_world: RTSWorld

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
	for unit in units:
		if not is_instance_valid(unit) or not unit.has_method("rts_combat_tick"):
			continue
		var range_px: float = max(float(unit.get("attack_range")) * 1.5, 256.0)
		var nearby := rts_world.query_units(unit.global_position, range_px) if rts_world != null else _spatial.query_radius(unit.global_position, range_px)
		unit.rts_combat_tick(delta, nearby)
