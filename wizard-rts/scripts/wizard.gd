extends "res://scripts/units/rts_unit.gd"

@export var treant_scene: PackedScene = preload("res://scenes/units/treant.tscn")
@export var summon_count: int = 12
@export var summon_radius_cells: int = 3

func _ready() -> void:
	super()
	move_speed = 190.0
	selection_radius = 26.0
	collision_separation = 24.0
	print("[Wizard] Ready at ", global_position)

func summon_treants() -> Array[Node]:
	var summoned: Array[Node] = []
	if terrain == null or treant_scene == null:
		return summoned

	var origin: Vector2i = terrain.world_to_cell(global_position)
	var cells := _summon_cells(origin)
	var parent := get_parent()
	for cell in cells:
		var treant := treant_scene.instantiate()
		parent.add_child(treant)
		treant.global_position = terrain.cell_to_world(cell)
		summoned.append(treant)
	print("[Wizard] Summoned ", summoned.size(), " treants")
	return summoned

func _summon_cells(origin: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for radius in range(1, summon_radius_cells + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				if cells.size() >= summon_count:
					return cells
				if abs(x - origin.x) != radius and abs(y - origin.y) != radius:
					continue
				var cell := Vector2i(x, y)
				if terrain.is_walkable_cell(cell):
					cells.append(cell)
	return cells

func _draw() -> void:
	if has_node("ArtSprite"):
		_draw_selection_and_path()
		return
	draw_circle(Vector2(0, 8), 15, Color(0, 0, 0, 0.32))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 0), Vector2(10, 0),
		Vector2(13, 20), Vector2(-13, 20)
	]), Color("#2D5A3E"))
	draw_circle(Vector2(0, -4), 9, Color("#D6C7AE"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -11), Vector2(8, -11),
		Vector2(3, -31), Vector2(-3, -31)
	]), Color("#5C0F14"))
	draw_circle(Vector2(0, -23), 3.0, Color("#7DDDE8"))
	draw_circle(Vector2(-3, -5), 1.5, Color("#0A1612"))
	draw_circle(Vector2(3, -5), 1.5, Color("#0A1612"))
	_draw_selection_and_path()
