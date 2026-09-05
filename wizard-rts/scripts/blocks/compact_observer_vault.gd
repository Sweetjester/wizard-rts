extends "res://scripts/blocks/compact_splicing_lab.gd"

var books: StandardMaterial3D
var door_paint: StandardMaterial3D
var seal_paint: StandardMaterial3D
var slate: StandardMaterial3D
var parchment: StandardMaterial3D

func build() -> Node3D:
	books = _atlas_material(Vector2(0,0))
	door_paint = _atlas_material(Vector2(0.5,0))
	seal_paint = _atlas_material(Vector2(0,0.5))
	slate = _atlas_material(Vector2(0.5,0.5))
	seal_paint.emission_enabled = true
	seal_paint.emission_texture = seal_paint.albedo_texture
	seal_paint.emission = Color("25a9b7")
	seal_paint.emission_energy_multiplier = 0.7
	parchment = material(Color("b7bdab"))
	return super()

func _atlas_material(uv: Vector2) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/structures/observer_vault/library_atlas.png")
	mat.uv1_scale = Vector3(0.496,0.496,1)
	mat.uv1_offset = Vector3(uv.x+0.002,uv.y+0.002,0)
	mat.roughness = 0.92
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _walls() -> void:
	wall(Vector3(0.3,1,1.3),Vector3(0.3,1,6.7),3.4,0.5)
	wall(Vector3(8.7,1,1.3),Vector3(8.7,1,4),3.4,0.5)
	wall(Vector3(8.7,1,5),Vector3(8.7,1,6.7),3.4,0.5)
	wall(Vector3(0.3,1,6.7),Vector3(8.7,1,6.7),3.65,0.5)
	wall(Vector3(0.3,1,1.45),Vector3(2.5,1,1.45),3.4,0.6)
	wall(Vector3(5.5,1,1.45),Vector3(8.7,1,1.45),3.4,0.6)
	for x in [0.5,2.4,5.65,8.5]:
		box(Vector3(x,2.65,1.03),Vector3(0.25,3.25,0.42),stone)
		box(Vector3(x,4.27,1.03),Vector3(0.45,0.17,0.55),stone)
		box(Vector3(x,1.2,1.03),Vector3(0.42,0.25,0.52),iron)
	for x in [1.35,7.45]: _window(Vector3(x,2.75,1.08),0.65,1.65)
	for z in [2.3,5.6]:
		box(Vector3(8.89,2.7,z),Vector3(0.12,1.5,0.55),glass)
		for dz in [-0.3,0,0.3]: rod(Vector3(8.97,1.95,z+dz),Vector3(8.97,3.45,z+dz),0.022,iron)
	box(Vector3(4.5,4.59,6.5),Vector3(8.6,0.2,0.65),stone)

func _portal() -> void:
	var center := Vector3(4,2.65,0.97)
	for i in 28:
		var a := -0.18+float(i)* (PI+0.36)/28.0
		var b := -0.18+float(i+1)*(PI+0.36)/28.0
		rod(center+Vector3(cos(a)*1.75,sin(a)*1.75,0),center+Vector3(cos(b)*1.75,sin(b)*1.75,0),0.20,stone)
		rod(center+Vector3(cos(a)*1.51,sin(a)*1.51,-0.05),center+Vector3(cos(b)*1.51,sin(b)*1.51,-0.05),0.04,iron)
	for x in [2.27,5.73]: box(Vector3(x,1.82,1.0),Vector3(0.32,1.65,0.48),stone)
	# The medallion is integrated in the facade, below the 5-block roof limit.
	_disk("ObserverSeal",Vector3(4,4.45,0.69),0.38,seal_paint,root)
	_ring(Vector3(4,4.45,0.70),0.40,0.045,iron)
	_light(Vector3(4,4.45,0.45),2.6,1.0)
	var hinge := preload("res://scripts/blocks/vault_door.gd").new()
	hinge.name = "VaultGate"
	hinge.position = Vector3(5.68,2.65,1.36)
	root.add_child(hinge)
	var leaf := MeshInstance3D.new()
	leaf.name = "IronLeaf"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.6
	cylinder.bottom_radius = 1.6
	cylinder.height = 0.26
	cylinder.radial_segments = 48
	leaf.mesh = cylinder
	leaf.material_override = iron
	leaf.position.x = -1.68
	leaf.rotation.x = PI*0.5
	hinge.add_child(leaf)
	_disk("PaintedLockFace",Vector3(-1.68,0,-0.137),1.6,door_paint,hinge)
	_disk("InsideLockFace",Vector3(-1.68,0,0.137),1.6,door_paint,hinge)
	_gate("ServiceGate",Vector3(8.66,2,4.5),Vector3(0.13,1.95,0.92))
	for x in [2.05,6.05]:
		box(Vector3(x,2.8,0.6),Vector3(0.2,0.37,0.2),glass)
		box(Vector3(x,3.01,0.6),Vector3(0.3,0.08,0.3),iron)
		rod(Vector3(x,3.05,0.6),Vector3(x,3.35,1.12),0.03,iron)
		_light(Vector3(x,2.65,0.45),2.7,0.75)

func _disk(label: String, at: Vector3, radius: float, mat: Material, parent: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		for t in [-1,i,i+1]:
			var p := Vector2.ZERO if t<0 else Vector2.from_angle(float(t)*TAU/64)
			surface.set_uv(Vector2(p.x*0.5+0.5,0.5-p.y*0.5))
			surface.set_normal(Vector3.FORWARD)
			surface.add_vertex(Vector3(p.x*radius,p.y*radius,0))
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = surface.commit()
	node.material_override = mat
	node.position = at
	parent.add_child(node)

func _ring(at: Vector3, radius: float, thick: float, mat: Material) -> void:
	for i in 32:
		var a := i*TAU/32.0
		var b := (i+1)*TAU/32.0
		rod(at+Vector3(cos(a)*radius,sin(a)*radius,0),at+Vector3(cos(b)*radius,sin(b)*radius,0),thick,mat)

func _roof() -> void:
	# Raised slate shoulders frame an open nave; no roof hides the unit routes.
	for x in [0.55,8.45]:
		box(Vector3(x,4.42,3.9),Vector3(1.0,0.18,5.8),slate)
		for z in [1.35,3.75,6.45]:
			rod(Vector3(x-0.43,4.54,z),Vector3(x,4.84,z),0.045,iron)
			rod(Vector3(x,4.84,z),Vector3(x+0.43,4.54,z),0.045,iron)
	for z in [2.2,4.3,6.35]:
		for side in [-1,1]:
			rod(Vector3(4.5+side*2.4,4.5,z),Vector3(4.5,4.85,z),0.06,iron)
	rod(Vector3(4.5,4.85,2.2),Vector3(4.5,4.85,6.35),0.05,iron)

func _shelf(at: Vector3, width: float, height: float) -> void:
	box(at+Vector3(0,0,0.15),Vector3(width,height,0.3),wood)
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width-0.08,height-0.08)
	node.mesh = quad
	node.material_override = books
	node.position = at-Vector3(0,0,0.018)
	root.add_child(node)
	for side in [-1,1]: box(at+Vector3(side*width*0.5,0,-0.035),Vector3(0.07,height,0.13),wood)
	for row in 5: box(at+Vector3(0,-height*0.5+row*height/4,-0.045),Vector3(width+0.04,0.065,0.14),wood)

func _interior() -> void:
	for x in [1.7,3.55,5.4,7.25]: _shelf(Vector3(x,2.36,6.34),1.63,2.65)
	for x in [2.25,4.15,6.05]: _shelf(Vector3(x,4.43,6.30),1.72,0.83)
	for x in 14: box(Vector3(1.25+x*0.5,3.93,5.5),Vector3(0.48,0.14,0.97),wood)
	for i in 18:
		var t := float(i+1)/18
		box(Vector3(1.5,1+3*t-0.06,2.5+3*t),Vector3(0.83,0.12,0.21),wood)
	for side in [-0.44,0.44]: rod(Vector3(1.5+side,1.65,2.5),Vector3(1.5+side,4.65,5.5),0.035,iron)
	for x in [2.2,3.2,4.2,5.2,6.2,7.5]: rod(Vector3(x,4,5.0),Vector3(x,4.63,5.0),0.025,iron)
	rod(Vector3(2.2,4.63,5.0),Vector3(7.5,4.63,5.0),0.03,iron)
	# Desks and loose books occupy the reserved east bay, never the main aisle.
	box(Vector3(6.5,1.70,3.5),Vector3(0.72,0.15,1.15),wood)
	for z in [3.05,3.95]: box(Vector3(6.5,1.35,z),Vector3(0.55,0.7,0.1),iron)
	for i in 7:
		box(Vector3(6.5,1.83+i*0.06,3.2),Vector3(0.35,0.045,0.23),red if i%3 else parchment,rng.randf_range(-0.2,0.2))
	box(Vector3(6.5,1.81,3.7),Vector3(0.52,0.035,0.32),parchment,0.1)
	for x in [0.72,8.25]:
		for i in 9: box(Vector3(x,1.04+i*0.055,1.85),Vector3(0.43,0.04,0.33),red if i%3 else parchment,rng.randf_range(-0.2,0.2))
	_light(Vector3(4,3.5,5.85),4.0,1.1)
	_light(Vector3(6.4,2.5,3.5),2.2,0.55)
