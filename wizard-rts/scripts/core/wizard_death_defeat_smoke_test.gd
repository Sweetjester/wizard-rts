extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _check_death_ends_run():
		return
	if not await _check_non_default_archetype_not_false_positive():
		return
	print("[WizardDeathDefeatSmokeTest] death_ends_run=pass archetype_regression=pass")
	quit(0)

func _boot_scene(character_id: String) -> Node:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "wizard-death-defeat-smoke", character_id, "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	return scene

func _teardown_scene(scene: Node) -> void:
	scene.queue_free()
	await process_frame
	await process_frame

# Wizard death alone (tower left standing) must end the run.
func _check_death_ends_run() -> bool:
	var scene: Node = await _boot_scene("bad_kon_willow")

	var controller: Node = scene.get_node("KonVerticalSliceController")
	if controller == null or not bool(controller.get("_initialized")):
		_fail("Vertical slice controller did not initialize")
		return false

	var wizard: Node = null
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1 and str(unit.get("unit_archetype")) == "life_wizard":
			wizard = unit
			break
	if wizard == null:
		_fail("Expected a life_wizard KON unit to spawn")
		return false

	var tower: Node = null
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == 1 and str(structure.get("archetype")) == "wizard_tower":
			tower = structure
			break
	if tower == null:
		_fail("Expected a wizard tower to exist before the death check")
		return false

	controller.call("_check_defeat")
	if bool(controller.get("_defeat")):
		_fail("Defeat triggered before the wizard died")
		return false

	var defeat_reason_box := [""]
	controller.connect("defeat_triggered", func(reason: String) -> void:
		defeat_reason_box[0] = reason
	)

	wizard.call("take_damage", 999999, null)
	await process_frame
	await process_frame

	if is_instance_valid(wizard):
		_fail("Wizard should die (queue_free) on lethal damage, not survive/respawn")
		return false

	controller.call("_check_defeat")
	if not bool(controller.get("_defeat")):
		_fail("Wizard death should trigger defeat independent of tower state")
		return false
	if not is_instance_valid(tower) or int(tower.get("health")) <= 0:
		_fail("Test setup invalid: tower should still be standing when defeat fired from wizard death")
		return false
	if str(defeat_reason_box[0]).is_empty():
		_fail("Expected defeat_triggered signal to fire with a reason")
		return false

	await _teardown_scene(scene)
	return true

# Regression guard: defeat must not false-positive for non-life_wizard archetypes
# (a prior bug only matched unit_archetype == "life_wizard" when checking for a living wizard).
func _check_non_default_archetype_not_false_positive() -> bool:
	var scene: Node = await _boot_scene("hellfire_baby")

	var controller: Node = scene.get_node("KonVerticalSliceController")
	if controller == null or not bool(controller.get("_initialized")):
		_fail("Vertical slice controller did not initialize (fire wizard run)")
		return false

	var wizard: Node = null
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1 and str(unit.get("unit_archetype")) == "fire_wizard":
			wizard = unit
			break
	if wizard == null:
		_fail("Expected a fire_wizard KON unit to spawn")
		return false

	controller.call("_check_defeat")
	if bool(controller.get("_defeat")):
		_fail("Defeat false-triggered with a live fire_wizard and standing tower")
		return false

	await _teardown_scene(scene)
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
