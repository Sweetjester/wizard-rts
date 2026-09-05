class_name Map3DView
extends Node3D

# The 3D presentation layer for the normal game mode (added 2026-08-31).
#
# DESIGN, and the reason this is not built inside map_3d_renderer.gd:
# `map_3d_renderer.gd` is a preview tool. It generates its own map, runs its own
# toy unit probe, and owns its own camera and input. This project has twice lost
# work by building gameplay against it (see the 2026-08-19 Decisions Log entry).
#
# So nothing here changes the game. The 2D simulation in main_map.tscn stays
# exactly as it is and remains authoritative for every unit position, every
# order and every combat result. This node only:
#
#   1. asks the preview renderer to draw the LIVE MapGenerator's terrain in 3D,
#   2. mirrors the live 2D units into a MultiMesh each frame,
#   3. owns a 3D RTS camera,
#   4. translates mouse position on the ground plane back into 2D simulation
#      coordinates, so the existing SelectionController keeps working unchanged.
#
# If this node is deleted the game still runs. That is the property that keeps
# the 3D mode from becoming a second, diverging implementation.

const RENDERER_SCRIPT := preload("res://scripts/map/map_3d_renderer.gd")
const UNIT_MESH_HEIGHT := 1.5
const UNIT_MESH_RADIUS := 0.32
# Camera pitch and field of view, and why they are what they are.
#
# Both were wrong until 2026-09-04, and together they were the reason 2D
# billboards looked pasted onto the 3D ground rather than standing on it.
#
# PITCH matches the angle the 2D art is DRAWN at. Every sprite has a viewing
# angle baked into it -- the barracks shows a nearly undistorted front wall and a
# shallow roof plane, which is about 38 degrees above horizontal. A full
# billboard (BILLBOARD_ENABLED) shows that art face-on, so it only reads as
# standing on the ground when the camera pitch equals the art's own angle. It was
# 52, so every sprite was 14 degrees out.
#
# FOV was never set at all, so it was Godot's 75 degree default. That is very
# wide, and the consequence is worse than it sounds: at 75 degrees the ground is
# seen anywhere from 14 to 89 degrees WITHIN A SINGLE FRAME, while every
# billboard presents the same face everywhere on screen. No art angle can match
# that, and it is why sprites looked fine in one part of the frame and wrong in
# another. Narrowing to 35 cuts the spread from 75 degrees to 35.
#
# Strategy games either use a narrow FOV or go orthographic for exactly this
# reason. Orthographic would cut the spread to zero; it is the logical next step
# if these values are not enough, and is noted in the Roadmap.
const DEFAULT_CAMERA_PITCH_DEGREES := -38.0
const DEFAULT_CAMERA_FOV := 35.0
var camera_pitch_degrees := DEFAULT_CAMERA_PITCH_DEGREES
var camera_fov := DEFAULT_CAMERA_FOV

# Camera distances below are authored in REFERENCE units -- how much ground was
# framed at the old 75 degree FOV -- and converted to world distance against the
# live FOV. Narrowing the FOV therefore does not change how much map is on
# screen, only the perspective.
#
# That matters twice over. It keeps every existing caller of
# set_camera_distance() (tools and smoke tests) framing what it always framed,
# with no number changes. And it is what makes the debug tuning keys below
# meaningful: pressing "narrow the FOV" shows you a perspective change rather
# than just zooming you in.
const REFERENCE_HALF_FOV_TAN := 0.767327  # tan(37.5 deg), half of the old 75
const CAMERA_MIN_DISTANCE := 12.0
const CAMERA_MAX_DISTANCE := 160.0
const CAMERA_PAN_SPEED := 26.0
const CAMERA_ZOOM_STEP := 4.0
const DEFAULT_PLAY_DISTANCE := 42.0
const MAX_UNIT_INSTANCES := 4000
# Billboarded sprites are one node and one draw call each, so only the units
# nearest the camera get them; everything past this falls back to the capsule
# MultiMesh. Same two-tier idea as MassUnitMultimeshRenderer uses in 2D, for the
# same reason -- see the 2026-08-09 LOD entry in the Decisions Log.
const MAX_SPRITE_UNITS := 220
# A sprite cell is ~92px tall in the shipped sheets and a unit should stand
# roughly 1.3 world units, which is a little under the 1.5 capsule.
const SPRITE_PIXEL_SIZE := 0.014
# Above the tallest terrain props, and safely below the camera at minimum zoom.
const FOG_PLANE_HEIGHT := 6.0
# Drawn this many times the map size. A raised plane loses coverage at the far
# map edge to parallax, which showed as a bright unfogged band along the border.
const FOG_PLANE_OVERSIZE := 3.0
const OVERLAY_SCRIPT := preload("res://scripts/map/map_3d_overlay.gd")
# Matched to CameraController's 2D behaviour so the two modes feel the same.
const EDGE_PAN_MARGIN := 20.0
const EDGE_PAN_SPEED := 26.0

@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var build_system_path: NodePath = NodePath("../BuildSystem")
@export var fog_of_war_path: NodePath = NodePath("../FogOfWar")
@export var block_nav_bridge_path: NodePath = NodePath("../BlockNavBridge")
# Units are mirrored on a fixed interval rather than every frame. The 2D sim
# already budgets its own work; re-uploading a multimesh transform buffer at
# render rate would add a cost that scales with army size for no visible gain
# at this camera distance.
@export var unit_refresh_interval: float = 0.05

var map_generator: Node
var rts_world: RTSWorld
var build_system: Node
var fog_of_war: Node
var camera: Camera3D

var _renderer: Node3D
var _camera_rig: Node3D
var _unit_multimesh: MultiMeshInstance3D
var _structure_multimesh: MultiMeshInstance3D
var _refresh_elapsed := 0.0
var _camera_distance := 46.0
var _camera_focus := Vector3.ZERO
# Panning moves a TARGET and the camera eases toward it. Writing the focus
# directly meant the camera moved in discrete per-event jumps -- one step per
# key frame, one per mouse-motion event -- which is what made panning feel
# rough even though the per-frame cost was fine (measured 0.33ms).
var _camera_target := Vector3.ZERO
var _camera_distance_target := 46.0
var _live_unit_count := 0
var _live_structure_count := 0
var _overlay: Control
var _placement_root: Node3D
var _placement_pool: Array[MeshInstance3D] = []
var _fog_plane: MeshInstance3D
var _impassable_marks: MultiMeshInstance3D
var _drag_camera := false
var _sprite_pool: Array[Sprite3D] = []
var _structure_sprite_pool: Array[Sprite3D] = []
# archetype -> baked Texture2D (or null while a bake is in flight / impossible).
var _baked_unit_art: Dictionary = {}
var _bake_viewport: SubViewport
# Number of economy spaces the marks bake was built against.
#
# It counts the SPACES, not the plots: plots are registered with an empty
# economy_spaces array and filled in afterwards, so a plot-count check sees 13
# plots both before and after and never rebuilds. That is precisely how the Bio
# Absorber's legal cells stayed invisible in 3D -- the bake ran at terrain time,
# caught the plots empty, and never noticed them fill.
var _marked_economy_count := -1
var _sprite_root: Node3D
var _live_sprite_count := 0
var _block_nav_bridge: Node
var _block_structure_root: Node3D
# Raised when a placed block structure is taller than the default. The fog is a
# horizontal plane, so anything taller than it simply pokes through and stands
# lit in unexplored blackness -- which is exactly how the first placed gatehouse
# looked.
var _fog_plane_height := FOG_PLANE_HEIGHT

func _ready() -> void:
	# Inert unless the session asked for the 3D view. main_map.tscn is a single
	# scene shared by both presentations on purpose -- forking a parallel
	# main_map_3d.tscn is how this project has drifted before, and a copy would
	# start diverging from the real one the first time either is edited.
	if not _session_wants_3d():
		queue_free()
		return
	map_generator = get_node_or_null(map_generator_path)
	rts_world = get_node_or_null(rts_world_path)
	build_system = get_node_or_null(build_system_path)
	fog_of_war = get_node_or_null(fog_of_war_path)
	_block_nav_bridge = get_node_or_null(block_nav_bridge_path)
	if _block_nav_bridge != null and _block_nav_bridge.has_signal("structures_placed"):
		_block_nav_bridge.connect("structures_placed", _on_block_structures_placed)
	_build_renderer()
	_build_lighting()
	_build_camera()
	_build_unit_layers()
	_suppress_2d_presentation()
	# Terrain is drawn when generation SAYS it is done, not one frame after
	# _ready. Generation is now spread across frames, so a deferred call would
	# render a half-built map -- and on a big map, an empty one.
	if map_generator != null and map_generator.has_signal("map_generated"):
		map_generator.map_generated.connect(func(_summary: Dictionary) -> void:
			rebuild_terrain()
		)
	call_deferred("rebuild_terrain")

func _session_wants_3d() -> bool:
	var session := get_node_or_null("/root/GameSession")
	return session != null and bool(session.get("render_3d"))

# Godot draws 3D first and CanvasItems over the top, so the 2D presentation has
# to be switched off or it simply paints over the 3D world. The HUD is a
# CanvasLayer and is deliberately untouched -- it works in either mode.
func _suppress_2d_presentation() -> void:
	if rts_world != null and is_instance_valid(rts_world):
		rts_world.presentation_3d = true
	var root := get_parent()
	if root == null:
		return
	# Hide every CanvasItem in the map subtree rather than a list of known names.
	# A name list missed the terrain prop sprites, which live under MapGenerator
	# ("VisualProps") rather than under the scene root, and would miss anything
	# added later too. Systems themselves (BuildSystem, WaveDirector, ...) are
	# plain Nodes and keep running -- they are the game, and this mode changes
	# nothing about them.
	for child in root.get_children():
		if child == self:
			continue
		_hide_canvas_items(child)
	var camera_2d := root.get_node_or_null("Camera2D")
	if camera_2d != null and camera_2d is Camera2D:
		(camera_2d as Camera2D).enabled = false

# Recursion stops at CanvasLayers, which is what keeps the HUD, the pause menu
# and the vertical-slice overlay visible -- they work unchanged in either mode.
func _hide_canvas_items(node: Node) -> void:
	if node is CanvasLayer:
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = false
		return
	for child in node.get_children():
		_hide_canvas_items(child)

func rebuild_terrain() -> void:
	if _renderer == null or map_generator == null or not is_instance_valid(map_generator):
		return
	_renderer.call("render_live_map", map_generator)
	# Map generation paints its 2D props during bootstrap, which can happen after
	# _ready(). Re-run suppression now that everything exists.
	_suppress_2d_presentation()
	_refresh_fog_plane()
	_build_impassable_marks()
	_center_camera_on_map()

func _build_renderer() -> void:
	_renderer = Node3D.new()
	_renderer.name = "Map3DTerrain"
	_renderer.set_script(RENDERER_SCRIPT)
	_renderer.set("embedded_mode", true)
	_renderer.set("show_gameplay_probe", false)
	_renderer.set("presentation_mode", "BIOME")
	add_child(_renderer)

func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-58.0, -42.0, 0.0)
	sun.light_energy = 1.1
	sun.light_color = Color("#CFE3E8")
	sun.shadow_enabled = true
	add_child(sun)
	var environment := WorldEnvironment.new()
	environment.name = "Environment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#10161A")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#33505C")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("#16242B")
	env.fog_density = 0.006
	environment.environment = env
	add_child(environment)

func _build_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	add_child(_camera_rig)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	# World distance grows as the FOV narrows (see REFERENCE_HALF_FOV_TAN), so the
	# far plane has to cover the widest reference distance at the narrowest FOV.
	camera.far = 1200.0
	_camera_rig.add_child(camera)
	_apply_camera_transform()

func _build_unit_layers() -> void:
	_unit_multimesh = _make_multimesh_layer("Units3D", _make_unit_mesh(), Color("#67BED9"))
	_structure_multimesh = _make_multimesh_layer("Structures3D", _make_structure_mesh(), Color("#C9CDD4"))
	_sprite_root = Node3D.new()
	_sprite_root.name = "UnitSprites3D"
	add_child(_sprite_root)
	_placement_root = Node3D.new()
	_placement_root.name = "PlacementPreview3D"
	add_child(_placement_root)
	_build_fog_plane()
	# A CanvasLayer, so it survives the CanvasItem suppression that hides the
	# rest of the 2D presentation.
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "Overlay3D"
	overlay_layer.layer = 40
	add_child(overlay_layer)
	_overlay = Control.new()
	_overlay.name = "Map3DOverlay"
	_overlay.set_script(OVERLAY_SCRIPT)
	overlay_layer.add_child(_overlay)

func _make_multimesh_layer(layer_name: String, mesh: Mesh, albedo: Color) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = layer_name
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = MAX_UNIT_INSTANCES
	multimesh.visible_instance_count = 0
	instance.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.75
	instance.material_override = material
	add_child(instance)
	return instance

# --- Fog of war ------------------------------------------------------------
# Reads the SAME vision texture FogOfWar publishes for the 2D overlay. One
# vision computation, two presentations -- the same principle the unit mirroring
# uses, and the reason the two views can never disagree about what is hidden.
const FOG_SHADER_3D := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D fog_map : filter_linear, repeat_disable;
uniform vec4 fog_color : source_color = vec4(0.02, 0.031, 0.027, 1.0);
uniform float explored_alpha = 0.62;
uniform float drift_strength = 0.006;
uniform float drift_speed = 0.09;
// The plane is drawn larger than the map so that raising it above the terrain
// cannot leave the far border uncovered. This maps the MAP area back to UV 0..1;
// everything outside clamps to the border texel, which is unexplored, so
// off-map ground is correctly black rather than clear.
uniform float uv_scale = 1.0;
void fragment() {
	vec2 uv = (UV - vec2(0.5)) * uv_scale + vec2(0.5);
	float drift = sin(uv.x * 14.0 + TIME * drift_speed * 3.0) * cos(uv.y * 11.0 - TIME * drift_speed * 2.2);
	float v = texture(fog_map, uv + vec2(drift, -drift) * drift_strength).r;
	float a = mix(1.0, explored_alpha, smoothstep(0.0, 0.5, v));
	a = mix(a, 0.0, smoothstep(0.5, 1.0, v));
	ALBEDO = fog_color.rgb;
	ALPHA = a;
}
"""

# The 2D impassable overlay, translated to 3D.
#
# It is a MultiMesh of one small quad per marked cell rather than a single map
# sized plane, because the 3D terrain has real elevation: a flat sheet at y=0
# would be buried under every plateau, marking exactly the cliffs it is meant to
# describe with nothing visible. Each instance instead sits at its own cell's
# surface height.
#
# Built ONCE after the terrain, because terrain does not change during a run --
# same reasoning as the 2D bake. One draw call, zero per-frame cost.
#
# No fog masking is needed here: the 3D fog is a plane ABOVE the ground, so it
# occludes these marks wherever the player has not explored, for free.
const MARK_LIFT := 0.045
const MARK_SIZE := 0.94

func _build_impassable_marks() -> void:
	if map_generator == null or not is_instance_valid(map_generator) or _renderer == null:
		return
	if not map_generator.has_method("is_impassable_cell"):
		return
	var size: Vector2i = _renderer.call("rendered_map_size")
	if size.x <= 0 or size.y <= 0:
		return
	if _impassable_marks == null or not is_instance_valid(_impassable_marks):
		_impassable_marks = MultiMeshInstance3D.new()
		_impassable_marks.name = "ImpassableMarks3D"
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(MARK_SIZE, MARK_SIZE)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		_impassable_marks.multimesh = multimesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color.WHITE
		_impassable_marks.material_override = material
		# Same reason the fog plane disables it: a field of flat quads throwing
		# directional shadows across the terrain looks like corrupt geometry.
		_impassable_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_impassable_marks)

	var marks := compute_marks()
	var multimesh := _impassable_marks.multimesh
	multimesh.instance_count = maxi(1, marks.size())
	for i in marks.size():
		var entry: Dictionary = marks[i]
		multimesh.set_instance_transform(i, _instance_transform(entry["centre"], MARK_LIFT))
		multimesh.set_instance_color(i, entry["color"])
	multimesh.visible_instance_count = marks.size()
	_marked_economy_count = _economy_space_count()

# What gets marked, as plain data.
#
# Split out from the upload so it can be asserted on: MultiMesh instance data
# lives on the rendering server, and under the headless dummy driver
# get_instance_transform() reads back all zeros. A test that inspected the
# uploaded buffer was therefore checking nothing -- it "passed" by comparing
# every mark against cell (0,0). This returns the same values the bake uploads,
# computed the same way, so a headless test can verify them for real.
#
# CLIFF EDGES ONLY, plus economy spaces. The 2D overlay also washes rocks, trees
# and water, because on a flat map there is no other way to tell a blocker from
# open ground. In 3D those are visible geometry, so marking them scattered
# orange over open ground that read as arbitrary rather than as information.
# Cliffs are the one thing the 3D view genuinely cannot convey on its own, since
# a height change reads only as a change in shading.
# Runs on the unit-refresh tick, not per frame, and is a dozen array sizes -- so
# it costs nothing once the map settles, and it picks up a regenerated map free.
func _economy_space_count() -> int:
	var total := 0
	for plot in map_generator.get("plots"):
		total += plot.get("economy_spaces", []).size()
	return total

func compute_marks() -> Array:
	var marks: Array = []
	if map_generator == null or not is_instance_valid(map_generator) or _renderer == null:
		return marks
	var size: Vector2i = _renderer.call("rendered_map_size")
	var cliff_color := Color("#FF6A00", 0.5)
	# Economy spaces are the only cells a Bio Absorber may be built on, they are
	# drawn by PlotRenderer, and this mode hides every CanvasItem -- so without
	# marking them the player cannot find a legal cell and the building simply
	# appears unbuildable.
	var economy_color := Color("#67BED9", 0.5)
	var cell_size := float(_renderer.SIM_PIXELS_PER_CELL)
	var seen := {}
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			if bool(map_generator.call("is_cliff_edge_cell", cell)):
				seen[cell] = true
				marks.append({"cell": cell, "color": cliff_color,
					"centre": (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size})
	for plot in map_generator.get("plots"):
		for economy_cell in plot.get("economy_spaces", []):
			if seen.has(economy_cell):
				continue
			seen[economy_cell] = true
			marks.append({"cell": economy_cell, "color": economy_color,
				"centre": (Vector2(economy_cell) + Vector2(0.5, 0.5)) * cell_size})
	return marks

# The world-space height a mark lands at, exposed for the same reason.
func mark_origin_for(centre: Vector2) -> Vector3:
	return _instance_transform(centre, MARK_LIFT).origin

func _build_fog_plane() -> void:
	if fog_of_war == null or not is_instance_valid(fog_of_war):
		return
	if not fog_of_war.has_method("get_fog_texture"):
		return
	_fog_plane = MeshInstance3D.new()
	_fog_plane.name = "FogOfWar3D"
	_fog_plane.visible = false
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	_fog_plane.mesh = mesh
	var shader := Shader.new()
	shader.code = FOG_SHADER_3D
	var material := ShaderMaterial.new()
	material.shader = shader
	_fog_plane.material_override = material
	# A 96x96 quad hanging above the map casts an enormous directional shadow if
	# left to. That showed up as a hard diagonal edge across half the terrain --
	# the fog's own shadow, not the fog.
	_fog_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fog_plane)

func _refresh_fog_plane() -> void:
	if _fog_plane == null or fog_of_war == null or not is_instance_valid(fog_of_war):
		return
	var texture: Texture2D = fog_of_war.call("get_fog_texture")
	if texture == null:
		_fog_plane.visible = false
		return
	var size: Vector2i = _renderer.call("rendered_map_size")
	if size.x <= 0 or size.y <= 0:
		return
	var material: ShaderMaterial = _fog_plane.material_override
	material.set_shader_parameter("fog_map", texture)
	material.set_shader_parameter("uv_scale", FOG_PLANE_OVERSIZE)
	(_fog_plane.mesh as PlaneMesh).size = Vector2(float(size.x), float(size.y)) * FOG_PLANE_OVERSIZE
	# Height matters only for occlusion -- the plane is an unshaded overlay, so
	# raising it does not change how it looks, only what pokes through it. At
	# 1.75 the map's tall tree props stood above it and rendered unfogged, which
	# read as a hard diagonal band of clear terrain.
	#
	# The ceiling is the camera: its height above the focus is
	# sin(52 degrees) * distance, so at CAMERA_MIN_DISTANCE (12) the camera sits
	# at about 9.5. The plane has to stay below that or zooming in puts the
	# camera underneath the fog and blacks out the whole view.
	_fog_plane.position = Vector3(float(size.x) * 0.5, _fog_plane_height, float(size.y) * 0.5)
	_fog_plane.visible = true

func _make_unit_mesh() -> Mesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = UNIT_MESH_RADIUS
	mesh.height = UNIT_MESH_HEIGHT
	return mesh

func _make_structure_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.6, 1.4, 1.6)
	return mesh

func _process(delta: float) -> void:
	_update_camera_motion(delta)
	_update_camera_smoothing(delta)
	_update_move_marker(delta)
	# Deliberately ahead of the refresh-interval gate below. Economy spaces are
	# filled in some frames after the terrain bake, and behind the gate this check
	# can miss the window entirely on a short-lived view. The cost is a dozen
	# array-size reads and one int compare -- and once the count matches, nothing
	# happens at all.
	if map_generator != null and is_instance_valid(map_generator) and _economy_space_count() != _marked_economy_count:
		_build_impassable_marks()
	_refresh_elapsed += delta
	if _refresh_elapsed < unit_refresh_interval:
		return
	_refresh_elapsed = 0.0
	_sync_units()
	_sync_structures()
	_sync_block_gates()

# --- mirroring the live 2D simulation ---------------------------------------

# Units are drawn one of two ways:
#
#   * Units that HAVE 2D sprite art get a billboarded Sprite3D -- a flat quad
#     turned to face the camera, showing the same sheet the 2D game shows.
#   * Everything else (no art yet, or beyond the sprite budget) falls back to
#     the coloured capsule.
#
# The important part is that the sprite carries NO animation logic. The unit's
# own `ArtSprite` (kon_unit_art.gd) already works out the 8-direction row and
# the animation frame every tick from velocity and attack target; this simply
# mirrors its texture/hframes/vframes/frame. One animation implementation, two
# renderers, and they cannot drift apart.
func _sync_units() -> void:
	if _unit_multimesh == null or rts_world == null or not is_instance_valid(rts_world):
		return
	var sprite_units: Array[Node2D] = []
	var capsule_units: Array[Node2D] = []
	for unit in rts_world.all_units():
		if not is_instance_valid(unit):
			continue
		# Fog hides enemies in 2D by flipping `visible`, which this mode already
		# owns for its own reasons -- so the 3D view asks the fog directly
		# instead. Without this, the 3D mode would see through the fog.
		if not _is_revealed(unit):
			continue
		if unit.get_node_or_null("ArtSprite") != null:
			sprite_units.append(unit)
		elif _baked_texture_for(unit) != null:
			sprite_units.append(unit)
		else:
			capsule_units.append(unit)

	# Past the budget, the furthest sprite units drop to capsules rather than
	# the nearest ones vanishing.
	if sprite_units.size() > MAX_SPRITE_UNITS:
		var focus := _camera_focus
		sprite_units.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return _sim_distance_sq_to_focus(a, focus) < _sim_distance_sq_to_focus(b, focus)
		)
		while sprite_units.size() > MAX_SPRITE_UNITS:
			capsule_units.append(sprite_units.pop_back())

	_sync_unit_sprites(sprite_units)
	_sync_unit_xray(sprite_units, get_process_delta_time())
	_sync_unit_capsules(capsule_units)
	_live_unit_count = sprite_units.size() + capsule_units.size()
	_live_sprite_count = sprite_units.size()

# Serves units AND structures: both carry owner_player_id, and both must be
# concealed by fog. Structures were not checked at all before, which is why
# enemy outposts were plainly visible inside unexplored blackness.
func _is_revealed(node: Node2D) -> bool:
	if bool(node.get_meta("kon_banished",false)): return false
	if fog_of_war == null or not is_instance_valid(fog_of_war):
		return true
	if not fog_of_war.has_method("is_world_position_visible"):
		return true
	if int(node.get("owner_player_id")) == 1:
		return true
	return bool(fog_of_war.call("is_world_position_visible", node.global_position))

func _sim_distance_sq_to_focus(unit: Node2D, focus: Vector3) -> float:
	var world: Vector3 = _renderer.call("sim_to_world_3d", unit.global_position, 0.0)
	return Vector2(world.x - focus.x, world.z - focus.z).length_squared()

# --- seeing units through buildings ----------------------------------------

# How often occlusion is re-tested. Whether a unit is hidden changes when the
# camera or the unit moves, not at render rate, so a few frames of latency is
# imperceptible and the raycasts stop mattering.
const XRAY_CHECK_INTERVAL := 0.12
# Only the player's own units get a ghost. Seeing where your army is inside your
# own buildings is the point; x-raying the enemy through walls is not.
const XRAY_MAX_UNITS := 64

var _xray_pool: Array[Sprite3D] = []
var _xray_elapsed := 0.0
var _xray_occluded: Dictionary = {}

# A flat copy of each hidden unit, drawn with the depth test off so it shows
# through whatever is covering it.
#
# Units are billboards here rather than meshes, so this does not reuse
# XraySilhouette -- that draws a scaled mesh copy and was written for the demo,
# which renders units as capsules. The reasoning is the same though: an RTS
# where units vanish inside their own buildings is unplayable, because a unit on
# the far side of a wall reads as dead rather than hidden, and you cannot select
# what you cannot see.
func _sync_unit_xray(units: Array[Node2D], delta: float) -> void:
	_xray_elapsed += delta
	var recheck := _xray_elapsed >= XRAY_CHECK_INTERVAL
	if recheck:
		_xray_elapsed = 0.0
	var shown := 0
	if camera != null and is_instance_valid(camera):
		var space := camera.get_world_3d().direct_space_state
		for i in units.size():
			var unit := units[i]
			if shown >= XRAY_MAX_UNITS:
				break
			if int(unit.get("owner_player_id")) != 1:
				continue
			var id := unit.get_instance_id()
			if recheck:
				var to := _unit_transform(unit, 0.45).origin
				var query := PhysicsRayQueryParameters3D.create(camera.global_position, to)
				query.collide_with_areas = false
				var hit := space.intersect_ray(query)
				# Anything solid between the camera and the unit hides it. The
				# unit itself has no 3D body here, so any hit at all is a wall.
				_xray_occluded[id] = not hit.is_empty()
			if not bool(_xray_occluded.get(id, false)):
				continue
			var source := _sprite_at(i)
			var ghost := _xray_sprite_at(shown)
			ghost.visible = true
			ghost.texture = source.texture
			ghost.hframes = source.hframes
			ghost.vframes = source.vframes
			ghost.frame = source.frame
			ghost.pixel_size = source.pixel_size
			ghost.global_transform = source.global_transform
			ghost.modulate = Color(0.29, 0.87, 0.5, 0.85)
			shown += 1
	for i in range(shown, _xray_pool.size()):
		_xray_pool[i].visible = false

func _xray_sprite_at(index: int) -> Sprite3D:
	while _xray_pool.size() <= index:
		var ghost := Sprite3D.new()
		ghost.name = "UnitXray%s" % _xray_pool.size()
		ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ghost.shaded = false
		ghost.no_depth_test = true
		# Drawn after everything else, so it lands on top of the wall rather
		# than fighting it.
		ghost.render_priority = 20
		ghost.transparent = true
		ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_sprite_root.add_child(ghost)
		_xray_pool.append(ghost)
	return _xray_pool[index]

func _sync_unit_sprites(units: Array[Node2D]) -> void:
	for i in units.size():
		var unit := units[i]
		var art := unit.get_node_or_null("ArtSprite")
		var sprite := _sprite_at(i)
		sprite.visible = not bool(unit.get_meta("hide_unit_billboard",false))
		if art != null:
			sprite.texture = art.texture
			sprite.hframes = max(1, int(art.hframes))
			sprite.vframes = max(1, int(art.vframes))
			sprite.frame = int(art.frame)
			sprite.flip_h = art.flip_h
			sprite.flip_v = art.flip_v
			sprite.offset.x = art.offset.x
			sprite.pixel_size = float(art.get_meta("billboard_pixel_size",SPRITE_PIXEL_SIZE))
		else:
			# Baked procedural art: a single frame, no direction rows. Scaled so
			# the 192px bake lands at roughly a unit's height in world space.
			sprite.texture = _baked_texture_for(unit)
			sprite.hframes = 1
			sprite.vframes = 1
			sprite.frame = 0
			sprite.flip_h = false
			sprite.flip_v = false
			sprite.offset.x = 0.0
			sprite.pixel_size = SPRITE_PIXEL_SIZE * 0.62
		# Owner tint and selection highlight, matching the capsule colours so the
		# two tiers read as the same army.
		sprite.modulate = _sprite_modulate(int(unit.get("owner_player_id")), bool(unit.get("selected")))
		var transform := _unit_transform(unit)
		# Lift by half the sprite's world height so its feet sit on the ground.
		var cell_height := 0.0
		if sprite.texture != null:
			cell_height = float(sprite.texture.get_height()) / float(sprite.vframes)
		if art != null and art.has_meta("foot_anchor_y"):
			transform.origin.y += (float(art.get_meta("foot_anchor_y"))-cell_height*0.5)*sprite.pixel_size
		else:
			transform.origin.y += cell_height*SPRITE_PIXEL_SIZE*0.5
		sprite.global_transform = transform
	for i in range(units.size(), _sprite_pool.size()):
		_sprite_pool[i].visible = false

func _sync_unit_capsules(units: Array[Node2D]) -> void:
	var multimesh := _unit_multimesh.multimesh
	var index := 0
	for unit in units:
		if index >= MAX_UNIT_INSTANCES:
			break
		multimesh.set_instance_transform(index, _unit_transform(unit, UNIT_MESH_HEIGHT * 0.5))
		multimesh.set_instance_color(index, _owner_color(int(unit.get("owner_player_id")), bool(unit.get("selected"))))
		index += 1
	multimesh.visible_instance_count = index

func spawn_painted_unit_death(unit: Node2D, art: Sprite2D) -> void:
	if not _is_revealed(unit) or not is_instance_valid(_sprite_root):
		return
	var corpse:=Sprite3D.new()
	corpse.name="PaintedUnitCorpse"
	corpse.texture=art.texture
	corpse.hframes=art.hframes
	corpse.vframes=art.vframes
	var first:=int(art.get_meta("death_row",5))*art.hframes
	corpse.frame=first
	corpse.flip_h=art.flip_h
	corpse.offset.x=art.offset.x
	corpse.pixel_size=float(art.get_meta("billboard_pixel_size",SPRITE_PIXEL_SIZE))
	corpse.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	corpse.shaded=false
	corpse.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	corpse.modulate=_sprite_modulate(int(unit.get("owner_player_id")),false)
	_sprite_root.add_child(corpse)
	var half_height:=float(art.texture.get_height())/art.vframes*0.5
	corpse.global_transform=_unit_transform(unit,(float(art.get_meta("foot_anchor_y",210.0))-half_height)*corpse.pixel_size)
	var tween:=corpse.create_tween()
	tween.tween_method(func(t: float) -> void: corpse.frame=first+mini(corpse.hframes-1,int(t*corpse.hframes)),0.0,1.0,float(art.get_meta("death_seconds",1.0)))
	tween.tween_interval(float(art.get_meta("corpse_hold_seconds",1.2)))
	tween.tween_property(corpse,"modulate:a",0.0,0.7)
	tween.tween_callback(corpse.queue_free)

# ---------------------------------------------------------------------------
# Offscreen sprite baking.
#
# Units with no sprite sheet -- which is still the entire KoN roster -- fell back
# to a plain capsule in 3D. But those units are NOT featureless in 2D: they draw
# detailed procedural art in `_draw()` (the Oaven has a teal body, cyan eyes, a
# red scarf and a spear). The 3D view was discarding art that already existed.
#
# So it is rendered once per archetype into a SubViewport and used as a
# billboard. No new art, no pipeline, and the 3D view now shows what the 2D view
# shows for every unit.
#
# SAFETY: a unit instantiated for baking would otherwise join the live
# simulation -- RTSUnit._ready() adds itself to the "units" and
# "selectable_units" groups and to a STATIC registry. All three are undone
# immediately, and physics is disabled, so the baking copy is never selectable,
# targetable, or counted. `terrain` and `rts_world` do not resolve inside the
# SubViewport, which is what makes the rest of _ready() harmless.
const BAKE_SIZE := 192

func _baked_texture_for(unit: Node2D) -> Texture2D:
	var archetype := StringName(unit.get("unit_archetype"))
	if _baked_unit_art.has(archetype):
		return _baked_unit_art[archetype]
	var scene_path: String = unit.scene_file_path
	if scene_path.is_empty():
		_baked_unit_art[archetype] = null
		return null
	# Mark in-flight so the next sync does not queue a second bake.
	_baked_unit_art[archetype] = null
	_bake_unit_art(archetype, scene_path)
	return null

func _bake_unit_art(archetype: StringName, scene_path: String) -> void:
	if _bake_viewport == null or not is_instance_valid(_bake_viewport):
		_bake_viewport = SubViewport.new()
		_bake_viewport.name = "UnitArtBaker"
		_bake_viewport.size = Vector2i(BAKE_SIZE, BAKE_SIZE)
		_bake_viewport.transparent_bg = true
		_bake_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_bake_viewport.disable_3d = true
		add_child(_bake_viewport)

	var packed: PackedScene = load(scene_path)
	if packed == null:
		return
	# Headless rasterises nothing, so the bake could only ever return an empty
	# image -- and, worse, `frame_post_draw` never fires there, so this coroutine
	# would park forever holding a live unit under the viewport and hang teardown.
	if DisplayServer.get_name() == "headless":
		return
	var stand_in: Node = packed.instantiate()
	stand_in.set("owner_player_id", 1)
	_bake_viewport.add_child(stand_in)
	# Undo everything _ready() registered, before any tick can observe it.
	if stand_in.is_in_group("units"):
		stand_in.remove_from_group("units")
	if stand_in.is_in_group("selectable_units"):
		stand_in.remove_from_group("selectable_units")
	if stand_in.has_method("set_physics_process"):
		stand_in.set_physics_process(false)
	RTSUnit._unregister_unit(stand_in)
	if stand_in is Node2D:
		# The art is drawn around the node's origin, so centre it and lift it a
		# little: unit art extends further below the origin than above it.
		(stand_in as Node2D).position = Vector2(BAKE_SIZE * 0.5, BAKE_SIZE * 0.55)
	if stand_in.has_method("queue_redraw"):
		stand_in.call("queue_redraw")

	_bake_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := _bake_viewport.get_texture().get_image()
	stand_in.queue_free()
	if image == null or image.is_empty():
		return
	# A fully transparent bake means the unit draws nothing without a live world;
	# storing it would just pin an invisible sprite in place of the capsule.
	if not _image_has_content(image):
		return
	_baked_unit_art[archetype] = ImageTexture.create_from_image(image)

func _image_has_content(image: Image) -> bool:
	var step: int = maxi(1, image.get_width() / 48)
	for x in range(0, image.get_width(), step):
		for y in range(0, image.get_height(), step):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false

func _sprite_at(index: int) -> Sprite3D:
	while _sprite_pool.size() <= index:
		var sprite := Sprite3D.new()
		sprite.name = "UnitSprite%s" % _sprite_pool.size()
		# BILLBOARD_ENABLED turns the quad to face the camera on every axis. The
		# sheets were rendered from a fixed -52 degree camera, so the sprite
		# already contains that perspective -- facing the camera squarely is what
		# makes it read correctly rather than looking like a standing cutout.
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Unlit, so the painted art keeps its own values instead of being
		# re-lit by the 3D sun and losing the ink-outline look.
		sprite.shaded = false
		# Discard rather than blend: with hundreds of overlapping transparent
		# quads, alpha blending has no correct draw order and produces flicker.
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.pixel_size = SPRITE_PIXEL_SIZE
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_sprite_root.add_child(sprite)
		_sprite_pool.append(sprite)
	return _sprite_pool[index]

func _sprite_modulate(owner_id: int, selected: bool) -> Color:
	var tint := Color.WHITE
	match owner_id:
		2:
			tint = Color(1.14, 0.78, 0.78, 1.0)
		0:
			tint = Color(1.05, 1.0, 0.92, 1.0)
		3:
			tint = Color(0.74, 1.05, 1.18, 1.0)
		4:
			tint = Color(1.16, 1.02, 0.72, 1.0)
	return tint.lightened(0.28) if selected else tint

# Structures are drawn the same way units are: those with 2D art (every KoN
# building has an `art_sprite`) become billboards showing that exact texture,
# and anything without falls back to the coloured box.
#
# They are ALSO fog-gated now. They were not, which is why enemy outposts were
# clearly visible inside unexplored blackness -- the most obvious "line of sight
# is broken" symptom in the 3D view, and it was structures rather than units.
# Whether this structure is represented by authored block geometry rather than
# by a sprite. Read from the catalog rather than stored on the node, so it stays
# true of anything that gains a block structure later.
func _has_block_structure(structure: Node) -> bool:
	var archetype: Variant = structure.get("archetype")
	if archetype == null:
		return false
	return UnitCatalog.get_definition(StringName(archetype)).has("block_structure")

func _sync_structures() -> void:
	if _structure_multimesh == null:
		return
	var sprite_structures: Array[Node2D] = []
	var box_structures: Array[Node2D] = []
	for structure in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(structure) or not (structure is Node2D):
			continue
		if not _is_revealed(structure as Node2D):
			continue
		# A building whose real geometry is a block structure draws nothing here.
		# Its walls, floors and roof are already in the world as actual meshes,
		# so billboarding the 2D placeholder on top of them puts a flat painted
		# barracks inside the laboratory you just built.
		if _has_block_structure(structure):
			continue
		if structure.get("art_sprite") != null and is_instance_valid(structure.get("art_sprite")):
			sprite_structures.append(structure as Node2D)
		else:
			box_structures.append(structure as Node2D)

	for i in sprite_structures.size():
		var structure := sprite_structures[i]
		var art: Sprite2D = structure.get("art_sprite")
		var sprite := _structure_sprite_at(i)
		sprite.visible = true
		sprite.texture = art.texture
		sprite.hframes = max(1, int(art.hframes))
		sprite.vframes = max(1, int(art.vframes))
		sprite.frame = int(art.frame)
		# Derived from the 2D art scale rather than a constant: 64 simulation
		# pixels are one world unit, so this keeps a building exactly the size in
		# 3D that it is in 2D, whatever its sprite resolution.
		sprite.pixel_size = maxf(0.001, art.scale.y / _renderer.SIM_PIXELS_PER_CELL)
		sprite.modulate = _sprite_modulate(int(structure.get("owner_player_id")), bool(structure.get("selected")))
		sprite.modulate *= art.modulate
		var transform := _instance_transform(structure.global_position, 0.0)
		if sprite.texture != null:
			transform.origin.y += float(sprite.texture.get_height()) / float(sprite.vframes) * sprite.pixel_size * 0.5
		sprite.global_transform = transform
	for i in range(sprite_structures.size(), _structure_sprite_pool.size()):
		_structure_sprite_pool[i].visible = false

	var multimesh := _structure_multimesh.multimesh
	var index := 0
	for structure in box_structures:
		if index >= MAX_UNIT_INSTANCES:
			break
		multimesh.set_instance_transform(index, _instance_transform(structure.global_position, 0.7))
		multimesh.set_instance_color(index, _owner_color(int(structure.get("owner_player_id")), bool(structure.get("selected"))))
		index += 1
	multimesh.visible_instance_count = index
	_live_structure_count = sprite_structures.size() + index

func _structure_sprite_at(index: int) -> Sprite3D:
	while _structure_sprite_pool.size() <= index:
		var sprite := Sprite3D.new()
		sprite.name = "StructureSprite%s" % _structure_sprite_pool.size()
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_sprite_root.add_child(sprite)
		_structure_sprite_pool.append(sprite)
	return _structure_sprite_pool[index]

# A unit's position, taking its BLOCK LEVEL into account when it has one.
#
# Without this the 3D view puts every unit on the terrain surface under it, so a
# unit standing on a wall-walk renders inside the passage below -- the elevation
# would exist in the simulation and be invisible on screen. `nav_level` is 0 for
# any unit that has never been given a lattice path, and level 0 IS the terrain
# surface, so ordinary units are unaffected.
# Draws the block structures the nav bridge placed on the live map.
#
# Signal-driven rather than polled: placement happens once, after map generation
# settles, and a per-frame check for something that changes once would be exactly
# the kind of cost this file has had to remove twice already.
#
# How tall one block level is, as a fraction of a map cell. 1.0 keeps blocks
# cubic, which is the only value that looks right.
#
# Buildings were once made smaller by squashing this instead, which was the
# wrong fix: it flattened them rather than shrinking them, so a laboratory
# turned into a wide bungalow with the same 34x28 floor area. Size is now
# reduced where it should be -- by downsampling the authored blocks themselves,
# so a 20x20x20 building becomes 5x5x5 and keeps its proportions.
const BLOCK_LEVEL_HEIGHT := 1.0

# Blocks are one world unit wide and a map cell is one TILE_SIZE, so the two
# grids line up horizontally without conversion.
func _sync_block_gates() -> void:
	if not is_instance_valid(_block_structure_root) or _block_nav_bridge == null:
		return
	var world: BlockNavWorld = _block_nav_bridge.get("world")
	if world == null:
		return
	for builder: BlockStructureBuilder in _block_structure_root.get_children():
		for key in builder.definition.gate_cells:
			builder.set_gate_open(key, bool(world.gate_states.get(str(key), false)))

func _on_block_structures_placed(placements: Array) -> void:
	if _block_structure_root == null or not is_instance_valid(_block_structure_root):
		_block_structure_root = Node3D.new()
		_block_structure_root.name = "BlockStructures3D"
		add_child(_block_structure_root)
	var library: BlockStructureLibrary = _block_nav_bridge.get("library")
	if library == null:
		return
	for placement in placements:
		var definition := library.get_definition(placement["id"])
		if definition == null:
			continue
		var builder := BlockStructureBuilder.new()
		# Named by the placement, not the structure type: a town has several
		# laboratories and naming them all Block_kons_splicing_laboratory_01
		# left Godot to invent @Node3D@285 for the rest, which is unreadable in
		# the tree and impossible to look up later.
		builder.name = "Block_%s_%s_%s" % [placement["id"],
			int(placement["origin"].x), int(placement["origin"].y)]
		_block_structure_root.add_child(builder)
		builder.build(definition.rotated(int(placement.get("rotation_steps", 0))))
		var origin: Vector2i = placement["origin"]
		builder.position = Vector3(
			float(origin.x) * _renderer.TILE_SIZE,
			float(placement["base_level"]) * _renderer.TILE_SIZE,
			float(origin.y) * _renderer.TILE_SIZE)
		# Runtime profiles already contain the gameplay dimensions. Do not apply
		# another quarter-scale transform here or to units standing on them.
		builder.scale = Vector3(1.0, BLOCK_LEVEL_HEIGHT, 1.0)
		var top: float = float(placement["base_level"]) * float(_renderer.TILE_SIZE) 			+ float(definition.dimensions.y) * BLOCK_LEVEL_HEIGHT
		_fog_plane_height = maxf(_fog_plane_height, top + 1.5)
	_refresh_fog_plane()
	_sync_block_gates()

func _unit_transform(unit: Node2D, lift: float = 0.0) -> Transform3D:
	var level: Variant = unit.get("nav_level")
	if level == null or int(level) <= 0:
		return _instance_transform(unit.global_position, lift)
	var ground := _renderer.call("sim_to_world_3d", unit.global_position, 0.0) as Vector3
	# Measured from the ground the structure stands on, then scaled by the same
	# BLOCK_LEVEL_HEIGHT the geometry uses -- otherwise a unit ordered onto the
	# gallery is drawn at the height that floor USED to be and stands in the air.
	var base := _terrain_level_under(unit.global_position)
	ground.y = float(base) * _renderer.TILE_SIZE 		+ float(maxi(int(level) - base, 0)) * BLOCK_LEVEL_HEIGHT + lift
	return Transform3D(Basis.IDENTITY, ground)

# The terrain level beneath a world position, which is where any structure on
# that cell has its foot.
func _terrain_level_under(sim_position: Vector2) -> int:
	if map_generator == null or not is_instance_valid(map_generator):
		return 0
	var cell: Vector2i = map_generator.call("world_to_cell", sim_position)
	if not bool(map_generator.call("is_in_bounds", cell)):
		return 0
	return int(map_generator.call("get_height", cell))

func _instance_transform(sim_position: Vector2, lift: float) -> Transform3D:
	var ground := _renderer.call("sim_to_world_3d", sim_position, 0.0) as Vector3
	ground.y = _surface_height(sim_position) + lift
	return Transform3D(Basis.IDENTITY, ground)

func _surface_height(sim_position: Vector2) -> float:
	if map_generator == null or not is_instance_valid(map_generator) or _renderer == null:
		return 0.0
	var cell: Vector2i = map_generator.call("world_to_cell", sim_position)
	return float(_renderer.call("surface_height_at_cell", cell))

func _owner_color(owner_id: int, selected: bool) -> Color:
	var color := Color("#67BED9")
	match owner_id:
		2:
			color = Color("#C13030")
		0:
			color = Color("#B9B2A6")
		3:
			color = Color("#3FA8B5")
		4:
			color = Color("#D6A84F")
	return color.lightened(0.35) if selected else color

# --- camera -----------------------------------------------------------------

func _center_camera_on_map() -> void:
	if _renderer == null or not is_instance_valid(_renderer):
		return
	# Framed on the geometry the renderer actually drew, not on the simulation's
	# world bounds -- those cover the playable rect only, which left the drawn
	# map noticeably off-centre.
	var size: Vector2i = _renderer.call("rendered_map_size")
	if size.x <= 0 or size.y <= 0:
		return
	_camera_distance = DEFAULT_PLAY_DISTANCE
	_camera_distance_target = DEFAULT_PLAY_DISTANCE
	# Open on the player's base, the way the 2D camera does, rather than on the
	# geometric centre of the map. Falls back to the map centre before the tower
	# exists.
	var tower := _find_player_tower()
	if tower != null:
		_camera_focus = _renderer.call("sim_to_world_3d", tower.global_position, 0.0)
	else:
		_camera_focus = Vector3(float(size.x) * 0.5, 0.0, float(size.y) * 0.5)
	_apply_camera_transform()

func _find_player_tower() -> Node2D:
	for structure in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(structure) or not (structure is Node2D):
			continue
		if int(structure.get("owner_player_id")) == 1 and str(structure.get("archetype")) == "wizard_tower":
			return structure as Node2D
	return null

# Lets tools and future systems frame the view without reaching into internals.
func set_camera_distance(distance: float) -> void:
	_camera_distance = clampf(distance, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
	_camera_distance_target = _camera_distance
	_apply_camera_transform()

# Focuses the 3D camera on a point in SIMULATION coordinates, so other systems
# can drive it without knowing anything about the 3D layer.
func focus_on_sim_position(sim_position: Vector2) -> void:
	_camera_focus = _renderer.call("sim_to_world_3d", sim_position, 0.0)
	_camera_target = _camera_focus
	_apply_camera_transform()

# Feature-for-feature with CameraController's 2D behaviour: keyboard pan, edge
# pan, middle-mouse drag, wheel zoom and clamping to the map. The first pass
# shipped keyboard pan only, which is why the map felt stuck.
func _update_camera_motion(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		direction.x += 1.0
	if Input.is_action_pressed("ui_up"):
		direction.z -= 1.0
	if Input.is_action_pressed("ui_down"):
		direction.z += 1.0
	if direction != Vector3.ZERO:
		var speed := CAMERA_PAN_SPEED * (_camera_distance / DEFAULT_PLAY_DISTANCE)
		_camera_target += direction.normalized() * speed * delta
	_update_edge_pan(delta)

# Frame-rate independent easing: the same fraction of the remaining distance is
# covered per unit of TIME, not per frame, so panning feels identical at 30fps
# and 144fps.
const CAMERA_SMOOTHING := 14.0

func _update_camera_smoothing(delta: float) -> void:
	var weight: float = 1.0 - exp(-CAMERA_SMOOTHING * delta)
	var moved := false
	if _camera_focus.distance_squared_to(_camera_target) > 0.000001:
		_camera_focus = _camera_focus.lerp(_camera_target, weight)
		moved = true
	if absf(_camera_distance - _camera_distance_target) > 0.001:
		_camera_distance = lerpf(_camera_distance, _camera_distance_target, weight)
		moved = true
	if moved:
		_apply_camera_transform()

func _update_edge_pan(delta: float) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var mouse := viewport.get_mouse_position()
	var size := viewport.get_visible_rect().size
	# Ignore the cursor when it is outside the window, or edge pan latches on.
	if mouse.x < 0.0 or mouse.y < 0.0 or mouse.x > size.x or mouse.y > size.y:
		return
	var direction := Vector3.ZERO
	if mouse.x < EDGE_PAN_MARGIN:
		direction.x -= 1.0
	if mouse.x > size.x - EDGE_PAN_MARGIN:
		direction.x += 1.0
	if mouse.y < EDGE_PAN_MARGIN:
		direction.z -= 1.0
	if mouse.y > size.y - EDGE_PAN_MARGIN:
		direction.z += 1.0
	if direction != Vector3.ZERO:
		# Scaled by zoom so panning covers a consistent fraction of the visible
		# area rather than crawling when zoomed out.
		var speed := EDGE_PAN_SPEED * (_camera_distance / DEFAULT_PLAY_DISTANCE)
		_camera_target += direction.normalized() * speed * delta

# Live camera tuning, debug builds only.
#
# Pitch and FOV are art-direction values, not engineering ones -- the right
# numbers are whatever looks right to the person looking at it, and that is not a
# judgement to make from a screenshot. These keys make them adjustable while the
# game is running so they can be dialled in against the real map, then written
# back into the constants above.
#
#   [ / ]   field of view   (framing is held constant, so this shows perspective)
#   ; / '   camera pitch    (; shallower, ' steeper)
#   \      print the constant lines to paste back into this file
#   B       jump the camera to the next placed block structure
#   Backspace  reset both to the defaults
#
# OS.is_debug_build() gates the whole thing, so none of it exists in an export.
const TUNE_FOV_STEP := 2.5
const TUNE_PITCH_STEP := 1.5

func _handle_camera_tuning(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_BRACKETLEFT:
			camera_fov = clampf(camera_fov - TUNE_FOV_STEP, 10.0, 90.0)
		KEY_BRACKETRIGHT:
			camera_fov = clampf(camera_fov + TUNE_FOV_STEP, 10.0, 90.0)
		KEY_SEMICOLON:
			camera_pitch_degrees = clampf(camera_pitch_degrees + TUNE_PITCH_STEP, -85.0, -10.0)
		KEY_APOSTROPHE:
			camera_pitch_degrees = clampf(camera_pitch_degrees - TUNE_PITCH_STEP, -85.0, -10.0)
		KEY_BACKSPACE:
			camera_fov = DEFAULT_CAMERA_FOV
			camera_pitch_degrees = DEFAULT_CAMERA_PITCH_DEGREES
		KEY_B:
			_focus_next_block_structure()
		KEY_BACKSLASH:
			print("[Map3DView] paste into scripts/map/map_3d_view.gd:")
			print("const DEFAULT_CAMERA_PITCH_DEGREES := %.1f" % camera_pitch_degrees)
			print("const DEFAULT_CAMERA_FOV := %.1f" % camera_fov)
			return true
		_:
			return false
	_apply_camera_transform()
	_update_tuning_readout()
	return true

# Jumps the camera to each placed block structure in turn.
#
# They are deliberately placed at least 16 cells from the tower, which puts them
# outside the player's starting vision -- correct for the game, and infuriating
# when you are trying to look at one. This is the difference between "go and
# find it" and "press B".
var _block_focus_index := -1

func _focus_next_block_structure() -> void:
	if _block_nav_bridge == null or not is_instance_valid(_block_nav_bridge):
		return
	var block_world = _block_nav_bridge.get("world")
	if block_world == null:
		return
	var placements: Array = block_world.placements()
	if placements.is_empty():
		return
	_block_focus_index = wrapi(_block_focus_index + 1, 0, placements.size())
	var placement: Dictionary = placements[_block_focus_index]
	var origin: Vector2i = placement["origin"]
	var centre: Vector2 = map_generator.call("cell_to_world", origin + Vector2i(6, 5))
	focus_on_sim_position(centre)
	set_camera_distance(30.0)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.set("debug_text", "block structure %d/%d: %s at %s" % [
			_block_focus_index + 1, placements.size(), placement["structure"], origin])
		_overlay.call("queue_redraw")

# Shows the live values, and the cross-frame angle spread they produce -- the
# number that actually explains whether billboards will sit on the ground. See
# the FOV note on the constants.
func _update_tuning_readout() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var pitch := absf(camera_pitch_degrees)
	var half := camera_fov * 0.5
	_overlay.set("debug_text", "pitch %.1f°   fov %.1f°\nground seen %.0f°-%.0f° across frame\n[ ] fov   ; ' pitch   \\ print   Bksp reset" % [
		pitch, camera_fov, maxf(0.0, pitch - half), minf(90.0, pitch + half)])
	_overlay.call("queue_redraw")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and OS.is_debug_build():
		if _handle_camera_tuning(event as InputEventKey):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_drag_camera = event.pressed
			return
		if not event.pressed:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance_target = clampf(_camera_distance_target - CAMERA_ZOOM_STEP, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance_target = clampf(_camera_distance_target + CAMERA_ZOOM_STEP, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
	elif event is InputEventMouseMotion and _drag_camera:
		# True 1:1 drag: work out which ground point was under the cursor before
		# and after the motion, and shift the focus by the difference. The
		# ground under the cursor then stays under the cursor exactly, at any
		# zoom and any pitch.
		#
		# A fixed pixels-to-world factor (the first attempt) cannot do this --
		# the correct factor depends on camera distance AND field of view AND
		# where on the screen the cursor is, because the view is a perspective
		# projection rather than an orthographic one.
		var from_point := _ground_point(event.position - event.relative)
		var to_point := _ground_point(event.position)
		if from_point != Vector3.INF and to_point != Vector3.INF:
			# Dragging is 1:1 and must not lag behind the cursor, so it moves the
			# camera and the target together rather than easing.
			var shift := from_point - to_point
			_camera_target += shift
			_camera_focus += shift
			_apply_camera_transform()

# Where a screen position lands on the y=0 ground plane, or Vector3.INF if the
# ray never reaches it (above the horizon).
func _ground_point(screen_position: Vector2) -> Vector3:
	if camera == null or not is_instance_valid(camera):
		return Vector3.INF
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return Vector3.INF
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return Vector3.INF
	return origin + direction * distance

# --- screen-space overlay + placement preview, driven by the 2D systems ------

func sim_to_screen(sim_position: Vector2) -> Vector2:
	if camera == null or not is_instance_valid(camera) or _renderer == null:
		return Vector2.ZERO
	var world: Vector3 = _renderer.call("sim_to_world_3d", sim_position, 0.0)
	world.y = _surface_height(sim_position)
	return camera.unproject_position(world)

func is_sim_position_on_camera(sim_position: Vector2) -> bool:
	if camera == null or not is_instance_valid(camera) or _renderer == null:
		return false
	var world: Vector3 = _renderer.call("sim_to_world_3d", sim_position, 0.0)
	world.y = _surface_height(sim_position)
	return not camera.is_position_behind(world)

func set_drag_rect(active: bool, rect: Rect2) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.call("set_drag", active, rect)

func set_cursor_mode(mode: StringName) -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var viewport := get_viewport()
	var mouse := viewport.get_mouse_position() if viewport != null else Vector2.ZERO
	_overlay.call("set_cursor", mode, mouse)

# Called by BuildSystem while a structure is pending. The 2D preview is drawn in
# BuildSystem._draw(), which never runs here because the node is hidden.
func update_placement_preview(cells: Array, valid: bool) -> void:
	if _placement_root == null or _renderer == null:
		return
	for i in cells.size():
		var pad := _placement_pad(i)
		var cell: Vector2i = cells[i]
		var centre := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) * 64.0
		var transform := _instance_transform(centre, 0.0)
		transform.origin.y += 0.06
		pad.global_transform = transform
		pad.visible = true
		var material: StandardMaterial3D = pad.material_override
		material.albedo_color = Color(0.35, 0.95, 0.55, 0.45) if valid else Color(0.95, 0.30, 0.30, 0.45)
	for i in range(cells.size(), _placement_pool.size()):
		_placement_pool[i].visible = false

func clear_placement_preview() -> void:
	for pad in _placement_pool:
		pad.visible = false

func _placement_pad(index: int) -> MeshInstance3D:
	while _placement_pool.size() <= index:
		var pad := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(0.94, 0.94)
		pad.mesh = mesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		pad.material_override = material
		_placement_root.add_child(pad)
		_placement_pool.append(pad)
	return _placement_pool[index]

func _apply_camera_transform() -> void:
	if _camera_rig == null or camera == null:
		return
	_clamp_camera_focus()
	_camera_rig.global_position = _camera_focus

# Keeps the camera over the map, the way CameraController._clamp_to_map() does
# in 2D. Without it the 3D camera pans off into empty space with no way back.
func _clamp_camera_focus() -> void:
	if _renderer == null or not is_instance_valid(_renderer):
		return
	var size: Vector2i = _renderer.call("rendered_map_size")
	if size.x <= 0 or size.y <= 0:
		return
	_camera_focus.x = clampf(_camera_focus.x, 0.0, float(size.x))
	_camera_focus.z = clampf(_camera_focus.z, 0.0, float(size.y))
	_camera_focus.y = 0.0
	_camera_target.x = clampf(_camera_target.x, 0.0, float(size.x))
	_camera_target.z = clampf(_camera_target.z, 0.0, float(size.y))
	_camera_target.y = 0.0
	camera.fov = camera_fov
	var pitch := deg_to_rad(camera_pitch_degrees)
	var distance := _camera_distance * distance_scale()
	camera.position = Vector3(0.0, -sin(pitch) * distance, cos(pitch) * distance)
	camera.look_at(_camera_rig.global_position, Vector3.UP)

# Reference distance -> world distance for the current FOV. See the constants.
func distance_scale() -> float:
	return REFERENCE_HALF_FOV_TAN / maxf(0.02, tan(deg_to_rad(camera_fov * 0.5)))

# --- the input bridge -------------------------------------------------------
# The existing 2D SelectionController works in simulation coordinates and asks
# the viewport for the mouse position. In 3D that question has no answer until
# the cursor is projected onto the ground, so this converts a screen point into
# the simulation coordinate the 2D systems already understand. That is the whole
# reason selection, orders and building placement keep working in this mode
# without a second input implementation.
# Where the cursor is pointing, in simulation space, accounting for buildings.
#
# screen_to_sim_position() below intersects the y = 0 ground plane, which was
# exact while the world was flat and is wrong now that structures stand twelve
# units tall: clicking a wall-walk or a roof projects THROUGH the building to
# the ground behind it, so the order lands well past whatever was clicked and
# the unit walks around the far side. That reads as broken pathing and is
# actually a mis-aimed cursor.
#
# So geometry is asked first -- structures carry collision boxes -- and the
# ground plane is the fallback for open terrain. The returned level is the block
# level of the surface that was hit, which is what lets a right-click on a
# gallery mean that gallery rather than the floor under it.
# --- move order marker ------------------------------------------------------

const MARKER_SECONDS := 0.55

var _move_marker: MeshInstance3D
var _move_marker_elapsed := 0.0

# A ring where the order landed, at the height it landed on.
#
# Without it there is no way to tell a mis-aimed click from a unit that refused
# to move -- which is exactly the confusion that hid the cursor projecting
# through buildings to the ground behind them. The level matters as much as the
# position: an order onto a gallery should show the ring ON the gallery, or it
# looks like the click went to the floor below.
func show_move_marker(sim_position: Vector2, level: int) -> void:
	if _renderer == null or not is_instance_valid(_renderer):
		return
	if _move_marker == null or not is_instance_valid(_move_marker):
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.42
		mesh.outer_radius = 0.6
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.42, 0.92, 0.55)
		material.emission_enabled = true
		material.emission = Color(0.42, 0.92, 0.55)
		material.emission_energy_multiplier = 1.4
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Drawn over the ground it sits on rather than z-fighting with it.
		material.no_depth_test = true
		material.render_priority = 18
		mesh.material = material
		_move_marker = MeshInstance3D.new()
		_move_marker.name = "MoveOrderMarker"
		_move_marker.mesh = mesh
		add_child(_move_marker)
	var ground := _renderer.call("sim_to_world_3d", sim_position, 0.0) as Vector3
	ground.y = float(maxi(level, 0)) * _renderer.TILE_SIZE + 0.08
	_move_marker.global_position = ground
	_move_marker.visible = true
	_move_marker_elapsed = 0.0

func _update_move_marker(delta: float) -> void:
	if _move_marker == null or not is_instance_valid(_move_marker) or not _move_marker.visible:
		return
	_move_marker_elapsed += delta
	if _move_marker_elapsed >= MARKER_SECONDS:
		_move_marker.visible = false
		return
	# Expands and fades, so it reads as a pulse rather than a decal left behind.
	var t := _move_marker_elapsed / MARKER_SECONDS
	_move_marker.scale = Vector3.ONE * (0.7 + t * 0.9)
	var material: StandardMaterial3D = _move_marker.mesh.material
	material.albedo_color.a = 1.0 - t

func screen_to_sim_hit(screen_position: Vector2) -> Dictionary:
	if camera == null or not is_instance_valid(camera):
		return {}
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 4000.0)
	query.collide_with_areas = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"position": screen_to_sim_position(screen_position), "level": 0}
	var point: Vector3 = hit["position"]
	return {
		"position": _renderer.call("world_3d_to_sim", point),
		# Rounded down: standing ON a surface at y = 6.0 means level 6.
		"level": maxi(0, int(floor(point.y / _renderer.TILE_SIZE + 0.001))),
	}

func screen_to_sim_position(screen_position: Vector2) -> Vector2:
	if camera == null or not is_instance_valid(camera):
		return Vector2.ZERO
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return Vector2.ZERO
	# Intersect the y = 0 ground plane. Elevation is cosmetic in this view; the
	# simulation grid is flat, so projecting to the logical ground keeps the
	# cursor and the simulation in agreement.
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return Vector2.ZERO
	return _renderer.call("world_3d_to_sim", origin + direction * distance)

func get_view_telemetry() -> Dictionary:
	return {
		"impassable_marks": _impassable_marks.multimesh.visible_instance_count if _impassable_marks != null and is_instance_valid(_impassable_marks) else 0,
		"units_rendered": _live_unit_count,
		"units_as_sprites": _live_sprite_count,
		"baked_archetypes": _baked_unit_art.size(),
		"economy_marks": _marked_economy_count,
		"sprite_pool_size": _sprite_pool.size(),
		"structures_rendered": _live_structure_count,
		"camera_distance": _camera_distance,
		"camera_focus": _camera_focus,
		"terrain_ready": _renderer != null and is_instance_valid(_renderer),
		"fog_active": _fog_plane != null and is_instance_valid(_fog_plane) and _fog_plane.visible,
	}
