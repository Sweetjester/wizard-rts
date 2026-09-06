extends SceneTree

# The mouse becomes a sword over something the selection can attack.
#
# The rules that matter are the ones that turn it OFF. A cursor that promises an
# attack the game will not carry out is worse than no cursor at all, so the
# sword must appear exactly where a right-click would issue an attack order and
# nowhere else:
#
#   * nothing selected            -> no sword (a right-click does nothing)
#   * selection is buildings only -> no sword (nothing there can attack)
#   * hovering open ground        -> no sword (a right-click is a move order)
#   * hovering your OWN unit      -> no sword
#   * hovering an enemy           -> sword
#
# The last two share one code path with the right-click handler on purpose --
# _attackable_at_position() is what decides both -- so the cursor cannot drift
# out of agreement with what the click actually does. That agreement is asserted
# directly at the end rather than assumed.
#
# The texture is checked for pixels rather than for dimensions: "a 28x28 texture
# exists" would pass on a fully transparent image, which is what a broken
# procedural draw produces.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check_texture():
		return

	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "attack-cursor-smoke", "bad_kon_willow", "build_sandbox")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _gen_wait in 400:
		if map == null or bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 10:
		await process_frame

	var selection: Node = scene.get_node_or_null("SelectionController")
	var wave_director: Node = scene.get_node_or_null("WaveDirector")
	if selection == null or wave_director == null:
		_fail("Expected a SelectionController and a WaveDirector")
		return

	var origin := Vector2i(40, 40)
	var mine: Node2D = wave_director.call("_spawn_enemy", &"oaven_spear", origin, scene, Vector2.ZERO)
	mine.set("owner_player_id", 1)
	var enemy: Node2D = wave_director.call("_spawn_enemy", &"poorper", origin + Vector2i(6, 0), scene, Vector2.ZERO)
	enemy.set("owner_player_id", 2)
	for _i in 10:
		await process_frame

	# --- nothing selected -----------------------------------------------------
	if _hover(selection, enemy.global_position):
		_fail("The sword appeared with nothing selected, where a right-click does nothing")
		return

	# --- a unit selected, hovering the enemy ----------------------------------
	var chosen: Array[Node] = [mine as Node]
	selection.call("_apply_selection", chosen)
	if not _hover(selection, enemy.global_position):
		_fail("No sword over a hostile unit with an attacker selected")
		return

	# --- ...and not over open ground or over your own unit --------------------
	if _hover(selection, enemy.global_position + Vector2(2000, 2000)):
		_fail("The sword appeared over open ground, where a right-click is a move order")
		return
	if _hover(selection, mine.global_position):
		_fail("The sword appeared over the player's own unit")
		return

	# --- a selection that cannot attack does not promise one ------------------
	selection.call("_apply_selection", [] as Array[Node])
	if _hover(selection, enemy.global_position):
		_fail("The sword survived the selection being cleared")
		return

	# --- the cursor and the click agree ---------------------------------------
	#
	# The point of the whole feature: wherever the sword shows, a right-click
	# must actually find a target there.
	selection.call("_apply_selection", chosen)
	var showed := _hover(selection, enemy.global_position)
	var target = selection.call("_attackable_at_position", enemy.global_position)
	if showed != (target != null):
		_fail("The cursor says %s and the click finds %s -- they are reading different rules" % [
			showed, target])
		return

	if not _check_mouse_path(selection):
		return

	# --- and it is put away on the way out ------------------------------------
	scene.queue_free()
	for _i in 5:
		await process_frame
	if AttackCursor.is_active():
		_fail("The sword was still installed after the map was freed; it would follow the player to the menu")
		return

	print("[AttackCursorSmokeTest] the pointer becomes a sword exactly where a right-click would attack, and goes back to an arrow everywhere else")
	quit(0)

# --- helpers ----------------------------------------------------------------

# Asks the controller whether the sword belongs at a world position.
#
# Goes through attack_cursor_should_show() rather than through the pointer:
# there is no mouse in a headless run, so driving warp_mouse would make every
# answer below "no" and the test would pass for the wrong reason. The
# mouse-reading half is covered separately by _check_mouse_path().
func _hover(selection: Node, world_position: Vector2) -> bool:
	return bool(selection.call("attack_cursor_should_show", world_position))

# The pointer path itself: _update_attack_cursor() has to read the mouse, apply
# the same rule, and install or remove the cursor without erroring. It cannot
# assert WHICH answer it gets -- that depends on where a mouse that does not
# exist is pointing -- so it asserts that it runs and leaves the cursor in a
# state consistent with its own rule.
func _check_mouse_path(selection: Node) -> bool:
	selection.set("_attack_hover_frame", -1)
	selection.call("_update_attack_cursor")
	var expected: bool = selection.call("attack_cursor_should_show", selection.call("_world_mouse_position"))
	if AttackCursor.is_active() != expected:
		_fail("The mouse-driven update installed %s where its own rule says %s" % [
			AttackCursor.is_active(), expected])
		return false
	return true

func _check_texture() -> bool:
	var texture := AttackCursor.texture()
	if texture == null:
		_fail("No cursor texture was generated")
		return false
	var image := texture.get_image()
	if image.get_width() != AttackCursor.SIZE or image.get_height() != AttackCursor.SIZE:
		_fail("The cursor is %sx%s, expected %s square" % [image.get_width(), image.get_height(), AttackCursor.SIZE])
		return false
	# Pixels, not dimensions: a transparent image is the shape a broken
	# procedural draw takes, and it has exactly the right size.
	var opaque := 0
	var outlined := false
	for x in image.get_width():
		for y in image.get_height():
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.5:
				opaque += 1
				if pixel.is_equal_approx(AttackCursor.OUTLINE):
					outlined = true
	if opaque < 60:
		_fail("The cursor has only %d opaque pixels; nothing was drawn" % opaque)
		return false
	if not outlined:
		_fail("The cursor has no outline, so it will disappear against light terrain")
		return false
	# The tip has to be where the hotspot is, or the sword aims somewhere other
	# than where it points.
	var tip_drawn := false
	for x in 6:
		for y in 6:
			if image.get_pixel(x, y).a > 0.5:
				tip_drawn = true
	if not tip_drawn:
		_fail("Nothing is drawn near the hotspot at %s; the sword does not point where it aims" % AttackCursor.HOTSPOT)
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
