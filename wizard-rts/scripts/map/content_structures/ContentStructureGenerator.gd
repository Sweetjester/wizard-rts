class_name ContentStructureGenerator
extends RefCounted

const STRUCTURE_ABANDONED_WIZARD_MONOLITH := "ABANDONED_WIZARD_MONOLITH"
const CELL_WALKABLE := "walkable"
const CELL_WALL := "wall"
const CELL_BLOCKER := "blocker"
const CELL_GAP := "gap"
const CELL_STAIR := "stair"
const CELL_DECOR := "decor"

var _rng := DeterministicRng.new(1)


func generate_abandoned_wizard_monolith(structure_id: String, exterior_rect: Rect2i, seed_value: int, options: Dictionary = {}) -> Dictionary:
	_rng = DeterministicRng.new(seed_value)
	var footprint := clampi(int(options.get("footprint_size", 16)), 12, 20)
	var floor_count := clampi(int(options.get("floor_count", 3)), 1, 3)
	var floor_height := maxf(1.0, float(options.get("floor_height", 1.8)))
	var room_density := clampf(float(options.get("room_density", 0.45)), 0.0, 1.0)
	var gap_density := clampf(float(options.get("gap_density", 0.035)), 0.0, 0.14)
	var decor_density := clampf(float(options.get("decor_density", 0.35)), 0.0, 1.0)
	var size := Vector2i(footprint, footprint)
	exterior_rect = Rect2i(exterior_rect.position, size)
	var entrance_local := Vector2i(size.x / 2, size.y - 1)
	var stair_cells := _scaled_stair_cells(size)
	var floors: Array[Dictionary] = []
	floors.append(_make_floor_0(size, entrance_local, stair_cells[0], room_density, gap_density, decor_density))
	if floor_count >= 2:
		floors.append(_make_floor_1(size, stair_cells[0], stair_cells[1], room_density, gap_density, decor_density))
	if floor_count >= 3:
		floors.append(_make_floor_2(size, stair_cells[1], room_density, gap_density, decor_density))
	for floor in floors:
		_repair_floor_connectivity(floor)
	var stair_links: Array[Dictionary] = []
	if floor_count >= 2:
		stair_links.append({"from_floor": 0, "from_cell": stair_cells[0], "to_floor": 1, "to_cell": stair_cells[0]})
	if floor_count >= 3:
		stair_links.append({"from_floor": 1, "from_cell": stair_cells[1], "to_floor": 2, "to_cell": stair_cells[1]})
	_mark_stairs(floors, stair_links)
	var structure := {
		"id": structure_id,
		"structure_type": STRUCTURE_ABANDONED_WIZARD_MONOLITH,
		"footprint_size": size,
		"exterior_rect": exterior_rect,
		"floor_count": floors.size(),
		"floor_height": floor_height,
		"room_density": room_density,
		"gap_density": gap_density,
		"decor_density": decor_density,
		"entrance_cells": [exterior_rect.position + entrance_local],
		"entrance_local_cells": [entrance_local],
		"stair_links": stair_links,
		"floors": floors,
		"discovered_floors": [0],
		"occupied_floors": [],
		"current_floor_focus": 0,
		"validation": {},
	}
	structure["validation"] = validate_structure(structure)
	return structure


func validate_structure(structure: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var floors: Array = structure.get("floors", [])
	if floors.is_empty():
		errors.append("no floors")
	var entrance_local: Vector2i = structure.get("entrance_local_cells", [Vector2i(-1, -1)])[0]
	if floors.size() > 0 and not _floor_has_walkable(floors[0], entrance_local):
		errors.append("entrance does not connect to floor 0")
	for floor_value in floors:
		var floor: Dictionary = floor_value
		var walkable: Array = floor.get("walkable_cells", [])
		if walkable.is_empty():
			errors.append("floor %s has no walkable cells" % floor.get("floor_index", -1))
		elif _reachable_floor_cells(floor, walkable[0]).size() < walkable.size():
			errors.append("floor %s has isolated walkable regions" % floor.get("floor_index", -1))
	for link_value in structure.get("stair_links", []):
		var link: Dictionary = link_value
		var from_floor := int(link.get("from_floor", -1))
		var to_floor := int(link.get("to_floor", -1))
		var from_cell: Vector2i = link.get("from_cell", Vector2i(-1, -1))
		var to_cell: Vector2i = link.get("to_cell", Vector2i(-1, -1))
		if from_floor < 0 or from_floor >= floors.size() or to_floor < 0 or to_floor >= floors.size():
			errors.append("stair link floor out of range")
			continue
		if not _floor_has_walkable(floors[from_floor], from_cell):
			errors.append("stair from cell is not walkable")
		if not _floor_has_walkable(floors[to_floor], to_cell):
			errors.append("stair to cell is not walkable")
	if floors.size() > 1 and structure.get("stair_links", []).size() < floors.size() - 1:
		errors.append("floor chain missing stair links")
	return {
		"passed": errors.is_empty(),
		"errors": errors,
		"walkable_counts": _walkable_counts(floors),
		"stair_count": structure.get("stair_links", []).size(),
	}


func _scaled_stair_cells(size: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(maxi(2, size.x - 4), maxi(2, size.y - 4)),
		Vector2i(maxi(2, size.x / 4), maxi(2, size.y / 4)),
	]


func _make_floor_0(size: Vector2i, entrance_local: Vector2i, stair_cell: Vector2i, room_density: float, gap_density: float, decor_density: float) -> Dictionary:
	var floor := _new_floor(0, size, "Entrance Chamber")
	for x in range(1, size.x - 1):
		for y in range(1, size.y - 1):
			_add_walkable(floor, Vector2i(x, y))
	_add_walkable(floor, entrance_local)
	_carve_path(floor, entrance_local, stair_cell)
	var protected := _protected_cells([entrance_local, stair_cell], floor)
	_scatter_gaps(floor, protected, gap_density)
	_scatter_blockers(floor, protected, room_density * 0.035)
	floor["rooms"].append({"id": "entrance_chamber", "rect": Rect2i(Vector2i(2, 2), Vector2i(size.x - 4, size.y - 4)), "role": "open tactical entry"})
	_add_decor_markers(floor, "broken_entrance", decor_density)
	return floor


func _make_floor_1(size: Vector2i, lower_stair: Vector2i, upper_stair: Vector2i, room_density: float, gap_density: float, decor_density: float) -> Dictionary:
	var floor := _new_floor(1, size, "Narrow Chambers")
	var west_width := maxi(4, size.x / 2 - 1)
	var east_width := maxi(4, size.x - west_width - 3)
	var rooms := [
		Rect2i(1, 1, west_width, maxi(4, size.y / 2 - 1)),
		Rect2i(size.x - east_width - 1, 2, east_width, maxi(4, size.y / 2 - 2)),
		Rect2i(2, maxi(6, size.y - 5), size.x - 4, 3),
	]
	for rect in rooms:
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				_add_walkable(floor, Vector2i(x, y))
	_carve_path(floor, lower_stair, upper_stair)
	var protected := _protected_cells([lower_stair, upper_stair], floor)
	_scatter_blockers(floor, protected, room_density * 0.055)
	_scatter_gaps(floor, protected, gap_density * 0.55)
	floor["rooms"].append({"id": "west_chamber", "rect": rooms[0], "role": "tight skirmish room"})
	floor["rooms"].append({"id": "east_chamber", "rect": rooms[1], "role": "pillar room"})
	floor["rooms"].append({"id": "south_choke", "rect": rooms[2], "role": "choke connector"})
	_add_decor_markers(floor, "pillar", decor_density)
	return floor


func _make_floor_2(size: Vector2i, stair_cell: Vector2i, room_density: float, gap_density: float, decor_density: float) -> Dictionary:
	var floor := _new_floor(2, size, "Ritual Core")
	var center := Vector2i(size.x / 2, size.y / 2)
	var radius := maxf(4.5, float(size.x) * 0.36)
	for x in range(2, size.x - 2):
		for y in range(2, size.y - 2):
			var cell := Vector2i(x, y)
			var center_distance := Vector2(cell - center).length()
			if center_distance <= radius:
				_add_walkable(floor, cell)
	_carve_path(floor, stair_cell, center)
	var core_cells := [center, center + Vector2i.LEFT, center + Vector2i.RIGHT, center + Vector2i.UP, center + Vector2i.DOWN]
	for cell in core_cells:
		_add_walkable(floor, cell)
		floor["decor_markers"].append({"cell": cell, "kind": "ritual_core"})
	var protected := _protected_cells([stair_cell, center], floor)
	_scatter_blockers(floor, protected, room_density * 0.04)
	_scatter_gaps(floor, protected, gap_density * 0.45)
	floor["rooms"].append({"id": "ritual_core", "rect": Rect2i(2, 2, size.x - 4, size.y - 4), "role": "reward and identity chamber"})
	_add_decor_markers(floor, "ritual_rune", decor_density)
	return floor


func _new_floor(floor_index: int, size: Vector2i, label: String) -> Dictionary:
	var wall_cells: Array[Vector2i] = []
	for x in range(size.x):
		wall_cells.append(Vector2i(x, 0))
		wall_cells.append(Vector2i(x, size.y - 1))
	for y in range(1, size.y - 1):
		wall_cells.append(Vector2i(0, y))
		wall_cells.append(Vector2i(size.x - 1, y))
	return {
		"floor_index": floor_index,
		"label": label,
		"size": size,
		"walkable_cells": [],
		"wall_cells": wall_cells,
		"blocker_cells": [],
		"gap_cells": [],
		"stair_cells": [],
		"rooms": [],
		"decor_markers": [],
	}


func _add_walkable(floor: Dictionary, cell: Vector2i) -> void:
	if not floor["walkable_cells"].has(cell):
		floor["walkable_cells"].append(cell)
	floor["wall_cells"].erase(cell)
	floor["gap_cells"].erase(cell)
	floor["blocker_cells"].erase(cell)


func _add_blocker(floor: Dictionary, cell: Vector2i) -> void:
	_add_walkable(floor, cell)
	if not floor["blocker_cells"].has(cell):
		floor["blocker_cells"].append(cell)


func _add_gap(floor: Dictionary, cell: Vector2i) -> void:
	floor["walkable_cells"].erase(cell)
	floor["blocker_cells"].erase(cell)
	if not floor["gap_cells"].has(cell):
		floor["gap_cells"].append(cell)


func _carve_path(floor: Dictionary, start: Vector2i, target: Vector2i) -> void:
	var cell := start
	var guard := 0
	while cell != target and guard < 256:
		_add_walkable(floor, cell)
		if cell.x != target.x:
			cell.x += 1 if target.x > cell.x else -1
		else:
			cell.y += 1 if target.y > cell.y else -1
		guard += 1
	_add_walkable(floor, target)


func _protected_cells(anchors: Array[Vector2i], floor: Dictionary) -> Dictionary:
	var protected := {}
	for anchor in anchors:
		for x in range(anchor.x - 1, anchor.x + 2):
			for y in range(anchor.y - 1, anchor.y + 2):
				var cell := Vector2i(x, y)
				if _floor_bounds_has(floor, cell):
					protected[cell] = true
	var walkable: Array = floor.get("walkable_cells", [])
	for cell_value in walkable:
		var cell: Vector2i = cell_value
		if cell.x == floor.get("size", Vector2i.ZERO).x / 2 or cell.y == floor.get("size", Vector2i.ZERO).y / 2:
			protected[cell] = true
	return protected


func _scatter_gaps(floor: Dictionary, protected: Dictionary, density: float) -> void:
	if density <= 0.0:
		return
	var walkable: Array = floor.get("walkable_cells", []).duplicate()
	for cell_value in walkable:
		var cell: Vector2i = cell_value
		if protected.has(cell):
			continue
		if _hash_floor_cell(floor, cell, 31) < density:
			_add_gap(floor, cell)


func _scatter_blockers(floor: Dictionary, protected: Dictionary, density: float) -> void:
	if density <= 0.0:
		return
	var walkable: Array = floor.get("walkable_cells", []).duplicate()
	for cell_value in walkable:
		var cell: Vector2i = cell_value
		if protected.has(cell) or floor.get("gap_cells", []).has(cell):
			continue
		if _hash_floor_cell(floor, cell, 73) < density:
			_add_blocker(floor, cell)


func _add_decor_markers(floor: Dictionary, kind: String, density: float) -> void:
	var walkable: Array = floor.get("walkable_cells", [])
	var max_count := maxi(1, int(float(walkable.size()) * density * 0.025))
	var count := 0
	for cell_value in walkable:
		var cell: Vector2i = cell_value
		if count >= max_count:
			return
		if floor.get("blocker_cells", []).has(cell) or floor.get("gap_cells", []).has(cell):
			continue
		if _hash_floor_cell(floor, cell, 107) < 0.08:
			floor["decor_markers"].append({"cell": cell, "kind": kind})
			count += 1


func _floor_bounds_has(floor: Dictionary, cell: Vector2i) -> bool:
	var size: Vector2i = floor.get("size", Vector2i.ZERO)
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func _repair_floor_connectivity(floor: Dictionary) -> void:
	var walkable: Array = floor.get("walkable_cells", [])
	if walkable.is_empty():
		return
	var start: Vector2i = walkable[0]
	var reachable := _reachable_floor_cells(floor, start)
	for cell_value in walkable.duplicate():
		var cell: Vector2i = cell_value
		if not reachable.has(cell):
			_carve_path(floor, start, cell)
			reachable = _reachable_floor_cells(floor, start)


func _hash_floor_cell(floor: Dictionary, cell: Vector2i, salt: int) -> float:
	var floor_index := int(floor.get("floor_index", 0))
	var value := int(abs(cell.x * 928371 + cell.y * 523127 + floor_index * 8191 + salt * 131071)) % 1000
	return float(value) / 1000.0


func _mark_stairs(floors: Array[Dictionary], links: Array[Dictionary]) -> void:
	for link in links:
		var from_floor := int(link["from_floor"])
		var to_floor := int(link["to_floor"])
		var from_cell: Vector2i = link["from_cell"]
		var to_cell: Vector2i = link["to_cell"]
		_add_walkable(floors[from_floor], from_cell)
		_add_walkable(floors[to_floor], to_cell)
		if not floors[from_floor]["stair_cells"].has(from_cell):
			floors[from_floor]["stair_cells"].append(from_cell)
		if not floors[to_floor]["stair_cells"].has(to_cell):
			floors[to_floor]["stair_cells"].append(to_cell)


func _floor_has_walkable(floor: Dictionary, cell: Vector2i) -> bool:
	return floor.get("walkable_cells", []).has(cell) and not floor.get("gap_cells", []).has(cell)


func _reachable_floor_cells(floor: Dictionary, start: Vector2i) -> Dictionary:
	var walkable := {}
	for cell in floor.get("walkable_cells", []):
		if not floor.get("gap_cells", []).has(cell):
			walkable[cell] = true
	var visited := {}
	if not walkable.has(start):
		return visited
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next_cell: Vector2i = cell + offset
			if walkable.has(next_cell) and not visited.has(next_cell):
				visited[next_cell] = true
				queue.append(next_cell)
	return visited


func _walkable_counts(floors: Array) -> Array[int]:
	var counts: Array[int] = []
	for floor_value in floors:
		var floor: Dictionary = floor_value
		counts.append(floor.get("walkable_cells", []).size())
	return counts
