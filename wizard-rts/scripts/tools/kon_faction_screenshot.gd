extends SceneTree

# Verification tool (NOT a smoke test -- it needs a real window, so it is not
# part of the headless CI suite). Boots the actual shipping scene as a Bad Kon
# Willow run, stands up a Biospawner, spawns one of each KoN roster unit, drops
# a unit card into the HUD layer, and saves a screenshot.
#
# Exists because Unattended_Work_Definition_of_Done.md requires visual evidence
# from scripts/map/main_map.tscn itself, not from an isolated preview scene.
#
# Run:  Godot_v4.6.2-stable_win64.exe --path <project> -s scripts/tools/kon_faction_screenshot.gd

const OUT_DIR := "user://kon_faction_verification"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "kon-faction-shot", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 8:
		await process_frame

	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	var hud: Node = scene.get_node_or_null("RTSHud")
	var camera: Camera2D = scene.get_node_or_null("Camera2D")
	var tower: Node = _find_structure(scene, "wizard_tower")
	if build_system == null or hud == null or tower == null:
		push_error("Scene did not come up as expected")
		quit(1)
		return
	economy.call("add_resource", 1, &"bio", 20000)

	var base_cell: Vector2i = map_generator.call("world_to_cell", (tower as Node2D).global_position)
	build_system.call("add_free_structure", 1, &"barracks", base_cell + Vector2i(6, 6), "")
	build_system.call("add_free_structure", 1, &"bio_absorber", map_generator.call("nearest_walkable_cell", base_cell + Vector2i(3, -5), 10), "")
	build_system.call("research_upgrade", 1, &"tier_two_hybrids")
	build_system.call("research_upgrade", 1, &"tier_three_hybrids")

	# One of each, so the KoN evolution palette and the silhouettes are visible
	# side by side against the observer-themed hero.
	var origin: Vector2 = (tower as Node2D).global_position + Vector2(-140, 150)
	var spawned: Array[Node] = []
	var roster := [
		["res://scenes/units/oaven_spear.tscn", 4],
		["res://scenes/units/stone_face_serpent.tscn", 1],
		["res://scenes/units/spawner.tscn", 1],
	]
	var index := 0
	for entry in roster:
		for _n in int(entry[1]):
			var unit: Node = (load(entry[0]) as PackedScene).instantiate()
			unit.set("owner_player_id", 1)
			scene.add_child(unit)
			unit.global_position = origin + Vector2(float(index) * 74.0, 0.0)
			spawned.append(unit)
			index += 1
	for _i in 6:
		await process_frame

	if camera != null:
		camera.zoom = Vector2(1.1, 1.1)
		camera.position = (tower as Node2D).global_position + Vector2(0, 90)
	for _i in 20:
		await process_frame

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_save_shot("01_kon_units_in_shipping_scene.png")

	# Now the unit card itself. It normally lives in a separate OS Window, which
	# a viewport grab cannot see, so for the screenshot it is parented into the
	# HUD's CanvasLayer instead.
	var overlay := PanelContainer.new()
	overlay.position = Vector2(160, 120)
	overlay.custom_minimum_size = Vector2(900, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	overlay.add_child(column)
	for archetype in [&"life_wizard", &"oaven_spear", &"stone_face_serpent", &"spawner"]:
		column.add_child(hud.call("_build_stat_card", archetype))
	hud.add_child(overlay)
	for _i in 20:
		await process_frame
	_save_shot("02_kon_unit_cards.png")

	print("[KonFactionScreenshot] wrote verification images to ", ProjectSettings.globalize_path(OUT_DIR))
	quit(0)

func _save_shot(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("No viewport image -- this tool needs a real window, do not run it with --headless")
		return
	image.save_png("%s/%s" % [OUT_DIR, file_name])
	print("[KonFactionScreenshot] saved ", file_name, " ", image.get_size())

func _find_structure(scene: Node, archetype: String) -> Node:
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == 1 and str(structure.get("archetype")) == archetype:
			return structure
	return null
