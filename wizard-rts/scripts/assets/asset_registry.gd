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
const SUPPORTED_TEXTURE_EXTENSIONS := ["png", "webp", "jpg", "jpeg"]


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
	return _list_texture_assets(folder_path)


func list_all_prop_assets() -> Dictionary:
	var result := {}
	for tag in get_prop_categories():
		result[tag] = list_prop_assets(tag)
	return result


func _list_texture_assets(folder_path: String) -> Array[String]:
	var assets: Array[String] = []
	_collect_texture_assets(folder_path, assets)
	assets.sort()
	return assets


func _collect_texture_assets(folder_path: String, assets: Array[String]) -> void:
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
			_collect_texture_assets(entry_path, assets)
		elif _is_supported_texture(entry):
			assets.append(entry_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _is_supported_texture(file_name: String) -> bool:
	return SUPPORTED_TEXTURE_EXTENSIONS.has(file_name.get_extension().to_lower())
