extends "res://scripts/core/map_3d_mode_smoke_test.gd"

func _check_3d_mode() -> bool:
	if not await super(): return false
	var stage: Node
	for child in root.get_children():
		if child.get_node_or_null("Map3DView")!=null: stage=child
	if stage==null: return false
	var view: Node=stage.get_node("Map3DView")
	var kon: Node2D=load("res://scenes/wizard.tscn").instantiate()
	stage.add_child(kon)
	kon.global_position=_walkable(stage.get_node("MapGenerator"),Vector2i(30,30))
	kon.set_physics_process(false)
	var art: Sprite2D=kon.get_node("ArtSprite")
	art.set_process(false)
	art.flip_h=true
	art.frame=52
	view._sync_unit_sprites([kon] as Array[Node2D])
	var sprite_root: Node=view.get_node("UnitSprites3D")
	var sprite: Sprite3D
	for child in sprite_root.get_children():
		if child is Sprite3D and child.visible and child.texture==art.texture: sprite=child
	if sprite==null or sprite.frame!=52 or not sprite.flip_h or sprite.vframes!=8:
		_fail("Kon billboard frame/facing/atlas mismatch")
		return false
	kon.set_meta("kon_banished",true)
	if view._is_revealed(kon):
		_fail("Banished hero visible in 3D")
		return false
	kon.remove_meta("kon_banished")
	var fx: Node2D=kon.kon_abilities.spawn_fx(&"biostorm",kon.position+Vector2(160,0),200.0,4.0)
	await process_frame
	if not is_instance_valid(fx._spatial) or fx._painted_3d==null:
		_fail("Spell missing 3D painted effect")
		return false
	view.focus_on_sim_position(kon.position)
	view.set_camera_distance(12.0)
	view.camera.make_current()
	view.fog_of_war.set_reveal_all(true)
	await create_timer(2.0).timeout
	if not OS.get_environment("ART_SHOT_DIR").is_empty() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR")+"/kon_ingame.png")
	print("[Kon3D] PASS: live map, painted atlas, facing, banish concealment, spatial spell effects")
	await _teardown(stage)
	await create_timer(0.3).timeout
	return true
