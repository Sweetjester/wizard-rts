extends RTSUnit

const MAX_MOMENTUM := 5
const DISTANCE_PER_STACK := 64.0
const SPEED_PER_STACK := 0.08
const IMPACT_RADIUS := 100.0
const IMPACT_DAMAGE := 36
const LEAP_RANGE := 384.0
const LEAP_RADIUS := 112.0
const LEAP_DAMAGE := 65
const LEAP_STUN := 1.5
const LEAP_COOLDOWN := 14.0
const LEAP_WINDUP := 0.3
const LEAP_FLIGHT := 0.75
const LEAP_RECOVERY := 0.3

var momentum_stacks := 0
var momentum_distance := 0.0
var leap_remaining := 0.0
var leap_age := -1.0
var leap_height := 0.0
var leap_start := Vector2.ZERO
var leap_target := Vector2.ZERO
var leap_landed := false
var last_leap_error := ""
var _blocked_seconds := 0.0

func _ready() -> void:
	if unit_archetype != &"winged_mangler": unit_archetype = &"mangler"
	super()
	move_speed = 160.0
	selection_radius = 26.0
	collision_separation = 27.0

func _draw() -> void:
	if not has_node("ArtSprite"):
		draw_circle(Vector2.ZERO, 24.0, Color("397988"))
	_draw_selection_and_path()

func _current_move_speed() -> float:
	return super() * (1.0 + momentum_stacks * SPEED_PER_STACK)

func reset_momentum() -> void:
	momentum_stacks = 0
	momentum_distance = 0.0

func accumulate_momentum(distance: float) -> void:
	momentum_distance = minf(MAX_MOMENTUM * DISTANCE_PER_STACK, momentum_distance + maxf(0.0, distance))
	momentum_stacks = mini(MAX_MOMENTUM, int(momentum_distance / DISTANCE_PER_STACK))

func rts_movement_tick(delta: float) -> void:
	leap_remaining = maxf(0.0, leap_remaining - delta)
	if leap_age >= 0.0:
		_update_damage_over_time(delta)
		_update_temporary_status_effects()
		if not is_alive(): return
		if is_banished() or _is_stunned():
			_abort_leap()
			return
		_tick_leap(delta)
		return
	var before := global_position
	var commanded_run := not path.is_empty()
	var intended := (path[0]-before).normalized() if commanded_run else Vector2.ZERO
	super(delta)
	if not is_alive() or is_banished() or _is_stunned():
		reset_momentum()
		return
	var travelled := before.distance_to(global_position)
	# Reject teleports and idle separation. Central simulation may skip a frame,
	# so only a genuinely empty path or an actual contact counts as stopping.
	if commanded_run and travelled > 0.01 and travelled < maxf(32.0, _current_move_speed() * delta * 3.0):
		accumulate_momentum(maxf(0.0,(global_position-before).dot(intended)))
		_blocked_seconds = 0.0
		var contact := _contact_unit()
		if is_instance_valid(contact):
			resolve_collision(contact)
		elif not uses_central_mass_movement() and get_slide_collision_count() > 0:
			resolve_collision(null)
	elif commanded_run:
		_blocked_seconds += delta
		if momentum_stacks > 0:
			var contact := _contact_unit()
			if is_instance_valid(contact): resolve_collision(contact)
		if _blocked_seconds >= 0.3: reset_momentum()
	if path.is_empty() or (commanded_run and travelled < 0.01 and not uses_central_mass_movement()):
		reset_momentum()

func _contact_unit() -> Node2D:
	var candidates: Array = rts_world.query_units(global_position, 72.0) if is_instance_valid(rts_world) else get_tree().get_nodes_in_group("units")
	for other in candidates:
		if other == self or not is_instance_valid(other) or not other.is_alive() or other.is_banished(): continue
		if int(other.nav_level) != nav_level: continue
		var contact_radius := collision_separation + float(other.collision_separation)
		if global_position.distance_squared_to(other.global_position) <= contact_radius * contact_radius:
			return other
	return null

func resolve_collision(other: Node2D) -> void:
	var charged := momentum_stacks == MAX_MOMENTUM
	reset_momentum()
	if charged and is_instance_valid(other) and _is_enemy_unit(other):
		_damage_area(other.global_position, IMPACT_RADIUS, IMPACT_DAMAGE, 0.0)
		_spawn_impact(other.global_position, IMPACT_RADIUS)

func _fire_attack(target: Node2D, damage_multiplier: float = 1.0) -> void:
	if leap_age >= 0.0 or not is_alive() or is_banished() or _is_stunned() or not is_instance_valid(target): return
	var charged := momentum_stacks == MAX_MOMENTUM
	var impact_position := target.global_position
	reset_momentum()
	super(target, damage_multiplier)
	if charged:
		_damage_area(impact_position, IMPACT_RADIUS, IMPACT_DAMAGE, 0.0)
		_spawn_impact(impact_position, IMPACT_RADIUS)

func rts_combat_tick(delta: float, nearby_units: Array[Node2D]) -> void:
	if leap_age < 0.0: super(delta, nearby_units)

func issue_stop_order() -> void:
	reset_momentum()
	super()

func issue_hold_position_order() -> void:
	reset_momentum()
	super()

func _evolve(definition: Dictionary) -> void:
	reset_momentum()
	super(definition)

func _damage_area(center: Vector2, radius: float, amount: int, stun_seconds: float) -> void:
	var victims: Array = rts_world.query_enemy_units(center, radius, owner_player_id, 512) if is_instance_valid(rts_world) else get_tree().get_nodes_in_group("units")
	for victim in victims:
		if not is_instance_valid(victim) or victim == self or not _is_enemy_unit(victim): continue
		if not victim.is_alive() or victim.is_banished() or int(victim.nav_level) != nav_level: continue
		if victim.global_position.distance_squared_to(center) > radius * radius: continue
		victim.take_damage(amount, self)
		if stun_seconds > 0.0 and is_instance_valid(victim) and victim.is_alive(): victim.stun_for_seconds(stun_seconds)

func _landing_clear(point: Vector2) -> bool:
	if terrain == null or nav_level != 0: return false
	var cell: Vector2i = terrain.world_to_cell(point)
	var origin_cell: Vector2i = terrain.world_to_cell(leap_start if leap_age >= 0.0 else global_position)
	if terrain.has_method("get_height") and terrain.get_height(cell) != terrain.get_height(origin_cell): return false
	for offset in [Vector2.ZERO, Vector2(26,0), Vector2(-26,0), Vector2(0,26), Vector2(0,-26)]:
		if not terrain.is_walkable_cell(terrain.world_to_cell(point + offset)): return false
	var neighbors: Array = rts_world.query_units(point,128.0) if is_instance_valid(rts_world) else get_tree().get_nodes_in_group("units")
	for other in neighbors:
		if other == self or not is_instance_valid(other) or not other.is_alive() or other.is_banished(): continue
		if int(other.nav_level) == 0 and point.distance_to(other.global_position) < collision_separation + float(other.collision_separation): return false
	return true

func can_leap_to(point: Vector2) -> bool:
	last_leap_error = ""
	if unit_archetype != &"winged_mangler": last_leap_error = "Requires Winged Mangler"
	elif not is_alive() or is_banished() or _is_stunned(): last_leap_error = "Cannot leap in this state"
	elif leap_age >= 0.0 or leap_remaining > 0.0: last_leap_error = "Leap recovering: %.1fs" % leap_remaining
	elif global_position.distance_to(point) > LEAP_RANGE: last_leap_error = "Outside leap range"
	elif not _landing_clear(point): last_leap_error = "Needs clear, level ground"
	return last_leap_error.is_empty()

func cast_mangler_leap(point: Vector2) -> bool:
	if not can_leap_to(point): return false
	issue_stop_order()
	leap_start = global_position
	leap_target = point
	leap_age = 0.0
	leap_landed = false
	leap_remaining = LEAP_COOLDOWN
	collision_layer = 0
	collision_mask = 0
	unit_state = &"leap"
	return true

func _tick_leap(delta: float) -> void:
	leap_age += delta
	velocity = Vector2.ZERO
	moving = false
	path.clear()
	path_levels.clear()
	attack_target = null
	var t := clampf((leap_age - LEAP_WINDUP) / LEAP_FLIGHT, 0.0, 1.0)
	if not leap_landed:
		global_position = leap_start.lerp(leap_target, t)
		leap_height = sin(t * PI) * 160.0
	if t >= 1.0 and not leap_landed:
		leap_landed = true
		leap_height = 0.0
		if _landing_clear(leap_target):
			global_position = leap_target
			_damage_area(leap_target, LEAP_RADIUS, LEAP_DAMAGE, LEAP_STUN)
			_spawn_impact(leap_target, LEAP_RADIUS)
		else:
			global_position = _safe_return_point()
		collision_layer = 2
		collision_mask = 2
	if leap_age >= LEAP_WINDUP + LEAP_FLIGHT + LEAP_RECOVERY:
		leap_age = -1.0
		issue_stop_order()

func _safe_return_point() -> Vector2:
	if _landing_clear(leap_start): return leap_start
	for ring in range(1, 9):
		for step in 16:
			var point := leap_start + Vector2.from_angle(step * TAU / 16.0) * ring * 32.0
			if _landing_clear(point): return point
	return leap_start

func _abort_leap() -> void:
	global_position = _safe_return_point()
	leap_height = 0.0
	leap_age = -1.0
	collision_layer = 2
	collision_mask = 2
	issue_stop_order()

func _snap_to_walkable_terrain() -> void:
	if leap_age < 0.0: super()

func _spawn_impact(point: Vector2, radius: float) -> void:
	var fx := preload("res://scripts/fx/mangler_impact.gd").new()
	fx.radius = radius
	get_parent().add_child(fx)
	fx.global_position = point

func _spawn_death_fx(source: Node = null) -> void:
	if leap_age >= 0.0: _abort_leap()
	var art := get_node_or_null("ArtSprite") as Sprite2D
	if art == null or art.texture == null:
		super(source)
		return
	art.sync_view_facing()
	art.offset.y = -92.0
	art.set_meta("foot_anchor_y", 220.0)
	var view := get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view):
		view.spawn_painted_unit_death(self, art)
	else:
		var corpse := preload("res://scripts/fx/painted_unit_death.gd").new()
		get_parent().add_child(corpse)
		corpse.configure(self, art)
