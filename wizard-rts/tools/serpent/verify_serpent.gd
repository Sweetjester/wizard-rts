extends SceneTree

var failures := 0
class Map extends Node:
	var blocked: Dictionary = {}
	func cell_to_world(c: Vector2i) -> Vector2: return Vector2(c)*64
	func world_to_cell(p: Vector2) -> Vector2i: return Vector2i((p/64).round())
	func get_height(_c: Vector2i) -> int: return 0
	func is_walkable_cell(c: Vector2i) -> bool: return not blocked.has(c)
	func add_dynamic_blockers(cells: Array[Vector2i]) -> void:
		for c in cells: blocked[c] = true
	func remove_dynamic_blockers(cells: Array[Vector2i]) -> void:
		for c in cells: blocked.erase(c)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; push_error(label)
	else: print("[Serpent] PASS: ",label)

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var map := Map.new()
	map.name = "MapGenerator"
	stage.add_child(map)
	var world := RTSWorld.new()
	world.name = "RTSWorld"
	stage.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	var serpent: Node2D = load("res://scenes/units/stone_face_serpent.tscn").instantiate()
	stage.add_child(serpent)
	serpent.set_physics_process(false)
	var previous_hp: int = serpent.max_health
	var previous_range: float = serpent.attack_range
	for level in range(2,7):
		serpent._gain_evolution_xp(45)
		check(serpent.evolution_level==level and serpent.max_health>previous_hp and serpent.attack_range<previous_range,"Evolution %d adds HP and reduces reach" % (level-1))
		previous_hp = serpent.max_health
		previous_range = serpent.attack_range
	serpent._gain_evolution_xp(10000)
	check(serpent.evolution_level==6,"Exactly five evolutions after the starting form")
	var cells: Array[Vector2i] = serpent._line_cells(Vector2i(1,1),Vector2i(4,3),serpent._stone_length())
	check(cells.size()==8 and cells[3]==Vector2i(4,1) and cells[4]==Vector2i(4,2),"Full-length wall has a 90-degree bend")
	serpent._stone_drag_start = Vector2i(1,1)
	serpent._stone_drag_cells.assign([Vector2i(1,1)])
	serpent._extend_stone_drag(Vector2i(3,1))
	serpent._extend_stone_drag(Vector2i(3,3))
	serpent._extend_stone_drag(Vector2i(1,3))
	var bent: Array[Vector2i] = serpent._drag_wall_cells()
	check(bent.size()==8 and bent[2]==Vector2i(3,1) and bent[4]==Vector2i(3,3) and bent[6]==Vector2i(1,3),"Dragging supports multiple right-angle bends")
	var normal_hp: int = serpent.max_health
	var normal_armor: int = serpent.armor
	serpent.health = normal_hp/2
	serpent._enter_stone_form(cells)
	check(serpent._stone_form_active and serpent.max_health==normal_hp*3 and serpent.armor>normal_armor and serpent.attack_damage==0,"Harden grants level-scaled HP/armor and removes attack")
	check(absf(float(serpent.health)/serpent.max_health-0.5)<0.01,"Harden preserves health fraction")
	check(world.all_structures().size()==8 and map.blocked.size()==8,"Every wall segment is targetable and blocks a tile")
	var anchor: Vector2 = serpent.global_position
	serpent.rts_movement_tick(1.0)
	serpent._snap_to_walkable_terrain()
	check(serpent.global_position==anchor,"Central movement cannot move the hardened wall owner")
	serpent.apply_poison(null,3.0,2.0)
	var poisoned_hp: int = serpent.health
	serpent._process(1.1)
	check(serpent.health<poisoned_hp,"Hardening does not freeze existing poison damage")
	var segment: Node = serpent._stone_wall_segments[3]
	check(segment.get_selection_owner()==serpent and segment.art_sprite.texture!=null,"Bent segment has painted art and selects its owner")
	var before: int = serpent.health
	segment.take_damage(40,null,&"physical")
	check(serpent.health<before,"Wall damage reaches shared armored health pool")
	var enemy: Node2D = load("res://scenes/units/oaven_spear.tscn").instantiate()
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(500,500)
	var enemy_hp: int = enemy.health
	serpent._fire_attack(enemy)
	check(enemy.health==enemy_hp,"Direct attacks cannot bypass wall disarm")
	var moved: Array[Vector2i] = serpent._line_cells(Vector2i(2,1),Vector2i(5,3),8)
	serpent._enter_stone_form(moved)
	check(not map.blocked.has(Vector2i(1,1)) and map.blocked.size()==8,"Reshaping replaces blockers without leaving old tiles")
	var ratio: float = float(serpent.health)/serpent.max_health
	serpent.activate_revert_stone_form()
	check(map.blocked.is_empty() and serpent.max_health==normal_hp and serpent.armor==normal_armor,"Revert removes every blocker and restores mobile stats")
	check(absf(float(serpent.health)/serpent.max_health-ratio)<0.01,"Revert cannot heal by toggling forms")
	serpent._fire_attack(enemy)
	check(enemy.health<enemy_hp and not enemy._damage_over_time_effects.is_empty(),"Melee bite applies passive poison")
	var poison_hp: int = enemy.health
	enemy._update_damage_over_time(1.1)
	check(enemy.health<poison_hp,"Poison deals damage over time")
	var remote: Array[Vector2i] = [Vector2i(99,99)]
	var diagonal: Array[Vector2i] = [Vector2i(2,1),Vector2i(3,2)]
	check(not serpent._stone_cells_are_valid(remote),"Remote placement rejected")
	check(not serpent._stone_cells_are_valid(diagonal),"Diagonal wall segment rejected")
	for level in range(1,7):
		var img := Image.load_from_file("res://assets_game/units/kon/serpent/directional_v3/serpent_%d_e.png" % level)
		check(img.get_size()==Vector2i(2048,2304),"Level %d contains 72 frames per direction" % level)
		for row in 9:
			var a := img.get_region(Rect2i(0,row*256,256,256))
			var b := img.get_region(Rect2i(5*256,row*256,256,256))
			check(a.get_used_rect().size.x>40 and a.get_used_rect().position.x>0 and a.get_used_rect().end.x<256,"Unclipped level %d row %d" % [level,row])
			if row!=4: check(a.get_data()!=b.get_data(),"Animation changes level %d row %d" % [level,row])
	serpent.take_damage(9999,null,&"magic")
	await process_frame
	var corpses := stage.get_children().filter(func(node: Node) -> bool: return node.get_script()==preload("res://scripts/fx/painted_unit_death.gd"))
	check(not corpses.is_empty(),"Death leaves the animated painted corpse")
	stage.queue_free()
	await process_frame
	print("[Serpent] failures=",failures)
	quit(0 if failures==0 else 1)
