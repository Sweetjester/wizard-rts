extends Node

# A small block landscape for the demo world.
#
# Implements exactly the three calls BlockNavWorld makes of MapGenerator --
# is_walkable_cell, get_height, is_cliff_edge_cell -- and nothing else. That is
# the whole terrain contract, which is itself worth noticing: the elevation
# system needs almost nothing from the map generator, so pointing it at the real
# one later is a substitution rather than a port.
#
# Heights use MapGenerator's own scale (0 low, 2 high) plus a 4 tier, so a demo
# plateau reads at the same vertical scale a real map would.

const MAP_W := 48
const MAP_H := 48

# Plateau rect -> {height, ramps}. Ramp cells are the ONLY places the height
# change can be crossed; everything else on the border is a cliff.
const PLATEAUS := [
	{"rect": Rect2i(26, 4, 14, 12), "height": 2,
		"ramps": [Vector2i(25, 9), Vector2i(26, 9), Vector2i(25, 10), Vector2i(26, 10)]},
	{"rect": Rect2i(30, 6, 6, 6), "height": 4,
		"ramps": [Vector2i(29, 8), Vector2i(30, 8), Vector2i(29, 9), Vector2i(30, 9)]},
	{"rect": Rect2i(4, 30, 12, 12), "height": 2,
		"ramps": [Vector2i(9, 29), Vector2i(9, 30), Vector2i(10, 29), Vector2i(10, 30)]},
]

# A pond, to prove unwalkable cells simply produce no node at all.
const WATER := Rect2i(18, 26, 6, 5)

func is_walkable_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_W or cell.y >= MAP_H:
		return false
	return not WATER.has_point(cell)

func get_height(cell: Vector2i) -> int:
	var height := 0
	for plateau in PLATEAUS:
		if (plateau["rect"] as Rect2i).has_point(cell):
			height = maxi(height, int(plateau["height"]))
	return height

func is_cliff_edge_cell(cell: Vector2i) -> bool:
	for plateau in PLATEAUS:
		if (plateau["ramps"] as Array).has(cell):
			return false
	var height := get_height(cell)
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if get_height(cell + offset) != height:
			return true
	return false

# Every column that has ground, for the block renderer. Terrain is drawn as
# solid columns from 0 up to the surface, which is what makes a plateau read as
# a cliff rather than a floating slab.
func column_blocks() -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for x in MAP_W:
		for y in MAP_H:
			var cell := Vector2i(x, y)
			if not is_walkable_cell(cell):
				continue
			for level in range(0, get_height(cell) + 1):
				cells.append(Vector3i(x, level, y))
	return cells
