class_name WaveDirector
extends Node

signal phase_changed(phase: StringName)
signal wave_spawned(wave_index: int, count: int)
signal boss_spawned()
signal boss_defeated()

@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var enemy_scene: PackedScene = preload("res://scenes/units/deom_legion_unit.tscn")
@export var terrible_thing_scene: PackedScene = preload("res://scenes/units/terrible_thing.tscn")
@export var oaven_spear_scene: PackedScene = preload("res://scenes/units/oaven_spear.tscn")
@export var horror_scene: PackedScene = preload("res://scenes/units/horror.tscn")
@export var apex_scene: PackedScene = preload("res://scenes/units/apex.tscn")
@export var spawner_scene: PackedScene = preload("res://scenes/units/spawner.tscn")
@export var stone_face_serpent_scene: PackedScene = preload("res://scenes/units/stone_face_serpent.tscn")
@export var deom_legion_scene: PackedScene = preload("res://scenes/units/deom_legion_unit.tscn")
@export var enabled: bool = true
# Who attacks you. The Deom Legion is still here, still spawnable by archetype
# and still covered by its own smoke test -- it is just no longer what a normal
# run fields. Switch this back to "deom" to restore the old waves.
@export_enum("deom", "steel_force") var enemy_faction: String = "steel_force"
# A settling period at the start of a run before the wave clock starts at all.
# Everything downstream -- phases, waves and the boss -- is measured from the end
# of it, so raising this pushes the whole schedule back rather than compressing
# the gap between the first wave and the boss. Applies to both the 2D and the 3D
# presentation, because both run this same director.
@export var grace_period_seconds: float = 180.0
@export var scouting_seconds: float = 45.0
@export var buildup_seconds: float = 135.0
@export var first_wave_seconds: float = 50.0
@export var wave_interval_seconds: float = 32.0
@export var boss_arrival_seconds: float = 240.0
@export var base_wave_size: int = 6
@export var wave_size_growth: int = 3
@export var max_active_enemies: int = 120
@export var retarget_interval: float = 2.0
@export var max_retargets_per_tick: int = 12
@export var ai_test_spawn_budget_per_frame: int = 48
@export var ai_test_min_spawn_budget_per_frame: int = 8
@export var ai_test_spawn_queue_limit: int = 3600
@export var ai_test_live_unit_soft_cap: int = 3200
@export var ai_test_spawn_pause_fps: float = 28.0
@export var ai_test_spawn_slow_fps: float = 45.0
@export var combat_debug_logging: bool = false
# Strips Arena 2.0's units back to the original arena's lightweight form. Off in
# normal use -- the whole point of this map is the real units -- and switched on
# by the profiling tool to separate presentation cost from simulation cost.
@export var arena_2_force_lightweight: bool = false

var map_generator: Node
var rts_world: RTSWorld
var phase: StringName = &"grace"
var elapsed := 0.0
var next_wave_at := 75.0
var wave_index := 0
var boss_has_spawned := false
var boss_has_been_defeated := false
var boss_node: Node = null
var _retarget_elapsed := 0.0
var ai_test_wave_index := 0
var _ai_test_spawn_queue: Array[Dictionary] = []
var _ai_test_units_spawned_this_second := 0
var _ai_test_spawn_meter_elapsed := 0.0
var _ai_test_last_units_spawned_per_second := 0
var _ai_test_spawn_second_budget_remaining := 0

func _ready() -> void:
	map_generator = get_node_or_null(map_generator_path)
	rts_world = get_node_or_null(rts_world_path)
	next_wave_at = first_wave_seconds
	_force_ai_test_mode_if_needed()

func _process(delta: float) -> void:
	_force_ai_test_mode_if_needed()
	if is_build_sandbox():
		_process_target_dummies()
	# Nothing attacks you in the build sandbox. It exists so buildings can be
	# laid out and looked at, and a wave arriving mid-layout is not a feature.
	#
	# Asked here rather than in _ready: the map type is read from GameSession
	# during MapGenerator._ready, which may not have run when this node is ready.
	# Checking too early found an empty string and left waves switched on.
	if is_build_sandbox():
		enabled = false
		return
	if is_ai_testing_ground():
		_update_ai_test_spawn_queue(delta)
	if not enabled:
		return
	elapsed += delta
	_update_phase()
	# Nothing hostile happens during the grace period. Measuring waves, phases
	# and the boss from combat_elapsed rather than from elapsed keeps their
	# relative spacing exactly as tuned.
	var combat_elapsed := combat_time_elapsed()
	if combat_elapsed >= next_wave_at:
		_spawn_wave()
		next_wave_at += wave_interval_seconds
	if not boss_has_spawned and combat_elapsed >= boss_arrival_seconds:
		_spawn_boss()
	if boss_has_spawned and not boss_has_been_defeated and (boss_node == null or not is_instance_valid(boss_node)):
		boss_has_been_defeated = true
		phase = &"victory"
		phase_changed.emit(phase)
		boss_defeated.emit()
	_retarget_elapsed += delta
	if _retarget_elapsed >= retarget_interval:
		_retarget_enemy_army()
		_retarget_elapsed = 0.0

# Seconds of hostile time so far: zero until the grace period is over.
func combat_time_elapsed() -> float:
	return maxf(0.0, elapsed - grace_period_seconds)

func is_in_grace_period() -> bool:
	return elapsed < grace_period_seconds

func get_grace_seconds_remaining() -> int:
	return maxi(0, ceili(grace_period_seconds - elapsed))

func _update_phase() -> void:
	var next_phase := phase
	if is_in_grace_period():
		next_phase = &"grace"
	elif combat_time_elapsed() >= scouting_seconds + buildup_seconds:
		next_phase = &"offense"
	elif combat_time_elapsed() >= scouting_seconds:
		next_phase = &"buildup"
	else:
		next_phase = &"scouting"
	if next_phase != phase:
		phase = next_phase
		phase_changed.emit(phase)

func _spawn_wave() -> void:
	if map_generator == null or enemy_scene == null:
		return
	var active := rts_world.count_units_for_owner(2) if rts_world != null else _count_enemy_units_fallback()
	if active >= max_active_enemies:
		return
	wave_index += 1
	var spawn_count: int = mini(base_wave_size + wave_index * wave_size_growth, max_active_enemies - active)
	var spawns: Array = map_generator.get("enemy_spawns")
	if spawns.is_empty():
		return
	var target := _player_target_world()
	for i in spawn_count:
		var spawn_cell: Vector2i = _pathable_spawn_cell(spawns, target, i * 17 + wave_index * 11)
		_spawn_enemy(_enemy_archetype_for_wave(i), spawn_cell, get_parent(), target)
	wave_spawned.emit(wave_index, spawn_count)

func _spawn_boss() -> void:
	if map_generator == null or enemy_scene == null:
		return
	if boss_has_spawned:
		return
	boss_has_spawned = true
	var spawns: Array = map_generator.get("enemy_spawns")
	if spawns.is_empty():
		return
	var target := _player_target_world()
	var spawn_cell: Vector2i = _pathable_spawn_cell(spawns, target, wave_index * 19 + 5)
	boss_node = _spawn_enemy(&"mycelium_boss", spawn_cell, get_parent(), target)
	boss_spawned.emit()

func trigger_boss_now(reason: String = "manual") -> bool:
	if boss_has_spawned or boss_has_been_defeated:
		return false
	print("[WaveDirector] Boss triggered now. reason=", reason)
	_spawn_boss()
	return boss_has_spawned

func is_build_sandbox() -> bool:
	return map_generator != null and str(map_generator.get("map_type_id")) == "build_sandbox"

# Kon's Arena 2.0 counts as a testing ground, which is what gives it the whole
# existing harness for free: the neutral observer, the Spawn Wave and Target N
# buttons, the spawn-queue budgeting, the telemetry readout and the unit browser
# all key off this one predicate. Building a parallel set for the new map would
# have been a second implementation of the thing being tested.
func is_ai_testing_ground() -> bool:
	return map_generator != null and map_generator.has_method("is_observer_arena") 		and bool(map_generator.call("is_observer_arena"))

func is_kon_arena_2() -> bool:
	return map_generator != null and str(map_generator.get("map_type_id")) == "kon_arena_2"

func is_fortress_ai_arena() -> bool:
	return map_generator != null and str(map_generator.get("map_type_id")) == "fortress_ai_arena"

func _force_ai_test_mode_if_needed() -> void:
	if not is_ai_testing_ground():
		return
	var changed := enabled or phase != &"ai_test" or boss_has_spawned
	enabled = false
	phase = &"ai_test"
	boss_has_spawned = false
	boss_has_been_defeated = false
	boss_node = null
	_ai_test_spawn_second_budget_remaining = maxi(_ai_test_spawn_second_budget_remaining, _ai_test_spawn_cap_per_second())
	if changed:
		phase_changed.emit(phase)

func spawn_ai_test_wave() -> Dictionary:
	if map_generator == null:
		return {"wave": ai_test_wave_index, "west": 0, "east": 0, "queued": _ai_test_spawn_queue.size(), "accepted": false}
	var live_units: int = rts_world.count_units_all() if rts_world != null and rts_world.has_method("count_units_all") else _count_ai_test_units_fallback()
	var remaining_capacity: int = ai_test_live_unit_soft_cap - live_units - _ai_test_spawn_queue.size()
	if remaining_capacity <= 0:
		return {"wave": ai_test_wave_index, "west": 0, "east": 0, "queued": _ai_test_spawn_queue.size(), "accepted": false, "reason": "soft_cap"}
	if _ai_test_spawn_queue.size() >= ai_test_spawn_queue_limit:
		return {"wave": ai_test_wave_index, "west": 0, "east": 0, "queued": _ai_test_spawn_queue.size(), "accepted": false, "reason": "spawn_queue_full"}
	ai_test_wave_index += 1
	var count_per_side: int = mini(12 + ai_test_wave_index * 4, 80)
	var max_requests: int = mini(mini(count_per_side * 2, remaining_capacity), ai_test_spawn_queue_limit - _ai_test_spawn_queue.size())
	var parent := get_parent()
	var west_queued := 0
	var east_queued := 0
	for i in count_per_side:
		if west_queued + east_queued >= max_requests:
			break
		var west_cell := _ai_test_spawn_cell(_ai_test_west_spawn_anchor(), i, -1)
		var east_cell := _ai_test_spawn_cell(_ai_test_east_spawn_anchor(), i, 1)
		var west_target: Vector2 = _ai_test_lane_target(_ai_test_west_target_anchor(), i)
		var east_target: Vector2 = _ai_test_lane_target(_ai_test_east_target_anchor(), i)
		_ai_test_spawn_queue.append({"index": i, "side": 2, "cell": west_cell, "target": west_target, "parent": parent})
		west_queued += 1
		if west_queued + east_queued >= max_requests:
			break
		_ai_test_spawn_queue.append({"index": i, "side": 3, "cell": east_cell, "target": east_target, "parent": parent})
		east_queued += 1
	return {"wave": ai_test_wave_index, "west": west_queued, "east": east_queued, "queued": _ai_test_spawn_queue.size(), "accepted": west_queued + east_queued > 0}

func queue_ai_test_until(target_live_units: int) -> Dictionary:
	var queued_waves := 0
	var queued_units := 0
	var last_result := {}
	for _i in 40:
		var live_units: int = rts_world.count_units_all() if rts_world != null and rts_world.has_method("count_units_all") else _count_ai_test_units_fallback()
		if live_units + _ai_test_spawn_queue.size() >= target_live_units:
			break
		last_result = spawn_ai_test_wave()
		if not bool(last_result.get("accepted", false)):
			break
		queued_waves += 1
		queued_units += int(last_result.get("west", 0)) + int(last_result.get("east", 0))
	return {
		"target": target_live_units,
		"queued_waves": queued_waves,
		"queued_units": queued_units,
		"queued": _ai_test_spawn_queue.size(),
		"last_reason": str(last_result.get("reason", "")),
	}

func get_ai_test_spawn_telemetry() -> Dictionary:
	return {
		"spawn_queue": _ai_test_spawn_queue.size(),
		"spawn_queue_limit": ai_test_spawn_queue_limit,
		"spawn_budget_per_frame": ai_test_spawn_budget_per_frame,
		"effective_spawn_budget_per_frame": _effective_ai_test_spawn_budget(),
		"spawned_per_second": _ai_test_last_units_spawned_per_second,
		"live_soft_cap": ai_test_live_unit_soft_cap,
	}

func spawn_ai_test_player_unit(archetype: StringName) -> Dictionary:
	if not is_ai_testing_ground() or map_generator == null:
		return {"accepted": false, "reason": "not_ai_testing_ground"}
	var scene := _scene_for_test_unit(archetype)
	if scene == null:
		return {"accepted": false, "reason": "unknown_unit"}
	var live_units: int = rts_world.count_units_all() if rts_world != null and rts_world.has_method("count_units_all") else _count_ai_test_units_fallback()
	if live_units >= ai_test_live_unit_soft_cap:
		return {"accepted": false, "reason": "soft_cap"}
	var existing: int = rts_world.count_units_for_owner(1) if rts_world != null else 0
	var spawn_cell: Vector2i = map_generator.nearest_walkable_cell(Vector2i(48 + existing % 6, 45 + existing / 6), 12)
	var unit := _spawn_ai_test_unit(scene, archetype, 1, spawn_cell, get_parent(), map_generator.cell_to_world(Vector2i(48, 37)))
	if unit == null:
		return {"accepted": false, "reason": "spawn_failed"}
	return {"accepted": true, "unit": str(archetype), "owner": 1}

func _update_ai_test_spawn_queue(delta: float) -> void:
	_ai_test_spawn_meter_elapsed += delta
	if _ai_test_spawn_meter_elapsed >= 1.0:
		_ai_test_last_units_spawned_per_second = _ai_test_units_spawned_this_second
		_ai_test_units_spawned_this_second = 0
		_ai_test_spawn_second_budget_remaining = _ai_test_spawn_cap_per_second()
		_ai_test_spawn_meter_elapsed = 0.0
	if _ai_test_spawn_queue.is_empty():
		return
	if _ai_test_spawn_second_budget_remaining <= 0 and _ai_test_units_spawned_this_second == 0:
		_ai_test_spawn_second_budget_remaining = _ai_test_spawn_cap_per_second()
	var budget := _effective_ai_test_spawn_budget()
	if budget <= 0:
		return
	var spawned := 0
	while spawned < budget and not _ai_test_spawn_queue.is_empty():
		var live_units: int = rts_world.count_units_all() if rts_world != null and rts_world.has_method("count_units_all") else _count_ai_test_units_fallback()
		if live_units >= ai_test_live_unit_soft_cap:
			_ai_test_spawn_queue.clear()
			return
		var request: Dictionary = _ai_test_spawn_queue.pop_front()
		var unit := _spawn_queued_ai_test_unit(request)
		if unit != null:
			spawned += 1
			_ai_test_units_spawned_this_second += 1
			_ai_test_spawn_second_budget_remaining = maxi(0, _ai_test_spawn_second_budget_remaining - 1)
	if spawned > 0:
		wave_spawned.emit(ai_test_wave_index, spawned)

func _effective_ai_test_spawn_budget() -> int:
	var fps := float(Performance.get_monitor(Performance.TIME_FPS))
	var process_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var live_units: int = rts_world.count_units_all() if rts_world != null and rts_world.has_method("count_units_all") else _count_ai_test_units_fallback()
	if live_units < 120:
		return mini(_ai_test_spawn_second_budget_remaining, ai_test_spawn_budget_per_frame)
	if process_ms > 75.0 or physics_ms > 45.0:
		return 0
	if _ai_test_spawn_second_budget_remaining <= 0:
		return 0
	var max_budget := ai_test_spawn_budget_per_frame
	if live_units >= 2200:
		max_budget = mini(max_budget, 3)
	elif live_units >= 1600:
		max_budget = mini(max_budget, 5)
	elif live_units >= 1200:
		max_budget = mini(max_budget, 8)
	elif live_units >= 900:
		max_budget = mini(max_budget, 14)
	elif live_units >= 600:
		max_budget = mini(max_budget, 24)
	if fps > 1.0 and fps < ai_test_spawn_slow_fps:
		return mini(max_budget, ai_test_min_spawn_budget_per_frame)
	if process_ms > 50.0 or physics_ms > 28.0:
		return 0
	if process_ms > 32.0 or physics_ms > 18.0:
		return mini(_ai_test_spawn_second_budget_remaining, maxi(ai_test_min_spawn_budget_per_frame, max_budget / 4))
	return mini(_ai_test_spawn_second_budget_remaining, maxi(ai_test_min_spawn_budget_per_frame, max_budget))

func _ai_test_spawn_cap_per_second() -> int:
	var live_units: int = rts_world.count_units_all() if rts_world != null and rts_world.has_method("count_units_all") else _count_ai_test_units_fallback()
	if live_units >= 2200:
		return 12
	if live_units >= 1600:
		return 18
	if live_units >= 1200:
		return 30
	if live_units >= 900:
		return 42
	if live_units >= 600:
		return 64
	return 96

func _spawn_queued_ai_test_unit(request: Dictionary) -> Node:
	var index := int(request.get("index", 0))
	var side := int(request.get("side", 2))
	var spawn_cell: Vector2i = request.get("cell", Vector2i.ZERO)
	var parent: Node = request.get("parent", get_parent())
	var target: Vector2 = request.get("target", Vector2.ZERO)
	if parent == null or not is_instance_valid(parent):
		parent = get_parent()
	if side == 2:
		return _spawn_ai_test_west_unit(index, spawn_cell, parent, target)
	return _spawn_ai_test_east_unit(index, spawn_cell, parent, target)

func _ai_test_spawn_cell(anchor: Vector2i, index: int, side: int) -> Vector2i:
	var row := index / 10
	var col := index % 10
	var offset := Vector2i(col * side, row - 5)
	return map_generator.nearest_walkable_cell(anchor + offset, 12)

func _ai_test_lane_target(anchor: Vector2i, index: int) -> Vector2:
	var lane := (index % 14) - 7
	var depth := (index / 14) % 4
	var target_cell: Vector2i = map_generator.nearest_walkable_cell(anchor + Vector2i(depth, lane), 10)
	return map_generator.cell_to_world(target_cell)

# Anchors are asked of the MAP on Arena 2.0 rather than hardcoded here.
#
# The other two arenas carry literal cell numbers, which is why they are pinned
# to a 96 map: change the size and the armies spawn in a wall. Arena 2.0 reads
# its camps and its centre from the generator that drew them, so the layout and
# the spawns cannot disagree.
func _arena_2_cell(plot_id: String, fallback: Vector2i) -> Vector2i:
	if map_generator == null:
		return fallback
	for plot in map_generator.get("plots"):
		if str(plot.get("id", "")) == plot_id:
			return plot.get("anchor", fallback)
	return fallback

func _ai_test_west_spawn_anchor() -> Vector2i:
	if is_kon_arena_2():
		return _arena_2_cell("arena2_kon_camp", Vector2i(14, 64))
	return Vector2i(29, 38) if is_fortress_ai_arena() else Vector2i(18, 37)

func _ai_test_east_spawn_anchor() -> Vector2i:
	if is_kon_arena_2():
		return _arena_2_cell("arena2_steel_camp", Vector2i(114, 64))
	return Vector2i(66, 38) if is_fortress_ai_arena() else Vector2i(78, 37)

# BOTH sides are sent to the same place on Arena 2.0.
#
# The other arenas send each army at the other's staging ground, so they pass
# through each other's flanks and the fight smears across the whole map -- fine
# for a pathing stress test, useless for watching two rosters trade. Sending both
# to the killing field means every wave meets in the same place, at the same
# time, on ground neither side owns.
func _ai_test_west_target_anchor() -> Vector2i:
	if is_kon_arena_2():
		return _arena_2_cell("arena2_killing_field", Vector2i(64, 64))
	return Vector2i(81, 38) if is_fortress_ai_arena() else Vector2i(66, 37)

func _ai_test_east_target_anchor() -> Vector2i:
	if is_kon_arena_2():
		return _arena_2_cell("arena2_killing_field", Vector2i(64, 64))
	return Vector2i(14, 38) if is_fortress_ai_arena() else Vector2i(30, 37)

func _spawn_ai_test_west_unit(index: int, spawn_cell: Vector2i, parent: Node, target: Vector2) -> Node:
	if is_kon_arena_2():
		var kon := _arena_2_kon_mix()
		var kon_archetype: StringName = kon[index % kon.size()]
		return _spawn_ai_test_unit(_scene_for_test_unit(kon_archetype), kon_archetype, 2, spawn_cell, parent, target)
	var archetypes := _ai_test_kon_mix()
	var scenes := _ai_test_kon_mix_scenes()
	var slot := index % archetypes.size()
	return _spawn_ai_test_unit(scenes[slot], archetypes[slot], 2, spawn_cell, parent, target)

# East is the Steel Force on Arena 2.0, and Kon's own mix everywhere else.
#
# The first arena runs the same mix on both sides. That is a real test of pathing
# and of how many units the frame can carry, and it is no test at all of whether
# one roster beats another -- a mirror match always ends 50/50 given enough runs.
func _spawn_ai_test_east_unit(index: int, spawn_cell: Vector2i, parent: Node, target: Vector2) -> Node:
	if is_kon_arena_2():
		var steel := _arena_2_steel_mix()
		var steel_archetype: StringName = steel[index % steel.size()]
		return _spawn_ai_test_unit(_steel_scene(steel_archetype), steel_archetype, 3, spawn_cell, parent, target)
	var archetypes := _ai_test_kon_mix()
	var scenes := _ai_test_kon_mix_scenes()
	var slot := index % archetypes.size()
	return _spawn_ai_test_unit(scenes[slot], archetypes[slot], 3, spawn_cell, parent, target)

func _ai_test_kon_mix() -> Array[StringName]:
	return [
		&"terrible_thing", &"horror", &"terrible_thing", &"apex",
		&"oaven_spear", &"horror", &"terrible_thing", &"terrible_thing",
		&"apex", &"horror", &"terrible_thing", &"terrible_thing",
		&"horror", &"terrible_thing", &"apex", &"spawner",
		&"stone_face_serpent",
	]

func _ai_test_deom_mix() -> Array[StringName]:
	return [
		&"deom_scout", &"deom_blade", &"deom_crosshirran", &"deom_scout",
		&"deom_blade", &"deom_crosshirran", &"deom_hammer", &"deom_glaive",
		&"deom_scout", &"deom_blade", &"deom_glaive", &"deom_odden",
	]

func _ai_test_kon_mix_scenes() -> Array[PackedScene]:
	return [
		terrible_thing_scene, horror_scene, terrible_thing_scene, apex_scene,
		oaven_spear_scene, horror_scene, terrible_thing_scene, terrible_thing_scene,
		apex_scene, horror_scene, terrible_thing_scene, terrible_thing_scene,
		horror_scene, terrible_thing_scene, apex_scene, spawner_scene,
		stone_face_serpent_scene,
	]

func _ai_test_deom_mix_scenes() -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []
	for _i in _ai_test_deom_mix():
		scenes.append(deom_legion_scene)
	return scenes

# The two arena rosters, and when each unit joins the fight.
#
# READ FROM THE CATALOG, NOT LISTED HERE. The first version of this hand-listed
# eight archetypes per side and got Kon's wrong: terrible_thing, horror and apex
# are not Kon's units at all, they belong to the other two wizard classes, so
# "Kon versus the Steel Force" was really "somebody else's units versus the
# Steel Force". A list in a function cannot notice that. A roster read from the
# class definition cannot get it wrong, and a unit added to either faction
# tomorrow joins the arena with no code change -- the same lesson the Mounted
# Knight taught the conscription ladder.
#
# WAVE THRESHOLD IS THE UNIT'S OWN TIER. A tier 3 unit joins at wave 3. That is
# one rule rather than two hand-tuned schedules, and it is symmetric for free:
# the two rosters happen to have the same tier spread (one T1, two T2, one T3),
# so neither side thickens ahead of the other. If that ever stops being true the
# arena tells you honestly rather than hiding it behind matched hand-lists.
func _arena_2_roster(archetypes: Array[StringName]) -> Array[StringName]:
	var mix: Array[StringName] = []
	for archetype in archetypes:
		if ai_test_wave_index + 1 < UnitCatalog.tier_of(archetype):
			continue
		# Weighted by tier: the cheap unit is the bulk of the army and the heavy
		# one is the spike, which is what an army looks like. Without this a
		# Spawner would be a quarter of every wave.
		var copies: int = maxi(1, 4 - UnitCatalog.tier_of(archetype))
		for _i in copies:
			mix.append(archetype)
	if mix.is_empty():
		mix.append(archetypes[0] if not archetypes.is_empty() else &"oaven_spear")
	return mix

func _arena_2_kon_mix() -> Array[StringName]:
	return _arena_2_roster(UnitCatalog.fieldable_units_for_class("bad_kon_willow"))

func _arena_2_steel_mix() -> Array[StringName]:
	return _arena_2_roster(UnitCatalog.fieldable_units_for_faction(&"steel_force"))

func _spawn_ai_test_unit(scene: PackedScene, archetype: StringName, owner: int, spawn_cell: Vector2i, parent: Node, target: Vector2) -> Node:
	if scene == null:
		# Silently returning null is how a whole unit type went missing from the
		# arena without anyone noticing: the roster asked for Manglers, the scene
		# factory had none, and the army just came up short. An arena that drops
		# part of an army is measuring the wrong fight.
		push_error("[WaveDirector] No scene for arena unit '%s'; it is on a roster but cannot be spawned" % archetype)
		return null
	var unit := scene.instantiate()
	unit.set("owner_player_id", owner)
	unit.set("unit_archetype", archetype)
	if _has_property(unit, "enemy_archetype"):
		unit.set("enemy_archetype", archetype)
	if unit.has_method("configure_enemy"):
		unit.call("configure_enemy", archetype)
	parent.add_child(unit)
	unit.set("owner_player_id", owner)
	# Arena 2.0 keeps its units WHOLE.
	#
	# prepare_lightweight_arena_unit() deletes the ArtSprite and switches off
	# _process and _physics_process, which is right for the original arena --
	# that one exists to answer "how many bodies fit in a frame" and the art is
	# not part of the question. It is wrong here: Arena 2.0 exists to watch the
	# real roster fight, so a Mounted Knight has to charge with its momentum
	# animation and an Oaven has to swap to its blowpipe on a wall. Stripping
	# that leaves coloured capsules sliding at each other, which is what this
	# map looked like before.
	#
	# The cost is real and it is the point: measuring frame time with the art ON
	# is the measurement worth having.
	if owner != 1 and (not is_kon_arena_2() or arena_2_force_lightweight) and unit.has_method("prepare_lightweight_arena_unit"):
		unit.call("prepare_lightweight_arena_unit")
	unit.global_position = map_generator.cell_to_world(map_generator.nearest_walkable_cell(spawn_cell, 10))
	if unit.has_method("set_arena_leash"):
		# The other two arenas carry literal cell numbers, which only work
		# because they are both 96 maps. Arena 2.0 is 128 and asks the generator
		# for its own bounds -- hardcoding them here would have penned every unit
		# into the corner of a map twice the size, with nothing to say why.
		var min_cell := Vector2i(6, 21) if is_fortress_ai_arena() else Vector2i(8, 20)
		var max_cell := Vector2i(90, 59) if is_fortress_ai_arena() else Vector2i(88, 58)
		if is_kon_arena_2() and map_generator.has_method("kon_arena_2_bounds"):
			var bounds: Rect2i = map_generator.call("kon_arena_2_bounds")
			min_cell = bounds.position
			max_cell = bounds.end - Vector2i.ONE
		var min_world: Vector2 = map_generator.cell_to_world(min_cell)
		var max_world: Vector2 = map_generator.cell_to_world(max_cell)
		var arena_rect := Rect2(min_world, max_world - min_world)
		unit.call("set_arena_leash", arena_rect, target)
	if owner != 1:
		if unit.has_method("issue_arena_attack_move_order"):
			unit.issue_arena_attack_move_order(target)
		elif unit.has_method("issue_attack_move_order"):
			unit.issue_attack_move_order(target)
	return unit

func _scene_for_kon_unit(archetype: StringName) -> PackedScene:
	match archetype:
		&"terrible_thing", &"awful_thing":
			return terrible_thing_scene
		&"oaven_spear", &"oaven_jumper":
			return oaven_spear_scene
		&"horror":
			return horror_scene
		&"apex", &"apex_predator":
			return apex_scene
		&"spawner":
			return spawner_scene
		&"stone_face_serpent":
			return stone_face_serpent_scene
		# The Mangler was missing here while being on Kon's roster, so Arena 2.0
		# quietly spawned nothing for every Mangler slot in every wave -- a
		# seventh of Kon's army simply absent, with no error. _spawn_ai_test_unit
		# returns null on a null scene, and nothing above it was looking.
		&"mangler", &"winged_mangler":
			return preload("res://scenes/units/mangler.tscn")
	return null

func _scene_for_test_unit(archetype: StringName) -> PackedScene:
	var steel := _steel_scene(archetype)
	if steel != null: return steel
	var kon_scene := _scene_for_kon_unit(archetype)
	if kon_scene != null:
		return kon_scene
	if _deom_archetypes().has(archetype):
		return deom_legion_scene
	return null

func _deom_archetypes() -> Array[StringName]:
	return [&"deom_scout", &"deom_blade", &"deom_crosshirran", &"deom_hammer", &"deom_glaive", &"deom_odden"]

func _steel_archetypes() -> Array[StringName]:
	return [&"poorper", &"steel_knight", &"proper_blimp", &"mounted_knight"]

# Everything the CURRENT enemy faction fields, in the order the waves introduce
# it. The sandbox spawn buttons are built from this rather than from a list of
# their own, so switching enemy_faction switches what you can spawn by hand too
# -- one place to change, and no menu quietly offering last month's enemies.
func enemy_roster() -> Array[StringName]:
	return _steel_archetypes() if enemy_faction == "steel_force" else _deom_archetypes()

# The faction's plain body and its heavy one.
#
# Authored content -- the citadel garrison, the vertical slice's outposts --
# wants "a defender" and "a heavy defender", not a named unit. Asking here means
# a faction switch reaches the garrisons as well as the waves, instead of
# leaving last month's enemies standing on the walls of a map whose waves have
# already changed.
func enemy_light_archetype() -> StringName:
	return &"poorper" if enemy_faction == "steel_force" else &"deom_blade"

func enemy_heavy_archetype() -> StringName:
	return &"steel_knight" if enemy_faction == "steel_force" else &"deom_crosshirran"

# Spawn one enemy by hand, for the sandbox. Deliberately the same call the wave
# spawner uses, aggression and all: a unit you placed yourself behaves exactly
# like one that walked in, which is the only way testing against it means
# anything.
func spawn_sandbox_enemy(archetype: StringName, cell: Vector2i, parent: Node) -> Node:
	return _spawn_enemy(archetype, cell, parent, Vector2.ZERO)

func _has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

# A punchbag for the sandbox: an enemy that stands still and cannot die.
#
# Testing a heavy blowpipe, or whether a unit on a wall-walk can actually shoot
# what it is looking at, needs something to shoot at that is still there a minute
# later. It holds position so it does not wander off mid-test, and its health is
# restored every frame rather than being made invulnerable, so it still shows
# damage numbers, still draws aggro and still behaves like a target in every way
# that matters -- it simply never falls over.
func spawn_target_dummy(cell: Vector2i, parent: Node) -> Node:
	# A punchbag from whatever faction is currently attacking you, so the thing
	# you are shooting has the armour you will actually meet. A Steel Knight's
	# 10 armour is most of what makes it feel different to shoot at, and a
	# dummy that did not have it would quietly test the wrong weapon.
	var archetype: StringName = &"steel_knight" if enemy_faction == "steel_force" else &"terrible_thing"
	var dummy := _spawn_enemy(archetype, cell, parent, Vector2.ZERO)
	if dummy == null or not is_instance_valid(dummy):
		return null
	dummy.set_meta("sandbox_dummy", true)
	if dummy.has_method("issue_hold_position_order"):
		dummy.call_deferred("issue_hold_position_order")
	return dummy

func _process_target_dummies() -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or not bool(unit.get_meta("sandbox_dummy", false)):
			continue
		var maximum: Variant = unit.get("max_health")
		if maximum != null:
			unit.set("health", int(maximum))

func _spawn_enemy(archetype: StringName, spawn_cell: Vector2i, parent: Node, preferred_target: Vector2 = Vector2.ZERO) -> Node:
	var steel := _steel_scene(archetype)
	var enemy := (steel if steel != null else enemy_scene).instantiate()
	enemy.set("owner_player_id", 2)
	enemy.set("unit_archetype", archetype)
	if _has_property(enemy, "enemy_archetype"):
		enemy.set("enemy_archetype", archetype)
	if enemy.has_method("configure_enemy"):
		enemy.call("configure_enemy", archetype)
	parent.add_child(enemy)
	enemy.set("owner_player_id", 2)
	enemy.global_position = map_generator.cell_to_world(map_generator.nearest_walkable_cell(spawn_cell, 10))
	if archetype == &"proper_blimp":
		for i in 3:
			var crew := preload("res://scenes/units/poorper.tscn").instantiate()
			crew.owner_player_id = 2
			parent.add_child(crew)
			crew.global_position = enemy.global_position+Vector2(70+i*20,0)
			crew.nav_level = enemy.nav_level
			enemy.landed = true
			enemy.board(crew)
			enemy.landed = false
	_log_combat_entity("spawn_enemy", enemy)
	call_deferred("_send_enemy_to_player_target", enemy, preferred_target)
	return enemy

func _send_enemy_to_player_target(enemy: Node, preferred_target: Vector2 = Vector2.ZERO) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("issue_attack_move_order"):
		if combat_debug_logging:
			print("[WaveDirector] Enemy aggression failed: invalid enemy or missing issue_attack_move_order enemy=", enemy)
		return
	var target := preferred_target if preferred_target != Vector2.ZERO else _player_target_world()
	if target == Vector2.ZERO:
		if combat_debug_logging:
			print("[WaveDirector] Enemy aggression failed: no player target enemy=", enemy.name)
		return
	var uses_flow_field := _can_use_flow_field_for_enemy(enemy as Node2D, target)
	if not uses_flow_field and not bool(enemy.get("ignores_terrain")):
		target = _pathable_target_for_enemy(enemy as Node2D, target)
	if uses_flow_field:
		enemy.call("issue_flow_field_attack_move_order", target)
	else:
		enemy.issue_attack_move_order(target)
	if enemy.get("path").is_empty() and not bool(enemy.get("ignores_terrain")):
		target = _nearest_walkable_player_target(enemy as Node2D)
		if target != Vector2.ZERO:
			enemy.issue_attack_move_order(target)
	if combat_debug_logging:
		print("[WaveDirector] Enemy attack-move enemy=", enemy.name,
			" owner=", enemy.get("owner_player_id"),
			" target=", target,
			" path_length=", enemy.get("path").size() if _has_property(enemy, "path") else "<unknown>",
			" registered=", _is_registered_unit(enemy))

func _can_use_flow_field_for_enemy(enemy: Node2D, target: Vector2) -> bool:
	if enemy == null or map_generator == null or bool(enemy.get("ignores_terrain")):
		return false
	if not enemy.has_method("issue_flow_field_attack_move_order"):
		return false
	if not map_generator.has_method("has_flow_field_route_world"):
		return false
	return bool(map_generator.call("has_flow_field_route_world", enemy.global_position, target))

func get_boss_seconds_remaining() -> int:
	if boss_has_spawned:
		return 0
	return maxi(0, ceili(boss_arrival_seconds - combat_time_elapsed()))

func _enemy_archetype_for_wave(index: int) -> StringName:
	if enemy_faction == "steel_force":
		if wave_index >= 7 and index%9 == 0: return &"mounted_knight"
		if wave_index >= 4 and index%7 == 0: return &"proper_blimp"
		if wave_index >= 2 and index%3 == 0: return &"steel_knight"
		return &"poorper"
	if wave_index <= 1:
		return &"deom_scout" if index % 3 == 0 else &"deom_blade"
	if wave_index <= 3:
		if index % 4 == 0:
			return &"deom_crosshirran"
		return &"deom_scout" if index % 3 == 0 else &"deom_blade"
	if index % 6 == 0:
		return &"deom_hammer"
	if index % 4 == 0:
		return &"deom_glaive"
	if wave_index >= 7 and index % 9 == 0:
		return &"deom_odden"
	return &"deom_crosshirran" if index % 3 == 0 else &"deom_blade"

func _steel_scene(archetype: StringName) -> PackedScene:
	match archetype:
		&"poorper": return preload("res://scenes/units/poorper.tscn")
		&"steel_knight": return preload("res://scenes/units/steel_knight.tscn")
		&"mounted_knight": return preload("res://scenes/units/mounted_knight.tscn")
		&"proper_blimp": return preload("res://scenes/units/proper_blimp.tscn")
	return null

func _retarget_enemy_army() -> void:
	var target := _player_target_world()
	if target == Vector2.ZERO:
		return
	var retargeted := 0
	var enemies: Array[Node2D] = rts_world.units_for_owner(2) if rts_world != null else _enemy_units_fallback()
	for unit in enemies:
		if not is_instance_valid(unit) or int(unit.get("owner_player_id")) != 2:
			continue
		if unit.has_method("issue_attack_move_order") and _should_retarget(unit):
			_send_enemy_to_player_target(unit, target)
			retargeted += 1
			if retargeted >= max_retargets_per_tick:
				return

func _should_retarget(unit: Node) -> bool:
	var state: StringName = unit.get("unit_state")
	if state in [&"attacking", &"stunned"]:
		return false
	var target = unit.get("attack_target")
	return target == null or not is_instance_valid(target)

func _player_target_world() -> Vector2:
	var tower := _nearest_player_structure(&"wizard_tower")
	if tower != null:
		return _reachable_world_near(tower.global_position)
	var any_structure := _nearest_player_structure(&"")
	if any_structure != null:
		return _reachable_world_near(any_structure.global_position)
	var player_units: Array[Node2D] = rts_world.units_for_owner(1) if rts_world != null else _player_units_fallback()
	for unit in player_units:
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1:
			return _reachable_world_near(unit.global_position)
	return Vector2.ZERO

func _reachable_world_near(world_pos: Vector2) -> Vector2:
	if map_generator == null or not map_generator.has_method("world_to_cell") or not map_generator.has_method("nearest_walkable_cell"):
		return world_pos
	var cell: Vector2i = map_generator.world_to_cell(world_pos)
	var reachable: Vector2i = map_generator.nearest_walkable_cell(cell, 16)
	if map_generator.has_method("cell_to_world"):
		return map_generator.cell_to_world(reachable)
	return world_pos

func _pathable_spawn_cell(spawns: Array, target: Vector2, start_index: int) -> Vector2i:
	if target == Vector2.ZERO or map_generator == null or not map_generator.has_method("find_path_world"):
		return spawns[posmod(start_index, spawns.size())]
	for offset in range(mini(spawns.size(), 36)):
		var cell: Vector2i = spawns[posmod(start_index + offset * 7, spawns.size())]
		var world: Vector2 = map_generator.cell_to_world(map_generator.nearest_walkable_cell(cell, 10))
		var path: Array = map_generator.find_path_world(world, target)
		if not path.is_empty():
			return cell
	return spawns[posmod(start_index, spawns.size())]

func _pathable_target_for_enemy(enemy: Node2D, preferred_target: Vector2) -> Vector2:
	if enemy == null or map_generator == null or not map_generator.has_method("find_path_world"):
		return preferred_target
	var path: Array = map_generator.find_path_world(enemy.global_position, preferred_target)
	if not path.is_empty():
		return preferred_target
	var fallback := _nearest_walkable_player_target(enemy)
	return fallback if fallback != Vector2.ZERO else preferred_target

func _nearest_walkable_player_target(enemy: Node2D) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	for candidate in _player_target_candidates():
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		var cell: Vector2i = map_generator.world_to_cell((candidate as Node2D).global_position)
		var target_cell: Vector2i = map_generator.nearest_walkable_cell(cell, 18)
		var target_world: Vector2 = map_generator.cell_to_world(target_cell)
		var path: Array = map_generator.find_path_world(enemy.global_position, target_world)
		if path.is_empty():
			continue
		var distance := enemy.global_position.distance_squared_to(target_world)
		if distance < best_distance:
			best = target_world
			best_distance = distance
	return best

func _player_target_candidates() -> Array[Node]:
	var candidates: Array[Node] = []
	for structure in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == 1:
			candidates.append(structure)
	var player_units: Array[Node2D] = rts_world.units_for_owner(1) if rts_world != null else _player_units_fallback()
	for unit in player_units:
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1:
			candidates.append(unit)
	return candidates

func _nearest_player_structure(archetype: StringName) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	var origin := Vector2.ZERO
	var spawns: Array = []
	if map_generator != null:
		spawns = map_generator.get("enemy_spawns")
	if not spawns.is_empty():
		origin = map_generator.cell_to_world(spawns[0])
	for structure in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(structure) or int(structure.get("owner_player_id")) != 1:
			continue
		if archetype != &"" and str(structure.get("archetype")) != str(archetype):
			continue
		var distance := origin.distance_squared_to(structure.global_position)
		if distance < best_distance:
			best = structure
			best_distance = distance
	return best

func _count_enemy_units_fallback() -> int:
	var active := 0
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 2:
			active += 1
	return active

func _count_ai_test_units_fallback() -> int:
	var active := 0
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) in [2, 3]:
			active += 1
	return active

func _enemy_units_fallback() -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and unit is Node2D and int(unit.get("owner_player_id")) == 2:
			enemies.append(unit)
	return enemies

func _player_units_fallback() -> Array[Node2D]:
	var players: Array[Node2D] = []
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and unit is Node2D and int(unit.get("owner_player_id")) == 1:
			players.append(unit)
	return players

func _log_combat_entity(context: String, node: Node) -> void:
	if not combat_debug_logging:
		return
	if node == null or not is_instance_valid(node):
		print("[CombatValidation] ", context, " node=<invalid>")
		return
	var groups := PackedStringArray()
	for group in node.get_groups():
		groups.append(str(group))
	var script_path := "<none>"
	var script: Variant = node.get_script()
	if script != null and script is Resource:
		script_path = str((script as Resource).resource_path)
	var group_text := ",".join(groups)
	print("[CombatValidation] ", context,
		" node=", node.name,
		" class=", node.get_class(),
		" script=", script_path,
		" owner=", node.get("owner_player_id") if _has_property(node, "owner_player_id") else "<missing>",
		" take_damage=", node.has_method("take_damage"),
		" rts_unit_registered=", _is_registered_unit(node),
		" rts_structure_registered=", _is_registered_structure(node),
		" groups=", group_text,
		" attack_damage=", node.get("attack_damage") if _has_property(node, "attack_damage") else "<missing>",
		" attack_range=", node.get("attack_range") if _has_property(node, "attack_range") else "<missing>",
		" health=", node.get("health") if _has_property(node, "health") else "<missing>",
		" max_health=", node.get("max_health") if _has_property(node, "max_health") else "<missing>")

func _is_registered_unit(node: Node) -> bool:
	if rts_world == null or not is_instance_valid(rts_world) or not (node is Node2D):
		return false
	return rts_world.all_units().has(node)

func _is_registered_structure(node: Node) -> bool:
	if rts_world == null or not is_instance_valid(rts_world) or not (node is Node2D):
		return false
	return rts_world.all_structures().has(node)
