class_name TelemetryLogger
extends Node

const EXPORT_DIR := "res://test_exports/session_data"

@export var sample_interval: float = 1.0
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var wave_director_path: NodePath = NodePath("../WaveDirector")
@export var combat_system_path: NodePath = NodePath("../CombatSystem")
@export var enabled: bool = true

var rts_world: RTSWorld
var map_generator: Node
var wave_director: Node
var combat_system: Node
var session_id := ""
var export_dir_absolute := ""
var samples_path := ""
var summary_path := ""
var _elapsed := 0.0
var _session_elapsed := 0.0
var _sample_count := 0
var _started_msec := 0
var _peak_units := 0
var _lowest_fps := INF
var _highest_process_ms := 0.0
var _highest_physics_ms := 0.0
var _last_sample := {}
var _samples_file: FileAccess
var _finalized := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not enabled:
		set_process(false)
		return
	set_process(false)
	rts_world = get_node_or_null(rts_world_path)
	map_generator = get_node_or_null(map_generator_path)
	wave_director = get_node_or_null(wave_director_path)
	combat_system = get_node_or_null(combat_system_path)
	call_deferred("_start_logging")

func _start_logging() -> void:
	if _finalized:
		return
	if map_generator == null:
		map_generator = get_node_or_null(map_generator_path)
	if map_generator == null or (map_generator.has_method("get_map_summary") and map_generator.get("grid").is_empty()):
		call_deferred("_start_logging")
		return
	_started_msec = Time.get_ticks_msec()
	_prepare_export_files()
	_write_metadata()
	set_process(true)

func _process(delta: float) -> void:
	if _finalized:
		return
	_session_elapsed += delta
	if get_tree().paused:
		return
	_elapsed += delta
	if _elapsed < sample_interval:
		return
	_elapsed = 0.0
	capture_sample()

func capture_sample() -> Dictionary:
	var sample := _make_sample()
	_last_sample = sample
	_sample_count += 1
	_peak_units = maxi(_peak_units, int(sample.get("units", 0)))
	_lowest_fps = minf(_lowest_fps, float(sample.get("fps", 0.0)))
	_highest_process_ms = maxf(_highest_process_ms, float(sample.get("process_ms", 0.0)))
	_highest_physics_ms = maxf(_highest_physics_ms, float(sample.get("physics_ms", 0.0)))
	if _samples_file != null:
		_samples_file.store_line(JSON.stringify(sample))
		_samples_file.flush()
	return sample

func finalize(reason: String = "session_end") -> void:
	if _finalized:
		return
	_finalized = true
	if _sample_count == 0:
		capture_sample()
	if _samples_file != null:
		_samples_file.flush()
		_samples_file.close()
		_samples_file = null
	var summary := _make_summary(reason)
	var file := FileAccess.open(summary_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary, "\t"))
		file.close()
	print("[TelemetryLogger] Exported session data to ", export_dir_absolute)

func get_export_paths() -> Dictionary:
	return {
		"session_id": session_id,
		"folder": export_dir_absolute,
		"samples": samples_path,
		"summary": summary_path,
	}

func _exit_tree() -> void:
	finalize("scene_exit")

func _prepare_export_files() -> void:
	var root_absolute := ProjectSettings.globalize_path(EXPORT_DIR)
	DirAccess.make_dir_recursive_absolute(root_absolute)
	session_id = _make_session_id()
	export_dir_absolute = root_absolute.path_join(session_id)
	DirAccess.make_dir_recursive_absolute(export_dir_absolute)
	samples_path = export_dir_absolute.path_join("samples.jsonl")
	summary_path = export_dir_absolute.path_join("summary.json")
	_samples_file = FileAccess.open(samples_path, FileAccess.WRITE)

func _write_metadata() -> void:
	var metadata := {
		"type": "metadata",
		"session_id": session_id,
		"created_unix": Time.get_unix_time_from_system(),
		"map_type_id": _map_type_id(),
		"map_type_name": _map_type_name(),
		"seed": _map_seed(),
		"wizard_class_id": str(GameSession.get("wizard_class_id")) if has_node("/root/GameSession") else "",
		"sample_interval": sample_interval,
	}
	if _samples_file != null:
		_samples_file.store_line(JSON.stringify(metadata))
		_samples_file.flush()

func _make_sample() -> Dictionary:
	var world_stats: Dictionary = rts_world.get_observation_telemetry() if rts_world != null and rts_world.has_method("get_observation_telemetry") else {}
	var path_stats: Dictionary = map_generator.get_path_telemetry() if map_generator != null and map_generator.has_method("get_path_telemetry") else {}
	var spawn_stats: Dictionary = wave_director.get_ai_test_spawn_telemetry() if wave_director != null and wave_director.has_method("get_ai_test_spawn_telemetry") else {}
	var combat_stats: Dictionary = combat_system.get_combat_telemetry() if combat_system != null and combat_system.has_method("get_combat_telemetry") else {}
	var collision_stats: Dictionary = RTSUnit.get_mass_collision_telemetry()
	var fps := float(Performance.get_monitor(Performance.TIME_FPS))
	var process_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var frame_ms := 1000.0 / maxf(1.0, fps)
	return {
		"type": "sample",
		"t": snapped(_session_elapsed, 0.001),
		"map_type_id": _map_type_id(),
		"wave": int(wave_director.get("ai_test_wave_index")) if wave_director != null and _has_property(wave_director, "ai_test_wave_index") else int(wave_director.get("wave_index")) if wave_director != null and _has_property(wave_director, "wave_index") else 0,
		"phase": str(wave_director.get("phase")) if wave_director != null and _has_property(wave_director, "phase") else "",
		"fps": fps,
		"frame_ms": frame_ms,
		"process_ms": process_ms,
		"physics_ms": physics_ms,
		"unaccounted_frame_ms": snapped(maxf(0.0, frame_ms - process_ms - physics_ms), 0.001),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_memory_mb": snapped(float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0, 0.001),
		"units": int(world_stats.get("units", 0)),
		"structures": int(world_stats.get("structures", 0)),
		"peak_units": int(world_stats.get("peak_units", 0)),
		"owner_counts": _stringify_keys(world_stats.get("owner_counts", {})),
		"archetype_counts": _stringify_keys(world_stats.get("archetype_counts", {})),
		"state_counts": _stringify_keys(world_stats.get("state_counts", {})),
		"moving_units": int(world_stats.get("moving_units", 0)),
		"attacking_units": int(world_stats.get("attacking_units", 0)),
		"active_projectiles": int(world_stats.get("active_projectiles", 0)),
		"projectiles_spawned": int(world_stats.get("projectiles_spawned", 0)),
		"projectiles_recycled": int(world_stats.get("projectiles_recycled", 0)),
		"projectiles_spawned_per_second": int(world_stats.get("projectiles_spawned_per_second", 0)),
		"projectiles_recycled_per_second": int(world_stats.get("projectiles_recycled_per_second", 0)),
		"damage_total": int(world_stats.get("damage_total", 0)),
		"damage_by_owner": _stringify_keys(world_stats.get("damage_by_owner", {})),
		"spawn_queue": int(spawn_stats.get("spawn_queue", 0)),
		"spawn_queue_limit": int(spawn_stats.get("spawn_queue_limit", 0)),
		"spawn_budget_per_frame": int(spawn_stats.get("spawn_budget_per_frame", 0)),
		"effective_spawn_budget_per_frame": int(spawn_stats.get("effective_spawn_budget_per_frame", 0)),
		"spawned_per_second": int(spawn_stats.get("spawned_per_second", 0)),
		"live_unit_soft_cap": int(spawn_stats.get("live_soft_cap", 0)),
		"combat_tick_units": int(combat_stats.get("combat_tick_units", 0)),
		"combat_tick_budget": int(combat_stats.get("combat_tick_budget", 0)),
		"combat_candidate_queries": int(combat_stats.get("combat_candidate_queries", 0)),
		"combat_candidate_total": int(combat_stats.get("combat_candidate_total", 0)),
		"combat_avg_candidates": snapped(float(combat_stats.get("combat_avg_candidates", 0.0)), 0.001),
		"combat_tick_ms": snapped(float(combat_stats.get("combat_tick_ms", 0.0)), 0.001),
		"mass_collision_calls": int(collision_stats.get("mass_collision_calls", 0)),
		"mass_collision_neighbors": int(collision_stats.get("mass_collision_neighbors", 0)),
		"mass_collision_overlap_checks": int(collision_stats.get("mass_collision_overlap_checks", 0)),
		"path_requests": int(path_stats.get("path_requests", 0)),
		"path_cache_hits": int(path_stats.get("path_cache_hits", 0)),
		"path_requests_per_second": int(path_stats.get("path_requests_per_second", 0)),
		"path_cache_hits_per_second": int(path_stats.get("path_cache_hits_per_second", 0)),
		"path_cache_size": int(path_stats.get("path_cache_size", 0)),
	}

func _make_summary(reason: String) -> Dictionary:
	var latest := _last_sample
	return {
		"session_id": session_id,
		"finalized_reason": reason,
		"duration_seconds": snapped(_session_elapsed, 0.001),
		"sample_count": _sample_count,
		"map_type_id": _map_type_id(),
		"map_type_name": _map_type_name(),
		"seed": _map_seed(),
		"peak_units_observed": _peak_units,
		"lowest_fps_observed": 0.0 if _lowest_fps == INF else _lowest_fps,
		"highest_process_ms_observed": _highest_process_ms,
		"highest_physics_ms_observed": _highest_physics_ms,
		"latest": latest,
		"files": {
			"samples": samples_path,
			"summary": summary_path,
		},
	}

func _make_session_id() -> String:
	var map_label := _map_type_id()
	if map_label.is_empty():
		map_label = "unknown_map"
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace("T", "_")
	return "%s_%s_%s" % [stamp, map_label, str(Time.get_ticks_msec())]

func _map_type_id() -> String:
	return str(map_generator.get("map_type_id")) if map_generator != null else ""

func _map_type_name() -> String:
	return str(map_generator.get_map_type_name()) if map_generator != null and map_generator.has_method("get_map_type_name") else _map_type_id()

func _map_seed() -> int:
	return int(map_generator.get_seed_value()) if map_generator != null and map_generator.has_method("get_seed_value") else 0

func _has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

func _stringify_keys(value: Variant) -> Dictionary:
	var result := {}
	if not (value is Dictionary):
		return result
	for key in value.keys():
		result[str(key)] = value[key]
	return result
