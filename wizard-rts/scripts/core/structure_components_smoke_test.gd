extends SceneTree

# Component-based structure destruction (master doc section 39).
#
# Asserted here rather than through a live map on purpose: StructureComponents
# is a plain RefCounted with no scene dependency, so the whole destruction model
# -- absorption order, critical loss, dependency collapse, module slots, and the
# navigation cells a breach opens -- is verifiable without standing up a map or
# a renderer. Nothing in this file touches the rendering server, which is what
# made an earlier 3D assertion pass vacuously (see the 2026-09-03 entry).

const GATEHOUSE := {
	"max_hp": 900,
	"footprint": Vector2i(3, 3),
	"components": [
		{"id": &"west_wall", "hp": 100, "region": Rect2i(0, 0, 1, 3)},
		{"id": &"east_wall", "hp": 100, "region": Rect2i(2, 0, 1, 3)},
		{"id": &"roof", "hp": 80, "region": Rect2i(1, 0, 1, 3), "depends_on": [&"west_wall", &"east_wall"]},
		{"id": &"core", "hp": 200, "critical": true, "region": Rect2i(1, 1, 1, 1)},
	],
}

const TOWER := {
	"max_hp": 700,
	"footprint": Vector2i(3, 3),
	"module_slots": 2,
	"components": [
		{"id": &"shell", "hp": 150, "region": Rect2i(0, 0, 3, 3)},
		{"id": &"core", "hp": 300, "critical": true, "region": Rect2i(1, 1, 1, 1)},
	],
}

const PRODUCTION_MODULE := {"max_hp": 120, "module_role": &"production"}
const RESEARCH_MODULE := {"max_hp": 120, "module_role": &"research"}

func _initialize() -> void:
	if not _check_absorption_order():
		return
	if not _check_dependency_collapse():
		return
	if not _check_navigation_opens():
		return
	if not _check_module_slots():
		return
	if not _check_legacy_structures_unchanged():
		return
	print("[StructureComponentsSmokeTest] components absorb, collapse, free navigation and hold module slots")
	quit(0)

# Walls protect the modules; the modules are the last thing standing before the
# structure is lost. A hit that would kill the whole building outright must not
# skip straight to the critical core while a wall is still up.
func _check_absorption_order() -> bool:
	var structure := StructureComponents.new(GATEHOUSE)
	var destroyed := structure.take_damage(100)
	if not destroyed.has(&"west_wall"):
		_fail("100 damage should destroy the first wall, got %s" % [destroyed])
		return false
	if not structure.is_alive():
		_fail("Losing a non-critical wall must not destroy the structure")
		return false
	if structure.is_destroyed(&"core"):
		_fail("Damage reached the critical core while a wall was still standing")
		return false
	return true

# A roof listing both walls comes down when the SECOND one does, without anyone
# shooting the roof. One wall standing is a damaged building, not a collapsed one.
func _check_dependency_collapse() -> bool:
	var structure := StructureComponents.new(GATEHOUSE)
	structure.destroy_component(&"west_wall")
	if structure.is_destroyed(&"roof"):
		_fail("The roof collapsed with one wall still standing")
		return false
	var destroyed := structure.destroy_component(&"east_wall")
	if not destroyed.has(&"roof"):
		_fail("The roof should collapse once both walls are gone, got %s" % [destroyed])
		return false
	if not structure.is_alive():
		_fail("A roof collapse must not end the structure -- only a critical component does")
		return false
	# And the critical component still ends it.
	if structure.is_alive() != true or not structure.destroy_component(&"core").has(&"core"):
		_fail("Destroying the core should report the core destroyed")
		return false
	if structure.is_alive():
		_fail("The structure must be lost once its critical component falls")
		return false
	return true

# The point of authored regions: a breached wall is a route units can path
# through, not just a hole in a sprite.
func _check_navigation_opens() -> bool:
	var origin := Vector2i(10, 10)
	var structure := StructureComponents.new(GATEHOUSE)
	var before := structure.blocked_cells(origin, Vector2i(3, 3))
	if not before.has(Vector2i(10, 11)):
		_fail("The west wall should block its own cells, got %s" % [before])
		return false
	structure.destroy_component(&"west_wall")
	var after := structure.blocked_cells(origin, Vector2i(3, 3))
	if after.has(Vector2i(10, 11)):
		_fail("A destroyed wall must release its cells back to navigation")
		return false
	if after.size() >= before.size():
		_fail("Breaching a wall should reduce the blocked cell count (%s -> %s)" % [before.size(), after.size()])
		return false
	# The rest of the building still blocks.
	if not after.has(Vector2i(12, 11)):
		_fail("Destroying the west wall must not open the east wall's cells")
		return false
	return true

# Slots are the scarce thing; Bio is only the price. A destroyed module frees
# its slot and can be rebuilt -- permanent slot loss would turn one bad siege
# into an unrecoverable run.
func _check_module_slots() -> bool:
	var structure := StructureComponents.new(TOWER)
	if structure.free_slots() != 2:
		_fail("Tower should start with 2 free slots, got %s" % structure.free_slots())
		return false
	var first := structure.install_module(&"biospawner", PRODUCTION_MODULE)
	var second := structure.install_module(&"observer_vault", RESEARCH_MODULE)
	if first == &"" or second == &"":
		_fail("Both modules should install into an empty 2-slot tower")
		return false
	if structure.free_slots() != 0:
		_fail("Two installed modules should fill a 2-slot tower")
		return false
	# Refusal, not silent success -- the caller has to handle a full tower.
	if structure.install_module(&"biospawner", PRODUCTION_MODULE) != &"":
		_fail("A full tower must refuse a third module")
		return false
	if not structure.has_module_role(&"production"):
		_fail("The tower should report the production role it has installed")
		return false

	structure.destroy_component(first)
	if structure.has_module_role(&"production"):
		_fail("A destroyed production module must stop providing its role")
		return false
	if structure.is_alive() != true:
		_fail("Losing a module must not lose the tower")
		return false
	# The slot is genuinely free again, and rebuildable.
	structure.remove_module(first)
	if structure.free_slots() != 1:
		_fail("Removing a destroyed module should free its slot, got %s" % structure.free_slots())
		return false
	if structure.install_module(&"biospawner", PRODUCTION_MODULE) == &"":
		_fail("A freed slot should accept a rebuilt module")
		return false
	return true

# Adoption has to be building-by-building: a structure with no authored
# components must behave exactly as it did before this system existed.
func _check_legacy_structures_unchanged() -> bool:
	var structure := StructureComponents.new({"max_hp": 260})
	if structure.total_max_hp() != 260:
		_fail("An un-authored structure should hold all of its HP, got %s" % structure.total_max_hp())
		return false
	if structure.blocked_cells(Vector2i(4, 4), Vector2i(2, 2)).size() != 4:
		_fail("An un-authored structure should block its whole footprint")
		return false
	if not structure.take_damage(260).has(StructureComponents.IMPLICIT_COMPONENT_ID):
		_fail("An un-authored structure should die at exactly its max HP")
		return false
	if structure.is_alive():
		_fail("An un-authored structure's implicit component is critical")
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
