extends SceneTree

# Oavens stationed inside a building make it work faster.
#
# The assertions that matter are the negative ones. "A buff applied" is easy to
# make pass and easy to make wrong; what makes this feature real is that it is
# OFF everywhere it should be:
#
#   * standing next to the building, not in it
#   * standing on the building's footprint but not on one of its floors
#   * walking through rather than stationed
#   * a unit that is not an Oaven
#
# The first two are the reason this reads ownership out of the navigation
# lattice rather than testing footprints: a footprint covers the walls and the
# tile the door opens onto, so a footprint test would pay a unit for loitering
# outside the front door.
#
# The timing assertions compare two real clocks rather than reading the
# multiplier back, because the multiplier being right and the clock not using it
# is exactly the bug worth catching -- and it is the shape of bug this session
# has already hit twice (a value computed correctly and never reaching the
# screen).

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := await _start()
	if scene == null:
		return
	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	var garrison: Node = scene.get_node_or_null("StructureGarrisonEffects")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	var wave_director: Node = scene.get_node_or_null("WaveDirector")
	if build_system == null or bridge == null or wave_director == null:
		_fail("Expected BuildSystem, BlockNavBridge and WaveDirector")
		return
	if garrison == null:
		_fail("main_map.tscn has no StructureGarrisonEffects node, so nothing counts stationed units")
		return
	if economy != null:
		economy.call("add_resource", 1, &"bio", 999999)

	# --- a lab, and the cells inside it --------------------------------------
	var origin := Vector2i(40, 40)
	if not bool(build_system.call("try_place_structure", 1, &"barracks", origin)):
		_fail("Could not raise a Splicing Laboratory")
		return
	for _i in 6:
		await process_frame
	var lab := _structure_at(build_system, &"barracks")
	if lab.is_empty():
		_fail("The Splicing Laboratory is not in BuildSystem.structures")
		return
	lab["complete"] = true
	_set_structure_complete(build_system, &"barracks")
	var instance: StringName = StringName(lab.get("block_instance", &""))
	if instance == &"":
		_fail("The lab has no block instance, so nothing can be stationed inside it")
		return

	var inside := _interior_cell(bridge, instance, origin)
	if inside.is_empty():
		_fail("The Splicing Laboratory has no interior floor cell to stand on")
		return

	# --- nobody home ---------------------------------------------------------
	if int(garrison.call("workers_in", instance)) != 0:
		_fail("An empty building reported a crew")
		return
	if not is_equal_approx(float(garrison.call("rate_multiplier_for", instance)), 1.0):
		_fail("An empty building is not running at normal speed")
		return

	# --- an Oaven OUTSIDE it does nothing ------------------------------------
	var map: Node = scene.get_node_or_null("MapGenerator")
	var loiterer: Node2D = wave_director.call("_spawn_enemy", &"oaven_spear",
		origin + Vector2i(-4, -4), scene, Vector2.ZERO)
	loiterer.set("owner_player_id", 1)
	loiterer.set("nav_level", 0)
	for _i in 20:
		await process_frame
	if int(garrison.call("workers_in", instance)) != 0:
		_fail("An Oaven standing outside the building was counted as stationed in it")
		return

	# --- walking THROUGH it is not being stationed in it ----------------------
	#
	# _spawn_enemy issues an attack-move order, so a freshly spawned unit is
	# still walking somewhere. Standing it on the lab floor while it is under
	# orders is exactly the "passing through" case, and it must not pay.
	loiterer.global_position = map.call("cell_to_world", inside["cell"])
	loiterer.set("nav_level", int(inside["level"]))
	for _i in 20:
		await process_frame
	if bool(loiterer.get("moving")) and int(garrison.call("workers_in", instance)) != 0:
		_fail("An Oaven walking through the lab was counted as stationed in it")
		return

	# --- and stationed in it does ---------------------------------------------
	loiterer.call("issue_stop_order")
	loiterer.global_position = map.call("cell_to_world", inside["cell"])
	loiterer.set("nav_level", int(inside["level"]))
	for _i in 20:
		await process_frame
	if int(garrison.call("workers_in", instance)) != 1:
		_fail("An Oaven standing on the lab's own floor was not counted, got %s" % garrison.call("workers_in", instance))
		return
	var crewed_rate := float(garrison.call("rate_multiplier_for", instance))
	if crewed_rate <= 1.0:
		_fail("One stationed Oaven produced no speed-up (rate %s)" % crewed_rate)
		return

	# --- a non-Oaven in the same room does not count --------------------------
	var horror: Node2D = wave_director.call("_spawn_enemy", &"horror", origin, scene, Vector2.ZERO)
	horror.set("owner_player_id", 1)
	horror.call("issue_stop_order")
	horror.global_position = map.call("cell_to_world", inside["cell"])
	horror.set("nav_level", int(inside["level"]))
	for _i in 20:
		await process_frame
	if int(garrison.call("workers_in", instance)) != 1:
		_fail("A Horror in the lab was counted as a worker; only units with garrison_work should be")
		return

	# --- production actually runs faster --------------------------------------
	#
	# Two real clocks, not the multiplier read back: the whole point is that the
	# number reaches the training tick.
	loiterer.call("issue_stop_order")
	var crewed_progress := await _training_progress_over(build_system, 40)
	if crewed_progress <= 0.0:
		_fail("The lab made no training progress at all")
		return
	loiterer.queue_free()
	for _i in 20:
		await process_frame
	if int(garrison.call("workers_in", instance)) != 0:
		_fail("The crew count survived the Oaven being freed")
		return
	var empty_progress := await _training_progress_over(build_system, 40)
	if not (crewed_progress > empty_progress * 1.05):
		_fail("A crewed lab trained at %s and an empty one at %s -- the crew is not reaching the training clock" % [
			crewed_progress, empty_progress])
		return

	print("[StructureGarrisonSmokeTest] an Oaven stationed on a building's own floor speeds its work up, and standing outside it, walking through it, or being the wrong unit does not")
	scene.queue_free()
	quit(0)

# --- helpers ----------------------------------------------------------------

func _start() -> Node:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "garrison-smoke", "bad_kon_willow", "build_sandbox")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _gen_wait in 400:
		if map == null or bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 10:
		await process_frame
	return scene

func _structure_at(build_system: Node, archetype: StringName) -> Dictionary:
	for structure in build_system.get("structures"):
		if StringName(structure.get("archetype", &"")) == archetype:
			return structure
	return {}

func _set_structure_complete(build_system: Node, archetype: StringName) -> void:
	var structures: Array = build_system.get("structures")
	for i in structures.size():
		if StringName(structures[i].get("archetype", &"")) == archetype:
			structures[i]["complete"] = true
			structures[i]["build_progress"] = float(structures[i].get("build_time", 0.0))
			var node = structures[i].get("node", null)
			if node != null and is_instance_valid(node):
				node.set("complete", true)

# A floor cell this structure owns, found by asking the lattice rather than by
# guessing at the authored layout.
func _interior_cell(bridge: Node, instance: StringName, origin: Vector2i) -> Dictionary:
	for radius in range(0, 14):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var cell := origin + Vector2i(dx, dz)
				for level in range(0, 8):
					if StringName(bridge.call("structure_instance_at", cell, level)) == instance:
						return {"cell": cell, "level": level}
	return {}

# How much training progress the lab makes over a fixed number of frames.
#
# Frames rather than seconds: process_frame yields nothing to measure time with,
# and both samples running the same frame count is what makes them comparable.
# The absolute figures are meaningless; only their ratio is asserted.
func _training_progress_over(build_system: Node, frames: int) -> float:
	var structures: Array = build_system.get("structures")
	var index := -1
	for i in structures.size():
		if StringName(structures[i].get("archetype", &"")) == &"barracks":
			index = i
	if index < 0:
		return 0.0
	# A job long enough that neither sample can finish and reset the clock
	# partway through the measurement.
	structures[index]["production_queue"] = []
	structures[index]["training_archetype"] = &"oaven_spear"
	structures[index]["training_progress"] = 0.0
	structures[index]["training_time"] = 9999.0
	for _i in frames:
		await process_frame
	return float((build_system.get("structures") as Array)[index].get("training_progress", 0.0))

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
