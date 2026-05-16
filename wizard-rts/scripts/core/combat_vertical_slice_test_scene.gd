extends Node2D

const KON_SCENE := preload("res://scenes/units/oaven_spear.tscn")
const DEOM_SCENE := preload("res://scenes/units/deom_legion_unit.tscn")

var rts_world: RTSWorld
var combat_system: CombatSystem
var selection_controller: SelectionController

func _ready() -> void:
	rts_world = get_node("RTSWorld")
	combat_system = get_node("CombatSystem")
	selection_controller = get_node("SelectionController")
	_spawn_test_entities()
	print("[CombatVerticalSliceTest] Ready. Select the cyan KON unit, right-click the enemy unit or red outpost.")

func _spawn_test_entities() -> void:
	var kon := KON_SCENE.instantiate()
	kon.name = "KON_Oaven_Test"
	kon.owner_player_id = 1
	add_child(kon)
	kon.global_position = Vector2(260, 300)

	var enemy := DEOM_SCENE.instantiate()
	enemy.name = "Enemy_Deom_Test"
	enemy.owner_player_id = 2
	enemy.configure_enemy(&"deom_blade")
	add_child(enemy)
	enemy.owner_player_id = 2
	enemy.global_position = Vector2(560, 300)

	var hq := KonStructure.new()
	hq.name = "KON_HQ_Test"
	hq.configure(&"wizard_tower", Vector2i(2, 2), Vector2i(3, 3))
	hq.set_runtime_stats(1, 700, 700, 1)
	add_child(hq)
	hq.global_position = Vector2(180, 520)

	var outpost := KonStructure.new()
	outpost.name = "Enemy_Outpost_Test"
	outpost.configure(&"enemy_outpost", Vector2i(8, 2), Vector2i(4, 4))
	outpost.set_runtime_stats(2, 220, 220, 1)
	add_child(outpost)
	outpost.global_position = Vector2(760, 300)
	outpost.destroyed.connect(func(_structure: KonStructure, source: Node) -> void:
		print("[CombatVerticalSliceTest] Enemy outpost destroyed by ", source.name if source != null and is_instance_valid(source) else "<unknown>")
	)

	enemy.issue_attack_move_order(hq.global_position)
	_log_entity("kon", kon)
	_log_entity("enemy", enemy)
	_log_entity("hq", hq)
	_log_entity("outpost", outpost)

func _log_entity(context: String, node: Node) -> void:
	print("[CombatVerticalSliceTest] ", context,
		" node=", node.name,
		" owner=", node.get("owner_player_id") if _has_property(node, "owner_player_id") else "<missing>",
		" hp=", node.get("health") if _has_property(node, "health") else "<missing>",
		" max=", node.get("max_health") if _has_property(node, "max_health") else "<missing>",
		" take_damage=", node.has_method("take_damage"),
		" unit_registered=", rts_world.all_units().has(node) if rts_world != null else false,
		" structure_registered=", rts_world.all_structures().has(node) if rts_world != null else false,
		" groups=", node.get_groups())

func _has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
