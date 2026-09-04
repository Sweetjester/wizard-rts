extends SceneTree

# The citadel march: a 192x192 map type carrying Kon's Arcane Citadel as a
# guaranteed content plot (master doc section 40).
#
# The assertion that carries the most weight is the LAST one: that the standard
# frontier map is still 96x96. Map size stopped being a project-wide constant to
# make this map type possible, and 127 references across the project read it --
# so "did the other maps change size" is the question that matters, and it is
# cheaper to ask here than to discover from a broken fog texture.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _check_march():
		return
	if not await _check_default_map_unchanged():
		return
	print("[CitadelMarchSmokeTest] the march is 192x192 with the citadel placed in its own plot, and standard maps are untouched")
	quit(0)

func _check_march() -> bool:
	var scene := await _boot("citadel_march")
	var terrain: Node = scene.get_node_or_null("MapGenerator")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	if terrain == null or bridge == null:
		_fail("Expected MapGenerator and BlockNavBridge")
		return false

	if int(terrain.get("MAP_W")) != 192 or int(terrain.get("MAP_H")) != 192:
		_fail("The march should be 192x192, got %sx%s" % [terrain.get("MAP_W"), terrain.get("MAP_H")])
		return false

	# The citadel is a real content plot, not a structure dropped on the map.
	var citadel_plot := {}
	for plot in terrain.get("plots"):
		if str(plot.get("block_structure", "")) == "kons_arcane_citadel_01":
			citadel_plot = plot
			break
	if citadel_plot.is_empty():
		_fail("No plot on the march requested the citadel")
		return false
	var rect: Rect2i = citadel_plot.get("rect", Rect2i())
	if rect.size.x < 96 or rect.size.y < 96:
		_fail("The citadel plot should reserve 96x96, got %s" % [rect.size])
		return false

	# And it was actually placed there, not merely reserved.
	var world = bridge.get("world")
	if world == null:
		_fail("The bridge built no lattice on the march")
		return false
	var placed_at := Vector2i(-1, -1)
	for placement in world.placements():
		if placement.get("structure", &"") == &"kons_arcane_citadel_01":
			placed_at = placement.get("origin", Vector2i(-1, -1))
	if placed_at != rect.position:
		_fail("The citadel was placed at %s but its plot is at %s" % [placed_at, rect.position])
		return false

	# A quarter of the map, which is the whole point: a fortress on a level
	# rather than a fortress that IS the level.
	var coverage := float(rect.size.x * rect.size.y) / float(192 * 192)
	if coverage > 0.4:
		_fail("The citadel covers %.0f%% of the march; it should read as a landmark" % (coverage * 100.0))
		return false

	# Base plots must not sit inside it -- the player starts outside and takes it.
	for plot in terrain.get("base_plots"):
		var base_rect: Rect2i = plot.get("rect", Rect2i())
		if rect.encloses(base_rect):
			_fail("Base plot %s starts inside the citadel" % plot.get("id"))
			return false
	scene.queue_free()
	await process_frame
	return true

# Map size became a variable for the march. Every other map must be exactly as
# it was.
func _check_default_map_unchanged() -> bool:
	var scene := await _boot("seeded_grid_frontier")
	var terrain: Node = scene.get_node_or_null("MapGenerator")
	if int(terrain.get("MAP_W")) != 96 or int(terrain.get("MAP_H")) != 96:
		_fail("The standard frontier map should still be 96x96, got %sx%s"
			% [terrain.get("MAP_W"), terrain.get("MAP_H")])
		return false
	for plot in terrain.get("plots"):
		if str(plot.get("block_structure", "")) != "":
			_fail("A standard map asked for a block structure; the citadel is march-only")
			return false
	scene.queue_free()
	await process_frame
	return true

func _boot(map_type: String) -> Node:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "march-smoke-%s" % map_type, "bad_kon_willow", map_type)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	# The march is large and the bridge places after generation settles, so this
	# waits generously rather than assuming a frame count that suits 96x96.
	for _i in 60:
		await process_frame
	return scene

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
