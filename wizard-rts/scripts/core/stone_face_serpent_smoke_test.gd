extends SceneTree

class FakeTerrain:
	extends Node
	var dynamic_blockers: Array[Vector2i] = []
	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)
	func world_to_cell(world: Vector2) -> Vector2i:
		return Vector2i(roundi(world.x / 64.0), roundi(world.y / 64.0))
	func is_walkable_cell(_cell: Vector2i) -> bool:
		return true
	func add_dynamic_blockers(cells: Array[Vector2i]) -> void:
		dynamic_blockers.append_array(cells)
	func remove_dynamic_blockers(cells: Array[Vector2i]) -> void:
		for cell in cells:
			dynamic_blockers.erase(cell)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/units/stone_face_serpent.tscn")
	if scene == null:
		push_error("Stone Face Serpent scene failed to load")
		quit(1)
		return
	var holder := Node2D.new()
	root.add_child(holder)
	var terrain := FakeTerrain.new()
	terrain.name = "MapGenerator"
	holder.add_child(terrain)
	var world := RTSWorld.new()
	world.name = "RTSWorld"
	holder.add_child(world)
	var unit := scene.instantiate()
	holder.add_child(unit)
	await process_frame
	if unit.get("unit_archetype") != &"stone_face_serpent":
		push_error("Stone Face Serpent did not report the correct archetype")
		quit(1)
		return
	if not unit.has_method("activate_stone_form"):
		push_error("Stone Face Serpent missing Stone Form active")
		quit(1)
		return
	unit.set("selected", true)
	if not bool(unit.call("activate_stone_form")):
		push_error("Stone Face Serpent could not activate Stone Form")
		quit(1)
		return
	await process_frame
	var cells: Array[Vector2i] = [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5)]
	unit.call("_enter_stone_form", cells)
	await process_frame
	if unit.global_position != terrain.cell_to_world(cells[0]):
		push_error("Stone Face Serpent did not move to the start of the stone wall")
		quit(1)
		return
	if world.count_units_all() != 0:
		push_error("Stone Face Serpent remains registered as a normal unit while in stone form")
		quit(1)
		return
	if world.all_structures().size() != cells.size():
		push_error("Stone wall segments were not registered as targetable structures")
		quit(1)
		return
	unit.queue_free()
	holder.queue_free()
	print("[StoneFaceSerpentSmokeTest] Stone Face Serpent stone form is positioned and targetable.")
	quit(0)
