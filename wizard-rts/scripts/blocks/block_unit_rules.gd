class_name BlockUnitRules
extends RefCounted

# Unit-class capabilities, in one place.
#
# Both the per-structure navigation and the world-level nav lattice need to ask
# the same questions -- can this class use stairs, how big is its footprint, does
# it ignore ground movement -- and two implementations of that would eventually
# disagree. A unit that can climb a structure's stairs in isolation but not once
# the structure is placed on a map is the kind of bug nobody can reproduce.
#
# So this is the single answer, and both callers use it.

# Link type -> the capability flag that permits it. A type absent from this map
# is permitted to any class the link's own `allowed` list names.
const LINK_PERMISSION := {
	&"STAIR": "can_use_stairs",
	&"RAMP": "can_use_ramps",
	&"LADDER": "can_use_ladders",
	&"CLIMB_POINT": "can_use_climb_points",
	&"PORTAL": "can_use_portals",
}

var _classes: Dictionary = {}
var _resolved: Dictionary = {}

func _init(unit_classes: Dictionary) -> void:
	_classes = unit_classes

# Resolves `inherits` (archer inherits infantry) and caches the result. One
# level deep, which is all the spec uses; a deeper chain would need a loop guard
# and is not silently supported.
func data_for(unit_class: StringName) -> Dictionary:
	if _resolved.has(unit_class):
		return _resolved[unit_class]
	var data: Dictionary = _classes.get(str(unit_class), {})
	var inherits := str(data.get("inherits", ""))
	if not inherits.is_empty():
		var base: Dictionary = _classes.get(inherits, {}).duplicate()
		for key in data:
			if key != "inherits":
				base[key] = data[key]
		data = base
	_resolved[unit_class] = data
	return data

func is_flying(unit_class: StringName) -> bool:
	return bool(data_for(unit_class).get("ignores_ground_navigation", false))

func footprint_of(unit_class: StringName) -> Vector2i:
	var footprint: Array = data_for(unit_class).get("footprint", [1, 1])
	return Vector2i(int(footprint[0]), int(footprint[1]))

func max_drop(unit_class: StringName) -> int:
	return int(data_for(unit_class).get("max_drop_blocks", 0))

func can_pass_open_gates(unit_class: StringName) -> bool:
	return bool(data_for(unit_class).get("can_pass_open_gates", true))

# Whether a class may use an authored link. Checks three things, in order of how
# often they reject: the link's own allowed list, the class capability the link
# type requires, and -- for drops -- how far the class will fall.
func link_admits(link: Dictionary, unit_class: StringName) -> bool:
	var allowed: Array = link.get("allowed", [])
	if not allowed.is_empty() and not allowed.has(str(unit_class)):
		return false
	var capability := str(LINK_PERMISSION.get(link.get("type", &""), ""))
	if not capability.is_empty() and not bool(data_for(unit_class).get(capability, false)):
		return false
	if link.get("type", &"") == &"DROP_EDGE":
		var drop: int = absi(int(link["from"].y) - int(link["to"].y)) if link["from"] is Vector3i \
			else absi(int(link.get("drop", 0)))
		if drop > max_drop(unit_class):
			return false
	# A link narrower than the class's footprint cannot carry it. Wider is fine.
	var width := int(link.get("width", 1))
	if width > 0 and footprint_of(unit_class).x > width:
		return false
	return true
