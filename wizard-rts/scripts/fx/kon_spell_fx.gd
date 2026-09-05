extends Node2D

var action: StringName = &"seal_away"
var radius := 150.0
var duration := 5.0
var damage_source: WeakRef
var world: Node
var preview := false
var valid_target := true
var floor_level := -1
var _age := 0.0
var _tick := 0.0
var _spatial: Node3D
var _view: Node
var _rings: Array[MeshInstance3D] = []
var _motes: Array[MeshInstance3D] = []
var _painted: Sprite2D
var _painted_3d: Sprite3D

func _ready() -> void:
	z_index=100
	_view=get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(_view):
		_make_3d()
		visible=false
	if not preview:
		_painted=Sprite2D.new()
		_painted.texture=load("res://assets_game/units/kon/hero/painted_v2/spells.png")
		_painted.hframes=2
		_painted.vframes=2
		_painted.frame={&"seal_away":0,&"biostorm":1,&"observation":2,&"staff":3}.get(action,0)
		_painted.scale=Vector2.ONE*radius*2.0/(float(_painted.texture.get_width())/2.0)
		_painted.position.y=-radius*0.5
		add_child(_painted)
		if is_instance_valid(_spatial):
			_painted_3d=Sprite3D.new()
			_painted_3d.texture=_painted.texture
			_painted_3d.hframes=2
			_painted_3d.vframes=2
			_painted_3d.frame=_painted.frame
			_painted_3d.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			_painted_3d.pixel_size=_painted.scale.x/64.0
			_painted_3d.position.y=radius/64.0
			_painted_3d.no_depth_test=false
			_spatial.add_child(_painted_3d)

func _process(delta: float) -> void:
	var step := minf(delta,maxf(0.0,duration-_age))
	_age+=delta
	if action==&"biostorm" and not preview:
		_tick+=step
		while _tick>=0.5:
			_tick-=0.5
			_damage_tick()
	if is_instance_valid(_spatial): _update_3d()
	if is_instance_valid(_painted):
		var fade := minf(1.0,_age*5.0)*clampf((duration-_age)*3.0,0.0,1.0)
		_painted.modulate.a=fade*(0.78+sin(_age*5.0)*0.12)
		_painted.rotation=sin(_age*2.0)*0.025
		if is_instance_valid(_painted_3d):
			_painted_3d.modulate.a=_painted.modulate.a
	queue_redraw()
	if _age>=duration: queue_free()

func _exit_tree() -> void:
	if is_instance_valid(_spatial): _spatial.queue_free()

func _damage_tick() -> void:
	var source: Node=damage_source.get_ref() if damage_source!=null else null
	var candidates: Array=world.all_units() if is_instance_valid(world) else get_tree().get_nodes_in_group("units")
	for victim in candidates:
		if not is_instance_valid(victim) or not victim.has_method("is_banished") or not victim.is_alive() or victim.is_banished(): continue
		if victim.global_position.distance_squared_to(global_position)<=radius*radius:
			victim.take_damage(12,source,&"magic")

func _color() -> Color:
	if preview and not valid_target: return Color("f16169")
	return Color("be445d") if action==&"biostorm" else Color("74f1eb")

func _draw() -> void:
	var c := _color()
	var fade := 1.0 if preview else minf(1.0,(duration-_age)*3.0)
	if fade<=0: return
	draw_circle(Vector2.ZERO,radius,Color(c,0.035*fade))
	for ring in 3:
		var r := radius*(0.82+float(ring)*0.09)
		draw_arc(Vector2.ZERO,r,_age*0.15+ring,_age*0.15+ring+TAU*0.92,80,Color(c,(0.25+ring*0.15)*fade),1.6,true)
	for i in 24:
		var a := float(i)*TAU/24.0+_age*0.10
		var p := Vector2.from_angle(a)*radius
		draw_line(p*0.94,p*1.03,Color(c,0.7*fade),2,true)
	if preview: return
	for i in 32:
		var t := fmod(_age*(0.35 if action==&"biostorm" else 0.16)+float(i)*0.618,1.0)
		var a := float(i)*2.4+_age*(1.3 if action==&"biostorm" else 0.2)
		var p := Vector2.from_angle(a)*radius*(0.2+0.7*float(i%7)/7.0)
		p.y-=t*100.0
		draw_line(p,p+Vector2(-7,14) if action==&"biostorm" else p+Vector2(0,4),Color(c,sin(t*PI)*fade),2,true)
		if action==&"biostorm" and i%4==0:
			draw_polyline(PackedVector2Array([p+Vector2(12,-70),p+Vector2(-5,-35),p+Vector2(8,-30),p]),Color("8cf4e3"),1.5,true)

func _make_3d() -> void:
	_spatial=Node3D.new()
	_view.add_child(_spatial)
	var mat := StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=_color()
	mat.emission_enabled=true
	mat.emission=_color()
	mat.emission_energy_multiplier=2.0
	for i in 3:
		var mesh := TorusMesh.new()
		mesh.inner_radius=radius/64.0*(0.82+i*0.09)-0.015
		mesh.outer_radius=mesh.inner_radius+0.03
		mesh.rings=64
		mesh.ring_segments=6
		var ring := MeshInstance3D.new()
		ring.mesh=mesh
		ring.material_override=mat
		_spatial.add_child(ring)
		_rings.append(ring)
	if preview: return
	for i in 32:
		var mesh := SphereMesh.new()
		mesh.radius=0.025 if i%3 else 0.04
		mesh.height=mesh.radius*3.0
		mesh.radial_segments=6
		mesh.rings=3
		var mote := MeshInstance3D.new()
		mote.mesh=mesh
		mote.material_override=mat
		_spatial.add_child(mote)
		_motes.append(mote)

func _update_3d() -> void:
	var renderer: Node=_view.get("_renderer")
	if renderer==null: return
	var elevation := 0.08
	var map: Node=_view.get("map_generator")
	if map!=null:
		elevation+=float(renderer.surface_height_at_cell(map.world_to_cell(global_position)))
	if floor_level>=0: elevation=float(floor_level)*float(_view.BLOCK_LEVEL_HEIGHT)+0.08
	_spatial.position=renderer.sim_to_world_3d(global_position,elevation)
	var fog: Node=_view.get("fog_of_war")
	_spatial.visible=fog==null or fog.is_world_position_visible(global_position)
	for ring in _rings:
		ring.material_override.albedo_color=_color()
		ring.material_override.emission=_color()
	for i in _motes.size():
		var t := fmod(_age*0.45+float(i)*0.618,1.0)
		var a := i*2.4+_age*(1.3 if action==&"biostorm" else 0.2)
		var r := radius/64.0*(0.2+0.7*float(i%7)/7.0)
		_motes[i].position=Vector3(cos(a)*r,t*2.6,sin(a)*r)
		_motes[i].scale=Vector3.ONE*maxf(0.01,sin(t*PI))
