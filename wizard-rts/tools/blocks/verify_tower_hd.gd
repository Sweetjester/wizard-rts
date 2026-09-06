extends SceneTree

const ID := &"kons_observation_wizard_tower_01"
const HD = preload("res://scripts/blocks/observation_tower_remaster.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("[TowerHD] ",label," ",ok)
	if not ok:
		failures+=1
		push_error(label)

func run() -> void:
	var library := BlockStructureLibrary.load_default()
	var definition := library.get_definition(ID)
	check(definition.dimensions==Vector3i(18,32,18),"Original dimensions")
	var before := var_to_bytes([definition.solid_cells,definition.nav_cells,definition.links,definition.gate_cells,definition.open_cells,definition.sockets,definition.block_boxes])
	for test in library.validation_tests_for(ID):
		var nav := library.navigation_for(ID)
		nav.gate_states=test.get("state",{})
		var a: Array=test.start
		var b: Array=test.destination
		check(nav.can_reach(Vector3i(a[0],a[1],a[2]),Vector3i(b[0],b[1],b[2]),StringName(test.unit_class))==(test.expected=="PASS"),test.id)
	var nav := library.navigation_for(ID)
	nav.gate_states={"main_gate_open":true}
	for unit_class: StringName in [&"infantry",&"archer",&"climber",&"flying"]:
		for region: StringName in [&"west_balcony",&"east_balcony",&"north_balcony",&"observatory"]:
			check(nav.can_reach_region(Vector3i(8,0,0),region,unit_class),str(unit_class)+" reaches "+str(region))
	var detail_checker := HD.new()
	var unused := detail_checker.build(definition)
	unused.free()
	var previous_digest := ""
	for rotation in 4:
		var builder := BlockStructureBuilder.new()
		root.add_child(builder)
		builder.build(definition.rotated(rotation))
		await process_frame
		var gothic := builder.get_node("GothicDetails")
		check(gothic.get_meta("skin_id")=="observation_tower_hd_v3","HD active rotation "+str(rotation))
		check(gothic.transform.is_equal_approx(builder._tower_art_transform()),"Dressing follows placement rotation")
		var detail_root := gothic.get_node("RemasteredArchitecture")
		var transforms: Array=[]
		var pieces := 0
		var clear := true
		for node in detail_root.get_children():
			if node is MultiMeshInstance3D:
				for i in node.multimesh.instance_count:
					var t: Transform3D=node.multimesh.get_instance_transform(i)
					transforms.append(t)
					var bounds := t*AABB(Vector3.ONE*-.5,Vector3.ONE)
					clear=clear and detail_checker.clear_box(bounds.get_center(),bounds.size)
					pieces+=1
		check(clear,"New sculpted pieces avoid reserved clearance")
		check(pieces>250,"Substantial batched detail: "+str(pieces))
		var digest := var_to_bytes(transforms).hex_encode().sha256_text()
		if rotation>0: check(digest==previous_digest,"Deterministic canonical architecture")
		previous_digest=digest
		var lights := 0
		for node in gothic.get_children():
			if node is OmniLight3D:
				lights+=1
				check(not node.shadow_enabled and node.distance_fade_enabled,"Bounded unshadowed local light")
		check(lights<=6,"Six-light maximum")
		for opened in [false,true,false]:
			builder.set_gate_open(&"main_gate_open",opened)
			check(builder.get_node("Gate_main_gate_open").visible!=opened,"Gate artwork follows gate state")
		builder.set_blocks_visible(false)
		check(not gothic.visible,"All added dressing hides with tower")
		builder.set_blocks_visible(true)
		var settings := root.get_node("DisplayManager")
		var old: bool=settings.performance_mode
		settings.performance_mode=true
		settings.settings_changed.emit()
		var disabled := true
		for node in gothic.get_children():
			if node is OmniLight3D: disabled=disabled and not node.visible
		check(disabled,"Performance mode removes tower lights")
		settings.performance_mode=old
		settings.settings_changed.emit()
		builder.free()
	check(before==var_to_bytes([definition.solid_cells,definition.nav_cells,definition.links,definition.gate_cells,definition.open_cells,definition.sockets,definition.block_boxes]),"Authored data byte-identical after all builds")
	for label in ["masonry","surfaces","details"]:
		var texture: Texture2D=load(HD.PATH+label+".png")
		check(texture.get_width()>=1200 and texture.get_height()>=1200,"Native image resolution: "+label)
		check(texture.get_image().has_mipmaps(),"Mipmaps: "+label)
	print("[TowerHD] failures=",failures)
	quit(0 if failures==0 else 1)
