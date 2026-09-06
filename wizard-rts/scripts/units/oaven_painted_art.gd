extends Sprite2D

const Facing := preload("res://scripts/units/eight_direction_facing.gd")
const DIRECTIONS := ["e","se","s","sw","w","nw","n","ne"]
const ROOT := "res://assets_game/units/kon/oaven/directional_v4/"
static var _pages: Dictionary = {}
var facing_index := 2
var world_facing := Vector2.DOWN
var _page_key := ""

const ACTIONS: Array[StringName]=[&"idle",&"move",&"attack_spear",&"attack_blowpipe",&"hit",&"death",&"taunt",&"swap_weapon",&"charge",&"takeoff",&"flying",&"landing",&"evolve",&"idle_blowpipe",&"move_blowpipe"]
var current_action: StringName=&"idle"
var _clock:=0.0
var _last_health:=-1
var _hurt_left:=0.0
var _evolved:=false

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	hframes=8
	vframes=ACTIONS.size()
	offset=Vector2(0,-61.5)
	scale=Vector2.ONE*(0.598/0.75)
	set_meta("billboard_pixel_size",0.01014/0.75)
	set_meta("foot_anchor_y",157.5)
	set_meta("death_row",5)
	_set_form(get_parent().get("unit_archetype")==&"oaven_jumper")

func _set_form(evolved: bool) -> void:
	_evolved=evolved
	_update_page()

func _update_page() -> void:
	var key: String = ("jumper_" if _evolved else "oaven_")+DIRECTIONS[facing_index]
	if key==_page_key: return
	if not _pages.has(key): _pages[key]=load(ROOT+key+".png")
	texture=_pages[key]
	_page_key=key
	flip_h=false

func sync_view_facing() -> void:
	var unit := get_parent()
	var heading: Vector2 = unit.velocity
	if is_instance_valid(unit.attack_target): heading=unit.attack_target.global_position-unit.global_position
	if heading.length_squared()>.25: world_facing=heading.normalized()
	var screen_heading := world_facing
	var view := unit.get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view) and is_instance_valid(view.get("camera")):
		screen_heading=Facing.camera_relative(world_facing,view.get("camera").global_basis)
	else:
		var camera := get_viewport().get_camera_2d()
		if camera!=null and not camera.ignore_rotation: screen_heading=world_facing.rotated(-camera.global_rotation)
	facing_index=Facing.sector(screen_heading,facing_index)
	_update_page()

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
	var frame_index:=int(_clock*8.0)%8
	if next in [&"idle",&"idle_blowpipe"]: frame_index=int(_clock*(7.0*8.0/12.0))%8
	if next in [&"attack_spear",&"attack_blowpipe"]:
		# Damage fires when the attack clock resets. Frame 3 is the contact pose.
		var cooldown:=maxf(0.1,float(unit.call("_current_attack_cooldown")))
		frame_index=int(fposmod(float(unit.get("_attack_elapsed"))/cooldown+0.42,1.0)*8.0)
	if next==&"hit": frame_index=mini(7,int(_clock*24.0))
	if next in [&"takeoff",&"landing",&"evolve",&"swap_weapon"]: frame_index=mini(7,int(_clock*8.0))
	if next==&"swap_weapon":
		var duration := maxf(.01,float(UnitCatalog.get_definition(unit.unit_archetype).get("weapon_swap_seconds",1.0)))
		frame_index=clampi(int((1.0-unit._weapon_swap_remaining/duration)*8),0,7)
		if unit.weapon_mode==&"spear": frame_index=7-frame_index
	frame=ACTIONS.find(next)*8+clampi(frame_index,0,7)
	sync_view_facing()
