extends SceneTree

# No unit script may read a possibly-freed reference into a TYPED local.
#
# Reported as "it froze when I spawned a unit and combat was happening". The
# session log ended on:
#
#   SCRIPT ERROR: Trying to assign invalid previously freed instance.
#      at: _process (res://scripts/units/kon_painted_art.gd:47)
#
# The line was `var target: Node2D = unit.get("attack_target")`. There IS an
# is_instance_valid() guard -- on the NEXT line, which never runs, because
# assigning a freed object to a typed local raises before the guard is reached.
# A killed unit is queue_free()d and is not actually gone until the end of the
# frame, so a stale-but-freed attack_target is a state every reader must expect.
# Three art scripts had the typed form; everything else in the codebase already
# reads it untyped and checks it.
#
# WHY THIS IS A SOURCE CHECK AND NOT A BEHAVIOUR CHECK, which is the part worth
# reading: the first version of this test asserted the consequence -- that the
# art's animation clock stopped advancing -- and it PASSED against the broken
# code. Godot does not abort _process for this error. It logs it and carries on
# with a null, which is the same value the fix produces. So there is no
# behavioural difference to assert at all. The entire damage is the error
# itself: once per frame, per unit, for as long as the stale reference lives,
# each one capturing a stack, writing to the log and being serialised to the
# attached debugger. GDScript cannot observe a pushed error, so the only honest
# guard is on the shape of the code that causes it.
#
# The runtime half below is still worth running: it proves the guarded read
# actually survives the freed instance rather than only looking like it should.

const UNIT_SCRIPT_DIR := "res://scripts/units"
# The reference fields that can outlive what they point at.
const VOLATILE_FIELDS := ["attack_target", "attack_source", "carrier", "transport"]
# Types that make an assignment strict enough to raise. A plain `var x = ...`
# or an explicitly Variant one is fine -- that is the fix.
const STRICT_TYPES := ["Node2D", "Node", "Sprite2D", "RTSUnit", "CharacterBody2D", "Area2D"]

const RUNTIME_CASES := [
	{"script": "res://scripts/units/kon_painted_art.gd", "scene": "res://wizard.tscn"},
	{"script": "res://scripts/units/spawner_painted_art.gd", "scene": "res://scenes/units/spawner.tscn"},
	{"script": "res://scripts/units/spawner_drone_art.gd", "scene": "res://scenes/units/spawner_drone.tscn"},
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check_sources():
		return
	if not await _check_runtime():
		return
	print("[PaintedArtStaleTargetSmokeTest] no unit script reads a volatile reference into a typed local, and the art survives its target being freed mid-frame")
	quit(0)

# --- the guard that actually catches the bug --------------------------------

func _check_sources() -> bool:
	var offences: Array[String] = []
	for path in _unit_scripts():
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var line_number := 0
		while not file.eof_reached():
			var line := file.get_line()
			line_number += 1
			var offence := _offending_declaration(line)
			if offence != "":
				offences.append("%s:%d  %s" % [path, line_number, offence])
		file.close()
	if offences.is_empty():
		return true
	_fail("A freed instance assigned to a typed local raises every frame instead of giving null:\n  %s"
		% "\n  ".join(offences))
	return false

func _unit_scripts() -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(UNIT_SCRIPT_DIR)
	if directory == null:
		return paths
	for name in directory.get_files():
		if name.ends_with(".gd"):
			paths.append(UNIT_SCRIPT_DIR.path_join(name))
	return paths

# `var <name>: <StrictType> = <something reading a volatile field>`, on one line.
#
# The two halves are checked separately, and the first version of this did not
# do that: it looked for the field name anywhere on the line and flagged
# RTSUnit's own `var attack_target: Node2D = null`, which is the DECLARATION of
# the field and is exactly right. The field has to appear on the value side --
# that is what makes it a read of something that may already be freed.
func _offending_declaration(line: String) -> String:
	var trimmed := line.strip_edges()
	if not trimmed.begins_with("var ") or not trimmed.contains(":") or not trimmed.contains("="):
		return ""
	var split := trimmed.find("=")
	var declaration := trimmed.substr(4, split - 4)
	var value := trimmed.substr(split + 1)
	var reads_volatile := false
	for field in VOLATILE_FIELDS:
		if value.contains(field):
			reads_volatile = true
			break
	if not reads_volatile:
		return ""
	for type_name in STRICT_TYPES:
		if declaration.contains(": " + type_name) or declaration.contains(":" + type_name):
			return trimmed
	return ""

# --- and a live one, so the guarded read is known to work --------------------

func _check_runtime() -> bool:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "stale-target-smoke", "bad_kon_willow", "build_sandbox")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _gen_wait in 400:
		if map == null or bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 10:
		await process_frame
	var wave_director: Node = scene.get_node_or_null("WaveDirector")

	for case in RUNTIME_CASES:
		var scene_path := str(case["scene"])
		var script_path := str(case["script"])
		if not ResourceLoader.exists(scene_path) or not ResourceLoader.exists(script_path):
			_fail("Missing %s or %s" % [scene_path, script_path])
			return false
		var unit: Node2D = (load(scene_path) as PackedScene).instantiate()
		unit.set("owner_player_id", 1)
		scene.add_child(unit)
		unit.global_position = Vector2(2600, 2600)
		var art: Sprite2D = unit.get_node_or_null("ArtSprite")
		if art == null:
			_fail("%s has no ArtSprite to drive" % scene_path)
			return false
		art.set_script(load(script_path))
		art.call("_ready")
		for _i in 4:
			await process_frame

		var victim: Node2D = wave_director.call("_spawn_enemy", &"poorper",
			Vector2i(41, 41), scene, Vector2.ZERO)
		if victim == null or not is_instance_valid(victim):
			_fail("Could not spawn something for %s to attack" % scene_path)
			return false
		unit.set("attack_target", victim)
		for _i in 3:
			await process_frame

		# The exact window: freed this frame, still referenced, not yet cleared.
		var clock_before := float(art.get("_clock"))
		victim.queue_free()
		for _i in 3:
			await process_frame
		if float(art.get("_clock")) <= clock_before:
			_fail("%s stopped running once its attack target was freed" % script_path)
			return false
		unit.queue_free()
		for _i in 2:
			await process_frame

	scene.queue_free()
	for _i in 2:
		await process_frame
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
