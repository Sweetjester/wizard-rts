class_name ControlGroupManager
extends RefCounted

# Numbered control groups (1-9) for Wizard RTS, plus the swarm-specific
# "reinforce group" this project needs and SC2/WC3 don't.
#
# Performance contract (this project has a documented per-frame-cost culture --
# see Decisions_Log 2026-08-23 "two real performance regressions"):
#   * This class has NO _process/_physics_process and is never polled.
#   * Membership is kept correct by an event hook (Node.tree_exiting) rather
#     than by scanning groups every frame for dead units.
#   * No has_method()/get_property_list() anywhere. Node identity and plain
#     property reads only.
#   * The only O(group size) work happens on an explicit player action
#     (assign / recall / a unit finishing training), never on a frame tick.

signal groups_changed()

const GROUP_COUNT := 9
const NO_REINFORCE_GROUP := 0

var _groups: Array = []
var _tracked: Dictionary = {}
var _reinforce_group: int = NO_REINFORCE_GROUP

func _init() -> void:
	for i in GROUP_COUNT:
		_groups.append([] as Array[Node])

static func is_valid_index(index: int) -> bool:
	return index >= 1 and index <= GROUP_COUNT

func assign(index: int, units: Array[Node]) -> int:
	if not is_valid_index(index):
		return 0
	var previous: Array = _groups[index - 1]
	for unit in previous:
		_untrack_if_orphaned(unit, index)
	var fresh: Array[Node] = []
	for unit in units:
		if not is_instance_valid(unit) or fresh.has(unit):
			continue
		fresh.append(unit)
		_track(unit)
	_groups[index - 1] = fresh
	groups_changed.emit()
	return fresh.size()

func add(index: int, units: Array[Node]) -> int:
	if not is_valid_index(index):
		return 0
	var group: Array[Node] = _prune(index)
	var added := 0
	for unit in units:
		if not is_instance_valid(unit) or group.has(unit):
			continue
		group.append(unit)
		_track(unit)
		added += 1
	_groups[index - 1] = group
	if added > 0:
		groups_changed.emit()
	return added

func get_group(index: int) -> Array[Node]:
	if not is_valid_index(index):
		return [] as Array[Node]
	return _prune(index)

func count(index: int) -> int:
	if not is_valid_index(index):
		return 0
	return _prune(index).size()

func has_any() -> bool:
	for i in range(1, GROUP_COUNT + 1):
		if count(i) > 0:
			return true
	return false

func clear_all() -> void:
	for unit in _tracked.values():
		if is_instance_valid(unit):
			_disconnect_leave_hook(unit)
	_tracked.clear()
	for i in GROUP_COUNT:
		_groups[i] = [] as Array[Node]
	_reinforce_group = NO_REINFORCE_GROUP
	groups_changed.emit()

# --- Reinforce group -------------------------------------------------------
# Wizard RTS is one hero plus a large, disposable, constantly-replaced swarm.
# In SC2 a control group is a mostly-stable set you build once; here the army
# is a stream, so the "select the new units and shift-add them to group 1"
# loop is exactly the per-minute APM tax the design doc says to avoid. Flagging
# one group as the reinforce target makes newly trained units join it on their
# own, and reinforce_rally_position() sends them to wherever that army actually
# is right now rather than to a rally point set several fights ago.

func reinforce_group() -> int:
	return _reinforce_group

func set_reinforce_group(index: int) -> void:
	var next := index if is_valid_index(index) else NO_REINFORCE_GROUP
	if next == _reinforce_group:
		return
	_reinforce_group = next
	groups_changed.emit()

func toggle_reinforce_group(index: int) -> bool:
	if not is_valid_index(index):
		return false
	if _reinforce_group == index:
		set_reinforce_group(NO_REINFORCE_GROUP)
		return false
	set_reinforce_group(index)
	return true

func absorb_reinforcement(unit: Node) -> bool:
	if _reinforce_group == NO_REINFORCE_GROUP or not is_instance_valid(unit):
		return false
	return add(_reinforce_group, [unit] as Array[Node]) > 0

func reinforce_rally_position() -> Variant:
	if _reinforce_group == NO_REINFORCE_GROUP:
		return null
	var group := _prune(_reinforce_group)
	var total := Vector2.ZERO
	var counted := 0
	for unit in group:
		if unit is Node2D:
			total += (unit as Node2D).global_position
			counted += 1
	if counted == 0:
		return null
	return total / float(counted)

# --- Internals -------------------------------------------------------------

func _prune(index: int) -> Array[Node]:
	var group: Array[Node] = _groups[index - 1]
	for i in range(group.size() - 1, -1, -1):
		if not is_instance_valid(group[i]):
			group.remove_at(i)
	return group

func _track(unit: Node) -> void:
	var id := unit.get_instance_id()
	if _tracked.has(id):
		return
	_tracked[id] = unit
	unit.tree_exiting.connect(_leave_callable(unit))

func _untrack_if_orphaned(unit: Node, ignore_index: int) -> void:
	if not is_instance_valid(unit):
		return
	for i in range(1, GROUP_COUNT + 1):
		if i == ignore_index:
			continue
		if (_groups[i - 1] as Array).has(unit):
			return
	var id := unit.get_instance_id()
	if not _tracked.has(id):
		return
	_tracked.erase(id)
	_disconnect_leave_hook(unit)

func _leave_callable(unit: Node) -> Callable:
	return _on_tracked_unit_leaving.bind(unit)

func _disconnect_leave_hook(unit: Node) -> void:
	var callable := _leave_callable(unit)
	if unit.tree_exiting.is_connected(callable):
		unit.tree_exiting.disconnect(callable)

# The auto-cleanup hook. Fires once per grouped unit, at the moment it dies --
# not once per frame per group. Ungrouped units cost nothing at all.
func _on_tracked_unit_leaving(unit: Node) -> void:
	_tracked.erase(unit.get_instance_id())
	var changed := false
	for i in GROUP_COUNT:
		var group: Array = _groups[i]
		var at := group.find(unit)
		if at >= 0:
			group.remove_at(at)
			changed = true
	if changed:
		groups_changed.emit()
