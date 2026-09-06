extends RefCounted

const PATH := "res://assets/structures/steel_barracks_hd/"
var root: Node3D
var roof: Node3D
var front: Node3D
var batches: Dictionary = {}
var stone: Material
var slate: Material
var wood: Material
var ink: Material
var brass: Material
var cloth: Material
var soil: Material
var glass: Material
var glazing: Material
var door_paint: Material
var banner_paint: Material
var straw: Material
var rng := RandomNumberGenerator.new()

func build() -> Node3D:
	rng.seed=932164
	root=Node3D.new()
	root.name="GothicDetails"
	roof=group("Roof",root)
	front=group("FrontCutaway",root)
	stone=paint("masonry",Color("e4e2d7"),.333333)
	slate=paint("slate",Color("b2bdc5"),.48)
	wood=paint("timber",Color("c9b99a"),.42)
	ink=colour("242724")
	brass=colour("98815a")
	cloth=colour("c6bb94")
	soil=colour("424339")
	glass=colour("ffc979")
	glass.emission_enabled=true
	glass.emission=Color("ffb84f")
	glass.emission_energy_multiplier=.8
	glazing=detail(Vector2.ZERO,1.3)
	door_paint=detail(Vector2(1,0))
	banner_paint=detail(Vector2(0,1))
	banner_paint.set_shader_parameter("wind",.025)
	straw=detail(Vector2(1,1))
	_foundation()
	_hall()
	_roofline()
	_farm()
	_interior()
	_finish()
	return root

func group(label: String, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name=label
	parent.add_child(node)
	return node

func paint(file: String, tint: Color, density: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=load(PATH+"painted_surface.gdshader")
	mat.set_shader_parameter("paint",load(PATH+file+".png"))
	mat.set_shader_parameter("tint",tint)
	mat.set_shader_parameter("repeats_per_cell",density)
	return mat

func colour(hex: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color(hex)
	mat.roughness=.95
	return mat

func detail(quadrant: Vector2, glow: float=0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=load(PATH+"painted_detail.gdshader")
	mat.set_shader_parameter("atlas",load(PATH+"details.png"))
	mat.set_shader_parameter("quadrant",quadrant)
	mat.set_shader_parameter("glow",glow)
	return mat

func decal(at: Vector3, size: Vector2, mat: Material, parent: Node3D=null, angle: float=0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rotation := Basis(Vector3.UP,angle)
	for uv in [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(0,0)]:
		st.set_uv(uv)
		st.add_vertex(at+rotation*Vector3((uv.x-.5)*size.x,(.5-uv.y)*size.y,0))
	st.generate_normals()
	mesh(st.commit(),Vector3.ZERO,mat,parent)

func box(at: Vector3, size: Vector3, mat: Material, parent: Node3D=null, basis: Basis=Basis.IDENTITY) -> void:
	if parent==null: parent=root
	if not batches.has(parent): batches[parent]={}
	if not batches[parent].has(mat): batches[parent][mat]=[]
	batches[parent][mat].append(Transform3D(basis*Basis.from_scale(size),at))

func rod(a: Vector3, b: Vector3, width: float, mat: Material, parent: Node3D=null) -> void:
	var up := (b-a).normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	if side.length_squared()<.1: side=Vector3.RIGHT
	box((a+b)*.5,Vector3(width,a.distance_to(b),width),mat,parent,Basis(side,up,side.cross(up)))

func mesh(shape: Mesh, at: Vector3, mat: Material, parent: Node3D=null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=shape
	node.material_override=mat
	node.position=at
	(parent if parent!=null else root).add_child(node)
	return node

func cylinder(at: Vector3, radius: float, height: float, mat: Material, parent: Node3D=null, top: float=-1) -> void:
	var shape := CylinderMesh.new()
	shape.bottom_radius=radius
	shape.top_radius=radius if top<0 else top
	shape.height=height
	shape.radial_segments=12
	mesh(shape,at,mat,parent)

func ellipsoid(at: Vector3, size: Vector3, mat: Material) -> void:
	var shape := SphereMesh.new()
	shape.radius=.5
	shape.height=1
	shape.radial_segments=12
	shape.rings=6
	mesh(shape,at,mat).scale=size

func panel(points: Array[Vector3], mat: Material, parent: Node3D=null) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()-1):
		for p in [points[0],points[i],points[i+1]]:
			st.set_uv(Vector2(p.x,p.z))
			st.add_vertex(p)
	st.generate_normals()
	mesh(st.commit(),Vector3.ZERO,mat,parent)

func _finish() -> void:
	for parent in batches:
		for mat in batches[parent]:
			var cube := BoxMesh.new()
			cube.size=Vector3.ONE
			var mm := MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.mesh=cube
			mm.instance_count=batches[parent][mat].size()
			var bounds: AABB = batches[parent][mat][0]*cube.get_aabb()
			for i in mm.instance_count:
				mm.set_instance_transform(i,batches[parent][mat][i])
				bounds=bounds.merge(batches[parent][mat][i]*cube.get_aabb())
			var node := MultiMeshInstance3D.new()
			node.multimesh=mm
			node.material_override=mat
			node.set_meta("authored_bounds",bounds)
			parent.add_child(node)

func _foundation() -> void:
	box(Vector3(1.5,.46,7),Vector3(3,.92,14),ink)
	box(Vector3(7,.46,7),Vector3(4,.92,14),ink)
	box(Vector3(4,.46,8),Vector3(2,.92,12),ink)
	box(Vector3(1.6,.97,3.5),Vector3(2.8,.06,6.7),soil)
	box(Vector3(6.9,.97,3.5),Vector3(3.8,.06,6.7),soil)
	box(Vector3(4,.97,4.5),Vector3(2,.06,5),soil)
	box(Vector3(4.5,.98,10.5),Vector3(8.8,.04,6.8),stone)
	for x in range(18):
		for z in [0,27]:
			if z==0 and x in [6,7,8,9]: continue
			box(Vector3(x*.5+.25,.64,z*.5+.25),Vector3(.48,.64,.46),stone)
	for z in range(1,27):
		for x in [.25,8.75]: box(Vector3(x,.64,z*.5+.25),Vector3(.46,.64,.48),stone)
	for x in range(6):
		for z in range(14):
			if x<4 and z<4: continue
			box(Vector3(3.05+x*.48,1.005,.24+z*.48),Vector3(.45,.035,.45),stone,null,Basis(Vector3.UP,rng.randf_range(-.025,.025)))
	panel([Vector3(3,.025,0),Vector3(5,.025,0),Vector3(5,1.01,2),Vector3(3,1.01,2)],stone)
	for x in range(18):
		for z in [11,12,13]: box(Vector3(.25+x*.5,1.01,z*.5),Vector3(.47,.04,.47),stone)

func _hall() -> void:
	# The inner edge of these walls stays within the authored exterior wall cells.
	box(Vector3(.35,2.12,10.5),Vector3(.7,2.24,7),stone)
	box(Vector3(8.65,2.12,8.5),Vector3(.7,2.24,3),stone)
	box(Vector3(8.65,2.12,12.5),Vector3(.7,2.24,3),stone)
	box(Vector3(8.65,3.15,11),Vector3(.7,.24,2),wood)
	box(Vector3(4.5,2.5,13.65),Vector3(7.6,3,.7),stone)
	box(Vector3(1.5,2.05,7.4),Vector3(3,2.1,.8),stone,front)
	box(Vector3(7,2.05,7.4),Vector3(4,2.1,.8),stone,front)
	box(Vector3(4,3.15,7.4),Vector3(2,.3,.8),wood,front)
	for z in [7.15,9,11.9,13.7]:
		for x in [.15,8.85]:
			box(Vector3(x,2.15,z),Vector3(.22,2.3,.25),wood)
	for y in [1.22,2.95,3.2]:
		box(Vector3(4.5,y,13.89),Vector3(8.7,.15,.16),wood)
		for x in [.11,8.89]: box(Vector3(x,y,10.5),Vector3(.15,.15,6.8),wood)
	for x in [1,2.7,5.3,7.8]: box(Vector3(x,2.2,7.03),Vector3(.15,2.25,.18),wood,front)
	for pair in [[.8,2.7],[5.3,7.7]]:
		rod(Vector3(pair[0],1.4,6.99),Vector3(pair[1],2.95,6.99),.13,wood,front)
	for z in [8.35,12.6]:
		window(Vector3(.22,2.3,z),.75,.95,PI*.5)
		window(Vector3(8.78,2.3,z),.75,.95,-PI*.5)
	for x in [2,4.4,6.8]: window(Vector3(x,2.45,13.77),.75,1,PI)
	window(Vector3(1.75,2.23,6.97),.9,1,0,front)
	window(Vector3(6.7,2.25,6.97),1.15,1.1,0,front)
	gate("FarmGate",Vector3(4,.68,.35),Vector3(1.96,.95,.14),true)
	gate("MusterGate",Vector3(4,1.95,7.45),Vector3(1.96,1.9,.14))
	gate("ServiceGate",Vector3(8.65,1.95,11),Vector3(.14,1.9,1.96))
	for x in [2.86,5.14]:
		box(Vector3(x,1.96,7.09),Vector3(.25,1.92,.35),wood)
		lantern(Vector3(x,2.35,6.85))

func gate(label: String, at: Vector3, size: Vector3, rails: bool=false) -> void:
	var node := group(label,root)
	if rails:
		for x in range(8): box(at+Vector3((x-3.5)*.24,0,0),Vector3(.13,size.y,.13),wood,node)
		for y in [-.23,.23]: box(at+Vector3(0,y,0),Vector3(size.x,.12,.17),wood,node)
		rod(at+Vector3(-.85,-.25,-.1),at+Vector3(.85,.25,-.1),.09,brass,node)
	else:
		box(at,size,wood,node)
		if size.x>size.z:
			decal(at+Vector3(0,0,-size.z*.5-.01),Vector2(size.x,size.y),door_paint,node)
		else:
			decal(at+Vector3(size.x*.5+.01,0,0),Vector2(size.z,size.y),door_paint,node,-PI*.5)
		for y in [-.65,.6]: box(at+Vector3(0,y,0),Vector3(size.x+.02,.1,size.z+.04),ink,node)

func window(at: Vector3, width: float, height: float, angle: float=0, parent: Node3D=null) -> void:
	var rotation := Basis(Vector3.UP,angle)
	box(at,Vector3(width+.16,height+.16,.12),ink,parent,rotation)
	decal(at+rotation*Vector3(0,0,-.08),Vector2(width,height),glazing,parent,angle)
	for x in [-width*.5,width*.5]: box(at+rotation*Vector3(x,0,-.11),Vector3(.08,height+.2,.16),wood,parent,rotation)
	for y in [-height*.5,height*.5]: box(at+rotation*Vector3(0,y,-.11),Vector3(width+.2,.08,.16),wood,parent,rotation)
	for x in [0]:
		box(at+rotation*Vector3(x*width,0,-.1),Vector3(.025,height,.03),ink,parent,rotation)
	for y in [0]:
		box(at+rotation*Vector3(0,y*height,-.1),Vector3(width,.025,.03),ink,parent,rotation)

func lantern(at: Vector3) -> void:
	box(at,Vector3(.19,.3,.19),glass)
	for y in [-.2,.2]: box(at+Vector3(0,y,0),Vector3(.29,.1,.29),ink)
	for x in [-.11,.11]:
		for z in [-.11,.11]: rod(at+Vector3(x,-.17,z),at+Vector3(x,.17,z),.03,ink)
	rod(at+Vector3(0,.25,0),at+Vector3(0,.55,.18),.035,ink)
	var light := OmniLight3D.new()
	light.position=at+Vector3(0,0,-.25)
	light.light_color=Color("ffcc83")
	light.light_energy=.65
	light.omni_range=2.6
	light.shadow_enabled=false
	root.add_child(light)

func gable(x0: float, x1: float, z0: float, z1: float, eave: float, ridge: float, parent: Node3D) -> void:
	var mid := (x0+x1)*.5
	panel([Vector3(x0,eave,z0),Vector3(mid,ridge,z0),Vector3(mid,ridge,z1),Vector3(x0,eave,z1)],slate,parent)
	panel([Vector3(mid,ridge,z0),Vector3(x1,eave,z0),Vector3(x1,eave,z1),Vector3(mid,ridge,z1)],slate,parent)
	for z in [z0,z1]:
		panel([Vector3(x0,eave,z),Vector3(x1,eave,z),Vector3(mid,ridge,z)],wood,parent)
		rod(Vector3(x0,eave,z),Vector3(mid,ridge,z),.12,wood,parent)
		rod(Vector3(mid,ridge,z),Vector3(x1,eave,z),.12,wood,parent)
		rod(Vector3(mid,eave,z),Vector3(mid,ridge,z),.1,wood,parent)
	rod(Vector3(mid,ridge,z0),Vector3(mid,ridge,z1),.13,ink,parent)
	for x in [x0,x1]: rod(Vector3(x,eave,z0),Vector3(x,eave,z1),.16,wood,parent)
	# Individually stepped shingle lips break the perfect roof silhouette.
	for side in [-1,1]:
		for row in 7:
			var f := (row+1)/7.0
			var x := lerpf(mid,x0 if side<0 else x1,f)
			var y := lerpf(ridge,eave,f)+.016
			for col in 13:
				var z := lerpf(z0,z1,(col+.5)/13.0)
				box(Vector3(x,y,z),Vector3(.06,.025,(z1-z0)/13-.012),slate,parent)

func _roofline() -> void:
	# The rear loft is an uncovered gallery: roof planes stop before its nav row.
	gable(1.9,8.93,8.45,11.88,3.15,4.8,roof)
	# Lower front awning extends the entrance into a sheltered muster porch.
	panel([Vector3(.2,2.65,6.3),Vector3(8.8,2.65,6.3),Vector3(8.8,3.23,8.5),Vector3(.2,3.23,8.5)],slate,roof)
	for x in [.22,2.75,5.25,8.78]:
		rod(Vector3(x,2.64,6.25),Vector3(x,3.23,8.5),.13,wood,roof)
		# Porch posts occupy wall-side strips, never the farm's central path.
		if x<1 or x>8: rod(Vector3(x,1,6.3),Vector3(x,2.65,6.3),.14,wood)
	rod(Vector3(.2,2.66,6.25),Vector3(8.8,2.66,6.25),.17,wood,roof)
	# A stout octagonal lookout gives the compound its asymmetric identity.
	cylinder(Vector3(1.05,2.5,10.3),.88,2.8,stone,roof)
	cylinder(Vector3(1.05,3.68,10.3),1.02,.3,wood,roof)
	cylinder(Vector3(1.05,4.3,10.3),1.03,1.05,slate,roof,.07)
	for i in 8:
		var a := i*TAU/8
		rod(Vector3(1.05,3.78,10.3)+Vector3(cos(a),0,sin(a))*1.03,Vector3(1.05,4.84,10.3),.045,ink,roof)
	window(Vector3(1.05,3.48,9.25),.8,.32,0,roof)
	for x in [6.9,7.5]:
		box(Vector3(x,4.24,12.85),Vector3(.35,.95,.4),stone,roof)
		box(Vector3(x,4.7,12.85),Vector3(.47,.12,.53),ink,roof)
		box(Vector3(x,4.77,12.85),Vector3(.25,.025,.29),soil,roof)
	# Front dormer and its warm window remain distinct from the dark roof planes.
	box(Vector3(6.15,3.51,8.62),Vector3(1.1,.65,.7),wood,roof)
	gable(5.45,6.85,8.15,9.35,3.82,4.34,roof)
	window(Vector3(6.15,3.54,8.21),.58,.5,0,roof)
	for x in [2.1,8.1]:
		rod(Vector3(x,3.6,13.1),Vector3(x,4.94,13.1),.035,ink,roof)
		decal(Vector3(x+.3,4.61,13.1),Vector2(.6,.55),banner_paint,roof)
	# The heraldic hanging is a visible faction cue over the entrance.
	rod(Vector3(3.3,3.57,6.2),Vector3(4.8,3.57,6.2),.055,ink,roof)
	for x in [3.35,4.75]: rod(Vector3(x,2.69,6.25),Vector3(x,3.57,6.2),.05,ink,roof)
	decal(Vector3(4.05,3.13,6.18),Vector2(1.2,.78),banner_paint,roof)

func fence(a: Vector3, b: Vector3, parent: Node3D=null) -> void:
	var count := ceili(a.distance_to(b)/.55)
	for i in range(count+1):
		var p := a.lerp(b,float(i)/count)
		box(p+Vector3(0,.5,0),Vector3(.1,.94,.11),wood,parent,Basis(Vector3.FORWARD,rng.randf_range(-.035,.035)))
	for y in [.25,.7]: rod(a+Vector3(0,y,0),b+Vector3(0,y,0),.1,wood,parent)

func barrel(at: Vector3, radius: float=.26) -> void:
	cylinder(at+Vector3(0,.3,0),radius,.6,wood)
	for y in [.08,.5]: cylinder(at+Vector3(0,y,0),radius+.018,.045,ink)
	cylinder(at+Vector3(0,.606,0),radius*.95,.025,wood)

func _farm() -> void:
	fence(Vector3(.35,1,.4),Vector3(2.92,1,.4))
	fence(Vector3(5.08,1,.4),Vector3(8.65,1,.4))
	fence(Vector3(.35,1,.4),Vector3(.35,1,6.85))
	fence(Vector3(8.65,1,.4),Vector3(8.65,1,6.85))
	for x in [2.9,5.1]:
		box(Vector3(x,1.57,.4),Vector3(.17,1.15,.18),wood)
		box(Vector3(x,2.16,.4),Vector3(.24,.08,.25),brass)
	# Farm objects are entirely inside the YAML's occupied crop/pen cells.
	box(Vector3(2,1.04,3.5),Vector3(1.82,.08,2.85),soil)
	var wheat := colour("666b49")
	var tips := colour("96845b")
	for i in 260:
		var p := Vector3(rng.randf_range(1.16,2.82),1.03,rng.randf_range(2.14,4.82))
		var h := rng.randf_range(.28,.62)
		rod(p,p+Vector3(.05,h,.025),.018,wheat)
		for j in 3:
			var y := h-.12+j*.035
			rod(p+Vector3(.04,y,0),p+Vector3(.10,y+.05,.02),.03,tips)
	for z in [2.12,4.85]: box(Vector3(2,1.08,z),Vector3(1.86,.12,.07),wood)
	fence(Vector3(6.05,1,2.08),Vector3(6.05,1,4.88))
	fence(Vector3(6.05,1,2.08),Vector3(7.86,1,2.08))
	fence(Vector3(6.05,1,4.88),Vector3(7.86,1,4.88))
	box(Vector3(7.52,1.12,2.48),Vector3(.6,.22,.36),wood)
	box(Vector3(7.52,1.24,2.48),Vector3(.48,.03,.23),soil)
	for p in [Vector3(6.75,1,3.08),Vector3(7.32,1,4.13)]: pig(p)
	barrel(Vector3(.72,1,6.32),.26)
	barrel(Vector3(8.24,1,6.34),.29)
	# Lean-to hay store sits within the livestock pen footprint.
	for x in [6.15,7.78]: rod(Vector3(x,1,4.72),Vector3(x,2.32,4.72),.09,wood)
	panel([Vector3(6.12,2.05,4.15),Vector3(7.87,2.05,4.15),Vector3(7.87,2.4,4.92),Vector3(6.12,2.4,4.92)],slate)
	for x in [6.4,7.1]:
		box(Vector3(x,1.24,4.64),Vector3(.56,.46,.38),straw)
		box(Vector3(x,1.48,4.64),Vector3(.06,.03,.4),wood)

func pig(at: Vector3) -> void:
	var hide := colour("888477")
	var pink := colour("9c8777")
	ellipsoid(at+Vector3(0,.38,0),Vector3(.57,.53,.9),hide)
	ellipsoid(at+Vector3(0,.42,-.4),Vector3(.45,.42,.46),hide)
	ellipsoid(at+Vector3(0,.32,-.63),Vector3(.26,.18,.1),pink)
	for x in [-.065,.065]: ellipsoid(at+Vector3(x,.33,-.68),Vector3(.035,.04,.025),ink)
	for x in [-.19,.19]:
		ellipsoid(at+Vector3(x,.49,-.5),Vector3(.025,.04,.04),ink)
		panel([at+Vector3(x,.52,-.4),at+Vector3(x*1.4,.78,-.4),at+Vector3(x*.4,.59,-.28)],hide)
		for z in [-.25,.25]:
			box(at+Vector3(x,.14,z),Vector3(.1,.28,.12),hide)
			box(at+Vector3(x,.035,z-.015),Vector3(.11,.07,.14),ink)
	for i in 7:
		var z := -.16+i*.075
		rod(at+Vector3(-.08,.64,z),at+Vector3(.015,.65,z+.035),.009,ink)
	for i in 9:
		var a := float(i)*TAU/9
		var b := float(i+1)*TAU/9
		rod(at+Vector3(cos(a)*.065,.4+sin(a)*.065,.45),at+Vector3(cos(b)*.065,.4+sin(b)*.065,.45),.024,pink)

func _interior() -> void:
	box(Vector3(4.5,3.9,12.5),Vector3(7,.2,1),wood)
	for x in [1.12,3,5,7.85]: rod(Vector3(x,4,12.04),Vector3(x,4.65,12.04),.065,wood)
	rod(Vector3(1.1,4.65,12.04),Vector3(2.02,4.65,12.04),.07,wood)
	rod(Vector3(2.98,4.65,12.04),Vector3(7.88,4.65,12.04),.07,wood)
	# Twelve treads rise from [2,1,9] to [2,4,12]; loft hole is not infilled.
	for i in 12:
		box(Vector3(2.5,1+(i+1)*.25-.07,9.5+(i+1)*.25),Vector3(.84,.14,.28),wood)
	for x in [2.07,2.93]: rod(Vector3(x,1,9.5),Vector3(x,3.98,12.5),.09,wood)
	for z in [10.6,11.5]:
		for y in [1.3,2.1]:
			box(Vector3(1.45,y,z),Vector3(.77,.12,.72),wood)
			box(Vector3(1.45,y+.1,z),Vector3(.7,.13,.63),cloth)
		for x in [1.08,1.82]: rod(Vector3(x,1,z-.31),Vector3(x,2.4,z-.31),.075,wood)
	# Wall-mounted polearms remain inside the east wall band, outside the aisle.
	for z in [8.25,8.6,8.95,9.3]:
		rod(Vector3(8.45,1.15,z),Vector3(8.42,2.72,z),.045,wood)
		box(Vector3(8.42,2.68,z),Vector3(.045,.3,.19),brass)
	box(Vector3(8.43,1.4,8.8),Vector3(.16,.1,1.55),wood)
	for x in [3.5,5.7,7.3]:
		box(Vector3(x,4.2,13.36),Vector3(.65,.35,.36),wood)
		box(Vector3(x,4.4,13.36),Vector3(.7,.06,.4),ink)
