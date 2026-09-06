extends Node

var view: Node3D
var light: OmniLight3D
var enabled := true
var hero: Node2D
var elapsed := 0.0

func _ready() -> void:
	view = get_parent()
	light = OmniLight3D.new()
	light.name = "ObserverGlow"
	light.light_color = Color("67c9b9")
	match str(get_node("/root/GameSession").wizard_class_id):
		"hellfire_baby": light.light_color = Color("ec946b")
		"evangalion": light.light_color = Color("d9bf79")
	light.omni_range = 4.0
	light.omni_attenuation = 1.8
	light.shadow_enabled = false
	light.visible = false
	view.add_child.call_deferred(light)
	get_node("/root/DisplayManager").settings_changed.connect(_settings)
	_settings()

func _settings() -> void:
	var settings := get_node("/root/DisplayManager")
	enabled = settings.atmospheric_effects and not settings.performance_mode
	var environment: Environment = view.get_node("Environment").environment
	environment.glow_enabled = enabled
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.15
	view.get_node("Sun").shadow_enabled = not settings.performance_mode
	if is_instance_valid(light): light.visible = false

func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(light) or not light.is_inside_tree(): return
	elapsed += delta
	if not is_instance_valid(hero):
		hero = view.get_parent().get_node_or_null("Wizard") as Node2D
	if not is_instance_valid(hero) or not hero.has_method("is_alive") or not hero.is_alive():
		light.visible = false
		return
	# Only our visible hero receives a light; unseen enemy positions never leak.
	light.visible = int(hero.get("owner_player_id"))==1 and view._is_revealed(hero)
	if not light.visible: return
	light.position = view._unit_transform(hero).origin + Vector3(0,0.8,0)
	light.light_energy = 0.48 + 0.035*sin(elapsed*1.3)
