extends SceneTree

class Ground extends Node:
	var blocked := false
	func world_to_cell(p: Vector2) -> Vector2i: return Vector2i(p/64)
	func cell_to_world(c: Vector2i) -> Vector2: return Vector2(c)*64+Vector2.ONE*32
	func is_walkable_cell(c: Vector2i) -> bool: return not blocked and c.x>=0 and c.y>=0 and c.x<40 and c.y<40
	func get_height(_c: Vector2i) -> int: return 0

var failures := 0
func check(ok: bool, label: String) -> void:
	print("[Steel] ",label," ",ok)
	if not ok: failures+=1

func _initialize() -> void: call_deferred("_run")
func spawn(id: String, at: Vector2, owner: int = 2) -> RTSUnit:
	var unit: RTSUnit = load("res://scenes/units/"+id+".tscn").instantiate()
	unit.owner_player_id = owner
	root.add_child(unit)
	unit.global_position = at
	unit.set_physics_process(false)
	unit.set_process(false)
	return unit

func _run() -> void:
	var ground := Ground.new()
	root.add_child(ground)
	var poorper := spawn("poorper",Vector2(600,600))
	var knight := spawn("steel_knight",Vector2(650,600),1)
	check(poorper.move_speed>knight.move_speed and knight.armor>poorper.armor and knight.attack_damage>poorper.attack_damage,"Infantry roles")
	var hp := poorper.health
	knight._fire_attack(poorper)
	check(poorper.health<hp,"Knight melee damage")
	var blimp := spawn("proper_blimp",Vector2(1000,1000))
	blimp.terrain = ground
	check(blimp.ignores_terrain,"Blimp flying")
	check(blimp.activate_land(),"Land on clear ground")
	check(not blimp.ignores_terrain and blimp._current_move_speed()==0,"Landed grounded and stationary")
	var crew: Array[RTSUnit] = []
	for i in 4:
		var unit := spawn("poorper",Vector2(1080+i*8,1000))
		crew.append(unit)
	check(not blimp.board(knight),"Reject enemy and non-Poorper")
	for i in 3: check(blimp.board(crew[i]),"Board slot "+str(i))
	check(not blimp.board(crew[3]),"Capacity three")
	check(not blimp.board(crew[0]),"No duplicate boarding")
	check(crew[0].is_banished() and not crew[0].is_in_group("selectable_units") and crew[0].collision_layer==0,"Passenger exclusion")
	hp = knight.health
	crew[0]._fire_attack(knight)
	check(knight.health==hp,"Passenger cannot attack")
	check(blimp.activate_takeoff(),"Takeoff")
	var target_hp := knight.health
	knight.global_position = blimp.global_position+Vector2(100,0)
	blimp._fire_attack(knight)
	for child in root.get_children():
		if child is RtsProjectile: child._process(0.4)
	check(knight.health<target_hp,"Crewed blimp projectile hits")
	knight.global_position = Vector2(650,600)
	check(not blimp.activate_unload(),"Cannot unload airborne")
	ground.blocked = true
	check(not blimp.activate_land(),"Blocked landing rejected")
	ground.blocked = false
	check(blimp.activate_land(),"Land again")
	ground.blocked = true
	check(not blimp.activate_unload() and blimp.passengers.size()==3,"Blocked unload retains passengers")
	ground.blocked = false
	check(blimp.activate_unload() and blimp.passengers.is_empty(),"Unload all into clear spaces")
	check(blimp.activate_takeoff(),"Empty transport can take off")
	var children_before := root.get_child_count()
	blimp._fire_attack(knight)
	check(root.get_child_count()==children_before,"Empty blimp cannot fire")
	check(blimp.activate_land(),"Empty transport lands")
	check(not crew[0].is_banished() and crew[0].is_in_group("selectable_units") and crew[0].collision_layer==2,"Passenger restored")
	check(crew[0].global_position.distance_to(crew[1].global_position)>36,"Unloaded units separated")
	for unit in crew: unit.global_position = Vector2(1080,1000)
	check(blimp.board(crew[0]),"Reboard same object")
	blimp._die()
	check(crew[0].is_queued_for_deletion(),"Carrier death cleans passengers")
	var corpse_found := false
	for child in root.get_children():
		if child is Sprite2D and child.frame==48:
			corpse_found = true
			check(not child.is_in_group("units"),"Corpse is visual only")
			child.queue_free()
	check(corpse_found,"Painted death row playback")
	for id in ["poorper","steel_knight","proper_blimp"]:
		var img := Image.load_from_file("res://assets_game/units/steel_force/painted_v1/"+id+".png")
		check(img.get_size()==Vector2i(4608,2304),id+" atlas dimensions")
		check(img.get_pixel(0,0).a<0.01,id+" transparent background")
		for row in 6:
			check(img.get_region(Rect2i(0,row*384,384,384)).get_used_rect().has_area(),id+" action "+str(row))
	for node in root.get_children():
		if node is RTSUnit or node==ground: node.queue_free()
	await process_frame
	print("[SteelForce] failures=",failures)
	quit(0 if failures==0 else 1)
