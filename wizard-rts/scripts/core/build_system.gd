class_name BuildSystem
extends Node2D

const STRUCTURE_PREVIEW_TEXTURES := {
	&"wizard_tower": preload("res://assets/buildings/kon/wizard_tower.png"),
	&"bio_absorber": preload("res://assets/buildings/kon/bio_absorber.png"),
	&"barracks": preload("res://assets/buildings/kon/barracks.png"),
	&"terrible_vault": preload("res://assets/buildings/kon/terrible_vault.png"),
	&"vinewall": preload("res://assets/buildings/kon/vinewall_segment.png"),
	&"bio_launcher": preload("res://assets/buildings/kon/bio_launcher_rooted.png"),
}
const USE_PLACEHOLDER_BUILDING_PREVIEWS := false

signal structure_placed(player_id: int, archetype: StringName, cell: Vector2i)
signal structure_completed(player_id: int, archetype: StringName, cell: Vector2i)
signal build_rejected(reason: String)
signal unit_training_queued(player_id: int, producer: Node, archetype: StringName, queue_count: int)
signal unit_produced(player_id: int, archetype: StringName, cell: Vector2i)
# Same event as unit_produced, but carries the spawned node. unit_produced is
# left exactly as-is so existing HUD/telemetry listeners are untouched; the
# control-group "reinforce group" needs the actual unit, not just its cell.
signal unit_trained(player_id: int, archetype: StringName, unit: Node)
signal upgrade_researched(player_id: int, upgrade_id: StringName)
signal tier_unlocked(player_id: int, tier: int)
signal forbidden_unleashed(player_id: int, unit: Node)
signal module_installed(player_id: int, archetype: StringName)
signal module_destroyed(player_id: int, module_id: StringName)
signal tower_resummoned(cell: Vector2i)

@export var economy_manager_path: NodePath = NodePath("../EconomyManager")
@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var simulation_runner_path: NodePath = NodePath("../SimulationRunner")
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var terrible_thing_scene: PackedScene = preload("res://scenes/units/terrible_thing.tscn")
@export var oaven_spear_scene: PackedScene = preload("res://scenes/units/oaven_spear.tscn")
@export var horror_scene: PackedScene = preload("res://scenes/units/horror.tscn")
@export var apex_scene: PackedScene = preload("res://scenes/units/apex.tscn")
@export var spawner_scene: PackedScene = preload("res://scenes/units/spawner.tscn")
@export var stone_face_serpent_scene: PackedScene = preload("res://scenes/units/stone_face_serpent.tscn")
@export var the_forbidden_scene: PackedScene = preload("res://scenes/units/the_forbidden.tscn")

var economy_manager: EconomyManager
var map_generator: Node
var simulation_runner: SimulationRunner
var rts_world: RTSWorld
var structures: Array[Dictionary] = []
var pending_archetype: StringName = &""
var _dragging_wall := false
var _wall_drag_start := Vector2i.ZERO
var _wall_drag_end := Vector2i.ZERO
const UPGRADE_MAX_RANK := {
	&"thorned_vines": 3,
	&"hardened_horrors": 3,
	&"launcher_bile": 3,
	&"accelerated_evolution": 1,
	# Observer Vault research proper -- the roster doc's "researches ways to
	# upgrade Kon's observer abilities". The four above are evolution-side
	# upgrades that predate the doc and are left exactly as they were.
	&"observer_sight": 3,
	# Raises the intelligence of every KoN unit by one rank, capped at Bound (3).
	# Observer magic is what lets Kon direct the forbidden at all, so buying
	# obedience is the thematically right research to sit in this building.
	&"observer_command": 2,
	&"observer_oversight": 3,
	&"tier_two_hybrids": 1,
	&"tier_three_hybrids": 1,
}

# Tier 2 and 3 of the KoN roster sit behind these. Tier 1 (Oaven) is free from
# the first minute; tier 4 (The Forbidden) is never trained, it is unleashed.
const TIER_UNLOCK_UPGRADES := {
	2: &"tier_two_hybrids",
	3: &"tier_three_hybrids",
}

var researched_upgrade_ranks: Dictionary = {}
var _launcher_elapsed := 0.0
var _map_3d_view: Node
var _heal_aura_elapsed := 0.0

func _ready() -> void:
	economy_manager = get_node_or_null(economy_manager_path)
	map_generator = get_node_or_null(map_generator_path)
	simulation_runner = get_node_or_null(simulation_runner_path)
	rts_world = get_node_or_null(rts_world_path)
	z_index = 120

func _process(delta: float) -> void:
	_sync_structure_damage_and_cleanup()
	_update_construction(delta)
	_update_production(delta)
	_update_structure_evolution(delta)
	_update_structure_regeneration(delta)
	_update_bio_launchers(delta)
	_update_absorber_heal_auras(delta)
	_update_3d_placement_preview()
	if pending_archetype == &"vinewall" and _dragging_wall:
		_wall_drag_end = map_generator.world_to_cell(_placement_mouse_position())
		queue_redraw()
	elif pending_archetype != &"":
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if pending_archetype == &"":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: Vector2i = map_generator.world_to_cell(_placement_mouse_position())
		if pending_archetype == &"vinewall":
			if event.pressed:
				_dragging_wall = true
				_wall_drag_start = cell
				_wall_drag_end = cell
			else:
				_place_vinewall_drag(1, _wall_drag_start, cell)
				_dragging_wall = false
				pending_archetype = &""
		elif event.pressed:
			try_place_structure(1, pending_archetype, cell)
			pending_archetype = &""
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		rotate_placement(1)
		_update_3d_placement_preview()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		pending_archetype = &""
		_dragging_wall = false
		queue_redraw()
		get_viewport().set_input_as_handled()

# Placement follows the cursor, and in the 3D view the cursor has to be
# projected onto the ground plane before it means anything in simulation space.
# Same bridge SelectionController uses, so both agree on where the mouse is.
# The 2D placement preview is drawn in _draw(), which never runs in the 3D view
# because this node is hidden along with the rest of the 2D presentation. The
# same footprint is pushed to the 3D view as translucent pads instead -- without
# this, building in 3D is placing blind.
func _update_3d_placement_preview() -> void:
	if _map_3d_view == null or not is_instance_valid(_map_3d_view):
		_map_3d_view = get_node_or_null(NodePath("../Map3DView"))
	if _map_3d_view == null or not is_instance_valid(_map_3d_view) or not _map_3d_view.has_method("update_placement_preview"):
		return
	if pending_archetype == &"" or map_generator == null:
		_map_3d_view.call("clear_placement_preview")
		return
	if pending_archetype == &"vinewall" and _dragging_wall:
		var wall_cells := _line_cells(_wall_drag_start, _wall_drag_end)
		var wall_valid := not wall_cells.is_empty()
		for cell in wall_cells:
			if not _can_place(&"vinewall", cell):
				wall_valid = false
				break
		_map_3d_view.call("update_placement_preview", wall_cells, wall_valid)
		return
	var target: Vector2i = map_generator.world_to_cell(_placement_mouse_position())
	_map_3d_view.call("update_placement_preview", get_placement_cells(pending_archetype, target), _can_place(pending_archetype, target))

func _placement_mouse_position() -> Vector2:
	if _map_3d_view == null or not is_instance_valid(_map_3d_view):
		_map_3d_view = get_node_or_null(NodePath("../Map3DView"))
	if _map_3d_view != null and is_instance_valid(_map_3d_view) and _map_3d_view.has_method("screen_to_sim_position"):
		return _map_3d_view.call("screen_to_sim_position", get_viewport().get_mouse_position())
	return get_global_mouse_position()

func set_rally_point_for_structure(producer_node: Node, world_pos: Vector2) -> bool:
	var index := _structure_index_for_node(producer_node)
	if index < 0:
		return false
	if not _produces_units(structures[index]):
		return false
	structures[index]["rally_point"] = world_pos
	var node: KonStructure = structures[index].get("node", null)
	if node != null and is_instance_valid(node):
		node.set_rally_point(world_pos)
	return true

# Quarter turns applied to the pending building. Reset on every new placement so
# a rotation never leaks from one building to the next.
var pending_rotation := 0

# The footprint a building occupies at its current rotation. A quarter turn
# swaps width and depth, and everything that asks "does this fit" and "which
# cells does it cover" has to ask about the TURNED shape or a rotated building
# validates against its unrotated self.
func rotated_footprint(archetype: StringName, rotation_steps: int) -> Vector2i:
	var footprint: Vector2i = _base_footprint(archetype)
	if ((rotation_steps % 4) + 4) % 4 % 2 == 1:
		return Vector2i(footprint.y, footprint.x)
	return footprint

# A building that carries a block structure takes its footprint FROM that
# runtime structure, not the full-size design master. This also keeps rotated
# placement previews and footprint reservations aligned with the compact art.
func _base_footprint(archetype: StringName) -> Vector2i:
	var definition := UnitCatalog.get_definition(archetype)
	var structure_id := StringName(definition.get("block_structure", &""))
	if structure_id != &"":
		var bridge: Node = get_parent().get_node_or_null("BlockNavBridge") if get_parent() != null else null
		if bridge != null and bridge.get("library") != null:
			var block_definition = bridge.get("library").get_definition(structure_id)
			if block_definition != null:
				return Vector2i(int(block_definition.dimensions.x), int(block_definition.dimensions.z))
	return definition.get("footprint", Vector2i.ONE)

# Buildings come out of the menu facing the player.
#
# Structures are authored with their door on a particular side -- the
# laboratory's muster gate faces south -- and a building dropped down with its
# entrance pointing away is both ugly and actively annoying: units walk the whole
# way around it to get in. Since the player is almost always looking at their own
# base from the camera's side, the useful default is the door turned toward the
# wizard who is building it.
#
# R still rotates from there; this only changes where the cycle starts.
func _default_rotation_for(archetype: StringName) -> int:
	var structure_id := StringName(UnitCatalog.get_definition(archetype).get("block_structure", &""))
	if structure_id == &"":
		return 0
	var bridge: Node = get_parent().get_node_or_null("BlockNavBridge") if get_parent() != null else null
	if bridge == null or bridge.get("library") == null:
		return 0
	var definition = bridge.get("library").get_definition(structure_id)
	if definition == null:
		return 0
	# Which way the front door faces as authored.
	var door := ""
	for socket in definition.sockets:
		var socket_type := str(socket.get("type", "")).to_upper()
		if socket_type.begins_with("ROAD"):
			door = str(socket.get("facing", ""))
			break
	if door == "":
		return 0
	# The camera sits at +Z relative to what it is looking at and looks back
	# toward -Z (map_3d_view._apply_camera_transform puts it at
	# cos(pitch) * distance on Z). So the face turned toward the player is the
	# one pointing at INCREASING Z, which the socket convention calls north.
	#
	# This was south first time round, which is precisely backwards and is why
	# buildings came out with their doors round the back.
	var order := BlockStructureDefinition.FACING_ORDER
	var from := order.find(door)
	var to := order.find("north")
	if from < 0 or to < 0:
		return 0
	# _turn_facing steps BACKWARDS through the compass, so the steps needed to
	# bring `from` onto `to` is from - to.
	return ((from - to) % 4 + 4) % 4

func rotate_placement(steps: int = 1) -> void:
	if pending_archetype == &"":
		return
	pending_rotation = ((pending_rotation + steps) % 4 + 4) % 4
	queue_redraw()

func start_placement(archetype: StringName) -> void:
	pending_rotation = _default_rotation_for(archetype)
	# A module has no location to choose, so it never enters placement mode -- it
	# is installed into the player's tower directly. Routing it here rather than
	# in the HUD means every existing build button keeps working unchanged.
	if UnitCatalog.get_definition(archetype).get("module_role", &"") != &"":
		build_module(1, archetype)
		return
	pending_archetype = archetype

# Installs a module into the player's tower. Slots are the scarce thing and Bio
# is only the price, so a full tower is refused with a reason rather than
# silently eating the cost.
func build_module(player_id: int, archetype: StringName) -> bool:
	var definition := UnitCatalog.get_definition(archetype)
	if definition.get("module_role", &"") == &"":
		build_rejected.emit("%s is not a module" % archetype)
		return false
	var host := _module_host(player_id)
	if host.is_empty():
		build_rejected.emit("Requires a completed Observation Tower")
		return false
	var components: StructureComponents = host.get("components", null)
	if components == null or components.free_slots() <= 0:
		build_rejected.emit("No free module slots")
		return false
	var costs := {&"bio": int(definition.get("cost_bio", 0))}
	if economy_manager == null or not economy_manager.spend(player_id, costs):
		build_rejected.emit("Not enough Bio")
		return false
	if components.install_module(archetype, definition) == &"":
		economy_manager.add_resource(player_id, &"bio", int(costs[&"bio"]))
		build_rejected.emit("No free module slots")
		return false
	module_installed.emit(player_id, archetype)
	queue_redraw()
	return true

# Moves the player's wizard tower into the captured citadel's keep.
#
# Master doc section 40: the reward for taking the citadel is GROUND, and this
# is how the player banks it. It is also the largest bet the game offers --
# section 11 makes tower loss end the run, so relocating it mid-run trades a
# known position for a far stronger one.
#
# ORDER MATTERS. The defeat check scans the structures group every frame for a
# player wizard_tower, so the new tower is built BEFORE the old one is removed.
# Reversed, the player would lose the run at the moment of their reward.
func resummon_tower_to_citadel(player_id: int = 1) -> bool:
	var garrison: Node = get_parent().get_node_or_null("CitadelGarrison") if get_parent() != null else null
	if garrison == null or not bool(garrison.call("is_captured")):
		build_rejected.emit("The citadel is still held")
		return false
	var cell: Vector2i = garrison.call("keep_plinth_cell")
	if cell.x < 0:
		build_rejected.emit("The citadel keep has no plinth to summon onto")
		return false
	var old_index := -1
	for i in structures.size():
		if int(structures[i].get("player_id", -1)) == player_id 				and structures[i].get("archetype", &"") == &"wizard_tower":
			old_index = i
			break
	if old_index < 0:
		build_rejected.emit("No wizard tower to re-summon")
		return false
	# New first, old second. See the note above.
	add_free_structure(player_id, &"wizard_tower", cell, "")
	var old_structure: Dictionary = structures[old_index]
	_unregister_blockers(old_structure)
	var node = old_structure.get("node", null)
	if node != null and is_instance_valid(node):
		node.queue_free()
	structures.remove_at(old_index)
	tower_resummoned.emit(cell)
	print("[BuildSystem] wizard tower re-summoned into the captured citadel at ", cell)
	return true

# The structure modules are installed into: the player's completed tower.
func _module_host(player_id: int) -> Dictionary:
	for structure in structures:
		if int(structure.get("player_id", -1)) != player_id or not bool(structure.get("complete", false)):
			continue
		var components: StructureComponents = structure.get("components", null)
		if components != null and components.slot_capacity > 0:
			return structure
	return {}

func module_slots_free(player_id: int) -> int:
	var host := _module_host(player_id)
	if host.is_empty():
		return 0
	var components: StructureComponents = host.get("components", null)
	return 0 if components == null else components.free_slots()

func module_slots_total(player_id: int) -> int:
	var host := _module_host(player_id)
	if host.is_empty():
		return 0
	var components: StructureComponents = host.get("components", null)
	return 0 if components == null else components.slot_capacity

func installed_modules(player_id: int) -> Array[StringName]:
	var host := _module_host(player_id)
	if host.is_empty():
		return []
	var components: StructureComponents = host.get("components", null)
	return [] if components == null else components.module_archetypes()

# Units a structure can train: its own list plus every installed module's, so a
# tower with a production module trains what that module trains.
func production_list_for(structure: Dictionary) -> Array:
	var produced: Array = []
	produced.append_array(UnitCatalog.get_definition(structure.get("archetype", &"")).get("production", []))
	var components: StructureComponents = structure.get("components", null)
	if components != null:
		for module_archetype in components.module_archetypes():
			for entry in UnitCatalog.get_definition(module_archetype).get("production", []):
				if not produced.has(entry):
					produced.append(entry)
	return produced

func try_place_structure(player_id: int, archetype: StringName, cell: Vector2i) -> bool:
	var definition := UnitCatalog.get_definition(archetype)
	if definition.is_empty():
		build_rejected.emit("Unknown structure: %s" % archetype)
		return false
	if definition.get("module_role", &"") != &"":
		return build_module(player_id, archetype)
	var costs := {&"bio": int(definition.get("cost_bio", 0))}
	if economy_manager == null or not economy_manager.spend(player_id, costs):
		build_rejected.emit("Not enough Bio")
		return false
	if not _can_place(archetype, cell, player_id):
		economy_manager.add_resource(player_id, &"bio", int(costs[&"bio"]))
		build_rejected.emit("Invalid placement")
		return false
	var plot_id := _plot_id_for_cell(cell)
	if archetype == &"bio_absorber" and plot_id.is_empty():
		economy_manager.add_resource(player_id, &"bio", int(costs[&"bio"]))
		build_rejected.emit("Bio Absorber must be placed on an economy space")
		return false
	var structure := _make_structure_data(player_id, archetype, cell, plot_id, definition)
	structure["rotation_steps"] = pending_rotation
	structure["footprint"] = rotated_footprint(archetype, pending_rotation)
	if not definition.has("block_structure"):
		structure["blocked_cells"] = _footprint_cells(cell, structure["footprint"])
	structure["node"] = _create_structure_node(structure)
	structures.append(structure)
	_register_blockers(structure)
	_raise_block_structure(structure)
	if simulation_runner != null:
		var command := simulation_runner.make_local_command(RTSCommand.Type.BUILD_STRUCTURE, [], cell, {"structure": str(archetype)})
		simulation_runner.queue_command(command)
	structure_placed.emit(player_id, archetype, cell)
	queue_redraw()
	return true

func research_upgrade(player_id: int, upgrade_id: StringName) -> bool:
	var current_rank := upgrade_rank(upgrade_id)
	var max_rank := int(UPGRADE_MAX_RANK.get(upgrade_id, 1))
	if current_rank >= max_rank:
		build_rejected.emit("Upgrade already at max rank")
		return false
	if not _has_completed_structure(player_id, &"terrible_vault"):
		build_rejected.emit("Requires completed Observer Vault")
		return false
	if upgrade_id == &"tier_three_hybrids" and upgrade_rank(&"tier_two_hybrids") <= 0:
		build_rejected.emit("Requires Tier 2 Hybrids first")
		return false
	var next_rank := current_rank + 1
	var cost := _upgrade_cost(upgrade_id, next_rank)
	if economy_manager == null or not economy_manager.spend(player_id, {&"bio": cost}):
		build_rejected.emit("Not enough Bio")
		return false
	researched_upgrade_ranks[upgrade_id] = next_rank
	_apply_upgrade_to_existing_units(upgrade_id)
	upgrade_researched.emit(player_id, upgrade_id)
	for tier in TIER_UNLOCK_UPGRADES.keys():
		if TIER_UNLOCK_UPGRADES[tier] == upgrade_id:
			tier_unlocked.emit(player_id, int(tier))
	return true

# Highest roster tier this player may currently train. Map-discovered upgrades
# can grant a tier directly (see grant_tier_unlock) without paying research.
func unlocked_tier(player_id: int = 1) -> int:
	var tier := UnitCatalog.TIER_1
	for candidate in [2, 3]:
		if upgrade_rank(StringName(TIER_UNLOCK_UPGRADES[candidate])) > 0:
			tier = candidate
		else:
			break
	return tier

# Used by map discoveries ("finding upgrades on the map" in the roster doc) to
# open a tier without going through the Vault. Idempotent.
func grant_tier_unlock(player_id: int, tier: int) -> bool:
	if not TIER_UNLOCK_UPGRADES.has(tier):
		return false
	var upgrade_id: StringName = TIER_UNLOCK_UPGRADES[tier]
	if upgrade_rank(upgrade_id) > 0:
		return false
	researched_upgrade_ranks[upgrade_id] = 1
	upgrade_researched.emit(player_id, upgrade_id)
	tier_unlocked.emit(player_id, tier)
	return true

func upgrade_rank(upgrade_id: StringName) -> int:
	return int(researched_upgrade_ranks.get(upgrade_id, 0))

func upgrade_max_rank(upgrade_id: StringName) -> int:
	return int(UPGRADE_MAX_RANK.get(upgrade_id, 1))

func has_upgrade(upgrade_id: StringName) -> bool:
	return upgrade_rank(upgrade_id) > 0

func _make_structure_data(player_id: int, archetype: StringName, cell: Vector2i, plot_id: String, definition: Dictionary) -> Dictionary:
	var hp := int(definition.get("max_hp", 200))
	if definition.has("starts_at_hp_percent"):
		hp = int(float(hp) * float(definition["starts_at_hp_percent"]))
	var footprint: Vector2i = _base_footprint(archetype)
	var build_time := float(definition.get("build_time_seconds", 0.0))
	return {
		"player_id": player_id,
		"archetype": archetype,
		"cell": cell,
		"plot_id": plot_id,
		"hp": hp,
		"max_hp": int(definition.get("max_hp", 200)),
		"footprint": footprint,
		# A building carrying a block structure gets its walls from that
		# structure once it is stamped into the lattice. Blocking the whole
		# bounding box would seal its own muster hall, aisles and doorway --
		# the building would be a solid 34x28 brick that nothing could enter,
		# which is the entire point of it being walkable.
		"blocked_cells": ([] as Array[Vector2i]) if definition.has("block_structure") 			else _footprint_cells(cell, footprint),
		"block_structure": StringName(definition.get("block_structure", &"")),
		# Component state (master doc section 39). A structure with no authored
		# components gets one implicit critical component holding all its HP, so
		# this can be adopted building by building rather than all at once.
		"components": StructureComponents.new(definition),
		"build_time": build_time,
		"build_progress": 0.0,
		"complete": build_time <= 0.0,
		"production_queue": [],
		"training_archetype": &"",
		"training_progress": 0.0,
		"training_time": 0.0,
		"evolution_xp": 0.0,
		"level": 1,
		"upgrade": "",
		"auto_fire": true,
		"manual_target": null,
		"node": null,
	}

func add_free_structure(player_id: int, archetype: StringName, cell: Vector2i, plot_id: String = "") -> void:
	var definition := UnitCatalog.get_definition(archetype)
	var structure := _make_structure_data(player_id, archetype, cell, plot_id, definition)
	structure["build_progress"] = float(structure["build_time"])
	structure["complete"] = true
	structure["node"] = _create_structure_node(structure)
	structures.append(structure)
	_register_blockers(structure)
	structure_placed.emit(player_id, archetype, cell)
	queue_redraw()

func _place_vinewall_drag(player_id: int, start: Vector2i, end: Vector2i) -> void:
	var cells := _line_cells(start, end)
	if cells.is_empty():
		return
	var cost := UnitCatalog.cost_bio(&"vinewall") * cells.size()
	if economy_manager == null or not economy_manager.spend(player_id, {&"bio": cost}):
		build_rejected.emit("Not enough Bio for Vinewall")
		return
	var placed := 0
	for cell in cells:
		if not _can_place(&"vinewall", cell):
			continue
		var definition := UnitCatalog.get_definition(&"vinewall")
		var structure := _make_structure_data(player_id, &"vinewall", cell, "", definition)
		structure["node"] = _create_structure_node(structure)
		structures.append(structure)
		_register_blockers(structure)
		placed += 1
		structure_placed.emit(player_id, &"vinewall", cell)
	if placed < cells.size():
		var refund := UnitCatalog.cost_bio(&"vinewall") * (cells.size() - placed)
		economy_manager.add_resource(player_id, &"bio", refund)
	if placed == 0:
		build_rejected.emit("No valid Vinewall cells")
	queue_redraw()

func _current_wizard_class_id() -> String:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return ""
	return str(session.get("wizard_class_id"))

func produce_unit(player_id: int, archetype: StringName) -> bool:
	var producer := _first_structure_with_production(archetype, player_id)
	if producer.is_empty():
		if _has_incomplete_structure_with_production(archetype, player_id):
			build_rejected.emit("Barracks is still building")
		else:
			build_rejected.emit("Requires completed Barracks")
		return false
	if not UnitCatalog.is_unit_allowed_for_class(archetype, _current_wizard_class_id()):
		build_rejected.emit("Not available for this class")
		return false
	if not _tier_available(player_id, archetype):
		build_rejected.emit(_tier_locked_reason(archetype))
		return false
	var costs := {&"bio": UnitCatalog.cost_bio(archetype)}
	if economy_manager == null or not economy_manager.spend(player_id, costs):
		build_rejected.emit("Not enough Bio")
		return false
	return _enqueue_unit_at_structure(player_id, archetype, producer)

func _tier_available(player_id: int, archetype: StringName) -> bool:
	var tier := UnitCatalog.tier_of(archetype)
	if tier > UnitCatalog.MAX_TRAINABLE_TIER:
		return false
	return tier <= unlocked_tier(player_id)

func _tier_locked_reason(archetype: StringName) -> String:
	var tier := UnitCatalog.tier_of(archetype)
	if tier > UnitCatalog.MAX_TRAINABLE_TIER:
		return "The Forbidden cannot be trained -- it is unleashed from the Observation Tower"
	return "Requires Tier %s Hybrids research at the Observer Vault" % tier

func _spawn_trained_unit(player_id: int, archetype: StringName, producer: Dictionary) -> bool:
	var spawn_cell: Vector2i = map_generator.nearest_walkable_cell(producer["cell"] + Vector2i(2, 2), 8)
	var scene := _scene_for_unit(archetype)
	var spawned: Node = null
	if scene != null:
		var unit := scene.instantiate()
		unit.set("owner_player_id", player_id)
		get_parent().add_child(unit)
		unit.global_position = map_generator.cell_to_world(spawn_cell)
		_apply_upgrades_to_unit(unit)
		var rally: Vector2 = producer.get("rally_point", Vector2.ZERO)
		if rally != Vector2.ZERO and unit.has_method("issue_move_order"):
			unit.call_deferred("issue_move_order", rally)
		if simulation_runner != null:
			var entity_id := simulation_runner.state.spawn_entity(player_id, archetype, spawn_cell)
			unit.set("simulation_entity_id", entity_id)
		spawned = unit
	if simulation_runner != null:
		var command := simulation_runner.make_local_command(RTSCommand.Type.PRODUCE_UNIT, [], spawn_cell, {"unit": str(archetype)})
		simulation_runner.queue_command(command)
	unit_produced.emit(player_id, archetype, spawn_cell)
	if spawned != null:
		unit_trained.emit(player_id, archetype, spawned)
	return true

func _enqueue_unit_at_structure(player_id: int, archetype: StringName, producer: Dictionary) -> bool:
	var index := _structure_index_for_node(producer.get("node", null))
	if index < 0:
		build_rejected.emit("Production building was not found")
		return false
	var queue: Array = structures[index].get("production_queue", [])
	if queue.size() >= 5:
		build_rejected.emit("Training queue is full")
		return false
	queue.append(archetype)
	structures[index]["production_queue"] = queue
	_sync_training_node(index)
	unit_training_queued.emit(player_id, structures[index].get("node", null), archetype, queue.size())
	return true

func produce_unit_from_structure(player_id: int, archetype: StringName, producer_node: Node) -> bool:
	var producer := _structure_for_node(producer_node)
	if producer.is_empty():
		build_rejected.emit("Select a Barracks")
		return false
	if int(producer["player_id"]) != player_id:
		build_rejected.emit("That Barracks belongs to another player")
		return false
	if not bool(producer.get("complete", false)):
		build_rejected.emit("Barracks is still building")
		return false
	var definition := UnitCatalog.get_definition(producer["archetype"])
	if not production_list_for(producer).has(archetype):
		build_rejected.emit("This building cannot train that unit")
		return false
	if not UnitCatalog.is_unit_allowed_for_class(archetype, _current_wizard_class_id()):
		build_rejected.emit("Not available for this class")
		return false
	if not _tier_available(player_id, archetype):
		build_rejected.emit(_tier_locked_reason(archetype))
		return false
	var costs := {&"bio": UnitCatalog.cost_bio(archetype)}
	if economy_manager == null or not economy_manager.spend(player_id, costs):
		build_rejected.emit("Not enough Bio")
		return false
	return _enqueue_unit_at_structure(player_id, archetype, producer)

# Tier 4. Cast at great cost from the Observation Tower, and deliberately NOT
# owned by the caster: the roster doc is explicit that it "will not obey Kon and
# will turn its wrath on all". Given owner_player_id 0 (the neutral-hostile slot
# nothing else uses) so every faction's target acquisition treats it as an enemy,
# including the player who paid for it.
const FORBIDDEN_OWNER_ID := 0

func unleash_forbidden(player_id: int) -> Node:
	if not _has_completed_structure(player_id, &"wizard_tower"):
		build_rejected.emit("Requires the Observation Tower")
		return null
	var definition := UnitCatalog.get_definition(&"the_forbidden")
	var cost := int(definition.get("unleash_cost_bio", 900))
	if economy_manager == null or not economy_manager.spend(player_id, {&"bio": cost}):
		build_rejected.emit("Unleashing the Forbidden costs %s Bio" % cost)
		return null
	var tower := _first_structure_of(player_id, &"wizard_tower")
	if tower.is_empty():
		economy_manager.add_resource(player_id, &"bio", cost)
		build_rejected.emit("Requires the Observation Tower")
		return null
	var spawn_cell: Vector2i = map_generator.nearest_walkable_cell(tower["cell"] + Vector2i(4, 4), 12)
	var scene := _scene_for_unit(&"the_forbidden")
	if scene == null:
		economy_manager.add_resource(player_id, &"bio", cost)
		build_rejected.emit("No scene available for the Forbidden")
		return null
	var unit := scene.instantiate()
	unit.set("owner_player_id", FORBIDDEN_OWNER_ID)
	get_parent().add_child(unit)
	unit.global_position = map_generator.cell_to_world(spawn_cell)
	# It marches on the tower of whoever released it. Everything else it meets on
	# the way -- Deom included -- it will attack too, because owner 0 is hostile
	# to every owner id.
	var tower_node = tower.get("node", null)
	if unit.has_method("rampage_toward") and tower_node != null and is_instance_valid(tower_node):
		unit.call_deferred("rampage_toward", (tower_node as Node2D).global_position)
	forbidden_unleashed.emit(player_id, unit)
	return unit

func _first_structure_of(player_id: int, archetype: StringName) -> Dictionary:
	for structure in structures:
		if int(structure.get("player_id", -1)) != player_id:
			continue
		if structure.get("archetype", &"") != archetype:
			continue
		if bool(structure.get("complete", false)):
			return structure
	return {}

func apply_first_absorber_upgrade(upgrade_id: StringName) -> bool:
	for i in structures.size():
		if structures[i]["archetype"] == &"bio_absorber" and bool(structures[i].get("complete", false)) and int(structures[i]["level"]) >= 2 and str(structures[i]["upgrade"]).is_empty():
			structures[i]["upgrade"] = str(upgrade_id)
			queue_redraw()
			return true
	build_rejected.emit("Requires evolved Bio Absorber")
	return false

# Whether a structure can train units at all.
#
# This used to be spelled `archetype == &"barracks"` in three places. Once the
# barracks became a TOWER MODULE rather than a building, all three silently
# stopped matching anything: there is no barracks structure on the map any more,
# so production never ticked, idle-cycling found nothing, and rally points were
# refused. Asking about capability instead of identity keeps them correct
# wherever the production actually lives.
func _produces_units(structure: Dictionary) -> bool:
	if not (UnitCatalog.get_definition(structure.get("archetype", &"")).get("production", []) as Array).is_empty():
		return true
	var components: StructureComponents = structure.get("components", null)
	return components != null and components.has_module_role(&"production")

# Idle production buildings, in a stable order, for the "cycle idle barracks"
# hotkey. Reads the production bookkeeping this system already maintains --
# no node reflection, and only ever called from a key press.
func idle_production_nodes(player_id: int) -> Array[Node]:
	var idle: Array[Node] = []
	for structure in structures:
		if int(structure.get("player_id", -1)) != player_id:
			continue
		if not _produces_units(structure):
			continue
		if not bool(structure.get("complete", false)):
			continue
		if not str(structure.get("training_archetype", &"")).is_empty():
			continue
		if not (structure.get("production_queue", []) as Array).is_empty():
			continue
		var node: Node = structure.get("node", null)
		if node != null and is_instance_valid(node):
			idle.append(node)
	return idle

# "can be set to attack ground for manual firing" / "can be set to fire
# automatically" -- both from the roster doc. Auto-fire defaults on, so existing
# behaviour is unchanged unless the player turns it off.
func set_launcher_auto_fire(launcher_node: Node, enabled: bool) -> bool:
	var index := _structure_index_for_node(launcher_node)
	if index < 0 or structures[index]["archetype"] != &"bio_launcher":
		return false
	structures[index]["auto_fire"] = enabled
	return true

func launcher_auto_fire(launcher_node: Node) -> bool:
	var index := _structure_index_for_node(launcher_node)
	if index < 0:
		return true
	return bool(structures[index].get("auto_fire", true))

func order_launcher_attack_ground(launcher_node: Node, world_position: Vector2) -> bool:
	var index := _structure_index_for_node(launcher_node)
	if index < 0 or structures[index]["archetype"] != &"bio_launcher":
		return false
	if not bool(structures[index].get("complete", false)):
		build_rejected.emit("Bio Launcher is still building")
		return false
	var raw_node = structures[index].get("node", null)
	if raw_node == null or not is_instance_valid(raw_node) or not (raw_node is Node2D):
		return false
	var range := float(UnitCatalog.get_definition(&"bio_launcher").get("attack_range_cells", 9)) * 64.0
	if (raw_node as Node2D).global_position.distance_to(world_position) > range:
		build_rejected.emit("Target is out of Bio Launcher range")
		return false
	structures[index]["manual_target"] = world_position
	return true

func _fire_bio_launcher_at_ground(structure: Dictionary, world_position: Vector2) -> void:
	var raw_node = structure.get("node", null)
	if raw_node == null or not is_instance_valid(raw_node) or not (raw_node is Node2D):
		return
	var definition := UnitCatalog.get_definition(&"bio_launcher")
	var radius := float(definition.get("aoe_radius", 92.0))
	var damage := int(definition.get("attack_damage", 24))
	var rank := upgrade_rank(&"launcher_bile")
	if rank > 0:
		damage = int(round(float(damage) * (1.0 + 0.25 * float(rank))))
		radius *= 1.0 + 0.08 * float(rank)
	var player_id := int(structure["player_id"])
	var hit := rts_world.query_enemy_units(world_position, radius, player_id) if rts_world != null else _fallback_unit_nodes()
	for unit in hit:
		if is_instance_valid(unit) and unit.has_method("take_damage") and int(unit.get("owner_player_id")) != player_id:
			unit.call("take_damage", damage, raw_node)
	_draw_launcher_burst(world_position, radius)

func get_structures() -> Array[Dictionary]:
	return structures.duplicate(true)

func _can_place(archetype: StringName, cell: Vector2i, player_id: int = 1) -> bool:
	if map_generator == null or not map_generator.has_method("is_walkable_cell"):
		return false
	var definition := UnitCatalog.get_definition(archetype)
	# While observing, construction is projected only from the owned tower crown.
	# Normal construction rules outside the stance remain unchanged.
	if rts_world!=null:
		for unit in rts_world.units_for_owner(player_id):
			if unit.has_method("can_remote_summon") and unit.is_observer_aura_enabled():
				if not unit.can_remote_summon(map_generator.cell_to_world(cell)): return false
	var footprint := rotated_footprint(archetype, pending_rotation)
	for blocked_cell in _footprint_cells(cell, footprint):
		if not _is_placement_cell_free(blocked_cell):
			return false
	if archetype == &"bio_absorber":
		return not _plot_id_for_cell(cell).is_empty()
	return true

func _is_placement_cell_free(cell: Vector2i) -> bool:
	if map_generator == null or not map_generator.has_method("is_walkable_cell"):
		return false
	if not map_generator.is_walkable_cell(cell):
		return false
	for structure in structures:
		if structure.get("blocked_cells", []).has(cell):
			return false
	return true

func get_placement_cells(archetype: StringName, cell: Vector2i) -> Array[Vector2i]:
	return _footprint_cells(cell, rotated_footprint(archetype, pending_rotation))

func _footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(origin.x, origin.x + footprint.x):
		for y in range(origin.y, origin.y + footprint.y):
			cells.append(Vector2i(x, y))
	return cells

# Builds the walkable block structure a building is made of.
#
# The bridge owns this: it stamps the structure into the navigation lattice,
# stitches its authored entrance to the surrounding ground, and registers only
# the columns that are genuinely wall as 2D blockers. Doing it here by hand
# would mean two places deciding what a building's walls are.
func _raise_block_structure(structure: Dictionary) -> void:
	var structure_id: StringName = structure.get("block_structure", &"")
	if structure_id == &"":
		return
	var bridge: Node = get_parent().get_node_or_null("BlockNavBridge") if get_parent() != null else null
	if bridge == null or not bridge.has_method("place_runtime_structure"):
		push_warning("[BuildSystem] %s wants block structure %s but there is no BlockNavBridge"
			% [structure.get("archetype", &""), structure_id])
		return
	var instance_id := StringName("%s_%s_%s" % [structure_id, structure["cell"].x, structure["cell"].y])
	if not bool(bridge.call("place_runtime_structure", structure_id, structure["cell"], instance_id,
			int(structure.get("rotation_steps", 0)))):
		push_warning("[BuildSystem] could not raise %s at %s" % [structure_id, structure["cell"]])
		return
	structure["block_instance"] = instance_id

func _register_blockers(structure: Dictionary) -> void:
	if map_generator != null and map_generator.has_method("add_dynamic_blockers"):
		map_generator.add_dynamic_blockers(structure.get("blocked_cells", []))

# Destroyed components release their cells back to navigation, so a breached
# wall becomes a route units can actually path through rather than a hole in a
# sprite. Re-registered wholesale rather than diffed: a structure is a handful
# of cells, and this only runs when something actually breaks.
func _apply_component_damage(structure: Dictionary, amount: int) -> void:
	var components: StructureComponents = structure.get("components", null)
	if components == null:
		return
	var destroyed := components.take_damage(amount)
	if destroyed.is_empty():
		return
	_unregister_blockers(structure)
	structure["blocked_cells"] = components.blocked_cells(
		structure.get("cell", Vector2i.ZERO), structure.get("footprint", Vector2i.ONE))
	_register_blockers(structure)
	for id in destroyed:
		# A destroyed module is removed outright so its slot is genuinely free
		# again -- permanent slot loss would turn one bad siege into an
		# unrecoverable run (section 39).
		if components.remove_module(id):
			module_destroyed.emit(int(structure.get("player_id", 1)), id)

func _unregister_blockers(structure: Dictionary) -> void:
	if map_generator != null and map_generator.has_method("remove_dynamic_blockers"):
		map_generator.remove_dynamic_blockers(structure.get("blocked_cells", []))

func _sync_structure_damage_and_cleanup() -> void:
	for i in range(structures.size() - 1, -1, -1):
		var structure: Dictionary = structures[i]
		var node = structure.get("node", null)
		if node == null or not is_instance_valid(node):
			_unregister_blockers(structure)
			structures.remove_at(i)
			continue
		if node is KonStructure:
			var previous := int(structure.get("hp", node.health))
			var current := int(node.health)
			if current < previous:
				_apply_component_damage(structure, previous - current)
				# A critical component going down takes the structure with it, even
				# if the node's own HP bar has not reached zero.
				var components: StructureComponents = structure.get("components", null)
				if components != null and not components.is_alive():
					current = 0
					node.health = 0
			structure["hp"] = current
			if int(structure["hp"]) <= 0:
				_unregister_blockers(structure)
				structures.remove_at(i)
				continue
			structures[i] = structure

func _create_structure_node(structure: Dictionary) -> KonStructure:
	var node := KonStructure.new()
	var cell: Vector2i = structure["cell"]
	var footprint: Vector2i = structure.get("footprint", Vector2i.ONE)
	node.configure(structure["archetype"], cell, footprint)
	node.set_runtime_stats(int(structure["player_id"]), int(structure.get("hp", 1)), int(structure.get("max_hp", 1)), int(structure.get("level", 1)))
	node.global_position = _footprint_center_world(cell, footprint)
	node.z_index = clampi(int(node.global_position.y) + 160, -4096, 4096)
	node.set_construction_state(float(structure.get("build_progress", 0.0)), float(structure.get("build_time", 0.0)), bool(structure.get("complete", true)))
	get_parent().add_child(node)
	return node

func _line_cells(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := end - start
	var steps: int = maxi(abs(delta.x), abs(delta.y))
	if steps == 0:
		return [start]
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var cell := Vector2i(roundi(lerpf(float(start.x), float(end.x), t)), roundi(lerpf(float(start.y), float(end.y), t)))
		if not cells.has(cell):
			cells.append(cell)
	return cells

func _update_structure_evolution(delta: float) -> void:
	var changed := false
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if not bool(structure.get("complete", false)):
			continue
		var definition := UnitCatalog.get_definition(structure["archetype"])
		if not bool(definition.get("auto_evolves", false)):
			continue
		structure["evolution_xp"] = float(structure.get("evolution_xp", 0.0)) + delta
		var needed := float(definition.get("evolution_seconds", 90.0))
		var next_level := int(structure.get("level", 1)) + 1
		if float(structure["evolution_xp"]) >= needed and next_level <= 3:
			structure["level"] = next_level
			structure["evolution_xp"] = 0.0
			structure["max_hp"] = int(float(structure["max_hp"]) * 1.2)
			structure["hp"] = structure["max_hp"]
			if structure["archetype"] == &"vinewall":
				structure["max_hp"] = int(float(structure["max_hp"]) * 1.15)
				structure["hp"] = structure["max_hp"]
			var node: KonStructure = structure.get("node", null)
			if node != null and is_instance_valid(node):
				node.set_runtime_stats(int(structure["player_id"]), int(structure["hp"]), int(structure["max_hp"]), next_level)
				node.set_level(next_level)
			changed = true
		structures[i] = structure
	if changed:
		queue_redraw()

func _update_structure_regeneration(delta: float) -> void:
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if not bool(structure.get("complete", false)):
			continue
		var definition := UnitCatalog.get_definition(structure["archetype"])
		var regen := float(definition.get("regeneration_per_second", 0.0))
		if structure["archetype"] == &"vinewall":
			regen += 3.0 * float(upgrade_rank(&"thorned_vines"))
		if regen <= 0.0:
			continue
		structure["hp"] = mini(int(structure["max_hp"]), int(float(structure["hp"]) + regen * delta))
		var node: KonStructure = structure.get("node", null)
		if node != null and is_instance_valid(node):
			node.set_runtime_stats(int(structure["player_id"]), int(structure["hp"]), int(structure["max_hp"]), int(structure.get("level", 1)))
		structures[i] = structure

func _update_bio_launchers(delta: float) -> void:
	_launcher_elapsed += delta
	if _launcher_elapsed < 0.25:
		return
	var step := _launcher_elapsed
	_launcher_elapsed = 0.0
	if rts_world != null:
		rts_world.rebuild_spatial()
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if structure["archetype"] != &"bio_launcher" or not bool(structure.get("complete", false)):
			continue
		var cooldown := float(UnitCatalog.get_definition(&"bio_launcher").get("attack_cooldown_ticks", 40)) / 20.0
		structure["attack_elapsed"] = float(structure.get("attack_elapsed", 0.0)) + step
		if float(structure["attack_elapsed"]) < cooldown:
			structures[i] = structure
			continue
		# A queued manual attack-ground shot always takes priority over
		# auto-acquisition, and fires even when auto-fire is switched off.
		var manual_target: Variant = structure.get("manual_target", null)
		var target: Node2D = null
		var manual_position := Vector2.ZERO
		var has_manual := manual_target != null
		if has_manual:
			manual_position = manual_target
		elif not bool(structure.get("auto_fire", true)):
			structures[i] = structure
			continue
		else:
			target = _find_launcher_target(structure)
			if target == null:
				structures[i] = structure
				continue
		var shot_cost := int(UnitCatalog.get_definition(&"bio_launcher").get("shot_cost_bio", 3))
		if economy_manager != null and not economy_manager.spend(int(structure["player_id"]), {&"bio": shot_cost}):
			structures[i] = structure
			continue
		if has_manual:
			_fire_bio_launcher_at_ground(structure, manual_position)
			structure["manual_target"] = null
		else:
			_fire_bio_launcher(structure, target)
		structure["attack_elapsed"] = 0.0
		structure["evolution_xp"] = float(structure.get("evolution_xp", 0.0)) + 18.0
		structures[i] = structure

# The roster doc: "Bio absorbers will naturally slowly heal units and buildings
# in a large radius. This rewards Kon choosing a more difficult place to base
# with more eco slots." The heal_aura upgrade choice existed in the catalog and
# in the HUD button, but nothing ever read it -- picking it did literally
# nothing. Baseline heal now applies to every completed absorber; the upgrade
# widens the radius and triples the rate.
#
# Ticks once per second, not per frame, and reuses RTSWorld's existing spatial
# buckets. At a normal base count that is a handful of radius queries a second.
const HEAL_AURA_INTERVAL := 1.0

func _update_absorber_heal_auras(delta: float) -> void:
	_heal_aura_elapsed += delta
	if _heal_aura_elapsed < HEAL_AURA_INTERVAL:
		return
	var step := _heal_aura_elapsed
	_heal_aura_elapsed = 0.0
	var definition := UnitCatalog.get_definition(&"bio_absorber")
	if definition.is_empty():
		return
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if structure.get("archetype", &"") != &"bio_absorber" or not bool(structure.get("complete", false)):
			continue
		var raw_node = structure.get("node", null)
		if raw_node == null or not is_instance_valid(raw_node) or not (raw_node is Node2D):
			continue
		var upgraded := str(structure.get("upgrade", "")) == "heal_aura"
		var radius := float(definition.get("upgraded_heal_aura_radius", 720.0)) if upgraded else float(definition.get("heal_aura_radius", 460.0))
		var rate := float(definition.get("upgraded_heal_per_second", 6.0)) if upgraded else float(definition.get("heal_per_second", 2.0))
		var amount := int(round(rate * step))
		if amount <= 0:
			continue
		_apply_heal_aura(raw_node as Node2D, int(structure.get("player_id", 1)), radius, amount)

func _apply_heal_aura(source: Node2D, player_id: int, radius: float, amount: int) -> void:
	# Iterates the owner's own unit list with a squared-distance test rather than
	# RTSWorld.query_units(). query_units reads the spatial buckets, which are
	# only rebuilt by the Bio Launcher tick -- correct in a live frame, but it
	# makes this function silently depend on another system's cadence and gives
	# stale or empty results when called in isolation. The owner list is always
	# current, and at a normal base count this is a few hundred cheap distance
	# checks per second, once per absorber.
	var radius_sq := radius * radius
	if rts_world != null and is_instance_valid(rts_world):
		for unit in rts_world.units_for_owner(player_id):
			if not is_instance_valid(unit) or not unit.has_method("heal_damage"):
				continue
			if source.global_position.distance_squared_to(unit.global_position) > radius_sq:
				continue
			unit.call("heal_damage", amount)
	# Friendly structures mend too, per the doc ("units and buildings").
	# The KonStructure node is the authoritative HP holder here -- the structures
	# dictionary is synced FROM it every frame by _sync_structure_damage_and_cleanup(),
	# so healing the dictionary alone would be silently overwritten.
	for i in structures.size():
		var other: Dictionary = structures[i]
		if int(other.get("player_id", -1)) != player_id:
			continue
		var other_node = other.get("node", null)
		if other_node == null or not is_instance_valid(other_node) or not (other_node is KonStructure):
			continue
		var structure_node := other_node as KonStructure
		if structure_node.health <= 0 or structure_node.health >= structure_node.max_health:
			continue
		if source.global_position.distance_squared_to(structure_node.global_position) > radius_sq:
			continue
		structure_node.health = mini(structure_node.max_health, structure_node.health + amount)
		structures[i]["hp"] = structure_node.health
		structure_node.queue_redraw()

func _find_launcher_target(structure: Dictionary) -> Node2D:
	var raw_node = structure.get("node", null)
	if raw_node == null or not is_instance_valid(raw_node) or not (raw_node is Node2D):
		return null
	var node := raw_node as Node2D
	var range := float(UnitCatalog.get_definition(&"bio_launcher").get("attack_range_cells", 9)) * 64.0
	var best: Node2D = null
	var best_distance := INF
	var candidates: Array[Node2D] = rts_world.query_enemy_units(node.global_position, range, int(structure["player_id"])) if rts_world != null else _fallback_unit_nodes()
	for unit in candidates:
		if not is_instance_valid(unit) or not (unit is Node2D):
			continue
		if int(unit.get("owner_player_id")) == int(structure["player_id"]):
			continue
		if not unit.has_method("take_damage"):
			continue
		var unit_node := unit as Node2D
		var distance := node.global_position.distance_squared_to(unit_node.global_position)
		if distance <= range * range and distance < best_distance:
			best = unit_node
			best_distance = distance
	return best

func _fire_bio_launcher(structure: Dictionary, target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var definition := UnitCatalog.get_definition(&"bio_launcher")
	var damage := int(definition.get("attack_damage", 24))
	var radius := float(definition.get("aoe_radius", 92.0))
	var bile_rank := upgrade_rank(&"launcher_bile")
	damage += 8 * bile_rank
	radius += 34.0 * float(bile_rank)
	var raw_source = structure.get("node", null)
	var source_node: Node = raw_source if raw_source != null and is_instance_valid(raw_source) and raw_source is Node else null
	if rts_world != null and source_node is Node2D:
		var weapon := WeaponCatalog.get_weapon(&"bio_launcher")
		var projectile := rts_world.spawn_projectile(source_node as Node2D, target, damage, weapon.get("color", Color("#8B1A1F")), float(weapon.get("speed", 420.0)), (source_node as Node2D).global_position + Vector2(0, -40))
		projectile.set_aoe_radius(radius)
		return
	var candidates: Array[Node2D] = _fallback_unit_nodes()
	for unit in candidates:
		if not is_instance_valid(unit) or not (unit is Node2D) or not unit.has_method("take_damage"):
			continue
		if int(unit.get("owner_player_id")) == int(structure["player_id"]):
			continue
		var unit_node := unit as Node2D
		if target == null or not is_instance_valid(target):
			return
		var distance: float = unit_node.global_position.distance_to(target.global_position)
		if distance <= radius:
			unit.take_damage(maxi(1, int(float(damage) * (1.0 - distance / (radius * 1.6)))), source_node)
	_draw_launcher_burst(target.global_position, radius)

func _fallback_unit_nodes() -> Array[Node2D]:
	var units: Array[Node2D] = []
	for unit in get_tree().get_nodes_in_group("units"):
		if unit is Node2D:
			units.append(unit)
	return units

func _draw_launcher_burst(pos: Vector2, radius: float) -> void:
	var fx := Node2D.new()
	fx.set_script(preload("res://scripts/fx/aoe_burst_fx.gd"))
	get_parent().add_child(fx)
	fx.global_position = pos
	fx.call("configure", radius, Color("#7BC47F"), Color("#8B1A1F"))

func _update_construction(delta: float) -> void:
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if bool(structure.get("complete", false)):
			continue
		var build_time := float(structure.get("build_time", 0.0))
		var build_progress := float(structure.get("build_progress", 0.0)) + delta
		var completed := build_time <= 0.0 or build_progress >= build_time
		structure["build_progress"] = minf(build_progress, build_time)
		structure["complete"] = completed
		var node: KonStructure = structure.get("node", null)
		if node != null and is_instance_valid(node):
			node.set_construction_state(float(structure["build_progress"]), build_time, completed)
		if completed:
			_activate_completed_structure(structure)
			structure_completed.emit(int(structure["player_id"]), structure["archetype"], structure["cell"])
		structures[i] = structure

func _update_production(delta: float) -> void:
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if not bool(structure.get("complete", false)):
			continue
		if not _produces_units(structure):
			continue
		var current: StringName = structure.get("training_archetype", &"")
		if str(current).is_empty():
			_start_next_training(i)
			structure = structures[i]
			current = structure.get("training_archetype", &"")
			if str(current).is_empty():
				continue
		var progress := float(structure.get("training_progress", 0.0)) + delta
		var train_time := float(structure.get("training_time", UnitCatalog.train_time(current)))
		structure["training_progress"] = minf(progress, train_time)
		structures[i] = structure
		_sync_training_node(i)
		if progress >= train_time:
			_spawn_trained_unit(int(structure["player_id"]), current, structure)
			structures[i]["training_archetype"] = &""
			structures[i]["training_progress"] = 0.0
			structures[i]["training_time"] = 0.0
			_start_next_training(i)
			_sync_training_node(i)

func _start_next_training(index: int) -> void:
	var queue: Array = structures[index].get("production_queue", [])
	if queue.is_empty():
		structures[index]["training_archetype"] = &""
		structures[index]["training_progress"] = 0.0
		structures[index]["training_time"] = 0.0
		return
	var next: StringName = queue.pop_front()
	structures[index]["production_queue"] = queue
	structures[index]["training_archetype"] = next
	structures[index]["training_progress"] = 0.0
	structures[index]["training_time"] = UnitCatalog.train_time(next)

func _sync_training_node(index: int) -> void:
	var node: KonStructure = structures[index].get("node", null)
	if node == null or not is_instance_valid(node):
		return
	var queue: Array = structures[index].get("production_queue", [])
	var training_archetype: StringName = structures[index].get("training_archetype", &"")
	node.set_training_state(queue.size(), training_archetype, float(structures[index].get("training_progress", 0.0)), float(structures[index].get("training_time", 0.0)))

func _activate_completed_structure(structure: Dictionary) -> void:
	if structure["archetype"] != &"bio_absorber" or economy_manager == null:
		return
	var player_id := int(structure["player_id"])
	var plot_id := str(structure.get("plot_id", ""))
	var cell: Vector2i = structure["cell"]
	if not economy_manager.register_economy_building(player_id, plot_id, cell, structure["archetype"]):
		build_rejected.emit("Bio Absorber could not attach to its economy space")

func _first_structure_with_production(unit_archetype: StringName, player_id: int) -> Dictionary:
	for structure in structures:
		if int(structure["player_id"]) != player_id:
			continue
		if not bool(structure.get("complete", false)):
			continue
		if production_list_for(structure).has(unit_archetype):
			return structure
	return {}

func _structure_for_node(producer_node: Node) -> Dictionary:
	for structure in structures:
		var node: Node = structure.get("node", null)
		if node == producer_node:
			return structure
	return {}

func _structure_index_for_node(producer_node: Node) -> int:
	for i in structures.size():
		var node: Node = structures[i].get("node", null)
		if node == producer_node:
			return i
	return -1

func _has_incomplete_structure_with_production(unit_archetype: StringName, player_id: int) -> bool:
	for structure in structures:
		if int(structure["player_id"]) != player_id:
			continue
		if bool(structure.get("complete", false)):
			continue
		if production_list_for(structure).has(unit_archetype):
			return true
	return false

# A capability counts whether it comes from a standalone building on the ground
# or a module installed in a tower. This is the single seam that let modules
# arrive without rewriting research and production: those systems ask "does this
# player have an Observer Vault", and a tower module now answers yes.
func _has_completed_structure(player_id: int, archetype: StringName) -> bool:
	for structure in structures:
		if int(structure.get("player_id", -1)) != player_id or not bool(structure.get("complete", false)):
			continue
		if structure.get("archetype", &"") == archetype:
			return true
		var components: StructureComponents = structure.get("components", null)
		if components != null and components.module_archetypes().has(archetype):
			return true
	return false

func _upgrade_cost(upgrade_id: StringName, rank: int) -> int:
	var base_cost := 0
	match upgrade_id:
		&"thorned_vines":
			base_cost = 120
		&"accelerated_evolution":
			base_cost = 150
		&"hardened_horrors":
			base_cost = 140
		&"launcher_bile":
			base_cost = 160
		&"observer_sight":
			base_cost = 90
		&"observer_command":
			base_cost = 240
		&"observer_oversight":
			base_cost = 130
		&"tier_two_hybrids":
			base_cost = 200
		&"tier_three_hybrids":
			base_cost = 420
		_:
			return 99999
	return int(round(float(base_cost) * (1.0 + float(rank - 1) * 0.6)))

func _apply_upgrade_to_existing_units(upgrade_id: StringName) -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1:
			_apply_upgrades_to_unit(unit)
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if upgrade_id == &"thorned_vines" and structure.get("archetype", &"") == &"vinewall":
			structure["max_hp"] = int(float(structure.get("max_hp", 1)) * 1.18)
			structure["hp"] = mini(int(structure["max_hp"]), int(structure.get("hp", 1)) + 45)
			var node: KonStructure = structure.get("node", null)
			if node != null and is_instance_valid(node):
				node.set_runtime_stats(int(structure["player_id"]), int(structure["hp"]), int(structure["max_hp"]), int(structure.get("level", 1)))
		structures[i] = structure

func _apply_upgrades_to_unit(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not _node_has_property(unit, "unit_archetype"):
		return
	var archetype: StringName = unit.get("unit_archetype")
	var horrors_rank := upgrade_rank(&"hardened_horrors")
	# Matched on unit FAMILY, not archetype. Keyed on &"horror" alone, the
	# upgrade stopped applying the instant a Horror evolved into a Hunter -- so
	# an upgrade the player paid for evaporated exactly when their unit got
	# better. Families are already in the catalog (horror -> hunter share
	# unit_family &"horror").
	if UnitCatalog.family_of(archetype) == &"horror" and horrors_rank > 0:
		var applied_rank := int(unit.get_meta("hardened_horrors_rank_applied", 0))
		if applied_rank < horrors_rank:
			var delta := horrors_rank - applied_rank
			unit.set("max_health", int(unit.get("max_health")) + 20 * delta)
			unit.set("health", int(unit.get("health")) + 20 * delta)
			unit.set("attack_damage", int(unit.get("attack_damage")) + 2 * delta)
			unit.set_meta("hardened_horrors_rank_applied", horrors_rank)
	# Intelligence is recomputed from the catalog baseline plus the current rank
	# rather than incremented, so it is naturally idempotent and survives the
	# stat reset that evolution performs.
	var command_rank := upgrade_rank(&"observer_command")
	if _node_has_property(unit, "intelligence"):
		var baseline := UnitCatalog.intelligence_of(archetype)
		unit.set("intelligence", mini(UnitCatalog.INTELLIGENCE_BOUND, baseline + command_rank))
	if upgrade_rank(&"accelerated_evolution") > 0 and _node_has_property(unit, "evolution_xp") and not bool(unit.get_meta("accelerated_evolution_applied", false)):
		unit.set("evolution_xp", float(unit.get("evolution_xp")) + 28.0)
		unit.set_meta("accelerated_evolution_applied", true)

# Called by RTSUnit._evolve(). An evolution re-reads the archetype's catalog
# stats, which discards any research bonus baked into the node, so the
# already-applied rank markers are cleared and the upgrades re-applied against
# the unit's new base stats.
func reapply_upgrades_after_evolution(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	unit.set_meta("hardened_horrors_rank_applied", 0)
	_apply_upgrades_to_unit(unit)

func _node_has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

func _scene_for_unit(archetype: StringName) -> PackedScene:
	match archetype:
		&"mangler", &"winged_mangler":
			return preload("res://scenes/units/mangler.tscn")
		&"terrible_thing", &"awful_thing":
			return terrible_thing_scene
		&"oaven_spear", &"oaven_jumper":
			return oaven_spear_scene
		&"horror":
			return horror_scene
		&"apex", &"apex_predator":
			return apex_scene
		&"spawner":
			return spawner_scene
		&"stone_face_serpent":
			return stone_face_serpent_scene
		&"the_forbidden":
			return the_forbidden_scene
	return null

func _draw() -> void:
	if map_generator == null:
		return
	if pending_archetype == &"vinewall" and _dragging_wall:
		for cell in _line_cells(_wall_drag_start, _wall_drag_end):
			_draw_cell_preview(cell, _can_place(&"vinewall", cell), _is_placement_cell_free(cell))
	elif pending_archetype != &"":
		var cell: Vector2i = map_generator.world_to_cell(_placement_mouse_position())
		var valid := _can_place(pending_archetype, cell)
		var cells := get_placement_cells(pending_archetype, cell)
		_draw_footprint_pad(cells, valid, true)
		_draw_structure_preview(pending_archetype, cells, valid)

func _draw_cell_preview(cell: Vector2i, placement_valid: bool, cell_valid: bool) -> void:
	var valid := placement_valid and cell_valid
	var fill := Color("#7BC47F", 0.22) if valid else Color("#C13030", 0.36)
	var line := Color("#7BC47F", 0.96) if valid else Color("#E85A5A", 0.98)
	var points := _cell_polygon(cell)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_colored_polygon(points, fill)
	draw_polyline(outline, line, 2.0)

func _draw_structure_preview(archetype: StringName, cells: Array[Vector2i], valid: bool) -> void:
	if cells.is_empty():
		return
	if USE_PLACEHOLDER_BUILDING_PREVIEWS:
		_draw_placeholder_structure_preview(archetype, cells, valid)
		return
	if not STRUCTURE_PREVIEW_TEXTURES.has(archetype):
		return
	var texture: Texture2D = STRUCTURE_PREVIEW_TEXTURES[archetype]
	var footprint := _footprint_extents(cells)
	var center := _footprint_center_world(cells[0], footprint)
	var tile_size := _grid_cell_size()
	var target_width := maxf(58.0, float(footprint.x + footprint.y) * tile_size.x * 0.31)
	var scale := target_width / maxf(1.0, float(texture.get_width()))
	var size := Vector2(texture.get_width(), texture.get_height()) * scale
	var tint := Color(1, 1, 1, 0.62) if valid else Color("#E85A5A", 0.52)
	var base_bottom := _footprint_bottom_y(cells)
	draw_texture_rect(texture, Rect2(Vector2(center.x - size.x * 0.5, base_bottom - size.y + 6.0), size), false, tint)

func _draw_placeholder_structure_preview(archetype: StringName, cells: Array[Vector2i], valid: bool) -> void:
	var color := _structure_color(archetype)
	if not valid:
		color = Color("#C13030")
	var top_offset := Vector2(0, -24.0)
	for cell in cells:
		var base := _cell_polygon(cell)
		var top := PackedVector2Array()
		for point in base:
			top.append(point + top_offset)
		draw_colored_polygon(base, Color(color.darkened(0.45), 0.58))
		draw_colored_polygon(top, Color(color, 0.72))
		for i in base.size():
			var next := (i + 1) % base.size()
			draw_line(base[i], top[i], Color(color.darkened(0.35), 0.72), 1.5)
			draw_line(top[i], top[next], Color(color.lightened(0.15), 0.86), 2.0)

func _draw_footprint_outline(cells: Array[Vector2i], valid: bool) -> void:
	if cells.is_empty():
		return
	var color := Color("#7BC47F", 1.0) if valid else Color("#E85A5A", 1.0)
	for cell in cells:
		var points := _cell_polygon(cell)
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		draw_polyline(outline, color, 3.0)

func _draw_footprint_pad(cells: Array[Vector2i], valid: bool, show_cell_lines: bool) -> void:
	if cells.is_empty():
		return
	var fill := Color("#7BC47F", 0.22) if valid else Color("#C13030", 0.34)
	var edge := Color("#7BC47F", 0.95) if valid else Color("#E85A5A", 0.95)
	for cell in cells:
		draw_colored_polygon(_cell_polygon(cell), fill)
	if show_cell_lines:
		for cell in cells:
			var points := _cell_polygon(cell)
			var outline := PackedVector2Array(points)
			outline.append(points[0])
			draw_polyline(outline, edge, 2.6)

func _footprint_bottom_y(cells: Array[Vector2i]) -> float:
	var bottom := -INF
	for cell in cells:
		for point in _cell_polygon(cell):
			bottom = maxf(bottom, point.y)
	return bottom

func _footprint_boundary_segments(cells: Array[Vector2i]) -> Array[Array]:
	var occupied := {}
	for cell in cells:
		occupied[cell] = true
	var segments: Array[Array] = []
	for cell in cells:
		var points := _cell_polygon(cell)
		if not occupied.has(cell + Vector2i(0, -1)):
			segments.append([points[0], points[1]])
		if not occupied.has(cell + Vector2i(1, 0)):
			segments.append([points[1], points[2]])
		if not occupied.has(cell + Vector2i(0, 1)):
			segments.append([points[2], points[3]])
		if not occupied.has(cell + Vector2i(-1, 0)):
			segments.append([points[3], points[0]])
	return segments

func _footprint_center_world(origin: Vector2i, footprint: Vector2i) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for cell in _footprint_cells(origin, footprint):
		sum += map_generator.cell_to_world(cell)
		count += 1
	if count <= 0:
		return map_generator.cell_to_world(origin)
	return sum / float(count)

func _cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var center: Vector2 = map_generator.cell_to_world(cell)
	var size := _grid_cell_size()
	if _uses_square_test_grid():
		var half := size * 0.5
		return PackedVector2Array([
			center + Vector2(-half.x, -half.y),
			center + Vector2(half.x, -half.y),
			center + Vector2(half.x, half.y),
			center + Vector2(-half.x, half.y),
		])
	var half_width := size.x * 0.5
	var half_height := size.y * 0.5
	return PackedVector2Array([
		center + Vector2(0, -half_height),
		center + Vector2(half_width, 0),
		center + Vector2(0, half_height),
		center + Vector2(-half_width, 0),
	])

func _grid_cell_size() -> Vector2:
	if _uses_square_test_grid():
		return Vector2(64, 64)
	var layer = map_generator.get("layer_low")
	if layer != null and is_instance_valid(layer) and layer.get("tile_set") != null:
		return Vector2(layer.get("tile_set").tile_size)
	return Vector2(111, 55)

func _uses_square_test_grid() -> bool:
	if map_generator == null:
		return false
	var map_type := str(map_generator.get("map_type_id"))
	return map_type == "seeded_grid_frontier" or map_type == "grid_test_canvas" or map_type == "ai_testing_ground" or map_type == "fortress_ai_arena" or map_type == "plot_generator_test"

func _footprint_extents(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ONE
	var min_cell: Vector2i = cells[0]
	var max_cell: Vector2i = cells[0]
	for cell in cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	return max_cell - min_cell + Vector2i.ONE

func _structure_color(archetype: StringName) -> Color:
	match archetype:
		&"bio_absorber":
			return Color("#7BC47F")
		&"barracks":
			return Color("#8B1A1F")
		&"terrible_vault":
			return Color("#7DDDE8")
		&"vinewall":
			return Color("#2D5A3E")
		&"bio_launcher":
			return Color("#C13030")
	return Color("#8A7560")

func _plot_id_for_cell(cell: Vector2i) -> String:
	if map_generator == null or not map_generator.has_method("get_economy_zones"):
		return ""
	for zone in map_generator.get_economy_zones():
		for economy_cell in zone.get("economy_spaces", []):
			if economy_cell == cell:
				return str(zone.get("plot_id", ""))
	return ""
