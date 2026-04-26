class_name VampiricMushroomForest
extends Node2D

@export var map_path: NodePath = NodePath("../MapGenerator")
@export var style_seed: int = 0
@export var mushroom_density: int = 34
@export var canopy_density: int = 48
@export var wisp_density: int = 5

const ABYSSAL_MOSS := Color("#0A1612")
const DAMP_EARTH := Color("#142420")
const FOREST_FLOOR := Color("#1E3A2D")
const LIVING_MOSS := Color("#2D5A3E")
const FERN_LIGHT := Color("#4A8A5C")
const SPORE_GLOW := Color("#7BC47F")

const DRIED_BLOOD := Color("#2B0608")
const HEART_WOUND := Color("#5C0F14")
const VAMPIRE_BLOOM := Color("#8B1A1F")
const FRESH_KILL := Color("#C13030")
const SPORE_BLOOM := Color("#E85A5A")

const DEEP_POOL := Color("#0E2C32")
const ALGAE_BLOOM := Color("#1A4F5C")
const WISP_LIGHT := Color("#3FA8B5")
const SOUL_SPARK := Color("#7DDDE8")

const CHARCOAL_BARK := Color("#1A1410")
const WET_BARK := Color("#332820")
const DRY_WOOD := Color("#5C4838")
const OLD_BONE := Color("#8A7560")
const PALE_MUSHROOM := Color("#D6C7AE")

var map: Node
var mushrooms: Array[Dictionary] = []
var canopies: Array[Dictionary] = []
var giant_mushrooms: Array[Dictionary] = []
var blood_blooms: Array[Dictionary] = []
var wisps: Array[Dictionary] = []
var pools: Array[Dictionary] = []
var height_shadows: Array[Dictionary] = []
var _effective_seed := 1

func _ready() -> void:
	z_index = 4
	y_sort_enabled = true
	var display_manager := get_node_or_null("/root/DisplayManager")
	if display_manager != null and bool(display_manager.get("performance_mode")):
		mushroom_density = int(float(mushroom_density) * 0.55)
		canopy_density = int(float(canopy_density) * 0.55)
		wisp_density = int(float(wisp_density) * 0.5)
	set_process(false)
	call_deferred("_rebuild")

func _rebuild() -> void:
	map = get_node_or_null(map_path)
	if map == null or map.grid.is_empty():
		call_deferred("_rebuild")
		return
	_effective_seed = int(map.get_seed_value()) if style_seed == 0 and map.has_method("get_seed_value") else style_seed
	_apply_tile_palette()
	_build_features()
	print("[VampiricMushroomForest] mushrooms:", mushrooms.size(),
		" | blood blooms:", blood_blooms.size(),
		" | wisps:", wisps.size(),
		" | canopy:", canopies.size())
	queue_redraw()

func _apply_tile_palette() -> void:
	map.layer_low.modulate = Color("#D4E0D3")
	map.layer_mid.modulate = Color("#EEF9E9")
	map.layer_high.modulate = Color("#FFF3D7")

func _build_features() -> void:
	mushrooms.clear()
	canopies.clear()
	giant_mushrooms.clear()
	blood_blooms.clear()
	wisps.clear()
	pools.clear()
	height_shadows.clear()

	for x in map.MAP_W:
		for y in map.MAP_H:
			var cell := Vector2i(x, y)
			var elevation: int = map.grid[x][y]
			_add_height_shadow(cell, elevation)
			if elevation == map.E_WATER:
				_add_pool(cell)
				continue

			if _roll(cell, canopy_density) and _is_forest_edge(cell):
				_add_canopy(cell)
			if _roll(cell, mushroom_density) and not _is_base_spawn(cell):
				_add_mushroom(cell, elevation)
			if _is_blood_site(cell, elevation):
				_add_blood_bloom(cell, elevation)
			if _roll(cell, wisp_density) and _near_water(cell):
				_add_wisp(cell)

	for zone in map.get_economy_zones():
		_seed_economy_bloom(zone["rect"])
	var choke_index := 0
	for choke in map.get_chokepoints():
		if choke_index % 14 == 0:
			_add_wisp(choke)
		choke_index += 1
	if map.has_method("get_landmarks"):
		for landmark in map.get_landmarks():
			if str(landmark.get("kind", "")) == "giant_mushroom":
				_add_giant_mushroom(landmark)

func _draw() -> void:
	if map == null:
		return
	_draw_ground_haze()
	for shadow in height_shadows:
		_draw_height_shadow(shadow)
	for pool in pools:
		_draw_pool(pool)
	for bloom in blood_blooms:
		_draw_blood_bloom(bloom)
	for canopy in canopies:
		_draw_canopy(canopy)
	for giant in giant_mushrooms:
		_draw_giant_mushroom(giant)
	for mushroom in mushrooms:
		_draw_mushroom(mushroom)
	for wisp in wisps:
		_draw_wisp(wisp)

func _draw_ground_haze() -> void:
	var corners := [
		map.cell_to_world(Vector2i(-2, -2)),
		map.cell_to_world(Vector2i(map.MAP_W + 2, -2)),
		map.cell_to_world(Vector2i(map.MAP_W + 2, map.MAP_H + 2)),
		map.cell_to_world(Vector2i(-2, map.MAP_H + 2)),
	]
	draw_polygon(PackedVector2Array(corners), PackedColorArray([_alpha(ABYSSAL_MOSS.darkened(0.25), 0.22)]))

func _draw_pool(pool: Dictionary) -> void:
	var pos: Vector2 = pool["pos"]
	var radius: float = pool["radius"]
	draw_circle(pos, radius, _alpha(DEEP_POOL, 0.58))
	draw_circle(pos + Vector2(0, -3), radius * 0.54, _alpha(ALGAE_BLOOM, 0.28))

func _draw_height_shadow(shadow: Dictionary) -> void:
	var pos: Vector2 = shadow["pos"]
	var width: float = shadow["width"]
	draw_ellipse(pos, width, 10.0, _alpha(CHARCOAL_BARK, 0.32))

func _draw_canopy(canopy: Dictionary) -> void:
	var pos: Vector2 = canopy["pos"]
	var radius: float = canopy["radius"]
	draw_circle(pos + Vector2(0, -20), radius, _alpha(ABYSSAL_MOSS, 0.82))
	draw_circle(pos + Vector2(-radius * 0.35, -22), radius * 0.55, _alpha(DAMP_EARTH, 0.78))
	draw_circle(pos + Vector2(radius * 0.28, -25), radius * 0.45, _alpha(FOREST_FLOOR, 0.72))

func _draw_mushroom(mushroom: Dictionary) -> void:
	var pos: Vector2 = mushroom["pos"]
	var scale: float = mushroom["scale"]
	var stem_h := 16.0 * scale
	var cap_w := 18.0 * scale
	var cap_h := 8.0 * scale
	draw_line(pos + Vector2(0, 4), pos + Vector2(0, -stem_h), PALE_MUSHROOM, max(2.0, 4.0 * scale))
	draw_circle(pos + Vector2(0, -stem_h), cap_w * 0.48, VAMPIRE_BLOOM)
	draw_circle(pos + Vector2(-cap_w * 0.24, -stem_h - 1), cap_h * 0.4, _alpha(SPORE_BLOOM, 0.75))
	if mushroom["glow"]:
		draw_circle(pos + Vector2(0, -stem_h + 1), cap_w * 0.75, _alpha(SPORE_GLOW, 0.16))

func _draw_giant_mushroom(mushroom: Dictionary) -> void:
	var pos: Vector2 = mushroom["pos"]
	var radius: float = mushroom["radius"]
	var stem_h: float = mushroom["height"]
	draw_line(pos + Vector2(0, 20), pos + Vector2(0, -stem_h), PALE_MUSHROOM.darkened(0.08), max(10.0, radius * 0.16))
	draw_circle(pos + Vector2(0, -stem_h), radius, _alpha(VAMPIRE_BLOOM, 0.96))
	draw_circle(pos + Vector2(-radius * 0.26, -stem_h - radius * 0.12), radius * 0.45, _alpha(SPORE_BLOOM, 0.64))
	draw_circle(pos + Vector2(radius * 0.12, -stem_h + radius * 0.02), radius * 0.18, _alpha(SOUL_SPARK, 0.34))
	for i in 9:
		var angle := float(i) * TAU / 9.0
		var dot := pos + Vector2(cos(angle) * radius * 0.46, -stem_h + sin(angle) * radius * 0.22)
		draw_circle(dot, radius * 0.035, _alpha(PALE_MUSHROOM, 0.75))

func _draw_blood_bloom(bloom: Dictionary) -> void:
	var pos: Vector2 = bloom["pos"]
	var radius: float = bloom["radius"]
	draw_circle(pos, radius, _alpha(DRIED_BLOOD, 0.72))
	draw_circle(pos + Vector2(-radius * 0.18, -2), radius * 0.55, _alpha(HEART_WOUND, 0.88))
	draw_circle(pos + Vector2(radius * 0.18, -4), radius * 0.24, _alpha(FRESH_KILL, 0.7))
	for i in 5:
		var angle: float = float(i) * TAU / 5.0 + float(bloom["phase"])
		var tip := pos + Vector2(cos(angle), sin(angle) * 0.55) * radius * 0.92
		draw_line(pos, tip, _alpha(VAMPIRE_BLOOM, 0.65), 2.0)

func _draw_wisp(wisp: Dictionary) -> void:
	var phase := float(wisp["phase"])
	var pos: Vector2 = wisp["pos"] + Vector2(0, sin(phase) * 3.0)
	var radius: float = wisp["radius"]
	draw_circle(pos, radius * 2.2, _alpha(WISP_LIGHT, 0.11))
	draw_circle(pos, radius, _alpha(WISP_LIGHT, 0.45))
	draw_circle(pos + Vector2(0, -1), radius * 0.35, _alpha(SOUL_SPARK, 0.9))

func _add_pool(cell: Vector2i) -> void:
	if not _roll(cell, 480):
		return
	pools.append({
		"pos": map.cell_to_world(cell) + _offset(cell, 9.0),
		"radius": 12.0 + float(_hash(cell, 10) % 8),
	})

func _add_height_shadow(cell: Vector2i, elevation: int) -> void:
	if elevation <= map.E_LOW:
		return
	var south := cell + Vector2i(0, 1)
	if not map.is_in_bounds(south):
		return
	if map.get_height(south) >= map.get_height(cell):
		return
	height_shadows.append({
		"pos": map.cell_to_world(cell) + Vector2(0, 18),
		"width": 22.0 + float(elevation) * 8.0,
	})

func _add_canopy(cell: Vector2i) -> void:
	canopies.append({
		"pos": map.cell_to_world(cell) + _offset(cell, 12.0),
		"radius": 26.0 + float(_hash(cell, 7) % 15),
	})

func _add_mushroom(cell: Vector2i, elevation: int) -> void:
	var h := _hash(cell, 3)
	mushrooms.append({
		"pos": map.cell_to_world(cell) + _offset(cell, 14.0),
		"scale": 0.65 + float(h % 7) * 0.12 + float(max(0, elevation)) * 0.07,
		"glow": h % 9 == 0,
	})

func _add_giant_mushroom(landmark: Dictionary) -> void:
	var cell: Vector2i = landmark["cell"]
	giant_mushrooms.append({
		"pos": map.cell_to_world(cell),
		"radius": 42.0 + float(landmark.get("radius", 2)) * 14.0,
		"height": 58.0 + float(landmark.get("height", 2)) * 16.0,
	})

func _add_blood_bloom(cell: Vector2i, _elevation: int) -> void:
	blood_blooms.append({
		"pos": map.cell_to_world(cell) + _offset(cell, 8.0),
		"radius": 10.0 + float(_hash(cell, 5) % 9),
		"phase": float(_hash(cell, 11) % 628) / 100.0,
	})

func _add_wisp(cell: Vector2i) -> void:
	if not map.is_walkable_cell(cell):
		cell = map.nearest_walkable_cell(cell)
	if not map.is_walkable_cell(cell):
		return
	wisps.append({
		"pos": map.cell_to_world(cell) + _offset(cell, 10.0) + Vector2(0, -18),
		"radius": 3.0 + float(_hash(cell, 17) % 4),
		"phase": float(_hash(cell, 23) % 628) / 100.0,
	})

func _seed_economy_bloom(rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if map.is_walkable_cell(cell) and _roll(cell, 180):
				_add_blood_bloom(cell, map.grid[x][y])
			elif map.is_walkable_cell(cell) and _roll(cell, 140):
				_add_mushroom(cell, map.grid[x][y])

func _is_blood_site(cell: Vector2i, elevation: int) -> bool:
	if elevation == map.E_WATER:
		return false
	return (cell.x * 7 + cell.y * 11) % 97 == 0 or _roll(cell, 5)

func _is_forest_edge(cell: Vector2i) -> bool:
	return cell.x <= 5 or cell.x >= map.MAP_W - 6 or cell.y <= 5 or cell.y >= map.MAP_H - 6

func _is_base_spawn(cell: Vector2i) -> bool:
	for zone in map.get_economy_zones():
		var rect: Rect2i = zone["rect"]
		if rect.has_point(cell):
			return true
	return false

func _near_water(cell: Vector2i) -> bool:
	for x in range(cell.x - 2, cell.x + 3):
		for y in range(cell.y - 2, cell.y + 3):
			var neighbor := Vector2i(x, y)
			if map.is_in_bounds(neighbor) and map.grid[x][y] == map.E_WATER:
				return true
	return false

func _roll(cell: Vector2i, threshold_per_mille: int) -> bool:
	return _hash(cell, 0) % 1000 < threshold_per_mille

func _hash(cell: Vector2i, salt: int) -> int:
	var value := int(_effective_seed)
	value = int((value ^ (cell.x * 73856093)) & 0x7fffffff)
	value = int((value ^ (cell.y * 19349663)) & 0x7fffffff)
	value = int((value ^ (salt * 83492791)) & 0x7fffffff)
	return value

func _offset(cell: Vector2i, amount: float) -> Vector2:
	var h := _hash(cell, 31)
	var ox := (float(h % 200) / 100.0 - 1.0) * amount
	var oy := (float((h / 200) % 200) / 100.0 - 1.0) * amount * 0.55
	return Vector2(ox, oy)

func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
