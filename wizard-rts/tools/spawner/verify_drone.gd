extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(9))
	var atlas := Image.load_from_file("res://assets_game/units/kon/spawner_drone/painted_v1/drone.png")
	check(atlas.get_size() == Vector2i(3072,1280),"Drone atlas dimensions")
	for row in 5:
		var first: PackedByteArray
		var varied := false
		for column in 12:
			var tile := atlas.get_region(Rect2i(column*256,row*256,256,256))
			var bounds := tile.get_used_rect()
			check(bounds.has_area() and bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<256 and bounds.end.y<256,"Drone frame empty/clipped")
			if column == 0: first = tile.get_data()
			else: varied = varied or first != tile.get_data()
		check(varied,"Drone action has no animation")
	var stage := Node2D.new()
	root.add_child(stage)
	var spawner = load("res://scenes/units/spawner.tscn").instantiate()
	stage.add_child(spawner)
	spawner.set_physics_process(false)
	var target := RTSUnit.new()
	target.unit_archetype = &"poorper"
	target.owner_player_id = 2
	stage.add_child(target)
	target.set_physics_process(false)
	target.position = Vector2(140,0)
	spawner._spawner_elapsed = 100
	spawner.attack_target = target
	spawner._update_spawner_drones([target] as Array[Node2D])
	check(spawner._drone_children.size() == 1,"Automatic combat summon must create a real drone")
	if spawner._drone_children.is_empty(): quit(1); return
	var drone = spawner._drone_children[0]
	drone.set_physics_process(false)
	check(drone.owner_player_id == spawner.owner_player_id and drone.attack_target == target,"Drone ownership/target")
	var art: Sprite2D = drone.get_node("ArtSprite")
	art.set_process(false)
	art._process(.01)
	var first_frame := art.frame
	art._process(.1)
	check(art.texture != null and art.frame != first_frame,"Runtime wingbeats not playing")
	drone.moving = true
	drone.velocity = Vector2(-20,0)
	drone.attack_target = null
	drone.unit_state = &"moving"
	art._process(.05)
	check(art.current_action == &"move" and art.flip_h,"Drone move/facing")
	drone.unit_state = &"attacking"
	art._process(.05)
	check(art.current_action == &"attack","Drone attack animation")
	drone.health -= 1
	art._process(.01)
	check(art.current_action == &"hit","Drone hit animation")
	drone._die()
	await process_frame
	check(not is_instance_valid(drone),"Dead drone still in simulation")
	var corpse: Sprite2D
	for child in stage.get_children():
		if child is Sprite2D: corpse = child
	check(corpse != null and corpse.frame >= 48,"Drone independent death row")
	await create_timer(2).timeout
	check(not is_instance_valid(corpse),"Drone corpse failed to clean up")
	stage.queue_free()
	await process_frame
	print("[DroneArt] failures=",failures)
	quit(0 if failures == 0 else 1)
