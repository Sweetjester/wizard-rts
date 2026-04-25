extends "res://scripts/units/rts_unit.gd"

const LIFE_WIZARD_SHEET: Texture2D = preload("res://assets/units/vampire_mushroom_forest/life_wizard_sheet.png")
const FIRE_WIZARD_SHEET: Texture2D = preload("res://assets/units/vampire_mushroom_forest/fire_wizard_sheet.png")

@onready var art_sprite: Sprite2D = get_node_or_null("ArtSprite")

var _anim_elapsed := 0.0
var _anim_frame := 0
var _wizard_class_id := "bad_kon_willow"

func _ready() -> void:
	unit_archetype = &"fire_wizard" if _get_session_wizard_class() == "hellfire_baby" else &"life_wizard"
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
	return String(session.get("wizard_class_id"))

func _process(delta: float) -> void:
	super(delta)
	_update_sprite_animation(delta)

func _apply_wizard_art() -> void:
	if art_sprite == null:
		return
	_wizard_class_id = _get_session_wizard_class()
	art_sprite.texture = FIRE_WIZARD_SHEET if _wizard_class_id == "hellfire_baby" else LIFE_WIZARD_SHEET
	art_sprite.hframes = 4
	art_sprite.vframes = 2
	art_sprite.frame = 0

func _update_sprite_animation(delta: float) -> void:
	if art_sprite == null:
		return
	var frame_time := 0.11 if moving else 0.22
	_anim_elapsed += delta
	if _anim_elapsed < frame_time:
		return
	_anim_elapsed = 0.0
	_anim_frame = (_anim_frame + 1) % 4
	var row := 1 if moving else 0
	art_sprite.frame = row * 4 + _anim_frame

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
