extends TextureRect

var elapsed := 0.0
var active_effects := true

func _ready() -> void:
	texture = preload("res://assets/ui/observer_vault/library_drawn_v2.png")
	expand_mode = EXPAND_IGNORE_SIZE
	stretch_mode = STRETCH_KEEP_ASPECT_COVERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://assets/ui/observer_vault/library_light.gdshader")
	material = shader
	get_node("/root/DisplayManager").settings_changed.connect(_settings)
	_settings()

func _settings() -> void:
	var settings := get_node("/root/DisplayManager")
	active_effects = settings.atmospheric_effects and not settings.performance_mode
	(material as ShaderMaterial).set_shader_parameter("strength", 1.0 if active_effects else 0.0)

func _process(delta: float) -> void:
	if not active_effects or not is_visible_in_tree(): return
	elapsed += minf(delta, 0.05)
	(material as ShaderMaterial).set_shader_parameter("clock", elapsed)
