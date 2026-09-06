extends SceneTree

# The Steel Force is the enemy now, and you can put one in front of you.
#
# Two things are being pinned here and they fail in different ways.
#
# The FACTION SWITCH is one exported default, and the risk is that it only half
# lands: waves changed but the sandbox tools, the target dummy or the testing
# ground still hand out Deom. So the roster is read from the director rather
# than restated here, and the buttons are checked against that same roster --
# if the two ever disagree, the menu is offering enemies the game no longer
# fields, which is the exact bug that hides a broken faction switch.
#
# The SANDBOX SPAWN is checked by pressing the actual buttons, not by calling
# the spawn function underneath them. A spawn function that works while the
# button that calls it was never built is a passing test and a useless sandbox.
#
# And the buttons are checked for VISIBILITY, not for existence. The first
# version of this test asked whether the container had the right children, and
# it passed while the row was invisible on screen -- _update_selection_panel()
# was calling map_tool_container.hide() every frame for Kon. Existing, sized,
# laid out and never once drawn. "Is it in the tree" is not the question a
# player asks; is_visible_in_tree() is.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "steel-sandbox-smoke", "bad_kon_willow", "build_sandbox")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _gen_wait in 400:
		if map == null or bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 10:
		await process_frame

	var director: Node = scene.get_node_or_null("WaveDirector")
	var hud: Node = scene.get_node_or_null("RTSHud")
	if director == null or hud == null:
		_fail("Expected a WaveDirector and an RTSHud")
		return

	# --- the faction actually switched ---------------------------------------
	if str(director.get("enemy_faction")) != "steel_force":
		_fail("The default enemy faction is still %s" % director.get("enemy_faction"))
		return
	var roster: Array = director.call("enemy_roster")
	for archetype in [&"poorper", &"steel_knight", &"proper_blimp"]:
		if not roster.has(archetype):
			_fail("The Steel Force roster is missing %s" % archetype)
			return
	# Waves field them too, not just the sandbox buttons.
	var wave_archetypes := {}
	for wave in range(1, 8):
		director.set("wave_index", wave)
		for i in 12:
			wave_archetypes[director.call("_enemy_archetype_for_wave", i)] = true
	for archetype in wave_archetypes:
		if not roster.has(archetype):
			_fail("Wave composition still fields %s, which is not in the Steel Force roster" % archetype)
			return

	# --- one button per unit, built from that roster --------------------------
	var buttons := _buttons_in(hud.get("map_tool_container"))
	for archetype in roster:
		var display := str(UnitCatalog.get_definition(archetype).get("display_name", archetype))
		if not buttons.has(display):
			_fail("The sandbox has no spawn button for %s. Buttons: %s" % [display, buttons.keys()])
			return
		if not (buttons[display] as Button).is_visible_in_tree():
			_fail("The %s button exists but is not on screen -- something is hiding the map-tool row" % display)
			return
		if (buttons[display] as Button).get_global_rect().get_area() <= 0.0:
			_fail("The %s button is visible but has no area on screen" % display)
			return

	# --- pressing them puts a live, hostile unit on the map -------------------
	for archetype in roster:
		var before := _count_enemy(scene, archetype)
		buttons[str(UnitCatalog.get_definition(archetype).get("display_name", archetype))].emit_signal("pressed")
		for _i in 8:
			await process_frame
		if _count_enemy(scene, archetype) <= before:
			_fail("Pressing the %s button spawned nothing hostile" % archetype)
			return

	# --- the punchbag is a Steel unit, and still cannot die -------------------
	var wizard_cell: Vector2i = Vector2i(40, 40)
	var dummy: Node = director.call("spawn_target_dummy", wizard_cell, scene)
	if dummy == null or not is_instance_valid(dummy):
		_fail("Could not spawn a target dummy")
		return
	if not roster.has(StringName(dummy.get("unit_archetype"))):
		_fail("The target dummy is a %s, which is not in the current enemy faction" % dummy.get("unit_archetype"))
		return
	dummy.set("health", 1)
	for _i in 6:
		await process_frame
	if int(dummy.get("health")) != int(dummy.get("max_health")):
		_fail("The target dummy did not heal back to full: %s of %s" % [dummy.get("health"), dummy.get("max_health")])
		return

	# The dock has to fit what it is showing, or the row is on screen in name
	# only -- pushed out under the bottom edge, which is how this looked when it
	# was reported.
	var dock: Control = hud.get("command_dock")
	var row: Control = hud.get("map_tool_container")
	if row.get_global_rect().end.y > dock.get_global_rect().end.y + 1.0:
		_fail("The map-tool row runs past the bottom of the command dock: row ends at %s, dock at %s" % [
			row.get_global_rect().end.y, dock.get_global_rect().end.y])
		return

	print("[SteelForceSandboxSmokeTest] the Steel Force fields the waves, the sandbox shows a visible spawn button for every unit in it, and the punchbag is one of them")
	scene.queue_free()
	quit(0)

func _buttons_in(container: Node) -> Dictionary:
	var found := {}
	if container == null:
		return found
	for child in container.get_children():
		if child is Button:
			found[str((child as Button).text)] = child
	return found

func _count_enemy(scene: Node, archetype: StringName) -> int:
	var count := 0
	for unit in scene.get_tree().get_nodes_in_group("units"):
		# Not everything in the units group carries an archetype -- asking a node
		# that has none returns null, and StringName(null) is an error, not "".
		if not is_instance_valid(unit) or unit.get("unit_archetype") == null:
			continue
		if StringName(unit.get("unit_archetype")) == archetype and int(unit.get("owner_player_id")) == 2:
			count += 1
	return count

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
