extends SceneTree

const Records := preload("res://scripts/ui/vault_records.gd")
const Card := preload("res://scripts/ui/vault_drawn_card.gd")
var failures := 0
class VaultSource extends Node2D:
	var owner_player_id := 1
	var complete := true
	var health := 320

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 10: await process_frame
	if DisplayServer.get_name() != "headless": await create_timer(.35).timeout

func shot(filename: String) -> void:
	await settle()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(), "Screenshot is empty")
	var dir := OS.get_environment("ART_SHOT_DIR")
	if not dir.is_empty(): image.save_png(dir.path_join(filename+".png"))

func check_layout(archive: Node) -> void:
	for card in archive.grid.get_children():
		check(is_zero_approx(card.rotation), "Rotated card")
		check(card.position == card.position.round(), "Fractional card placement")
		check(card.size == Card.CARD_SIZE, "Card changed dimensions")
		check(card.position.x >= 0 and card.get_rect().end.x <= archive.grid.size.x, "Card clipped horizontally")
		check(card.get_rect().end.y <= archive.hand.size.y, "Row outside scroll extent")
		for other in archive.grid.get_children():
			if other != card: check(not card.get_rect().intersects(other.get_rect()), "Cards overlap")
		for label in card.get_children():
			if label is Label:
				check(Rect2(Vector2.ZERO,Card.CARD_SIZE).encloses(label.get_rect()), "Card text outside frame: "+label.text)
		var at: Vector2 = card.position
		card.lift(true)
		check(card.position == at and is_zero_approx(card.rotation), "Focus/hover shifted card")

func run() -> void:
	create_timer(100).timeout.connect(func(): quit(9))
	root.size = Vector2i(1440,900)
	root.content_scale_size = root.size
	var session := root.get_node("GameSession")
	session.start_new_game("straight-card-test","bad_kon_willow","build_sandbox")
	var build := BuildSystem.new()
	var world := RTSWorld.new()
	world.name = "RTSWorld"
	root.add_child(world)
	var source := VaultSource.new()
	root.add_child(source)
	var archive := preload("res://scripts/ui/observer_vault.gd").new()
	root.add_child(archive)
	check(archive.open_archive(source,build,world),"Vault did not open")
	for id in Card.STEEL_CELLS:
		check(Records.record_for(id,"Creations",build,world,session).is_empty(),"Unseen Steel unit leaked into Creations")
		check(Records.record_for(id,"Felled",build,world,session).is_empty(),"Unseen enemy leaked")
		session.record_felled(id,2,1)
		var sealed := Records.record_for(id,"Creations",build,world,session)
		check(sealed.sealed and not sealed.has("portrait") and not sealed.has("stats"),"Recruit leaked before Conscription")
		check(sealed.requirement.contains("Conscription"),"Wrong recruit unlock requirement")
		var recorded := Records.record_for(id,"Felled",build,world,session)
		check(not recorded.sealed,"Felled unit missing")
		var card := Card.new()
		card.setup(recorded)
		check(card.portrait == Card.STEEL_ART,"Steel used sprite fallback: "+str(id))
		check(card.portrait_region.size == Vector2(627,627),"Unexpected atlas cell size")
		card.free()
	archive.choose_tier(1)
	await shot("vault_v4_sealed_recruit")
	archive.choose_tier(2)
	check(archive.hand.has_node("TierFog"),"Unresearched tier has no fog")
	await shot("vault_v4_sealed_tier")
	build.researched_upgrade_ranks[&"steel_conscription"] = 4
	archive.choose_tier(2)
	check(not archive.hand.has_node("TierFog"),"Hybrid fog hides independently unlocked Steel")
	for id in Card.STEEL_CELLS:
		check(not Records.record_for(id,"Creations",build,world,session).sealed,"Conscription incorrectly needs hybrid research")
	await shot("vault_v4_independent_unlock")
	build.researched_upgrade_ranks[&"tier_two_hybrids"] = 1
	build.researched_upgrade_ranks[&"tier_three_hybrids"] = 1
	archive.choose_tier(2)
	await settle()
	check(archive.grid.get_child_count() == 4,"Tier II needs two Kon families and two Steel units")
	check_layout(archive)
	await shot("vault_v4_tier2")
	archive.choose_tier(1)
	await shot("vault_v4_tier1")
	archive.choose_tier(3)
	await shot("vault_v4_tier3")
	archive.section = "Felled"
	archive.choose_tier(2)
	await shot("vault_v4_steel_records")
	archive.grid.get_child(0).pressed.emit()
	await shot("vault_v4_knight_detail")
	archive.section = "Creations"
	archive.choose_tier(2)
	archive.content.find_child("Specimen_mangler",true,false).pressed.emit()
	check(archive.content.find_child("Form_winged_mangler",true,false) != null,"Evolution lost from detail")
	archive.content.find_child("Form_winged_mangler",true,false).pressed.emit()
	check(archive.selected_id == &"winged_mangler","Evolution button failed")
	archive.choose_tier(3)
	check(archive.grid.get_child_count() == 2,"Spawner evolution/drone became separate gallery cards")
	archive.content.find_child("Specimen_spawner",true,false).pressed.emit()
	check(archive.content.find_child("Form_spawner_drone",true,false) != null,"Summon missing from family")
	# The selected specimen's frame must agree with the detail measurements.
	var unit := RTSUnit.new()
	unit.unit_archetype = &"poorper"
	unit.owner_player_id = 1
	root.add_child(unit)
	unit.attack_damage = 77
	archive.selected_id = &"poorper"
	archive.specimen_index = 0
	archive.refresh()
	var detail_card: Node = archive.content.find_child("Specimen_poorper",true,false)
	check(detail_card.record.stats.attack_damage == 77,"Detail card does not show selected live buff")
	check(detail_card.record.stat_labels.is_empty(),"Template/living range leaked into selected stats")
	unit.attack_damage = 3
	archive.refresh()
	detail_card = archive.content.find_child("Specimen_poorper",true,false)
	check(detail_card.record.stats.attack_damage == 3,"Detail card does not show nerf")
	for viewport in [Vector2i(1024,720),Vector2i(640,800)]:
		root.size = viewport
		root.content_scale_size = viewport
		archive.choose_tier(2)
		await settle()
		check_layout(archive)
		await shot("vault_v4_"+str(viewport.x))
		var old_tier: int = archive.current_tier
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = archive.hand.global_position+Vector2(100,100)
		root.push_input(wheel)
		await settle()
		check(archive.current_tier == old_tier,"Scrolling rows unexpectedly changed tier")
		archive.scroll.scroll_vertical = int(archive.hand.size.y)
		await shot("vault_v4_"+str(viewport.x)+"_lower")
	archive.close_archive()
	check(not root.has_meta("observer_archive_open"),"Vault left camera input locked")
	archive.queue_free()
	unit.queue_free()
	world.queue_free()
	source.queue_free()
	build.free()
	await process_frame
	print("[StraightVaultCards] failures=",failures)
	quit(0 if failures == 0 else 1)
