extends Node3D

const AssetRegistryScript := preload("res://scripts/assets/asset_registry.gd")

@export_file("*.json", "*.tres") var asset_pack := "res://resources/asset_packs/dark_forest_frontier_v2_asset_pack.json"

var _registry: Node


func _ready() -> void:
	_create_light()
	_registry = AssetRegistryScript.new()
	add_child(_registry)
	if not bool(_registry.call("load_asset_pack", asset_pack)):
		push_error("[Asset3DPreview] Failed to load asset pack: %s" % asset_pack)
		return
	_build_preview()


func _create_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.6
	add_child(light)
	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.current = true
	camera.position = Vector3(8.0, 10.0, 13.0)
	add_child(camera)
	camera.look_at(Vector3(4.0, 0.0, 2.5), Vector3.UP)


func _build_preview() -> void:
	var categories: Array = _registry.call("get_3d_categories")
	var x := 0.0
	var z := 0.0
	var total := 0
	for category_value in categories:
		var category := StringName(str(category_value))
		_add_label(str(category), Vector3(x, 1.8, z - 0.9))
		var defs: Array = _registry.call("get_3d_category_asset_defs", category)
		var material: Material = _registry.call("load_3d_category_material", category)
		if material != null:
			var swatch := MeshInstance3D.new()
			swatch.name = "%s_material_swatch" % str(category)
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.85, 0.1, 0.85)
			swatch.mesh = mesh
			swatch.material_override = material
			swatch.position = Vector3(x, 0.05, z)
			add_child(swatch)
			x += 1.25
			total += 1
		for def_value in defs:
			var definition: Dictionary = def_value
			var scene := load(str(definition.get("path", ""))) as PackedScene
			if scene == null:
				continue
			var instance := scene.instantiate() as Node3D
			instance.name = "%s_preview" % str(category)
			instance.position = Vector3(x, 0.0, z)
			add_child(instance)
			x += 1.35
			total += 1
		x = 0.0
		z += 2.5
	print("[Asset3DPreview] pack=", asset_pack, " categories=", categories.size(), " preview_items=", total)


func _add_label(text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = position
	add_child(label)
