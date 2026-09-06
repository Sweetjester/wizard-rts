class_name StructureGarrisonEffects
extends Node

# Units stationed inside a building make that building work faster.
#
# The green cells in the debug view are authored floors -- rooms, galleries,
# wall-walks -- and until now the only thing they were worth was height
# (VantageEffects). This gives the interior a second reason to exist: park
# Oavens in the Splicing Laboratory and it produces faster; park them in the
# Observer Vault and it researches faster. It is the same idea as the vantage
# buff and deliberately shares its shape, so there is one way that "where a unit
# is standing inside a structure" turns into an effect.
#
# WHY THE LATTICE OWNS "WHICH BUILDING", not a footprint test: every nav node
# already records the placement that stamped it, so a unit's cell and level map
# straight to a building instance. Testing the unit's position against each
# building's footprint would be a second answer to the same question, and a
# worse one -- a footprint covers the walls and the tile the door opens onto,
# and a unit standing in a doorway is not inside the building.
#
# WHY "STATIONED" MEANS STOPPED: without it, an Oaven walking through the lab on
# its way somewhere else would flicker the buff on and off, and the player could
# not tell whether the building was crewed. Requiring the unit to have stopped
# makes it a deliberate act -- you post units to a building the way you post
# them to a wall -- and it is legible from outside: the ones standing still in
# the windows are the ones working.
#
# Cost: one dictionary lookup per player unit per tick, throttled, and the
# result is a small dictionary that BuildSystem reads. No physics, no queries.

# What one stationed worker is worth, and how many a building can use. Chosen so
# a full crew is a real decision (a meaningfully faster lab) without making
# un-crewed buildings feel broken, and so the fourth Oaven is better used
# fighting -- a cap the player can feel is more legible than diminishing returns
# they have to infer.
const RATE_PER_WORKER := 0.20
const MAX_WORKERS := 3
const TICK_SECONDS := 0.25

@export var enabled: bool = true

var bridge: Node
var terrain: Node

# instance id -> how many stationed workers, capped. Read by BuildSystem.
var _workers: Dictionary = {}
var _elapsed := 0.0

func _ready() -> void:
	bridge = get_parent().get_node_or_null("BlockNavBridge")
	terrain = get_parent().get_node_or_null("MapGenerator")

func _process(delta: float) -> void:
	if not enabled or bridge == null or terrain == null:
		return
	_elapsed += delta
	if _elapsed < TICK_SECONDS:
		return
	_elapsed = 0.0
	_recount()

# How many workers are stationed in a placed structure right now.
func workers_in(instance_id: StringName) -> int:
	if instance_id == &"":
		return 0
	return int(_workers.get(instance_id, 0))

# The multiplier a building's timed work runs at: 1.0 with nobody in it.
func rate_multiplier_for(instance_id: StringName) -> float:
	return 1.0 + RATE_PER_WORKER * float(workers_in(instance_id))

# Recounted wholesale rather than tracked by enter/leave events.
#
# Events would need a hook on every way a unit can stop being stationed --
# ordered away, killed, banished, boarded onto a blimp, evolved into something
# else -- and the first one missed leaves a building permanently crewed by a
# unit that died ten minutes ago. A count over the live units cannot drift,
# because there is nothing to drift from.
func _recount() -> void:
	if bridge.get("world") == null:
		return
	var counts := {}
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or not (unit is Node2D):
			continue
		if not _is_working(unit):
			continue
		var cell: Vector2i = terrain.call("world_to_cell", (unit as Node2D).global_position)
		var level: int = int(unit.get("nav_level"))
		var instance: StringName = bridge.call("structure_instance_at", cell, level)
		if instance == &"":
			continue
		counts[instance] = mini(MAX_WORKERS, int(counts.get(instance, 0)) + 1)
	_workers = counts

func _is_working(unit: Node) -> bool:
	# Not everything in the units group is an RTSUnit. Asking a node that has no
	# unit_archetype returns null, and StringName(null) is an error rather than
	# an empty name -- the same trap the vantage tick hit.
	if unit.get("unit_archetype") == null:
		return false
	if int(unit.get("owner_player_id")) != 1:
		return false
	if UnitCatalog.garrison_work_of(StringName(unit.get("unit_archetype"))) <= 0.0:
		return false
	if bool(unit.get("moving")):
		return false
	# A unit that is fighting is fighting, not working -- otherwise a building
	# under attack would speed up while its defenders were busy dying in it.
	if StringName(unit.get("unit_state")) == &"attacking":
		return false
	if unit.has_method("is_banished") and bool(unit.call("is_banished")):
		return false
	return int(unit.get("health")) > 0
