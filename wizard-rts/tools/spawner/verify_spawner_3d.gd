extends "res://scripts/core/map_3d_mode_smoke_test.gd"

func _check_3d_mode() -> bool:
	if not await super(): return false
	var stage: Node=null
	for child in root.get_children():
		if child.get_node_or_null("Map3DView")!=null: stage=child
	if stage==null:
		_fail("Missing live 3D stage")
		return false
	var view: Node=stage.get_node("Map3DView")
	var unit: Node2D=load("res://scenes/units/spawner.tscn").instantiate()
	unit.set("owner_player_id",1)
	stage.add_child(unit)
	unit.global_position=_walkable(stage.get_node("MapGenerator"),Vector2i(30,30))
	unit.set_physics_process(false)
	var art: Sprite2D=unit.get_node("ArtSprite")
	art.set_process(false)
	art.flip_h=true
	art.frame=48
	view.call("_sync_unit_sprites",[unit] as Array[Node2D])
	var sprite_root: Node=view.get_node("UnitSprites3D")
	var sprite: Sprite3D=null
	for child in sprite_root.get_children():
		if child is Sprite3D and child.visible and child.texture==art.texture: sprite=child
	if sprite==null or sprite.frame!=48 or not sprite.flip_h or sprite.vframes!=16:
		_fail("Spawner billboard does not mirror its animated artwork")
		return false
	var expected: Transform3D=view.call("_unit_transform",unit,(310.0-192.0)*0.009)
	if not sprite.global_position.is_equal_approx(expected.origin):
		_fail("Spawner billboard foot alignment")
		return false
	unit.call("_die")
	await process_frame
	var corpse: Sprite3D=null
	for child in sprite_root.get_children():
		if child is Sprite3D and str(child.name).begins_with("PaintedUnitCorpse") and child.texture==sprite.texture: corpse=child
	if is_instance_valid(unit) or corpse==null or corpse.frame<108 or not corpse.flip_h:
		_fail("Spawner must leave the simulation while its 3D death animation remains")
		return false
	await create_timer(1.5).timeout
	if not is_instance_valid(corpse) or corpse.frame!=119:
		_fail("Spawner 3D corpse must finish the correct death row")
		return false
	await create_timer(2.8).timeout
	if is_instance_valid(corpse):
		_fail("Spawner 3D corpse did not clean up")
		return false
	print("[Spawner3D] PASS: sheet, facing, frame, feet, removal, death row and cleanup")
	return true
