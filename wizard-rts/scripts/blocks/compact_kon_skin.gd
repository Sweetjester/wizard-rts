extends BlockGothicDetails

# All generic dressing reads the detailed visual plan. Only the laboratory's
# equipment has explicit anchors, kept clear of its authored operating aisle.
func build(definition: BlockStructureDefinition) -> Node3D:
	var result := super(definition)
	if bool(definition.art.get("laboratory", false)):
		_laboratory_equipment()
	result.set_meta("skin_id", "kon_compact_painted")
	return result

func _laboratory_equipment() -> void:
	for x in [2.5, 6.5]:
		for z in [3.5, 4.5]:
			var vat := MeshInstance3D.new()
			vat.name = "SpecimenVat"
			var glass := CylinderMesh.new()
			glass.top_radius = 1.25
			glass.bottom_radius = 1.25
			glass.height = 3.2
			glass.radial_segments = 12
			vat.mesh = glass
			vat.position = Vector3(x, 2.4, z) * 4.0
			var material := StandardMaterial3D.new()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(0.08, 0.65, 0.67, 0.45)
			material.emission_enabled = true
			material.emission = Color(0.02, 0.35, 0.4)
			vat.material_override = material
			_root.add_child(vat)
			var specimen := MeshInstance3D.new()
			var body := SphereMesh.new()
			body.radius = 0.6
			body.height = 2.0
			specimen.mesh = body
			specimen.material_override = _colour_material(Color("713c4d"))
			specimen.position = vat.position
			_root.add_child(specimen)
	var roof := MeshInstance3D.new()
	roof.name = "SplicingChamberGlassCanopy"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		# A rear clerestory canopy, outside the open upper walkway at z=5.
		var a := Vector3(18+side*14, 17, 24)
		var b := Vector3(18, 20, 24)
		var c := Vector3(18, 20, 27)
		var d := Vector3(18+side*14, 17, 27)
		for point: Vector3 in [a,b,c,a,c,d]:
			surface.set_uv(Vector2(point.x/28.0, point.z/5.0))
			surface.add_vertex(point)
	surface.generate_normals()
	roof.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/structures/arcane_stone/observatory_glass.gdshader")
	roof.material_override = material
	_root.add_child(roof)
