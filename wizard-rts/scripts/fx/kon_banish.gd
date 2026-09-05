extends Node

var remaining := 5.0
var _layer := 0
var _mask := 0
var _was_visible := true

func _ready() -> void:
	var unit := get_parent()
	_layer=int(unit.get("collision_layer"))
	_mask=int(unit.get("collision_mask"))
	_was_visible=unit.visible
	unit.set_meta("kon_banished",true)
	unit.set("collision_layer",0)
	unit.set("collision_mask",0)
	unit.call("issue_stop_order")
	unit.visible=false

func _process(delta: float) -> void:
	remaining-=delta
	if remaining<=0.0:
		restore()

func restore() -> void:
	var unit := get_parent()
	if unit==null: return
	unit.remove_meta("kon_banished")
	unit.set("collision_layer",_layer)
	unit.set("collision_mask",_mask)
	unit.visible=_was_visible
	queue_free()
