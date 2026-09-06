extends "res://scripts/units/steel_force_unit.gd"

const CAPACITY := 3
var passengers: Array[RTSUnit] = []
var landed := false
var visual_lift := 90.0
var last_transport_error := ""
var _crew_visuals: Array[Sprite2D] = []
var _crew_3d: Array[Sprite3D] = []
var _view: Node

func _ready() -> void:
	super()
	move_speed = 110
	collision_separation = 38
	ignores_terrain = true
	_view = get_parent().get_node_or_null("Map3DView")
	for i in CAPACITY:
		var crew := Sprite2D.new()
		crew.texture = load("res://assets_game/units/steel_force/painted_v1/poorper_portrait.png")
		crew.scale = Vector2.ONE*0.11
		crew.position = Vector2(-30+i*28,-100)
		crew.visible = false
		add_child(crew)
		_crew_visuals.append(crew)
		if is_instance_valid(_view):
			var marker := Sprite3D.new()
			marker.texture = crew.texture
			marker.pixel_size = 0.0019
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.visible = false
			_view.add_child(marker)
			_crew_3d.append(marker)

func _current_move_speed() -> float:
	return 0.0 if landed else super()

func _ground_clear(point: Vector2, radius: float, reserved: Array[Vector2] = []) -> bool:
	if terrain == null: return false
	for offset in [Vector2.ZERO,Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(-radius,radius),Vector2(radius,radius)]:
		var cell: Vector2i = terrain.world_to_cell(point+offset)
		if not terrain.is_walkable_cell(cell): return false
		if terrain.get_height(cell) != terrain.get_height(terrain.world_to_cell(point)): return false
	for used in reserved:
		if used.distance_to(point)<radius*2+4: return false
	for unit in get_tree().get_nodes_in_group("units"):
		if not unit is RTSUnit: continue
		if unit == self or not is_instance_valid(unit) or unit.is_banished() or not unit.is_alive(): continue
		if point.distance_to(unit.global_position)<radius+float(unit.collision_separation): return false
	return true

func activate_land() -> bool:
	if landed or is_banished() or _is_stunned() or not is_alive(): return false
	if not _ground_clear(global_position,38):
		last_transport_error = "Landing area is blocked"
		return false
	issue_stop_order()
	landed = true
	ignores_terrain = false
	nav_level = terrain.get_height(terrain.world_to_cell(global_position))
	return true

func activate_takeoff() -> bool:
	if not landed or is_banished() or _is_stunned() or not is_alive(): return false
	landed = false
	ignores_terrain = true
	return true

func board(unit: RTSUnit) -> bool:
	if not landed or not is_alive() or is_banished() or _is_stunned(): return false
	if passengers.size() >= CAPACITY or not is_instance_valid(unit) or passengers.has(unit): return false
	if unit.unit_archetype != &"poorper" or unit.owner_player_id != owner_player_id or not unit.is_alive() or unit.is_banished() or unit._is_stunned(): return false
	if global_position.distance_to(unit.global_position)>130 or unit.nav_level != nav_level: return false
	unit.issue_stop_order()
	unit.set_selected(false)
	unit.embarked = true
	# Reuse the shared non-interactable visibility/query exclusion, without a banish timer.
	unit.set_meta("kon_banished",true)
	unit.set_meta("steel_transport",get_instance_id())
	unit.collision_layer = 0
	unit.collision_mask = 0
	unit.remove_from_group("selectable_units")
	unit.hide()
	passengers.append(unit)
	return true

func activate_board_nearby() -> bool:
	var count := passengers.size()
	for unit in get_tree().get_nodes_in_group("units"):
		if unit is RTSUnit: board(unit)
	return passengers.size()>count

func activate_unload() -> bool:
	if not landed or not is_alive() or is_banished() or _is_stunned(): return false
	var reserved: Array[Vector2] = []
	var unloaded := false
	for unit in passengers.duplicate():
		if not is_instance_valid(unit): passengers.erase(unit); continue
		for index in 16:
			var point := global_position+Vector2.from_angle(index*TAU/16)*105
			if terrain.get_height(terrain.world_to_cell(point)) != nav_level: continue
			if not _ground_clear(point,unit.collision_separation,reserved): continue
			reserved.append(point)
			unit.global_position = point
			unit.nav_level = terrain.get_height(terrain.world_to_cell(point))
			unit.embarked = false
			unit.set_meta("kon_banished",false)
			unit.remove_meta("steel_transport")
			unit.collision_layer = 2
			unit.collision_mask = 2
			unit.add_to_group("selectable_units")
			unit.visible = not (is_instance_valid(rts_world) and rts_world.presentation_3d)
			unit.issue_stop_order()
			passengers.erase(unit)
			unloaded = true
			break
	last_transport_error = "No clear space for remaining passengers" if not passengers.is_empty() else ""
	return unloaded

func rts_movement_tick(delta: float) -> void:
	if landed:
		issue_stop_order()
	visual_lift = move_toward(visual_lift,0.0 if landed else 90.0,delta*90)
	super(delta)
	for unit in passengers:
		if is_instance_valid(unit): unit.global_position = global_position
	for i in _crew_visuals.size():
		_crew_visuals[i].visible = i<passengers.size() and not is_banished()
		_crew_visuals[i].position.y = -100-visual_lift
		if i<_crew_3d.size():
			var fog: Node = _view.get("fog_of_war")
			_crew_3d[i].visible = i<passengers.size() and not is_banished() and (fog==null or fog.is_world_position_visible(global_position))
			_crew_3d[i].global_transform = _view._unit_transform(self,1.4+visual_lift/64.0)
			_crew_3d[i].position.x += (i-1)*0.45

func rts_combat_tick(delta: float, nearby_units: Array[Node2D]) -> void:
	if landed or passengers.is_empty(): return
	super(delta,nearby_units)

func _fire_attack(target: Node2D, damage_multiplier: float = 1.0) -> void:
	if landed or passengers.is_empty(): return
	super(target,damage_multiplier)

func _die(source: Node = null) -> void:
	if _dying: return
	# No arbitrary teleport rescue: passengers are lost with a destroyed carrier.
	for unit in passengers:
		if is_instance_valid(unit):
			unit.health = 0
			unit.queue_free()
	passengers.clear()
	super(source)

func _exit_tree() -> void:
	for marker in _crew_3d:
		if is_instance_valid(marker): marker.queue_free()
	for unit in passengers:
		if is_instance_valid(unit): unit.queue_free()
	super()
