extends Node2D

# Orange terrain indicator for the 2D map (added 2026-09-02).
#
# The 2D map gave the player no way to tell what they could actually walk on --
# a plateau read as a flat coloured box exactly like open ground, so cliffs were
# invisible until a unit refused to path up one.
#
# Two distinct things are marked, because they mean different things:
#
#   * CLIFF EDGES  -- walkable ground you cannot cross because of an unramped
#     height change. Drawn as a bright orange rim, because this is the one the
#     player needs to read at a glance: it is where movement AND line of sight
#     stop (see MapGenerator.has_line_of_sight).
#   * BLOCKED / WATER -- simply not ground. Drawn as a dim orange wash.
#
# PERFORMANCE: terrain does not change during a run, so this is baked ONCE into
# a one-texel-per-cell texture at map generation and then costs nothing per
# frame. It deliberately does not use _draw(): a per-cell draw pass is exactly
# what made fog of war too expensive to leave switched on.

# Deliberately a hue nothing else on the map uses. The ground tiles are still
# placeholder red/green/yellow blocks, so a muted orange simply disappeared
# into them -- this has to be unmistakable, not tasteful.
const CLIFF_COLOR := Color("#FF6A00")
const BLOCKED_COLOR := Color("#B4581F")

# Drawn ABOVE the fog, but masked BY the fog: a cliff you have explored stays
# marked, a cliff you have never seen does not. Terrain memory, the way RTS
# games handle it -- and necessary here, because a cliff cell is by definition
# the thing line of sight cannot reach, so a marker drawn under the fog is
# hidden by exactly the terrain it exists to warn about.
const OVERLAY_SHADER := """
shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D fog_map : filter_linear, repeat_disable;
uniform float has_fog = 0.0;
void fragment() {
	vec4 mark = texture(TEXTURE, UV);
	float seen = 1.0;
	if (has_fog > 0.5) {
		// Anything above "never seen" counts: explored is enough to remember
		// the shape of the ground.
		seen = smoothstep(0.05, 0.45, texture(fog_map, UV).r);
	}
	COLOR = vec4(mark.rgb, mark.a * seen);
}
"""

@export var map_path: NodePath = NodePath("../MapGenerator")
@export var fog_path: NodePath = NodePath("../FogOfWar")
@export var cliff_alpha: float = 0.62
@export var blocked_alpha: float = 0.16

var map: Node
var overlay_texture: ImageTexture

var _sprite: Sprite2D

func _ready() -> void:
	# Sits just above the fog layer (4095), which is the only workable slot:
	#
	#   * Below the fog, the fog veil crushed the marker to invisibility on the
	#     very cells it exists to warn about -- a cliff blocks line of sight, so
	#     cliff cells are the LEAST likely to be brightly lit.
	#   * Above the fog, it must be masked by the fog in-shader, or it would
	#     reveal the shape of terrain the player has never scouted.
	#
	# Godot clamps CanvasItem z_index to +/-4096, so 4096 is the ceiling. An
	# earlier attempt at 4200 was silently out of range and drew nothing at all.
	# Alpha is kept moderate so units standing on a lip still read through it.
	z_index = 4096
	z_as_relative = false
	call_deferred("_rebuild")

func _rebuild() -> void:
	map = get_node_or_null(map_path)
	if map == null or not bool(map.get("generation_complete")):
		# NEXT frame, not this one. call_deferred() from inside a deferred call lands
		# in the same frame's queue, so this retry never yielded -- once map
		# generation stopped finishing within a single frame it spun inside one
		# flush until the process segfaulted.
		get_tree().process_frame.connect(_rebuild, CONNECT_ONE_SHOT)
		return
	# Square-grid maps only: the overlay is an axis-aligned rect over the world
	# bounds, which does not hold for the legacy isometric map.
	if not bool(map.call("_uses_square_grid_map")):
		visible = false
		return
	if not map.has_method("is_impassable_cell"):
		visible = false
		return
	_build_texture()
	_build_sprite()

func _build_texture() -> void:
	var width: int = int(map.MAP_W)
	var height: int = int(map.MAP_H)
	var bytes := PackedByteArray()
	bytes.resize(width * height * 4)
	var index := 0
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			var color := Color(0, 0, 0, 0)
			if bool(map.call("is_cliff_edge_cell", cell)):
				color = Color(CLIFF_COLOR, cliff_alpha)
			elif bool(map.call("is_impassable_cell", cell)):
				color = Color(BLOCKED_COLOR, blocked_alpha)
			bytes[index] = int(color.r * 255.0)
			bytes[index + 1] = int(color.g * 255.0)
			bytes[index + 2] = int(color.b * 255.0)
			bytes[index + 3] = int(color.a * 255.0)
			index += 4
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes)
	overlay_texture = ImageTexture.create_from_image(image)

func _build_sprite() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.queue_free()
	var bounds: Rect2 = map.call("get_world_bounds")
	_sprite = Sprite2D.new()
	_sprite.name = "ImpassableSprite"
	_sprite.texture = overlay_texture
	_sprite.centered = false
	_sprite.position = bounds.position
	_sprite.scale = bounds.size / Vector2(float(map.MAP_W), float(map.MAP_H))
	# NEAREST on purpose. Fog wants soft edges; this wants a crisp boundary,
	# because its whole job is telling the player exactly which cell is the edge.
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader := Shader.new()
	shader.code = OVERLAY_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	# Masked by the fog texture: explored terrain keeps its marker, unexplored
	# terrain shows nothing. Without this, drawing above the fog would hand the
	# player a free map of every cliff on the level.
	var fog := get_node_or_null(fog_path)
	if fog != null and fog.has_method("get_fog_texture"):
		var fog_texture: Texture2D = fog.call("get_fog_texture")
		if fog_texture != null:
			material.set_shader_parameter("fog_map", fog_texture)
			material.set_shader_parameter("has_fog", 1.0)
	_sprite.material = material
	add_child(_sprite)

# Regenerating the map has to rebuild the bake.
func rebuild_for_new_map() -> void:
	call_deferred("_rebuild")
