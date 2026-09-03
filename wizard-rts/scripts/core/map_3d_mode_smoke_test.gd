extends SceneTree

# Guard for the 3D view mode added 2026-08-31.
#
# The mechanic being protected is not "3D works" -- it is that the 3D mode is a
# PRESENTATION layer over the unmodified 2D simulation, and never a second
# implementation of the game. `map_3d_renderer.gd` builds its own MapGenerator
# and runs its own toy unit probe; building gameplay against it is the mistake
# this project has already made twice. So the assertions below are mostly about
# what must stay TRUE of the simulation while the 3D view is on:
#
#   * the same main_map.tscn is used, with no forked scene,
#   * MapGenerator, RTSWorld, BuildSystem and the unit nodes are untouched,
#   * the 3D view draws the LIVE generator, not one of its own,
#   * turning the view off leaves the game exactly as it was,
#   * the screen-to-simulation bridge round-trips, because selection, orders and
#     building placement all depend on it.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _check_2d_still_default():
		return
	if not await _check_3d_mode():
		return
	print("[Map3DModeSmokeTest] 3D view renders the live map, leaves the simulation untouched, and stays inert in 2D mode")
	quit(0)

# --- 2D must be completely unaffected ---------------------------------------
func _check_2d_still_default() -> bool:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "map3d-off", "bad_kon_willow", "seeded_grid_frontier", "", false)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 6:
		await process_frame
	if scene.get_node_or_null("Map3DView") != null:
		_fail("Map3DView must free itself when the session did not ask for 3D")
		await _teardown(scene)
		return false
	var world: Node = scene.get_node_or_null("RTSWorld")
	if world == null or bool(world.get("presentation_3d")):
		_fail("presentation_3d must stay false in the 2D mode")
		await _teardown(scene)
		return false
	var tilemap := scene.get_node_or_null("TileMapLow")
	if tilemap != null and not (tilemap as CanvasItem).visible:
		_fail("The 2D tilemap must stay visible in the 2D mode")
		await _teardown(scene)
		return false
	await _teardown(scene)
	return true

# --- 3D mode -----------------------------------------------------------------
func _check_3d_mode() -> bool:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "map3d-on", "bad_kon_willow", "seeded_grid_frontier", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 10:
		await process_frame

	var view: Node = scene.get_node_or_null("Map3DView")
	if view == null:
		_fail("Map3DView should be alive when the session asked for 3D")
		return false
	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	var world: Node = scene.get_node_or_null("RTSWorld")
	var build_system: Node = scene.get_node_or_null("BuildSystem")
	if map_generator == null or world == null or build_system == null:
		_fail("The 3D mode must still run the full 2D system set")
		return false

	# The renderer must be drawing THIS generator, not one of its own. This is
	# the single most important assertion in the file.
	var terrain: Node = view.get_node_or_null("Map3DTerrain")
	if terrain == null:
		_fail("Expected the embedded terrain renderer")
		return false
	if terrain.get("_map_generator") != map_generator:
		_fail("The 3D terrain must render the LIVE MapGenerator, not a private one")
		return false
	if not bool(terrain.get("embedded_mode")):
		_fail("The embedded renderer must be in embedded mode (no camera, UI, probe or input of its own)")
		return false
	if terrain.get_node_or_null("GameplayProbe") != null:
		_fail("The preview tool's toy unit probe must not exist in the game mode")
		return false

	var telemetry: Dictionary = view.call("get_view_telemetry")
	if not bool(telemetry.get("terrain_ready", false)):
		_fail("Terrain should have been built from the live map")
		return false

	# The simulation is untouched: units still exist as 2D nodes, still register
	# with RTSWorld, and are still selectable.
	if not bool(world.get("presentation_3d")):
		_fail("presentation_3d should be set in the 3D mode")
		return false
	var unit: Node = (load("res://scenes/units/oaven_spear.tscn") as PackedScene).instantiate()
	unit.set("owner_player_id", 1)
	scene.add_child(unit)
	unit.global_position = _walkable(map_generator, Vector2i(30, 30))
	for _i in 4:
		await process_frame
	if not (unit is Node2D):
		_fail("Units must still be 2D nodes in the 3D view")
		return false
	if int(world.call("count_units_for_owner", 1)) <= 0:
		_fail("Units must still register with RTSWorld in the 3D view")
		return false
	if (unit as CanvasItem).visible:
		_fail("A unit's 2D canvas drawing should be suppressed while the 3D view renders it")
		return false
	# ...and it is actually being mirrored into the 3D layer.
	for _i in 8:
		await process_frame
	telemetry = view.call("get_view_telemetry")
	if int(telemetry.get("units_rendered", 0)) <= 0:
		_fail("The 3D view should be mirroring live units, rendered %s" % telemetry.get("units_rendered", 0))
		return false

	# The input bridge has to round-trip, because selection, right-click orders
	# and building placement all read the mouse through it.
	var sample := _walkable(map_generator, Vector2i(40, 40))
	var camera: Camera3D = view.get("camera")
	if camera == null:
		_fail("Expected a 3D camera")
		return false
	var world_3d: Vector3 = terrain.call("sim_to_world_3d", sample, 0.0)
	var screen: Vector2 = camera.unproject_position(world_3d)
	var round_tripped: Vector2 = view.call("screen_to_sim_position", screen)
	if round_tripped.distance_to(sample) > 48.0:
		_fail("screen_to_sim_position should round-trip within a cell: sent %s, got %s" % [sample, round_tripped])
		return false

	# --- billboarded sprites vs capsule fallback ---------------------------
	# A unit WITH 2D art must be drawn as a billboard mirroring its own
	# ArtSprite; a unit WITHOUT art must fall back to the capsule multimesh.
	# Getting this wrong silently would show the whole army as capsules, which
	# looks like "3D mode has no art" rather than like a bug.
	var sprited: Node = (load("res://scenes/units/terrible_thing.tscn") as PackedScene).instantiate()
	sprited.set("owner_player_id", 1)
	scene.add_child(sprited)
	sprited.global_position = _walkable(map_generator, Vector2i(32, 32))
	for _i in 10:
		await process_frame
	telemetry = view.call("get_view_telemetry")
	if int(telemetry.get("units_as_sprites", 0)) <= 0:
		_fail("A unit with an ArtSprite should render as a billboard, sprites rendered: %s" % telemetry.get("units_as_sprites", 0))
		return false
	# The billboard must mirror the unit's own animation state rather than
	# carrying a second copy of the direction/frame logic.
	var art := sprited.get_node_or_null("ArtSprite")
	var sprite_root: Node = view.get_node_or_null("UnitSprites3D")
	if art == null or sprite_root == null or sprite_root.get_child_count() == 0:
		_fail("Expected a pooled Sprite3D mirroring the unit's ArtSprite")
		return false
	# Matched by texture rather than by pool index: the wizard also has an
	# ArtSprite and already occupies a slot, so index 0 is not this unit.
	var billboard: Sprite3D = null
	for child in sprite_root.get_children():
		var candidate := child as Sprite3D
		if candidate != null and candidate.visible and candidate.texture == art.texture:
			billboard = candidate
			break
	if billboard == null:
		_fail("No visible billboard is showing the test unit's sheet")
		return false
	if billboard.hframes != int(art.hframes) or billboard.vframes != int(art.vframes):
		_fail("The billboard must use the same sheet grid as the 2D ArtSprite (%sx%s vs %sx%s)" % [billboard.hframes, billboard.vframes, art.hframes, art.vframes])
		return false
	if billboard.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
		_fail("Unit sprites must actually billboard toward the camera")
		return false
	if billboard.shaded:
		_fail("Unit sprites must render unlit so the painted art keeps its own values")
		return false
	# The earlier unit had no art, so it must still be a capsule.
	if int(telemetry.get("units_rendered", 0)) <= int(telemetry.get("units_as_sprites", 0)):
		_fail("The art-less Oaven should still be counted as a capsule fallback")
		return false

	# --- structures use their real art, and obey fog ------------------------
	# Both were wrong in the first pass: buildings rendered as plain boxes even
	# though every KoN structure has an art_sprite, and structures were not fog
	# gated at all, so enemy outposts showed through unexplored blackness.
	var structure_sprites := 0
	var sprite_root_node: Node = view.get_node_or_null("UnitSprites3D")
	for child in sprite_root_node.get_children():
		var candidate := child as Sprite3D
		if candidate != null and candidate.visible and str(candidate.name).begins_with("StructureSprite"):
			structure_sprites += 1
	if structure_sprites <= 0:
		_fail("Structures with art must render as billboards, not boxes")
		return false
	# An enemy structure far from anything the player can see must be concealed.
	var enemy_structure: Node2D = null
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) != 1:
			enemy_structure = structure
			break
	if enemy_structure != null and not bool(view.call("_is_revealed", enemy_structure)):
		# Concealed as expected; make sure it is genuinely excluded from the draw.
		var drawn := false
		for child in sprite_root_node.get_children():
			var s3: Sprite3D = child as Sprite3D
			if s3 != null and s3.visible and s3.global_position.distance_to(view.call("_instance_transform", enemy_structure.global_position, 0.0).origin) < 0.4:
				drawn = true
		if drawn:
			_fail("A fog-concealed enemy structure must not be drawn in the 3D view")
			return false

	# --- impassable terrain is marked in 3D too ----------------------------
	# A MultiMesh of per-cell quads rather than one map-sized sheet: the 3D
	# terrain has real elevation, so a flat plane at y=0 would be buried under
	# every plateau -- hiding exactly the cliffs it exists to mark.
	var marks: Node = view.get_node_or_null("ImpassableMarks3D")
	if marks == null:
		_fail("The 3D view should mark impassable terrain like the 2D map does")
		return false
	var mark_mesh: MultiMesh = (marks as MultiMeshInstance3D).multimesh
	if mark_mesh.visible_instance_count <= 0:
		_fail("The 3D impassable marks bake produced no instances")
		return false
	# Assertions run against compute_marks() -- the same data the bake uploads --
	# NOT against the MultiMesh buffer. MultiMesh instance data lives on the
	# rendering server, and under the headless dummy driver get_instance_transform()
	# reads back all zeros. The previous version of this check inspected that
	# buffer and so compared every mark against cell (0,0): it passed on any code
	# at all, including code that stacked every mark on the origin.
	var marks_data: Array = view.call("compute_marks")
	if marks_data.size() != mark_mesh.visible_instance_count:
		_fail("Marks bake uploaded %s instances but computes %s" % [mark_mesh.visible_instance_count, marks_data.size()])
		return false

	var marked_cells := {}
	for entry in marks_data:
		var cell: Vector2i = entry["cell"]
		marked_cells[cell] = true
		# Each mark must sit on ITS OWN cell's rendered surface, so a mark on a
		# plateau is not buried inside it -- the whole reason this is a MultiMesh
		# of per-cell quads rather than one flat map-sized sheet.
		var origin: Vector3 = view.call("mark_origin_for", entry["centre"])
		var expected: float = float(terrain.call("surface_height_at_cell", cell))
		if absf(origin.y - expected) > 0.2:
			_fail("Mark at cell %s sits at y=%s but its terrain surface is %s" % [cell, origin.y, expected])
			return false

	# Economy spaces are the important half: they are the ONLY cells a Bio
	# Absorber may be built on, PlotRenderer draws them, and this mode hides every
	# CanvasItem. Without them the player cannot find a legal spot and the
	# building simply appears unbuildable. They are also registered AFTER the
	# deferred terrain bake, so a bake taken at terrain time has cliffs but no
	# economy spaces -- which is exactly how they went missing.
	var economy_total := 0
	for plot in map_generator.get("plots"):
		for economy_cell in plot.get("economy_spaces", []):
			economy_total += 1
			if not marked_cells.has(economy_cell):
				_fail("Economy space %s is unmarked in 3D, so a Bio Absorber has no visible legal cell" % economy_cell)
				return false
	if economy_total <= 0:
		_fail("The map generated no economy spaces, so this assertion proves nothing")
		return false

	# And nothing else is marked: plain blockers are visible geometry in 3D, so
	# marking them was noise.
	for cell in marked_cells:
		if bool(map_generator.call("is_cliff_edge_cell", cell)):
			continue
		var is_economy := false
		for plot in map_generator.get("plots"):
			if plot.get("economy_spaces", []).has(cell):
				is_economy = true
				break
		if not is_economy:
			_fail("Cell %s is marked in 3D but is neither a cliff edge nor an economy space" % cell)
			return false

	# Units with no sprite sheet -- still the whole KoN roster -- fell back to a
	# featureless capsule in 3D, throwing away the detailed procedural art they
	# already draw in _draw(). They are now rendered once per archetype into a
	# SubViewport and billboarded.
	#
	# What is asserted here is the SAFETY of that, not the pixels: a unit
	# instantiated for baking would otherwise join the live simulation, because
	# RTSUnit._ready() adds itself to the "units" and "selectable_units" groups
	# and to a static registry. A leak there would put an invisible, invincible
	# unit in the world -- selectable, targetable, and counted against supply.
	#
	# The rendered result is deliberately NOT asserted: the headless dummy driver
	# rasterises nothing, so every bake comes back empty here regardless of
	# correctness. That is verified against a real renderer instead.
	var art_telemetry: Dictionary = view.call("get_view_telemetry")
	if int(art_telemetry.get("baked_archetypes", 0)) <= 0:
		_fail("No art-less archetype was queued for baking, so every KoN unit is still a capsule")
		return false
	# No node used for baking may be in a live gameplay group. Checked by walking
	# the baker's own subtree rather than by comparing group counts before and
	# after, so the assertion does not depend on when a bake happens to finish.
	var baker: Node = view.get_node_or_null("UnitArtBaker")
	if baker != null and not _bake_subtree_is_inert(baker):
		return false

	# Camera pitch and FOV, and the invariant behind the live tuning keys.
	#
	# Both values were wrong until 2026-09-04 and were the real reason billboards
	# looked pasted onto the ground: pitch did not match the angle the 2D art is
	# drawn at, and FOV was never set at all (Godot default 75), so the ground was
	# seen from 14 to 89 degrees within one frame while every billboard presented
	# the same face.
	#
	# The invariant asserted here is what makes tuning them meaningful: changing
	# the FOV must NOT change how much ground is on screen. Camera distances are
	# authored in reference units and converted against the live FOV for exactly
	# this reason. Without it, "narrow the FOV" would just zoom you in and tell
	# you nothing about perspective -- and every existing set_camera_distance()
	# caller would silently reframe.
	#
	# _handle_camera_tuning() is called directly: the debug-build gate is at the
	# input call site, not inside it, so this runs in any build.
	var framed_before: float = _framed_ground_span(view)
	if framed_before <= 0.0:
		_fail("Could not project the framed ground span -- camera is not looking at the ground")
		return false
	var fov_before: float = float(view.get("camera_fov"))
	view.call("_handle_camera_tuning", _tuning_key(KEY_BRACKETLEFT))
	var fov_after: float = float(view.get("camera_fov"))
	if is_equal_approx(fov_after, fov_before):
		_fail("The [ key did not change the camera FOV")
		return false
	var framed_after: float = _framed_ground_span(view)
	if absf(framed_after - framed_before) > framed_before * 0.04:
		_fail("Changing FOV %s -> %s reframed the ground (%.2f -> %.2f). Distance must compensate." % [
			fov_before, fov_after, framed_before, framed_after])
		return false

	var pitch_before: float = float(view.get("camera_pitch_degrees"))
	view.call("_handle_camera_tuning", _tuning_key(KEY_APOSTROPHE))
	if float(view.get("camera_pitch_degrees")) >= pitch_before:
		_fail("The apostrophe key should steepen the camera pitch")
		return false

	view.call("_handle_camera_tuning", _tuning_key(KEY_BACKSPACE))
	if not is_equal_approx(float(view.get("camera_fov")), float(view.get("DEFAULT_CAMERA_FOV"))):
		_fail("Backspace should reset the FOV to its default")
		return false
	if not is_equal_approx(float(view.get("camera_pitch_degrees")), float(view.get("DEFAULT_CAMERA_PITCH_DEGREES"))):
		_fail("Backspace should reset the pitch to its default")
		return false

	# Terrain props are the ones that caught this out during development -- they
	# live under MapGenerator, not the scene root, so a name-based hide missed
	# them and they painted over the 3D world.
	var props := map_generator.get_node_or_null("VisualProps")
	if props != null and (props as CanvasItem).visible:
		_fail("2D terrain props must be hidden in the 3D view")
		return false

	return true

# How much ground the frame covers, measured by projecting two screen points
# onto the ground plane. Deliberately measured through the real camera
# projection rather than computed from distance and FOV, so it would catch the
# compensation being applied to the wrong quantity.
#
# Sampled SYMMETRICALLY about the screen centre. The ground plane is oblique to
# the view, so a single distance scale cannot hold the framing exactly across the
# whole frame -- nor should it, since changing the FOV is supposed to change how
# the ground foreshortens away from centre. What must hold is the framing at the
# focus, which is what symmetric sampling measures. (Off-centre this reads a ~2%
# residual; uncompensated, the same FOV step moves it 8%.)
func _framed_ground_span(view: Node) -> float:
	var viewport_size: Vector2 = view.get_viewport().get_visible_rect().size
	# Both points below the horizon, or the ray never reaches the ground.
	var near_point: Vector3 = view.call("_ground_point", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.42))
	var far_point: Vector3 = view.call("_ground_point", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.58))
	if near_point == Vector3.INF or far_point == Vector3.INF:
		return -1.0
	return near_point.distance_to(far_point)

func _tuning_key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _bake_subtree_is_inert(node: Node) -> bool:
	for group in ["units", "selectable_units", "structures"]:
		if node.is_in_group(group):
			_fail("Sprite baking left %s in the live '%s' group" % [node.name, group])
			return false
	for child in node.get_children():
		if not _bake_subtree_is_inert(child):
			return false
	return true

func _walkable(map_generator: Node, cell: Vector2i) -> Vector2:
	return map_generator.call("cell_to_world", map_generator.call("nearest_walkable_cell", cell, 24))

func _teardown(scene: Node) -> void:
	scene.queue_free()
	await process_frame
	await process_frame

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
