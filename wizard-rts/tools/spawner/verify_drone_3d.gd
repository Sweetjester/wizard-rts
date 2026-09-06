extends "res://scripts/core/map_3d_mode_smoke_test.gd"

func _check_3d_mode() -> bool:
	if not await super(): return false
	var stage: Node
	for child in root.get_children():
		if child.get_node_or_null("Map3DView") != null: stage = child
	if stage == null:
		_fail("Missing 3D map")
		return false
	var view: Node = stage.get_node("Map3DView")
	var drone: Node2D = load("res://scenes/units/spawner_drone.tscn").instantiate()
	stage.add_child(drone)
	drone.global_position = _walkable(stage.get_node("MapGenerator"),Vector2i(30,30))
	drone.set_physics_process(false)
	var art: Sprite2D = drone.get_node("ArtSprite")
	art.set_process(false)
	art.flip_h = true
	art.frame = 17
	view.call("_sync_unit_sprites",[drone] as Array[Node2D])
	var sprite_root: Node = view.get_node("UnitSprites3D")
	var sprite: Sprite3D
	for child in sprite_root.get_children():
		if child is Sprite3D and child.visible and child.texture == art.texture: sprite = child
	if sprite == null or sprite.frame != 17 or not sprite.flip_h or sprite.vframes != 5:
		_fail("Drone billboard must mirror painted animation, not use static fallback")
		return false
	art.frame = 22
	view.call("_sync_unit_sprites",[drone] as Array[Node2D])
	if sprite.frame != 22:
		_fail("Drone wingbeat did not update in 3D")
		return false
	var texture := art.texture
	drone.call("_die")
	await process_frame
	var corpse: Sprite3D
	for child in sprite_root.get_children():
		if child is Sprite3D and str(child.name).begins_with("PaintedUnitCorpse") and child.texture == texture: corpse = child
	if is_instance_valid(drone) or corpse == null or corpse.frame < 48:
		_fail("Missing independent drone death in 3D")
		return false
	await create_timer(2).timeout
	if is_instance_valid(corpse):
		_fail("3D drone corpse failed to clean up")
		return false
	print("[Drone3D] PASS: animated billboard, facing, death and cleanup")
	return true
