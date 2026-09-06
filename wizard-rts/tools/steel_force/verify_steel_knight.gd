extends SceneTree
const Art := preload("res://scripts/units/steel_knight_directional_art.gd")
const Facing := preload("res://scripts/units/eight_direction_facing.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("[Knight] " + label)

func run() -> void:
	var hashes: Array = []
	for direction in Art.DIRECTIONS:
		var image := Image.load_from_file(Art.ROOT + "steel_knight_" + direction + ".png")
		check(image != null and image.get_size() == Vector2i(2048, 1280), direction + " dimensions")
		for row in 5:
			var frame_hashes: Array = []
			for f in 8:
				var img := image.get_region(Rect2i(f * 256, row * 256, 256, 256))
				var box := img.get_used_rect()
				check(box.size.x > 30 and box.size.y > 25, direction + " nonblank pose")
				check(box.position.x > 1 and box.position.y > 1 and box.end.x < 255 and box.end.y < 255, direction + " unclipped pose")
				var magenta := 0
				for y in range(0, 256, 2):
					for x in range(0, 256, 2):
						var c := img.get_pixel(x, y)
						if c.a > .5 and minf(c.r, c.b) - c.g > .3: magenta += 1
				check(magenta == 0, direction + " clean key")
				var digest := img.get_data().hex_encode().sha256_text()
				if not frame_hashes.has(digest): frame_hashes.append(digest)
				if row == 0 and f == 0:
					check(not hashes.has(digest), "Independently painted " + direction)
					hashes.append(digest)
			check(frame_hashes.size() > 2, direction + " animated row " + str(row))
		print("[Knight] asset PASS ", direction)
	var unit: RTSUnit = load("res://scenes/units/steel_knight.tscn").instantiate()
	root.add_child(unit)
	unit.set_process(false)
	unit.set_physics_process(false)
	var art: Sprite2D = unit.get_node("ArtSprite")
	art.set_process(false)
	check(unit.unit_archetype == &"steel_knight" and unit.move_speed == 90, "Original gameplay identity")
	for i in 8:
		unit.velocity = Vector2.from_angle(i * PI / 4) * 100
		art.frame = 11
		art.sync_view_facing()
		check(art.facing_index == i and not art.flip_h and art.frame == 11, "Direction without frame reset " + str(i))
		unit.velocity = Vector2.ZERO
		art.sync_view_facing()
		check(art.facing_index == i, "Stopped direction persists")
		var basis := Basis(Vector3.UP, i * PI / 4) * Basis(Vector3.RIGHT, -PI / 4)
		check(Facing.sector(Facing.camera_relative(Vector2.RIGHT, basis), i) == i, "Camera yaw " + str(i))
	check(Facing.sector(Vector2.from_angle(deg_to_rad(24)), 0) == 0, "Facing hysteresis holds boundary")
	check(Facing.sector(Vector2.from_angle(deg_to_rad(28)), 0) == 1, "Facing crosses boundary")
	unit.moving = true
	unit.attack_visual_age = 10
	art._process(.1)
	check(art.frame / 8 == 1, "Walk action")
	unit.attack_visual_age = 0
	art._process(0)
	check(art.frame == 16, "Attack begins at contact")
	unit.health -= 1
	art._process(.01)
	check(art.frame / 8 == 3, "Hit action")
	unit.velocity = Vector2.UP
	art.sync_view_facing()
	var page := art.texture
	unit._spawn_death_fx()
	var corpses := root.get_children().filter(func(n: Node) -> bool: return n is Sprite2D)
	check(corpses.size() == 1, "2D corpse exists")
	if corpses.size() == 1:
		check(corpses[0].texture == page and corpses[0].frame == 32 and corpses[0].offset == Vector2(0, -92), "2D corpse facing/frame/anchor")
		corpses[0].queue_free()
	unit.queue_free()
	await process_frame
	print("[Knight] failures=", failures)
	quit(0 if failures == 0 else 1)
