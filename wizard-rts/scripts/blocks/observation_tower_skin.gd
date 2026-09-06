class_name ObservationTowerSkin
extends BlockGothicDetails

const HD = preload("res://scripts/blocks/observation_tower_remaster.gd")

static func material_for(family: int) -> ShaderMaterial:
	if family==3: return HD.material(7)
	if family==4: return HD.material(8)
	return HD.material(family)

static func replaces_block(cell: Vector3i, material_name: StringName) -> bool:
	# Visual replacements only. Authored collision and navigation remain untouched.
	if material_name==&"METAL" and cell.y>=30: return true
	if material_name==&"METAL" and cell.x==17 and cell.y>=20 and cell.y<=22: return true
	if material_name!=&"TIMBER": return false
	if cell.x>=14 and cell.y==23 and cell.z>=8 and cell.z<=9: return true
	return (cell.x>=2 and cell.x<=4 and cell.y>=9 and cell.y<=11 and cell.z>=7 and cell.z<=10) or (cell.x>=12 and cell.x<=14 and cell.y>=14 and cell.y<=16 and cell.z>=8 and cell.z<=10)

func build(definition: BlockStructureDefinition) -> Node3D:
	var result:=super(definition)
	var lights: Array[OmniLight3D]=[]
	for child in result.get_children():
		if child is GeometryInstance3D and child.material_override is ShaderMaterial:
			var mat: ShaderMaterial=child.material_override
			if mat.shader==preload("res://assets/structures/arcane_stone/painted_structure.gdshader"):
				child.material_override=material_for(int(mat.get_shader_parameter("family")))
		if child is OmniLight3D:
			lights.append(child)
			child.light_energy=minf(child.light_energy,1.8)
			child.shadow_enabled=false
			child.distance_fade_enabled=true
			child.distance_fade_begin=60
			child.distance_fade_length=25
	var dome := result.get_node("ObservationDome") as MeshInstance3D
	var glass := ShaderMaterial.new()
	glass.shader=preload("res://assets/structures/observation_tower_hd/dome.gdshader")
	glass.set_shader_parameter("surfaces",preload("res://assets/structures/observation_tower_hd/surfaces.png"))
	dome.material_override=glass
	result.add_child(HD.new().build(definition))
	var leaf_mat := ShaderMaterial.new()
	leaf_mat.shader=preload("res://assets/structures/observation_tower_hd/leaf.gdshader")
	result.get_node("BurgundyLeaves").material_override=leaf_mat
	# Six non-shadowing lights per tower; emission does the rest at RTS distance.
	lights.sort_custom(func(a: OmniLight3D,b: OmniLight3D) -> bool: return _light_priority(a)<_light_priority(b))
	for i in range(6,lights.size()):
		result.remove_child(lights[i])
		lights[i].free()
	var lamp_mat: StandardMaterial3D=result.get_node("GateLanternGlass").material_override
	lamp_mat.emission_energy_multiplier=.8
	result.add_child(preload("res://scripts/blocks/observation_tower_effects.gd").new())
	result.set_meta("skin_id","observation_tower_hd_v3")
	return result

func _light_priority(light: OmniLight3D) -> float:
	if light.position.x>16: return 0
	if light.position.y<7: return 1+light.position.z*.01
	if light.position.y>25: return 2+light.position.z*.01
	return 3+light.position.y*.01

func _window(p: Dictionary) -> void:
	var width: float=p.width
	var height: float=p.height
	var across: Vector3=p.across
	var normal: Vector3=p.side
	var centre: Vector3=p.centre
	var bays := maxi(1,roundi(width/2.8))
	for bay in bays:
		var w := width/bays
		var at := centre+across*(-width*.5+w*(bay+.5))+normal*.07
		HD.plaque(_root,at,Vector2(w*.94,height),normal,0)
		# Deep sill and outer jambs give the drawn atlas a physical edge.
		var base := at-Vector3.UP*(height*.5-.08)+normal*.07
		_rod(_stone,base-across*w*.46,base+across*w*.46,.14)
		for sign_x: int in [-1,1]:
			var start := base+across*w*.46*sign_x
			var shoulder := start+Vector3.UP*height*.58
			_rod(_stone,start,shoulder,.10)
			_rod(_stone,shoulder,at+Vector3.UP*height*.49+normal*.07,.10)

func _leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := [Vector3(0,0,0),Vector3(-.4,.20,0),Vector3(-.23,.4,0),Vector3(-.52,.59,0),Vector3(-.14,.64,0),Vector3(0,1,0),Vector3(.17,.67,0),Vector3(.47,.57,0),Vector3(.25,.38,0),Vector3(.36,.18,0)]
	var centre := Vector3(0,.43,.13)
	for i in edge.size():
		for p: Vector3 in [centre,edge[i],edge[(i+1)%edge.size()]]:
			st.set_uv(Vector2(p.x+.5,p.y))
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()

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
				var size:=_rng.randf_range(0.32,0.55)
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
