class_name BlockArchitecturalSkin
extends RefCounted

# Surface-only dressings. Never inserted into the authored cell/nav dictionaries.
static func build(definition: BlockStructureDefinition) -> MultiMeshInstance3D:
	var pieces: Array[Transform3D] = []
	var solid := definition.solid_cells
	var sides: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
	for raw_cell in solid:
		var cell: Vector3i = raw_cell
		var family := BlockMaterialPalette.family_for(solid[cell])
		if family != BlockMaterialPalette.Family.STONE and family != BlockMaterialPalette.Family.PALE_STONE:
			continue
		for side in sides:
			if solid.has(cell + side):
				continue
			# Reserve authored walking and clearance volumes, including stair endpoints.
			if definition.nav_cells.has(cell + side) or definition.open_cells.has(cell + side):
				continue
			var across := Vector3i(0, 0, 1) if side.x != 0 else Vector3i(1, 0, 0)
			var corner: bool = not solid.has(cell + across) or not solid.has(cell - across)
			var top: bool = not solid.has(cell + Vector3i.UP)
			if not top and not corner:
				continue
			var size := Vector3(1.02, 0.34, 0.22) if side.z != 0 else Vector3(0.22, 0.34, 1.02)
			var centre := Vector3(cell) + Vector3.ONE * 0.5 + Vector3(side) * 0.52
			if top:
				centre.y += 0.30
			else:
				size.y = 0.87
				# Alternating quoins read as stacked dressed corner stones.
				if cell.y % 2 == 0:
					size += Vector3(absf(float(across.x)), 0.0, absf(float(across.z))) * 0.18
			pieces.append(Transform3D(Basis.from_scale(size), centre))
	var mesh := BoxMesh.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = pieces.size()
	for i in pieces.size():
		multi.set_instance_transform(i, pieces[i])
	var result := MultiMeshInstance3D.new()
	result.name = "ArchitecturalSkin"
	result.multimesh = multi
	result.material_override = BlockMaterialPalette.make_material(BlockMaterialPalette.Family.PALE_STONE)
	return result

static func build_window_frames(definition: BlockStructureDefinition) -> MultiMeshInstance3D:
	var pieces: Array[Transform3D] = []
	var solid := definition.solid_cells
	var sides: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
	for raw_cell in solid:
		var cell: Vector3i = raw_cell
		if BlockMaterialPalette.family_for(solid[cell]) != BlockMaterialPalette.Family.GLASS:
			continue
		for side in sides:
			if solid.has(cell + side) or definition.nav_cells.has(cell + side) or definition.open_cells.has(cell + side):
				continue
			var across := Vector3i(0, 0, 1) if side.x != 0 else Vector3i(1, 0, 0)
			var centre := Vector3(cell) + Vector3.ONE * 0.5 + Vector3(side) * 0.54
			for edge: Vector3i in [Vector3i.UP, Vector3i.DOWN, across, -across]:
				var neighbour := cell + edge
				if solid.has(neighbour) and BlockMaterialPalette.family_for(solid[neighbour]) == BlockMaterialPalette.Family.GLASS:
					continue
				var size := Vector3.ONE * 0.18
				if edge.y != 0:
					size += Vector3(across) * 0.88
				else:
					size.y = 1.08
				pieces.append(Transform3D(Basis.from_scale(size), centre + Vector3(edge) * 0.46))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = BoxMesh.new()
	multi.instance_count = pieces.size()
	for i in pieces.size():
		multi.set_instance_transform(i, pieces[i])
	var result := MultiMeshInstance3D.new()
	result.name = "WindowFrames"
	result.multimesh = multi
	result.material_override = BlockMaterialPalette.make_material(BlockMaterialPalette.Family.METAL)
	return result
