class_name ObservationTowerSkin
extends BlockGothicDetails

static func material_for(family: int) -> ShaderMaterial:
	var material:=BlockMaterialPalette.make_material(family)
	material.set_shader_parameter("masonry",preload("res://assets/structures/observation_tower/masonry.png"))
	return material

static func replaces_block(cell: Vector3i, material_name: StringName) -> bool:
	# Visual replacements only. Authored collision and navigation remain untouched.
	if material_name==&"METAL" and cell.y>=30: return true
	if material_name==&"METAL" and cell.x==17 and cell.y>=20 and cell.y<=22: return true
	if material_name!=&"TIMBER": return false
	if cell.x>=14 and cell.y==23 and cell.z>=8 and cell.z<=9: return true
	return (cell.x>=2 and cell.x<=4 and cell.y>=9 and cell.y<=11 and cell.z>=7 and cell.z<=10) or (cell.x>=12 and cell.x<=14 and cell.y>=14 and cell.y<=16 and cell.z>=8 and cell.z<=10)

func build(definition: BlockStructureDefinition) -> Node3D:
	var result:=super(definition)
	for child in result.get_children():
		if child is GeometryInstance3D and child.material_override is ShaderMaterial:
			var mat: ShaderMaterial=child.material_override
			if mat.shader==preload("res://assets/structures/arcane_stone/painted_structure.gdshader") or mat.shader==preload("res://assets/structures/arcane_stone/gothic_window.gdshader"):
				mat.set_shader_parameter("masonry",preload("res://assets/structures/observation_tower/masonry.png"))
	_roof(Vector3(0.8,16.2,6.8),Vector3(6.1,17.4,11.2))
	_roof(Vector3(11.9,21,7.8),Vector3(17.1,22.2,11.2))
	result.set_meta("skin_id","observation_tower_painted_v2")
	return result

func _windows() -> void:
	super()
	# Surface-mounted lancets occupy only solid facades, not door or balcony routes.
	var windows=[
		[Vector3(7,4.6,2.97),Vector3.FORWARD,1.4,2.6],
		[Vector3(9,14.4,5.97),Vector3.FORWARD,2.4,3.4],
		[Vector3(9,21.2,5.97),Vector3.FORWARD,1.8,3.2],
		[Vector3(3.97,5.5,9.3),Vector3.LEFT,2.4,3.7],
		[Vector3(4.97,16.5,9.5),Vector3.LEFT,2.2,3.4],
		[Vector3(13.03,11.6,9),Vector3.RIGHT,2.1,3.1],
		[Vector3(9,16.0,13.03),Vector3.BACK,2.1,3.5]]
	for data in windows:
		var n: Vector3=data[1]
		var p: Vector3=data[0]
		_window({"centre":p,"side":n,"across":Vector3(n.z,0,-n.x),"width":data[2],"height":data[3]})
		var light:=OmniLight3D.new()
		light.position=p+n*0.7
		light.light_color=Color("45dfe3")
		light.light_energy=1.6
		light.omni_range=4.5
		_root.add_child(light)

func _vines() -> void:
	super()
	for entry in [[Vector3(7.3,18.2,5.78),Vector3.FORWARD],[Vector3(10.6,18.0,5.78),Vector3.FORWARD],[Vector3(3.78,8.8,7.1),Vector3.LEFT],[Vector3(3.78,8.6,11.7),Vector3.LEFT],[Vector3(13.22,8.7,10.5),Vector3.RIGHT],[Vector3(8,9.0,14.22),Vector3.BACK]]:
		var start: Vector3=entry[0]
		var normal: Vector3=entry[1]
		var across:=Vector3(normal.z,0,-normal.x)
		var previous:=start
		for i in range(1,32):
			var t:=i*0.24
			var point:=start+Vector3.DOWN*t+across*sin(t*1.2)*0.35
			if not _wall_point(point,normal): continue
			if _wall_point(previous,normal): _rod(_stems,previous,point,0.065)
			previous=point
			# Typed, because an untyped array literal yields Variant elements and
			# every `:=` derived from one then fails to infer.
			for sign_value: float in [-1.0,1.0]:
				var angle:=sign_value*_rng.randf_range(0.45,1.45)
				var basis:=Basis(across,Vector3.UP,normal)*Basis(Vector3.FORWARD,angle)
				var size:=_rng.randf_range(0.18,0.36)
				var tip:=point+across*sign_value*_rng.randf_range(0.1,0.4)
				_rod(_stems,point,tip,0.025)
				_leaves.append(Transform3D(basis.scaled(Vector3.ONE*size),tip))

func _corbel_braces() -> void:
	super()
	for z in [7.3,10.7]:
		_rod(_stems,Vector3(4.8,9.4,z),Vector3(1.3,12,z),0.24)
		_rod(_stems,Vector3(4.8,10.8,z),Vector3(1.3,12,z),0.16)
		_rod(_iron,Vector3(0.85,13.0,z),Vector3(0.85,14.1,z),0.075)
	_rod(_iron,Vector3(0.85,14.1,6.9),Vector3(0.85,14.1,11.1),0.085)
	for z in [8.3,10.7]:
		_rod(_stems,Vector3(12.2,14.3,z),Vector3(16.7,17,z),0.24)
		_rod(_iron,Vector3(17.1,18.0,z),Vector3(17.1,19.1,z),0.07)
	_rod(_iron,Vector3(17.1,19.1,7.9),Vector3(17.1,19.1,11.1),0.08)
	# Iron framing at crown corners is outside the rectangular observation floor.
	for x in [3.2,14.8]:
		for z in [3.2,14.8]:
			_rod(_iron,Vector3(x,26,z),Vector3(x,30.2,z),0.14)
	var lamp:=Vector3(17.2,19.8,9)
	_rod(_stems,Vector3(11.5,23.5,9),Vector3(17.4,23.5,9),0.24)
	_rod(_stems,Vector3(11.7,21.6,9),Vector3(15.7,23.5,9),0.16)
	_rod(_iron,Vector3(17.2,23.5,9),lamp+Vector3.UP*0.8,0.055)
	_lamps.append(Transform3D(Basis.from_scale(Vector3(1.4,1.4,1.4)),lamp))
	for x in [-0.45,0.45]:
		_rod(_iron,lamp+Vector3(x,-0.7,0),lamp+Vector3(x,0.7,0),0.065)
	_rod(_iron,lamp+Vector3(-0.45,0.7,0),lamp+Vector3(0.45,0.7,0),0.075)
	var light:=OmniLight3D.new()
	light.position=lamp
	light.light_color=Color("3cd9db")
	light.light_energy=3
	light.omni_range=7
	_root.add_child(light)

func _roof(low: Vector3, high: Vector3) -> void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners=[Vector3(low.x,low.y,low.z),Vector3(high.x,high.y,low.z),Vector3(high.x,high.y,high.z),Vector3(low.x,low.y,high.z)]
	for index in [0,2,1,0,3,2]: surface.add_vertex(corners[index])
	surface.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.name="TimberBalconyCanopy"
	mesh.mesh=surface.commit()
	var material:=material_for(BlockMaterialPalette.Family.ROOF)
	material.set_shader_parameter("tint",Color(0.75,0.85,0.92))
	mesh.material_override=material
	_root.add_child(mesh)
