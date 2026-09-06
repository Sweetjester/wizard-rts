extends Sprite2D

const ACTIONS: Array[StringName]=[&"idle",&"move",&"attack_spear",&"attack_blowpipe",&"hit",&"death",&"taunt",&"swap_weapon",&"charge",&"takeoff",&"flying",&"landing",&"evolve",&"idle_blowpipe",&"move_blowpipe"]
var current_action: StringName=&"idle"
var _clock:=0.0
var _last_health:=-1
var _hurt_left:=0.0
var _evolved:=false

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	hframes=12
	vframes=ACTIONS.size()
	offset=Vector2(0,-123)
	scale=Vector2.ONE*(0.598/1.5)
	set_meta("billboard_pixel_size",0.01014/1.5)
	set_meta("foot_anchor_y",315.0)
	_set_form(false)

func _set_form(evolved: bool) -> void:
	_evolved=evolved
	texture=load("res://assets_game/units/kon/oaven/painted_v3/jumper.png" if evolved else "res://assets_game/units/kon/oaven/painted_v3/oaven.png")

func _process(delta: float) -> void:
	var unit:=get_parent()
	if unit==null:
		return
	var evolved: bool=unit.get("unit_archetype")==&"oaven_jumper"
	if evolved!=_evolved: _set_form(evolved)
	var hp:=int(unit.get("health"))
	if _last_health>=0 and hp<_last_health and hp>0: _hurt_left=0.28
	_last_health=hp
	_hurt_left=maxf(0.0,_hurt_left-delta)
	var next: StringName=&"idle_blowpipe" if unit.get("weapon_mode")==&"blowpipe" else &"idle"
	var ability:=StringName(unit.get("ability_animation_action"))
	if bool(unit.get("moving")):
		next=&"move_blowpipe" if unit.get("weapon_mode")==&"blowpipe" else &"move"
	if unit.get("unit_state")==&"attacking":
		next=&"attack_blowpipe" if unit.get("weapon_mode")==&"blowpipe" else &"attack_spear"
	if unit.get("_flight_state")==&"flying": next=&"flying"
	if ACTIONS.has(ability): next=ability
	if ability==&"landing_stun": next=&"landing"
	if _hurt_left>0.0 or unit.get("unit_state")==&"stunned": next=&"hit"
	if next!=current_action:
		current_action=next
		_clock=0.0
	_clock+=delta
	var frame_index:=int(_clock*12.0)%12
	if next in [&"idle",&"idle_blowpipe"]: frame_index=int(_clock*7.0)%12
	if next in [&"attack_spear",&"attack_blowpipe"]:
		# Damage fires when the attack clock resets. Frame 5 is the contact pose.
		var cooldown:=maxf(0.1,float(unit.call("_current_attack_cooldown")))
		frame_index=int(fposmod(float(unit.get("_attack_elapsed"))/cooldown+0.42,1.0)*12.0)
	if next==&"hit": frame_index=mini(11,int(_clock*36.0))
	if next in [&"takeoff",&"landing",&"evolve",&"swap_weapon"]: frame_index=mini(11,int(_clock*12.0))
	frame=ACTIONS.find(next)*12+clampi(frame_index,0,11)
	var direction: Vector2=unit.get("velocity")
	var target: Node2D=unit.get("attack_target")
	if is_instance_valid(target): direction=target.global_position-unit.global_position
	if absf(direction.x)>0.5: flip_h=direction.x<0.0
