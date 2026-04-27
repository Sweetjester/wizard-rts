class_name RTSUnit
extends CharacterBody2D

@export var move_speed: float = 180.0
@export var selection_radius: float = 24.0
@export var stop_distance: float = 3.0
@export var terrain_path: NodePath = NodePath("../MapGenerator")
@export var collision_separation: float = 18.0
@export var separation_bucket_size: float = 96.0
@export var owner_player_id: int = 1
@export var unit_archetype: StringName = &"life_treant"
@export var max_health: int = 80
@export var attack_damage: int = 8
@export var attack_range: float = 96.0
@export var attack_cooldown: float = 1.0
@export var projectile_speed: float = 620.0
@export var ignores_terrain: bool = false

static var _registered_units: Array[Node2D] = []
static var _spatial_frame := -1
static var _spatial_bucket_size := 96.0
static var _spatial_buckets: Dictionary = {}

var selected := false
var target_pos := Vector2.ZERO
var moving := false
var path: Array[Vector2] = []
var terrain: Node
var rts_world: RTSWorld
var simulation_entity_id: int = 0
var health: int = 80
var unit_state: StringName = &"idle"
var attack_target: Node2D = null
var command_mode: StringName = &"idle"
var patrol_a := Vector2.ZERO
var patrol_b := Vector2.ZERO
var _patrol_heading_to_b := true
var evolution_xp: float = 0.0
var evolution_level: int = 1
var stunned_until_msec: int = 0
var _attack_elapsed: float = 0.0
var _last_z_cell_y := 999999
var _visual_elapsed := 0.0
var _facing_sign := 1.0
var _last_melee_attack_msec: int = -10000
var _command_destination := Vector2.ZERO
var _has_command_destination := false
var _last_progress_position := Vector2.ZERO
var _stuck_elapsed := 0.0
var _last_repath_msec: int = -10000
var _last_chase_repath_msec: int = -10000
var _redraw_elapsed := 0.0
var mass_lane_offset := Vector2.ZERO
var arena_leash_enabled := false
var arena_leash_rect := Rect2()
var arena_home := Vector2.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 2
	target_pos = global_position
	_apply_catalog_definition()
	health = max_health
	terrain = get_node_or_null(terrain_path)
	rts_world = get_node_or_null("../RTSWorld")
	add_to_group("selectable_units")
	add_to_group("units")
	if rts_world != null:
		rts_world.register_unit(self)
	_register_unit(self)
	call_deferred("_snap_to_walkable_terrain")

func _exit_tree() -> void:
	if rts_world != null and is_instance_valid(rts_world):
		rts_world.unregister_unit(self)
	_unregister_unit(self)

func _process(delta: float) -> void:
	_visual_elapsed += delta
	_redraw_elapsed += delta
	var mass_mode := _mass_performance_mode()
	if selected:
		queue_redraw()
		_redraw_elapsed = 0.0
		return
	if health < max_health:
		var damaged_redraw_interval := 0.35 if mass_mode else 0.0
		if _redraw_elapsed >= damaged_redraw_interval:
			queue_redraw()
			_redraw_elapsed = 0.0
		return
	if moving or unit_state in [&"attacking", &"attack_move", &"patrol", &"hold", &"stunned"]:
		var redraw_interval := 0.22 if mass_mode else 0.0
		if _redraw_elapsed >= redraw_interval:
			queue_redraw()
			_redraw_elapsed = 0.0

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func is_inside_selection_rect(rect: Rect2) -> bool:
	return rect.has_point(global_position)

func issue_move_order(world_pos: Vector2) -> void:
	attack_target = null
	command_mode = &"move"
	unit_state = &"moving"
	_set_path_to_world(world_pos, true)
	queue_redraw()

func issue_move_order_offset(world_pos: Vector2, offset: Vector2) -> void:
	issue_move_order(world_pos + offset)

func issue_shared_path_order(shared_path: Array[Vector2], offset: Vector2) -> void:
	attack_target = null
	command_mode = &"move"
	unit_state = &"moving"
	path.clear()
	if shared_path.is_empty():
		moving = false
		_has_command_destination = false
		return
	var final_target := _legal_destination(shared_path[shared_path.size() - 1] + offset)
	_command_destination = final_target
	_has_command_destination = true
	path = _joined_shared_path(shared_path, final_target)
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
		_reset_stuck_watch()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _is_stunned():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_update_z_index()
	if arena_leash_enabled and not arena_leash_rect.has_point(global_position):
		_pull_back_to_arena()
	if path.is_empty():
		_reset_stuck_watch()
		velocity = Vector2.ZERO if _mass_performance_mode() else _separation_velocity()
		moving = false
		if command_mode == &"patrol" and attack_target == null:
			_resume_patrol_leg()
		elif attack_target == null and command_mode == &"hold":
			unit_state = &"hold"
		elif attack_target == null and command_mode == &"attack_move":
			unit_state = &"attack_move"
		elif attack_target == null:
			unit_state = &"idle"
		if not _mass_performance_mode():
			move_and_slide()
		return

	target_pos = path[0]
	_advance_path_lookahead()
	if path.is_empty():
		_reset_stuck_watch()
		moving = false
		return
	target_pos = path[0]
	var dir := target_pos - global_position
	if absf(dir.x) > 0.5:
		_facing_sign = signf(dir.x)
	var step := move_speed * delta
	if dir.length() <= max(stop_distance, step):
		global_position = target_pos
		velocity = Vector2.ZERO
		path.pop_front()
		moving = not path.is_empty()
		if not moving:
			if command_mode == &"patrol":
				_resume_patrol_leg()
			elif command_mode == &"attack_move":
				unit_state = &"attack_move"
			else:
				unit_state = &"idle"
		queue_redraw()
		return

	var mass_mode := _mass_performance_mode()
	velocity = dir.normalized() * move_speed + (Vector2.ZERO if mass_mode else _separation_velocity(dir.normalized()))
	if mass_mode:
		global_position += velocity * delta
	else:
		move_and_slide()
	_update_stuck_recovery(delta)

func issue_attack_target(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	attack_target = target
	command_mode = &"attack_target"
	_has_command_destination = false
	path.clear()
	moving = false
	unit_state = &"attacking"

func issue_attack_move_order(world_pos: Vector2) -> void:
	issue_move_order(world_pos)
	command_mode = &"attack_move"
	unit_state = &"attack_move"

func issue_patrol_order(world_pos: Vector2) -> void:
	attack_target = null
	command_mode = &"patrol"
	patrol_a = global_position
	patrol_b = world_pos
	_patrol_heading_to_b = true
	_set_path_to_world(patrol_b, true)
	unit_state = &"patrol"

func issue_hold_position_order() -> void:
	attack_target = null
	command_mode = &"hold"
	_has_command_destination = false
	path.clear()
	moving = false
	velocity = Vector2.ZERO
	unit_state = &"hold"
	queue_redraw()

func issue_stop_order() -> void:
	attack_target = null
	command_mode = &"idle"
	_has_command_destination = false
	path.clear()
	moving = false
	velocity = Vector2.ZERO
	unit_state = &"idle"
	queue_redraw()

func rts_combat_tick(delta: float, nearby_units: Array[Node2D]) -> void:
	if health <= 0 or _is_stunned():
		return
	_attack_elapsed += delta
	if attack_target != null and (not is_instance_valid(attack_target) or not _is_enemy_unit(attack_target)):
		attack_target = null
	if attack_target == null:
		attack_target = _find_nearest_enemy(nearby_units)
	if attack_target == null:
		return
	var distance := global_position.distance_to(attack_target.global_position)
	if distance > attack_range:
		if command_mode == &"hold":
			return
		if unit_state == &"attacking" or command_mode in [&"attack_move", &"attack_target", &"patrol"]:
			_chase_attack_target()
		return
	path.clear()
	moving = false
	unit_state = &"attacking"
	if _attack_elapsed < attack_cooldown:
		return
	_attack_elapsed = 0.0
	if attack_target.has_method("take_damage"):
		var weapon := WeaponCatalog.get_weapon(unit_archetype)
		var casts := int(weapon.get("casts", 2 if bool(UnitCatalog.get_definition(unit_archetype).get("dual_cast", false)) else 1))
		for _i in casts:
			if is_instance_valid(attack_target):
				_fire_attack(attack_target)
				_gain_evolution_xp(float(attack_damage) * 0.6)
		var heal := int(UnitCatalog.get_definition(unit_archetype).get("heal_per_attack", 0))
		if heal > 0:
			heal_damage(heal)

func _chase_attack_target() -> void:
	if attack_target == null:
		return
	var now := Time.get_ticks_msec()
	var repath_interval := 850 if _mass_performance_mode() else 300
	if moving and now - _last_chase_repath_msec < repath_interval:
		return
	_last_chase_repath_msec = now
	var chase_target := attack_target.global_position
	if arena_leash_enabled:
		chase_target = _clamp_to_arena(chase_target)
	_command_destination = _legal_destination(chase_target)
	_has_command_destination = true
	if ignores_terrain or terrain == null:
		path = [_command_destination]
	else:
		path = terrain.find_path_world(global_position, _command_destination)
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
		_reset_stuck_watch()
	unit_state = &"attacking"

func _set_path_to_world(world_pos: Vector2, track_destination: bool = false) -> void:
	var legal_target := _legal_destination(world_pos)
	if track_destination:
		_command_destination = legal_target
		_has_command_destination = true
	if ignores_terrain or terrain == null:
		path = [legal_target]
	else:
		path = terrain.find_path_world(global_position, legal_target)
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
		_reset_stuck_watch()

func _legal_destination(world_pos: Vector2) -> Vector2:
	if ignores_terrain or terrain == null or not terrain.has_method("world_to_cell") or not terrain.has_method("is_walkable_cell"):
		return world_pos
	var target_cell: Vector2i = terrain.world_to_cell(world_pos)
	if terrain.is_walkable_cell(target_cell):
		return terrain.cell_to_world(target_cell)
	if terrain.has_method("nearest_walkable_cell"):
		var legal_cell: Vector2i = terrain.nearest_walkable_cell(target_cell, 12)
		if terrain.is_walkable_cell(legal_cell):
			return terrain.cell_to_world(legal_cell)
	return world_pos

func _joined_shared_path(shared_path: Array[Vector2], final_target: Vector2) -> Array[Vector2]:
	if shared_path.is_empty():
		return []
	if ignores_terrain or terrain == null or not terrain.has_method("find_path_world"):
		return _dedupe_path([final_target])
	var join_limit: int = mini(shared_path.size(), 8)
	for join_index in join_limit:
		var join_path: Array[Vector2] = []
		for point in terrain.find_path_world(global_position, shared_path[join_index]):
			join_path.append(point)
		if join_path.is_empty():
			continue
		for i in range(join_index + 1, shared_path.size()):
			join_path.append(shared_path[i])
		if not join_path.is_empty():
			join_path[join_path.size() - 1] = final_target
		return _dedupe_path(join_path)
	return _world_path_to(final_target)

func _world_path_to(world_pos: Vector2) -> Array[Vector2]:
	var target := _legal_destination(world_pos)
	if ignores_terrain or terrain == null or not terrain.has_method("find_path_world"):
		return [target]
	var world_path: Array[Vector2] = []
	for point in terrain.find_path_world(global_position, target):
		world_path.append(point)
	return _dedupe_path(world_path)

func _dedupe_path(points: Array[Vector2]) -> Array[Vector2]:
	var clean: Array[Vector2] = []
	for point in points:
		if clean.is_empty() or clean[clean.size() - 1].distance_squared_to(point) > 9.0:
			clean.append(point)
	return clean

func _reset_stuck_watch() -> void:
	_last_progress_position = global_position
	_stuck_elapsed = 0.0

func _update_stuck_recovery(delta: float) -> void:
	if ignores_terrain or terrain == null or path.is_empty():
		_reset_stuck_watch()
		return
	if global_position.distance_squared_to(_last_progress_position) > 36.0:
		_reset_stuck_watch()
		return
	if global_position.distance_squared_to(target_pos) <= 144.0:
		_reset_stuck_watch()
		return
	_stuck_elapsed += delta
	if _stuck_elapsed < 0.65:
		return
	var now := Time.get_ticks_msec()
	if now - _last_repath_msec < 650:
		return
	_last_repath_msec = now
	_recover_from_stuck()

func _recover_from_stuck() -> void:
	_reset_stuck_watch()
	_nudge_to_walkable_cell()
	if _has_command_destination:
		path = _world_path_to(_command_destination)
	elif not path.is_empty():
		path = _world_path_to(path[path.size() - 1])
	if path.is_empty():
		path = _escape_path_to_neighbor()
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
	else:
		velocity = Vector2.ZERO

func _nudge_to_walkable_cell() -> void:
	if terrain == null or not terrain.has_method("world_to_cell") or not terrain.has_method("is_walkable_cell") or not terrain.has_method("nearest_walkable_cell"):
		return
	var cell: Vector2i = terrain.world_to_cell(global_position)
	if terrain.is_walkable_cell(cell):
		return
	var legal_cell: Vector2i = terrain.nearest_walkable_cell(cell, 4)
	if terrain.is_walkable_cell(legal_cell):
		global_position = terrain.cell_to_world(legal_cell)

func _escape_path_to_neighbor() -> Array[Vector2]:
	var escape: Array[Vector2] = []
	if terrain == null or not terrain.has_method("world_to_cell") or not terrain.has_method("is_walkable_cell"):
		return escape
	var origin: Vector2i = terrain.world_to_cell(global_position)
	for radius in range(1, 4):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				if abs(x - origin.x) != radius and abs(y - origin.y) != radius:
					continue
				var cell := Vector2i(x, y)
				if not terrain.is_walkable_cell(cell):
					continue
				if terrain.has_method("_has_clear_path_segment") and not terrain.call("_has_clear_path_segment", origin, cell):
					continue
				escape.append(terrain.cell_to_world(cell))
				return escape
	return escape

func _resume_patrol_leg() -> void:
	_patrol_heading_to_b = not _patrol_heading_to_b
	_set_path_to_world(patrol_b if _patrol_heading_to_b else patrol_a, true)
	unit_state = &"patrol"

func _fire_attack(target: Node2D) -> void:
	if _uses_projectile():
		_spawn_projectile(target)
	else:
		_last_melee_attack_msec = Time.get_ticks_msec()
		queue_redraw()
		target.take_damage(attack_damage, self)

func _uses_projectile() -> bool:
	return WeaponCatalog.uses_projectile(unit_archetype)

func _spawn_projectile(target: Node2D) -> void:
	var origin := global_position + Vector2(0, -12)
	if rts_world != null and is_instance_valid(rts_world):
		var weapon := WeaponCatalog.get_weapon(unit_archetype)
		var projectile := rts_world.spawn_projectile(self, target, int(weapon.get("damage", attack_damage)), weapon.get("color", _projectile_color()), float(weapon.get("speed", projectile_speed)), origin)
		projectile.set_aoe_radius(float(weapon.get("aoe_radius", 0.0)))
		return
	var projectile := RtsProjectile.new()
	projectile.configure(self, target, attack_damage, _projectile_color(), projectile_speed)
	get_parent().add_child(projectile)
	projectile.global_position = origin

func _projectile_color() -> Color:
	match unit_archetype:
		&"horror":
			return Color("#7DDDE8")
		&"apex":
			return Color("#7BC47F")
		&"life_wizard":
			return Color("#7DDDE8")
		&"fire_wizard":
			return Color("#E85A5A")
		&"evangalion_wizard":
			return Color("#7DDDE8")
	return Color("#D6C7AE")

func take_damage(amount: int, source: Node = null) -> void:
	var actual_damage: int = mini(amount, health)
	if rts_world != null and is_instance_valid(rts_world):
		rts_world.record_damage(source, self, actual_damage)
	health = maxi(0, health - amount)
	_gain_evolution_xp(float(amount) * 0.35)
	queue_redraw()
	if health <= 0:
		queue_free()

func is_alive() -> bool:
	return health > 0

func heal_damage(amount: int) -> void:
	health = mini(max_health, health + amount)
	queue_redraw()

func stun_for_seconds(seconds: float) -> void:
	stunned_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	path.clear()
	moving = false
	unit_state = &"stunned"
	queue_redraw()

func salvage_value() -> int:
	return int(float(UnitCatalog.cost_bio(unit_archetype)) * 0.6) + int(float(max_health) * 0.12)

func _gain_evolution_xp(amount: float) -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var needed := float(definition.get("evolution_xp_required", 0.0))
	if needed <= 0.0:
		return
	evolution_xp += amount
	while evolution_xp >= needed:
		evolution_xp -= needed
		_evolve(definition)
		definition = UnitCatalog.get_definition(unit_archetype)
		needed = float(definition.get("evolution_xp_required", 0.0))
		if needed <= 0.0:
			break

func _evolve(definition: Dictionary) -> void:
	var evolves_to: StringName = definition.get("evolves_to", &"")
	if not str(evolves_to).is_empty():
		unit_archetype = evolves_to
	_apply_catalog_definition()
	evolution_level += 1
	max_health = int(float(max_health) * (1.18 + float(evolution_level) * 0.03))
	health = max_health
	move_speed += float(definition.get("evolution_speed_bonus", 0.0))
	attack_damage = int(float(attack_damage) * 1.15)
	queue_redraw()

func _is_stunned() -> bool:
	if stunned_until_msec <= 0:
		return false
	if Time.get_ticks_msec() <= stunned_until_msec:
		return true
	stunned_until_msec = 0
	if unit_state == &"stunned":
		unit_state = &"idle"
	return false

func _is_enemy_unit(other: Node) -> bool:
	return other != self and other is Node2D and other.get("owner_player_id") != owner_player_id and other.has_method("take_damage")

func _find_nearest_enemy(units: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for unit in units:
		if not is_instance_valid(unit) or not _is_enemy_unit(unit):
			continue
		var distance := global_position.distance_squared_to(unit.global_position)
		var score := distance / maxf(0.1, _target_priority(unit))
		if score < best_score:
			best = unit
			best_score = score
	return best

func _target_priority(unit: Node) -> float:
	if owner_player_id != 2:
		return 1.0
	if unit.has_method("get_selection_kind") and unit.get_selection_kind() == &"structure":
		var archetype := str(unit.get("archetype"))
		if archetype == "wizard_tower":
			return 8.0
		if archetype == "bio_launcher":
			return 5.5
		if archetype == "bio_absorber":
			return 4.0
		return 3.0
	return 1.25

func _apply_catalog_definition() -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	if definition.is_empty():
		return
	max_health = int(definition.get("max_hp", max_health))
	attack_damage = int(definition.get("attack_damage", attack_damage))
	attack_range = float(definition.get("attack_range_cells", 1)) * 64.0
	attack_cooldown = float(definition.get("attack_cooldown_ticks", 20)) / 20.0
	projectile_speed = float(definition.get("projectile_speed", projectile_speed))
	ignores_terrain = bool(definition.get("ignores_terrain", false))

func _separation_velocity(move_dir: Vector2 = Vector2.ZERO) -> Vector2:
	if _mass_performance_mode():
		return Vector2.ZERO
	var push := Vector2.ZERO
	for unit in _nearby_units():
		if unit == self or not (unit is Node2D):
			continue
		var delta: Vector2 = global_position - unit.global_position
		var distance: float = delta.length()
		if distance <= 0.01 or distance >= collision_separation:
			continue
		var weight := 8.0
		if move_dir != Vector2.ZERO and delta.normalized().dot(move_dir) < -0.35:
			weight = 3.0
		push += delta.normalized() * (collision_separation - distance) * weight
	return push.limit_length(move_speed * 0.42)

func _advance_path_lookahead() -> void:
	if terrain == null or path.size() < 3 or not terrain.has_method("world_to_cell") or not terrain.has_method("_has_clear_path_segment"):
		return
	var current_cell: Vector2i = terrain.world_to_cell(global_position)
	var best_index := 0
	var limit: int = mini(path.size() - 1, 4)
	for i in range(limit, 0, -1):
		var cell: Vector2i = terrain.world_to_cell(path[i])
		if terrain.call("_has_clear_path_segment", current_cell, cell):
			best_index = i
			break
	for i in best_index:
		path.pop_front()

func _update_z_index() -> void:
	var cell_y := int(global_position.y / 8.0)
	if cell_y == _last_z_cell_y:
		return
	_last_z_cell_y = cell_y
	z_index = int(global_position.y)

func _nearby_units() -> Array[Node2D]:
	_rebuild_spatial_buckets_if_needed()
	var nearby: Array[Node2D] = []
	var bucket := _bucket_for_position(global_position)
	for x in range(bucket.x - 1, bucket.x + 2):
		for y in range(bucket.y - 1, bucket.y + 2):
			var key := Vector2i(x, y)
			if _spatial_buckets.has(key):
				nearby.append_array(_spatial_buckets[key])
	return nearby

static func _register_unit(unit: Node2D) -> void:
	if not _registered_units.has(unit):
		_registered_units.append(unit)
	_spatial_frame = -1

static func _unregister_unit(unit: Node2D) -> void:
	_registered_units.erase(unit)
	_spatial_frame = -1

static func _rebuild_spatial_buckets_if_needed() -> void:
	var frame := Engine.get_physics_frames()
	if _spatial_frame == frame:
		return
	_spatial_frame = frame
	_spatial_buckets.clear()
	for unit in _registered_units:
		if not is_instance_valid(unit):
			continue
		var key := _bucket_for_position(unit.global_position)
		if not _spatial_buckets.has(key):
			_spatial_buckets[key] = []
		_spatial_buckets[key].append(unit)

static func _bucket_for_position(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / _spatial_bucket_size), floori(position.y / _spatial_bucket_size))

func _snap_to_walkable_terrain() -> void:
	if ignores_terrain:
		return
	if terrain == null:
		return
	var cell: Vector2i = terrain.world_to_cell(global_position)
	if terrain.is_walkable_cell(cell):
		return
	var spawn: Vector2i = terrain.get_spawn_position()
	var walkable_spawn: Vector2i = terrain.nearest_walkable_cell(spawn)
	if terrain.is_walkable_cell(walkable_spawn):
		global_position = terrain.cell_to_world(walkable_spawn)
		target_pos = global_position

func _draw_selection_and_path() -> void:
	_draw_sprite_shadow()
	_draw_melee_swing_fx()
	var mass_mode := _mass_performance_mode()
	var hide_mass_health := mass_mode and rts_world != null and is_instance_valid(rts_world) and rts_world.count_units_all() >= 600
	if selected or not hide_mass_health and (health < max_health or not mass_mode):
		_draw_health_bar()
	if not selected:
		return
	draw_arc(Vector2(0, 10), selection_radius, 0, TAU, 40, Color(0.25, 0.95, 1.0), 2.5)
	if path.is_empty():
		return
	var previous := Vector2.ZERO
	for point in path:
		var local_point := to_local(point)
		draw_line(previous, local_point, Color(0.25, 0.95, 1.0, 0.55), 2.0)
		previous = local_point
	draw_circle(to_local(path[path.size() - 1]), 5.0, Color(0.25, 0.95, 1.0, 0.8))

func _draw_sprite_shadow() -> void:
	if _mass_performance_mode() and not selected:
		return
	if not has_node("ArtSprite"):
		return
	var radius := maxf(12.0, selection_radius * 0.72)
	var points := PackedVector2Array()
	for i in 20:
		var angle := float(i) * TAU / 20.0
		points.append(Vector2(cos(angle) * radius, 10.0 + sin(angle) * radius * 0.28))
	draw_colored_polygon(points, Color(0, 0, 0, 0.28))

func _draw_unit_transform_begin() -> void:
	var bob := 0.0
	var squash := 1.0
	if moving:
		bob = sin(_visual_elapsed * 12.0) * 2.0
		squash = 1.0 + sin(_visual_elapsed * 12.0) * 0.04
	elif unit_state == &"attacking":
		bob = -absf(sin(_visual_elapsed * 18.0)) * 3.0
		squash = 1.0 + absf(sin(_visual_elapsed * 18.0)) * 0.08
	elif unit_state == &"hold":
		squash = 1.04
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(_facing_sign, squash))

func _draw_unit_transform_end() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_health_bar() -> void:
	var ratio := 1.0
	if max_health > 0:
		ratio = clampf(float(health) / float(max_health), 0.0, 1.0)
	var width := 38.0
	var y := -42.0
	var fill := Color("#7BC47F") if owner_player_id == 1 else Color("#C13030")
	if ratio < 0.35:
		fill = Color("#E85A5A")
	draw_rect(Rect2(Vector2(-width * 0.5 - 1.0, y - 1.0), Vector2(width + 2.0, 5.0)), Color("#0A1612", 0.85), true)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width * ratio, 3.0)), fill, true)
	if unit_state == &"hold":
		draw_line(Vector2(-12, y - 5), Vector2(12, y - 5), Color("#D6C7AE", 0.9), 2.0)
	elif command_mode == &"patrol":
		draw_arc(Vector2(0, y - 6), 6.0, 0.3, TAU - 0.3, 16, Color("#7DDDE8", 0.85), 1.5)
	elif command_mode == &"attack_move":
		draw_line(Vector2(-7, y - 7), Vector2(7, y - 3), Color("#E85A5A", 0.9), 1.5)
		draw_line(Vector2(7, y - 7), Vector2(-7, y - 3), Color("#E85A5A", 0.9), 1.5)

func _mass_performance_mode() -> bool:
	if terrain != null and str(terrain.get("map_type_id")) == "ai_testing_ground":
		return rts_world == null or not is_instance_valid(rts_world) or rts_world.count_units_all() >= 120
	return rts_world != null and is_instance_valid(rts_world) and rts_world.count_units_all() >= 360

func set_arena_leash(rect: Rect2, home: Vector2) -> void:
	arena_leash_enabled = true
	arena_leash_rect = rect
	arena_home = home

func _pull_back_to_arena() -> void:
	var return_target := _clamp_to_arena(global_position)
	if return_target.distance_squared_to(global_position) < 4.0:
		return_target = arena_home
	attack_target = null
	command_mode = &"attack_move"
	unit_state = &"attack_move"
	_set_path_to_world(return_target, true)

func _clamp_to_arena(point: Vector2) -> Vector2:
	if not arena_leash_enabled:
		return point
	return Vector2(
		clampf(point.x, arena_leash_rect.position.x, arena_leash_rect.end.x),
		clampf(point.y, arena_leash_rect.position.y, arena_leash_rect.end.y)
	)

func _draw_melee_swing_fx() -> void:
	if _uses_projectile():
		return
	var elapsed := float(Time.get_ticks_msec() - _last_melee_attack_msec) / 1000.0
	if elapsed < 0.0 or elapsed > 0.22:
		return
	var alpha := 1.0 - elapsed / 0.22
	var side := _facing_sign
	var center := Vector2(18.0 * side, -5.0)
	draw_arc(center, 18.0, -1.3 if side > 0.0 else PI - 1.8, 1.0 if side > 0.0 else PI + 1.3, 18, Color("#D6C7AE", 0.75 * alpha), 3.0)
	draw_line(Vector2(4.0 * side, -4), Vector2(25.0 * side, -14), Color("#E85A5A", 0.65 * alpha), 2.0)
