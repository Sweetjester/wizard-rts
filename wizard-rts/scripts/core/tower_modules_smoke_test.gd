extends SceneTree

# The tower-module economy, end to end (master doc section 39).
#
# The Observation Tower is a megastructure: production and research are built
# INSIDE it as modules, against a fixed number of slots. Economy and walls stay
# on the ground, because where they sit is part of the decision and moving them
# inside would delete the base-placement choice section 12 depends on.
#
# What matters here is that modules are a real constraint rather than a rename.
# The assertions that carry weight are the refusals: a full tower must refuse a
# module, and it must refuse without eating the Bio.
#
# StructureComponents itself is covered separately and headlessly in
# structure_components_smoke_test.gd; this is about the wiring.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "tower-modules-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 4:
		await process_frame

	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	if build_system == null or economy == null:
		_fail("Expected BuildSystem and EconomyManager in main_map.tscn")
		return
	economy.call("add_resource", 1, &"bio", 20000)

	if not _check_slots_are_real(build_system, economy):
		return
	if not _check_production_comes_from_the_module(build_system):
		return
	if not _check_research_is_module_gated(build_system):
		return
	if not _check_modules_are_not_placeable(build_system, scene):
		return

	print("[TowerModulesSmokeTest] tower slots constrain the build, and production and research come from modules")
	scene.queue_free()
	quit(0)

# Slots are the scarce thing; Bio is only the price.
func _check_slots_are_real(build_system: Node, economy: Node) -> bool:
	var total: int = int(build_system.call("module_slots_total", 1))
	if total <= 0:
		_fail("The Observation Tower should host module slots, got %s" % total)
		return false
	if int(build_system.call("module_slots_free", 1)) != total:
		_fail("A fresh tower should have every slot free")
		return false

	# Fill it, using the same entry point the HUD build buttons use -- a module
	# never enters placement mode, it installs directly.
	for i in total:
		build_system.call("start_placement", &"barracks")
	if int(build_system.call("module_slots_free", 1)) != 0:
		_fail("Installing %s modules should fill a %s-slot tower" % [total, total])
		return false

	# The refusal is the assertion that matters. A full tower must say no, and
	# must not silently charge for it.
	var bio_before: int = _bio(economy)
	if bool(build_system.call("build_module", 1, &"barracks")):
		_fail("A full tower must refuse another module")
		return false
	if _bio(economy) != bio_before:
		_fail("A refused module must not spend Bio (%s -> %s)" % [bio_before, _bio(economy)])
		return false
	return true

# A tower with a production module trains what that module trains. Before this,
# production came from a Barracks standing on the ground.
func _check_production_comes_from_the_module(build_system: Node) -> bool:
	var tower := _tower(build_system)
	if tower.is_empty():
		_fail("Found no completed tower to host modules")
		return false
	var trains: Array = build_system.call("production_list_for", tower)
	if not trains.has(&"oaven_spear"):
		_fail("A tower with a production module should train the module's roster, got %s" % [trains])
		return false
	return true

# Research asks "does this player have an Observer Vault". A module has to
# answer yes -- that single seam is what let modules arrive without rewriting
# the research and production systems.
func _check_research_is_module_gated(build_system: Node) -> bool:
	# The tower is full of production modules at this point, so research must be
	# refused: the player committed those slots elsewhere. That IS the mechanic.
	if bool(build_system.call("research_upgrade", 1, &"observer_sight")):
		_fail("Research should be refused while no research module is installed")
		return false

	# Free a slot the way a siege would, then install research into it.
	var tower := _tower(build_system)
	var components = tower.get("components", null)
	if components == null:
		_fail("The tower should carry component state")
		return false
	var installed: Array = components.components()
	for component in installed:
		if component["module_role"] == &"production":
			components.destroy_component(component["id"])
			components.remove_module(component["id"])
			break
	if int(build_system.call("module_slots_free", 1)) != 1:
		_fail("Losing a module should free exactly one slot")
		return false
	if not bool(build_system.call("build_module", 1, &"terrible_vault")):
		_fail("A freed slot should accept a research module")
		return false
	if not bool(build_system.call("research_upgrade", 1, &"observer_sight")):
		_fail("Research should be available once a research module is installed")
		return false
	return true

# Modules have no location, so every path onto the map has to refuse them --
# not just the HUD one.
func _check_modules_are_not_placeable(build_system: Node, scene: Node) -> bool:
	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	var before: int = (build_system.call("get_structures") as Array).size()
	build_system.call("start_placement", &"barracks")
	if build_system.get("pending_archetype") == &"barracks":
		_fail("A module must never enter placement mode")
		return false
	# try_place_structure is reachable from the command path, so it is guarded too.
	var cell: Vector2i = map_generator.call("nearest_walkable_cell", Vector2i(30, 30), 24)
	build_system.call("try_place_structure", 1, &"terrible_vault", cell)
	for structure in build_system.call("get_structures"):
		if structure.get("archetype", &"") == &"terrible_vault":
			_fail("A research module was placed on the ground at %s" % [structure.get("cell")])
			return false
	if (build_system.call("get_structures") as Array).size() != before:
		_fail("Placing a module must not add a ground structure")
		return false
	return true

func _bio(economy: Node) -> int:
	return int((economy.call("get_resources", 1) as Dictionary).get(&"bio", 0))

func _tower(build_system: Node) -> Dictionary:
	for structure in build_system.call("get_structures"):
		if structure.get("archetype", &"") == &"wizard_tower":
			return structure
	return {}

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
