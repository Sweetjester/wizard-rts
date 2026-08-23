extends "res://scripts/units/rts_unit.gd"

const LIFE_WIZARD_SHEET: Texture2D = preload("res://assets/units/kon/bad_kon_willow_directions.png")
const FIRE_WIZARD_SHEET: Texture2D = preload("res://assets/units/vampire_mushroom_forest/fire_wizard_sheet.png")
const EVANGALION_PORTRAIT: Texture2D = preload("res://assets/ui/characters/evangalion.png")

# WC3-style hero leveling: the wizard gains XP from combat, and each level lets
# the player choose one upgrade rather than applying it automatically (unlike
# the generic per-unit "evolution" system, which is automatic with no choice).
const WIZARD_MAX_LEVEL := 6
const WIZARD_XP_BASE := 220.0
const WIZARD_XP_GROWTH := 1.35
const SPELL_UPGRADE_OPTIONS: Array[String] = ["bio_mend", "seal_away", "observer_aura"]
const STAT_UPGRADE_OPTIONS: Array[String] = ["power", "vitality", "swiftness"]

signal leveled_up(new_level: int, options: Array)

@onready var art_sprite: Sprite2D = get_node_or_null("ArtSprite")

var _anim_elapsed := 0.0
var _anim_frame := 0
var _wizard_class_id := "bad_kon_willow"
var _art_base_position := Vector2.ZERO
var wizard_level := 1
var wizard_xp := 0.0
var pending_level_up := false
var wizard_upgrade_ranks: Dictionary = {}

func _ready() -> void:
	match _get_session_wizard_class():
		"hellfire_baby":
			unit_archetype = &"fire_wizard"
		"evangalion":
			unit_archetype = &"evangalion_wizard"
		_:
			unit_archetype = &"life_wizard"
	super()
	move_speed = 190.0
	selection_radius = 26.0
	collision_separation = 24.0
	_apply_wizard_art()
	print("[Wizard] Ready at ", global_position)

func _get_session_wizard_class() -> String:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return _wizard_class_id
	return str(session.get("wizard_class_id"))

func _process(delta: float) -> void:
	super(delta)
	_update_sprite_animation(delta)

func _apply_wizard_art() -> void:
	if art_sprite == null:
		return
	_wizard_class_id = _get_session_wizard_class()
	art_sprite.offset = Vector2.ZERO
	if _wizard_class_id == "evangalion":
		art_sprite.texture = EVANGALION_PORTRAIT
		art_sprite.hframes = 1
		art_sprite.vframes = 1
		art_sprite.offset = Vector2(0, -58)
		art_sprite.scale = Vector2(0.11, 0.11)
		_art_base_position = art_sprite.position
		art_sprite.frame = 0
		return
	art_sprite.texture = FIRE_WIZARD_SHEET if _wizard_class_id == "hellfire_baby" else LIFE_WIZARD_SHEET
	art_sprite.hframes = 4 if _wizard_class_id == "hellfire_baby" else 3
	art_sprite.vframes = 2 if _wizard_class_id == "hellfire_baby" else 8
	art_sprite.scale = Vector2(1.08, 1.08) if _wizard_class_id != "hellfire_baby" else Vector2.ONE
	_art_base_position = art_sprite.position
	art_sprite.frame = 0

func _update_sprite_animation(delta: float) -> void:
	if art_sprite == null:
		return
	if _wizard_class_id == "evangalion":
		art_sprite.frame = 0
		_apply_wizard_sprite_motion()
		return
	if _wizard_class_id != "hellfire_baby":
		_update_kon_sprite_animation(delta)
		return
	var frame_time := 0.11 if moving else 0.22
	_anim_elapsed += delta
	if _anim_elapsed < frame_time:
		return
	_anim_elapsed = 0.0
	_anim_frame = (_anim_frame + 1) % 4
	var row := 1 if moving else 0
	art_sprite.frame = row * 4 + _anim_frame
	_apply_wizard_sprite_motion()

func _update_kon_sprite_animation(delta: float) -> void:
	var frame_time := 0.10 if moving or unit_state == &"attacking" else 0.24
	_anim_elapsed += delta
	if _anim_elapsed >= frame_time:
		_anim_elapsed = 0.0
		_anim_frame = (_anim_frame + 1) % 3
	var row := _direction_row()
	art_sprite.frame = row * 3 + _anim_frame
	_apply_wizard_sprite_motion()

func _apply_wizard_sprite_motion() -> void:
	var bob := 0.0
	var sway := 0.0
	var lunge := 0.0
	var squash := Vector2.ONE
	if moving:
		var stride := sin(_visual_elapsed * 13.0)
		bob = -absf(stride) * 3.0
		sway = sin(_visual_elapsed * 6.5) * 1.1
		squash = Vector2(1.0 + absf(stride) * 0.025, 1.0 - absf(stride) * 0.025)
	elif unit_state == &"attacking":
		var cast := absf(sin(_visual_elapsed * 16.0))
		lunge = cast * 4.0 * _facing_sign
		bob = -cast * 2.5
		squash = Vector2(1.0 + cast * 0.04, 1.0 - cast * 0.025)
	art_sprite.position = _art_base_position + Vector2(sway + lunge, bob)
	var base_scale := Vector2(0.11, 0.11) if _wizard_class_id == "evangalion" else Vector2(1.08, 1.08) if _wizard_class_id != "hellfire_baby" else Vector2.ONE
	art_sprite.scale = Vector2(base_scale.x * squash.x, base_scale.y * squash.y)

func _direction_row() -> int:
	var direction := Vector2(_facing_sign, 0.25)
	if attack_target != null and is_instance_valid(attack_target):
		direction = attack_target.global_position - global_position
	elif not path.is_empty():
		direction = path[0] - global_position
	elif velocity.length_squared() > 4.0:
		direction = velocity
	var angle := direction.angle()
	return posmod(int(round((angle + PI * 0.5) / (TAU / 8.0))), 8)

func take_damage(amount: int, source: Node = null, damage_type: StringName = &"physical") -> void:
	var mitigation := magic_armor if damage_type == &"magic" else armor
	var actual_damage := maxi(1, amount - mitigation)
	health = maxi(0, health - actual_damage)
	_gain_evolution_xp(float(actual_damage) * 0.35)
	queue_redraw()
	if health <= 0:
		_die(source)

func _xp_required_for_level(level: int) -> float:
	return WIZARD_XP_BASE * pow(WIZARD_XP_GROWTH, float(level - 1))

func _gain_wizard_xp(amount: float) -> void:
	if _dying or wizard_level >= WIZARD_MAX_LEVEL or amount <= 0.0:
		return
	wizard_xp += amount
	while wizard_level < WIZARD_MAX_LEVEL and wizard_xp >= _xp_required_for_level(wizard_level):
		wizard_xp -= _xp_required_for_level(wizard_level)
		wizard_level += 1
		pending_level_up = true
		leveled_up.emit(wizard_level, wizard_upgrade_options())

func wizard_upgrade_options() -> Array:
	return SPELL_UPGRADE_OPTIONS if _wizard_class_id == "bad_kon_willow" else STAT_UPGRADE_OPTIONS

func wizard_upgrade_rank(option: String) -> int:
	return int(wizard_upgrade_ranks.get(option, 0))

func choose_wizard_upgrade(option: String) -> bool:
	if not pending_level_up or not wizard_upgrade_options().has(option):
		return false
	pending_level_up = false
	_apply_wizard_upgrade(option)
	print("[Wizard] Level ", wizard_level, " upgrade chosen: ", option, " (rank ", wizard_upgrade_rank(option), ")")
	return true

# WC3-style creep-camp item drop: found on the map (outpost/content-plot clear),
# applied immediately with no player choice -- distinct from choose_wizard_upgrade(),
# which is the level-up decision the player actively makes.
func grant_relic_upgrade(option: String = "") -> String:
	var options := wizard_upgrade_options()
	var chosen: String = option if options.has(option) else str(options[randi() % options.size()])
	_apply_wizard_upgrade(chosen)
	print("[Wizard] Relic found: ", chosen, " (rank ", wizard_upgrade_rank(chosen), ")")
	return chosen

func _apply_wizard_upgrade(option: String) -> void:
	wizard_upgrade_ranks[option] = wizard_upgrade_rank(option) + 1
	match option:
		"power":
			attack_damage += 4
		"vitality":
			max_health += 40
			health += 40
		"swiftness":
			move_speed += 12.0
		_:
			pass

func _draw() -> void:
	if has_node("ArtSprite"):
		_draw_selection_and_path()
		return
	draw_circle(Vector2(0, 8), 15, Color(0, 0, 0, 0.32))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 0), Vector2(10, 0),
		Vector2(13, 20), Vector2(-13, 20)
	]), Color("#2D5A3E"))
	draw_circle(Vector2(0, -4), 9, Color("#D6C7AE"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -11), Vector2(8, -11),
		Vector2(3, -31), Vector2(-3, -31)
	]), Color("#5C0F14"))
	draw_circle(Vector2(0, -23), 3.0, Color("#7DDDE8"))
	draw_circle(Vector2(-3, -5), 1.5, Color("#0A1612"))
	draw_circle(Vector2(3, -5), 1.5, Color("#0A1612"))
	_draw_selection_and_path()
