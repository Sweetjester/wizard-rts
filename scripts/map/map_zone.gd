class_name MapZone
extends Area2D

@export var zone_type: ZoneType.Type = ZoneType.Type.NONE
@export var plot_count: int = 1
@export var difficulty: float = 1.0

func _ready() -> void:
    add_to_group("zones")
    monitoring = false
    monitorable = true

func get_zone_data() -> Dictionary:
    return {
        "type": zone_type,
        "plot_count": plot_count,
        "difficulty": difficulty,
        "position": global_position
    }
