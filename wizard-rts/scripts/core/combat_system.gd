class_name CombatSystem
extends Node

signal unit_killed(unit: Node2D, killer: Node2D)

@export var tick_interval: float = 0.2
@export var spatial_bucket_size: float = 384.0

var _elapsed := 0.0
var _spatial := RTSSpatialIndex.new()

func _ready() -> void:
	_spatial.bucket_size = spatial_bucket_size

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < tick_interval:
		return
	var step := _elapsed
	_elapsed = 0.0
	_tick_combat(step)

func _tick_combat(delta: float) -> void:
	var units := get_tree().get_nodes_in_group("units")
	_spatial.rebuild(units)
	for unit in units:
		if not is_instance_valid(unit) or not unit.has_method("rts_combat_tick"):
			continue
		var range_px: float = max(float(unit.get("attack_range")) * 1.5, 256.0)
		unit.rts_combat_tick(delta, _spatial.query_radius(unit.global_position, range_px))
