extends SceneTree

# Kon's Arena 2.0: Kon's roster against the Steel Force, colliding in the middle.
#
# This map is a MEASURING INSTRUMENT, so most of what is asserted here is about
# fairness and about the two armies actually meeting -- not about the map merely
# existing.
#
#   SYMMETRY is checked cell by cell across the whole arena. If one side has
#   better ground, every result the arena produces is about the terrain instead
#   of about the units, and that is the kind of bias nobody notices by eye. The
#   generator mirrors by construction (it tests distance from the centre line),
#   so this asserts the property rather than the implementation -- a later
#   rewrite that places two halves separately would fail here, which is exactly
#   when you would want it to.
#
#   CONVERGENCE is checked by watching where the units actually are, not by
#   reading back the order that was issued. Both armies being sent to the middle
#   is the design; both armies ARRIVING there is the thing that can break, and it
#   breaks quietly -- a bad leash, an unreachable target cell, a flow field that
#   never solves.
#
#   THE TWO SIDES must be different factions. The first arena runs the same mix
#   against itself, which can never tell you which roster wins, and reproducing
#   that here by accident would leave a test that passes and a map that is
#   pointless.
#
#   THE ROSTERS must be the real ones, and this is where the first version was
#   wrong in a way no assertion caught. Kon's side was a hand-written list that
#   contained terrible_thing, horror and apex -- units belonging to the OTHER TWO
#   wizard classes. It read as "Kon vs Steel Force" and was nothing of the kind.
#   So the rosters are now derived from the class and faction definitions, and
#   the test asserts every fielded unit really belongs to its side rather than
#   trusting the list.
#
#   EVERY ROSTER UNIT MUST HAVE A SCENE. The Mangler was on Kon's roster and
#   absent from the arena's scene factory, so every Mangler slot in every wave
#   spawned nothing and a seventh of Kon's army was quietly missing. Checked
#   directly, because a null scene produces no error and no unit.
#
#   UNITS MUST KEEP THEIR ART. prepare_lightweight_arena_unit() deletes the
#   ArtSprite and disables _process; the original arena wants that and this one
#   must not have it, or the map shows coloured capsules sliding into each other
#   instead of the roster it exists to show.

# The march is a real march: the camps are ~100 cells apart and Kon's infantry
# moves about a cell a second, so the armies need roughly a minute and a half of
# GAME time to meet. The headless loop runs at a real 60fps, so waiting for that
# in frames would put ninety seconds of wall clock into the suite.
#
# Engine.time_scale multiplies the delta every system already reads, so the
# simulation advances at the same rate per second of game time and simply gets
# more of it per frame. Nothing here depends on frames -- movement, combat and
# the spawn queue are all delta-driven -- which is what makes this safe. It is
# restored afterwards so it cannot leak into anything else in the run.
const CONVERGENCE_TIME_SCALE := 8.0
const CONVERGENCE_FRAMES := 1400

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "kon-arena-2-smoke", "bad_kon_willow", "kon_arena_2")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _gen_wait in 600:
		if map == null or bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 10:
		await process_frame

	var director: Node = scene.get_node_or_null("WaveDirector")
	var world: Node = scene.get_node_or_null("RTSWorld")
	if map == null or director == null or world == null:
		_fail("Expected a MapGenerator, WaveDirector and RTSWorld")
		return

	# --- it is an arena, and the harness knows it -----------------------------
	if not bool(director.call("is_kon_arena_2")):
		_fail("The WaveDirector does not recognise this map as Arena 2.0")
		return
	# This is what hands the map the observer mode, the spawn buttons, the
	# spawn-rate budgeting and the telemetry. Without it the map is a map with
	# no way to drive it.
	if not bool(director.call("is_ai_testing_ground")):
		_fail("Arena 2.0 is not a testing ground, so none of the AI test tooling appears")
		return

	# --- the layout is mirrored, cell for cell --------------------------------
	if not _check_symmetry(map):
		return

	# --- both armies are sent to the same middle ------------------------------
	var centre: Vector2i = map.call("kon_arena_2_centre")
	var west_target: Vector2i = director.call("_ai_test_west_target_anchor")
	var east_target: Vector2i = director.call("_ai_test_east_target_anchor")
	if west_target != east_target:
		_fail("The two armies are sent to different places (%s and %s); they will not meet in the middle" % [
			west_target, east_target])
		return
	if west_target != centre:
		_fail("Both armies are sent to %s, which is not the arena's centre %s" % [west_target, centre])
		return
	# ...and they start apart, or "meeting in the middle" means nothing.
	var west_spawn: Vector2i = director.call("_ai_test_west_spawn_anchor")
	var east_spawn: Vector2i = director.call("_ai_test_east_spawn_anchor")
	if absi(west_spawn.x - east_spawn.x) < 40:
		_fail("The two camps are only %s cells apart; there is no march to observe" % absi(west_spawn.x - east_spawn.x))
		return

	# --- one wave, two different factions -------------------------------------
	var result: Dictionary = director.call("spawn_ai_test_wave")
	if not bool(result.get("accepted", false)):
		_fail("The first wave was refused: %s" % result)
		return
	for _i in 180:
		await process_frame

	if not _check_rosters_are_real(director):
		return

	var west := _archetypes_for_owner(scene, 2)
	var east := _archetypes_for_owner(scene, 3)
	if west.is_empty() or east.is_empty():
		_fail("A wave spawned but one side is empty: west=%s east=%s" % [west, east])
		return
	if not _check_units_are_whole(scene):
		return
	for archetype in east:
		if UnitCatalog.faction_of(archetype) != &"steel_force":
			_fail("The east army fielded %s, which is not Steel Force" % archetype)
			return
	for archetype in west:
		if UnitCatalog.faction_of(archetype) == &"steel_force":
			_fail("The west army fielded %s, which belongs to the Steel Force" % archetype)
			return
	# The whole reason this map exists rather than the first arena.
	if west == east:
		_fail("Both sides fielded the same units; this is a mirror match, not Kon against the Steel Force")
		return

	# --- and they actually walk to the middle and fight -----------------------
	var west_start := _mean_distance_to(scene, 2, map, centre)
	var east_start := _mean_distance_to(scene, 3, map, centre)
	var contact := false
	Engine.time_scale = CONVERGENCE_TIME_SCALE
	for _i in CONVERGENCE_FRAMES:
		await process_frame
		if _sides_in_contact(scene, map, centre):
			contact = true
			break
	Engine.time_scale = 1.0
	var west_end := _mean_distance_to(scene, 2, map, centre)
	var east_end := _mean_distance_to(scene, 3, map, centre)
	if west_end >= west_start:
		_fail("Kon's army did not close on the middle: %.1f cells away, now %.1f" % [west_start, west_end])
		return
	if east_end >= east_start:
		_fail("The Steel Force did not close on the middle: %.1f cells away, now %.1f" % [east_start, east_end])
		return
	if not contact:
		_fail("After %d frames the two armies are %.1f and %.1f cells from the centre and have not met" % [
			CONVERGENCE_FRAMES, west_end, east_end])
		return

	# --- compositions thicken together ----------------------------------------
	#
	# Both sides gain heavier units at the same wave numbers. One side scaling
	# while the other did not would bias every later wave, which is the same
	# failure as asymmetric terrain and just as hard to see.
	director.set("ai_test_wave_index", 1)
	var early_west: int = (director.call("_arena_2_kon_mix") as Array).size()
	var early_east: int = (director.call("_arena_2_steel_mix") as Array).size()
	director.set("ai_test_wave_index", 6)
	var late_west: int = (director.call("_arena_2_kon_mix") as Array).size()
	var late_east: int = (director.call("_arena_2_steel_mix") as Array).size()
	if late_west <= early_west or late_east <= early_east:
		_fail("Compositions did not thicken with the waves: Kon %d->%d, Steel %d->%d" % [
			early_west, late_west, early_east, late_east])
		return
	if (late_west - early_west) != (late_east - early_east):
		_fail("One side gained %d unit types and the other %d; later waves are biased" % [
			late_west - early_west, late_east - early_east])
		return

	print("[KonArena2SmokeTest] the arena is mirrored cell for cell, Kon and the Steel Force are sent to the same middle from opposite camps, they get there and meet, and both rosters thicken on the same waves")
	scene.queue_free()
	quit(0)

# --- helpers ----------------------------------------------------------------

# Kon's side is Kon's roster; the Steel side is the Steel Force. Both read from
# the catalog, and every unit on both must be spawnable.
func _check_rosters_are_real(director: Node) -> bool:
	var kon_roster: Array = UnitCatalog.fieldable_units_for_class("bad_kon_willow")
	var steel_roster: Array = UnitCatalog.fieldable_units_for_faction(&"steel_force")
	if kon_roster.is_empty() or steel_roster.is_empty():
		_fail("A faction has no fieldable units at all: kon=%s steel=%s" % [kon_roster, steel_roster])
		return false

	# At the last wave threshold both rosters must be fully present -- a unit
	# that never joins any wave is a unit the arena does not test.
	director.set("ai_test_wave_index", 9)
	var kon_mix: Array = director.call("_arena_2_kon_mix")
	var steel_mix: Array = director.call("_arena_2_steel_mix")
	for archetype in kon_roster:
		if not kon_mix.has(archetype):
			_fail("%s is on Kon's roster and never appears in the arena" % archetype)
			return false
	for archetype in steel_roster:
		if not steel_mix.has(archetype):
			_fail("%s is a Steel Force unit and never appears in the arena" % archetype)
			return false

	# Nothing from anyone else. This is the assertion the first version needed:
	# terrible_thing, horror and apex passed every other check.
	for archetype in kon_mix:
		if not kon_roster.has(archetype):
			_fail("Kon's arena army fields %s, which is not on Kon's roster" % archetype)
			return false
	for archetype in steel_mix:
		if UnitCatalog.faction_of(archetype) != &"steel_force":
			_fail("The Steel Force arena army fields %s, which is not Steel Force" % archetype)
			return false

	# Every one of them can actually be built. A missing scene spawns nothing and
	# says nothing.
	for archetype in kon_mix + steel_mix:
		if director.call("_scene_for_test_unit", archetype) == null:
			_fail("%s is in an arena roster but the arena has no scene for it, so it silently spawns nothing" % archetype)
			return false
	director.set("ai_test_wave_index", 1)
	return true

# Arena 2.0 units keep their art and their own logic.
func _check_units_are_whole(scene: Node) -> bool:
	var stripped: Array[StringName] = []
	var idle: Array[StringName] = []
	var checked := 0
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.get("unit_archetype") == null:
			continue
		if int(unit.get("owner_player_id")) == 1:
			continue
		checked += 1
		if unit.get_node_or_null("ArtSprite") == null:
			stripped.append(StringName(unit.get("unit_archetype")))
		if not unit.is_processing():
			idle.append(StringName(unit.get("unit_archetype")))
	if checked == 0:
		_fail("No arena units to inspect")
		return false
	if not stripped.is_empty():
		_fail("%d of %d arena units have no ArtSprite (%s): they were prepared as lightweight and cannot animate" % [
			stripped.size(), checked, stripped.slice(0, 4)])
		return false
	if not idle.is_empty():
		_fail("%d of %d arena units are not processing (%s), so they cannot animate or act" % [
			idle.size(), checked, idle.slice(0, 4)])
		return false
	return true

# Every cell must match its mirror about the vertical centre line.
func _check_symmetry(map: Node) -> bool:
	var bounds: Rect2i = map.call("kon_arena_2_bounds")
	var centre: Vector2i = map.call("kon_arena_2_centre")
	var mismatches := 0
	var first := Vector2i.ZERO
	for x in range(bounds.position.x, centre.x):
		var mirrored_x: int = centre.x + (centre.x - x)
		if mirrored_x >= bounds.end.x:
			continue
		for y in range(bounds.position.y, bounds.end.y):
			var here: bool = map.call("is_walkable_cell", Vector2i(x, y))
			var there: bool = map.call("is_walkable_cell", Vector2i(mirrored_x, y))
			if here != there:
				if mismatches == 0:
					first = Vector2i(x, y)
				mismatches += 1
	if mismatches > 0:
		_fail("The arena is not mirrored: %d cells differ from their opposite, first at %s. One side has better ground than the other." % [
			mismatches, first])
		return false
	return true

func _archetypes_for_owner(scene: Node, owner_id: int) -> Array[StringName]:
	var found: Array[StringName] = []
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.get("unit_archetype") == null:
			continue
		if int(unit.get("owner_player_id")) != owner_id:
			continue
		var archetype := StringName(unit.get("unit_archetype"))
		if not found.has(archetype):
			found.append(archetype)
	found.sort()
	return found

func _mean_distance_to(scene: Node, owner_id: int, map: Node, centre: Vector2i) -> float:
	var total := 0.0
	var count := 0
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.get("unit_archetype") == null:
			continue
		if int(unit.get("owner_player_id")) != owner_id:
			continue
		var cell: Vector2i = map.call("world_to_cell", (unit as Node2D).global_position)
		total += Vector2(cell - centre).length()
		count += 1
	return total / float(maxi(count, 1))

# Both armies with a unit inside the killing field at the same time.
func _sides_in_contact(scene: Node, map: Node, centre: Vector2i) -> bool:
	var west := false
	var east := false
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.get("unit_archetype") == null:
			continue
		var cell: Vector2i = map.call("world_to_cell", (unit as Node2D).global_position)
		if Vector2(cell - centre).length() > 16.0:
			continue
		match int(unit.get("owner_player_id")):
			2: west = true
			3: east = true
	return west and east

func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	push_error(message)
	quit(1)
