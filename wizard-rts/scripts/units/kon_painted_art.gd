extends Sprite2D

const ACTIONS: Array[StringName] = [&"idle", &"move", &"attack", &"seal_away", &"observer_aura", &"biostorm", &"hit", &"death"]
var current_action: StringName = &"idle"
var _clock := 0.0
var _shot_left := 0.0
var _hurt_left := 0.0
var _last_hp := -1

func _ready() -> void:
	set_process(true)
	texture = load("res://assets_game/units/kon/hero/painted_v2/kon.png")
	hframes = 12
	vframes = 8
	position = Vector2.ZERO
	offset = Vector2(0,-138)
	scale = Vector2.ONE*0.43
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_meta("billboard_pixel_size",0.009)
	set_meta("foot_anchor_y",330.0)
	set_meta("death_row",7)
	set_meta("death_seconds",1.25)
	set_meta("corpse_hold_seconds",2.5)

func play_attack() -> void:
	_shot_left = 0.75

func _process(delta: float) -> void:
	var unit := get_parent()
	var hp := int(unit.get("health"))
	if _last_hp>=0 and hp<_last_hp: _hurt_left=0.30
	_last_hp=hp
	var next: StringName = &"move" if bool(unit.get("moving")) else &"idle"
	if _shot_left>0: next=&"attack"
	var ability := StringName(unit.get("ability_animation_action"))
	if ability in [&"seal_away", &"biostorm", &"observer_aura"]: next=ability
	if _hurt_left>0 and next!=&"observer_aura": next=&"hit"
	if next!=current_action:
		current_action=next
		_clock=0.0
	var index := int(_clock*10.0)%12
	if next==&"attack": index=clampi(int((0.75-_shot_left)*16),0,11)
	if next==&"hit": index=mini(11,int(_clock*40))
	if next in [&"seal_away",&"biostorm"]: index=mini(11,int(_clock*12))
	frame=ACTIONS.find(next)*12+index
	var direction: Vector2=unit.get("velocity")
	var target: Node2D=unit.get("attack_target")
	if is_instance_valid(target): direction=target.global_position-unit.global_position
	if absf(direction.x)>0.5: flip_h=direction.x<0
	_clock+=delta
	_shot_left=maxf(0.0,_shot_left-delta)
	_hurt_left=maxf(0.0,_hurt_left-delta)
