extends SceneTree

# Interaction parity guard for the 3D view (added 2026-09-02).
#
# WHY THIS EXISTS, honestly: the first 3D pass shipped with a test that verified
# the screen-to-simulation coordinate maths round-tripped, and that was reported
# as "selection, orders and building placement all work". They did not. Camera
# panning was keyboard-only, the drag rectangle and the build preview were both
# CanvasItems hidden along with the rest of the 2D presentation, and drag-select
# projected a screen rectangle onto the ground plane, which is a trapezoid under
# a perspective camera.
#
# Round-tripping a coordinate is not the same as being able to play. This test
# drives the ACTUAL interaction paths instead.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "map3d-interaction", "bad_kon_willow", "seeded_grid_frontier", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 10:
		await process_frame

	var view: Node = scene.get_node_or_null("Map3DView")
	var selection: Node = scene.get_node_or_null("SelectionController")
	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	if view == null or selection == null or build_system == null or map_generator == null:
		_fail("3D mode did not come up with the systems it needs")
		return
	economy.call("add_resource", 1, &"bio", 20000)

	# --- camera: pan, drag and clamp --------------------------------------
	var start_focus: Vector3 = view.call("get_view_telemetry").get("camera_focus", Vector3.ZERO)
	view.call("focus_on_sim_position", map_generator.call("cell_to_world", Vector2i(40, 40)))
	var moved_focus: Vector3 = view.call("get_view_telemetry").get("camera_focus", Vector3.ZERO)
	if moved_focus.distance_to(start_focus) < 0.5:
		_fail("The 3D camera should be movable")
		return
	# Off-map focus must be clamped back, or the player pans into the void with
	# no way home -- CameraController._clamp_to_map() does this in 2D.
	view.call("focus_on_sim_position", Vector2(-500000.0, -500000.0))
	var clamped: Vector3 = view.call("get_view_telemetry").get("camera_focus", Vector3.ZERO)
	if clamped.x < -1.0 or clamped.z < -1.0:
		_fail("The 3D camera focus must be clamped to the map, got %s" % clamped)
		return

	# --- mouse drag pans 1:1 ----------------------------------------------
	# The ground point under the cursor must stay under the cursor. A fixed
	# pixels-to-world factor cannot achieve that under a perspective camera,
	# which is why the first version felt wrong to drag.
	view.call("focus_on_sim_position", map_generator.call("cell_to_world", Vector2i(48, 48)))
	var probe_screen := Vector2(700.0, 500.0)
	var before_drag: Vector2 = view.call("screen_to_sim_position", probe_screen)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	view.call("_unhandled_input", press)
	var motion := InputEventMouseMotion.new()
	motion.position = probe_screen
	motion.relative = Vector2(120.0, 80.0)
	view.call("_unhandled_input", motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_MIDDLE
	release.pressed = false
	view.call("_unhandled_input", release)
	var after_drag: Vector2 = view.call("screen_to_sim_position", probe_screen)
	if after_drag.distance_to(before_drag) < 32.0:
		_fail("A middle-mouse drag should pan the 3D camera, moved only %s" % after_drag.distance_to(before_drag))
		return
	# Dragging right/down should bring ground from the upper-left into view,
	# i.e. the sim position under a fixed screen point decreases.
	if after_drag.x >= before_drag.x or after_drag.y >= before_drag.y:
		_fail("Drag direction is inverted: %s -> %s" % [before_drag, after_drag])
		return

	# --- drag-select actually selects -------------------------------------
	var anchor := map_generator.call("cell_to_world", map_generator.call("nearest_walkable_cell", Vector2i(34, 34), 20)) as Vector2
	view.call("focus_on_sim_position", anchor)
	view.call("set_camera_distance", 26.0)
	var squad: Array[Node] = []
	for i in 4:
		var unit: Node = (load("res://scenes/units/terrible_thing.tscn") as PackedScene).instantiate()
		unit.set("owner_player_id", 1)
		scene.add_child(unit)
		unit.global_position = anchor + Vector2(float(i) * 40.0 - 60.0, 0.0)
		squad.append(unit)
	for _i in 6:
		await process_frame

	# Build the drag rectangle in SCREEN space, which is what the 3D path uses.
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for unit in squad:
		var screen: Vector2 = view.call("sim_to_screen", (unit as Node2D).global_position)
		min_point = Vector2(minf(min_point.x, screen.x), minf(min_point.y, screen.y))
		max_point = Vector2(maxf(max_point.x, screen.x), maxf(max_point.y, screen.y))
	var drag := Rect2(min_point - Vector2(40, 60), (max_point - min_point) + Vector2(80, 120))
	selection.call("_select_units", drag)
	var selected: Array = selection.get("selected_units")
	if selected.size() < squad.size():
		_fail("Drag-select in 3D should have caught all %s units, got %s" % [squad.size(), selected.size()])
		return

	# A drag somewhere else must NOT keep them selected -- proves the rectangle
	# is actually being tested against unit positions, not just always passing.
	selection.call("_select_units", Rect2(Vector2(2.0, 2.0), Vector2(30.0, 30.0)))
	if (selection.get("selected_units") as Array).size() != 0:
		_fail("An empty region should select nothing, got %s" % (selection.get("selected_units") as Array).size())
		return

	# --- the drag rectangle is visible ------------------------------------
	var overlay: Node = null
	var overlay_layer: Node = view.get_node_or_null("Overlay3D")
	if overlay_layer != null:
		overlay = overlay_layer.get_node_or_null("Map3DOverlay")
	if overlay == null:
		_fail("The 3D view needs a CanvasLayer overlay for the drag rectangle, or selection is invisible")
		return
	view.call("set_drag_rect", true, drag)
	if not bool(overlay.get("drag_active")):
		_fail("The overlay should show the drag rectangle while dragging")
		return
	view.call("set_drag_rect", false, Rect2())
	if bool(overlay.get("drag_active")):
		_fail("The overlay should clear the drag rectangle when the drag ends")
		return

	# --- building: preview appears, and placement actually lands ----------
	# Barracks rather than bio_absorber: the absorber additionally requires an
	# economy plot, which would make a placement failure ambiguous here.
	# A ground building on purpose: tower modules never enter placement mode, so
	# they have no footprint to preview (master doc section 39).
	build_system.call("start_placement", &"bio_launcher")
	for _i in 3:
		await process_frame
	var placement_root: Node = view.get_node_or_null("PlacementPreview3D")
	if placement_root == null:
		_fail("Expected a 3D placement preview root")
		return
	var visible_pads := 0
	for pad in placement_root.get_children():
		if pad is MeshInstance3D and (pad as MeshInstance3D).visible:
			visible_pads += 1
	if visible_pads <= 0:
		_fail("A pending structure must show a 3D placement footprint, or the player is building blind")
		return

	# And the placement path itself still works through the 3D mouse bridge.
	var before := int(build_system.call("get_structures").size())
	var target_cell: Vector2i = map_generator.call("nearest_walkable_cell", Vector2i(36, 36), 20)
	if not bool(build_system.call("try_place_structure", 1, &"bio_launcher", target_cell)):
		_fail("Placing a structure should succeed in the 3D mode")
		return
	if int(build_system.call("get_structures").size()) <= before:
		_fail("The placed structure did not reach the build system")
		return

	# Clearing the pending build must clear the preview too.
	build_system.set("pending_archetype", &"")
	for _i in 3:
		await process_frame
	visible_pads = 0
	for pad in placement_root.get_children():
		if pad is MeshInstance3D and (pad as MeshInstance3D).visible:
			visible_pads += 1
	if visible_pads != 0:
		_fail("The placement preview should clear when nothing is pending, %s pads still visible" % visible_pads)
		return

	print("[Map3DInteractionSmokeTest] camera pan/clamp, drag-select, drag overlay and build placement all work in the 3D view")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
