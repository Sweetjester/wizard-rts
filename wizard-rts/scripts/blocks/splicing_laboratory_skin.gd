class_name SplicingLaboratorySkin
extends BlockGothicDetails

func build(definition: BlockStructureDefinition) -> Node3D:
	var result:=super(definition)
	_specimen_vats()
	result.set_meta("skin_id","splicing_laboratory_v1")
	return result

func _window(panel: Dictionary) -> void:
	var p: Vector3=panel["centre"]
	if p.y<6 and p.x>8 and p.x<23 and p.z>8 and p.z<16: return
	super(panel)

func _specimen_vats() -> void:
	for x in [11.0,21.0]:
		for z in [11.0,14.0]:
			var cylinder:=CylinderMesh.new()
			cylinder.top_radius=0.95
			cylinder.bottom_radius=0.95
			cylinder.height=3.1
			cylinder.radial_segments=12
			var glass:=StandardMaterial3D.new()
			glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.albedo_color=Color(0.07,0.55,0.60,0.38)
			glass.emission_enabled=true
			glass.emission=Color(0.02,0.22,0.25)
			glass.roughness=0.3
			var vat:=MeshInstance3D.new()
			vat.name="SpecimenVat"
			vat.mesh=cylinder
			vat.material_override=glass
			vat.position=Vector3(x,3.55,z)
			_root.add_child(vat)
			var specimen:=MeshInstance3D.new()
			var body:=SphereMesh.new()
			body.radius=0.49
			body.height=1.6
			body.radial_segments=12
			body.rings=6
			specimen.mesh=body
			specimen.material_override=_colour_material(Color("693b50"))
			specimen.position=Vector3(x,3.55,z)
			specimen.rotation.z=0.22 if x<16 else -0.32
			_root.add_child(specimen)
			for y in [2.0,5.1]:
				var cap:=MeshInstance3D.new()
				var disc:=CylinderMesh.new()
				disc.top_radius=1.06
				disc.bottom_radius=1.06
				disc.height=0.20
				disc.radial_segments=12
				cap.mesh=disc
				cap.position=Vector3(x,y,z)
				cap.material_override=BlockMaterialPalette.make_material(BlockMaterialPalette.Family.METAL)
				_root.add_child(cap)

func _observatory() -> void:
	# The centre stays open; only the rear chamber gets a glazed pitched canopy.
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0,1.0]:
		var a:=Vector3(16+side*12,12.8,20)
		var b:=Vector3(16,16.2,20)
		var c:=Vector3(16,16.2,24)
		var d:=Vector3(16+side*12,12.8,24)
		for p: Vector3 in [a,b,c,a,c,d]:
			surface.set_uv(Vector2(p.x/24,p.z/4))
			surface.add_vertex(p)
		_rod(_iron,a,b,0.12)
		_rod(_iron,c,d,0.12)
	surface.generate_normals()
	var roof:=MeshInstance3D.new()
	roof.name="SplicingChamberGlassCanopy"
	roof.mesh=surface.commit()
	var glass:=ShaderMaterial.new()
	glass.shader=preload("res://assets/structures/arcane_stone/observatory_glass.gdshader")
	roof.material_override=glass
	_root.add_child(roof)
	_rod(_iron,Vector3(16,16.2,19.8),Vector3(16,16.2,24.2),0.15)
	for x in [6.5,25.5]:
		var height:=17.0 if x<10 else 19.0
		_lamps.append(Transform3D(Basis.from_scale(Vector3(1.8,1.0,1.8)),Vector3(x,height,3.5)))
		_rod(_iron,Vector3(x,height-0.5,3.5),Vector3(x,height+0.7,3.5),0.12)
	# Articulated splicing arms remain inside the nonwalkable specimen islands.
	for x in [11.0,21.0]:
		_rod(_iron,Vector3(x,5.8,11),Vector3(x,7.8,11),0.12)
		_rod(_iron,Vector3(x,7.8,11),Vector3(x,7.0,14),0.11)
		_rod(_iron,Vector3(x,7,14),Vector3(x,5.8,14),0.065)

func _windows() -> void:
	super()
	for x in [6.5,25.5]:
		_window({"centre":Vector3(x,11.7,1.97),"side":Vector3.FORWARD,"across":Vector3.LEFT,"width":2.4,"height":3.8})
	for x in [10.8,21.2]:
		_window({"centre":Vector3(x,4.2,1.97),"side":Vector3.FORWARD,"across":Vector3.LEFT,"width":2.1,"height":3.5})

func _corbel_braces() -> void:
	super()
	# A wrought double helix marks the splicing entrance without blocking it.
	for strand: float in [-1.0,1.0]:
		var previous:=Vector3(16+strand*1.3,8.5,2)
		for i in range(1,25):
			var t:=i/24.0
			var p:=Vector3(16+strand*cos(t*TAU)*1.3,8.5+t*4.0,2)
			_rod(_stone,previous,p,0.11)
			previous=p
	for i in 7:
		var t:=i/6.0
		var width:=absf(cos(t*TAU))*1.3
		_rod(_iron,Vector3(16-width,8.5+t*4.0,2),Vector3(16+width,8.5+t*4.0,2),0.06)
	# Inner gallery railings stop short of the stair landings.
	for x in [8.9,23.1]:
		for z in [5.0,8.0,11.0,14.0,19.5]:
			_rod(_iron,Vector3(x,7.1,z),Vector3(x,8.3,z),0.07)
		_rod(_iron,Vector3(x,8.3,4.8),Vector3(x,8.3,15.0),0.08)
	_rod(_iron,Vector3(9.1,8.3,19.9),Vector3(22.9,8.3,19.9),0.08)
	for x in [10.0,14.0,18.0,22.0]:
		_rod(_iron,Vector3(x,7.1,19.9),Vector3(x,8.3,19.9),0.07)
