extends Sprite2D

var current_action := &"idle"
var _level := 0
var _clock := 0.0
var _attack_left := 0.0
var _hurt_left := 0.0
var _last_hp := -1

func _ready() -> void:
	hframes = 12
	vframes = 9
	scale = Vector2.ONE*0.576
	offset = Vector2(0,-67)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_meta("billboard_pixel_size",0.009)
	set_meta("foot_anchor_y",195.0)
	set_meta("death_row",7)
	set_meta("death_seconds",1.25)
	set_meta("corpse_hold_seconds",2.0)
	_update_level(1)

func _update_level(level: int) -> void:
	if level == _level: return
	_level = level
	texture = load("res://assets_game/units/kon/serpent/painted_v2/serpent_%d.png" % clampi(level,1,6))

func play_attack() -> void: _attack_left = 0.65

func _process(delta: float) -> void:
	var unit := get_parent()
	if not is_instance_valid(unit): return
	_update_level(int(unit.evolution_level))
	if _last_hp>unit.health and unit.health>0: _hurt_left = 0.3
	_last_hp = unit.health
	visible = not unit._stone_form_active
	var row := 1 if unit.moving else 0
	var index := int(_clock*12)%12
	if _attack_left>0:
		row = 2
		index = mini(11,int((0.65-_attack_left)/0.65*12))
	if _hurt_left>0:
		row = 8
		index = mini(11,int((0.3-_hurt_left)*40))
	if unit._stone_cast_remaining>0:
		row = 3
		index = clampi(int((1-unit._stone_cast_remaining/2.0)*11),0,11)
	elif unit.ability_animation_action == &"revert_stone": row = 5
	elif unit.ability_animation_action == &"evolve_growth": row = 6
	if row in [5,6]:
		var duration := 0.45 if row==5 else 1.0
		var remaining := maxf(0,float(unit._ability_animation_until_msec-Time.get_ticks_msec())/1000.0)
		index = clampi(int((1-remaining/duration)*11),0,11)
	if unit._stone_form_active: row = 4
	current_action = [&"idle",&"move",&"attack",&"harden",&"wall",&"revert",&"evolve",&"death",&"hit"][row]
	frame = row*12+index
	var direction: Vector2 = unit.velocity
	if is_instance_valid(unit.attack_target): direction = unit.attack_target.global_position-unit.global_position
	if absf(direction.x)>0.5: flip_h = direction.x<0
	offset.x = (3+2*(_level-1))*10.5*(1 if flip_h else -1)
	_clock += delta
	_attack_left = maxf(0,_attack_left-delta)
	_hurt_left = maxf(0,_hurt_left-delta)
