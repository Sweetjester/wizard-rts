class_name BlockGothicDetails
extends RefCounted

const SIDES: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
var _root: Node3D
var _definition: BlockStructureDefinition
var _stone: Array[Transform3D] = []
var _iron: Array[Transform3D] = []
var _stems: Array[Transform3D] = []
var _leaves: Array[Transform3D] = []
var _spires: Array[Transform3D] = []
var _lamps: Array[Transform3D] = []
var _rng := RandomNumberGenerator.new()
var _panels: Array[Dictionary] = []

func build(definition: BlockStructureDefinition) -> Node3D:
	_definition = definition
	_root = Node3D.new()
	_root.name = "GothicDetails"
	_rng.seed = 73193
	_windows()
	_vines()
	_gate_surrounds()
	_observatory()
	_pinnacles()
	_corbel_braces()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.78
	rod.bottom_radius = 1.0
	rod.height = 1.0
	rod.radial_segments = 6
	_batch("CarvedArches", _stone, rod, BlockMaterialPalette.make_material(BlockMaterialPalette.Family.PALE_STONE))
	_batch("Tracery", _iron, rod, BlockMaterialPalette.make_material(BlockMaterialPalette.Family.METAL))
	_batch("VineStems", _stems, rod, _colour_material(Color("#35282d")))
	var leaf_material := ShaderMaterial.new()
	leaf_material.shader = preload("res://assets/structures/arcane_stone/burgundy_leaf.gdshader")
	_batch("BurgundyLeaves", _leaves, _leaf_mesh(), leaf_material, true)
	var spike := CylinderMesh.new()
	spike.top_radius=0.0
	spike.bottom_radius=1.0
	spike.height=1.0
	spike.radial_segments=6
	_batch("GothicPinnacles",_spires,spike,BlockMaterialPalette.make_material(BlockMaterialPalette.Family.ROOF))
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius=0.38
	lamp_mesh.height=1.15
	lamp_mesh.radial_segments=6
	lamp_mesh.rings=3
	var lamp_material := StandardMaterial3D.new()
	lamp_material.albedo_color=Color("#62e1db")
	lamp_material.emission_enabled=true
	lamp_material.emission=Color("#36d7da")
	lamp_material.emission_energy_multiplier=1.7
	_batch("GateLanternGlass",_lamps,lamp_mesh,lamp_material)
	_root.set_meta("window_panels", _panels.size())
	return _root

func _colour_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _batch(label: String, transforms: Array[Transform3D], mesh: Mesh, material: Material, colours: bool = false) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = colours
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	var palette: Array[Color] = [Color("#762129"), Color("#9c2833"), Color("#ac3841"), Color("#521c27"), Color("#89302c")]
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
		if colours:
			multi.set_instance_color(i,palette[i % palette.size()])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = multi
	instance.material_override = material
	_root.add_child(instance)

func _rod(target: Array[Transform3D], a: Vector3, b: Vector3, radius: float) -> void:
	var delta := b-a
	if delta.length() < 0.001:
		return
	var basis := Basis(Quaternion(Vector3.UP, delta.normalized()))
	target.append(Transform3D(basis * Basis.from_scale(Vector3(radius,delta.length(),radius)),(a+b)*0.5))

func _windows() -> void:
	# Flood each exposed glass face, so a window is treated as one panel rather
	# than one decoration per block. Irregular/nonrectangular panels stay untouched.
	for side in SIDES:
		var faces := {}
		for raw in _definition.solid_cells:
			var cell: Vector3i = raw
			if BlockMaterialPalette.family_for(_definition.solid_cells[cell]) == BlockMaterialPalette.Family.GLASS and not _definition.solid_cells.has(cell+side):
				faces[cell] = true
		var across := Vector3i(side.z,0,-side.x)
		while not faces.is_empty():
			var seed: Vector3i = faces.keys()[0]
			var queue: Array[Vector3i] = [seed]
			faces.erase(seed)
			var low_u := Vector3(seed).dot(Vector3(across))
			var high_u := low_u
			var low_y := seed.y
			var high_y := seed.y
			var cursor := 0
			while cursor < queue.size():
				var cell := queue[cursor]
				cursor += 1
				var u := Vector3(cell).dot(Vector3(across))
				low_u = minf(low_u,u)
				high_u = maxf(high_u,u)
				low_y = mini(low_y,cell.y)
				high_y = maxi(high_y,cell.y)
				for step: Vector3i in [across,-across,Vector3i.UP,Vector3i.DOWN]:
					if faces.has(cell+step):
						faces.erase(cell+step)
						queue.append(cell+step)
			var width := high_u-low_u+1.0
			var height := float(high_y-low_y+1)
			if queue.size() != int(width*height) or height < 2.0:
				continue
			var centre := Vector3(seed)+Vector3.ONE*0.5+Vector3(side)*0.525
			centre += Vector3(across)*((low_u+high_u)*0.5-Vector3(seed).dot(Vector3(across)))
			centre.y = (low_y+high_y+1.0)*0.5
			var panel := {"centre":centre,"side":Vector3(side),"across":Vector3(across),"width":width,"height":height}
			_panels.append(panel)
			_window(panel)
	# Bound the number of real lights; emissive glazing remains on every window.
	_panels.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["width"]*a["height"] > b["width"]*b["height"])
	for i in mini(12,_panels.size()):
		var p := _panels[i]
		var light := OmniLight3D.new()
		light.position = p["centre"]+p["side"]*1.6
		light.light_color = Color("#4de4df")
		light.light_energy = 5.0
		light.omni_range = clampf(float(p["width"])*0.9+4.0,5.0,11.0)
		light.omni_attenuation = 1.5
		light.shadow_enabled = i < 4
		_root.add_child(light)

func _window(p: Dictionary) -> void:
	var width: float = p["width"]
	var height: float = p["height"]
	var across: Vector3 = p["across"]
	var normal: Vector3 = p["side"]
	var centre: Vector3 = p["centre"]
	var bays := maxi(1,roundi(width/2.8))
	var quad := QuadMesh.new()
	quad.size = Vector2(width,height)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/structures/arcane_stone/gothic_window.gdshader")
	material.set_shader_parameter("masonry",preload("res://assets/structures/arcane_stone/masonry_painted.png"))
	material.set_shader_parameter("bays",float(bays))
	material.set_shader_parameter("panel_size",Vector2(width,height))
	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = material
	instance.transform = Transform3D(Basis(across,Vector3.UP,normal),centre)
	_root.add_child(instance)
	for bay in bays:
		var w := width/float(bays)
		var base := centre+across*(-width*0.5+w*(bay+0.5))+Vector3.DOWN*height*0.5+normal*0.08
		var half := w*0.41
		for sign_x: float in [-1.0,1.0]:
			var start := base+across*half*sign_x+Vector3.UP*height*0.09
			var spring := base+across*half*sign_x+Vector3.UP*height*0.63
			_rod(_stone,start,spring,0.115)
			var prev := spring
			for j in range(1,9):
				var t := float(j)/8.0
				var next := base+across*half*sign_x*(1.0-t)+Vector3.UP*height*(0.63+0.34*(1.0-pow(1.0-t,0.8)))
				_rod(_stone,prev,next,0.115)
				prev=next
		_rod(_stone,base-across*half+Vector3.UP*height*0.08,base+across*half+Vector3.UP*height*0.08,0.16)
		_rod(_iron,base+Vector3.UP*height*0.10,base+Vector3.UP*height*0.94,0.035)

func _leaf_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: Array[Vector3] = [Vector3(0,0,0.06),Vector3(-0.32,0.22,0),Vector3(0,1,0),Vector3(0,0,0.06),Vector3(0,1,0),Vector3(0.32,0.22,0)]
	for vertex in verts:
		surface.set_uv(Vector2(vertex.x+0.5,vertex.y))
		surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()

func _wall_point(point: Vector3, normal: Vector3) -> bool:
	var behind := Vector3i((point-normal*0.35).floor())
	var outside := Vector3i((point+normal*0.1).floor())
	if not _definition.solid_cells.has(behind) or _definition.solid_cells.has(outside) or _definition.nav_cells.has(outside) or _definition.open_cells.has(outside):
		return false
	var family := BlockMaterialPalette.family_for(_definition.solid_cells[behind])
	return family == BlockMaterialPalette.Family.STONE or family == BlockMaterialPalette.Family.PALE_STONE

func _vines() -> void:
	var count := 0
	for raw in _definition.solid_cells:
		var cell: Vector3i = raw
		if cell.y != 6+absi(cell.x*17+cell.z*31)%20:
			continue
		for side in SIDES:
			var hash_value := absi(cell.x*73+cell.z*151+cell.y*37+side.x*17+side.z*11)
			if hash_value%5 != 0 or count >= 140:
				continue
			var normal := Vector3(side)
			var across := Vector3(side.z,0,-side.x)
			var start := Vector3(cell)+Vector3.ONE*0.5+normal*0.62
			if not _wall_point(start,normal):
				continue
			if not _wall_point(start+Vector3.DOWN*2.0,normal):
				continue
			count += 1
			var prev := start
			var length := mini(cell.y-1,_rng.randi_range(7,21))
			for step in range(1,length*3):
				var t := float(step)/3.0
				var point := start+Vector3.DOWN*t+across*(sin(t*0.36+hash_value)*1.4+sin(t*1.1)*0.25)
				if not _wall_point(point,normal):
					prev=point
					continue
				if _wall_point(prev,normal):
					_rod(_stems,prev,point,0.12)
				prev=point
				for branch_sign: float in [-1.0,1.0]:
					var tip := point+across*branch_sign*_rng.randf_range(0.3,1.15)+Vector3.UP*_rng.randf_range(0.15,0.6)
					if not _wall_point(tip,normal):
						continue
					_rod(_stems,point,tip,0.026)
					if _rng.randf() < 0.27:
						continue
					for leaf_index in 4:
						var leaf_point := point.lerp(tip,float(leaf_index+1)/4.0)+normal*0.03
						var basis := Basis(across,Vector3.UP,normal).rotated(normal,branch_sign*_rng.randf_range(0.5,1.4))
						var size := _rng.randf_range(0.4,0.85)
						_leaves.append(Transform3D(basis.scaled(Vector3.ONE*size),leaf_point))

func _gate_surrounds() -> void:
	for cells: Array in _gate_groups():
		if cells.is_empty():
			continue
		var low := Vector3(cells[0])
		var high := low
		for cell in cells:
			low=low.min(Vector3(cell))
			high=high.max(Vector3(cell))
		var size := high-low+Vector3.ONE
		var across := Vector3.RIGHT if size.x >= size.z else Vector3.BACK
		var normal := Vector3.FORWARD if size.x >= size.z else Vector3.LEFT
		if (size.x >= size.z and low.z > _definition.dimensions.z*0.5) or (size.x < size.z and low.x > _definition.dimensions.x*0.5):
			normal = -normal
		var width := maxf(size.x,size.z)
		var base := (low+high+Vector3.ONE)*0.5
		base.y=low.y
		base+=normal*(minf(size.x,size.z)*0.5+0.2)
		# The pointed arch sits outside/above the full rectangular gate clearance.
		for sign_x: float in [-1.0,1.0]:
			var foot := base+across*(width*0.5+0.35)*sign_x
			var shoulder := foot+Vector3.UP*(size.y+0.2)
			_rod(_stone,foot,shoulder,0.32)
			_rod(_stone,shoulder,base+Vector3.UP*(size.y+width*0.48),0.32)
			var mount := foot+across*sign_x*1.25+Vector3.UP*minf(size.y,4.6)
			var hook := mount+normal*1.1+Vector3.UP*0.45
			var lamp := hook+Vector3.DOWN*1.25
			_rod(_iron,mount,hook,0.09)
			_rod(_iron,hook,lamp+Vector3.UP*0.6,0.045)
			_lamps.append(Transform3D(Basis.IDENTITY,lamp))
			_spires.append(Transform3D(Basis.from_scale(Vector3(0.55,0.55,0.55)),lamp+Vector3.UP*0.72))
			for cage in 6:
				var theta := float(cage)/6.0*TAU
				var offset := Vector3(cos(theta)*0.35,0,sin(theta)*0.35)
				_rod(_iron,lamp+offset+Vector3.DOWN*0.46,lamp+offset+Vector3.UP*0.46,0.035)
			var light := OmniLight3D.new()
			light.position=lamp+normal*0.4
			light.light_color=Color("#35d5d7")
			light.light_energy=4.0
			light.omni_range=7.0
			_root.add_child(light)

func _gate_groups() -> Array[Array]:
	var groups: Array[Array] = []
	for key in _definition.gate_cells:
		var remaining := {}
		for cell in _definition.gate_cells[key]:
			remaining[cell]=true
		while not remaining.is_empty():
			var first: Vector3i=remaining.keys()[0]
			remaining.erase(first)
			var group: Array=[first]
			var cursor := 0
			while cursor < group.size():
				var cell: Vector3i=group[cursor]
				cursor+=1
				for offset: Vector3i in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
					if remaining.has(cell+offset):
						remaining.erase(cell+offset)
						group.append(cell+offset)
			groups.append(group)
	return groups

func _observatory() -> void:
	# Visual attachment positions follow the authored observation prefab instance.
	var mounts := {
		&"kons_arcane_citadel_01": Vector3(13,34,83),
		&"kons_observation_wizard_tower_01": Vector3(9,30,9),
	}
	if not mounts.has(_definition.id) and not _definition.art.has("dome"):
		return
	var centre: Vector3 = mounts.get(_definition.id, Vector3.ZERO)
	var radius := 5.6
	var height := 2.3 if _definition.id==&"kons_observation_wizard_tower_01" else 5.0
	if _definition.art.has("dome"):
		var p: Array = _definition.art["dome"]
		centre = Vector3(p[0], p[1], p[2]) * 4.0
		radius = float(_definition.art.get("dome_radius", 1.5)) * 4.0
		height = float(_definition.art.get("dome_height", 0.7)) * 4.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 10:
		for sector in 32:
			for offset: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var theta := float(sector+offset.x)/32.0*TAU
				var phi := float(ring+offset.y)/10.0*PI*0.5
				var point := Vector3(cos(theta)*cos(phi)*radius,sin(phi)*height,sin(theta)*cos(phi)*radius)
				surface.set_normal(Vector3(point.x/radius,point.y/height,point.z/radius).normalized())
				surface.set_uv(Vector2(float(sector+offset.x)/32.0,float(ring+offset.y)/10.0))
				surface.add_vertex(point)
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://assets/structures/arcane_stone/observatory_glass.gdshader")
	var instance := MeshInstance3D.new()
	instance.name = "ObservationDome"
	instance.position = centre
	instance.mesh = surface.commit()
	instance.material_override = glass
	_root.add_child(instance)
	for rib in 12:
		var theta := float(rib)/12.0*TAU
		var prev := centre+Vector3(cos(theta)*radius,0,sin(theta)*radius)
		for step in range(1,13):
			var phi := float(step)/12.0*PI*0.5
			var point := centre+Vector3(cos(theta)*cos(phi)*radius,sin(phi)*height,sin(theta)*cos(phi)*radius)
			_rod(_iron,prev,point,0.095)
			prev=point
	for phi: float in [0.0,0.35,0.75,1.1]:
		for sector in 48:
			var a := float(sector)/48.0*TAU
			var b := float(sector+1)/48.0*TAU
			_rod(_iron,centre+Vector3(cos(a)*cos(phi)*radius,sin(phi)*height,sin(a)*cos(phi)*radius),centre+Vector3(cos(b)*cos(phi)*radius,sin(phi)*height,sin(b)*cos(phi)*radius),0.09)
	_rod(_iron,centre+Vector3.UP*height,centre+Vector3.UP*(height+2.4),0.16)
	for side in SIDES:
		var foot := centre+Vector3(side)*4.8
		_rod(_iron,foot,foot+Vector3.UP*2.2+Vector3(side)*0.8,0.12)

func _pinnacles() -> void:
	for raw in _definition.solid_cells:
		var cell: Vector3i=raw
		if cell.y < 20 or BlockMaterialPalette.family_for(_definition.solid_cells[cell]) != BlockMaterialPalette.Family.ROOF:
			continue
		if _definition.solid_cells.has(cell+Vector3i.UP) or _definition.nav_cells.has(cell+Vector3i.UP):
			continue
		var edge_x := not _definition.solid_cells.has(cell+Vector3i.LEFT) or not _definition.solid_cells.has(cell+Vector3i.RIGHT)
		var edge_z := not _definition.solid_cells.has(cell+Vector3i.FORWARD) or not _definition.solid_cells.has(cell+Vector3i.BACK)
		if not edge_x or not edge_z:
			continue
		var base := Vector3(cell)+Vector3(0.5,1.0,0.5)
		_rod(_stone,base,base+Vector3.UP*1.1,0.62)
		_spires.append(Transform3D(Basis.from_scale(Vector3(0.7,2.5,0.7)),base+Vector3.UP*2.3))
		_rod(_iron,base+Vector3.UP*3.4,base+Vector3.UP*4.4,0.045)

func _corbel_braces() -> void:
	for panel in _panels:
		var width: float=panel["width"]
		if width < 6.0:
			continue
		var centre: Vector3=panel["centre"]
		var normal: Vector3=panel["side"]
		var across: Vector3=panel["across"]
		for index in int(width/3.0):
			var top := centre+across*(-width*0.5+1.5+index*3.0)+Vector3.DOWN*(float(panel["height"])*0.5+0.4)
			var bottom := top+Vector3.DOWN*2.4
			if not _wall_point(bottom,normal):
				continue
			var tip := top+normal*0.75
			var clear := true
			for sample_index in 14:
				var point := bottom.lerp(tip,float(sample_index)/13.0)
				var cell := Vector3i(point.floor())
				if _definition.nav_cells.has(cell) or _definition.open_cells.has(cell):
					clear=false
					break
			if clear:
				_rod(_stems,bottom,tip,0.22)
				_rod(_stems,top,tip,0.22)
