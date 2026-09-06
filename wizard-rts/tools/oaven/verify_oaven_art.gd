extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for form in ["oaven","jumper"]:
		var atlas:=Image.load_from_file("res://assets_game/units/kon/oaven/painted_v3/"+form+".png")
		assert(atlas.get_size()==Vector2i(4608,5760))
		for row in 15:
			for column in 12:
				var tile:=atlas.get_region(Rect2i(column*384,row*384,384,384))
				var bounds:=tile.get_used_rect()
				assert(bounds.has_area(),"Empty frame: %s %s %s" % [form,row,column])
				assert(bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<384 and bounds.end.y<384,"Clipped frame: %s %s %s %s" % [form,row,column,bounds])
		if form=="oaven":
			var preview:=Image.create(1536,768,false,Image.FORMAT_RGBA8)
			preview.fill(Color("121c22"))
			for i in 8:
				var row: int=[0,1,2,3,4,5,6,8][i]
				preview.blend_rect(atlas,Rect2i(5*384,row*384,384,384),Vector2i((i%4)*384,(i/4)*384))
			preview.save_png("res://assets_game/units/kon/oaven/painted_v3/preview.png")
	var unit: Node2D=load("res://scenes/units/oaven_spear.tscn").instantiate()
	root.add_child(unit)
	unit.set_physics_process(false)
	var art: Sprite2D=unit.get_node("ArtSprite")
	art.set_process(false)
	art._process(0.016)
	assert(art.current_action==&"idle","Initial health setup must not trigger hit")
	unit.set("moving",true)
	unit.set("velocity",Vector2(-10,0))
	art._process(0.1)
	assert(art.current_action==&"move" and art.flip_h)
	unit.set("weapon_mode",&"blowpipe")
	unit.set("unit_state",&"attacking")
	art._process(0.1)
	assert(art.current_action==&"attack_blowpipe")
	unit.set("unit_archetype",&"oaven_jumper")
	art._process(0.1)
	assert(art.texture.resource_path.ends_with("jumper.png"))
	unit.set("health",int(unit.get("health"))-1)
	art._process(0.01)
	assert(art.current_action==&"hit")
	unit.call("_die")
	var corpse: Sprite2D=null
	for child in root.get_children():
		if child is Sprite2D and child.get_script()==load("res://scripts/fx/oaven_death_sprite.gd"):
			corpse=child
	await process_frame
	assert(not is_instance_valid(unit),"Dead unit must leave the simulation")
	assert(is_instance_valid(corpse) and corpse.frame>=60)
	await create_timer(1.1).timeout
	assert(corpse.frame==71 and not corpse.is_in_group("units"))
	await create_timer(2.0).timeout
	assert(not is_instance_valid(corpse))
	print("[OavenArt] PASS: 360 nonempty/unclipped frames, modes, facing, evolution, hit and independent death playback")
	quit()
