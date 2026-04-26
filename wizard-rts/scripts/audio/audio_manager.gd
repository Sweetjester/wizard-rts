extends Node

const LIFE_WIZARD_MUSIC_PATH := "res://Bad John Dillo Fixed.mp3"
const FIRE_WIZARD_MUSIC_PATH := "res://Fire Wizard.mp3"
const EVANGALION_MUSIC_PATH := "res://Evangalion.mp3"
const MAP_MUSIC_PATH := "res://vampire mushroom forest.mp3"
const MUSIC_BUS := "Music"

var music_volume: float = 0.7:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_volume()

var music_muted: bool = false:
	set(value):
		music_muted = value
		_apply_volume()

var _player: AudioStreamPlayer

func _ready() -> void:
	_ensure_music_bus()
	_player = AudioStreamPlayer.new()
	_player.bus = MUSIC_BUS
	add_child(_player)
	_player.finished.connect(_restart_music)
	play_map_music()

func play_music(track_path: String = MAP_MUSIC_PATH) -> void:
	if _player == null:
		return
	if _player.stream == null or _player.stream.resource_path != track_path:
		var stream := load(track_path)
		if stream == null:
			push_error("[AudioManager] Missing music file: %s" % track_path)
			return
		if stream.has_method("set_loop"):
			stream.call("set_loop", true)
		elif "loop" in stream:
			stream.loop = true
		_player.stream = stream
		_player.stop()
	_apply_volume()
	if not _player.playing:
		_player.play()

func play_map_music() -> void:
	play_music(MAP_MUSIC_PATH)

func play_life_wizard_music() -> void:
	play_music(LIFE_WIZARD_MUSIC_PATH)

func play_fire_wizard_music() -> void:
	play_music(FIRE_WIZARD_MUSIC_PATH)

func play_evangalion_music() -> void:
	play_music(EVANGALION_MUSIC_PATH)

func stop_music() -> void:
	if _player:
		_player.stop()

func release_music() -> void:
	stop_music()
	if _player:
		_player.stream = null
		_player.free()
		_player = null

func is_music_playing() -> bool:
	return _player != null and _player.playing

func get_music_stream_path() -> String:
	if _player == null or _player.stream == null:
		return ""
	return _player.stream.resource_path

func set_music_volume(value: float) -> void:
	music_volume = value

func set_music_muted(value: bool) -> void:
	music_muted = value

func _restart_music() -> void:
	if _player:
		_player.play()

func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, MUSIC_BUS)

func _apply_volume() -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, music_muted)
	var db := linear_to_db(max(music_volume, 0.001))
	AudioServer.set_bus_volume_db(bus_index, db)

func _exit_tree() -> void:
	release_music()
