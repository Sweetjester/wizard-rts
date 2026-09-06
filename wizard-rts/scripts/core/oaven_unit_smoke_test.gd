extends SceneTree

const OAVEN_SCENE := preload("res://scenes/units/oaven_spear.tscn")
const DEOM_SCENE := preload("res://scenes/units/deom_legion_unit.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := Node2D.new()
	root.name = "OavenSmokeRoot"
	self.root.add_child(root)

	var oaven := OAVEN_SCENE.instantiate()
	oaven.name = "OavenUnderTest"
	oaven.owner_player_id = 1
	root.add_child(oaven)
	oaven.global_position = Vector2(0, 0)
	oaven.call("_apply_catalog_definition")
	oaven.health = oaven.max_health

	var enemy := DEOM_SCENE.instantiate()
	enemy.name = "MovingDeomTarget"
	enemy.owner_player_id = 2
	enemy.configure_enemy(&"deom_blade")
	root.add_child(enemy)
	enemy.global_position = Vector2(72, 0)
	enemy.moving = true
	enemy.health = enemy.max_health

	var ok := true
	ok = _expect(oaven.unit_archetype == &"oaven_spear", "Oaven scene spawns as oaven_spear") and ok
	ok = _expect(not oaven.activate_taunt(), "Taunt safely refuses without an RTSWorld query") and ok

	var enemy_hp_before := int(enemy.health)
	oaven.call("_try_oaven_crippling_attack", enemy)
	ok = _expect(int(enemy.health) < enemy_hp_before, "Oaven Spear damages and cripples target") and ok
	ok = _expect(int(enemy.get("_slowed_until_msec")) > Time.get_ticks_msec(), "Crippling spear slows target") and ok

	ok = _expect(oaven.debug_force_evolve(), "Oaven Spear evolves") and ok
	ok = _expect(oaven.unit_archetype == &"oaven_jumper", "Evolution becomes oaven_jumper") and ok
	ok = _expect(oaven.activate_flight(), "Oaven Jumper temporary flight activates") and ok
	ok = _expect(bool(oaven.ignores_terrain), "Temporary flight ignores terrain") and ok
	oaven.call("_update_winged_spawner_flight", 0.1)
	ok = _expect(oaven._flight_state == &"flying", "Spawner flight updater does not ground the Jumper") and ok
	ok = _expect(oaven.activate_charge(), "Oaven Jumper can arm aerial charge") and ok

	var enemy_2 := DEOM_SCENE.instantiate()
	enemy_2.name = "LandingVictim"
	enemy_2.owner_player_id = 2
	enemy_2.configure_enemy(&"deom_blade")
	root.add_child(enemy_2)
	enemy_2.global_position = Vector2(40, 0)
	enemy_2.health = enemy_2.max_health
	var enemy_2_hp_before := int(enemy_2.health)
	oaven.call("_try_oaven_jumper_landing", enemy_2)
	ok = _expect(int(enemy_2.health) < enemy_2_hp_before, "Aerial charge landing damages target") and ok
	ok = _expect(int(enemy_2.stunned_until_msec) > Time.get_ticks_msec(), "Aerial charge landing stuns target") and ok

	if not ok:
		quit(1)
		return
	print("[OavenUnitSmokeTest] Oaven Spear/Jumper combat hooks are coherent.")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("[OavenUnitSmokeTest] FAILED: %s" % message)
		return false
	print("[OavenUnitSmokeTest] OK: %s" % message)
	return true
