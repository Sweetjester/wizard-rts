class_name CitadelGarrison
extends Node

# The force holding Kon's Arcane Citadel, and the capture it gates.
#
# Master doc section 40 says the reward for taking the citadel is GROUND, not
# loot -- walls, a gatehouse choke, wall-walks and a keep. That only means
# anything if the ground is held. An empty fortress is a free quarter of the
# map, which inverts the risk the map type exists to create.
#
# So the garrison is placed on the citadel's OWN authored positions rather than
# scattered near it. Archers stand on the wall-walks because the structure
# declares wall-walks; the gate is held because the structure declares a gate
# passage; the keep has a core because the structure has a keep. The defence
# reads as a garrison rather than as a spawn ring, and it does so without any
# per-map hand placement -- change the YAML and the defence moves with it.
#
# CAPTURE is deliberately "clear the garrison", not "destroy a building". There
# is no building to destroy: the citadel is terrain the player wants intact.

signal citadel_captured(plot_id: String)

# Which nav region each post type draws from, and what stands there. Regions
# come from the authored structure, so this survives the citadel being re-authored
# as long as it still has walls, a gate and a keep.
#
# Posts name a WEIGHT rather than a unit. Which unit stands there is the current
# enemy faction's answer to "a body" or "a heavy", asked of the WaveDirector, so
# switching the faction re-garrisons the citadel instead of leaving the previous
# enemy holding the walls of a map whose waves have already changed.
const POSTS := [
	{"region": &"wall_walk_outer_ring_nav", "weight": &"light", "count": 8,
		"role": "wall line -- the reason taking this from outside is expensive"},
	{"region": &"main_gate_tunnel_nav", "weight": &"heavy", "count": 3,
		"role": "gate holders, in the one place the player must come through"},
	{"region": &"south_courtyard_nav", "weight": &"light", "count": 4,
		"role": "courtyard reserve"},
	{"region": &"keep_plinth_ring_nav", "weight": &"heavy", "count": 3,
		"role": "plinth guard"},
	{"region": &"keep_ground_floor_nav", "weight": &"heavy", "count": 2,
		"role": "keep core -- the last thing standing"},
]

@export var enabled: bool = true

var bridge: Node
var wave_director: Node
var map_generator: Node

var _defenders: Array[Node] = []
var _plot_id: String = ""
var _captured := false
var _spawned := false

func _ready() -> void:
	bridge = get_parent().get_node_or_null("BlockNavBridge")
	wave_director = get_parent().get_node_or_null("WaveDirector")
	map_generator = get_parent().get_node_or_null("MapGenerator")
	if bridge != null and bridge.has_signal("structures_placed"):
		bridge.connect("structures_placed", _on_structures_placed)

func _on_structures_placed(placements: Array) -> void:
	if not enabled or _spawned:
		return
	for placement in placements:
		if StringName(placement.get("id", &"")) == &"kons_arcane_citadel_01":
			_spawn_garrison(placement)
			return

# The unit that stands at a post, resolved from the current enemy faction.
func _archetype_for(post: Dictionary) -> StringName:
	var method := "enemy_heavy_archetype" if StringName(post["weight"]) == &"heavy" else "enemy_light_archetype"
	if wave_director == null or not wave_director.has_method(method):
		return &"deom_blade"
	return StringName(wave_director.call(method))

# Posts are drawn from the placed structure's nav cells, spread out rather than
# clustered: a defence bunched on one wall is a defence with a free side.
func _spawn_garrison(placement: Dictionary) -> void:
	if wave_director == null or map_generator == null or bridge == null:
		return
	_spawned = true
	_plot_id = _find_plot_id(placement.get("origin", Vector2i.ZERO))
	var definition: BlockStructureDefinition = bridge.get("library").get_definition(&"kons_arcane_citadel_01")
	if definition == null:
		return
	var origin: Vector2i = placement.get("origin", Vector2i.ZERO)
	var target: Vector2 = _player_world()
	for post in POSTS:
		var cells := _spread_cells(definition, post["region"], int(post["count"]))
		for cell in cells:
			var world_cell: Vector2i = origin + Vector2i(cell.x, cell.z)
			var spawned: Node = wave_director.call(
				"_spawn_enemy", _archetype_for(post), world_cell, get_parent(), target)
			if spawned == null or not is_instance_valid(spawned):
				continue
			# A garrison HOLDS. Without this they walk out to the player's base
			# and the citadel empties itself, which is the opposite of a fortress.
			#
			# Deferred, because WaveDirector._spawn_enemy() itself defers an
			# attack-move order at the player's base. Setting hold inline is
			# silently undone a frame later -- which is exactly how this first
			# presented: twenty defenders spawned, none of them holding.
			call_deferred("_post_defender", spawned, cell.y)
			_defenders.append(spawned)
	print("[CitadelGarrison] %d defenders posted across %d authored regions of the citadel"
		% [_defenders.size(), POSTS.size()])

# Runs after the wave director's own deferred order, and undoes it.
func _post_defender(unit: Node, level: int) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	# The unit's own hold order, rather than writing command_mode by hand.
	# Setting the field directly worked but skipped everything else the order
	# does -- clearing the flow-field order, the attack target and the path --
	# and issue_stop_order() afterwards then reset the mode to "idle", which is
	# how this presented the second time: deferred correctly, still not holding.
	if unit.has_method("issue_hold_position_order"):
		unit.call("issue_hold_position_order")
	else:
		unit.set("command_mode", &"hold")
	unit.set("nav_level", level)

# Evenly-spaced picks from a region's cells, so eight archers cover a wall
# rather than standing on each other.
func _spread_cells(definition: BlockStructureDefinition, region_id: StringName, count: int) -> Array[Vector3i]:
	var candidates: Array[Vector3i] = []
	for cell in definition.nav_cells:
		if definition.nav_cells[cell].get("region_id", &"") == region_id:
			candidates.append(cell)
	candidates.sort()
	var picked: Array[Vector3i] = []
	if candidates.is_empty() or count <= 0:
		return picked
	var stride: int = maxi(1, candidates.size() / count)
	for i in range(0, candidates.size(), stride):
		picked.append(candidates[i])
		if picked.size() >= count:
			break
	return picked

func _find_plot_id(origin: Vector2i) -> String:
	for plot in map_generator.get("plots"):
		if str(plot.get("block_structure", "")) == "kons_arcane_citadel_01":
			return str(plot.get("id", ""))
	return ""

func _player_world() -> Vector2:
	for structure in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and structure is Node2D and int(structure.get("owner_player_id")) == 1:
			return (structure as Node2D).global_position
	return Vector2.ZERO

# --- capture ----------------------------------------------------------------

func _process(_delta: float) -> void:
	if _captured or not _spawned or _defenders.is_empty():
		return
	for i in range(_defenders.size() - 1, -1, -1):
		if not is_instance_valid(_defenders[i]):
			_defenders.remove_at(i)
	if _defenders.is_empty():
		_captured = true
		print("[CitadelGarrison] citadel captured -- the keep plinth will accept a re-summoned tower")
		citadel_captured.emit(_plot_id)

func is_captured() -> bool:
	return _captured

func defenders_remaining() -> int:
	return _defenders.size()

# The cell a re-summoned wizard tower goes on: the centre of the keep's own
# floor, read from the structure rather than hardcoded.
func keep_plinth_cell() -> Vector2i:
	if bridge == null or bridge.get("world") == null:
		return Vector2i(-1, -1)
	for placement in bridge.get("world").placements():
		if placement.get("structure", &"") != &"kons_arcane_citadel_01":
			continue
		var origin: Vector2i = placement.get("origin", Vector2i.ZERO)
		var definition: BlockStructureDefinition = bridge.get("library").get_definition(&"kons_arcane_citadel_01")
		var sum := Vector2i.ZERO
		var count := 0
		for cell in definition.nav_cells:
			if definition.nav_cells[cell].get("region_id", &"") == &"keep_ground_floor_nav":
				sum += Vector2i(cell.x, cell.z)
				count += 1
		if count > 0:
			return origin + sum / count
	return Vector2i(-1, -1)
