extends SceneTree

const UNIT_COUNT := 180
const FRAME_COUNT := 180

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var map: Node = scene.get_node("MapGenerator")
	var wizard: Node2D = scene.get_node("Wizard")
	var treant_scene: PackedScene = load("res://scenes/units/treant.tscn")
	var parent := scene
	var spawned: Array[Node] = []
	var origin: Vector2i = map.world_to_cell(wizard.global_position)

	for i in UNIT_COUNT:
		var cell: Vector2i = map.nearest_walkable_cell(origin + Vector2i(i % 12, i / 12), 12)
		var treant := treant_scene.instantiate()
		parent.add_child(treant)
		treant.global_position = map.cell_to_world(cell)
		spawned.append(treant)

	var target_cell: Vector2i = map.nearest_walkable_cell(Vector2i(34, 32), 18)
	var target_world: Vector2 = map.cell_to_world(target_cell)
	var shared_path: Array[Vector2] = map.find_path_world(wizard.global_position, target_world)
	for i in spawned.size():
		var offset := Vector2(float(i % 12) * 24.0, float(i / 12) * 24.0)
		spawned[i].call("issue_shared_path_order", shared_path, offset)

	var started := Time.get_ticks_msec()
	for _frame in FRAME_COUNT:
		await physics_frame
	var elapsed := Time.get_ticks_msec() - started

	if elapsed > 9000:
		push_error("180-unit movement stress took %sms; expected under 9000ms" % elapsed)
		quit(1)
		return

	print("[UnitPerformanceSmokeTest] units=", spawned.size(), " frames=", FRAME_COUNT, " elapsed_ms=", elapsed)
	quit(0)
