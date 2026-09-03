extends SceneTree

# Regression guard for the bulk-selection rule added 2026-08-31 alongside the
# army-control hotkeys (RTSWorld.selected_unit_count / BULK_SELECTION_THRESHOLD,
# RTSUnit._selection_is_bulk(), MassUnitMultimeshRenderer's honour_selection).
#
# This test exists specifically because the smoke suite has historically only
# checked correctness, never cost -- see the 2026-08-23 Decisions Log entry on
# the two performance regressions that every automated test missed. "Selected"
# used to be a blanket exemption from every mass-LOD optimisation, which was
# fine when selecting meant a dozen units and became a lag switch the moment a
# single key could select the entire army. The assertions below are behavioural
# stand-ins for that cost: if they fail, the optimisations are being bypassed.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "bulk-selection-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var selection: Node = scene.get_node_or_null("SelectionController")
	var world: RTSWorld = scene.get_node_or_null("RTSWorld")
	var renderer: Node = scene.get_node_or_null("MassUnitMultimeshRenderer")
	if selection == null or world == null or renderer == null:
		_fail("Expected SelectionController, RTSWorld and MassUnitMultimeshRenderer in main_map.tscn")
		return

	var threshold := RTSWorld.BULK_SELECTION_THRESHOLD
	var units := _spawn(scene, "res://scenes/units/terrible_thing.tscn", threshold + 12, Vector2(4000, 4000))
	await process_frame

	# --- a small (squad-sized) selection keeps full fidelity ---------------
	var squad: Array[Node] = []
	for i in 6:
		squad.append(units[i])
	selection.call("_apply_selection", squad)
	if world.selected_unit_count != 6:
		_fail("RTSWorld.selected_unit_count should track the live selection, got %s" % world.selected_unit_count)
		return
	if bool(units[0].call("_selection_is_bulk")):
		_fail("A 6-unit selection must not count as bulk")
		return
	units[0].call("set_central_mass_movement_active", true)
	if bool(units[0].call("uses_central_mass_movement")):
		_fail("A hand-selected unit should stay on per-node physics, not the central movement loop")
		return

	# --- a whole-army selection does not ----------------------------------
	selection.call("_apply_selection", units)
	if world.selected_unit_count != units.size():
		_fail("Expected selected_unit_count %s, got %s" % [units.size(), world.selected_unit_count])
		return
	if not bool(units[0].call("_selection_is_bulk")):
		_fail("A %s-unit selection should count as bulk (threshold %s)" % [units.size(), threshold])
		return
	units[0].call("set_central_mass_movement_active", true)
	if not bool(units[0].call("uses_central_mass_movement")):
		_fail("A bulk-selected unit must still be allowed onto RTSWorld's budgeted central movement loop")
		return

	# --- the multimesh LOD renderer stops force-promoting selected units ---
	# closest_full_detail_count is zeroed for this check so the assertion is
	# about the selection override alone and not about the (unrelated) rule
	# that the N nearest units are always full detail. The camera is parked far
	# from the test units, zoomed in so the view rect is small -- at the default
	# 0.2 zoom the visible rect is ~9600px wide and covers the whole map, which
	# would make every unit "on screen" and the check meaningless. The camera is
	# moved AFTER the last awaited frame because CameraController._clamp_to_map()
	# would otherwise pull it back on the next tick.
	renderer.set("closest_full_detail_count", 0)
	renderer.set("camera_view_margin", 0.0)
	await process_frame
	var camera: Camera2D = scene.get_node_or_null("Camera2D")
	if camera == null:
		_fail("Expected a Camera2D to position for the LOD check")
		return
	camera.zoom = Vector2(2.0, 2.0)
	camera.position = Vector2(200, 200)
	renderer.call("_refresh_instances")
	var blob_ids: Dictionary = renderer.get("_blob_ids")
	var blobbed := 0
	for unit in units:
		if blob_ids.has(unit.get_instance_id()):
			blobbed += 1
	if blobbed == 0:
		_fail("Off-screen units in a bulk selection should still batch as multimesh blobs; none did")
		return

	# ...and still honours it for a squad-sized selection.
	selection.call("_apply_selection", squad)
	renderer.call("_refresh_instances")
	blob_ids = renderer.get("_blob_ids")
	for unit in squad:
		if blob_ids.has(unit.get_instance_id()):
			_fail("A hand-selected unit should still be force-promoted to full detail")
			return

	# --- deselecting releases the bulk flag -------------------------------
	selection.call("_apply_selection", [] as Array[Node])
	if world.selected_unit_count != 0:
		_fail("Clearing the selection should reset selected_unit_count, got %s" % world.selected_unit_count)
		return

	print("[BulkSelectionLodSmokeTest] squad selections keep full fidelity, army-wide selections do not defeat the LOD system")
	quit(0)

func _spawn(scene: Node, scene_path: String, count: int, origin: Vector2) -> Array[Node]:
	var packed: PackedScene = load(scene_path)
	var spawned: Array[Node] = []
	for i in count:
		var unit: Node = packed.instantiate()
		unit.set("owner_player_id", 1)
		scene.add_child(unit)
		unit.global_position = origin + Vector2(float(i % 10) * 40.0, float(i / 10) * 40.0)
		spawned.append(unit)
	return spawned

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
