extends Node

var lights: Array[OmniLight3D]=[]
var materials: Array[ShaderMaterial]=[]

func _ready() -> void:
	_collect(get_parent())
	var settings := get_node_or_null("/root/DisplayManager")
	if settings!=null:
		settings.settings_changed.connect(_settings)
	_settings()

func _collect(node: Node) -> void:
	if node is OmniLight3D: lights.append(node)
	if node is GeometryInstance3D and node.material_override is ShaderMaterial:
		var mat: ShaderMaterial=node.material_override
		if mat.shader in [preload("res://assets/structures/observation_tower_hd/detail.gdshader"),preload("res://assets/structures/observation_tower_hd/dome.gdshader")]: materials.append(mat)
	for child in node.get_children():
		if child!=self: _collect(child)

func _settings() -> void:
	var settings := get_node_or_null("/root/DisplayManager")
	var enabled: bool=settings==null or (settings.atmospheric_effects and not settings.performance_mode)
	for light in lights: light.visible=enabled
	for mat in materials: mat.set_shader_parameter("animate",enabled)
