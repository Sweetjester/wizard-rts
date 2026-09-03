class_name FogOfWar
extends Node2D

@export var map_path: NodePath = NodePath("../MapGenerator")
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var reveal_radius_cells: int = 8
@export var hard_fog_alpha: float = 0.94
@export var explored_fog_alpha: float = 0.62
@export var edge_fog_alpha: float = 0.72
@export var update_interval: float = 0.45
@export var draw_stride: int = 4
@export var reveal_enemy_vision: bool = false
@export var max_revealers_per_update: int = 96
# Revealers standing within this many cells of each other are merged into one
# reveal. Vision radius is 7-8 cells, so a clumped army's fields overlap almost
# completely -- computing all of them individually was the dominant fog cost.
# The reveal radius is widened by half the merge distance to compensate, which
# slightly over-reveals rather than leaving gaps between merged groups.
@export var revealer_merge_cells: int = 3
# How many reveal origins are processed per update. A full vision pass is spread
# over several updates instead of landing in one frame -- see the note on
# _update_visibility(). Results are only committed when a pass COMPLETES, so
# nothing flickers part-way through.
@export var origins_per_update: int = 3

const FOG_COLOR := Color("#050807")

# --- The vision texture -----------------------------------------------------
# Visibility is published as a one-texel-per-cell texture rather than being
# drawn directly. That single change is what makes fog both nicer AND cheaper:
#
#   * Nicer, because sampling it with LINEAR filtering gives soft, organic
#     edges for free. The old _draw() painted opaque diamonds per 4x4 block,
#     which is exactly why it looked blocky.
#   * Cheaper, because it is one small texture upload every update_interval
#     instead of thousands of draw_polygon calls every frame -- which is why it
#     could be switched off on this map type in the first place.
#   * And it means the 2D overlay and the 3D view read the SAME source. One
#     vision computation, two presentations, no chance of them disagreeing.
#
# Channel meaning (all of R, G and B carry it, so any sampler works):
#   0   = never seen
#   128 = explored, not currently visible
#   255 = currently visible
const FOG_UNSEEN := 0
const FOG_EXPLORED := 128
const FOG_VISIBLE := 255

var fog_texture: ImageTexture
var _fog_image: Image
var _fog_bytes: PackedByteArray
var _overlay_2d: Node2D
# Flat cell indices that were visible on the LAST update. Clearing and
# re-texturing walk this list instead of all MAP_W*MAP_H cells -- the revealed
# area is a few hundred cells, the map is 9216, and both loops used to run every
# single update. See the performance note on _update_visibility().
var _visible_indices: PackedInt32Array = PackedInt32Array()
# In-progress vision pass.
var _pass_origins: Array = []
var _pass_index := 0
var _pass_marks: PackedByteArray = PackedByteArray()
var _pass_indices: PackedInt32Array = PackedInt32Array()

var map: Node
var rts_world: RTSWorld
var explored: Array = []
var visible_cells: Array = []
var _elapsed := 0.0
var _revealer_cursor := 0

func _ready() -> void:
	z_index = 4096
	z_as_relative = false
	rts_world = get_node_or_null(rts_world_path)
	var display_manager := get_node_or_null("/root/DisplayManager")
	if display_manager != null and bool(display_manager.get("performance_mode")):
		update_interval = 0.65
		draw_stride = 5
		max_revealers_per_update = 64
	call_deferred("_rebuild")

func _process(delta: float) -> void:
	# NOTE: deliberately not gated on `visible`. With the texture overlay this
	# node is itself hidden (only its child sprite draws), and in the 3D view
	# every CanvasItem is hidden -- but vision still has to be computed, because
	# it drives entity visibility and the 3D veil as well as the 2D overlay.
	if _fog_image == null and not visible:
		return
	_elapsed += delta
	if _elapsed < update_interval:
		return
	_elapsed = 0.0
	_update_visibility()
	_refresh_fog_texture()

func _rebuild() -> void:
	map = get_node_or_null(map_path)
	if map == null or map.grid.is_empty():
		call_deferred("_rebuild")
		return
	# Fog stays off in the AI/benchmark map types -- they exist to measure
	# throughput, and hiding half the units would invalidate that. It is now ON
	# for seeded_grid_frontier, the real game map, which the texture-based
	# renderer above makes affordable.
	if str(map.get("map_type_id")) in ["ai_testing_ground", "fortress_ai_arena", "plot_generator_test"]:
		visible = false
		set_process(false)
		_show_all_entities()
		return
	# The legacy isometric map keeps the original per-cell _draw(); the shader
	# overlay assumes the square grid's axis-aligned world rect.
	var uses_texture_overlay: bool = bool(map.call("_uses_square_grid_map"))
	# NOTE: this node stays VISIBLE on the texture path. CanvasItem visibility
	# propagates to children, so hiding it would hide the overlay sprite that
	# does the actual drawing -- which is exactly what happened first time, and
	# looked like "fog is not working" rather than "the parent is hidden".
	# The old per-cell _draw() is suppressed inside _draw() instead.
	visible = true
	explored.clear()
	visible_cells.clear()
	for x in map.MAP_W:
		explored.append([])
		visible_cells.append([])
		for y in map.MAP_H:
			explored[x].append(false)
			visible_cells[x].append(false)
	_pass_marks.resize(map.MAP_W * map.MAP_H)
	if uses_texture_overlay:
		_build_fog_texture()
		_build_2d_overlay()
	_update_visibility()

# PERFORMANCE, 2026-09-02. Fog was switched on for the live map and immediately
# caused stutter. Measured at 63ms per update with 60 units. Four things were
# wrong, in descending order of cost:
#
#   1. _has_line_of_sight() called _line_cells(), which ALLOCATED a fresh array
#      for every one of the ~300 cells tested per revealer.
#   2. Every unit revealed individually, even standing on top of each other,
#      although their vision fields overlap almost entirely.
#   3. Two 9216-cell loops per update -- one to clear visibility, one to rebuild
#      the fog texture from scratch.
#   4. get_property_list() reflection per unit, twice, which is the same
#      pattern as the 2026-08-23 HUD regression.
#
# After 1-4: 12ms. Still a single spike landing in one frame, so a full vision
# pass is now spread across several updates (origins_per_update) and only
# committed when it finishes -- so the fog never flickers mid-pass.
func _update_visibility() -> void:
	if map == null:
		return
	if _pass_index == 0:
		_pass_origins = _collect_reveal_origins()
		_pass_marks.fill(0)
		_pass_indices.clear()
	var budget: int = maxi(1, origins_per_update)
	while _pass_index < _pass_origins.size() and budget > 0:
		var origin: Dictionary = _pass_origins[_pass_index]
		_reveal_line_of_sight(origin["cell"], int(origin["radius"]))
		_pass_index += 1
		budget -= 1
	if _pass_index < _pass_origins.size():
		return
	_commit_vision_pass()
	_pass_index = 0

# One entry per merged group of revealers, so a clumped army costs a handful of
# reveals rather than one per unit.
func _collect_reveal_origins() -> Array:
	var origins: Array = []
	var seen: Dictionary = {}
	var revealers := _vision_revealers()
	if revealers.is_empty():
		return origins
	var merge: int = maxi(1, revealer_merge_cells)
	for unit in revealers:
		if origins.size() >= max_revealers_per_update:
			break
		if not is_instance_valid(unit) or not (unit is Node2D):
			continue
		var owner_value: Variant = unit.get("owner_player_id")
		if not reveal_enemy_vision and (owner_value == null or int(owner_value) != 1):
			continue
		var cell: Vector2i = map.world_to_cell(unit.global_position)
		var key := Vector2i(cell.x / merge, cell.y / merge)
		if seen.has(key):
			continue
		seen[key] = true
		origins.append({"cell": cell, "radius": _sight_radius_for(unit) + merge / 2})
	return origins

# Swaps the finished pass in. Everything here is O(lit area), never O(map):
# cells that stopped being visible come off the old list, new ones come from the
# pass list, and the texture is patched per changed cell.
func _commit_vision_pass() -> void:
	for index in _visible_indices:
		if index >= 0 and index < _pass_marks.size() and _pass_marks[index] == 1:
			continue
		var cx: int = index / int(map.MAP_H)
		var cy: int = index % int(map.MAP_H)
		visible_cells[cx][cy] = false
		if _fog_image != null:
			_write_fog_texel(index, FOG_EXPLORED)
	for index in _pass_indices:
		var nx: int = index / int(map.MAP_H)
		var ny: int = index % int(map.MAP_H)
		visible_cells[nx][ny] = true
		explored[nx][ny] = true
		if _fog_image != null:
			_write_fog_texel(index, FOG_VISIBLE)
	_visible_indices = _pass_indices.duplicate()
	_apply_entity_visibility()
	queue_redraw()

# Buildings see as well as units do. Without this a base was a blind spot: the
# player could stand a tower in the dark and it revealed nothing around itself.
func _structure_revealers() -> Array[Node2D]:
	var structures: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var owner_value: Variant = node.get("owner_player_id")
		if owner_value == null:
			continue
		if not reveal_enemy_vision and int(owner_value) != 1:
			continue
		structures.append(node as Node2D)
	return structures

func _vision_revealers() -> Array[Node2D]:
	if rts_world != null:
		var revealers: Array[Node2D] = []
		revealers.append_array(rts_world.all_units() if reveal_enemy_vision else rts_world.units_for_owner(1))
		revealers.append_array(_structure_revealers())
		return revealers
	var revealers: Array[Node2D] = []
	for unit in get_tree().get_nodes_in_group("units"):
		if unit is Node2D:
			revealers.append(unit)
	return revealers

func _reveal_line_of_sight(center: Vector2i, radius: int) -> void:
	if not map.is_in_bounds(center):
		return
	var radius_sq := radius * radius
	var viewer_height := int(map.get_height(center)) if map.has_method("get_height") else 0
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var cell := Vector2i(x, y)
			if not map.is_in_bounds(cell):
				continue
			var delta := cell - center
			if delta.length_squared() > radius_sq:
				continue
			if not _has_line_of_sight(center, cell, viewer_height):
				continue
			var index: int = x * int(map.MAP_H) + y
			if _pass_marks[index] == 0:
				_pass_marks[index] = 1
				_pass_indices.append(index)

# Delegates to MapGenerator.has_line_of_sight() so vision and combat targeting
# can never disagree about what is visible -- see the note there.
func _has_line_of_sight(from_cell: Vector2i, to_cell: Vector2i, viewer_height: int) -> bool:
	return bool(map.call("has_line_of_sight", from_cell, to_cell, viewer_height))

func _build_fog_texture() -> void:
	_fog_bytes = PackedByteArray()
	_fog_bytes.resize(map.MAP_W * map.MAP_H * 4)
	_fog_image = Image.create_from_data(map.MAP_W, map.MAP_H, false, Image.FORMAT_RGBA8, _fog_bytes)
	fog_texture = ImageTexture.create_from_image(_fog_image)

# The byte buffer is now maintained incrementally as cells change, so this only
# has to hand the finished buffer to the GPU. It used to rebuild all 9216 texels
# from scratch on every update, which was the single largest cost in the fog.
func _refresh_fog_texture() -> void:
	if _fog_image == null or fog_texture == null:
		return
	_fog_image.set_data(map.MAP_W, map.MAP_H, false, Image.FORMAT_RGBA8, _fog_bytes)
	fog_texture.update(_fog_image)

# Cell index -> the four RGBA bytes for that texel. Image rows are y-major, so a
# cell at (x, y) is texel (x + y * MAP_W), not (x * MAP_H + y) -- the flat index
# used for the visible list is deliberately a different packing, and this is
# where the two are reconciled.
func _write_fog_texel(index: int, value: int) -> void:
	var cx: int = index / int(map.MAP_H)
	var cy: int = index % int(map.MAP_H)
	var offset: int = (cy * int(map.MAP_W) + cx) * 4
	_fog_bytes[offset] = value
	_fog_bytes[offset + 1] = value
	_fog_bytes[offset + 2] = value
	_fog_bytes[offset + 3] = 255

# Public, so the 3D view can veil the same cells without recomputing anything.
func is_world_position_visible(world_position: Vector2) -> bool:
	if map == null or visible_cells.is_empty():
		return true
	var cell: Vector2i = map.world_to_cell(world_position)
	if not map.is_in_bounds(cell):
		return false
	return visible_cells[cell.x][cell.y]

func get_fog_texture() -> Texture2D:
	return fog_texture

const FOG_SHADER_2D := """
shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D fog_map : filter_linear, repeat_disable;
uniform vec4 fog_color : source_color = vec4(0.02, 0.031, 0.027, 1.0);
uniform float explored_alpha = 0.58;
uniform float drift_strength = 0.006;
uniform float drift_speed = 0.09;
void fragment() {
	// A slow warp of the lookup, so the fog line breathes instead of sitting
	// as a hard static boundary. Cheap: it perturbs the UV, not the geometry.
	float drift = sin(UV.x * 14.0 + TIME * drift_speed * 3.0) * cos(UV.y * 11.0 - TIME * drift_speed * 2.2);
	float v = texture(fog_map, UV + vec2(drift, -drift) * drift_strength).r;
	float a = mix(1.0, explored_alpha, smoothstep(0.0, 0.5, v));
	a = mix(a, 0.0, smoothstep(0.5, 1.0, v));
	COLOR = vec4(fog_color.rgb, a);
}
"""

func _build_2d_overlay() -> void:
	if _overlay_2d != null and is_instance_valid(_overlay_2d):
		return
	var bounds: Rect2 = map.call("get_world_bounds")
	var sprite := Sprite2D.new()
	sprite.name = "FogOverlay2D"
	sprite.texture = fog_texture
	sprite.centered = false
	sprite.position = bounds.position
	sprite.scale = bounds.size / Vector2(float(map.MAP_W), float(map.MAP_H))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = 4095
	sprite.z_as_relative = false
	var shader := Shader.new()
	shader.code = FOG_SHADER_2D
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fog_map", fog_texture)
	sprite.material = material
	add_child(sprite)
	_overlay_2d = sprite

func _apply_entity_visibility() -> void:
	# In the 3D view Map3DView owns unit visibility (all units are hidden and
	# drawn as billboards instead), so fog must not touch it at all -- checked
	# once here rather than once per unit.
	if rts_world != null and is_instance_valid(rts_world) and rts_world.presentation_3d:
		return
	var entities := rts_world.all_units() if rts_world != null else _vision_revealers()
	for node in entities:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var owner_value: Variant = node.get("owner_player_id")
		if owner_value == null or int(owner_value) == 1:
			# Player units are never concealed, so there is nothing to write.
			continue
		var cell: Vector2i = map.world_to_cell((node as Node2D).global_position)
		var revealed: bool = map.is_in_bounds(cell) and visible_cells[cell.x][cell.y]
		if node.visible != revealed:
			node.visible = revealed

func _show_all_entities() -> void:
	var entities := rts_world.all_units() if rts_world != null else _vision_revealers()
	for node in entities:
		if is_instance_valid(node):
			node.visible = true
	for structure in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure):
			structure.visible = true

func _line_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := to_cell - from_cell
	var steps: int = maxi(abs(delta.x), abs(delta.y))
	if steps <= 0:
		return [from_cell]
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var cell := Vector2i(roundi(lerpf(float(from_cell.x), float(to_cell.x), t)), roundi(lerpf(float(from_cell.y), float(to_cell.y), t)))
		if cells.is_empty() or cells[cells.size() - 1] != cell:
			cells.append(cell)
	return cells

func _sight_radius_for(unit: Node) -> int:
	# Plain property read. This runs once per revealer per update and used to do
	# a full get_property_list() scan to fetch a single StringName.
	# Units expose `unit_archetype`; structures expose `archetype`.
	var archetype_value: Variant = unit.get("unit_archetype")
	if archetype_value == null:
		archetype_value = unit.get("archetype")
	if archetype_value == null:
		return reveal_radius_cells
	var definition := UnitCatalog.get_definition(StringName(archetype_value))
	return int(definition.get("sight_radius_cells", reveal_radius_cells))

func _property_or(node: Node, property_name: String, fallback: Variant) -> Variant:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return node.get(property_name)
	return fallback

func _draw() -> void:
	# The texture overlay replaces this per-cell drawing entirely on square-grid
	# maps. The legacy isometric map still uses the diamonds below.
	if _fog_image != null:
		return
	if map == null or explored.is_empty():
		return
	for x in range(0, map.MAP_W, draw_stride):
		for y in range(0, map.MAP_H, draw_stride):
			if _block_visible(x, y):
				continue
			var alpha := explored_fog_alpha if _block_explored(x, y) else hard_fog_alpha
			if _block_touches_visible(x, y):
				alpha = minf(alpha, edge_fog_alpha)
			draw_polygon(_block_diamond(Vector2i(x, y), draw_stride), PackedColorArray([_alpha(FOG_COLOR, alpha)]))

func _block_visible(start_x: int, start_y: int) -> bool:
	for x in range(start_x, mini(start_x + draw_stride, map.MAP_W)):
		for y in range(start_y, mini(start_y + draw_stride, map.MAP_H)):
			if visible_cells[x][y]:
				return true
	return false

func _block_explored(start_x: int, start_y: int) -> bool:
	for x in range(start_x, mini(start_x + draw_stride, map.MAP_W)):
		for y in range(start_y, mini(start_y + draw_stride, map.MAP_H)):
			if explored[x][y]:
				return true
	return false

func _block_touches_visible(start_x: int, start_y: int) -> bool:
	var margin := draw_stride
	for x in range(maxi(0, start_x - margin), mini(start_x + draw_stride + margin, map.MAP_W)):
		for y in range(maxi(0, start_y - margin), mini(start_y + draw_stride + margin, map.MAP_H)):
			if visible_cells[x][y]:
				return true
	return false

func _block_diamond(cell: Vector2i, stride: int) -> PackedVector2Array:
	var last := maxi(1, stride) - 1
	var north: Vector2 = map.cell_to_world(cell)
	var east: Vector2 = map.cell_to_world(cell + Vector2i(last, 0))
	var south: Vector2 = map.cell_to_world(cell + Vector2i(last, last))
	var west: Vector2 = map.cell_to_world(cell + Vector2i(0, last))
	return PackedVector2Array([
		north + Vector2(0, -36),
		east + Vector2(68, 0),
		south + Vector2(0, 36),
		west + Vector2(-68, 0),
	])

func _cell_diamond(pos: Vector2, scale: float) -> PackedVector2Array:
	return PackedVector2Array([
		pos + Vector2(0, -32) * scale,
		pos + Vector2(64, 0) * scale,
		pos + Vector2(0, 32) * scale,
		pos + Vector2(-64, 0) * scale,
	])

func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
