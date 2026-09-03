extends SceneTree

# Regression guard for the locally-rendered prop sprites installed 2026-08-23.
#
# The 2D map painter gets its scatter props from AssetRegistry.list_prop_assets(), which
# lists TEXTURE files (not meshes) out of the four prop category folders. Before this
# batch there were 6 tree sprites and 3 rock sprites and nothing at all for ruins or
# decor, so RUIN/DECOR scatter could never draw. The sprites are rendered from the styled
# meshes in art/processed_props by asset-factory and dropped into those folders.
#
# This guards two things that have each broken before:
#   1. every prop category resolves to a non-empty texture list
#   2. the textures actually load as Texture2D, not just exist as paths

const AssetRegistryScript := preload("res://scripts/assets/asset_registry.gd")
const AssetPackConfigScript := preload("res://scripts/assets/asset_pack_config.gd")
const ACTIVE_PACK := "res://resources/asset_packs/dark_forest_frontier_v2_asset_pack.json"

# Deliberately low: this asserts the categories are populated at all, not that a
# particular batch size landed. Raising it would make the test brittle to art edits.
const MIN_PER_CATEGORY := 4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry: Node = AssetRegistryScript.new()
	if not registry.call("load_asset_pack", ACTIVE_PACK):
		printerr("[SpritePropCoverageSmokeTest] could not load asset pack: %s" % ACTIVE_PACK)
		quit(1)
		return

	var failures: Array[String] = []
	var totals: Array[String] = []

	for tag in AssetPackConfigScript.prop_category_tags():
		var paths: Array = registry.call("list_prop_assets", tag)
		totals.append("%s=%d" % [tag, paths.size()])

		if paths.size() < MIN_PER_CATEGORY:
			failures.append("%s has only %d sprite(s), expected at least %d"
				% [tag, paths.size(), MIN_PER_CATEGORY])
			continue

		# A path that does not load is worse than a missing one: the painter would place
		# an invisible sprite and the map would silently lose scatter.
		var loaded := 0
		for path in paths:
			var texture: Texture2D = load(str(path)) as Texture2D
			if texture != null and texture.get_size().x > 0.0:
				loaded += 1
		if loaded != paths.size():
			failures.append("%s: only %d/%d sprites loaded as usable Texture2D"
				% [tag, loaded, paths.size()])

	print("[SpritePropCoverageSmokeTest] prop sprite counts: %s" % ", ".join(totals))

	if not failures.is_empty():
		for failure in failures:
			printerr("[SpritePropCoverageSmokeTest] %s" % failure)
		quit(1)
		return

	print("[SpritePropCoverageSmokeTest] all prop categories populated and loadable")
	quit(0)
