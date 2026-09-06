extends SceneTree
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("[KnightLive] ", label, " ", ok)
	if not ok:
		failures += 1
		push_error(label)

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var lit := 0
	for y in range(100, image.get_height() - 100, 8):
		for x in range(50, image.get_width() - 50, 8):
			if image.get_pixel(x, y).get_luminance() > .12: lit += 1
	check(lit > 100, "Nonblank " + label)
	var output := OS.get_environment("ART_SHOT_DIR")
	if not output.is_empty(): image.save_png(output + "/" + label + ".png")

func run() -> void:
	create_timer(150).timeout.connect(func(): quit(9))
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = root.size
	root.get_node("GameSession").start_new_game("serpent-art-review", "bad_kon_willow", "seeded_grid_frontier", "", true)
	var stage: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(stage)
	var terrain: Node = stage.get_node("MapGenerator")
	while not terrain.generation_complete: await process_frame
	for i in 20: await process_frame
	var bridge: BlockNavBridge = stage.get_node("BlockNavBridge")
	var taken: Array[Rect2i] = []
	for plot in terrain.plots:
		if plot.has("rect"): taken.append(plot.rect)
	var origin := bridge.find_flat_site(Vector2i(12, 10), taken)
	check(origin.x >= 0, "Flat review site")
	if origin.x < 0: quit(1); return
	var factory := stage.get_node("BuildSystem")
	var scene: PackedScene = factory._scene_for_unit(&"steel_knight")
	var runner: RTSUnit = scene.instantiate()
	runner.position = terrain.cell_to_world(origin + Vector2i(1, 2))
	runner.owner_player_id = 1
	stage.add_child(runner)
	check(bridge.class_for(runner) == &"infantry", "Infantry navigation preserved")
	var view := stage.get_node("Map3DView")
	view.focus_on_sim_position(terrain.cell_to_world(origin + Vector2i(6, 4)))
	view.set_camera_distance(15)
	stage.get_node("FogOfWar").set_reveal_all(true)
	root.set_meta("observer_archive_open", -1)
	var start := runner.position
	runner.issue_move_order(terrain.cell_to_world(origin + Vector2i(8, 2)))
	await create_timer(1.5).timeout
	check(runner.position.distance_to(start) > 60, "Actual path movement")
	runner.issue_stop_order()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	var actors: Array[Node2D] = [runner]
	for i in range(1, 8):
		var unit: RTSUnit = scene.instantiate()
		unit.owner_player_id = 1
		stage.add_child(unit)
		actors.append(unit)
	for i in 8:
		var unit := actors[i]
		unit.position = terrain.cell_to_world(origin + Vector2i(2 + (i % 4) * 2, 2 + (i / 4) * 4))
		unit.issue_stop_order()
		unit.attack_target = null
		unit.velocity = Vector2.from_angle(i * PI / 4) * 100
		unit.get_node("ArtSprite")._process(0)
		unit.velocity = Vector2.ZERO
	view._sync_unit_sprites(actors)
	await capture("steel_knight_ingame_directions")
	for unit in actors: unit.get_node("ArtSprite").world_facing = Vector2.RIGHT
	for yaw in 8:
		view.camera.global_basis = Basis(Vector3.UP, yaw * PI / 4) * Basis(Vector3.RIGHT, -PI / 4)
		view._sync_unit_sprites(actors)
		var correct := true
		for i in 8:
			var art: Sprite2D = actors[i].get_node("ArtSprite")
			var sprite: Sprite3D = view._sprite_at(i)
			var lift := (float(art.get_meta("foot_anchor_y")) - 128) * sprite.pixel_size
			correct = correct and art.facing_index == yaw and sprite.texture == art.texture and sprite.frame == art.frame and not sprite.flip_h
			correct = correct and absf(sprite.global_position.y - view._unit_transform(actors[i]).origin.y - lift) < .001
		check(correct, "Camera yaw/frame/feet " + str(yaw))
	view._apply_camera_transform()
	var target: RTSUnit = scene.instantiate()
	target.owner_player_id = 2
	target.position = actors[0].position + Vector2(50, 0)
	stage.add_child(target)
	var hp := target.health
	actors[0].attack_target = target
	actors[0]._fire_attack(target)
	actors[0].get_node("ArtSprite")._process(0)
	check(target.health < hp and actors[0].get_node("ArtSprite").frame == 16, "Real melee damage and strike playback")
	var carrier: RTSUnit = load("res://scenes/units/proper_blimp.tscn").instantiate()
	carrier.owner_player_id = 1
	carrier.position = actors[1].position
	stage.add_child(carrier)
	carrier.landed = true
	carrier.visual_lift = 0
	carrier.nav_level = actors[1].nav_level
	check(not carrier.board(actors[1]) and not actors[1].is_banished(), "Knight still cannot board Poorper transport")
	carrier.queue_free()
	for i in 8:
		actors[i].attack_target = null
		actors[i].velocity = Vector2.from_angle(i * PI / 4) * 100
		actors[i].attack_visual_age = 0
		actors[i].get_node("ArtSprite")._process(0)
		actors[i].velocity = Vector2.ZERO
	view._sync_unit_sprites(actors)
	await capture("steel_knight_ingame_attacks")
	var slain := actors[4]
	var page: Texture2D = slain.get_node("ArtSprite").texture
	var before: Array[Node] = view._sprite_root.get_children()
	slain.take_damage(99999, runner)
	var corpses: Array[Node] = view._sprite_root.get_children().filter(func(n: Node) -> bool: return not before.has(n))
	check(corpses.size() == 1, "One directional 3D corpse")
	if corpses.size() == 1:
		check(corpses[0].texture == page and corpses[0].frame == 32, "3D corpse keeps facing and death row")
	actors.remove_at(4)
	view._sync_unit_sprites(actors)
	var mount: RTSUnit = load("res://scenes/units/mounted_knight.tscn").instantiate()
	mount.owner_player_id = 1
	mount.position = terrain.cell_to_world(origin + Vector2i(8, 7))
	stage.add_child(mount)
	var before_dismount: Array[Node] = stage.get_children()
	mount.take_damage(99999, target)
	var riders: Array[Node] = stage.get_children().filter(func(n: Node) -> bool:
		return not before_dismount.has(n) and n is RTSUnit and n.unit_archetype == &"steel_knight")
	check(riders.size() == 1, "Mounted unit releases one Knight")
	if riders.size() == 1:
		var rider: RTSUnit = riders[0]
		var rider_art: Sprite2D = rider.get_node("ArtSprite")
		check(rider.health == int(ceil(rider.max_health * .5)) and rider_art.hframes == 8 and rider_art.vframes == 5 and rider_art.has_method("sync_view_facing"), "Half-health rider inherits new art")
		actors.append(rider)
		view._sync_unit_sprites(actors)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await capture("steel_knight_ingame_720")
	root.remove_meta("observer_archive_open")
	stage.queue_free()
	for i in 5: await process_frame
	print("[KnightLive] failures=", failures)
	quit(0 if failures == 0 else 1)
