extends RefCounted

const PATH := "res://assets/structures/observation_tower_hd/"
var root: Node3D
var definition: BlockStructureDefinition
var batches: Dictionary = {}
var reserved: Dictionary = {}
var stone: ShaderMaterial
var wood: ShaderMaterial
var roof: ShaderMaterial
var bronze: ShaderMaterial
var ink: StandardMaterial3D

static func material(family: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://assets/structures/observation_tower_hd/surface.gdshader")
	mat.set_shader_parameter("masonry",preload("res://assets/structures/observation_tower_hd/masonry.png"))
	mat.set_shader_parameter("surfaces",preload("res://assets/structures/observation_tower_hd/surfaces.png"))
	mat.set_shader_parameter("family",family)
	if family==1: mat.set_shader_parameter("tint",Color(1.12,1.10,1.04))
	if family==2: mat.set_shader_parameter("tint",Color(1.6,1.6,1.55))
	if family==3: mat.set_shader_parameter("tint",Color(1.6,1.6,1.4))
	if family==6: mat.set_shader_parameter("tint",Color(1.45,1.45,1.42))
	return mat

static func detail(item: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://assets/structures/observation_tower_hd/detail.gdshader")
	mat.set_shader_parameter("atlas",preload("res://assets/structures/observation_tower_hd/details.png"))
	mat.set_shader_parameter("item",item)
	return mat

static func plaque(parent: Node3D, at: Vector3, size: Vector2, normal: Vector3, item: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size=size
	var node := MeshInstance3D.new()
	node.name="PaintedDetail%d" % item
	node.mesh=quad
	node.material_override=detail(item)
	node.transform=Transform3D(Basis(Vector3(normal.z,0,-normal.x),Vector3.UP,normal),at)
	parent.add_child(node)
	return node

func build(source: BlockStructureDefinition) -> Node3D:
	definition=source
	root=Node3D.new()
	root.name="RemasteredArchitecture"
	stone=material(1)
	wood=material(2)
	roof=material(6)
	bronze=material(3)
	ink=StandardMaterial3D.new()
	ink.albedo_color=Color("20292b")
	ink.roughness=.94
	# Dressing respects unit-height clearance, not just the cell under its feet.
	for cell: Vector3i in source.nav_cells:
		for y in 2: reserved[cell+Vector3i.UP*y]=true
	for cell in source.open_cells: reserved[cell]=true
	for link in source.links:
		var a := Vector3(link.from)+Vector3(.5,0,.5)
		var b := Vector3(link.to)+Vector3(.5,0,.5)
		var count := maxi(1,ceili(a.distance_to(b)*4))
		for i in count+1:
			var p := a.lerp(b,float(i)/count)
			for y in 2: reserved[Vector3i(p.floor())+Vector3i.UP*y]=true
	_facades()
	_balconies()
	_crown()
	_finish()
	root.set_meta("clearance_checked",true)
	return root

func clear_box(at: Vector3, size: Vector3) -> bool:
	var low := Vector3i((at-size*.5+Vector3.ONE*.01).floor())
	var high := Vector3i((at+size*.5-Vector3.ONE*.01).floor())
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			for z in range(low.z,high.z+1):
				if reserved.has(Vector3i(x,y,z)): return false
	return true

func box(at: Vector3, size: Vector3, mat: Material, basis: Basis=Basis.IDENTITY) -> void:
	var transform := Transform3D(basis*Basis.from_scale(size),at)
	var bounds := transform*AABB(Vector3.ONE*-.5,Vector3.ONE)
	if not clear_box(bounds.get_center(),bounds.size): return
	if not batches.has(mat): batches[mat]=[]
	batches[mat].append(transform)

func rod(a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	box((a+b)*.5,Vector3(width,a.distance_to(b),width),mat,Basis(Quaternion(Vector3.UP,(b-a).normalized())))

func ring(at: Vector3, radius: float, width: float, mat: Material, basis: Basis=Basis.IDENTITY) -> void:
	for i in 32:
		var a := float(i)*TAU/32
		var b := float(i+1)*TAU/32
		rod(at+basis*Vector3(cos(a)*radius,0,sin(a)*radius),at+basis*Vector3(cos(b)*radius,0,sin(b)*radius),width,mat)

func tube(a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius=radius
	shape.bottom_radius=radius*.92
	shape.height=a.distance_to(b)
	shape.radial_segments=12
	var transform := Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5)
	var bounds := transform*shape.get_aabb()
	if not clear_box(bounds.get_center(),bounds.size): return
	var node := MeshInstance3D.new()
	node.name="TelescopeBarrel"
	node.mesh=shape
	node.material_override=mat
	node.transform=transform
	root.add_child(node)

func panel(points: Array[Vector3], mat: Material) -> void:
	var bounds := AABB(points[0],Vector3.ZERO)
	for p in points: bounds=bounds.expand(p)
	if not clear_box(bounds.get_center(),bounds.size+Vector3.ONE*.01): return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()-1):
		for p in [points[0],points[i],points[i+1]]: st.add_vertex(p)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh=st.commit()
	node.material_override=mat
	root.add_child(node)

func _facades() -> void:
	# Short structural pilasters are anchored on solid exterior strips only.
	for entry in [[6.15,6.1,8.8,4.84],[11.85,6.1,8.8,4.84],[5.12,14.5,8.7,5.84],[12.88,14.5,8.7,5.84],[6.12,21.8,5.9,5.84],[11.88,21.8,5.9,5.84]]:
		box(Vector3(entry[0],entry[1],entry[3]),Vector3(.22,entry[2],.24),wood)
	for entry in [[4.0,14.0,9.7,5.0,14.0],[5.0,13.0,18.7,6.0,13.0],[6.0,12.0,23.7,6.0,12.0]]:
		var x0: float=entry[0]
		var x1: float=entry[1]
		var y: float=entry[2]
		var z0: float=entry[3]
		var z1: float=entry[4]
		for z in [z0-.12,z1+.12]:
			for x in range(int(x0),int(x1)):
				box(Vector3(x+.5,y,z),Vector3(.94,.24,.35),stone)
		for x in [x0-.12,x1+.12]:
			for z in range(int(z0),int(z1)):
				box(Vector3(x,y,z+.5),Vector3(.35,.24,.94),stone)
	# Large role emblem above the gate, with a physically raised bronze rim.
	plaque(root,Vector3(9,8.05,4.97),Vector2(2.2,2.2),Vector3.FORWARD,1)
	ring(Vector3(9,8.05,4.89),1.08,.085,bronze,Basis(Vector3.RIGHT,PI*.5))
	for data in [[Vector3(6.0,16.8,5.77),Vector3.FORWARD],[Vector3(11.9,12.1,5.77),Vector3.FORWARD],[Vector3(13.2,16.8,11),Vector3.RIGHT]]:
		plaque(root,data[0],Vector2(.82,3.4),data[1],2)
	# An open entry remains a real hole. Door artwork is attached to the gate later.
	for x in [7.65,10.35]:
		for y in 5: box(Vector3(x,1.5+y,3.78),Vector3(.38,.90,.42),stone)
	for side in [-1,1]:
		rod(Vector3(9+side*1.34,5.9,3.78),Vector3(9,7.02,3.78),.29,stone)

func canopy(x0: float, x1: float, z0: float, z1: float, eave: float, peak: float) -> void:
	var mid := (x0+x1)*.5
	panel([Vector3(x0,eave,z0),Vector3(mid,peak,z0),Vector3(mid,peak,z1),Vector3(x0,eave,z1)],roof)
	panel([Vector3(mid,peak,z0),Vector3(x1,eave,z0),Vector3(x1,eave,z1),Vector3(mid,peak,z1)],roof)
	for z in [z0,z1]:
		panel([Vector3(x0,eave,z),Vector3(x1,eave,z),Vector3(mid,peak,z)],wood)
		rod(Vector3(x0,eave,z),Vector3(mid,peak,z),.18,wood)
		rod(Vector3(x1,eave,z),Vector3(mid,peak,z),.18,wood)
		rod(Vector3(mid,eave,z),Vector3(mid,peak,z),.13,bronze)
	rod(Vector3(mid,peak,z0-.1),Vector3(mid,peak,z1+.1),.20,bronze)
	for side in [-1,1]:
		for row in 5:
			var f := (row+1)/5.0
			for col in 8:
				var p := Vector3(lerpf(mid,x0 if side<0 else x1,f),lerpf(peak,eave,f)+.035,lerpf(z0,z1,(col+.5)/8.0))
				box(p,Vector3(.10,.075,(z1-z0)/8.0-.025),roof)

func _balconies() -> void:
	canopy(.85,5.9,6.8,11.25,15.3,17.35)
	canopy(12.05,17.05,7.8,11.2,20.35,22.3)
	canopy(6.8,11.2,12.1,15.9,23.25,24.2)
	for data in [[.92,5.75,6.85,11.13,12.0,15.3],[12.12,16.95,7.85,11.1,17.0,20.35],[6.88,11.1,12.15,15.8,20.0,23.25]]:
		var x0: float=data[0]
		var x1: float=data[1]
		var z0: float=data[2]
		var z1: float=data[3]
		var y: float=data[4]
		for x in [x0,x1]:
			for z in [z0,z1]:
				rod(Vector3(x,y,z),Vector3(x,data[5],z),.17,wood)
				box(Vector3(x,y+1.24,z),Vector3(.27,.13,.27),bronze)
		for z in [z0,z1]:
			rod(Vector3(x0,y+1.15,z),Vector3(x1,y+1.15,z),.10,wood)
			rod(Vector3(x0,y-.12,z),Vector3(x1,y-.12,z),.23,wood)
			for i in 7:
				var x := lerpf(x0,x1,float(i)/6)
				rod(Vector3(x,y+.05,z),Vector3(x,y+1.12,z),.055,bronze)

func _crown() -> void:
	# The cantilever brackets end below the observation floor, never inside it.
	for side: Vector3 in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
		var across := Vector3(side.z,0,-side.x)
		for u: float in [-3.8,0.0,3.8]:
			var tip := Vector3(9,24.1,9)+side*5.65+across*u
			var foot := Vector3(9,21.7,9)+side*3.05+across*u*.55
			rod(foot,tip,.30,wood)
			rod(foot+Vector3.UP*.8,tip,.16,bronze)
		for i in 12:
			var p := Vector3(9,25.15,9)+side*6.02+across*(i-5.5)
			box(p,Vector3(.92,.53,.35) if side.z!=0 else Vector3(.35,.53,.92),stone)
			box(p+Vector3.UP*.43,Vector3(1,.13,.43) if side.z!=0 else Vector3(.43,.13,1),bronze)
		for u: float in [-5.65,5.65]:
			var p := Vector3(9,28,9)+side*5.65+across*u
			box(p,Vector3(.3,4.15,.3),wood)
			box(p+Vector3.UP*2,Vector3(.57,.22,.57),bronze)
	# Four slate hips fill the square-to-round transition without a solid flat lid.
	for side: Vector3 in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
		var across := Vector3(side.z,0,-side.x)
		var p := Vector3(9,30,9)
		panel([p+side*5.98-across*5.98,p+side*5.98+across*5.98,p+Vector3.UP*.48+side*4.5+across*4.5,p+Vector3.UP*.48+side*4.5-across*4.5],roof)
		rod(p+side*6-across*6,p+side*6+across*6,.17,bronze)
	# Compact brass armillary sits inside the already-reserved crown airspace.
	var centre := Vector3(9,33.15,9)
	ring(centre,.72,.075,bronze)
	ring(centre,.90,.065,bronze,Basis(Vector3.RIGHT,PI*.5))
	ring(centre,.79,.06,bronze,Basis(Vector3.FORWARD,PI*.36))
	rod(Vector3(9,32.25,9),Vector3(9,34.35,9),.13,bronze)
	# A wall-mounted telescope, offset from the observation platform's walking area.
	tube(Vector3(11,28,3.0),Vector3(11.35,28.35,1.35),.26,bronze)
	tube(Vector3(11.3,28.3,1.6),Vector3(11.37,28.37,1.25),.34,ink)
	tube(Vector3(11.37,28.37,1.25),Vector3(11.38,28.38,1.21),.24,material(4))

func _finish() -> void:
	var shape := _bevelled_cube()
	var count := 0
	for mat in batches:
		var mm := MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=shape
		mm.instance_count=batches[mat].size()
		for i in mm.instance_count: mm.set_instance_transform(i,batches[mat][i])
		var node := MultiMeshInstance3D.new()
		node.name="SculptedBatch%d" % count
		node.multimesh=mm
		node.material_override=mat
		root.add_child(node)
		count+=1

func _bevelled_cube() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := [Vector2(-.38,-.5),Vector2(.38,-.5),Vector2(.5,-.38),Vector2(.5,.38),Vector2(.38,.5),Vector2(-.38,.5),Vector2(-.5,.38),Vector2(-.5,-.38)]
	var rings: Array[PackedVector3Array]=[]
	for data in [[-.5,.84],[-.42,1.0],[.42,1.0],[.5,.84]]:
		var ring_points := PackedVector3Array()
		for p: Vector2 in profile: ring_points.append(Vector3(p.x*data[1],data[0],p.y*data[1]))
		rings.append(ring_points)
	for r in 3:
		for i in 8:
			var j := (i+1)%8
			for p in [rings[r][i],rings[r+1][i],rings[r+1][j],rings[r][i],rings[r+1][j],rings[r][j]]: st.add_vertex(p)
	for r in [0,3]:
		for i in range(1,7):
			var points := [rings[r][0],rings[r][i],rings[r][i+1]]
			if r==3: points.reverse()
			for p in points: st.add_vertex(p)
	st.generate_normals()
	return st.commit()
