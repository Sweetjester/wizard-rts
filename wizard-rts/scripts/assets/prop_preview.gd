extends Control

const AssetRegistryScript := preload("res://scripts/assets/asset_registry.gd")
const AssetPackConfigScript := preload("res://scripts/assets/asset_pack_config.gd")

const PREVIEW_SIZE := Vector2(128, 128)
const CARD_MIN_SIZE := Vector2(180, 188)

var _registry: Node
var _grid: GridContainer
var _status_label: Label


func _ready() -> void:
	_build_ui()
	_load_registry()
	_refresh_preview()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_top = 18
	root.offset_right = -18
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title := Label.new()
	title.text = "Prop Asset Preview"
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh_preview)
	header.add_child(refresh_button)

	_status_label = Label.new()
	_status_label.text = "Drop images into assets_game/props/*, then refresh."
	root.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_grid = GridContainer.new()
	_grid.name = "PreviewGrid"
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)


func _load_registry() -> void:
	_registry = AssetRegistryScript.new()
	add_child(_registry)
	var loaded: bool = _registry.call("load_asset_pack", "res://resources/asset_packs/tiny_swords_asset_pack.json")
	if not loaded:
		push_warning("[PropPreview] Failed to load active asset pack config.")


func _refresh_preview() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	if _registry == null:
		_load_registry()

	var total := 0
	for category in AssetPackConfigScript.prop_category_tags():
		var paths: Array[String] = _registry.call("list_prop_assets", category)
		total += paths.size()
		_add_category_header(category, paths.size())
		if paths.is_empty():
			_add_empty_card(category)
		else:
			for path in paths:
				_add_asset_card(category, path)

	if _status_label != null:
		_status_label.text = "Previewing %s prop textures. Supported: PNG, WEBP, JPG, JPEG." % total


func _add_category_header(category: StringName, count: int) -> void:
	var label := Label.new()
	label.text = "%s (%s)" % [_display_category(category), count]
	label.add_theme_font_size_override("font_size", 20)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(label)
	for i in range(maxi(0, _grid.columns - 1)):
		var spacer := Control.new()
		_grid.add_child(spacer)


func _add_empty_card(category: StringName) -> void:
	var panel := _new_card_panel()
	var label := Label.new()
	label.text = "No %s assets found.\nCopy images into:\n%s" % [
		_display_category(category).to_lower(),
		_registry.call("get_prop_category_path", category)
	]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	_grid.add_child(panel)


func _add_asset_card(category: StringName, path: String) -> void:
	var panel := _new_card_panel()

	var texture_rect := TextureRect.new()
	texture_rect.custom_minimum_size = PREVIEW_SIZE
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture = load(path) as Texture2D
	panel.add_child(texture_rect)

	var name_label := Label.new()
	name_label.text = path.get_file()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(name_label)

	var path_label := Label.new()
	path_label.text = _display_category(category)
	path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	path_label.modulate = Color("#92C7A3")
	panel.add_child(path_label)

	_grid.add_child(panel)


func _new_card_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = CARD_MIN_SIZE
	panel.add_theme_constant_override("separation", 6)
	return panel


func _display_category(category: StringName) -> String:
	match category:
		AssetPackConfigScript.TREE:
			return "Trees"
		AssetPackConfigScript.ROCK:
			return "Rocks"
		AssetPackConfigScript.RUIN:
			return "Ruins"
		AssetPackConfigScript.DECOR:
			return "Decor"
	return str(category).capitalize()
