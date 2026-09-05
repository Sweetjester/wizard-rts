class_name VantageEffects
extends Node

# Standing somewhere high inside a structure should be worth something.
#
# The block lattice already knows every walkable cell a structure declares and
# how far above the ground it sits -- wall-walks, galleries, balconies, the
# observatory crown. Those are the green cells in the debug view, and they are
# exactly the positions a defender would want. This turns that geometry into a
# reason to go up there.
#
# WHY ELEVATION RATHER THAN AN AUTHORED FLAG: every structure already says where
# its floors are and how high. Asking authors to also mark which floors "count"
# would be a second source of truth, free to disagree with the first, and it
# would have to be maintained for each of the fourteen structures and anything
# added later. Height is the property that makes a position a firing step, so
# height is what is read. A gate tunnel at ground level is inside a building and
# is not a vantage; a wall-walk four levels up is.
#
# The effect is deliberately small and legible: a range bonus that scales with
# height, and -- for units that declare one -- a different weapon entirely.
#
# Cost: one dictionary lookup per player unit per tick, throttled. No physics,
# no raycasts, no per-frame work.

# How far above the ground a floor has to be before it counts. One level is a
# doorstep; two is a storey.
const MIN_HEIGHT := 2
# Range added per level of height, in cells, capped so a tall tower does not
# turn an archer into artillery.
const RANGE_CELLS_PER_LEVEL := 0.4
const MAX_RANGE_CELLS := 3.0
const TICK_SECONDS := 0.25

@export var enabled: bool = true

var bridge: Node
var terrain: Node

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
	_apply()

func _apply() -> void:
	if bridge.get("world") == null:
		return
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or not (unit is Node2D):
			continue
		# Not everything in the units group is an RTSUnit -- asking a node that
		# has no vantage_height for one returns null, and int(null) is an error
		# rather than a zero.
		if unit.get("vantage_height") == null:
			continue
		var cell: Vector2i = terrain.call("world_to_cell", (unit as Node2D).global_position)
		var level: int = int(unit.get("nav_level"))
		var vantage: Dictionary = bridge.call("vantage_at", cell, level)
		var height: int = int(vantage.get("height", 0)) if not vantage.is_empty() else 0
		_set_unit_vantage(unit, height, StringName(vantage.get("region", &"")))

# Applied by SETTING state on the unit rather than by mutating its stats.
#
# A bonus written straight into attack_range cannot be taken away reliably --
# every other system that touches range would have to know it was there, and a
# unit that dies or is banished mid-tick keeps it forever. The unit reads
# vantage_height when it computes its own range, the same way it already reads
# its observer aura, so leaving the wall-walk removes the bonus by arithmetic.
func _set_unit_vantage(unit: Node, height: int, region: StringName) -> void:
	var effective: int = height if height >= MIN_HEIGHT else 0
	if int(unit.get("vantage_height")) != effective:
		unit.set("vantage_height", effective)
		unit.set("vantage_region", region)
		_update_weapon(unit, effective)

# Some units carry a second weapon they only bring out from a fixed position.
#
# The Oaven's blowpipe becomes a heavy blowpipe on a wall: slower, longer, and
# harder hitting -- a static defence piece rather than a skirmishing weapon. It
# is declared on the archetype, so any unit can be given one without this file
# knowing which.
func _update_weapon(unit: Node, height: int) -> void:
	if not unit.has_method("set_weapon_mode"):
		return
	var definition := UnitCatalog.get_definition(StringName(unit.get("unit_archetype")))
	var vantage_mode := StringName(definition.get("vantage_weapon_mode", &""))
	if vantage_mode == &"":
		return
	if height > 0:
		# Remember what they had, so coming down restores it rather than
		# guessing at a default they may never have been on.
		if StringName(unit.get("weapon_mode")) != vantage_mode:
			unit.set_meta("vantage_previous_weapon", unit.get("weapon_mode"))
			unit.call("set_weapon_mode", vantage_mode)
		return
	if StringName(unit.get("weapon_mode")) != vantage_mode:
		return
	var previous := StringName(unit.get_meta("vantage_previous_weapon",
		definition.get("default_weapon_mode", &"")))
	if previous != &"":
		unit.call("set_weapon_mode", previous)
