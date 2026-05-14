class_name AssetRegistry
extends Node

const AssetPackConfigResource := preload("res://scripts/assets/asset_pack_config.gd")

@export_file("*.json", "*.tres") var active_asset_pack_path := "res://resources/asset_packs/tiny_swords_asset_pack.json"

var _active_pack: Resource
var _runtime_tileset: TileSet

const PROP_CATEGORY_FOLDERS := {
	AssetPackConfigResource.TREE: "res://assets_game/props/trees",
	AssetPackConfigResource.ROCK: "res://assets_game/props/rocks",
	AssetPackConfigResource.RUIN: "res://assets_game/props/ruins",
	AssetPackConfigResource.DECOR: "res://assets_game/props/decor",
}
const SUPPORTED_TEXTURE_EXTENSIONS: Array[String] = ["png", "webp", "jpg", "jpeg"]
const SUPPORTED_MESH_EXTENSIONS: Array[String] = ["glb", "gltf"]


func _ready() -> void:
	if active_asset_pack_path != "":
		load_asset_pack(active_asset_pack_path)


func load_asset_pack(config_path: String) -> bool:
	var config := _load_config_resource(config_path)
	if config == null:
		push_warning("[AssetRegistry] Could not load AssetPackConfig: %s" % config_path)
		_active_pack = null
		_runtime_tileset = null
		return false

	_active_pack = config
	_runtime_tileset = null
	if config.runtime_tileset_path != "":
		_runtime_tileset = load(config.runtime_tileset_path) as TileSet
		if _runtime_tileset == null:
			push_warning("[AssetRegistry] Pack '%s' could not load runtime TileSet: %s" % [config.pack_id, config.runtime_tileset_path])

	var missing := require_visual_tags(AssetPackConfigResource.required_runtime_tags())
	if not missing.is_empty():
		push_warning("[AssetRegistry] Pack '%s' is missing visual tags: %s" % [config.pack_id, ", ".join(PackedStringArray(missing))])
	return true


func _load_config_resource(config_path: String) -> Resource:
	if config_path.get_extension().to_lower() == "json":
		return _load_json_config(config_path)
	return load(config_path) as Resource


func _load_json_config(config_path: String) -> Resource:
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_warning("[AssetRegistry] Could not open JSON asset pack config: %s" % config_path)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[AssetRegistry] JSON asset pack config is not a dictionary: %s" % config_path)
		return null
	var data: Dictionary = parsed
	var config: Resource = AssetPackConfigResource.new()
	config.pack_id = str(data.get("pack_id", ""))
	config.display_name = str(data.get("display_name", ""))
	var tile_size_data: Array = data.get("tile_size", [64, 64])
	if tile_size_data.size() >= 2:
		config.tile_size = Vector2i(int(tile_size_data[0]), int(tile_size_data[1]))
	config.pixel_art = bool(data.get("pixel_art", true))
	config.runtime_tileset_path = str(data.get("runtime_tileset_path", ""))
	config.supported_visual_tags = _string_array_to_string_names(data.get("supported_visual_tags", []))
	config.terrain_mappings = _string_keys_to_string_names(data.get("terrain_mappings", {}))
	config.prop_mappings = _string_keys_to_string_names(data.get("prop_mappings", {}))
	config.unit_mappings = _string_keys_to_string_names(data.get("unit_mappings", {}))
	config.building_mappings = _string_keys_to_string_names(data.get("building_mappings", {}))
	config.asset_3d_categories = _string_keys_to_string_names(data.get("asset_3d_categories", {}))
	return config


func _string_array_to_string_names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(str(value)))
	return result


func _string_keys_to_string_names(values: Dictionary) -> Dictionary:
	var result := {}
	for key in values.keys():
		result[StringName(str(key))] = values[key]
	return result


func get_active_pack() -> Resource:
	return _active_pack


func get_runtime_tileset() -> TileSet:
	return _runtime_tileset


func has_visual_tag(tag: StringName) -> bool:
	return _active_pack != null and _active_pack.has_visual_tag(tag)


func resolve_visual_tag(tag: StringName) -> Dictionary:
	if _active_pack == null:
		push_warning("[AssetRegistry] No active asset pack while resolving tag '%s'" % tag)
		return {}
	var mapping: Dictionary = _active_pack.resolve_mapping(tag)
	if mapping.is_empty():
		push_warning("[AssetRegistry] Missing mapping for visual tag '%s' in pack '%s'" % [tag, _active_pack.pack_id])
	return mapping


func resolve_terrain(tag: StringName) -> Dictionary:
	var mapping := resolve_visual_tag(tag)
	if mapping.is_empty():
		return {}
	if str(mapping.get("kind", "")) != "terrain":
		push_warning("[AssetRegistry] Visual tag '%s' is not a terrain mapping. Found kind '%s'." % [tag, str(mapping.get("kind", ""))])
		return {}
	return mapping


func require_visual_tags(tags: Array[StringName]) -> Array[StringName]:
	var missing: Array[StringName] = []
	for tag in tags:
		if not has_visual_tag(tag):
			missing.append(tag)
	return missing


func validate_terrain_mapping(tag: StringName) -> bool:
	var mapping: Dictionary = resolve_terrain(tag)
	if mapping.is_empty():
		return false
	if _runtime_tileset == null:
		push_warning("[AssetRegistry] Cannot validate terrain tag '%s' without a runtime TileSet." % tag)
		return false
	var terrain_set_id := int(mapping.get("terrain_set_id", -1))
	var terrain_id := int(mapping.get("terrain_id", -1))
	if terrain_set_id < 0 or terrain_set_id >= _runtime_tileset.get_terrain_sets_count():
		push_warning("[AssetRegistry] Terrain tag '%s' references missing terrain_set_id %s." % [tag, terrain_set_id])
		return false
	if terrain_id < 0 or terrain_id >= _runtime_tileset.get_terrains_count(terrain_set_id):
		push_warning("[AssetRegistry] Terrain tag '%s' references missing terrain_id %s in set %s." % [tag, terrain_id, terrain_set_id])
		return false
	return true


func get_prop_category_path(tag: StringName) -> String:
	return str(PROP_CATEGORY_FOLDERS.get(tag, ""))


func get_prop_categories() -> Array[StringName]:
	return AssetPackConfigResource.prop_category_tags()


func list_prop_assets(tag: StringName) -> Array[String]:
	var folder_path := get_prop_category_path(tag)
	if folder_path == "":
		push_warning("[AssetRegistry] Unknown prop category '%s'." % tag)
		return []
	var mapping := resolve_visual_tag(tag)
	if not mapping.is_empty() and str(mapping.get("kind", "")) == "folder":
		folder_path = str(mapping.get("path", folder_path))
	return _list_assets(folder_path, SUPPORTED_TEXTURE_EXTENSIONS)


func list_mesh_assets(tag: StringName) -> Array[String]:
	var category := resolve_3d_category(tag)
	if not category.is_empty():
		return _asset_paths_for_category(category, SUPPORTED_MESH_EXTENSIONS)
	var mapping := resolve_visual_tag(tag)
	if mapping.is_empty():
		return []
	var kind := str(mapping.get("kind", ""))
	if kind == "file":
		var path := str(mapping.get("path", ""))
		return [path] if _is_supported_extension(path, SUPPORTED_MESH_EXTENSIONS) else []
	if kind != "folder":
		return []
	var extensions: Array = mapping.get("extensions", SUPPORTED_MESH_EXTENSIONS)
	return _list_assets(str(mapping.get("path", "")), _string_array(extensions))


func resolve_3d_category(tag: StringName) -> Dictionary:
	if _active_pack == null:
		push_warning("[AssetRegistry] No active asset pack while resolving 3D category '%s'" % tag)
		return {}
	var categories: Dictionary = _active_pack.get("asset_3d_categories")
	if not categories.has(tag):
		return {}
	var category: Dictionary = categories[tag]
	return category


func get_3d_categories() -> Array[StringName]:
	var result: Array[StringName] = []
	if _active_pack == null:
		return result
	var categories: Dictionary = _active_pack.get("asset_3d_categories")
	for key in categories.keys():
		result.append(StringName(str(key)))
	result.sort()
	return result


func get_3d_category_asset_defs(tag: StringName) -> Array[Dictionary]:
	var category := resolve_3d_category(tag)
	if category.is_empty():
		return []
	var defs: Array[Dictionary] = []
	if category.has("assets"):
		for value in category["assets"]:
			if value is Dictionary:
				defs.append(value)
	elif category.has("path"):
		defs.append(category)
	elif category.has("folder"):
		for path in _list_assets(str(category.get("folder", "")), _string_array(category.get("extensions", SUPPORTED_MESH_EXTENSIONS))):
			var item := category.duplicate(true)
			item["path"] = path
			defs.append(item)
	return defs


func load_3d_category_material(tag: StringName) -> Material:
	var category := resolve_3d_category(tag)
	if category.is_empty():
		return null
	var material_path := str(category.get("material_path", ""))
	if material_path == "":
		return null
	return load(material_path) as Material


func list_visual_assets(tag: StringName, extensions: Array[String] = []) -> Array[String]:
	var mapping := resolve_visual_tag(tag)
	if mapping.is_empty():
		return []
	var active_extensions := extensions
	if active_extensions.is_empty():
		active_extensions = []
		active_extensions.append_array(SUPPORTED_TEXTURE_EXTENSIONS)
		active_extensions.append_array(SUPPORTED_MESH_EXTENSIONS)
	var kind := str(mapping.get("kind", ""))
	if kind == "file":
		var path := str(mapping.get("path", ""))
		return [path] if _is_supported_extension(path, active_extensions) else []
	if kind == "folder":
		var mapping_extensions: Array = mapping.get("extensions", active_extensions)
		return _list_assets(str(mapping.get("path", "")), _string_array(mapping_extensions))
	return []


func _asset_paths_for_category(category: Dictionary, extensions: Array[String]) -> Array[String]:
	var paths: Array[String] = []
	if category.has("assets"):
		for value in category["assets"]:
			if value is Dictionary:
				var path := str(value.get("path", ""))
				if _is_supported_extension(path, extensions):
					paths.append(path)
		paths.sort()
		return paths
	if category.has("path"):
		var path := str(category.get("path", ""))
		return [path] if _is_supported_extension(path, extensions) else []
	if category.has("folder"):
		return _list_assets(str(category.get("folder", "")), _string_array(category.get("extensions", extensions)))
	return paths


func list_all_prop_assets() -> Dictionary:
	var result := {}
	for tag in get_prop_categories():
		result[tag] = list_prop_assets(tag)
	return result


func _list_texture_assets(folder_path: String) -> Array[String]:
	return _list_assets(folder_path, SUPPORTED_TEXTURE_EXTENSIONS)


func _list_assets(folder_path: String, extensions: Array[String]) -> Array[String]:
	var assets: Array[String] = []
	_collect_assets(folder_path, assets, extensions)
	assets.sort()
	return assets


func _collect_assets(folder_path: String, assets: Array[String], extensions: Array[String]) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_warning("[AssetRegistry] Prop asset folder missing: %s" % folder_path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var entry_path := folder_path.path_join(entry)
		if dir.current_is_dir():
			_collect_assets(entry_path, assets, extensions)
		elif _is_supported_extension(entry, extensions):
			assets.append(entry_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _is_supported_texture(file_name: String) -> bool:
	return _is_supported_extension(file_name, SUPPORTED_TEXTURE_EXTENSIONS)


func _is_supported_extension(file_name: String, extensions: Array[String]) -> bool:
	return extensions.has(file_name.get_extension().to_lower())


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value).to_lower())
	return result
