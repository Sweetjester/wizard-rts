extends SceneTree

# Regression guard for the army-management hotkeys added 2026-08-31 in
# scripts/input/selection_controller.gd:
#   * select_hero()          -- F1, the one-hero equivalent of WC3's hero key
#   * select_all_army()      -- F2, deliberately EXCLUDING the wizard
#   * cycle_idle_production()-- F3, idle Barracks (this game has no workers)
#   * cycle_idle_unit()      -- F4, idle swarm stragglers
#   * cycle_subgroup()       -- Tab, WC3 subgroup filtering, made non-lossy
#
# Also asserts the new KeybindManager actions exist and are rebindable, since
# the pause menu builds its key-bind rows straight off get_actions().

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check_keybind_actions():
		return

	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "army-hotkeys-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var selection: Node = scene.get_node_or_null("SelectionController")
	var build_system: Node = scene.get_node_or_null("BuildSystem")
	if selection == null or build_system == null:
		_fail("Expected SelectionController and BuildSystem in main_map.tscn")
		return

	# --- hero key ----------------------------------------------------------
	var hero: Node = selection.call("select_hero", false)
	if hero == null:
		_fail("select_hero() found no wizard -- the run should always start with one")
		return
	var hero_archetype := str(hero.get("unit_archetype"))
	if hero_archetype != "life_wizard":
		_fail("Expected the Bad Kon Willow run to select a life_wizard, got %s" % hero_archetype)
		return
	if (selection.get("selected_units") as Array).size() != 1:
		_fail("select_hero() should leave exactly the wizard selected")
		return

	# --- select all army, wizard excluded ---------------------------------
	var swarm := _spawn(scene, "res://scenes/units/terrible_thing.tscn", 3, Vector2(2000, 2000))
	var oavens := _spawn(scene, "res://scenes/units/oaven_spear.tscn", 2, Vector2(2400, 2000))
	await process_frame
	var army_size := int(selection.call("select_all_army"))
	if army_size < 5:
		_fail("select_all_army() should have picked up at least the 5 spawned units, got %s" % army_size)
		return
	for node in selection.get("selected_units") as Array:
		if str(node.get("unit_archetype")) == "life_wizard":
			_fail("select_all_army() must never sweep the wizard into the army selection")
			return

	# --- subgroup filtering (Tab) -----------------------------------------
	# Filter down to just the two archetypes we control here, so the assertion
	# does not depend on whatever else the map happens to have spawned.
	var mixed: Array[Node] = []
	for unit in swarm:
		mixed.append(unit)
	for unit in oavens:
		mixed.append(unit)
	selection.call("_apply_selection", mixed)
	var types: Array = selection.call("subgroup_types")
	selection.call("cycle_subgroup", false)
	types = selection.call("subgroup_types")
	if types.size() != 2:
		_fail("Expected 2 subgroup types in a mixed selection, got %s (%s)" % [types.size(), types])
		return
	var first_pass: Array = (selection.get("selected_units") as Array).duplicate()
	if first_pass.size() != 3 and first_pass.size() != 2:
		_fail("First Tab should narrow to one archetype (3 or 2 units), got %s" % first_pass.size())
		return
	var first_type := str(first_pass[0].get("unit_archetype"))
	for node in first_pass:
		if str(node.get("unit_archetype")) != first_type:
			_fail("A filtered subgroup must contain exactly one archetype")
			return
	selection.call("cycle_subgroup", false)
	var second_pass: Array = (selection.get("selected_units") as Array).duplicate()
	if second_pass.is_empty() or str(second_pass[0].get("unit_archetype")) == first_type:
		_fail("Second Tab should move to the other archetype")
		return
	# Cycling all the way round restores the full selection -- the non-lossy part.
	selection.call("cycle_subgroup", false)
	if (selection.get("selected_units") as Array).size() != 5:
		_fail("Cycling past the last subgroup should restore the full 5-unit selection, got %s" % (selection.get("selected_units") as Array).size())
		return
	# Shift+Tab walks backwards into the last archetype rather than the first.
	selection.call("cycle_subgroup", true)
	var reverse_pass: Array = (selection.get("selected_units") as Array).duplicate()
	if reverse_pass.is_empty() or str(reverse_pass[0].get("unit_archetype")) == first_type:
		_fail("Shift+Tab from the full selection should land on the LAST archetype, not the first")
		return

	# --- idle unit cycling -------------------------------------------------
	var idle_before: Array = selection.call("idle_army_units")
	if idle_before.is_empty():
		_fail("Freshly spawned units with no orders should count as idle")
		return
	var picked: Node = selection.call("cycle_idle_unit")
	if picked == null or (selection.get("selected_units") as Array).size() != 1:
		_fail("cycle_idle_unit() should select exactly one idle unit")
		return
	if str(picked.get("unit_archetype")) == "life_wizard":
		_fail("The wizard has its own key and must not appear in idle-unit cycling")
		return
	# A unit under orders is no longer idle.
	var busy: Node = swarm[0]
	busy.call("issue_hold_position_order")
	var idle_after: Array = selection.call("idle_army_units")
	for node in idle_after:
		if node == busy:
			_fail("A unit on hold-position must not be reported as idle")
			return

	# --- idle production cycling ------------------------------------------
	# Barracks with an empty queue are idle; one with something training is not.
	# oaven_spear is trained here because it is on bad_kon_willow's class roster
	# (UnitCatalog.CLASS_UNIT_ROSTERS) -- terrible_thing is not.
	var origin: Vector2i = _find_free_cell(scene)
	build_system.call("add_free_structure", 1, &"barracks", origin, "")
	await process_frame
	var idle_barracks: Array = build_system.call("idle_production_nodes", 1)
	if idle_barracks.is_empty():
		_fail("A completed Barracks with an empty queue should count as idle production")
		return
	var barracks_node: Node = selection.call("cycle_idle_production")
	if barracks_node == null:
		_fail("cycle_idle_production() should have selected the idle Barracks")
		return
	if str(barracks_node.get("archetype")) != "barracks":
		_fail("cycle_idle_production() selected a %s, expected a barracks" % barracks_node.get("archetype"))
		return
	var economy: Node = scene.get_node_or_null("EconomyManager")
	if economy != null:
		economy.call("add_resource", 1, &"bio", 5000)
	if not bool(build_system.call("produce_unit_from_structure", 1, &"oaven_spear", barracks_node)):
		_fail("Expected to be able to queue a unit at the test Barracks")
		return
	var idle_with_queue: Array = build_system.call("idle_production_nodes", 1)
	for node in idle_with_queue:
		if node == barracks_node:
			_fail("A Barracks with a queued unit must not be reported as idle production")
			return

	print("[ArmySelectionHotkeysSmokeTest] hero/army keys, subgroup filtering and both idle cyclers behave")
	quit(0)

# Autoloads are fetched off `root` rather than by their global identifier: a
# script run with `-s` compiles before the autoload singletons are registered,
# so `KeybindManager.x` is a compile error here even though it resolves fine
# inside normal scene scripts. Same pattern the other smoke tests use for
# GameSession.
func _check_keybind_actions() -> bool:
	var keybinds: Node = root.get_node_or_null("KeybindManager")
	if keybinds == null:
		_fail("Expected the KeybindManager autoload")
		return false
	var actions: Array = keybinds.call("get_actions")
	for required in [
		"select_hero",
		"select_army",
		"cycle_idle_production",
		"cycle_idle_unit",
		"cycle_subgroup",
	]:
		if not actions.has(required):
			_fail("KeybindManager.get_actions() is missing %s -- the pause menu builds its rebind rows from this list" % required)
			return false
		if int(keybinds.call("get_keycode", required)) == 0:
			_fail("%s has no default keycode" % required)
			return false
		var display := str(keybinds.call("get_action_display_name", required))
		if display.is_empty() or display == required:
			_fail("%s has no human-readable display name for the key-bind menu" % required)
			return false
	return true

func _spawn(scene: Node, scene_path: String, count: int, origin: Vector2) -> Array[Node]:
	var packed: PackedScene = load(scene_path)
	var spawned: Array[Node] = []
	for i in count:
		var unit: Node = packed.instantiate()
		unit.set("owner_player_id", 1)
		scene.add_child(unit)
		unit.global_position = origin + Vector2(float(i) * 48.0, 0.0)
		spawned.append(unit)
	return spawned

func _find_free_cell(scene: Node) -> Vector2i:
	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	if map_generator == null or not map_generator.has_method("nearest_walkable_cell"):
		return Vector2i(48, 48)
	return map_generator.call("nearest_walkable_cell", Vector2i(48, 48), 24)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
