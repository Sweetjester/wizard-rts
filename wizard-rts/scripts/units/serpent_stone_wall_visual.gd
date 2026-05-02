extends Node2D

var cells: Array[Vector2i] = []
var terrain: Node
var serpent: Node
var owner_player_id := 1

func configure(new_cells: Array[Vector2i], map_node: Node, player_id: int, source_serpent: Node = null) -> void:
	cells = new_cells.duplicate()
	terrain = map_node
	serpent = source_serpent
	owner_player_id = player_id
	queue_redraw()

func _draw() -> void:
	if terrain == null or not is_instance_valid(terrain):
		return
	var body := Color("#6F8587")
	var edge := Color("#0E2C32")
	var glow := Color("#7DDDE8")
	match owner_player_id:
		2:
			glow = Color("#E85A5A")
		3:
			glow = Color("#7DDDE8")
	for index in range(cells.size()):
		var world := _cell_world(cells[index])
		var local := to_local(world)
		var rect := Rect2(local - Vector2(30, 22), Vector2(60, 44))
		draw_rect(rect, body.darkened(0.12 + float(index % 2) * 0.08), true)
		draw_rect(rect, edge, false, 2.0)
		draw_line(rect.position + Vector2(8, 12), rect.position + Vector2(52, 30), Color(glow.r, glow.g, glow.b, 0.65), 2.0)
		draw_circle(local + Vector2(10, -4), 3.0, glow)
	_draw_health_bar()

func _draw_health_bar() -> void:
	if serpent == null or not is_instance_valid(serpent) or cells.is_empty():
		return
	var health := float(serpent.get("health"))
	var max_health := maxf(1.0, float(serpent.get("max_health")))
	var first := to_local(_cell_world(cells[0]))
	var last := to_local(_cell_world(cells[cells.size() - 1]))
	var midpoint := (first + last) * 0.5 + Vector2(0, -42)
	var width := maxf(58.0, first.distance_to(last) + 58.0)
	var rect := Rect2(midpoint - Vector2(width * 0.5, 5), Vector2(width, 6))
	draw_rect(rect, Color(0.03, 0.05, 0.04, 0.82), true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(health / max_health, 0.0, 1.0), rect.size.y)), Color("#7BC47F"), true)
	draw_rect(rect, Color("#0E2C32"), false, 1.0)

func _cell_world(cell: Vector2i) -> Vector2:
	if terrain != null and is_instance_valid(terrain) and terrain.has_method("cell_to_world"):
		return terrain.call("cell_to_world", cell)
	return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)
