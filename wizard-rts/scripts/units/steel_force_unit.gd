extends RTSUnit

var embarked := false
var attack_visual_age := 10.0

func _ready() -> void:
	super()
	move_speed = 145 if unit_archetype == &"poorper" else 90
	collision_separation = 18 if unit_archetype == &"poorper" else 25

func _apply_owner_art_tint() -> void:
	pass

func _draw() -> void:
	_draw_selection_and_path()

func is_banished() -> bool:
	return embarked or super()

func _current_move_speed() -> float:
	return 0.0 if embarked else super()

func _snap_to_walkable_terrain() -> void:
	if not embarked: super()

func rts_movement_tick(delta: float) -> void:
	attack_visual_age += delta
	if embarked: return
	super(delta)

func rts_combat_tick(delta: float, nearby_units: Array[Node2D]) -> void:
	if embarked: return
	super(delta,nearby_units)

func _fire_attack(target: Node2D, damage_multiplier: float = 1.0) -> void:
	if embarked or not is_alive() or is_banished() or _is_stunned() or not is_instance_valid(target): return
	attack_visual_age = 0.0
	super(target,damage_multiplier)

func _spawn_death_fx(source: Node = null) -> void:
	var art := get_node_or_null("ArtSprite") as Sprite2D
	if art == null or art.texture == null:
		super(source)
		return
	art.offset.y = -138
	art.set_meta("foot_anchor_y",330.0)
	var view := get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view):
		view.spawn_painted_unit_death(self,art)
	else:
		var corpse := preload("res://scripts/fx/painted_unit_death.gd").new()
		get_parent().add_child(corpse)
		corpse.configure(self,art)
