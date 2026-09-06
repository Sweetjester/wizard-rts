extends RTSUnit

var momentum_stacks := 0
var momentum_distance := 0.0
var flame_remaining := 0.0
var ignition_age := 99.0
var attack_visual_age := 99.0
var _blocked_seconds := 0.0
var _rider_spawned := false
var _max_momentum := 5
var _distance_per_stack := 64.0
var _speed_per_stack := .08
var _flame_duration := 12.0
var _flame_multiplier := 1.5

func _ready() -> void:
	unit_archetype=&"mounted_knight"
	super()
	var definition := UnitCatalog.get_definition(unit_archetype)
	_max_momentum=int(definition.get("momentum_max_stacks",5))
	_distance_per_stack=float(definition.get("momentum_distance_per_stack",64))
	_speed_per_stack=float(definition.get("momentum_speed_per_stack",.08))
	_flame_duration=float(definition.get("flame_duration_seconds",12))
	_flame_multiplier=float(definition.get("flame_damage_multiplier",1.5))
	collision_separation=30
	selection_radius=30

func _apply_owner_art_tint() -> void: pass

func _draw() -> void: _draw_selection_and_path()

func _current_move_speed() -> float:
	return super()*(1+momentum_stacks*_speed_per_stack)

func is_ablaze() -> bool: return flame_remaining>0 and is_alive()

func current_attack_damage_for_display() -> int:
	return maxi(1,int(attack_damage*(_flame_multiplier if is_ablaze() else 1.0)))

# Read by the art so the pip strip has as many pips as this unit actually has
# stacks, rather than the five the Mangler happens to use.
func max_momentum_stacks() -> int:
	return _max_momentum

func reset_momentum() -> void:
	momentum_stacks=0
	momentum_distance=0

func accumulate_momentum(distance: float) -> void:
	if not is_alive() or is_banished() or _is_stunned(): return
	var previous := momentum_stacks
	momentum_distance=minf(_max_momentum*_distance_per_stack,momentum_distance+maxf(0,distance))
	momentum_stacks=mini(_max_momentum,int(momentum_distance/_distance_per_stack))
	# Trigger on a fresh threshold crossing, never continually refresh an active buff.
	if previous<_max_momentum and momentum_stacks==_max_momentum and not is_ablaze():
		flame_remaining=_flame_duration
		ignition_age=0

func _tick_presentation_timers(delta: float) -> void:
	flame_remaining=maxf(0,flame_remaining-delta)
	ignition_age+=delta
	attack_visual_age+=delta

func rts_movement_tick(delta: float) -> void:
	_tick_presentation_timers(delta)
	var before := global_position
	var commanded_run := not path.is_empty()
	var intended := (path[0]-before).normalized() if commanded_run else Vector2.ZERO
	super(delta)
	if not is_alive() or is_banished() or _is_stunned():
		reset_momentum()
		return
	var travelled := before.distance_to(global_position)
	# Same distance-based charge rules as Mangler: reject idle separation/teleports.
	if commanded_run and travelled>.01 and travelled<maxf(32,_current_move_speed()*delta*3):
		accumulate_momentum(maxf(0,(global_position-before).dot(intended)))
		_blocked_seconds=0
		var contact := _contact_unit()
		if is_instance_valid(contact): resolve_collision(contact)
		elif not uses_central_mass_movement() and get_slide_collision_count()>0: resolve_collision(null)
	elif commanded_run:
		_blocked_seconds+=delta
		if momentum_stacks>0 and is_instance_valid(_contact_unit()): resolve_collision(null)
		if _blocked_seconds>=.3: reset_momentum()
	if path.is_empty() or (commanded_run and travelled<.01 and not uses_central_mass_movement()): reset_momentum()

func _contact_unit() -> Node2D:
	var candidates: Array = rts_world.query_units(global_position,96) if is_instance_valid(rts_world) else get_tree().get_nodes_in_group("units")
	for other in candidates:
		# The broad scene group also includes buildings, not only mobile units.
		if other==self or not is_instance_valid(other) or not other is RTSUnit: continue
		if not other.is_alive() or other.is_banished(): continue
		if int(other.nav_level)!=nav_level or bool(other.ignores_terrain): continue
		var radius := collision_separation+float(other.collision_separation)
		if global_position.distance_squared_to(other.global_position)<=radius*radius: return other
	return null

func resolve_collision(_other: Node2D) -> void: reset_momentum()

func _fire_attack(target: Node2D, damage_multiplier: float=1.0) -> void:
	if not is_alive() or is_banished() or _is_stunned() or not is_instance_valid(target): return
	if target.has_method("is_alive") and not target.is_alive(): return
	attack_visual_age=0
	reset_momentum()
	super(target,damage_multiplier*(_flame_multiplier if is_ablaze() else 1.0))

func issue_stop_order() -> void:
	reset_momentum()
	super()

func issue_hold_position_order() -> void:
	reset_momentum()
	super()

func _die(source: Node=null) -> void:
	if _dying or _rider_spawned: return
	_rider_spawned=true
	var parent := get_parent()
	if is_instance_valid(parent):
		var rider: RTSUnit = preload("res://scenes/units/steel_knight.tscn").instantiate()
		rider.owner_player_id=owner_player_id
		rider.position=parent.to_local(global_position)
		rider.nav_level=nav_level
		rider.set_meta("dismounted_spawn",true)
		parent.add_child(rider)
		rider.nav_level=nav_level
		var build := parent.get_node_or_null("BuildSystem")
		if owner_player_id==1 and is_instance_valid(build) and build.has_method("_apply_upgrades_to_unit"):
			build._apply_upgrades_to_unit(rider)
		rider.health=maxi(1,int(ceil(rider.max_health*.5)))
		rider.arena_leash_enabled=arena_leash_enabled
		rider.arena_leash_rect=arena_leash_rect
		rider.arena_home=arena_home
		if is_instance_valid(attack_target) and attack_target.has_method("is_alive") and attack_target.is_alive():
			rider.issue_attack_target(attack_target)
		elif _has_command_destination: rider.issue_attack_move_order(_command_destination)
		if selected:
			var selection := parent.get_node_or_null("SelectionController")
			if is_instance_valid(selection):
				var chosen: Array[Node] = []
				for node in selection.selected_units:
					if is_instance_valid(node): chosen.append(rider if node==self else node)
				selection._apply_selection(chosen)
	super(source)

func _spawn_death_fx(source: Node=null) -> void:
	var art := get_node_or_null("ArtSprite") as Sprite2D
	if art==null or art.texture==null:
		super(source)
		return
	art.sync_view_facing()
	var view := get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view): view.spawn_painted_unit_death(self,art)
	else:
		var corpse := preload("res://scripts/fx/painted_unit_death.gd").new()
		get_parent().add_child(corpse)
		corpse.configure(self,art)
