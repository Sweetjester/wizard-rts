extends SceneTree

# The citadel as it exists on a real generated map, rather than in its demo.
#
# Every bug this guards against was invisible in the standalone demo and only
# appeared once the structure was placed on generated terrain, because the demo
# spawns its test unit ON the structure and puts nothing else on the map:
#
#   * The citadel rests on a two-block foundation slab. Registering "every
#     column with a block at local level 0" as a 2D blocker therefore sealed the
#     whole fortress -- 2,620 columns of genuine floor, the gate tunnel
#     included -- and made a quarter of the march an impassable brick.
#   * Level changes happen only on terrain ramps or authored links, so a
#     structure standing on a plinth is an ISLAND. Every region of the citadel
#     was unreachable from outside by walking. The fix consumes the exterior
#     ROAD sockets the citadel already authored and nothing had ever read.
#   * BlockNavBridge.auto_place carried two test structures, so every map of
#     every type had a gatehouse and a ruined watchfort dropped into it,
#     unrelated to any plot the generator had laid out.
#
# The reachability assertion is the one that matters most. A fortress you cannot
# walk into is not a landmark, it is scenery -- and nothing else in the suite
# would notice, because the lattice, the garrison and the capture reward are all
# perfectly happy inside a building with no door.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := await _boot("citadel_march")
	var terrain: Node = scene.get_node_or_null("MapGenerator")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	var garrison: Node = scene.get_node_or_null("CitadelGarrison")
	if terrain == null or bridge == null or garrison == null:
		_fail("Expected MapGenerator, BlockNavBridge and CitadelGarrison")
		return

	if not _check_only_requested_structures(bridge):
		return
	var origin := _citadel_origin(bridge)
	if origin.x < 0:
		_fail("The citadel was not placed on the march at all")
		return
	if not _check_in_bounds(terrain, bridge, origin):
		return
	if not _check_interior_is_enterable(terrain, bridge, origin):
		return
	if not _check_reachable_from_outside(terrain, bridge, garrison, origin):
		return
	scene.queue_free()
	await process_frame

	if not await _check_standard_map_is_clean():
		return
	print("[CitadelPlacementSmokeTest] the citadel is placed in its plot, is not a solid brick, and can be walked into from outside")
	quit(0)

# Structures reach a map because a plot asked for one -- not because a debug
# affordance dropped them wherever the ground happened to be flat.
func _check_only_requested_structures(bridge: Node) -> bool:
	var requested := {}
	for plot in (bridge.get("terrain") as Node).get("plots"):
		var id := str(plot.get("block_structure", ""))
		if id != "":
			requested[id] = true
	for placement in bridge.get("world").placements():
		var id := str(placement.get("structure", &""))
		if not requested.has(id):
			_fail("%s was placed on the map but no plot asked for it" % id)
			return false
	return true

func _citadel_origin(bridge: Node) -> Vector2i:
	for placement in bridge.get("world").placements():
		if placement.get("structure", &"") == &"kons_arcane_citadel_01":
			return placement.get("origin", Vector2i(-1, -1))
	return Vector2i(-1, -1)

func _check_in_bounds(terrain: Node, bridge: Node, origin: Vector2i) -> bool:
	var definition = bridge.get("library").get_definition(&"kons_arcane_citadel_01")
	var size := Vector2i(int(definition.dimensions.x), int(definition.dimensions.z))
	var width := int(terrain.get("MAP_W"))
	var height := int(terrain.get("MAP_H"))
	if origin.x < 0 or origin.y < 0 or origin.x + size.x > width or origin.y + size.y > height:
		_fail("The citadel at %s (%s) hangs off a %sx%s map" % [origin, size, width, height])
		return false
	return true

# The plinth bug: if the whole footprint is unwalkable there is no way in, and
# the fortress is a hole in the map rather than a place.
func _check_interior_is_enterable(terrain: Node, bridge: Node, origin: Vector2i) -> bool:
	var definition = bridge.get("library").get_definition(&"kons_arcane_citadel_01")
	var size := Vector2i(int(definition.dimensions.x), int(definition.dimensions.z))
	var blocked := 0
	var total := 0
	for x in size.x:
		for y in size.y:
			total += 1
			if not bool(terrain.call("is_walkable_cell", origin + Vector2i(x, y))):
				blocked += 1
	var ratio := float(blocked) / float(maxi(total, 1))
	if ratio > 0.85:
		_fail("%.0f%% of the citadel footprint is impassable in 2D; the foundation slab is being registered as wall" % (ratio * 100.0))
		return false
	return true

# The island bug. Walked from real terrain OUTSIDE the footprint, through the
# authored gate, to each of the places the design says a player goes.
func _check_reachable_from_outside(terrain: Node, bridge: Node, garrison: Node, origin: Vector2i) -> bool:
	var world = bridge.get("world")
	var definition = bridge.get("library").get_definition(&"kons_arcane_citadel_01")
	var start := _ground_cell_outside(terrain, bridge, origin, definition)
	for key in definition.gate_cells: world.gate_states[str(key)] = true
	if start.x < 0:
		_fail("Found no standable terrain outside the citadel to walk in from")
		return false
	var start_levels: Array = bridge.call("levels_at", start)

	var first_cell_of := {}
	for cell in definition.nav_cells:
		var region: StringName = definition.nav_cells[cell].get("region_id", &"")
		if region != &"" and not first_cell_of.has(region):
			first_cell_of[region] = cell
	# The gate is the way in; the courtyard, the keep and the wall-walks are what
	# taking it is FOR (master doc section 40).
	for region in [&"main_gate_tunnel_nav", &"south_courtyard_nav",
			&"keep_ground_floor_nav", &"wall_walk_outer_ring_nav"]:
		if not first_cell_of.has(region):
			_fail("The citadel no longer declares %s" % region)
			return false
		var local: Vector3i = first_cell_of[region]
		var path: Array = world.find_path(
			start, int(start_levels[0]), origin + Vector2i(local.x, local.z), local.y, &"infantry")
		if path.is_empty():
			_fail("%s cannot be reached on foot from outside the citadel -- it is sealed" % region)
			return false

	# And the reward is reachable, since capturing grants the plinth.
	var plinth: Vector2i = garrison.call("keep_plinth_cell")
	var plinth_levels: Array = bridge.call("levels_at", plinth)
	if plinth_levels.is_empty():
		_fail("The keep plinth %s has no standing level" % plinth)
		return false
	if (world.find_path(start, int(start_levels[0]), plinth, int(plinth_levels[0]), &"infantry") as Array).is_empty():
		_fail("The keep plinth cannot be reached on foot; the capture reward is unreachable")
		return false
	return true

func _ground_cell_outside(terrain: Node, bridge: Node, origin: Vector2i, definition) -> Vector2i:
	var size := Vector2i(int(definition.dimensions.x), int(definition.dimensions.z))
	for distance in range(2, 12):
		for along in range(0, size.y, 4):
			for candidate in [origin + Vector2i(-distance, along), origin + Vector2i(size.x + distance, along)]:
				if not bool(terrain.call("is_in_bounds", candidate)):
					continue
				if not bool(terrain.call("is_walkable_cell", candidate)):
					continue
				if not (bridge.call("levels_at", candidate) as Array).is_empty():
					return candidate
	return Vector2i(-1, -1)

# The frontier carries the citadel and nothing else. A structure appears because
# a plot asked for it -- never because a debug affordance was left switched on.
func _check_standard_map_is_clean() -> bool:
	var scene := await _boot("seeded_grid_frontier")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	if not _check_only_requested_structures(bridge):
		return false
	var origin := _citadel_origin(bridge)
	if origin.x < 0:
		_fail("The frontier did not place the citadel; it should carry one every game")
		return false
	var terrain: Node = scene.get_node_or_null("MapGenerator")
	if not _check_in_bounds(terrain, bridge, origin):
		return false
	if not _check_interior_is_enterable(terrain, bridge, origin):
		return false
	# Base plots must never start inside the fortress the map exists to make the
	# player fight for. At 144x144 this happened on two seeds in six, which is
	# why the frontier is 160.
	var definition: BlockStructureDefinition = bridge.get("library").get_definition(&"kons_arcane_citadel_01")
	var citadel := Rect2i(origin, Vector2i(definition.dimensions.x, definition.dimensions.z))
	for plot in terrain.get("base_plots"):
		if citadel.intersects(plot.get("rect", Rect2i())):
			_fail("Base plot %s starts inside the citadel" % plot.get("id"))
			return false
	scene.queue_free()
	await process_frame
	return true

func _boot(map_type: String) -> Node:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "citadel-placement-%s" % map_type, "bad_kon_willow", map_type)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	# Map generation is spread across frames now, so the scene is not playable
	# the instant it is added. Waits for the generator to say it is finished
	# rather than for a fixed frame count -- a count that happened to be long
	# enough on a 96x96 map is not a guarantee, it is a coincidence.
	for _gen_wait in 400:
		var _gen := scene.get_node_or_null("MapGenerator")
		if _gen == null or bool(_gen.get("generation_complete")):
			break
		await process_frame
	# The march is 192x192 and the bridge places after generation settles.
	for _i in 80:
		await process_frame
	return scene

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
