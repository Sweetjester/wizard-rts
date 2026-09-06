extends SceneTree

# Every unit with a momentum mechanic shows its stacks.
#
# The Mounted Knight ran the same build-stacks-to-a-cap mechanic as the Mangler
# and displayed nothing, which made the more important of the two invisible:
# five stacks kindle the Knight's axe for twelve seconds and the player had no
# way to know it was about to happen.
#
# The strip is now one shared implementation, and this checks it through the
# thing the player actually sees -- the PIXELS of the generated texture -- for
# both units. Asserting that a MomentumPips exists would pass on a strip that
# draws nothing, which is the failure a generated texture actually has.
#
# The pip COUNT is read from each unit rather than assumed, because the two
# disagree: the Mangler has a hardcoded five and the Knight reads
# momentum_max_stacks from its catalog entry. That difference is exactly why the
# code was shared instead of copied, so it is worth an assertion.

# Scenes rather than archetypes. WaveDirector._spawn_enemy() substitutes the
# Deom legion scene for any archetype it does not recognise, so asking it for a
# "mangler" hands back a Deom wearing the name -- which has no Mangler art and
# no momentum. Worth knowing about generally; here it just means the test loads
# what it means.
const UNITS := [
	{"archetype": &"mangler", "scene": "res://scenes/units/mangler.tscn"},
	{"archetype": &"mounted_knight", "scene": "res://scenes/units/mounted_knight.tscn"},
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "pips-smoke", "bad_kon_willow", "build_sandbox")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _gen_wait in 400:
		if map == null or bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 10:
		await process_frame
	for entry in UNITS:
		if not await _check_unit(scene, StringName(entry["archetype"]), str(entry["scene"])):
			return

	print("[MomentumPipsSmokeTest] the Mangler and the Mounted Knight both show their momentum, with as many pips as each one actually has and a distinct colour at the cap")
	scene.queue_free()
	quit(0)

func _check_unit(scene: Node, archetype: StringName, scene_path: String) -> bool:
	if not ResourceLoader.exists(scene_path):
		_fail("No scene at %s for %s" % [scene_path, archetype])
		return false
	var unit: Node2D = (load(scene_path) as PackedScene).instantiate()
	unit.set("owner_player_id", 1)
	scene.add_child(unit)
	unit.global_position = Vector2(2600, 2600)
	for _i in 10:
		await process_frame
	# The unit's own movement tick calls reset_momentum() whenever it has no
	# path, so a stack count set from outside is wiped before the art can draw
	# it. Freezing the simulation on this one unit leaves the ART running, which
	# is the half being tested -- the alternative is driving it around the map
	# to build real momentum, which tests the movement code instead.
	unit.set_process(false)
	unit.set_physics_process(false)
	for _i in 3:
		await process_frame

	var art: Node = unit.get_node_or_null("ArtSprite")
	if art == null:
		_fail("%s has no ArtSprite, so nothing can draw its momentum" % archetype)
		return false
	var pips = art.get("_pips")
	if pips == null:
		_fail("%s has a momentum mechanic and no momentum indicator" % archetype)
		return false

	# The unit's own maximum, not an assumed five.
	var maximum: int = int(unit.call("max_momentum_stacks")) if unit.has_method("max_momentum_stacks") \
		else int(unit.get("MAX_MOMENTUM"))
	if maximum <= 0:
		_fail("%s reports %s maximum stacks" % [archetype, maximum])
		return false

	for stacks in [0, maxi(1, maximum / 2), maximum]:
		unit.set("momentum_stacks", stacks)
		for _i in 3:
			await process_frame
		var texture: Texture2D = pips.call("texture")
		if texture == null:
			_fail("%s drew no pip strip at %d stacks" % [archetype, stacks])
			return false
		var image := texture.get_image()
		var lit := _count_lit(image, maximum)
		if lit["pips"] != maximum:
			_fail("%s drew %d pips for a maximum of %d" % [archetype, lit["pips"], maximum])
			return false
		if lit["filled"] != stacks:
			_fail("%s has %d stacks and %d lit pips" % [archetype, stacks, lit["filled"]])
			return false
		# The cap is a different state, not simply a fuller bar.
		var charged: bool = stacks >= maximum
		if charged and not bool(lit["is_charged"]):
			_fail("%s at full stacks does not read as charged; the pips are the ordinary colour" % archetype)
			return false
		if not charged and stacks > 0 and bool(lit["is_charged"]):
			_fail("%s below the cap is already showing the charged colour" % archetype)
			return false

	unit.queue_free()
	for _i in 3:
		await process_frame
	return true

# Reads the middle of each pip cell and classifies it.
func _count_lit(image: Image, maximum: int) -> Dictionary:
	var pips := 0
	var filled := 0
	var charged := false
	var y: int = MomentumPips.PIP_HEIGHT / 2
	for i in maximum:
		var x: int = i * MomentumPips.PIP_PITCH + MomentumPips.PIP_WIDTH / 2
		if x >= image.get_width():
			break
		pips += 1
		var pixel := image.get_pixel(x, y)
		if pixel.is_equal_approx(MomentumPips.COLOR_FILLED):
			filled += 1
		elif pixel.is_equal_approx(MomentumPips.COLOR_CHARGED):
			filled += 1
			charged = true
	return {"pips": pips, "filled": filled, "is_charged": charged}

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
