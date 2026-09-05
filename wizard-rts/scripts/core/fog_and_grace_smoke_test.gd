extends SceneTree

# Guard for two things added 2026-09-02:
#
#  1. A 3-minute GRACE PERIOD before the first wave. Everything downstream --
#     phases, waves and the boss -- is measured from the end of it, so the gap
#     between the first wave and the boss stays as tuned instead of collapsing.
#
#  2. FOG OF WAR, re-enabled on seeded_grid_frontier and rebuilt around a shared
#     vision TEXTURE rather than per-cell drawing. The texture is what makes it
#     affordable enough to switch on (one small upload per update instead of
#     thousands of draw_polygon calls) and what lets the 2D overlay and the 3D
#     view read the same source.
#
# Both apply to the 2D and 3D presentations, because both run the same systems.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "fog-grace-smoke", "bad_kon_willow", "seeded_grid_frontier")
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
	for _i in 6:
		await process_frame

	var wave_director: Node = scene.get_node_or_null("WaveDirector")
	var fog: Node = scene.get_node_or_null("FogOfWar")
	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	if wave_director == null or fog == null or map_generator == null:
		_fail("Expected WaveDirector, FogOfWar and MapGenerator")
		return

	# --- grace period ------------------------------------------------------
	if float(wave_director.get("grace_period_seconds")) < 180.0:
		_fail("The grace period should be at least 3 minutes, got %s" % wave_director.get("grace_period_seconds"))
		return
	if not bool(wave_director.call("is_in_grace_period")):
		_fail("A run should start inside the grace period")
		return
	if str(wave_director.get("phase")) != "grace":
		_fail("The opening phase should be 'grace', got %s" % wave_director.get("phase"))
		return
	if float(wave_director.call("combat_time_elapsed")) > 0.0:
		_fail("No combat time should have elapsed during grace")
		return
	var boss_at_start := int(wave_director.call("get_boss_seconds_remaining"))

	# Halfway through grace: still no waves, and the boss clock has not started.
	wave_director.set("elapsed", 90.0)
	wave_director.call("_update_phase")
	if int(wave_director.get("wave_index")) != 0:
		_fail("No wave may spawn during the grace period, wave_index is %s" % wave_director.get("wave_index"))
		return
	if int(wave_director.call("get_boss_seconds_remaining")) != boss_at_start:
		_fail("The boss countdown must not run during the grace period")
		return
	if not bool(wave_director.call("is_in_grace_period")):
		_fail("90s in should still be inside a 180s grace period")
		return

	# Past it, the normal schedule resumes from zero.
	wave_director.set("elapsed", float(wave_director.get("grace_period_seconds")) + 1.0)
	wave_director.call("_update_phase")
	if bool(wave_director.call("is_in_grace_period")):
		_fail("The grace period should be over once elapsed passes it")
		return
	if str(wave_director.get("phase")) != "scouting":
		_fail("Phases should start at 'scouting' after grace, got %s" % wave_director.get("phase"))
		return
	if float(wave_director.call("combat_time_elapsed")) > 2.0:
		_fail("Combat time should be measured from the END of grace, got %s" % wave_director.call("combat_time_elapsed"))
		return

	# --- fog of war --------------------------------------------------------
	if not fog.get("visible") and fog.get_node_or_null("FogOverlay2D") == null:
		_fail("Fog should be active on seeded_grid_frontier, with a shader overlay")
		return
	var texture: Texture2D = fog.call("get_fog_texture")
	if texture == null:
		_fail("Fog should publish a vision texture for both presentations to share")
		return
	if texture.get_width() != int(map_generator.MAP_W) or texture.get_height() != int(map_generator.MAP_H):
		_fail("The fog texture should be one texel per cell, got %sx%s" % [texture.get_width(), texture.get_height()])
		return
	var overlay: Node = fog.get_node_or_null("FogOverlay2D")
	if overlay == null:
		_fail("Expected the 2D shader overlay")
		return
	if (overlay as Sprite2D).material == null:
		_fail("The fog overlay must use the shader, not per-cell drawing")
		return

	# Vision must actually follow units: somewhere far from anything the player
	# owns should be dark, and a cell under a friendly unit should be lit.
	var far_corner: Vector2 = map_generator.call("cell_to_world", Vector2i(2, 2))
	if bool(fog.call("is_world_position_visible", far_corner)):
		_fail("A far corner with nothing near it should not be visible")
		return
	var lit := map_generator.call("cell_to_world", map_generator.call("nearest_walkable_cell", Vector2i(50, 50), 20)) as Vector2
	var scout: Node = (load("res://scenes/units/oaven_spear.tscn") as PackedScene).instantiate()
	scout.set("owner_player_id", 1)
	scene.add_child(scout)
	scout.global_position = lit
	await process_frame
	fog.call("_update_visibility")
	if not bool(fog.call("is_world_position_visible", (scout as Node2D).global_position)):
		_fail("The cell a friendly unit is standing on must be visible")
		return

	# An enemy outside vision is hidden; the same query is what the 3D view uses,
	# so the two presentations cannot disagree about what is concealed.
	var hidden_spot := map_generator.call("cell_to_world", map_generator.call("nearest_walkable_cell", Vector2i(8, 8), 20)) as Vector2
	var lurker: Node = (load("res://scenes/units/oaven_spear.tscn") as PackedScene).instantiate()
	lurker.set("owner_player_id", 2)
	scene.add_child(lurker)
	lurker.global_position = hidden_spot
	await process_frame
	fog.call("_update_visibility")
	fog.call("_apply_entity_visibility")
	if bool(fog.call("is_world_position_visible", hidden_spot)):
		_fail("An unscouted corner should stay concealed")
		return
	if (lurker as Node2D).visible:
		_fail("An enemy standing in fog should be hidden in the 2D view")
		return

	print("[FogAndGraceSmokeTest] 3-minute grace gates waves/phases/boss, and fog publishes a shared vision texture that conceals correctly")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
