extends Node

const FX = preload("res://scripts/fx/kon_spell_fx.gd")
const BANISH = preload("res://scripts/fx/kon_banish.gd")
const SEAL_RADIUS := 150.0
const STORM_RADIUS := 200.0
const CAST_RANGE := 640.0
const STORM_COST := 60
const STORM_SECONDS := 4.0
const STORM_TICK := 0.5
const STORM_DAMAGE := 12
var cooldowns := {&"seal_away":0.0, &"biostorm":0.0}
var last_error := ""
var _observation_fx: Node2D

func _process(delta: float) -> void:
	for key in cooldowns: cooldowns[key]=maxf(0.0,float(cooldowns[key])-delta)
	var unit := get_parent()
	var observing: bool = bool(unit.get("_observer_aura_enabled")) and not unit.is_banished()
	if observing and not is_instance_valid(_observation_fx):
		_observation_fx=spawn_fx(&"observation",unit.global_position,100.0,999999.0)
	if is_instance_valid(_observation_fx):
		if not observing: _observation_fx.queue_free()
		else:
			_observation_fx.global_position=unit.global_position
			_observation_fx.floor_level=int(unit.get("nav_level")) if int(unit.get("nav_level"))>0 else -1

func _exit_tree() -> void:
	if is_instance_valid(_observation_fx): _observation_fx.queue_free()

func cast(action: StringName, center: Vector2) -> bool:
	var unit := get_parent()
	last_error=""
	if not cooldowns.has(action): return false
	if unit.is_banished() or not unit.is_alive() or unit._is_stunned():
		last_error="Kon cannot cast in his current state"
		return false
	if unit.is_observer_aura_enabled():
		last_error="Cancel Observation before casting"
		return false
	if float(cooldowns[action])>0:
		last_error="%s: %.1fs remaining" % [String(action).capitalize(),cooldowns[action]]
		return false
	if not center.is_finite() or unit.global_position.distance_to(center)>CAST_RANGE:
		last_error="Target is out of range"
		return false
	if action==&"biostorm":
		var economy: Node=unit.get("_economy_manager")
		if economy==null or not economy.spend(int(unit.get("owner_player_id")),{&"bio":STORM_COST}):
			last_error="Biostorm requires 60 Bio"
			return false
	unit.call("issue_stop_order")
	unit.call("_set_ability_animation",action,1.0)
	if action==&"seal_away":
		cooldowns[action]=12.0
		spawn_fx(action,center,seal_radius(),5.0)
		for victim in units_in_circle(center,seal_radius()):
			if victim.is_banished(): continue
			var banish := BANISH.new()
			victim.add_child(banish)
	else:
		cooldowns[action]=18.0
		var storm := spawn_fx(action,center,STORM_RADIUS,STORM_SECONDS)
		storm.damage_source=weakref(unit)
		storm.world=unit.get("rts_world")
	return true

func units_in_circle(center: Vector2, radius: float) -> Array[Node2D]:
	var found: Array[Node2D]=[]
	var unit := get_parent()
	var world: Node=unit.get("rts_world")
	var candidates: Array=world.all_units() if is_instance_valid(world) else get_tree().get_nodes_in_group("units")
	for victim in candidates:
		if is_instance_valid(victim) and victim.has_method("is_banished") and victim.is_alive() and victim.global_position.distance_squared_to(center)<=radius*radius:
			found.append(victim)
	return found

func spawn_fx(action: StringName, center: Vector2, radius: float, seconds: float) -> Node2D:
	var fx := FX.new()
	fx.action=action
	fx.radius=radius
	fx.duration=seconds
	get_parent().get_parent().add_child(fx)
	fx.global_position=center
	return fx

func observer_at_tower_top() -> bool:
	var unit := get_parent()
	if not unit.is_observer_aura_enabled() or unit.is_banished(): return false
	var bridge: Node=unit.get_node_or_null("../BlockNavBridge")
	var build: Node=unit.get_node_or_null("../BuildSystem")
	if bridge==null or bridge.world==null or build==null: return false
	var cell: Vector2i=bridge.terrain.world_to_cell(unit.global_position)
	for structure in build.structures:
		if int(structure.get("player_id",-1))!=int(unit.get("owner_player_id")) or not bool(structure.get("complete",false)): continue
		if structure.get("block_structure",&"")!=&"kons_observation_wizard_tower_01": continue
		for placement in bridge.world.placements():
			if placement.id!=structure.get("block_instance",&""): continue
			var local: Vector2i=cell-placement.origin
			var definition: BlockStructureDefinition = bridge.library.get_definition(placement.structure).rotated(int(placement.get("rotation_steps", 0)))
			var node := Vector3i(local.x, int(unit.get("nav_level"))-int(placement.base_level), local.y)
			if definition.nav_at(node).get("region_id", &"") == &"observatory":
				return bridge.world.has_node(cell,int(unit.get("nav_level")))
	return false

func sight_radius_cells() -> int:
	if not get_parent().is_observer_aura_enabled(): return 9
	var base := 18+2*int(get_parent().wizard_upgrade_rank("observer_aura"))
	return base*2 if observer_at_tower_top() else base

func seal_radius() -> float:
	return SEAL_RADIUS+12.0*float(get_parent().wizard_upgrade_rank("seal_away"))

func can_remote_summon(position: Vector2) -> bool:
	return observer_at_tower_top() and get_parent().global_position.distance_to(position)<=float(sight_radius_cells())*64.0
