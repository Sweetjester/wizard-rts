extends SceneTree

# Regression guard for the numbered control groups and the "reinforce group"
# added 2026-08-31 (scripts/input/control_group_manager.gd, driven through
# SelectionController's public assign/add/recall/toggle API).
#
# What this test is actually protecting:
#   1. assign replaces, add unions, recall selects -- the SC2/WC3 contract.
#   2. Auto-cleanup: a unit that dies leaves every group it was in, without
#      anything polling for it. This is the behaviour that makes control
#      groups usable at all with a disposable swarm.
#   3. The reinforce group absorbs newly trained units and points them at the
#      army's live position -- the Wizard-RTS-specific piece.
#   4. The reinforce flag is exclusive (flagging group 2 clears group 1).

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "control-group-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var selection: Node = scene.get_node_or_null("SelectionController")
	if selection == null:
		_fail("Expected a SelectionController in main_map.tscn")
		return
	var groups = selection.get("control_groups")
	if groups == null:
		_fail("SelectionController should own a ControlGroupManager")
		return

	var units := _spawn_units(scene, "res://scenes/units/terrible_thing.tscn", 4, Vector2(2000, 2000))
	if units.size() != 4:
		_fail("Expected to spawn 4 test units, got %s" % units.size())
		return
	await process_frame

	# --- assign / recall ---------------------------------------------------
	selection.call("_apply_selection", [units[0], units[1]] as Array[Node])
	if int(selection.call("assign_control_group", 1)) != 2:
		_fail("assign_control_group(1) should have stored 2 units")
		return
	selection.call("_apply_selection", [] as Array[Node])
	if int(selection.call("recall_control_group", 1, false)) != 2:
		_fail("recall_control_group(1) should have reselected 2 units")
		return
	if (selection.get("selected_units") as Array).size() != 2:
		_fail("Recall should leave exactly the group members selected")
		return

	# --- add unions, assign replaces --------------------------------------
	selection.call("_apply_selection", [units[2]] as Array[Node])
	selection.call("add_to_control_group", 1)
	if int(groups.call("count", 1)) != 3:
		_fail("Shift-add should union into the group, got %s" % groups.call("count", 1))
		return
	selection.call("_apply_selection", [units[3]] as Array[Node])
	selection.call("assign_control_group", 1)
	if int(groups.call("count", 1)) != 1:
		_fail("Ctrl-assign should replace the group, got %s" % groups.call("count", 1))
		return

	# --- auto-cleanup on death, with no polling ---------------------------
	selection.call("_apply_selection", [units[0], units[1], units[2]] as Array[Node])
	selection.call("assign_control_group", 2)
	selection.call("_apply_selection", [units[0]] as Array[Node])
	selection.call("assign_control_group", 3)
	units[0].queue_free()
	await process_frame
	await process_frame
	if int(groups.call("count", 2)) != 2:
		_fail("A dead unit should leave group 2 automatically, count is %s" % groups.call("count", 2))
		return
	if int(groups.call("count", 3)) != 0:
		_fail("A dead unit should leave every group it was in, group 3 count is %s" % groups.call("count", 3))
		return
	# And recalling a group whose members all died must not select anything.
	selection.call("_apply_selection", [] as Array[Node])
	if int(selection.call("recall_control_group", 3, false)) != 0:
		_fail("Recalling an emptied group should select nothing")
		return

	# --- reinforce group ---------------------------------------------------
	selection.call("_apply_selection", [units[1], units[2]] as Array[Node])
	selection.call("assign_control_group", 4)
	if not bool(selection.call("toggle_reinforce_group", 4)):
		_fail("toggle_reinforce_group(4) should turn the flag on")
		return
	if int(groups.call("reinforce_group")) != 4:
		_fail("Group 4 should be the reinforce target")
		return
	var rally = groups.call("reinforce_rally_position")
	if rally == null:
		_fail("A non-empty reinforce group should report a rally position")
		return
	var expected: Vector2 = (units[1].global_position + units[2].global_position) * 0.5
	if (rally as Vector2).distance_to(expected) > 1.0:
		_fail("Reinforce rally should be the group's live centroid, got %s want %s" % [rally, expected])
		return

	# A freshly trained unit joins the flagged group on the build system's
	# signal path, not by being manually selected first.
	var recruit := _spawn_units(scene, "res://scenes/units/terrible_thing.tscn", 1, Vector2(2600, 2600))[0]
	selection.call("_on_unit_trained", 1, &"terrible_thing", recruit)
	if int(groups.call("count", 4)) != 3:
		_fail("A trained unit should be absorbed into the reinforce group, count is %s" % groups.call("count", 4))
		return
	# An enemy-owned unit must never be absorbed.
	var enemy := _spawn_units(scene, "res://scenes/units/terrible_thing.tscn", 1, Vector2(2700, 2700))[0]
	enemy.set("owner_player_id", 2)
	selection.call("_on_unit_trained", 2, &"terrible_thing", enemy)
	if int(groups.call("count", 4)) != 3:
		_fail("An enemy-owned unit must not join the player's reinforce group")
		return

	# The flag is exclusive: flagging another group clears the first.
	selection.call("toggle_reinforce_group", 5)
	if int(groups.call("reinforce_group")) != 5:
		_fail("Flagging group 5 should move the reinforce target")
		return
	# Toggling the active one off clears it entirely.
	if bool(selection.call("toggle_reinforce_group", 5)):
		_fail("Toggling the active reinforce group should turn it off")
		return
	if int(groups.call("reinforce_group")) != ControlGroupManager.NO_REINFORCE_GROUP:
		_fail("No group should be flagged after toggling off")
		return
	if groups.call("reinforce_rally_position") != null:
		_fail("With no reinforce group there should be no rally position")
		return

	print("[ControlGroupSmokeTest] assign/add/recall, death auto-cleanup and the reinforce group all behave")
	quit(0)

func _spawn_units(scene: Node, scene_path: String, count: int, origin: Vector2) -> Array[Node]:
	var packed: PackedScene = load(scene_path)
	var spawned: Array[Node] = []
	for i in count:
		var unit: Node = packed.instantiate()
		unit.set("owner_player_id", 1)
		scene.add_child(unit)
		unit.global_position = origin + Vector2(float(i) * 48.0, 0.0)
		spawned.append(unit)
	return spawned

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
