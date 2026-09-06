extends SceneTree

# Health bars and damage numbers, checked in the space they are actually drawn.
#
# The thing that makes this worth a test is the failure it was written against.
# Units have drawn their own health bars in _draw() since the 2D days, and those
# bars still run in 3D -- they are simply never on screen, because Map3DView
# hides every CanvasItem in the map subtree. Existing, updating, invisible. A
# test that asked "does the unit have a health bar" would have passed the whole
# time.
#
# So this asserts SCREEN positions: that a live unit produces a bar entry which
# projects to a point inside the viewport, and that a hit produces a number
# anchored near the thing that was hit. And it runs the number path in BOTH
# presentations, because the 2D path goes through the canvas transform instead
# and has no camera at all -- one implementation, two projections, and only a
# test that exercises both would notice one of them returning nonsense.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _check_3d():
		return
	if not await _check_2d():
		return
	print("[CombatFeedbackSmokeTest] health bars project onto the screen over live units in 3D, and a hit floats a damage number over its target in both presentations")
	quit(0)

# --- 3D: bars and numbers ---------------------------------------------------

func _check_3d() -> bool:
	var scene := await _start(true)
	if scene == null:
		return false
	var feedback: Node = scene.get_node_or_null("CombatFeedback")
	var view: Node = scene.get_node_or_null("Map3DView")
	if feedback == null:
		_fail("main_map.tscn has no CombatFeedback node, so nothing draws bars or numbers")
		return false
	if view == null or not is_instance_valid(view):
		_fail("The session asked for the 3D view and Map3DView is not there")
		return false
	if not (feedback.get("project_3d") as Callable).is_valid():
		_fail("Map3DView did not install its projection, so the overlay has no way to place anything")
		return false

	var wave_director: Node = scene.get_node_or_null("WaveDirector")
	var map: Node = scene.get_node_or_null("MapGenerator")
	var target: Node2D = wave_director.call("_spawn_enemy", &"steel_knight", Vector2i(40, 40), scene, Vector2.ZERO)
	if target == null or not is_instance_valid(target):
		_fail("Could not spawn something to shoot at")
		return false
	# Look at it, or every assertion below is really just testing the camera's
	# starting position.
	if view.has_method("focus_on_sim_position"):
		view.call("focus_on_sim_position", target.global_position)
	for _i in 20:
		await process_frame

	# --- a bar, on screen, over the unit -------------------------------------
	var entries: Array = feedback.get("bar_entries")
	if entries.is_empty():
		_fail("No health bar entries at all while a unit is alive and in view")
		return false
	var entry := _entry_for(entries, target)
	if entry.is_empty():
		_fail("The spawned unit has no health bar entry")
		return false
	var project: Callable = feedback.get("project_3d")
	var at: Vector2 = project.call(entry["head"])
	var viewport_rect: Rect2 = root.get_viewport().get_visible_rect()
	if at == Vector2.INF or not viewport_rect.has_point(at):
		_fail("The bar for a unit the camera is looking at projects to %s, outside the viewport %s" % [at, viewport_rect])
		return false
	# Above the unit, not on it. A bar drawn at the feet is not a health bar.
	var feet: Vector2 = project.call(target.global_position)
	if feet != Vector2.INF and at.y >= feet.y:
		_fail("The health bar sits at or below the unit's own position on screen (bar y=%s, unit y=%s)" % [at.y, feet.y])
		return false

	# --- a hit, and a number that follows the target --------------------------
	if int(feedback.call("live_number_count")) != 0:
		_fail("Numbers on screen before anything was hit")
		return false
	var before_health := int(target.get("health"))
	target.call("take_damage", 25, null, &"physical")
	await process_frame
	if int(feedback.call("live_number_count")) != 1:
		_fail("A unit took damage and no number appeared")
		return false
	var numbers: Array = feedback.call("live_numbers")
	# The MITIGATED number, not the raw one. A Steel Knight has 10 armour, so a
	# 25 should read as 15 -- showing the weapon's damage rather than the damage
	# taken is the classic version of this bug and it makes armour invisible.
	var shown := int(numbers[0]["amount"])
	var actually_lost := before_health - int(target.get("health"))
	if shown != actually_lost:
		_fail("The number says %d and the unit actually lost %d health" % [shown, actually_lost])
		return false
	if shown >= 25:
		_fail("The number shows the raw damage (%d), so the target's armour is invisible" % shown)
		return false

	# It expires on its own rather than accumulating for the rest of the run.
	for _i in 90:
		await process_frame
	if int(feedback.call("live_number_count")) != 0:
		_fail("A damage number is still on screen a second and a half later")
		return false

	# --- and the bars stop when the units do ---------------------------------
	# By instance id, because the node is gone by the time this is checked and
	# passing a freed object to a typed Node parameter is an error rather than a
	# null -- which is how this test first failed, mid-await, and then hung.
	var target_id := target.get_instance_id()
	target.call("take_damage", 99999, null, &"physical")
	for _i in 10:
		await process_frame
	for remaining in feedback.get("bar_entries"):
		var reference = remaining.get("unit")
		var candidate = reference.get_ref() if reference is WeakRef else null
		if candidate != null and candidate.get_instance_id() == target_id:
			_fail("A dead unit still has a health bar entry")
			return false

	scene.queue_free()
	for _i in 4:
		await process_frame
	return true

# --- 2D: numbers only, through the canvas transform -------------------------

func _check_2d() -> bool:
	var scene := await _start(false)
	if scene == null:
		return false
	var feedback: Node = scene.get_node_or_null("CombatFeedback")
	if (feedback.get("project_3d") as Callable).is_valid():
		_fail("The 2D presentation should have no 3D projection installed")
		return false
	# Units draw their own bars in 2D. A second set from the overlay would be
	# two bars over every unit.
	if not (feedback.get("bar_entries") as Array).is_empty():
		_fail("The overlay is collecting health bars in 2D, where the units already draw their own")
		return false

	var wave_director: Node = scene.get_node_or_null("WaveDirector")
	var target: Node2D = wave_director.call("_spawn_enemy", &"poorper", Vector2i(40, 40), scene, Vector2.ZERO)
	if target == null or not is_instance_valid(target):
		_fail("Could not spawn a 2D target")
		return false
	for _i in 5:
		await process_frame
	target.call("take_damage", 12, null, &"physical")
	await process_frame
	if int(feedback.call("live_number_count")) != 1:
		_fail("The 2D presentation showed no damage number")
		return false
	scene.queue_free()
	return true

# --- helpers ----------------------------------------------------------------

func _start(use_3d: bool) -> Node:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "combat-feedback-smoke", "bad_kon_willow", "build_sandbox", "", use_3d)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _gen_wait in 400:
		if map == null or bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 12:
		await process_frame
	return scene

func _entry_for(entries: Array, unit: Node) -> Dictionary:
	for entry in entries:
		var reference = entry.get("unit")
		var candidate = reference.get_ref() if reference is WeakRef else reference
		if candidate == unit:
			return entry
	return {}

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
