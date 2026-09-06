class_name BlockStructureBuilder
extends Node3D

# Turns a BlockStructureDefinition into visible geometry and collision.
#
# This is the VISUAL layer and nothing else. It reads the same authored
# definition the navigation layer reads, but nothing reads it back -- that
# one-way direction is what keeps the spec's rule true: navigation is never
# inferred from rendered geometry. Deleting this node leaves traversal exactly
# as correct as it was.
#
# Blocks are a single MultiMesh with per-instance colour rather than a node per
# cell. A mid-sized structure is 400-1000 cells and the ziggurat is 680; that is
# a lot of nodes to spawn for something the player mostly sees as a silhouette.
#
# Collision is one StaticBody3D with a box shape per solid cell. Deliberately
# not merged into a convex hull: the cells ARE the authored truth, and a merged
# hull would quietly round off the carved gate passage.

# Primitive colours for readability, not art. Final art is explicitly out of
# scope for this system -- the point is to see the structure, not to dress it.
const MATERIAL_COLORS := {
	&"STONE_BRICK": Color("#8C8F96"),
	&"MOSSY_STONE": Color("#6E8B62"),
	&"BLACK_STONE": Color("#3A3B45"),
	&"TIMBER": Color("#8A6038"),
	&"BONE": Color("#D8CFB4"),
	&"METAL_GATE": Color("#B5763A"),
	&"RUIN_STONE": Color("#7A7466"),
	&"MAGIC_STONE": Color("#6A5AA8"),
	&"VOID_DECOR": Color("#202028"),
	# Schema 1.1 materials.
	&"TOWER_STONE": Color("#A8A79B"),
	&"DARK_STONE": Color("#4A4C55"),
	&"GLASS": Color("#5FD0E0"),
	&"METAL": Color("#3C4048"),
	&"GATE": Color("#7A5230"),
	&"EMPTY": Color("#202028"),
}

# Stair treads are drawn a shade lighter than the stone around them, because
# their job is to be READ as circulation from an RTS camera, not to blend in.
const STAIR_COLOR := Color("#C4B896")
const RAMP_COLOR := Color("#B9A87E")

var definition: BlockStructureDefinition

var _blocks: MultiMeshInstance3D
var _collision: StaticBody3D
# state_key -> the node holding that gate's leaf, so it can be hidden when the
# gate opens. Collision and navigation already switch together; this is the
# visual half, without which an open gate still looks shut.
var _gate_meshes: Dictionary = {}
var _family_meshes: Array[MultiMeshInstance3D] = []
var _gothic_details: Node3D
var _compact_visual: BlockStructureBuilder

func build(structure: BlockStructureDefinition) -> void:
	definition = structure
	_clear()
	if definition == null:
		return
	if definition.art.get("bespoke_skin", "") == "steel_barracks_hd_v1":
		_gothic_details = preload("res://scripts/blocks/steel_barracks_skin.gd").new().build()
		add_child(_gothic_details)
		_gothic_details.rotation.y = -definition.rotation_steps * PI * 0.5
		match definition.rotation_steps:
			1: _gothic_details.position.x = 14.0
			2: _gothic_details.position = Vector3(9,0,14)
			3: _gothic_details.position.z = 9.0
		_gate_meshes[&"steel_farm_open"] = _gothic_details.get_node("FarmGate")
		_gate_meshes[&"steel_muster_open"] = _gothic_details.get_node("MusterGate")
		_gate_meshes[&"steel_service_open"] = _gothic_details.get_node("ServiceGate")
		_build_collision()
		return
	if definition.art.get("bespoke_skin", "") == "observer_vault_v1":
		_gothic_details = preload("res://scripts/blocks/compact_observer_vault.gd").new().build()
		add_child(_gothic_details)
		_gothic_details.rotation.y = -definition.rotation_steps * PI * 0.5
		match definition.rotation_steps:
			1: _gothic_details.position.x = 7.0
			2: _gothic_details.position = Vector3(9,0,7)
			3: _gothic_details.position.z = 9.0
		_gate_meshes[&"vault_entry_open"] = _gothic_details.get_node("VaultGate")
		_gate_meshes[&"vault_service_open"] = _gothic_details.get_node("ServiceGate")
		_build_collision()
		return
	if definition.runtime_profile and definition.art.get("bespoke_skin", "") == "splicing_lab_v2":
		_gothic_details = preload("res://scripts/blocks/compact_splicing_lab.gd").new().build()
		add_child(_gothic_details)
		_gothic_details.rotation.y = -definition.rotation_steps * PI * 0.5
		match definition.rotation_steps:
			1: _gothic_details.position.x = 7.0
			2: _gothic_details.position = Vector3(9, 0, 7)
			3: _gothic_details.position.z = 9.0
		_gate_meshes[&"lab_entry_open"] = _gothic_details.get_node("MusterGate")
		_gate_meshes[&"lab_service_open"] = _gothic_details.get_node("ServiceGate")
		_build_collision()
		return
	if definition.runtime_profile:
		_build_compact_visual()
		return
	_build_blocks()
	var skin := BlockArchitecturalSkin.build(definition)
	add_child(skin)
	_family_meshes.append(skin)
	var frames := BlockArchitecturalSkin.build_window_frames(definition)
	add_child(frames)
	_family_meshes.append(frames)
	# Full-size master skins use their original coordinates. Compact profiles
	# take the separate visual branch above, including its own decoration anchors.
	if bool(definition.art.get("compact_skin", false)):
		_gothic_details = preload("res://scripts/blocks/compact_kon_skin.gd").new().build(definition)
	elif definition.id==&"kons_observation_wizard_tower_01":
		var canonical := definition if definition.rotation_steps==0 else definition.rotated(4-definition.rotation_steps)
		_gothic_details = ObservationTowerSkin.new().build(canonical)
		_gothic_details.transform = _tower_art_transform()
		for instance in _family_meshes:
			if instance.material_override is ShaderMaterial:
				var family := int(instance.material_override.get_shader_parameter("family"))
				instance.material_override=ObservationTowerSkin.material_for(family)
	elif definition.id==&"kons_splicing_laboratory_01":
		_gothic_details = SplicingLaboratorySkin.new().build(definition)
	else:
		_gothic_details = BlockGothicDetails.new().build(definition)
	add_child(_gothic_details)
	_build_stairs()
	_build_gates()
	if definition.id==&"kons_observation_wizard_tower_01" and not definition.art.get("compact_skin",false):
		if has_node("Stairs"):
			get_node("Stairs").material_override=ObservationTowerSkin.material_for(BlockMaterialPalette.Family.PALE_STONE)
		for key in _gate_meshes:
			_gate_meshes[key].material_override=ObservationTowerSkin.material_for(BlockMaterialPalette.Family.TIMBER)
			var door := preload("res://scripts/blocks/observation_tower_remaster.gd").plaque(_gate_meshes[key],Vector3(9,3,3.98),Vector2(1.96,3.98),Vector3.FORWARD,3)
			door.transform=_tower_art_transform()*door.transform
	_build_collision()

func _tower_art_transform() -> Transform3D:
	var transform := Transform3D(Basis(Vector3.UP,-definition.rotation_steps*PI*.5),Vector3.ZERO)
	match definition.rotation_steps:
		1: transform.origin.x=18
		2: transform.origin=Vector3(18,0,18)
		3: transform.origin.z=18
	return transform

func _build_compact_visual() -> void:
	# Subdivide the compact architecture for painted masonry and fine tracery.
	# This adds visual detail, not gameplay cells. No information is downsampled.
	var library := BlockStructureLibrary.load_default()
	var data := definition.source_data.duplicate(true)
	data["compact_runtime"] = false
	data["dimensions"] = data["dimensions"].map(func(v: int) -> int: return v * 4)
	data["art"]["compact_skin"] = true
	for field in ["blocks", "nav_regions"]:
		for entry in data.get(field, []):
			var original_y: Variant = entry["region"].get("y", 0)
			entry["region"] = _art_region(entry["region"], field == "nav_regions")
			# Thin floor slabs leave room for full-sized units between storeys.
			if field == "blocks" and entry.get("material", "") == "DARK_STONE" and not original_y is Array and int(original_y)>0:
				entry["region"]["y"] = int(original_y)*4+3
	for gate in data.get("gates", []):
		gate["block_region"] = _art_region(gate["block_region"], false)
		gate["passage_region"] = _art_region(gate["passage_region"], true)
	for link in data.get("links", []):
		for end in ["from", "to"]:
			var p: Array = link[end]
			link[end] = [int(p[0])*4+2, int(p[1])*4, int(p[2])*4+2]
		link["width"] = int(link.get("width", 1))*4
	var art_definition := BlockStructureDefinition.from_data(definition.id, data, library.materials)
	_carve_visual_stair_clearance(art_definition)
	_compact_visual = BlockStructureBuilder.new()
	_compact_visual.name = "PaintedQuarterScale"
	add_child(_compact_visual)
	_compact_visual.build(art_definition)
	_scale_compact_materials(_compact_visual)
	_compact_visual.scale = Vector3.ONE * 0.25
	_compact_visual.rotation.y = -definition.rotation_steps * PI * 0.5
	var dims: Array = definition.source_data["dimensions"]
	match definition.rotation_steps:
		1: _compact_visual.position.x = float(dims[2])
		2: _compact_visual.position = Vector3(float(dims[0]), 0, float(dims[2]))
		3: _compact_visual.position.z = float(dims[0])

func _carve_visual_stair_clearance(art_definition: BlockStructureDefinition) -> void:
	# The authored links also reserve headroom through the visual floor slabs.
	# This changes only the dressing plan, never the runtime navigation graph.
	for link in art_definition.links:
		if link.type not in [&"STAIR", &"RAMP"]: continue
		var start := Vector3(link.from)+Vector3(0.5,0,0.5)
		var end := Vector3(link.to)+Vector3(0.5,0,0.5)
		var samples := maxi(1, ceili(start.distance_to(end)*2.0))
		for i in samples+1:
			var p := start.lerp(end,float(i)/float(samples))
			for dx in range(-1,2):
				for dz in range(-1,2):
					for dy in 10:
						var c := Vector3i(floori(p.x)+dx,ceili(p.y)+dy,floori(p.z)+dz)
						art_definition.solid_cells.erase(c)
						art_definition.open_cells[c] = &"EMPTY"

func _scale_compact_materials(node: Node) -> void:
	if node is GeometryInstance3D and node.material_override is ShaderMaterial:
		var material: ShaderMaterial = node.material_override
		if material.shader == preload("res://assets/structures/arcane_stone/painted_structure.gdshader"):
			material.set_shader_parameter("paint_scale", 4.0)
	if node is OmniLight3D:
		# Light ranges are physical distances, not inherited mesh dimensions.
		node.omni_range *= 0.25
		node.light_energy *= 0.65
	for child in node.get_children(): _scale_compact_materials(child)

func _art_region(region: Dictionary, floor_only: bool) -> Dictionary:
	var result := {}
	for axis in ["x", "y", "z"]:
		var value: Variant = region.get(axis, 0)
		var low: int = int(value[0]) if value is Array else int(value)
		var high: int = int(value[1]) if value is Array else int(value)
		result[axis] = low*4 if floor_only and axis == "y" else [low*4, (high+1)*4-1]
	return result

func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_blocks = null
	_collision = null
	_gate_meshes.clear()
	_family_meshes.clear()
	_gothic_details = null
	_compact_visual = null

# One MultiMesh per MATERIAL FAMILY rather than one for the whole structure.
#
# Each family selects its painted shader treatment. Batching keeps the material
# count independent of the number of authored cells.
func _build_blocks() -> void:
	var gated := _all_gate_cells()
	var by_family := {}
	for cell in definition.solid_cells:
		if gated.has(cell):
			continue
		if not definition.art.get("compact_skin", false) and definition.id==&"kons_observation_wizard_tower_01":
			var canonical_cell := definition._turn_cell(cell,(4-definition.rotation_steps)%4)
			if ObservationTowerSkin.replaces_block(canonical_cell,definition.solid_cells[cell]): continue
		if not definition.art.get("compact_skin", false) and definition.id==&"kons_splicing_laboratory_01" and cell.y>=2 and cell.y<=5 and cell.x>=9 and cell.x<=22 and cell.z>=9 and cell.z<=15 and definition.solid_cells[cell] in [&"GLASS",&"METAL"]:
			continue
		var family := BlockMaterialPalette.family_for(definition.solid_cells[cell])
		if not by_family.has(family):
			by_family[family] = [] as Array[Vector3i]
		(by_family[family] as Array[Vector3i]).append(cell)
	for family in by_family:
		var cells: Array[Vector3i] = by_family[family]
		var instance := MultiMeshInstance3D.new()
		instance.name = "Blocks_%d" % int(family)
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = cells.size()
		for i in cells.size():
			multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_centre(cells[i])))
			multimesh.set_instance_color(i, BlockMaterialPalette.instance_tint(family, cells[i]))
		multimesh.visible_instance_count = cells.size()
		instance.multimesh = multimesh
		instance.material_override = BlockMaterialPalette.make_material(family)
		add_child(instance)
		_family_meshes.append(instance)

func _all_gate_cells() -> Dictionary:
	var cells := {}
	for state_key in definition.gate_cells:
		for cell in definition.gate_cells[state_key]:
			cells[cell] = state_key
	return cells

func _build_gates() -> void:
	for state_key in definition.gate_cells:
		var cells: Array = definition.gate_cells[state_key]
		if cells.is_empty():
			continue
		var instance := MultiMeshInstance3D.new()
		instance.name = "Gate_%s" % state_key
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = cells.size()
		for i in cells.size():
			multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_centre(cells[i])))
			multimesh.set_instance_color(i, BlockMaterialPalette.albedo_for(BlockMaterialPalette.Family.TIMBER))
		multimesh.visible_instance_count = cells.size()
		instance.multimesh = multimesh
		instance.material_override = BlockMaterialPalette.make_material(BlockMaterialPalette.Family.TIMBER)
		add_child(instance)
		_gate_meshes[state_key] = instance

# Hides the leaf of an open gate, so what you see matches what units can walk
# through. The spec asks for collision and navigation to switch together; this
# is the visual half of that.
func set_gate_open(state_key: StringName, open: bool) -> void:
	if is_instance_valid(_compact_visual):
		_compact_visual.set_gate_open(state_key, open)
	if _gate_meshes.has(state_key):
		var gate := _gate_meshes[state_key] as Node3D
		if gate.has_method("set_open"): gate.call("set_open",open)
		else: gate.visible = not open

# Generates visible step geometry along every STAIR and RAMP link.
#
# The spec is explicit that stairs must be built as block steps rather than
# existing only as invisible links, and it is right to insist: a tower whose
# floors are connected by nothing you can see reads as a stack of disconnected
# platforms. This is the one place geometry is DERIVED rather than authored --
# and it derives from the authored LINK, never the other way round. Navigation
# still comes from the link; these blocks are decoration that happens to be
# honest about where the link goes.
func _build_stairs() -> void:
	var treads: Array[Dictionary] = []
	for link in definition.links:
		var type: StringName = link["type"]
		if type != &"STAIR" and type != &"RAMP":
			continue
		treads.append_array(_tread_cells(link))
	if treads.is_empty():
		return
	var instance := MultiMeshInstance3D.new()
	instance.name = "Stairs"
	var mesh := BoxMesh.new()
	# Slightly under a full block so each tread reads as a separate step rather
	# than merging into a smooth ramp.
	mesh.size = Vector3(0.96, 0.9, 0.96)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = treads.size()
	for i in treads.size():
		var tread: Dictionary = treads[i]
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_centre(tread["cell"])))
		multimesh.set_instance_color(i, tread["color"])
	multimesh.visible_instance_count = treads.size()
	instance.multimesh = multimesh
	instance.material_override = BlockMaterialPalette.make_material(BlockMaterialPalette.Family.PALE_STONE)
	add_child(instance)

# One tread per step along the link, widened across the direction of travel.
# The tread sits one block BELOW the walking line, because a unit stands on a
# step rather than inside it.
func _tread_cells(link: Dictionary) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	var from: Vector3i = link["from"]
	var to: Vector3i = link["to"]
	var delta := to - from
	var steps: int = maxi(maxi(absi(delta.x), absi(delta.y)), absi(delta.z))
	if steps <= 0:
		return cells
	# Treads are pale paving, a shade brighter than the walls around them,
	# because their job is to read as circulation from an RTS camera.
	var color: Color = BlockMaterialPalette.albedo_for(BlockMaterialPalette.Family.PALE_STONE)
	if link["type"] == &"RAMP":
		color = color.lightened(0.08)
	# Widen perpendicular to the dominant horizontal direction.
	var across := Vector3i(0, 0, 1) if absi(delta.x) >= absi(delta.z) else Vector3i(1, 0, 0)
	var width: int = maxi(1, int(link.get("width", 1)))
	var seen := {}
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var point := Vector3i(
			from.x + roundi(float(delta.x) * t),
			from.y + roundi(float(delta.y) * t),
			from.z + roundi(float(delta.z) * t))
		for w in width:
			var lateral := w-width/2 if definition.art.get("compact_skin", false) else w
			var cell: Vector3i = point + across * lateral + Vector3i(0, -1, 0)
			if seen.has(cell):
				continue
			# Never overwrite authored structure: a tread that lands inside a
			# wall would poke a lighter block through it.
			if definition.is_solid(cell):
				continue
			seen[cell] = true
			cells.append({"cell": cell, "color": color})
	return cells

func _build_collision() -> void:
	_collision = StaticBody3D.new()
	_collision.name = "Collision"
	add_child(_collision)
	# One shape per AUTHORED BLOCK, not per cell. A cell-per-shape body is 2432
	# nodes for the observation tower and 104220 for the citadel, which simply
	# never finishes loading -- the citadel demo hung on exactly this.
	#
	# Collision here serves occlusion queries (the x-ray silhouette), not
	# movement: movement is the authored lattice and never touches physics. So a
	# carved gate tunnel keeping its parent block's collision is correct rather
	# than merely tolerable -- a unit inside a tunnel IS occluded.
	for box_data in definition.block_boxes:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var size: Vector3 = box_data["size"]
		box.size = size
		shape.shape = box
		shape.position = (box_data["min"] as Vector3) + size * 0.5
		_collision.add_child(shape)

func set_blocks_visible(value: bool) -> void:
	if is_instance_valid(_compact_visual):
		_compact_visual.set_blocks_visible(value)
	if is_instance_valid(_gothic_details):
		_gothic_details.visible = value
	for instance in _family_meshes:
		if is_instance_valid(instance):
			instance.visible = value

func set_interior_view(enabled: bool) -> void:
	if definition == null or definition.art.get("bespoke_skin", "") != "steel_barracks_hd_v1": return
	if not is_instance_valid(_gothic_details): return
	_gothic_details.get_node("Roof").visible = not enabled
	_gothic_details.get_node("FrontCutaway").visible = not enabled

# A cell's centre in local space. Cell (0,0,0) occupies the unit cube from the
# origin, so its centre is half a block along each axis.
static func cell_centre(cell: Vector3i) -> Vector3:
	return Vector3(float(cell.x) + 0.5, float(cell.y) + 0.5, float(cell.z) + 0.5)

# The floor of a cell -- where a nav marker or a standing unit belongs.
static func cell_floor(cell: Vector3i) -> Vector3:
	return Vector3(float(cell.x) + 0.5, float(cell.y), float(cell.z) + 0.5)
