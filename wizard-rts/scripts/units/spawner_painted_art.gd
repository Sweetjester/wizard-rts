extends Sprite2D

const ACTIONS: Array[StringName]=[&"idle",&"move",&"root_cast",&"rooted_idle",&"artillery_attack",&"uproot_cast",&"summon_drone",&"evolve_wings",&"hit",&"death",&"takeoff",&"idle_flying",&"move_flying",&"landing",&"air_artillery",&"summon_flying"]
var current_action: StringName=&"idle"
var _clock:=0.0
var _last_health:=-1
var _hurt_left:=0.0
var _shot_left:=0.0
var _summon_left:=0.0

func _ready() -> void:
	texture=load("res://assets_game/units/kon/spawner/painted_v3/spawner.png")
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	hframes=12
	vframes=ACTIONS.size()
	offset=Vector2(0,-118)
	scale=Vector2.ONE*0.50
	set_meta("billboard_pixel_size",0.009)
	set_meta("foot_anchor_y",310.0)
	set_meta("death_row",9)
	set_meta("death_seconds",1.4)
	set_meta("corpse_hold_seconds",2.0)

func play_shot() -> void:
	_shot_left=0.8

func play_summon() -> void:
	_summon_left=1.0

func _process(delta: float) -> void:
	var unit:=get_parent()
	if unit==null: return
	var hp:=int(unit.get("health"))
	if _last_health>=0 and hp<_last_health and hp>0: _hurt_left=0.35
	_last_health=hp
	var state:=StringName(unit.get("unit_state"))
	var flight:=StringName(unit.get("_flight_state"))
	var ability:=StringName(unit.get("ability_animation_action"))
	var definition:=UnitCatalog.get_definition(StringName(unit.get("unit_archetype")))
	var aerial:=flight==&"flying"
	var next: StringName=&"idle_flying" if aerial else &"idle"
	if bool(unit.get("moving")): next=&"move_flying" if aerial else &"move"
	if bool(unit.get("_spawner_rooted")): next=&"rooted_idle"
	if _summon_left>0: next=&"summon_flying" if aerial else &"summon_drone"
	if _shot_left>0: next=&"air_artillery" if aerial else &"artillery_attack"
	var progress: float=-1.0
	if state==&"rooting":
		next=&"root_cast"
		progress=1.0-float(unit.get("_root_cast_remaining"))/maxf(0.01,float(definition.get("root_cast_seconds",2.0)))
	elif state==&"uprooting":
		next=&"uproot_cast"
		progress=1.0-float(unit.get("_uproot_cast_remaining"))/maxf(0.01,float(definition.get("uproot_cast_seconds",2.0)))
	elif state in [&"takeoff",&"landing"]:
		next=state
		progress=1.0-float(unit.get("_flight_cast_remaining"))/maxf(0.01,float(definition.get("takeoff_seconds" if state==&"takeoff" else "landing_seconds",0.5)))
	if ability==&"evolve":
		next=&"evolve_wings"
		progress=1.0-maxf(0,float(unit.get("_ability_animation_until_msec"))-Time.get_ticks_msec())/1200.0
	if (_hurt_left>0 or state==&"stunned") and progress<0:
		next=&"hit"
	if next!=current_action:
		current_action=next
		_clock=0
	var frame_index:=int(_clock*10.0)%12
	if next in [&"artillery_attack",&"air_artillery"]: frame_index=mini(11,int((0.8-_shot_left)*15))
	if next in [&"summon_drone",&"summon_flying"]: frame_index=mini(11,int((1.0-_summon_left)*12))
	if next==&"hit": frame_index=mini(11,int(_clock*34))
	if progress>=0: frame_index=clampi(int(progress*11),0,11)
	frame=ACTIONS.find(next)*12+clampi(frame_index,0,11)
	var direction: Vector2=unit.get("velocity")
	# NOT typed as Node2D. attack_target can hold a unit that was queue_free()d
	# earlier this same frame -- a killed unit is not actually gone until the end
	# of it -- and assigning a freed object to a TYPED local raises "Trying to
	# assign invalid previously freed instance" instead of giving null. The
	# is_instance_valid() below is the right check; it just never gets to run.
	#
	# The engine does not stop for it, so nothing looks broken from GDScript: it
	# raises once per frame, per unit, for as long as the stale reference is
	# there, each one with a stack capture written to the log and sent to the
	# attached debugger. That is what the freeze was.
	var target = unit.get("attack_target")
	if target != null and is_instance_valid(target): direction=target.global_position-unit.global_position
	if absf(direction.x)>0.5: flip_h=direction.x<0
	_clock+=delta
	_hurt_left=maxf(0,_hurt_left-delta)
	_shot_left=maxf(0,_shot_left-delta)
	_summon_left=maxf(0,_summon_left-delta)
