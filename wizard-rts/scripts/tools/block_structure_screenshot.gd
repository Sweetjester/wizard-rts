extends SceneTree

# Captures the block-structure viewer for a few structures and unit classes, so
# the reachability colouring can be checked without driving the scene by hand.
# Not part of the suite -- a verification tool, like map_3d_mode_screenshot.gd.

const OUT_DIR := "user://block_structure_verification"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	# structure, unit class, camera orbit, label
	var shots := [
		[&"fortress_gatehouse_02_walkable", &"infantry", Vector2(-0.55, 0.55), "gatehouse_infantry"],
		[&"fortress_gatehouse_02_walkable", &"heavy", Vector2(-0.55, 0.55), "gatehouse_heavy"],
		[&"fortress_gatehouse_01", &"infantry", Vector2(-0.55, 0.55), "gatehouse_original_infantry"],
		[&"witchfire_ziggurat_01", &"infantry", Vector2(-0.60, 0.75), "ziggurat_infantry"],
		[&"hollowspire_tower_01", &"climber", Vector2(-0.35, 0.65), "hollowspire_climber"],
	]
	for shot in shots:
		var scene: Node = load("res://scenes/blocks/block_structure_test.tscn").instantiate()
		scene.set("start_structure", shot[0])
		root.add_child(scene)
		for _i in 6:
			await process_frame
		scene.call("_load_structure", shot[0])
		scene.set("_class_index", scene.get("CLASSES").find(shot[1]))
		scene.call("_handle_key", _key(KEY_C))  # applies the class and refreshes
		scene.set("_class_index", scene.get("CLASSES").find(shot[1]))
		scene.get("_debug").call("set_unit_class", shot[1])
		scene.call("_refresh_legend")
		scene.set("_orbit", shot[2])
		scene.call("_apply_camera")
		for _i in 8:
			await process_frame
		var image := root.get_texture().get_image()
		if image != null:
			image.save_png("%s/%s.png" % [OUT_DIR, shot[3]])
		print("[BlockShot] %s / %s" % [shot[0], shot[1]])
		scene.queue_free()
		await process_frame
		await process_frame
	print("[BlockShot] saved to ", ProjectSettings.globalize_path(OUT_DIR))
	quit(0)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
