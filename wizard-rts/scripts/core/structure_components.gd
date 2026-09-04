class_name StructureComponents
extends RefCounted

# Component-based structures (added 2026-09-04, master doc section 39).
#
# A structure is not one hit-point bar. It is a list of COMPONENTS, each with
# its own hit points, that fall independently. Two kinds share the one schema,
# because there is no reason a barracks-inside-a-tower and a wall-of-a-gatehouse
# should be different kinds of object:
#
#   * STRUCTURAL -- foundation, walls, roof, gate. These own cells, so
#     destroying one releases those cells back to navigation. A breached wall
#     becomes a route the enemy can actually path through rather than a hole in
#     a sprite.
#   * FUNCTIONAL -- modules installed into a tower's slots. These own no cells;
#     they provide production or research. Losing one costs the player tempo and
#     Bio, never the run (section 39: a destroyed module frees its slot and can
#     be rebuilt).
#
# Deliberately CHUNKS, NOT BRICKS -- roughly three to eight per building.
# Per-cell destructibility is a different game and a much more expensive one.
#
# Nothing in here reads a rendered mesh. Collision, navigation and destruction
# are authored and authoritative; the visual layer follows them. That is the
# same rule that keeps the 3D view a presentation layer rather than a second
# source of truth, and it holds here for the same reason.
#
# This is a plain RefCounted with no scene or node dependency, so the whole
# destruction model is testable headlessly without standing up a map.

# A structure with no authored components behaves exactly as it did before this
# system existed: one implicit critical component holding all of its HP. That is
# what lets it be adopted building by building instead of all at once.
const IMPLICIT_COMPONENT_ID := &"body"

var slot_capacity: int = 0

# Ordered. Order is meaningful -- see take_damage().
var _components: Array[Dictionary] = []
var _next_module_index: int = 0

func _init(definition: Dictionary = {}) -> void:
	slot_capacity = int(definition.get("module_slots", 0))
	var authored: Array = definition.get("components", [])
	if authored.is_empty():
		_components.append(_make_component({
			"id": IMPLICIT_COMPONENT_ID,
			"hp": int(definition.get("max_hp", 200)),
			"critical": true,
		}))
		return
	for entry in authored:
		_components.append(_make_component(entry))

func _make_component(source: Dictionary) -> Dictionary:
	var hp := int(source.get("hp", 100))
	var depends: Array = source.get("depends_on", [])
	return {
		"id": StringName(source.get("id", &"component")),
		"hp": hp,
		"max_hp": hp,
		"critical": bool(source.get("critical", false)),
		# Local to the structure's footprint, in cells. Empty for modules, which
		# occupy a slot rather than a place.
		"region": source.get("region", Rect2i()),
		"depends_on": depends.duplicate(),
		"module_role": StringName(source.get("module_role", &"")),
		"archetype": StringName(source.get("archetype", &"")),
		"destroyed": false,
	}

# --- queries ----------------------------------------------------------------

func components() -> Array[Dictionary]:
	return _components

func get_component(id: StringName) -> Dictionary:
	for component in _components:
		if component["id"] == id:
			return component
	return {}

func is_destroyed(id: StringName) -> bool:
	var component := get_component(id)
	return component.is_empty() or bool(component["destroyed"])

# The structure is lost when any CRITICAL component falls. Everything else is
# damage the player can recover from, which is the whole point of the split:
# a siege should be able to cost something before it costs the run.
func is_alive() -> bool:
	for component in _components:
		if bool(component["critical"]) and bool(component["destroyed"]):
			return false
	return true

func total_hp() -> int:
	var total := 0
	for component in _components:
		total += int(component["hp"])
	return total

func total_max_hp() -> int:
	var total := 0
	for component in _components:
		total += int(component["max_hp"])
	return total

# Cells still blocking movement, in world-grid coordinates. Only live structural
# components contribute -- this is the function that turns a destroyed wall into
# a hole units can walk through.
func blocked_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var any_region := false
	for component in _components:
		var region: Rect2i = component["region"]
		if region.size.x <= 0 or region.size.y <= 0:
			continue
		any_region = true
		if bool(component["destroyed"]):
			continue
		for x in region.size.x:
			for y in region.size.y:
				var cell := origin + region.position + Vector2i(x, y)
				if not cells.has(cell):
					cells.append(cell)
	if not any_region:
		# No authored regions: fall back to the whole footprint, so structures
		# that have not been given components block exactly what they always did.
		for x in footprint.x:
			for y in footprint.y:
				cells.append(origin + Vector2i(x, y))
	return cells

# --- modules ----------------------------------------------------------------

func used_slots() -> int:
	var used := 0
	for component in _components:
		if component["module_role"] != &"" and not bool(component["destroyed"]):
			used += 1
	return used

func free_slots() -> int:
	return maxi(0, slot_capacity - used_slots())

func module_archetypes() -> Array[StringName]:
	var installed: Array[StringName] = []
	for component in _components:
		if component["module_role"] != &"" and not bool(component["destroyed"]):
			installed.append(component["archetype"])
	return installed

func has_module_role(role: StringName) -> bool:
	for component in _components:
		if component["module_role"] == role and not bool(component["destroyed"]):
			return true
	return false

# Installs a module into a free slot. Returns its component id, or an empty
# StringName if there was no room -- slots are the scarce thing, Bio is only the
# price, so a caller must handle refusal rather than assume success.
func install_module(archetype: StringName, definition: Dictionary) -> StringName:
	if free_slots() <= 0:
		return &""
	var role := StringName(definition.get("module_role", &""))
	if role == &"":
		return &""
	# Ids are unique per installation rather than per archetype, so the same
	# module can be installed twice and destroyed independently.
	var id := StringName("%s_%d" % [archetype, _next_module_index])
	_next_module_index += 1
	# A destroyed module is REMOVED rather than left as a corpse, so its slot is
	# genuinely free again and the structure's HP pool shrinks with it.
	_components.append(_make_component({
		"id": id,
		"hp": int(definition.get("max_hp", 200)),
		"critical": false,
		"module_role": role,
		"archetype": archetype,
	}))
	return id

func remove_module(id: StringName) -> bool:
	for i in _components.size():
		if _components[i]["id"] == id and _components[i]["module_role"] != &"":
			_components.remove_at(i)
			return true
	return false

# --- damage and collapse ----------------------------------------------------

# Damage lands on components in a defined order rather than all at once:
# non-critical structural components absorb first (in authored order), then
# modules, then the critical core. So walls protect the modules and the modules
# are the last thing standing before the structure is lost.
#
# This ordering is deliberately POSITION-INDEPENDENT for now. Which side of a
# building an attack comes from cannot matter until the combat-occlusion layer
# exists, and inventing a directional rule before then would be a guess dressed
# up as a system. When that layer lands, this is the one function that changes.
#
# Returns the ids destroyed by this hit, cascades included.
func take_damage(amount: int) -> Array[StringName]:
	var destroyed: Array[StringName] = []
	var remaining := maxi(0, amount)
	for component in _absorption_order():
		if remaining <= 0:
			break
		var absorbed: int = mini(remaining, int(component["hp"]))
		component["hp"] = int(component["hp"]) - absorbed
		remaining -= absorbed
		if int(component["hp"]) <= 0 and not bool(component["destroyed"]):
			component["destroyed"] = true
			destroyed.append(component["id"])
			if bool(component["critical"]):
				# The structure is gone; nothing further is meaningful.
				return destroyed
	for id in _collapse_unsupported():
		if not destroyed.has(id):
			destroyed.append(id)
	return destroyed

func _absorption_order() -> Array[Dictionary]:
	var structural: Array[Dictionary] = []
	var modules: Array[Dictionary] = []
	var critical: Array[Dictionary] = []
	for component in _components:
		if bool(component["destroyed"]):
			continue
		if bool(component["critical"]):
			critical.append(component)
		elif component["module_role"] != &"":
			modules.append(component)
		else:
			structural.append(component)
	return structural + modules + critical

# Destroys one component outright, then collapses anything it was holding up.
func destroy_component(id: StringName) -> Array[StringName]:
	var component := get_component(id)
	if component.is_empty() or bool(component["destroyed"]):
		return []
	component["hp"] = 0
	component["destroyed"] = true
	var destroyed: Array[StringName] = [id]
	if bool(component["critical"]):
		return destroyed
	for cascaded in _collapse_unsupported():
		if not destroyed.has(cascaded):
			destroyed.append(cascaded)
	return destroyed

# A component whose dependencies have ALL fallen goes with them -- a roof listing
# both walls comes down when the second one does, without anyone shooting the
# roof. Looped until stable so a collapse can chain (walls -> roof -> whatever
# the roof was carrying).
#
# All rather than any: a roof with two walls left standing on one of them is a
# damaged building, not a collapsed one.
func _collapse_unsupported() -> Array[StringName]:
	var destroyed: Array[StringName] = []
	var changed := true
	while changed:
		changed = false
		for component in _components:
			if bool(component["destroyed"]):
				continue
			var depends: Array = component["depends_on"]
			if depends.is_empty():
				continue
			var supported := false
			for dependency_id in depends:
				if not is_destroyed(StringName(dependency_id)):
					supported = true
					break
			if supported:
				continue
			component["hp"] = 0
			component["destroyed"] = true
			destroyed.append(component["id"])
			changed = true
	return destroyed
