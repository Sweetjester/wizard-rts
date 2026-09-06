extends SceneTree
const Records := preload("res://scripts/ui/vault_records.gd")
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

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(9))
	root.size = Vector2i(1440, 1000)
	root.content_scale_size = root.size
	var session := root.get_node("GameSession")
	session.start_new_game("vault-ui-test", "bad_kon_willow", "build_sandbox")
	var build := BuildSystem.new()
	var world := RTSWorld.new()
	world.name = "RTSWorld"
	root.add_child(world)
	var source := VaultSource.new()
	root.add_child(source)
	var sealed := Records.record_for(&"spawner", "Creations", build, world, session)
	check(sealed.sealed and sealed.name == "Sealed specimen", "Tier 3 must withhold the name")
	check(not sealed.has("portrait") and not sealed.has("stats"), "Sealed record leaks data")
	check(sealed.requirement.contains("Tier 3"), "Missing unlock condition")
	check(Records.entries("Felled", build, world, session).is_empty(), "Enemies leaked before kills")
	session.record_felled(&"oaven_jumper", 1, 1)
	session.record_felled(&"oaven_jumper", 2, 2)
	session.record_felled(&"oaven_jumper", 2, -1)
	check(session.felled_specimens.is_empty(), "Friendly/environment/other enemy death must not reveal")
	var killer := RTSUnit.new()
	killer.unit_archetype = &"oaven_spear"
	killer.owner_player_id = 1
	root.add_child(killer)
	var victim := RTSUnit.new()
	victim.unit_archetype = &"oaven_jumper"
	victim.owner_player_id = 2
	root.add_child(victim)
	victim.take_damage(99999, killer)
	await process_frame
	check(session.felled_specimens.has(&"oaven_jumper"), "Real combat death did not reveal")
	check(Records.entries("Felled", build, world, session).size() == 1, "First kill should add exactly one card")
	session.record_felled(&"oaven_jumper", 2, 1)
	check(Records.entries("Felled", build, world, session).size() == 1, "Repeated kill duplicates cards")
	build.researched_upgrade_ranks = {&"hardened_horrors":2}
	var altered := Records.record_for(&"horror", "Felled", build, world, session)
	check(altered.is_empty(), "Unkilled enemy queried directly must still be hidden")
	var ledger := RosterLedger.entry_for(&"horror", build, world)
	check(ledger.live.max_health == ledger.base.max_health+40, "Research not reflected")
	killer.attack_damage = 73
	check(Records.specimen_stats(weakref(killer)).attack_damage == 73, "Live specimen buffs hidden")
	killer.attack_damage = 3
	check(Records.specimen_stats(weakref(killer)).attack_damage == 3, "Live specimen nerfs hidden")
	var field_record := Records.record_for(&"oaven_spear", "Creations", build, world, session)
	check(field_record.stats.attack_damage == 3, "Gallery must reflect a living nerf")
	var sibling := RTSUnit.new()
	sibling.unit_archetype = &"oaven_spear"
	sibling.owner_player_id = 1
	root.add_child(sibling)
	sibling.attack_damage = 73
	field_record = Records.record_for(&"oaven_spear", "Creations", build, world, session)
	check(field_record.stat_labels.attack_damage == "3-73", "Different living specimens must show a range")
	check(field_record.template_stats.attack_damage != 3, "Live nerf must not overwrite template")
	var archive := preload("res://scripts/ui/observer_vault.gd").new()
	root.add_child(archive)
	check(archive.open_archive(source, build, world), "Completed friendly Vault failed to open")
	check(archive.current_tier == 1, "Vault must start at Tier I")
	check(archive.grid.get_child_count() == 1, "Tier I must contain one Oaven family card")
	archive.grid.get_child(0).pressed.emit()
	check(archive.content.find_child("Form_oaven_jumper",true,false) != null, "Oaven evolution missing inside its record")
	archive.content.find_child("Form_oaven_jumper",true,false).pressed.emit()
	check(archive.selected_id == &"oaven_jumper", "Evolution selection failed")
	await shot("vault_oaven_evolution")
	archive.choose_tier(1)
	await shot("vault_hand_tier1")
	archive.choose_tier(2)
	check(archive.hand.has_node("TierFog"), "Tier II must be fogged until researched")
	for card in archive.grid.get_children():
		check(card.record.sealed and card.portrait == null, "Fogged hand leaked unit imagery")
	await shot("vault_sealed")
	archive.choose_tier(3)
	check(archive.hand.has_node("TierFog"), "Tier III must be fogged until researched")
	await shot("vault_hand_tier3_locked")
	archive.section = "Felled"
	archive.current_tier = 1
	archive.refresh()
	await shot("vault_felled")
	archive.section = "Creations"
	build.researched_upgrade_ranks[&"tier_two_hybrids"] = 1
	build.researched_upgrade_ranks[&"tier_three_hybrids"] = 1
	archive.choose_tier(2)
	check(not archive.hand.has_node("TierFog"), "Research must clear the tier fog")
	check(archive.grid.get_child_count() == 2, "Tier II must contain Mangler and Serpent families only")
	check(not Records.record_for(&"spawner", "Creations", build, world, session).sealed, "Tier unlock failed")
	await shot("vault_unsealed")
	var lifted: Button = archive.grid.get_child(0)
	lifted.mouse_entered.emit()
	await shot("vault_hand_hover")
	lifted = archive.grid.get_child(0)
	check(lifted.position == lifted.home_position and is_zero_approx(lifted.rotation), "Hover must preserve a straight, stable card")
	lifted.pressed.emit()
	check(archive.selected_id == &"mangler", "Card selection must open base unit")
	archive.content.find_child("Form_winged_mangler",true,false).pressed.emit()
	check(archive.selected_id == &"winged_mangler", "Evolved Mangler must open within family")
	await shot("vault_hand_open")
	archive.choose_tier(3)
	check(archive.grid.get_child_count() == 1, "Spawner evolution and drone must not duplicate tier cards")
	await shot("vault_hand_tier3")
	archive.grid.get_child(0).pressed.emit()
	check(archive.content.find_child("Form_spawner_drone",true,false) != null, "Summoned drone missing from Spawner record")
	await shot("vault_spawner_family")
	archive.section = "Research"
	archive.refresh()
	await shot("vault_research")
	archive.section = "Creations"
	archive.selected_id = &"mangler"
	archive.refresh()
	await shot("vault_detail")
	archive.selected_id = &""
	root.size = Vector2i(1024,720)
	root.content_scale_size = root.size
	archive.refresh()
	await shot("vault_1024")
	source.health = 0
	await process_frame
	await process_frame
	check(not archive.overlay.visible, "Destroyed Vault must close")
	source.health = 320
	source.complete = false
	check(not archive.open_archive(source, build, world), "Incomplete Vault must not open")
	source.complete = true
	source.owner_player_id = 2
	check(not archive.open_archive(source, build, world), "Enemy Vault must not open")
	archive.queue_free()
	await process_frame
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	root.size = Vector2i(1440,900)
	root.content_scale_size = root.size
	await shot("observer_menu")
	menu._on_start_pressed()
	await shot("observer_characters")
	menu._on_bad_kon_pressed()
	menu._on_character_continue_pressed()
	await shot("observer_maps")
	check(menu.selected_character_id == "bad_kon_willow", "Character selection broke")
	menu._on_audio_pressed()
	await shot("observer_audio")
	menu._on_display_pressed()
	await shot("observer_display")
	session.start_new_game("next-run")
	check(session.felled_specimens.is_empty(), "New expedition retained enemy discoveries")
	build.free()
	print("[ObserverUI] failures=", failures)
	quit(0 if failures == 0 else 1)

func shot(name: String) -> void:
	for i in 8:
		await process_frame
	if DisplayServer.get_name() == "headless":
		return
	await create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("ART_SHOT_DIR")
	if not dir.is_empty():
		var image := root.get_texture().get_image()
		check(not image.is_empty(), "Blank capture")
		image.save_png(dir.path_join(name+".png"))
