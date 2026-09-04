class_name XraySilhouette
extends MeshInstance3D

# Keeps a unit visible when a building is in the way.
#
# An RTS where units vanish inside their own structures is unplayable: you
# cannot select what you cannot see, and a unit on the far side of a tower reads
# as dead rather than hidden. So a second copy of the unit is drawn with the
# depth test off, in a bright flat colour, ON TOP of whatever is occluding it.
#
# WHY THIS APPROACH, on performance grounds:
#
#   * The silhouette is one extra draw of an already-tiny mesh, unshaded, with
#     no lighting or shadow work. It costs almost nothing to draw.
#   * It is only shown when the unit is ACTUALLY occluded, decided by a single
#     raycast from the camera. Drawing it unconditionally would be cheaper still
#     but looks wrong -- an unoccluded unit would render over things genuinely in
#     front of it, which reads as a z-fighting bug rather than a feature.
#   * That raycast is THROTTLED rather than run every frame. Occlusion changes
#     when the camera or the unit moves, not at render rate, and a few frames of
#     latency on "is it hidden" is imperceptible.
#
# Scaling: one raycast per tracked unit per throttle tick. At the demo's handful
# that is free. At the hundreds Section 5 targets you would not track every unit
# -- only the player's selection and anything inside a structure's footprint,
# which is a small set by definition. The silhouette draw itself scales fine
# because it can be batched into a MultiMesh the same way the unit sprites are.

const CHECK_INTERVAL := 0.12

@export var color: Color = Color("#4ADE80")

var target: Node3D
var camera: Camera3D

var _elapsed := 0.0
var _material: StandardMaterial3D

func setup(new_target: Node3D, new_camera: Camera3D, mesh_source: Mesh, silhouette_color: Color) -> void:
	target = new_target
	camera = new_camera
	color = silhouette_color
	mesh = mesh_source
	# Slightly larger so it reads as a halo around the shape rather than
	# z-fighting with the unit's own body on the frames it is visible.
	scale = Vector3.ONE * 1.12
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = color
	_material.no_depth_test = true
	_material.render_priority = 10
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

func set_color(new_color: Color) -> void:
	color = new_color
	if _material != null:
		_material.albedo_color = new_color

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or camera == null:
		return
	global_position = target.global_position
	_elapsed += delta
	if _elapsed < CHECK_INTERVAL:
		return
	_elapsed = 0.0
	visible = _is_occluded()

# One ray, camera to unit, against the world's static bodies. Stops short of the
# unit itself so the unit's own body never counts as its own occluder.
func _is_occluded() -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := camera.global_position
	var to := target.global_position
	var direction := to - from
	var distance := direction.length()
	if distance < 0.5:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, from + direction.normalized() * (distance - 0.45))
	query.collide_with_areas = false
	return not space.intersect_ray(query).is_empty()
