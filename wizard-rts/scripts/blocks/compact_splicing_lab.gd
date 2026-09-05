extends RefCounted

# A purpose-built 9 x 5 x 7 shell. Coordinates are game units, never a scaled
# version of the large laboratory. This class cannot modify navigation.
var root: Node3D
var stone: ShaderMaterial
var iron: StandardMaterial3D
var wood: ShaderMaterial
var glass: StandardMaterial3D
var painted_glass: ShaderMaterial
var red: StandardMaterial3D
var batches: Dictionary = {}
var rng := RandomNumberGenerator.new()

func build() -> Node3D:
	root = Node3D.new()
	root.name = "GothicDetails"
	rng.seed = 748120
	stone = ShaderMaterial.new()
	stone.shader = preload("res://assets/structures/arcane_stone/painted_structure.gdshader")
	stone.set_shader_parameter("masonry", preload("res://assets/structures/observation_tower/masonry.png"))
	stone.set_shader_parameter("paint_scale", 1.3)
	stone.set_shader_parameter("tint", Color("aac1c5"))
	wood = stone.duplicate()
	wood.set_shader_parameter("family", 2)
	iron = material(Color("162b30"))
	red = material(Color("7c283c"))
	glass = material(Color("248e99"))
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.emission_enabled = true
	glass.emission = Color("127e89")
	glass.emission_energy_multiplier = 0.65
	painted_glass = ShaderMaterial.new()
	painted_glass.shader = preload("res://assets/structures/arcane_stone/observatory_glass.gdshader")
	_foundation()
	_walls()
	_portal()
	_roof()
	_interior()
	_roots()
	_finish_batches()
	return root

func material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.94
	return mat

func box(at: Vector3, size: Vector3, mat: Material, tilt: float = 0.0) -> void:
	if not batches.has(mat): batches[mat] = []
	var basis := Basis(Vector3.UP, tilt) * Basis.from_scale(size)
	batches[mat].append(Transform3D(basis, at))

func rod(a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var delta := b-a
	if delta.length() < 0.001: return
	var up := delta.normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length() < 0.01: right = Vector3.RIGHT
	var basis := Basis(right, up, right.cross(up)) * Basis.from_scale(Vector3(radius*2,delta.length(),radius*2))
	if not batches.has(mat): batches[mat] = []
	batches[mat].append(Transform3D(basis,(a+b)*0.5))

func _finish_batches() -> void:
	var index := 0
	for mat in batches:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = batches[mat].size()
		var bounds: AABB = batches[mat][0] * mesh.get_aabb()
		for i in multi.instance_count:
			multi.set_instance_transform(i,batches[mat][i])
			bounds = bounds.merge(batches[mat][i] * mesh.get_aabb())
		var node := MultiMeshInstance3D.new()
		node.name = "PaintedDetails%d" % index
		node.multimesh = multi
		node.material_override = mat
		node.set_meta("authored_bounds",bounds)
		root.add_child(node)
		index += 1

func _foundation() -> void:
	box(Vector3(4.5,0.45,3.5),Vector3(8.9,0.9,6.9),iron)
	for x in 18:
		for z in 14:
			box(Vector3(x*0.5+0.25,0.94,z*0.5+0.25),Vector3(0.48,0.12,0.48),stone,rng.randf_range(-0.025,0.025))
	for side in [0.2,8.8]:
		for z in 10:
			box(Vector3(side,0.5,1.3+z*0.55),Vector3(0.37,0.7,0.52),stone)

func wall(a: Vector3, b: Vector3, height: float, thickness: float) -> void:
	var length := a.distance_to(b)
	var along := (b-a).normalized()
	var rows := ceili(height/0.34)
	for row in rows:
		var offset := -0.28 if row % 2 else 0.0
		var cursor := offset
		while cursor < length:
			var end := minf(cursor+rng.randf_range(0.48,0.76),length)
			var start := maxf(cursor,0.0)
			if end-start > 0.04:
				var p := a+along*((start+end)*0.5)+Vector3.UP*(row*0.34+0.16)
				var size := Vector3(end-start-0.025,0.315,thickness+rng.randf_range(-0.018,0.018))
				if absf(along.z)>0.5: size = Vector3(size.z,size.y,size.x)
				box(p,size,stone,rng.randf_range(-0.012,0.012))
			cursor = end

func _walls() -> void:
	# All wall dressing stays within the authored wall cells.
	wall(Vector3(0.3,1,1.3),Vector3(0.3,1,6.7),2.7,0.5)
	wall(Vector3(8.7,1,1.3),Vector3(8.7,1,3),2.7,0.5)
	wall(Vector3(8.7,1,5),Vector3(8.7,1,6.7),2.7,0.5)
	wall(Vector3(0.3,1,6.7),Vector3(8.7,1,6.7),2.7,0.5)
	wall(Vector3(0.3,1,1.35),Vector3(3,1,1.35),2.35,0.55)
	wall(Vector3(5,1,1.35),Vector3(8.7,1,1.35),2.35,0.55)
	for x in [0.5,2.7,5.3,8.5]:
		box(Vector3(x,2.05,1.18),Vector3(0.32,2.1,0.55),stone)
		box(Vector3(x,3.13,1.18),Vector3(0.5,0.18,0.72),stone)
		rod(Vector3(x,1.05,0.8),Vector3(x,2.75,1.2),0.105,wood)
	for x in [1.45,6.35,7.5]: _window(Vector3(x,2.15,1.04),0.7,1.25)
	for x in [2.1,4.5,6.9]: _window(Vector3(x,2.45,6.97),0.85,1.65,1.0)
	for z in [2.4,5.65]:
		box(Vector3(0.22,2,z),Vector3(0.25,1.8,0.3),wood)
		box(Vector3(8.78,2,z),Vector3(0.25,1.8,0.3),wood)
	# Unequal retorts provide a recognisable silhouette without exceeding y=5.
	for datum in [Vector3(1.25,4.8,1.6),Vector3(7.8,4.35,1.65)]:
		var height: float = datum.y-3.1
		box(Vector3(datum.x,3.1+height*0.5,datum.z),Vector3(0.52,height,0.55),stone)
		box(Vector3(datum.x,datum.y-0.15,datum.z),Vector3(0.76,0.18,0.8),iron)
		box(Vector3(datum.x,datum.y-0.05,datum.z),Vector3(0.42,0.08,0.43),glass)
		for y in [3.3,3.85]: box(Vector3(datum.x,y,datum.z),Vector3(0.59,0.1,0.63),iron)

func _window(at: Vector3, width: float, height: float, facing: float = -1.0) -> void:
	var vertices := PackedVector3Array([
		at+Vector3(-width*0.5,-height*0.5,0),at+Vector3(width*0.5,-height*0.5,0),
		at+Vector3(width*0.5,height*0.12,0),at+Vector3(0,height*0.5,0),
		at+Vector3(-width*0.5,height*0.12,0)])
	_polygon(vertices,glass)
	for i in vertices.size(): rod(vertices[i],vertices[(i+1)%vertices.size()],0.03,iron)
	rod(at+Vector3(0,-height*0.5,facing*0.008),at+Vector3(0,height*0.46,facing*0.008),0.018,iron)
	for side in [-1,1]:
		rod(at+Vector3(0,-0.2,facing*0.008),at+Vector3(side*width*0.45,0.1,facing*0.008),0.017,iron)
	box(at+Vector3(0,-height*0.53,-0.04),Vector3(width+0.18,0.12,0.1),stone)
	_light(at+Vector3(0,0,facing*0.25),1.9,0.6)

func _polygon(points: PackedVector3Array, mat: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()-1):
		for p in [points[0],points[i],points[i+1]]:
			surface.set_uv(Vector2(p.x*0.18+p.z*0.12,p.y*0.25+p.z*0.1))
			surface.add_vertex(p)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = painted_glass if mat == glass else mat
	root.add_child(node)
	return node

func _portal() -> void:
	var last_left := Vector3(2.92,2.7,1.0)
	var last_right := Vector3(5.08,2.7,1.0)
	for i in range(1,9):
		var t := float(i)/8.0
		var left := Vector3(2.92+1.08*t,2.7+1.3*sin(t*PI*0.5),1.0)
		var right := Vector3(5.08-1.08*t,left.y,1.0)
		rod(last_left,left,0.13,stone)
		rod(last_right,right,0.13,stone)
		last_left = left
		last_right = right
	# The arch is open below y=3; no false doorway painted onto a wall.
	box(Vector3(4,3.85,1.5),Vector3(1.55,0.24,0.38),wood)
	_gate("MusterGate",Vector3(4,2,1.48),Vector3(1.9,1.95,0.13))
	_gate("ServiceGate",Vector3(8.66,2,4),Vector3(0.13,1.95,1.9))
	for x in [2.55,5.45]:
		rod(Vector3(x,2.85,1.2),Vector3(x,2.85,0.6),0.045,iron)
		rod(Vector3(x,2.85,0.6),Vector3(x,2.45,0.6),0.022,iron)
		box(Vector3(x,2.27,0.6),Vector3(0.17,0.3,0.17),glass)
		box(Vector3(x,2.45,0.6),Vector3(0.26,0.07,0.26),iron)
		_light(Vector3(x,2.25,0.55),2.5,0.8)

func _gate(label: String, at: Vector3, size: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = wood
	node.position = at
	root.add_child(node)
	for y in [-0.65,0.65]:
		var band := MeshInstance3D.new()
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(size.x+0.025,0.11,size.z+0.025)
		band.mesh = band_mesh
		band.material_override = iron
		band.position.y = y
		node.add_child(band)

func _roof() -> void:
	# A narrow glazed nave leaves both stair runs and the rear gallery exposed.
	var roof_mat := painted_glass
	for side in [-1,1]:
		for z in 6:
			for strip in 4:
				var t0 := float(strip)/4
				var t1 := float(strip+1)/4
				var x0: float = 4.5+side*2.3*t0
				var x1: float = 4.5+side*2.3*t1
				var y0 := 4.82-1.22*pow(t0,0.75)
				var y1 := 4.82-1.22*pow(t1,0.75)
				var z0 := 1.8+z*0.48
				var pane := _polygon(PackedVector3Array([Vector3(x0,y0,z0),Vector3(x1,y1,z0),Vector3(x1,y1,z0+0.48),Vector3(x0,y0,z0+0.48)]),roof_mat)
				if side == -1 and z == 0 and strip == 0: pane.name = "SplicingChamberGlassCanopy"
				rod(Vector3(x0,y0+0.02,z0),Vector3(x1,y1+0.02,z0),0.037,iron)
				rod(Vector3(x1,y1+0.02,z0),Vector3(x1,y1+0.02,z0+0.48),0.026,iron)
				rod(Vector3(x0,y0+0.015,z0),Vector3(x1,y1+0.015,z0+0.48),0.012,iron)
	rod(Vector3(4.5,4.86,1.7),Vector3(4.5,4.86,4.78),0.06,iron)
	for x in [2.2,6.8]:
		box(Vector3(x,3.57,3.25),Vector3(0.14,0.18,3.15),wood)
		for z in [2.0,4.55]: rod(Vector3(x,2.65,z),Vector3(x,3.6,z),0.08,wood)
	# The front tympanum is translucent; the gate passage beneath stays clear.
	_polygon(PackedVector3Array([Vector3(2.2,3.6,1.8),Vector3(6.8,3.6,1.8),Vector3(4.5,4.82,1.8)]),roof_mat)
	for x in [3.1,3.8,4.5,5.2,5.9]:
		rod(Vector3(x,3.6,1.77),Vector3(4.5,4.79,1.77),0.025,iron)

func _interior() -> void:
	# Gallery deck at exactly nav y=4, ground deck at exactly y=1.
	for x in 14: box(Vector3(1.25+x*0.5,3.93,5.5),Vector3(0.48,0.14,0.96),wood)
	for x in [2.1,3.4,4.7,6.0,6.9]:
		rod(Vector3(x,4,5.02),Vector3(x,4.65,5.02),0.032,iron)
	rod(Vector3(2.1,4.65,5.02),Vector3(6.9,4.65,5.02),0.033,iron)
	for x in [1.5,7.5]:
		for i in 16:
			var t := float(i+1)/16
			box(Vector3(x,1+3*t-0.06,3.5+2*t),Vector3(0.83,0.12,0.18),wood)
		for side in [-0.44,0.44]:
			rod(Vector3(x+side,1.6,3.5),Vector3(x+side,4.6,5.5),0.035,iron)
	for x in [2.5,6.5]:
		for z in [3.5,4.5]:
			_vat(Vector3(x,1,z))
	_light(Vector3(4.5,3.4,3.4),3.5,0.9)

func _vat(at: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.31
	mesh.bottom_radius = 0.36
	mesh.height = 1.4
	mesh.radial_segments = 12
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var liquid := glass.duplicate() as StandardMaterial3D
	liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid.albedo_color.a = 0.48
	node.material_override = liquid
	node.position = at+Vector3.UP*0.9
	root.add_child(node)
	for y in [0.2,1.6]:
		for i in 12:
			var a := TAU*i/12
			var b := TAU*(i+1)/12
			rod(at+Vector3(cos(a)*0.36,y,sin(a)*0.36),at+Vector3(cos(b)*0.36,y,sin(b)*0.36),0.045,iron)
	for i in 4:
		var angle := TAU*i/4
		var delta := Vector3(cos(angle)*0.33,0,sin(angle)*0.33)
		rod(at+delta+Vector3.UP*0.2,at+delta+Vector3.UP*1.6,0.027,iron)
	var specimen := SphereMesh.new()
	specimen.radius = 0.17
	specimen.height = 0.57
	var body := MeshInstance3D.new()
	body.mesh = specimen
	body.material_override = red
	body.position = at+Vector3.UP*0.92
	body.rotation.z = 0.35
	root.add_child(body)
	rod(at+Vector3(-0.16,0.8,0),at+Vector3(0.14,1.15,0.04),0.045,red)

func _roots() -> void:
	for x in [1.1,3.25,5.7,7.95]:
		var previous := Vector3(x,1.05,6.97)
		for i in 14:
			var p := Vector3(x+sin(i*0.7+x)*0.25,1.05+i*0.18,6.97)
			rod(previous,p,0.023,red)
			if i%2 == 0: box(p+Vector3(0.08,0.04,0),Vector3(0.15,0.07,0.04),red)
			previous = p
	for x in [0.65,2.6,5.5,8.25]:
		var last := Vector3(x,1.05,0.99)
		for i in 16:
			var p := Vector3(x+sin(i*0.68+x)*0.18,1.05+i*0.15,0.98)
			rod(last,p,0.025,red)
			if i%2 == 0:
				var end := p+Vector3(0.22 if i%4 else -0.22,0.13,-0.04)
				rod(p,end,0.017,red)
				box(end,Vector3(0.12,0.055,0.07),red,0.6)
			last = p
	for side in [0.55,8.45]:
		var last := Vector3(side,1.05,1.3)
		for i in 24:
			var p := Vector3(side,1.2+0.45*sin(i*0.5),1.3+i*0.22)
			rod(last,p,0.04,wood)
			box(p+Vector3(0,0.09,0),Vector3(0.12,0.07,0.18),red,0.7)
			last = p

func _light(at: Vector3, radius: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color("56dfe8")
	light.light_energy = energy
	light.omni_range = radius
	root.add_child(light)
