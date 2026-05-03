extends SceneTree

const DEOM_UNITS := [
	&"deom_scout",
	&"deom_blade",
	&"deom_crosshirran",
	&"deom_hammer",
	&"deom_glaive",
	&"deom_odden",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/units/deom_legion_unit.tscn")
	if scene == null:
		push_error("Deom Legion unit scene failed to load")
		quit(1)
		return
	var ok := true
	for archetype in DEOM_UNITS:
		var definition := UnitCatalog.get_definition(archetype)
		if definition.is_empty():
			push_error("Missing Deom unit definition: %s" % str(archetype))
			ok = false
			continue
		var unit := scene.instantiate()
		unit.set("owner_player_id", 2)
		if unit.has_method("configure_enemy"):
			unit.call("configure_enemy", archetype)
		root.add_child(unit)
		if unit.get("unit_archetype") != archetype:
			push_error("Deom unit configured as %s, expected %s" % [str(unit.get("unit_archetype")), str(archetype)])
			ok = false
		if int(unit.get("max_health")) <= 0 or int(unit.get("attack_damage")) <= 0:
			push_error("Deom unit has invalid combat stats: %s" % str(archetype))
			ok = false
		unit.queue_free()
	if not ok:
		quit(1)
		return
	print("[DeomLegionSmokeTest] Deom Legion roster loads and configures correctly.")
	quit(0)
